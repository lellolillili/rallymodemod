-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'createObjectTool'
local imgui = ui_imgui
local imguiUtils = require("ui/imguiUtils")
local createObjectGroupIndex = 1
local createGroups = {}
local currentClassInstance = nil
local currentParent = nil
local currentCreateObjectItem = nil
local simObjectClassNameFilter = imgui.ArrayChar(128)
local simObjectSearch = require('/lua/ge/extensions/editor/util/searchUtil')()
local filteredFieldPopupSize = imgui.ImVec2(300, 500)
local tooltipLongTextLength = 70
local clearButtonSize = imgui.ImVec2(24, 24)
local simObjectClassNames = {}
local allClassesSearchResults = {}
local currentCustomClassName = nil
local activeWhileHoldingCtrl
local lastInstance
local objectIdToSelect
local placeAtCameraPos = false
local fieldsSetOnBuildFunc = {}
local offsetFromSurface = {
  PointLight = 0.2,
  SpotLight = 0.2,
  SFXEmitter = 0.2,
  ParticleEmitterNode = 0.2
}

--per class registration of fields that are set in "buildFunc"s.
local function registerBuildFuncField(classname, fieldname, key, val)
  if fieldsSetOnBuildFunc[classname] == nil then
    fieldsSetOnBuildFunc[classname] = {}
  else
    table.insert(fieldsSetOnBuildFunc[classname], {fieldname, key, val})
  end
end

local function clearBuildFuncFields(classname)
  fieldsSetOnBuildFunc[classname] = {}
end

local function getCurrentSelectedParent()
  if editor.selection.object and not tableIsEmpty(editor.selection.object) then
    local obj = scenetree.findObjectById(editor.selection.object[1])
    if obj and (obj:getClassName() == "SimSet" or obj:isSubClassOf("SimSet")) then
      return obj
    end
    if obj then
      return obj:getGroup()
    end
  end
  -- we return the mission group by default
  return scenetree.MissionGroup
end

local function getNextNumberedName(classname)
  local currentItems = scenetree.findClassObjects(classname)
  local newNameIndex = 1
  local fileNameIndexes = {}

  for _, itemName in ipairs(currentItems) do
    if string.match(itemName, "^"..classname.."_%d+".."$") then
      table.insert(fileNameIndexes, tonumber(string.match(itemName, "[1-9][0-9]*$")))
    end
  end

  table.sort(fileNameIndexes)
  for _, index in ipairs(fileNameIndexes) do
    if index > newNameIndex then
      break
    else
      newNameIndex = newNameIndex + 1
    end
  end

  return classname.."_"..newNameIndex
end

local function createObjectModeDeactivate()
  if currentClassInstance and currentClassInstance:getGroup() then
    currentClassInstance:getGroup():removeObject(currentClassInstance)
    currentClassInstance:delete()
    currentClassInstance = nil
  end
  currentCreateObjectItem = nil
  worldEditorCppApi.setAxisGizmoSelectedElement(-1)
end

-- Create Object
local function createObjectRedo(actionData)
  local obj = worldEditorCppApi.createObject(actionData.classname)

  if actionData.onBuildFuncFields then
    for _, val in pairs(actionData.onBuildFuncFields) do
      obj:setField(val[1], val[2], val[3])
    end
  end

  obj:registerObject("")
  obj:setName(actionData.name)
  editor.history:updateRedoStackObjectId(actionData.objectID, obj:getId())
  actionData.objectID = obj:getId()
  if actionData.transform then
    obj:setTransform(actionData.transform)
  end
  editor.selectObjectById(actionData.objectID)
  if actionData.parent then
    actionData.parent:addObject(obj)
  end
end

local function createObjectUndo(actionData)
  editor.clearObjectSelection()
  editor.deleteObject(actionData.objectID)
end

local function copyMat(mat)
  return mat * MatrixF(true)
end

local function createObjectModeUpdate()
  local res = getCameraMouseRay()

  if not currentClassInstance then return end
  local rayCastInfo = cameraMouseRayCast(true)

  if imgui.IsMouseClicked(0)
      and res
      and editor.isViewportHovered()
      and currentCreateObjectItem then
    lastInstance = currentClassInstance
    -- Add the last object to the scenetree and create a new object to be placed
    if currentParent then
      currentParent:addObject(lastInstance)
      editor.selectObjectById(lastInstance:getID())
    end

    -- create the object and set some default fields (especially for player/observer spawn points)
    local obj = worldEditorCppApi.createObject(currentCreateObjectItem.classname)
    local newName = getNextNumberedName(currentCreateObjectItem.classname)

    if obj then
      currentClassInstance = Sim.upcast(obj)
      obj:setName(newName)
    end

    if currentClassInstance then
      if currentCreateObjectItem.buildFunc then currentCreateObjectItem.buildFunc(currentClassInstance) end
      -- now we can register it (will call onAdd)
      currentClassInstance:registerObject("")
      currentClassInstance:disableCollision()
      editor.selectObjectById(currentClassInstance:getID())
    end

    if lastInstance then
      lastInstance:setSelected(false)
      lastInstance:enableCollision()
      local transform = copyMat(lastInstance:getTransform())
      local fields = {classname = currentCreateObjectItem.classname, name = lastInstance:getName(), parent = currentParent, objectID = lastInstance:getID(), transform = transform}
      local onBuildFuncFields = {}

      if fieldsSetOnBuildFunc[currentCreateObjectItem.classname] then
        for _, val in pairs(fieldsSetOnBuildFunc[currentCreateObjectItem.classname]) do
          -- If this field has been set in buildFunc, serialize it.
          table.insert(onBuildFuncFields, val)
        end
        fields.onBuildFuncFields = onBuildFuncFields
      end

      editor.history:commitAction("CreateObject", fields, createObjectUndo, createObjectRedo, true)
    else
      editor.logError("Could not create object from class name: " .. currentCreateObjectItem.classname)
    end

    editor.setDirty()
    activeWhileHoldingCtrl = true
  end

  -- if this is a scene visual node, then set its position to the cursor in world space
  if rayCastInfo and currentClassInstance and currentClassInstance:isSubClassOf("SceneObject") then
    local obj = Sim.upcast(currentClassInstance)

    if placeAtCameraPos then
      obj:setTransform(editor.getCamera():getTransform())
    else
      local offs = offsetFromSurface[currentClassInstance:getClassName()] or 0
      local finalPos = vec3(
        rayCastInfo.pos.x + rayCastInfo.normal.x * offs,
        rayCastInfo.pos.y + rayCastInfo.normal.y * offs,
        rayCastInfo.pos.z + rayCastInfo.normal.z * offs)
        finalPos = worldEditorCppApi.snapPositionToGrid(finalPos)
        obj:setPosition(finalPos)
    end
  end

  if rayCastInfo then
    if not placeAtCameraPos then
      local pos = vec3(worldEditorCppApi.snapPositionToGrid(rayCastInfo.pos))
      debugDrawer:drawLine((pos - vec3(2, 0, 0)), (pos + vec3(2, 0, 0)), ColorF(1, 0, 0, 1))
      debugDrawer:drawLine((pos - vec3(0, 2, 0)), (pos + vec3(0, 2, 0)), ColorF(0, 1, 0, 1))
      debugDrawer:drawLine((pos - vec3(0, 0, 2)), (pos + vec3(0, 0, 2)), ColorF(0, 0, 1, 1))
    else
      local pos = vec3(getCamera():getPosition()) + vec3(getCameraForward():normalized())
      debugDrawer:drawTextAdvanced(pos, "CLICK ANYWHERE TO CREATE AT CAMERA", ColorF(1, 1, 1, 1), true, false, ColorI(100, 100, 155, 255), false, false)
    end
  end

  if not editor.getPreference("createObjectTool.general.infiniteCreateByClick") and activeWhileHoldingCtrl and not editor.keyModifiers.ctrl then
    activeWhileHoldingCtrl = false
    editor.stopCreatingObjects()
  end
end

--- Create a class object under selected scene tree node.
-- @param clsName object class name
-- @param parentNode scene tree parent node (optional, defaults to current selected node)
-- @returns created object instance
local function createCustomClassObject(clsName, parentNode)
  local obj = worldEditorCppApi.createObject(clsName)
  if obj then
    obj = Sim.upcast(obj)
    if obj then
      extensions.hook("onEditorCustomClassBuildFunc", obj)
      -- now we can register it (will call onAdd)
      local newName = getNextNumberedName(clsName)
      obj:registerObject(newName)
      local parent = parentNode or getCurrentSelectedParent()
      if parent then
        parent:addObject(obj)
      end
    end
  end
  return obj
end

local focusTextInput
local resetScrollY = true
local selectedButtonListIndex = 1
local searchChanged

local function drawTextFilter()
  -- This is a little hack because SetKeyboardFocusHere() doesnt work when you call it only once.
  -- We call it, until the text input has focus
  if focusTextInput then
    imgui.SetKeyboardFocusHere()
  end

  if imgui.InputText("##searchObjectClass", simObjectClassNameFilter, nil, imgui.InputTextFlags_AutoSelectAll) then
    resetScrollY = true
    selectedButtonListIndex = 1
    searchChanged = true
  end

  if (imgui.IsItemActive()) then
    focusTextInput = false
  end

  imgui.SameLine()
  if editor.uiIconImageButton(editor.icons.close, imgui.ImVec2(22, 22)) then
    ffi.copy(simObjectClassNameFilter, "")
  end
  imgui.tooltip("Clear Filter")
end

local classSelected = false
local function selectClass()
  classSelected = true
end

local numberOfButtons
local function navigateList(up)
  if selectedButtonListIndex then
    if up then
      selectedButtonListIndex = math.max(selectedButtonListIndex - 1, 1)
    else
      selectedButtonListIndex = math.min(selectedButtonListIndex + 1, numberOfButtons)
    end
  end
end

local searchResults = {}
local popupOpen = false
local function createObjectToolbar()
  popupOpen = false
  -- show the toolbar buttons for the class groups
  for i, item in ipairs(createGroups) do
    local bgColor = nil
    if i == createObjectGroupIndex then bgColor = imgui.GetStyleColorVec4(imgui.Col_ButtonActive) end
    if editor.uiIconImageButton(item.icon or editor.icons.stop, nil, nil, nil, bgColor) then
      --Set edit mode to 'createObject', CreateObjectTool can also be open in objectSelect mode.
      editor.selectEditMode(editor.editModes.createObject)
      createObjectGroupIndex = i
    end
    if imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text(item.name) imgui.EndTooltip() end
    if not editor.getPreference("createObjectTool.general.verticalToolbar") then
      imgui.SameLine()
    end
  end

  if not editor.getPreference("createObjectTool.general.verticalToolbar") then
    editor.uiVertSeparator(editor.getPreference("ui.general.iconButtonSize"), imgui.ImVec2(0, 0))
    imgui.SameLine()
  else
    imgui.Separator()
  end
  imgui.Spacing()

  if not editor.getPreference("createObjectTool.general.verticalToolbar") then
    imgui.SameLine()
  end

  -- if the current class group is the other classes, then we show an UI with list of classes to choose from
  if createGroups[createObjectGroupIndex].objectClasses.otherClasses == true then
    local btnText
    if currentCustomClassName then
      btnText = "Class: " .. currentCustomClassName
    else
      btnText = "Class: <Click to Select a Class>"
    end
    if imgui.Button(btnText) then
      imgui.OpenPopup("CreateSimObjectPopup")
      focusTextInput = true
    end
    if imgui.IsItemHovered() then
      imgui.SetTooltip("Click to select a SimObject derived class")
    end
    imgui.SameLine()
    if imgui.BeginPopup("CreateSimObjectPopup") then
      popupOpen = true
      pushActionMapHighestPriority("CreateObjectTool")

      drawTextFilter()
      if ffi.string(simObjectClassNameFilter) == '' then
        searchResults = allClassesSearchResults
      else
        if searchChanged then
          simObjectSearch:startSearch(ffi.string(simObjectClassNameFilter))
          for i, clsName in ipairs(simObjectClassNames) do
            simObjectSearch:queryElement({
              name = clsName,
              score = 1,
              frecencyId = clsName
            })
          end
          searchResults = simObjectSearch:finishSearch()
          searchChanged = nil
        end
      end
      numberOfButtons = #searchResults

      imgui.BeginChild1("SimObjectClassNames", filteredFieldPopupSize)
      if resetScrollY then
        imgui.SetScrollY(0)
        resetScrollY = false
      end

      for i, result in ipairs(searchResults) do
        local isSelected = i == selectedButtonListIndex
        if imgui.Selectable1(result.name, isSelected) or classSelected and selectedButtonListIndex == i then
          simObjectSearch:updateFrecencyEntry(result.name)
          imgui.CloseCurrentPopup()
          currentCustomClassName = result.name
          classSelected = false
          editor.setPreference("createObjectTool.general.classFrecency", simObjectSearch:getFrecencyData())
        end
        --TODO: maybe something better for longer strings not fitting in the popup width
        if imgui.IsItemHovered() and string.len(result.name) >= tooltipLongTextLength then
          imgui.SetTooltip(result.name)
        end
        if isSelected then
          -- set the initial focus when opening the combo
          imgui.SetItemDefaultFocus()
        end
      end
      imgui.EndChild()
      imgui.EndPopup()
      imgui.SameLine()
    end

    if imgui.Button("Create") then
      --  Creates object under current selected node in scenetree
      local obj = createCustomClassObject(currentCustomClassName)
      --  Selects created object
      if obj then editor.selectObjectById(obj:getId()) end
    end
    if imgui.IsItemHovered() then
      imgui.SetTooltip("Create the class instance in the currently selected folder or object's parent folder")
    end
  else
    -- else we show a button for each class instance we can create
    for i, item in ipairs(createGroups[createObjectGroupIndex].objectClasses) do
      local bgColor = nil

      if item == currentCreateObjectItem then bgColor = imgui.GetStyleColorVec4(imgui.Col_ButtonActive) end
      if editor.uiIconImageButton(item.icon or editor.icons.stop, nil, nil, nil, bgColor) then
        --Set edit mode to 'createObject', CreateObjectTool can also be open in objectSelect mode.
        editor.selectEditMode(editor.editModes.createObject)

        -- delete the old instance if any, if we were hovering it in the viewport
        if currentClassInstance then
          if currentClassInstance:getGroup() then
            currentClassInstance:getGroup():removeObject(currentClassInstance)
          end
          currentClassInstance:delete()
          currentClassInstance = nil
        end
        currentCreateObjectItem = item

        local obj = worldEditorCppApi.createObject(item.classname)

        if obj then
          currentClassInstance = Sim.upcast(obj)
        end

        editor.setDirty()

        if currentClassInstance then
          local newName = getNextNumberedName(item.classname)
          if item.buildFunc then
            item.buildFunc(currentClassInstance)
          end
          currentClassInstance:registerObject(newName)
          if currentClassInstance.disableCollision then
            currentClassInstance:disableCollision()
          end
          currentParent = getCurrentSelectedParent()
          editor.selectObjectById(currentClassInstance:getID())
          -- do not repeat instance creation with mouse click in the scene, if this is not a
          -- scene object, for example groups, or single instance is true, thus create only when toolbar button pressed
          if not currentClassInstance:isSubClassOf("SceneObject") or item.singleInstance then
            if currentClassInstance.enableCollision then
              currentClassInstance:enableCollision()
            end
            editor.history:commitAction("CreateObject", {classname = item.classname, name = newName, objectID = currentClassInstance:getID()}, createObjectUndo, createObjectRedo, true)

            objectIdToSelect = currentClassInstance:getID()
            currentClassInstance = nil
            currentCreateObjectItem = nil
          end
        end
      end

      if imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text(item.title) imgui.EndTooltip() end
      if not editor.getPreference("createObjectTool.general.verticalToolbar") then
        imgui.SameLine()
      end
    end
  end
  if objectIdToSelect then
    -- Don't change mode after object creation to keep toolbar
    if editor.editMode ~= editor.editModes.createObject then
      editor.selectEditMode(editor.editModes.objectSelect)
    end
    editor.selectObjectById(objectIdToSelect)
    objectIdToSelect = nil
  end
end

local function buildPlayerDropPoint(obj)
  obj:setField("dataBlock", 0, "SpawnSphereMarker")
  obj:setField("radius", 0, "1")
  obj:setField("sphereWeight", 0, "1")
  obj:setField("spawnClass", 0, "Player")
  obj:setField("spawnDatablock", 0, "")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(), "dataBlock", 0, "SpawnSphereMarker")
  registerBuildFuncField(obj:getClassName(), "radius", 0, "1")
  registerBuildFuncField(obj:getClassName(), "sphereWeight", 0, "1")
  registerBuildFuncField(obj:getClassName(), "spawnClass", 0, "Player")
  registerBuildFuncField(obj:getClassName(), "spawnDatablock", 0, "")

  local grp = scenetree.findObject("PlayerDropPoints")

  if not grp then
    grp = worldEditorCppApi.createObject("SimGroup")
    grp:registerObject("")
    grp:setName("PlayerDropPoints")
    scenetree.MissionGroup:add(grp)
  end
  editor.selectObjectById(grp:getID())

  return true
end

local function buildObserverDropPoint(obj)
  obj:setField("dataBlock", 0, "SpawnSphereMarker")
  obj:setField("radius", 0, "1")
  obj:setField("sphereWeight", 0, "1")
  obj:setField("spawnClass", 0, "Camera")
  obj:setField("spawnDatablock", 0, "Observer")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(), "dataBlock", 0, "SpawnSphereMarker")
  registerBuildFuncField(obj:getClassName(), "radius", 0, "1")
  registerBuildFuncField(obj:getClassName(), "sphereWeight", 0, "1")
  registerBuildFuncField(obj:getClassName(), "spawnClass", 0, "Camera")
  registerBuildFuncField(obj:getClassName(), "spawnDatablock", 0, "Observer")

  local grp = scenetree.findObject("ObserverDropPoints")

  if not grp then
    grp = worldEditorCppApi.createObject("SimGroup")
    grp:registerObject("")
    grp:setName("ObserverDropPoints")
    scenetree.MissionGroup:add(grp)
  end
  editor.selectObjectById(grp:getID())
  return true
end

local function buildBeamNGVehicle(obj)
  obj:setField("JBeam", 0, "pickup")
  obj:setField("dataBlock", 0, "default_vehicle")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(), "JBeam", 0, "pickup")
  registerBuildFuncField(obj:getClassName(), "dataBlock", 0, "default_vehicle")

  return true
end

local function buildBeamNGTrigger(obj)
  return true
end

local function buildBeamNGParking(obj)
  return true
end

local function buildBeamNGBooster(obj)
  return true
end

local function buildBeamNGWaypoint(obj)
  return true
end

local function buildBeamNGEnvTrigger(obj)
  return true
end

local function buildBeamNGPointOfInterest(obj)
  return true
end

local function buildBeamNGGameplayArea(obj)
  return true
end

local function buildLevelInfo(obj)
  --TODO: check if already exists, show error, delete object
  obj:setName("theLevelInfo");
  return true
end

local function buildTimeOfDay(obj)
  --TODO: check if already exists, show error, delete object
  return true
end

local function buildCloudLayer(obj)
  obj:setField("texture", 0, "art/skies/clouds/clouds_normal_displacement")
  clearBuildFuncFields(obj:getClassName())
  registerBuildFuncField(obj:getClassName(), "texture", 0, "art/skies/clouds/clouds_normal_displacement")
  return true
end

local function buildBasicClouds(obj)
  obj:setField("texture", 0, "art/skies/clouds/cloud1")
  obj:setField("texture", 1, "art/skies/clouds/cloud2")
  obj:setField("texture", 2, "art/skies/clouds/cloud3")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(), "texture", 0, "art/skies/clouds/cloud1")
  registerBuildFuncField(obj:getClassName(), "texture", 1, "art/skies/clouds/cloud2")
  registerBuildFuncField(obj:getClassName(), "texture", 2, "art/skies/clouds/cloud3")
  return true
end

local function buildScatterSky(obj)
  obj:setField("rayleighScattering", 0, "0.0035")
  obj:setField("mieScattering", 0, "0.0045")
  obj:setField("skyBrightness", 0, "25")
  obj:setField("flareType", 0, "ScatterSkyFlareExample")
  obj:setField("moonMat", 0, "Moon_Glow_Mat")
  obj:setField("nightCubemap", 0, "NightCubemap" )
  obj:setField("useNightCubemap", 0, "true")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(), "rayleighScattering", 0, "0.0035")
  registerBuildFuncField(obj:getClassName(), "mieScattering", 0, "0.0045")
  registerBuildFuncField(obj:getClassName(), "skyBrightness", 0, "25")
  registerBuildFuncField(obj:getClassName(), "flareType", 0, "ScatterSkyFlareExample")
  registerBuildFuncField(obj:getClassName(), "moonMat", 0, "Moon_Glow_Mat")
  registerBuildFuncField(obj:getClassName(), "nightCubemap", 0, "NightCubemap")
  registerBuildFuncField(obj:getClassName(), "useNightCubemap", 0, "true")
  return true
end

local function buildSun(obj)
  obj:setField("direction", 0, "1 1 -1")
  obj:setField("color", 0, "0.8 0.8 0.8")
  obj:setField("ambient", 0, "0.2 0.2 0.2")
  obj:setField("coronaMaterial", 0, "Corona_Mat")
  obj:setField("flareType", 0, "SunFlareExample")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(),"direction", 0, "1 1 -1")
  registerBuildFuncField(obj:getClassName(),"color", 0, "0.8 0.8 0.8")
  registerBuildFuncField(obj:getClassName(),"ambient", 0, "0.2 0.2 0.2")
  registerBuildFuncField(obj:getClassName(),"coronaMaterial", 0, "Corona_Mat")
  registerBuildFuncField(obj:getClassName(),"flareType", 0, "SunFlareExample")
  return true
end

local function buildLightning(obj)
  obj:setField("dataBlock", 0, "DefaultStorm")
  clearBuildFuncFields(obj:getClassName())
  registerBuildFuncField(obj:getClassName(), "dataBlock", 0, "DefaultStorm")
  return true
end

local function buildWaterBlock(obj)
  obj:setField("baseColor", 0, "45 108 171 255")
  obj:setField("rippleDir", 0, "0.000000 1.000000")
  obj:setField("rippleDir", 1, "0.707000 0.707000")
  obj:setField("rippleDir", 2, "0.500000 0.860000")
  obj:setField("rippleTexScale", 0, "7.140000 7.140000")
  obj:setField("rippleTexScale", 1, "6.250000 12.500000")
  obj:setField("rippleTexScale", 2, "50.000000 50.000000")
  obj:setField("rippleSpeed", 0, "0.065")
  obj:setField("rippleSpeed", 1, "0.09")
  obj:setField("rippleSpeed", 2, "0.04")
  obj:setField("rippleMagnitude", 0, "1.0")
  obj:setField("rippleMagnitude", 1, "1.0")
  obj:setField("rippleMagnitude", 2, "0.3")
  obj:setField("overallRippleMagnitude", 0, "1.0")

  obj:setField("waveDir", 0, "0.000000 1.000000")
  obj:setField("waveDir", 1, "0.707000 0.707000")
  obj:setField("waveDir", 2, "0.500000 0.860000")
  obj:setField("waveMagnitude", 0, "0.2")
  obj:setField("waveMagnitude", 1, "0.2")
  obj:setField("waveMagnitude", 2, "0.2")
  obj:setField("waveSpeed", 0, "1")
  obj:setField("waveSpeed", 1, "1")
  obj:setField("waveSpeed", 2, "1")
  obj:setField("overallWaveMagnitude", 0, "1.0")

  obj:setField("rippleTex", 0, "core/art/water/ripple")
  obj:setField("depthGradientTex", 0, "core/art/water/depthcolor_ramp")
  obj:setField("foamTex", 0, "core/art/water/foam")
  obj:setField("cubemap", 0, "DefaultSkyCubemap")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(),"baseColor", 0, "45 108 171 255")
  registerBuildFuncField(obj:getClassName(),"rippleDir", 0, "0.000000 1.000000")
  registerBuildFuncField(obj:getClassName(),"rippleDir", 1, "0.707000 0.707000")
  registerBuildFuncField(obj:getClassName(),"rippleDir", 2, "0.500000 0.860000")
  registerBuildFuncField(obj:getClassName(),"rippleTexScale", 0, "7.140000 7.140000")
  registerBuildFuncField(obj:getClassName(),"rippleTexScale", 1, "6.250000 12.500000")
  registerBuildFuncField(obj:getClassName(),"rippleTexScale", 2, "50.000000 50.000000")
  registerBuildFuncField(obj:getClassName(),"rippleSpeed", 0, "0.065")
  registerBuildFuncField(obj:getClassName(),"rippleSpeed", 1, "0.09")
  registerBuildFuncField(obj:getClassName(),"rippleSpeed", 2, "0.04")
  registerBuildFuncField(obj:getClassName(),"rippleMagnitude", 0, "1.0")
  registerBuildFuncField(obj:getClassName(),"rippleMagnitude", 1, "1.0")
  registerBuildFuncField(obj:getClassName(),"rippleMagnitude", 2, "0.3")
  registerBuildFuncField(obj:getClassName(),"overallRippleMagnitude", 0, "1.0")

  registerBuildFuncField(obj:getClassName(),"waveDir", 0, "0.000000 1.000000")
  registerBuildFuncField(obj:getClassName(),"waveDir", 1, "0.707000 0.707000")
  registerBuildFuncField(obj:getClassName(),"waveDir", 2, "0.500000 0.860000")
  registerBuildFuncField(obj:getClassName(),"waveMagnitude", 0, "0.2")
  registerBuildFuncField(obj:getClassName(),"waveMagnitude", 1, "0.2")
  registerBuildFuncField(obj:getClassName(),"waveMagnitude", 2, "0.2")
  registerBuildFuncField(obj:getClassName(),"waveSpeed", 0, "1")
  registerBuildFuncField(obj:getClassName(),"waveSpeed", 1, "1")
  registerBuildFuncField(obj:getClassName(),"waveSpeed", 2, "1")
  registerBuildFuncField(obj:getClassName(),"overallWaveMagnitude", 0, "1.0")

  registerBuildFuncField(obj:getClassName(),"rippleTex", 0, "core/art/water/ripple")
  registerBuildFuncField(obj:getClassName(),"depthGradientTex", 0, "core/art/water/depthcolor_ramp")
  registerBuildFuncField(obj:getClassName(),"foamTex", 0, "core/art/water/foam")
  registerBuildFuncField(obj:getClassName(),"cubemap", 0, "DefaultSkyCubemap")

  obj:reloadTextures()
  return true
end

local function buildWaterPlane(obj)
  obj:setField("baseColor", 0, "45 108 171 255")
  obj:setField("rippleDir", 0, "0.000000 1.000000")
  obj:setField("rippleDir", 1, "0.707000 0.707000")
  obj:setField("rippleDir", 2, "0.500000 0.860000")
  obj:setField("rippleTexScale", 0, "7.140000 7.140000")
  obj:setField("rippleTexScale", 1, "6.250000 12.500000")
  obj:setField("rippleTexScale", 2, "50.000000 50.000000")
  obj:setField("rippleSpeed", 0, "0.065")
  obj:setField("rippleSpeed", 1, "0.09")
  obj:setField("rippleSpeed", 2, "0.04")
  obj:setField("rippleMagnitude", 0, "1.0")
  obj:setField("rippleMagnitude", 1, "1.0")
  obj:setField("rippleMagnitude", 2, "0.3")
  obj:setField("overallRippleMagnitude", 0, "1.0")

  obj:setField("waveDir", 0, "0.000000 1.000000")
  obj:setField("waveDir", 1, "0.707000 0.707000")
  obj:setField("waveDir", 2, "0.500000 0.860000")
  obj:setField("waveMagnitude", 0, "0.2")
  obj:setField("waveMagnitude", 1, "0.2")
  obj:setField("waveMagnitude", 2, "0.2")
  obj:setField("waveSpeed", 0, "1")
  obj:setField("waveSpeed", 1, "1")
  obj:setField("waveSpeed", 2, "1")
  obj:setField("overallWaveMagnitude", 0, "1.0")

  obj:setField("rippleTex", 0, "core/art/water/ripple")
  obj:setField("depthGradientTex", 0, "core/art/water/depthcolor_ramp")
  obj:setField("foamTex", 0, "core/art/water/foam")
  obj:setField("cubemap", 0, "DefaultSkyCubemap")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(),"baseColor", 0, "45 108 171 255")
  registerBuildFuncField(obj:getClassName(),"rippleDir", 0, "0.000000 1.000000")
  registerBuildFuncField(obj:getClassName(),"rippleDir", 1, "0.707000 0.707000")
  registerBuildFuncField(obj:getClassName(),"rippleDir", 2, "0.500000 0.860000")
  registerBuildFuncField(obj:getClassName(),"rippleTexScale", 0, "7.140000 7.140000")
  registerBuildFuncField(obj:getClassName(),"rippleTexScale", 1, "6.250000 12.500000")
  registerBuildFuncField(obj:getClassName(),"rippleTexScale", 2, "50.000000 50.000000")
  registerBuildFuncField(obj:getClassName(),"rippleSpeed", 0, "0.065")
  registerBuildFuncField(obj:getClassName(),"rippleSpeed", 1, "0.09")
  registerBuildFuncField(obj:getClassName(),"rippleSpeed", 2, "0.04")
  registerBuildFuncField(obj:getClassName(),"rippleMagnitude", 0, "1.0")
  registerBuildFuncField(obj:getClassName(),"rippleMagnitude", 1, "1.0")
  registerBuildFuncField(obj:getClassName(),"rippleMagnitude", 2, "0.3")
  registerBuildFuncField(obj:getClassName(),"overallRippleMagnitude", 0, "1.0")

  registerBuildFuncField(obj:getClassName(),"waveDir", 0, "0.000000 1.000000")
  registerBuildFuncField(obj:getClassName(),"waveDir", 1, "0.707000 0.707000")
  registerBuildFuncField(obj:getClassName(),"waveDir", 2, "0.500000 0.860000")
  registerBuildFuncField(obj:getClassName(),"waveMagnitude", 0, "0.2")
  registerBuildFuncField(obj:getClassName(),"waveMagnitude", 1, "0.2")
  registerBuildFuncField(obj:getClassName(),"waveMagnitude", 2, "0.2")
  registerBuildFuncField(obj:getClassName(),"waveSpeed", 0, "1")
  registerBuildFuncField(obj:getClassName(),"waveSpeed", 1, "1")
  registerBuildFuncField(obj:getClassName(),"waveSpeed", 2, "1")
  registerBuildFuncField(obj:getClassName(),"overallWaveMagnitude", 0, "1.0")

  registerBuildFuncField(obj:getClassName(),"rippleTex", 0, "core/art/water/ripple")
  registerBuildFuncField(obj:getClassName(),"depthGradientTex", 0, "core/art/water/depthcolor_ramp")
  registerBuildFuncField(obj:getClassName(),"foamTex", 0, "core/art/water/foam")
  registerBuildFuncField(obj:getClassName(),"cubemap", 0, "DefaultSkyCubemap")

  obj:reloadTextures()
  return true
end

local function buildPrecipitation(obj)
  obj:setField("dataBlock", 0, "rain_drop")
  clearBuildFuncFields(obj:getClassName())
  registerBuildFuncField(obj:getClassName(), "dataBlock", 0, "rain_drop")
  return true
end

local function buildTerrainBlock(obj)
  obj:setField("squareSize", 0, "8")
  clearBuildFuncFields(obj:getClassName())
  registerBuildFuncField(obj:getClassName(), "squareSize", 0, "8")
  if editor_terrainEditor then
    editor.log("Updating terrain block list...")
    editor_terrainEditor.updateTerrainBlockProxies()
  end
  obj:setTerrFileLvlFolder("/levels/".. (true and getCurrentLevelIdentifier() or "") )
  return true
end

local function buildParticleEmitter(obj)
  obj:setField("dataBlock", 0, "lightExampleEmitterNodeData1")
  obj:setField("emitter", 0, "BNGP_1")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(), "dataBlock", 0, "lightExampleEmitterNodeData1")
  registerBuildFuncField(obj:getClassName(), "emitter", 0, "BNGP_1")
  obj:setEmitterDataBlock(scenetree.findObject("BNGP_1"))
  return true
end

local function buildLight(obj)
  return true
end

local function buildGroundCover(obj)
  obj:setField("material", 0, "BNGGrass_3")
  obj:setField("probability", 0, "1")

  clearBuildFuncFields(obj:getClassName())

  registerBuildFuncField(obj:getClassName(), "material", 0, "BNGGrass_3")
  registerBuildFuncField(obj:getClassName(), "probability", 0, "1")
  return true
end

local function buildCamera(obj)
  obj:setField("dataBlock", 0, "Observer")
  return true
end

local function makeCreateObjectGroupItem(name, icon)
  return {
    name = name,
    icon = icon
  }
end

--- Prepare a create object item for the toolbar. Used as a helper when creating the array for the new group.
-- @param icon the icon for the create object button
-- @param classname the C++ classname for the create object button, to create the instance for
-- @param title the display name for the class
-- @param buildFunc the function to be called right before the instance is created, so you can setup the object
-- @param singleInstance true if this button will create a single instance on click, otherwise if false, you create instances by clicking in the 3D viewport until ESCAPE is pressed
local function makeCreateObjectItem(icon, classname, title, buildFunc, singleInstance)
  return {
    icon = icon,
    classname = classname,
    title = title or classname,
    buildFunc = buildFunc,
    singleInstance = singleInstance
  }
end

--- Add a new create objects group button to the create toolbar.
-- @param name the name of the custom create group
-- @param icon the icon for this group's button (in the form of: ``editor.icons.some_icon_name_here``)
-- @param objectClasses an array of object class info tables to create the buttons in this group, the info table for a class can be created with the `editor.makeCreateObjectItem` function
local function addObjectCreateGroup(name, icon, objectClasses)
  local grp = makeCreateObjectGroupItem(name, icon)
  grp.objectClasses = objectClasses
  table.insert(createGroups, grp)
end

--- Return a create group info table by group name.
-- @param name the name of the create group
-- @returns the create group
local function getObjectCreateGroup(name)
  for _, grp in ipairs(createGroups) do
    if grp.name == name then return grp end
  end
end

local function onEditorInitialized()
  editor.editModes.createObject =
  {
    displayName = "Create Object(s)",
    onDeactivate = createObjectModeDeactivate,
    onUpdate = createObjectModeUpdate,
    onToolbar = createObjectToolbar,
    actionMap = "CreatingObjects",
    icon = editor.icons.add_circle,
    iconTooltip = "Create Object",
    toolbarAlwaysVisible = false
  }

  editor.stopCreatingObjects = function()
    editor.clearObjectSelection()
    createObjectModeDeactivate()
    -- Clears always visible toolbars on create mode end
    editor.editModes.createObject["toolbarAlwaysVisible"] = false
    -- Goes back to select mode
    editor.selectEditMode(editor.editModes.objectSelect)
    if lastInstance ~= nil then
      editor.selectObjectById(lastInstance:getID())
    end
  end

  editor.togglePlaceNewObjectAtCamera = function ()
    placeAtCameraPos = not placeAtCameraPos
  end

  simObjectSearch:setFrecencyData(editor.getPreference("createObjectTool.general.classFrecency"))

  createGroups = {
    makeCreateObjectGroupItem("Environment", editor.icons.create_env_object),
    makeCreateObjectGroupItem("Level", editor.icons.create_level_object),
    makeCreateObjectGroupItem("BeamNG", editor.icons.create_beamng_object),
    makeCreateObjectGroupItem("Other Classes", editor.icons.playlist_add)
  }

  -- Environment classes
  createGroups[1].objectClasses = {
    -- icon, class name, title, buildFunc
    makeCreateObjectItem(editor.icons.simobject_skybox, "SkyBox", "Sky Box", nil, true),
    makeCreateObjectItem(editor.icons.simobject_cloud_layer, "CloudLayer", "Cloud Layer", buildCloudLayer, true),
    makeCreateObjectItem(editor.icons.simobject_basic_clouds, "BasicClouds", "Basic Clouds", buildBasicClouds, true),
    makeCreateObjectItem(editor.icons.simobject_scatter_sky, "ScatterSky", "Scatter Sky", buildScatterSky, true),
    makeCreateObjectItem(editor.icons.simobject_sun, "Sun", "Basic Sun", buildSun, true),
    --TODO: not exists? makeCreateObjectItem(editor.icons.simobject_lightning, "Lightning", "Lightning", buildLightning, true),
    makeCreateObjectItem(editor.icons.simobject_waterblock, "WaterBlock", "Water Block", buildWaterBlock),
    makeCreateObjectItem(editor.icons.simobject_sfxemitter, "SFXEmitter", "Sound Emitter"),
    makeCreateObjectItem(editor.icons.simobject_sfxspace, "SFXSpace", "Sound Space"),
    makeCreateObjectItem(editor.icons.simobject_precipitation, "Precipitation", "Precipitation", buildPrecipitation),
    makeCreateObjectItem(editor.icons.simobject_particle_emitter_node, "ParticleEmitterNode", "Particle Emitter", buildParticleEmitter),
    makeCreateObjectItem(editor.icons.simobject_pointlight, "PointLight", "Point Light", buildLight),
    makeCreateObjectItem(editor.icons.simobject_spotlight, "SpotLight", "Spot Light"),
    makeCreateObjectItem(editor.icons.simobject_groundcover, "GroundCover", "Ground Cover", buildGroundCover),
    makeCreateObjectItem(editor.icons.simobject_terrainblock, "TerrainBlock", "Terrain Block", buildTerrainBlock),
    makeCreateObjectItem(editor.icons.simobject_groundplane, "GroundPlane", "Ground Plane"),
    makeCreateObjectItem(editor.icons.simobject_waterplane, "WaterPlane", "Water Plane", buildWaterPlane),
  }

  -- Level classes
  createGroups[2].objectClasses = {
    -- icon, class name, title, buildFunc, singleInstance (boolean, if true create instance only when toolbar button is pressed)
    makeCreateObjectItem(editor.icons.folder, "SimGroup", "Group", nil, true),
    makeCreateObjectItem(editor.icons.simobject_camera, "Camera", nil, buildCamera),
    makeCreateObjectItem(editor.icons.simobject_levelinfo, "LevelInfo", "Level Info", buildLevelInfo, true),
    makeCreateObjectItem(editor.icons.simobject_timeofday, "TimeOfDay", "Time of Day", nil, true),
    makeCreateObjectItem(editor.icons.simobject_zone, "Zone"),
    makeCreateObjectItem(editor.icons.simobject_portal, "Portal", "Zone Portal"),
    makeCreateObjectItem(editor.icons.simobject_player_spawn_sphere, "SpawnSphere", "Player Spawn Sphere", buildPlayerDropPoint),
    makeCreateObjectItem(editor.icons.simobject_observer_spawn_sphere, "SpawnSphere", "Observer Spawn Sphere", buildObserverDropPoint),
    makeCreateObjectItem(editor.icons.simobject_occlusion_volume, "OcclusionVolume", "Occlusion Volume")
  }

  -- BeamNG classes
  createGroups[3].objectClasses = {
    -- icon, class name, title, buildFunc
    --TODO crashes: makeCreateObjectItem(editor.icons.simobject_bng_vehicle, "BeamNGVehicle", "Vehicle", buildBeamNGVehicle),
    makeCreateObjectItem(editor.icons.simobject_bng_trigger, "BeamNGTrigger", "Lua Trigger", buildBeamNGTrigger),
    makeCreateObjectItem(editor.icons.simobject_bng_booster, "BeamNGBooster", "Booster", buildBeamNGBooster),
    makeCreateObjectItem(editor.icons.simobject_bng_parking, "BeamNGParking", "Parking space", buildBeamNGParking),
    makeCreateObjectItem(editor.icons.simobject_bng_waypoint, "BeamNGWaypoint", "Waypoint", buildBeamNGWaypoint),
    makeCreateObjectItem(editor.icons.simobject_bng_env_trigger, "BeamNGEnvTrigger", "Environment Trigger", buildBeamNGEnvTrigger),
    makeCreateObjectItem(editor.icons.add_location, "BeamNGPointOfInterest", "Point of Interest", buildBeamNGPointOfInterest),
    makeCreateObjectItem(editor.icons.simobject_bng_gameplay_area, "BeamNGGameplayArea", "Gameplay Area", buildBeamNGGameplayArea)
  }

  -- other classes
  createGroups[4].objectClasses = {otherClasses = true}

  editor.addObjectCreateGroup = addObjectCreateGroup
  editor.getObjectCreateGroup = getObjectCreateGroup
  editor.makeCreateObjectItem = makeCreateObjectItem
  editor.getCurrentSelectedParent = getCurrentSelectedParent
  editor.createCustomClassObject = createCustomClassObject

  simObjectClassNames = Sim.getSimObjectDerivedClassNames()
  allClassesSearchResults = {}

  for i, className in ipairs(simObjectClassNames) do
    allClassesSearchResults[i] = {name = className}
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("createObjectTool")
  prefsRegistry:registerSubCategory("createObjectTool", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {infiniteCreateByClick = {"bool", true, "Create new objects by clicking locations in the scene, end by pressing ESC key"}},
    {verticalToolbar = {"bool", false, "Use vertical Create Object toolbar"}},
    {classFrecency = {"table", {}, "", nil, nil, nil, true, nil}}
  })
end

local function onEditorDeactivated()
  popActionMap("CreateObjectTool")
end

local function onEditorGui()
  if not popupOpen then
    popActionMap("CreateObjectTool")
  end
end

M.onEditorInitialized = onEditorInitialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorDeactivated = onEditorDeactivated
M.onEditorGui = onEditorGui
M.selectClass = selectClass
M.navigateList = navigateList

return M