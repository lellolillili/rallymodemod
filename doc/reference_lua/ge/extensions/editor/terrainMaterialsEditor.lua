 -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = ui_imgui
local imUtils = require("ui/imguiUtils")

local terrainMaterialTextureSetPath = "art/terrains/main.materials.json"

local terrainMaterialEditorWindowName = "terrainMaterialEditor"
local materialEditorWindowSize = nil
local materialEditorMapThumbnailSize = im.ImVec2(48,48)
local terrainMtlProxy
local terrainMtlCopyProxy
local fontSize

local NotificationState_Ok = 0
local NotificationState_ErrorMtlNameFirstCharIsNumber = 1
local NotificationState_ErrorMtlNameIsEmpty = 2
local notificationState = 0 -- 0: all good, 1: mat name's first char must not be a number, 2: material name must not be empty

local terrainMaterialTextureSetProperties = {
  {property = "baseTexSize", name = "Base Texture Size", tooltip = "Sets the expected dimensions of textures used in this slot (must match texture dimensions)"},
  {property = "macroTexSize", name = "Macro Texture Size", tooltip = "Sets the expected dimensions of textures used in this slot (must match texture dimensions)"},
  {property = "detailTexSize", name = "Detail Texture Size", tooltip = "Sets the expected dimensions of textures used in this slot (must match texture dimensions)"}
}

if not scenetree.terrainMatEditor_PersistMan then
  local persistenceMgr = PersistenceManager()
  persistenceMgr:registerObject('terrainMatEditor_PersistMan')
end

local v1MaterialTextureSetMaps = {
  {title = "Base Color", mapIdentifier = "baseColor", defaultOpen = true},
  {title = "Normal", mapIdentifier = "normal", defaultOpen = false},
  {title = "Roughness", mapIdentifier = "roughness", defaultOpen = false},
  {title = "Ambient Occlusio", mapIdentifier = "ao", defaultOpen = false},
  {title = "Height", mapIdentifier = "height", defaultOpen = false},
}

local bulkChange = {
  file = nil,
  name = nil,
  map = nil,
  ext = nil,
  textures = nil
}

local upgradeFileFormatMaterials = {}

local function setProperty(propertyName, value, obj)
  obj = obj or terrainMtlCopyProxy.material
  obj:setField(propertyName, 0, value)
end

local function propertyUndo(actionData)
  local obj = scenetree.findObjectById(actionData.objectId)
  if obj then
    if type(actionData.property) == "table" then
      if type(actionData.oldValue) == "table" then
        for k, prop in ipairs(actionData.property) do
          setProperty(prop, actionData.oldValue[k], obj)
        end
      else
        for k, prop in ipairs(actionData.property) do
          setProperty(prop, actionData.oldValue, obj)
        end
      end
      return
    end
    setProperty(actionData.property, actionData.oldValue, obj)
  end
end

local function propertyRedo(actionData)
  local obj = scenetree.findObjectById(actionData.objectId)
  if obj then
    if type(actionData.property) == "table" then
      if type(actionData.newValue) == "table" then
        for k, prop in ipairs(actionData.property) do
          setProperty(prop, actionData.newValue[k], obj)
        end
      else
        for k, prop in ipairs(actionData.property) do
          setProperty(prop, actionData.newValue, obj)
        end
      end
      return
    end
    setProperty(actionData.property, actionData.newValue, obj)
  end
end

local function setPropertyWithUndo(property, value, undoActionId, obj)
  obj = obj or terrainMtlCopyProxy.material
  local oldValue
  if type(property) == "table" then
    if type(value) == "table" then
      oldValue = {}
      for k,v in ipairs(property) do
        table.insert(oldValue, obj:getField(v, 0))
      end
    else
      oldValue = obj:getField(property[1], 0)
    end
  else
    oldValue = obj:getField(property, 0)
  end

  editor.history:commitAction(
    "SetTerrainMaterialProperty_" .. (undoActionId or property),
    {
      objectId = obj:getId(),
      property = property,
      newValue = value,
      oldValue = oldValue
    },
    propertyUndo,
    propertyRedo
  )
end

local function inputText(label, propertyName, widthMod)
  if label then
    im.TextUnformatted(label)
    im.SameLine()
  end
  im.PushItemWidth(im.GetContentRegionAvailWidth() + (widthMod or 0))
  editor.uiInputText(
    "##" .. propertyName .. tostring(0),
    editor.getTempCharPtr(terrainMtlCopyProxy.material:getField(propertyName, 0)),
    nil,
    im.InputTextFlags_AutoSelectAll,
    nil,
    nil,
    editor.getTempBool_BoolBool(false)
  )
  im.PopItemWidth()

  if editor.getTempBool_BoolBool() == true then
    setPropertyWithUndo(propertyName, editor.getTempCharPtr())
  end
end

local function deleteMapButton(label, propertyName)
  local inputWidgetHeight = math.ceil(im.GetFontSize()) + 2 * im.GetStyle().FramePadding.y
  im.PushID1(propertyName .. '_RemoveMapButton')
  if editor.uiIconImageButton(
    editor.icons.material_texturemap_remove,
    im.ImVec2(inputWidgetHeight, inputWidgetHeight)
  ) then
    setPropertyWithUndo(propertyName, "")
  end
  im.tooltip("Remove " .. label)
  im.PopID()
end

local function widgetTexture(map, property, widgetName)
  local propertyName = string.format(property, map)
  im.TextUnformatted(widgetName)
  if editor.uiButtonRightAlign("Bulk Change Texture", nil, true, "bulkChangeTexture_" .. map .. property) then
    editor_fileDialog.openFile(
      function(data)
        bulkChange = {
          file = data.filepath,
          property = property,
          textures = {}
        }

        local regexRule = "([a-zA-Z0-9_]+)_([a-zA-Z_]+).(%w+)$"

        bulkChange.name, bulkChange.map, bulkChange.ext = string.match(data.filepath, regexRule)

        local filePaths = FS:findFiles(data.path, "*", 0, true, false)
        local files = {}
        for k,v in ipairs(filePaths) do
          local name, map, ext = string.match(v, regexRule)
          local asset = {file = v, name = name, map = map, ext = ext}
          table.insert(files, asset)

          if name == bulkChange.name and ext == bulkChange.ext then
            bulkChange.textures[map] = asset
          end
        end

        editor.openModalWindow("bulkChangeTexturesModal")
      end,
      {{"Any files", "*"},{"Images",{".png"}},{"DDS",".dds"},{"PNG",".png"},{"Color maps",".color.png"}, {"Normal maps",".normal.png"}, {"Data maps",".data.png"}},
      false,
      getMissionPath() .. "art/terrains/",
      true
    )
  end
  im.tooltip("Automatically change all texture paths for a new set according to file name")

  local val = terrainMtlCopyProxy.material:getField(propertyName, 0)
  local texture = editor.getTempTextureObj(val)

  local function openFileDialog()
    editor_fileDialog.openFile(
      function(data)
        if val ~= data.filepath then
          setPropertyWithUndo(propertyName, data.filepath)
        end
      end,
      {{"Any files", "*"},{"Images",{".png", ".dds", ".jpg"}},{"DDS",".dds"},{"PNG",".png"},{"Color maps",".color.png"}, {"Normal maps",".normal.png"}, {"Data maps",".data.png"}},
      false,
      string.match(val, "(.+/).+$") or "/",
      true
    )
  end

  local inputWidgetHeight = math.ceil(im.GetFontSize()) + 2 * im.GetStyle().FramePadding.y

  -- im.TextUnformatted(val)
  inputText("Path", propertyName, -(2 * inputWidgetHeight * im.uiscale[0] + 2 * im.GetStyle().ItemSpacing.x))
  im.SameLine()
  if editor.uiIconImageButton(
    editor.icons.folder,
    im.ImVec2(inputWidgetHeight, inputWidgetHeight)
  ) then
    openFileDialog()
  end
  im.tooltip("Browse for new texture")
  im.SameLine()
  deleteMapButton(widgetName, propertyName)

  local texture = editor.getTempTextureObj(val)
  local size = im.ImVec2(128, 128)

  im.PushID1(propertyName)
  if im.ImageButton(
    texture.texId,
    size,
    im.ImVec2Zero,
    im.ImVec2One,
    1,
    im.ImColorByRGB(255,255,255,255).Value,
    im.ImColorByRGB(255,255,255,255).Value
  ) then
    openFileDialog()
  end
  im.tooltip("Browse for new texture")
  im.PopID()
end

local function widgetFloat(propertyName, widgetName)
  im.TextUnformatted(widgetName)
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if editor.uiInputFloat(
    "##" .. propertyName,
    editor.getTempFloat_StringString(terrainMtlCopyProxy.material:getField(propertyName, 0)),
    float_step or 1,
    float_step_fast or 128,
    string_format or "%.0f",
    nil,
    editor.getTempBool_BoolBool(false)
  ) then
    setProperty(propertyName, editor.getTempFloat_StringString())
  end

  if editor.getTempBool_BoolBool() == true then
    setPropertyWithUndo(propertyName, editor.getTempFloat_StringString())
  end
  im.PopItemWidth()
end

local function widgetTextureSize(map, property, widgetName, tooltip)
  local propertyName = string.format(property, map)
  im.TextUnformatted(widgetName)
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  editor.uiInputFloat(
    "##" .. propertyName,
    editor.getTempFloat_StringString(terrainMtlCopyProxy.material:getField(propertyName, 0)),
    float_step or 1,
    float_step_fast or 128,
    string_format or "%.0f",
    nil,
    editor.getTempBool_BoolBool(false)
  )

  if editor.getPreference("terrainEditor.terrainMaterialLibrary.keepSizeForAllMaps") == true then
    tooltip = (tooltip and (tooltip .. "\n\n") or "") .. "Setting 'keep size for all maps' is enabled.\nIf you change this value, '" .. widgetName .. "' will change for all groups (Base, Normal, Roughness, Ambient Occlusion, Height)."
  end
  if tooltip and im.IsItemHovered() then
    im.BeginTooltip()
    im.PushTextWrapPos(300)
    im.TextUnformatted(tooltip)
    im.PopTextWrapPos()
    im.EndTooltip()
  end

  if editor.getTempBool_BoolBool() == true then
    if editor.getPreference("terrainEditor.terrainMaterialLibrary.keepSizeForAllMaps") == true then
      local properties = {}
      for k,v in ipairs(v1MaterialTextureSetMaps) do
        table.insert(properties, string.format(property, v.mapIdentifier))
      end
      setPropertyWithUndo(properties, editor.getTempFloat_StringString(), property)
    else
      setPropertyWithUndo(propertyName, editor.getTempFloat_StringString())
    end
  end
  im.PopItemWidth()
end

local function widgetFloat2(propertyName, widgetName, obj, format, tooltip)
  obj = obj or terrainMtlCopyProxy.material
  im.TextUnformatted(widgetName)
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  editor.uiInputFloat2(
    "##" .. propertyName,
    editor.getTempFloatArray2_StringString(obj:getField(propertyName, 0)),
    format or "%.2f",
    nil,
    editor.getTempBool_BoolBool(false)
  )
  if tooltip then im.tooltip(tooltip) end

  if editor.getTempBool_BoolBool() == true then
    setPropertyWithUndo(propertyName, editor.getTempFloatArray2_StringString(), nil, obj)
  end
  im.PopItemWidth()
end

local function widgetInt2(propertyName, widgetName, obj, tooltip)
  obj = obj or terrainMtlCopyProxy.material
  im.TextUnformatted(widgetName)
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  editor.uiInputInt2(
    "##" .. propertyName,
    editor.getTempIntArray2_StringString(obj:getField(propertyName, 0)),
    nil,
    editor.getTempBool_BoolBool(false)
  )
  if tooltip then im.tooltip(tooltip) end

  if editor.getTempBool_BoolBool() == true then
    setPropertyWithUndo(propertyName, editor.getTempIntArray2_StringString(), nil, obj)
  end
  im.PopItemWidth()
end

local function widgetDistances(propertyName, widgetName)
  im.TextUnformatted(widgetName)
  local tempBoolPtr = editor.getTempBool_BoolBool(false)

  local floatArr4 = editor.getTempFloatArray4_StringString(terrainMtlCopyProxy.material:getField(propertyName, 0))
  local changed = false

  im.TextUnformatted("Start Fade In")
  local posX = im.GetCursorPosX()
  im.SameLine()
  im.SetCursorPosX(posX + 90)
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if editor.uiInputFloat(
    "##startFadeIn_" .. propertyName,
    editor.getTempFloat_NumberNumber(floatArr4[0]),
    float_step or 1,
    float_step_fast or 128,
    string_format or "%.0f",
    nil,
    tempBoolPtr
  ) then
    changed = true
    floatArr4[0] = editor.getTempFloat_NumberNumber()
  end
  im.PopItemWidth()
  im.tooltip("Distance to begin fading into the Near value")

  im.TextUnformatted("Near")
  im.SameLine()
  im.SetCursorPosX(posX + 90)
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if editor.uiInputFloat(
    "##near_" .. propertyName,
    editor.getTempFloat_NumberNumber(floatArr4[1]),
    float_step or 1,
    float_step_fast or 128,
    string_format or "%.0f",
    nil,
    tempBoolPtr
  ) then
    changed = true
    floatArr4[1] = editor.getTempFloat_NumberNumber()
  end
  im.PopItemWidth()
  im.tooltip("Distance of near value")

  im.TextUnformatted("Far")
  im.SameLine()
  im.SetCursorPosX(posX + 90)
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if editor.uiInputFloat(
    "##far_" .. propertyName,
    editor.getTempFloat_NumberNumber(floatArr4[2]),
    float_step or 1,
    float_step_fast or 128,
    string_format or "%.0f",
    nil,
    tempBoolPtr
  ) then
    changed = true
    floatArr4[2] = editor.getTempFloat_NumberNumber()
  end
  im.PopItemWidth()
  im.tooltip("Distance of far value")

  im.TextUnformatted("End Fade Out")
  im.SameLine()
  im.SetCursorPosX(posX + 90)
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if editor.uiInputFloat(
    "##endFadeOut_" .. propertyName,
    editor.getTempFloat_NumberNumber(floatArr4[3]),
    float_step or 1,
    float_step_fast or 128,
    string_format or "%.0f",
    nil,
    tempBoolPtr
  ) then
    changed = true
    floatArr4[3] = editor.getTempFloat_NumberNumber()
  end
  im.PopItemWidth()
  im.tooltip("Distance where the far value has completed faded")

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(propertyName, editor.getTempFloatArray4_StringString())
  elseif changed == true then
    setPropertyWithUndo(propertyName, editor.getTempFloatArray4_StringString())
  end
end

local function editMaterial(mtlProxy)
  -- if the previous edited material proxy was a newly created material and was not saved, then delete it as it was a temporary material
  if terrainMtlCopyProxy and terrainMtlCopyProxy.material and terrainMtlCopyProxy.isNew then
    terrainMtlCopyProxy.material:deleteObject()
    terrainMtlCopyProxy = nil
  end

  if not mtlProxy then
    -- create a new TerrainMaterial object
    local newName = editor_terrainEditor.getUniqueMtlName("NewMaterial")
    local newMtl = TerrainMaterial()
    newMtl:setInternalName(newName)
    mtlProxy = editor_terrainEditor.createMaterialProxy(-1, newMtl:getOrCreatePersistentID(), newMtl, newName, false, true)
    mtlProxy.isNew = true
    mtlProxy.fileName = editor_terrainEditor.getVars().levelPath .. editor_terrainEditor.getMatFilePath()
    newMtl:setFileName(mtlProxy.fileName)
  end

  terrainMtlProxy = mtlProxy
  terrainMtlCopyProxy = editor_terrainEditor.createMaterialProxy(-1, mtlProxy.persistentId, mtlProxy.material, mtlProxy.internalName)
  terrainMtlCopyProxy = editor_terrainEditor.copyMaterialProxyWithInputs(terrainMtlCopyProxy)
  terrainMtlCopyProxy.isNew = terrainMtlProxy.isNew
  notificationState = NotificationState_Ok
end

local function applyMtlChanges()
  local forbiddenName = false
  local newName = ffi.string(terrainMtlCopyProxy.nameInput)
  -- we have a new name
  if terrainMtlCopyProxy.internalName ~= newName then
    for _, mtl in ipairs(editor_terrainEditor.getMaterialsInJson()) do
      if mtl.internalName == newName then
        forbiddenName = true
        break
      end
    end
  end

  -- copy the material object from list to current material proxy
  terrainMtlProxy.material = terrainMtlCopyProxy.material

  if not forbiddenName then
    if terrainMtlCopyProxy.fileName == "" then editor.logError("Empty filename for terrain material: "  .. terrainMtlProxy.internalName) end
    -- we must delete the entry from the file first, because if the name changed, the old material will remain in the file
    scenetree.terrEd_PersistMan:removeObjectFromFileLua(terrainMtlCopyProxy.material)
    terrainMtlCopyProxy.internalName = newName
    terrainMtlProxy.material:setInternalName(newName)
    terrainMtlProxy.internalName = newName
  else
    editor.logWarn("Cannot set the terrain material name " .. newName .. ", already taken.")
    terrainMtlCopyProxy.nameInput = im.ArrayChar(32, terrainMtlCopyProxy.internalName)
    terrainMtlProxy.internalName = terrainMtlCopyProxy.internalName
  end

  -- version 1 terrain material
  if editor_terrainEditor.getTerrainBlock() then
    if editor_terrainEditor.getTerrainBlock():getField('materialTextureSet', 0) == "" then
      -- set the material properties from the edited material proxy
      terrainMtlProxy.material:setDiffuseMap(terrainMtlCopyProxy.diffuseMap)
      terrainMtlProxy.material:setDiffuseSize(terrainMtlCopyProxy.diffuseSizeInput[0])
      terrainMtlProxy.material:setNormalMap(terrainMtlCopyProxy.normalMap)
      terrainMtlProxy.material:setDetailMap(terrainMtlCopyProxy.detailMap)
      terrainMtlProxy.material:setMacroMap(terrainMtlCopyProxy.macroMap)
      terrainMtlProxy.material:setDetailSize(terrainMtlCopyProxy.detailSizeInput[0])
      terrainMtlProxy.material:setDetailStrength(terrainMtlCopyProxy.detailStrengthInput[0])
      terrainMtlProxy.material:setDetailDistance(terrainMtlCopyProxy.detailDistanceInput[0])
      terrainMtlProxy.material:setMacroSize(terrainMtlCopyProxy.macroSizeInput[0])
      terrainMtlProxy.material:setMacroDistance(terrainMtlCopyProxy.macroDistanceInput[0])
      terrainMtlProxy.material:setMacroStrength(terrainMtlCopyProxy.macroStrengthInput[0])
      terrainMtlProxy.material:setUseSideProjection(terrainMtlCopyProxy.useSideProjectionInput[0])
      terrainMtlProxy.material:setParallaxScale(terrainMtlCopyProxy.parallaxScaleInput[0])
    else -- version 1.5 terrain material
      for k, map in ipairs(v1MaterialTextureSetMaps) do
        terrainMtlProxy.material:setField(string.format("%sBaseTex", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("%sBaseTex", map.mapIdentifier), 0))
        terrainMtlProxy.material:setField(string.format("%sBaseTexSize", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("%sBaseTexSize", map.mapIdentifier), 0))

        terrainMtlProxy.material:setField(string.format("%sMacroTex", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("%sMacroTex", map.mapIdentifier), 0))
        terrainMtlProxy.material:setField(string.format("%sMacroTexSize", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("%sMacroTexSize", map.mapIdentifier), 0))
        terrainMtlProxy.material:setField(string.format("%sMacroStrength", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("%sMacroStrength", map.mapIdentifier), 0))

        terrainMtlProxy.material:setField(string.format("%sDetailTex", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("%sDetailTex", map.mapIdentifier), 0))
        terrainMtlProxy.material:setField(string.format("%sDetailTexSize", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("%sDetailTexSize", map.mapIdentifier), 0))
        terrainMtlProxy.material:setField(string.format("%sDetailStrength", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("%sDetailStrength", map.mapIdentifier), 0))
      end
      terrainMtlProxy.material:setField(string.format("macroDistAtten", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("macroDistAtten", map.mapIdentifier), 0))
      terrainMtlProxy.material:setField(string.format("detailDistAtten", map.mapIdentifier), 0, terrainMtlCopyProxy.material:getField(string.format("detailDistAtten", map.mapIdentifier), 0))

      --cleanup, removing v1 properties
      terrainMtlProxy.material:setDiffuseMap("")
      terrainMtlProxy.material:setNormalMap("")
      terrainMtlProxy.material:setDetailMap("")
      terrainMtlProxy.material:setMacroMap("")
    end
  end
  terrainMtlProxy.material:setGroundmodelName(terrainMtlCopyProxy.groundmodelName)
  terrainMtlProxy.material:setField("annotation", 0, terrainMtlCopyProxy.material:getField("annotation", 0))

  terrainMtlProxy.groundmodelName = terrainMtlCopyProxy.groundmodelName
  terrainMtlProxy.fileName = terrainMtlCopyProxy.fileName
end

local function terrainMaterialEditor_Accept()
  local oldMaterialName = terrainMtlCopyProxy.internalName
  local materialName = ffi.string(terrainMtlCopyProxy.nameInput)

  -- check if a material name has been set
  if string.len(materialName) == 0 then
    notificationState = NotificationState_ErrorMtlNameIsEmpty
  else
    local index = -1
    -- find the index if it exists in paint materials
    for i, mtlProxy in ipairs(editor_terrainEditor.getPaintMaterialProxies()) do
      if mtlProxy.internalName == oldMaterialName then
        index = i - 1
        break
      end
    end

    if terrainMtlCopyProxy.isNew then
      terrainMtlCopyProxy.material:registerObject("")
      editor_terrainEditor.getMaterialsInJson()[terrainMtlCopyProxy.uniqueID] = terrainMtlCopyProxy
    end

    applyMtlChanges()

    -- change the name in the paint materials also and find the index if it exists in there
    for _, mtlProxy in ipairs(editor_terrainEditor.getPaintMaterialProxies()) do
      if mtlProxy.internalName == oldMaterialName then
        mtlProxy.internalName = materialName
        break
      end
    end

    terrainMtlProxy.dirty = true

    if index ~= -1 then
      if editor_terrainEditor.getTerrainBlock() then
        editor_terrainEditor.getTerrainBlock():updateMaterial(index, terrainMtlProxy.internalName)
      end
      terrainMtlProxy.index = index
      editor_terrainEditor.updatePaintMaterialProxies()
      terrainMtlProxy.isNew = nil
    end

    scenetree.terrEd_PersistMan:setDirty(terrainMtlProxy.material, terrainMtlProxy.fileName or "")
    terrainMtlCopyProxy.isNew = nil
    editor_terrainEditor.setMaterialsDirty()
    editor_terrainEditor.setTerrainDirty()
    editor_terrainEditor.saveTerrainAndMaterials()
  end
end

local function materialPropertiesGuiBase()
  im.TextUnformatted("Material Properties")
  im.Separator()
end

local function matNameInputWidget(widthMod)
  im.TextUnformatted("Name")
  im.SameLine()
  im.PushItemWidth(im.GetWindowContentRegionWidth() - (widthMod or 0))
  if im.InputText("##MaterialNameInput", terrainMtlCopyProxy.nameInput, nil, im.flags(im.InputTextFlags_CharsNoBlank)) then
    local firstChar = tonumber(string.sub(ffi.string(terrainMtlCopyProxy.nameInput), 1, 1))
    if firstChar and type(firstChar) == "number" then
      notificationState = 1
    else
      notificationState = 0
    end
  end
  im.PopItemWidth()
end

local function materialPropertiesGuiV0()
  matNameInputWidget()
  im.Separator()

  local childWidth = im.GetItemRectSize().x
  local groundModelName = terrainMtlCopyProxy.groundmodelName
  local groundModelNamesSorted = tableKeys(core_environment.groundModels)
  table.sort(groundModelNamesSorted)
  if not tableContains(groundModelNamesSorted, string.upper(groundModelName)) then groundModelName = "" end
  im.Text("Ground Model:")
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if im.BeginCombo("##groundModels", groundModelName) then
    for _, gmName in ipairs(groundModelNamesSorted) do
      if im.Selectable1(gmName) then
        notificationState = 0
        terrainMtlCopyProxy.groundmodelName = gmName
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()
  im.Separator()

  -- diffuse
  im.PushID1("mat_properties_image_button_diffuse")
  if im.ImageButton(terrainMtlCopyProxy.diffuseMapObj.texId, materialEditorMapThumbnailSize, nil, nil, 1) then
    editor_fileDialog.openFile(
      function(data) editor_terrainEditor.updateMap(terrainMtlCopyProxy, "diffuse", data.filepath) end,
      {{"Any files", "*"}, {"Images", {".png", ".dds", ".jpg"}}, {"DDS", ".dds"}, {"PNG", ".png"}, {"JPG", ".jpg"}},
      false, editor_terrainEditor.getVars().lastPath .. editor_terrainEditor.getTerrainFolder(), true)
  end
  im.PopID()
  if terrainMtlCopyProxy.diffuseMap ~= "" then
    im.tooltip(terrainMtlCopyProxy.diffuseMap)
  end
  editor_terrainEditor.dragDropTarget(terrainMtlCopyProxy, "diffuse")
  im.SameLine()
  im.BeginGroup()
  im.TextUnformatted("Diffuse")
  im.SameLine()
  local removeMapButtonCursorX = childWidth - editor_terrainEditor.getVars().style.ItemInnerSpacing.x - fontSize - editor_terrainEditor.getVars().style.ScrollbarSize
  im.SetCursorPosX(removeMapButtonCursorX)
  if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(fontSize, fontSize)) then
    editor_terrainEditor.removeMap(terrainMtlCopyProxy, "diffuse")
  end
  im.tooltip("Remove diffuse map")
  local cursorPosX = im.GetCursorPosX()
  local itemWidth = childWidth - cursorPosX - editor_terrainEditor.getVars().style.WindowPadding.x / 2 - im.CalcTextSize("Parallax Scale").x - editor_terrainEditor.getVars().style.ItemInnerSpacing.x - editor_terrainEditor.getVars().style.ScrollbarSize
  im.PushItemWidth(itemWidth)
  im.InputFloat("Size##Diffuse", terrainMtlCopyProxy.diffuseSizeInput, 1, 10, "%.0f")
  im.PopItemWidth()
  im.Checkbox("Use Side Projection##Diffuse", terrainMtlCopyProxy.useSideProjectionInput)
  im.EndGroup()
  im.Separator()
  -- macro
  im.PushID1("mat_properties_image_button_macro")
  if im.ImageButton(terrainMtlCopyProxy.macroMapObj.texId, materialEditorMapThumbnailSize, nil, nil, 1) then
    editor_fileDialog.openFile(
      function(data) editor_terrainEditor.updateMap(terrainMtlCopyProxy, "macro", data.filepath) end,
      {{"Any files", "*"}, {"Images",{".png", ".dds", ".jpg"}}, {"DDS", ".dds"},{"PNG", ".png"},{"JPG", ".jpg"}},
      false, editor_terrainEditor.getVars().lastPath .. editor_terrainEditor.getTerrainFolder(), true)
  end
  im.PopID()
  if terrainMtlCopyProxy.macroMap ~= "" then
    im.tooltip(terrainMtlCopyProxy.macroMap)
  end
  editor_terrainEditor.dragDropTarget(terrainMtlCopyProxy, "macro")
  im.SameLine()
  im.BeginGroup()
  im.TextUnformatted("Macro")
  im.SameLine()
  im.SetCursorPosX(removeMapButtonCursorX)
  if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(fontSize, fontSize)) then
    editor_terrainEditor.removeMap(terrainMtlCopyProxy, "macro")
  end
  im.tooltip("Remove macro map")
  im.PushItemWidth(itemWidth)
  im.InputFloat("Strength##Macro", terrainMtlCopyProxy.macroStrengthInput, 0.01, 0.1, "%.2f")
  im.PopItemWidth()
  im.PushItemWidth(itemWidth)
  im.InputFloat("Size##Macro", terrainMtlCopyProxy.macroSizeInput, 1, 10, "%.0f")
  im.PopItemWidth()
  im.PushItemWidth(itemWidth)
  im.InputFloat("Distance##Macro", terrainMtlCopyProxy.macroDistanceInput, 1, 10, "%.0f")
  im.PopItemWidth()
  im.EndGroup()
  im.Separator()
  -- detail
  im.PushID1("mat_properties_image_button_detail")
  if im.ImageButton(terrainMtlCopyProxy.detailMapObj.texId, materialEditorMapThumbnailSize, nil, nil, 1) then
    editor_fileDialog.openFile(
      function(data) editor_terrainEditor.updateMap(terrainMtlCopyProxy, "detail", data.filepath) end,
      {{"Any files", "*"}, {"Images", {".png", ".dds", ".jpg"}}, {"DDS", ".dds"}, {"PNG", ".png"},{"JPG", ".jpg"}},
      false, editor_terrainEditor.getVars().lastPath .. editor_terrainEditor.getTerrainFolder(), true)
  end
  im.PopID()
  if terrainMtlCopyProxy.detailMap ~= "" then
    im.tooltip(terrainMtlCopyProxy.detailMap)
  end
  editor_terrainEditor.dragDropTarget(terrainMtlCopyProxy, "detail")
  im.SameLine()
  im.BeginGroup()
  im.TextUnformatted("Detail")
  im.SameLine()
  im.SetCursorPosX(removeMapButtonCursorX)
  if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(fontSize, fontSize)) then
    editor_terrainEditor.removeMap(terrainMtlCopyProxy, "detail")
  end
  im.tooltip("Remove detail map")
  im.PushItemWidth(itemWidth)
  im.InputFloat("Strength##Detail", terrainMtlCopyProxy.detailStrengthInput, 0.01, 0.1, "%.2f")
  im.PopItemWidth()
  im.PushItemWidth(itemWidth)
  im.InputFloat("Size##Detail", terrainMtlCopyProxy.detailSizeInput, 1, 10, "%.0f")
  im.PopItemWidth()
  im.PushItemWidth(itemWidth)
  im.InputFloat("Distance##Detail", terrainMtlCopyProxy.detailDistanceInput, 1, 10, "%.0f")
  im.PopItemWidth()
  im.EndGroup()
  im.Separator()
  -- normal
  im.PushID1("mat_properties_image_button_normal")
  if im.ImageButton(terrainMtlCopyProxy.normalMapObj.texId, materialEditorMapThumbnailSize, nil, nil, 1) then
    editor_fileDialog.openFile(
      function(data) editor_terrainEditor.updateMap(terrainMtlCopyProxy, "normal", data.filepath) end,
      {{"Any files", "*"}, {"Images", {".png", ".dds", ".jpg"}}, {"DDS", ".dds"}, {"PNG", ".png"}, {"JPG", ".jpg"}},
      false, editor_terrainEditor.getVars().lastPath .. editor_terrainEditor.getTerrainFolder(), true)
  end
  im.PopID()
  if terrainMtlCopyProxy.normalMap ~= "" then
    im.tooltip(terrainMtlCopyProxy.normalMap)
  end
  editor_terrainEditor.dragDropTarget(terrainMtlCopyProxy, "normal")
  im.SameLine()
  im.BeginGroup()
  im.TextUnformatted("Normal")
  im.SameLine()
  im.SetCursorPosX(removeMapButtonCursorX)
  if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(fontSize, fontSize)) then
    editor_terrainEditor.removeMap(terrainMtlCopyProxy, "normal")
  end
  im.tooltip("Remove normal map")
  im.PushItemWidth(itemWidth)
  im.InputFloat("Parallax Scale##Normal", terrainMtlCopyProxy.parallaxScaleInput, 0.01, 0.1, "%.2f")
  im.PopItemWidth()
  im.EndGroup()
  im.Separator()
end

local function terrainMaterialPropertyTreeNode(name, textureMap, defaultOpen)
  if im.CollapsingHeader1(name, defaultOpen == true and im.TreeNodeFlags_DefaultOpen or nil) then
    widgetTexture(textureMap, "%sBaseTex", "Base Texture")
    widgetTextureSize(textureMap, "%sBaseTexSize", "Base Mapping Scale", "Size (in meters) of the Base Texture in the world.")
    im.Separator()
    widgetTexture(textureMap, "%sMacroTex", "Macro Texture")
    widgetTextureSize(textureMap, "%sMacroTexSize", "Macro Mapping Scale", "Size (in meters) of the Macro Texture in the world.")
    widgetFloat2(string.format("%sMacroStrength", textureMap), "Macro Strength", nil, nil, "Strength of the macro texture influence (0.0 - 1.0)")
    im.Separator()
    widgetTexture(textureMap, "%sDetailTex", "Detail Texture")
    widgetTextureSize(textureMap, "%sDetailTexSize", "Detail Mapping Scale", "Size (in meters) of the Detail Texture in the world.")
    widgetFloat2(string.format("%sDetailStrength", textureMap), "Detail Strength", nil, nil, "Strength of the detail texture influence (0.0 - 1.0)")
  end
end

local function doBulkChange()
  local properties = {}
  local values = {}
  for map, asset in pairs(bulkChange.textures) do
    if map == "b" then
      table.insert(properties, string.format(bulkChange.property, "baseColor"))
      table.insert(values, asset.file)
    end
    if map == "nm" then
      table.insert(properties, string.format(bulkChange.property, "normal"))
      table.insert(values, asset.file)
    end
    if map == "r" then
      table.insert(properties, string.format(bulkChange.property, "roughness"))
      table.insert(values, asset.file)
    end
    if map == "ao" then
      table.insert(properties, string.format(bulkChange.property, "ao"))
      table.insert(values, asset.file)
    end
    if map == "h" then
      table.insert(properties, string.format(bulkChange.property, "height"))
      table.insert(values, asset.file)
    end
  end
  setPropertyWithUndo(properties, values, "bulkChange")
  bulkChange = {}
  editor.closeModalWindow("bulkChangeTexturesModal")
end

local function materialPropertiesGuiV1()
  if editor.beginModalWindow("bulkChangeTexturesModal", "Bulk Change Textures") then
    if bulkChange and bulkChange.textures then
      im.TextUnformatted("Found the following textures:")
      im.Dummy(im.ImVec2(0, 10))

      im.Columns(2)
      if bulkChange.textures.b then
        im.TextUnformatted("Base Color")
        im.NextColumn()
        im.TextUnformatted(bulkChange.textures.b.file)
        im.NextColumn()
      end
      if bulkChange.textures.nm then
        im.TextUnformatted("Normal")
        im.NextColumn()
        im.TextUnformatted(bulkChange.textures.nm.file)
        im.NextColumn()
      end
      if bulkChange.textures.r then
        im.TextUnformatted("Roughness")
        im.NextColumn()
        im.TextUnformatted(bulkChange.textures.r.file)
        im.NextColumn()
      end
      if bulkChange.textures.ao then
        im.TextUnformatted("Ambient Occlusion")
        im.NextColumn()
        im.TextUnformatted(bulkChange.textures.ao.file)
        im.NextColumn()
      end
      if bulkChange.textures.h then
        im.TextUnformatted("Height")
        im.NextColumn()
        im.TextUnformatted(bulkChange.textures.h.file)
        im.NextColumn()
      end
      im.Columns(1)
      im.Dummy(im.ImVec2(0, 10))
      im.TextUnformatted("Would you like to bulk change them?")
    end

    if im.Button("Close") then
      bulkChange = {}
      editor.closeModalWindow("bulkChangeTexturesModal")
    end
    im.SameLine()
    if im.Button("Bulk Change") then
      doBulkChange()
    end
  end
  editor.endModalWindow()

  matNameInputWidget()
  im.Separator()

  local groundModelName = terrainMtlCopyProxy.groundmodelName
  local groundModelNamesSorted = tableKeys(core_environment.groundModels)
  table.sort(groundModelNamesSorted)
  if not tableContains(groundModelNamesSorted, string.upper(groundModelName)) then groundModelName = "" end
  im.Text("Ground Model:")
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if im.BeginCombo("##groundModels", groundModelName) then
    for _, gmName in ipairs(groundModelNamesSorted) do
      if im.Selectable1(gmName) then
        notificationState = 0
        terrainMtlCopyProxy.groundmodelName = gmName
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()

  im.Separator()
  for i, k in ipairs(v1MaterialTextureSetMaps) do
    terrainMaterialPropertyTreeNode(k.title, k.mapIdentifier, k.defaultOpen)
  end

  im.Separator()
  widgetDistances("macroDistances", "Macro Distances")
  widgetFloat2("macroDistAtten", "Macro Distance Attenuation", nil, nil, "Defines how much the near and far values fade to at the Start Fade In/Out distances (1 = fade to 0, 0 = no fade)")
  im.Separator()
  widgetDistances("detailDistances", "Detail Distances")
  widgetFloat2("detailDistAtten", "Detail Distance Attenuation", nil, nil, "Defines how much the near and far values fade to at the Start Fade In/Out distances (1 = fade to 0, 0 = no fade)")
  im.Separator()
end

local function upgradeTerrainMaterialFileFormat()
  upgradeFileFormatMaterials.oldFile = editor_terrainEditor.getLevelPath() .. "/art/terrains/materials.json"
  upgradeFileFormatMaterials.newFile = editor_terrainEditor.getLevelPath() .. editor_terrainEditor.getMatFilePath()
  upgradeFileFormatMaterials.terrainMaterials = {}
  local terrainMaterials = scenetree.findClassObjects('TerrainMaterial')
  for k,v in ipairs(terrainMaterials) do
    local terrainMaterial = scenetree.findObject(v)
    if terrainMaterial then
      local currentFilename = terrainMaterial:getFileName()
      if currentFilename == editor_terrainEditor.getLevelPath() .. "/art/terrains/materials.json" then
        table.insert(upgradeFileFormatMaterials.terrainMaterials, {
          id = terrainMaterial:getId(),
          name = terrainMaterial:getInternalName()
        })
      end
    end
  end

  editor.openModalWindow("upgradeTerrainMaterialsFileFormatModal")
end

local function onEditorGui()
  if editor.beginWindow(terrainMaterialEditorWindowName, "Terrain Material Library") then

    if editor.beginModalWindow("upgradeTerrainMaterialsFileFormatModal", "Upgrade Terrain Material File Format") then

      if upgradeFileFormatMaterials and upgradeFileFormatMaterials.terrainMaterials then

        im.PushTextWrapPos(im.GetContentRegionAvailWidth())
        im.TextUnformatted("The following Terrain Materials will be moved to a new file using the the most recent file format.")
        im.Dummy(im.ImVec2(0, 10))
        im.TextUnformatted("Old file path: " .. upgradeFileFormatMaterials.oldFile)
        im.TextUnformatted("New file path: " .. upgradeFileFormatMaterials.newFile)
        im.PopTextWrapPos()

        im.Dummy(im.ImVec2(0, 10))
        if im.BeginTable('##terrainMaterialsTable', 2) then
          im.TableSetupScrollFreeze(0, 1)
          im.TableSetupColumn('ID')
          im.TableSetupColumn('Name')
          im.TableHeadersRow()
          im.TableNextColumn()
          for k, v in ipairs(upgradeFileFormatMaterials.terrainMaterials) do
            im.TextUnformatted(tostring(v.id))
            im.TableNextColumn()
            im.TextUnformatted(v.name)
            im.TableNextColumn()
          end
        end
        im.EndTable()
        im.Dummy(im.ImVec2(0, 10))
      end

      if im.Button("Close") then
        upgradeFileFormatMaterials = {}
        editor.closeModalWindow("upgradeTerrainMaterialsFileFormatModal")
      end
      im.SameLine()
      if im.Button("Upgrade##upgradeFileFormat") then
        if upgradeFileFormatMaterials and upgradeFileFormatMaterials.terrainMaterials then
          for k,v in ipairs(upgradeFileFormatMaterials.terrainMaterials) do
            local terrainMaterial = scenetree.findObject(v.id)
            if terrainMaterial then
              scenetree.terrainMatEditor_PersistMan:removeObjectFromFileLua(terrainMaterial, upgradeFileFormatMaterials.oldFile)
              terrainMaterial:serializeToNameDictFile(upgradeFileFormatMaterials.newFile)
            end
          end
        end
        upgradeFileFormatMaterials = {}
        editor.logInfo("Terrain Material's file format has been updated. Please check the files in question.")
        editor_terrainEditor.updateMaterialLibrary()
        editor_terrainEditor.checkForTerrainMaterialFileFormat()
        editor_terrainEditor.fixedFileFormat()
        editor.closeModalWindow("upgradeTerrainMaterialsFileFormatModal")
      end
    end
    editor.endModalWindow()

    if editor.beginModalWindow("upgradeTerrainMaterialsModal", "Upgrade Terrain Materials") then
      im.PushTextWrapPos(im.GetContentRegionAvailWidth())
      im.TextUnformatted("This will create a TerrainMaterialTextureSet object and attach it to your Terrain Blocks.")
      im.TextColored(editor.color.warning.Value, [[
DISCLAIMER: The upgraded terrain material system introduces new properties.
Former terrain material properties won't be used by the new system
hence all your terrain materials will be broken.
You'll have to manually update the properties (textures, ...).
]])
      im.Dummy(im.ImVec2(0,10))
      im.TextColored(editor.color.warning.Value, "Once the terrain materials are upgraded you won't be able to fallback to the former system within this editor.")
      im.TextUnformatted("Do not forget to save the level in order to apply the changes that have been made to the TerrainBlock object.")
      im.Dummy(im.ImVec2(0,20))
      if not editor_terrainEditor.getTerrainBlock() then
        im.TextColored(editor.color.warning.Value, "There's no Terrain Block in the scene.")
      end
      im.PopTextWrapPos()

      if im.Button("Close") then
        editor.closeModalWindow("upgradeTerrainMaterialsModal")
      end
      im.SameLine()
      if im.Button("Upgrade##upgradeTerrainMaterials") then
        if editor_terrainEditor.getTerrainBlock() then
          local filename = getMissionPath() .. terrainMaterialTextureSetPath
          local name = string.match(getMissionPath(), "/(.[^/]+)/$") .. "TerrainMaterialTextureSet"

          local textureSet = scenetree.findObject(name)
          if not textureSet then
           textureSet = createObject('TerrainMaterialTextureSet')
          end
          textureSet:setFileName(filename)
          textureSet:setField('name', 0, name)
          textureSet.canSave = true
          textureSet:registerObject(name)
          scenetree.terrainMatEditor_PersistMan:setDirty(textureSet, '')
          editor_terrainEditor.getTerrainBlock():setField('materialTextureSet', 0, name)
          scenetree.terrainMatEditor_PersistMan:saveDirty()
          editor.setDirty()

          -- remove obsolete v1 fields from terrain materials
          for id, mtl in pairs(editor_terrainEditor.getMaterialsInJson()) do
            mtl.material:setDiffuseMap("")
            mtl.material:setNormalMap("")
            mtl.material:setDetailMap("")
            mtl.material:setMacroMap("")

            scenetree.terrEd_PersistMan:setDirty(mtl.material, mtl.fileName or "")
            editor_terrainEditor.setMaterialsDirty()
            editor_terrainEditor.saveTerrainAndMaterials()
          end

          reloadTerrainMaterials()
        end

        editor.closeModalWindow("upgradeTerrainMaterialsModal")
      end
    end
    editor.endModalWindow()

    local btnHeight = math.ceil(im.GetFontSize()) + 2
    --TODO: move to terrain.lua api
    fontSize = math.ceil(im.GetFontSize())
    if editor_terrainEditor then editor_terrainEditor.setupVars() end
    materialEditorWindowSize = im.GetWindowSize()
    im.Columns(2)
    -- TERRAIN MATERIALS COLUMN
    if im.BeginChild1("Terrain Materials##Child", nil, true) then
      im.TextUnformatted("Material Library")
      im.SameLine()
      -- Add new material
      if editor.uiIconImageButton(editor.icons.add, im.ImVec2(fontSize, fontSize)) then
        editMaterial()
        terrainMtlProxy.dirty = true
        scenetree.terrEd_PersistMan:setDirty(terrainMtlProxy.material, editor_terrainEditor.getVars().levelPath .. editor_terrainEditor.getMatFilePath())
        terrainMtlProxy.uniqueID = terrainMtlProxy.material.internalName .. "-" .. terrainMtlProxy.material:getOrCreatePersistentID()
      end

      im.SameLine()
      -- Delete selected material
      if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(fontSize, fontSize)) and terrainMtlProxy and terrainMtlProxy.material then
        --TODO: undo
        local index = editor_terrainEditor.getTerrainBlockMaterialIndex(terrainMtlProxy.internalName)
        local canDelete = true

        if index ~= -1 then
          if tableSize(editor_terrainEditor.getPaintMaterialProxies()) == 1 then
            editor.logWarn("Cannot delete terrain material, there must be at least one in the library and terrain block")
            canDelete = false
          else
            if editor_terrainEditor.getTerrainBlock() then
              editor_terrainEditor.getTerrainBlock():removeMaterial(index - 1)
              editor_terrainEditor.setTerrainDirty()
            end
          end
        end

        if canDelete then
          editor_terrainEditor.setMaterialsDirty()
          scenetree.terrEd_PersistMan:removeObjectFromFileLua(terrainMtlProxy.material, terrainMtlProxy.fileName)
          editor_terrainEditor.updatePaintMaterialProxies()
          terrainMtlProxy.material:deleteObject()
          editor_terrainEditor.getMaterialsInJson()[terrainMtlProxy.uniqueID] = nil
          terrainMtlProxy = nil
          terrainMtlCopyProxy = nil
        end
      end

      im.SameLine()
      local posX = im.GetCursorPosX()
      im.SetCursorPosX(posX + im.GetContentRegionAvailWidth() - ((2 * im.GetStyle().FramePadding.x) + im.CalcTextSize("Reload Terrain Materials").x))
      if im.SmallButton("Reload Terrain Materials") then
        editor.logInfo("Reloading Terrain Materials")
        reloadTerrainMaterials()
      end

      im.Separator()

      local name = ""
      if terrainMtlCopyProxy then
        name = terrainMtlCopyProxy.internalName
      end
      if im.CollapsingHeader1("Terrain Materials", im.TreeNodeFlags_DefaultOpen) then
        for id, mtl in pairs(editor_terrainEditor.getMaterialsInJson()) do
          if im.Selectable1(mtl.internalName .. "##Terrain Materials" .. id, name == mtl.internalName, nil,
          im.ImVec2(im.GetContentRegionAvailWidth() - (editor_terrainEditor.getVars().style.ItemSpacing.x + btnHeight), 0))
          then
            editMaterial(mtl)
          end
        end
      end
      im.Separator()

      if editor_terrainEditor.getTerrainBlock() then
        if editor_terrainEditor.getTerrainBlock():getField('materialTextureSet', 0) == "" then
          im.Dummy(im.ImVec2(0,10))
          if im.Button("Upgrade Terrain Materials", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
            editor.openModalWindow("upgradeTerrainMaterialsModal")
          end
          im.tooltip("Upgrade Terrain Materials to the new PBR pipeline.")
        else
          if im.CollapsingHeader1("Edit TerrainMaterialTextureSet Properties", im.TreeNodeFlags_DefaultOpen) then
            local obj = scenetree.findObject(editor_terrainEditor.getTerrainBlock():getField('materialTextureSet', 0))
            if obj then
              for k,v in ipairs(terrainMaterialTextureSetProperties) do
                widgetInt2(v.property, v.name, obj, v.tooltip)
              end

              im.SetCursorPosX(im.GetContentRegionAvailWidth() - ((2 * im.GetStyle().FramePadding.x) + im.CalcTextSize("Apply Changes").x))
              if im.Button("Apply Changes") then
                editor.logInfo("Applying changes to Terrain Material Texture Set")
                scenetree.terrainMatEditor_PersistMan:setDirty(obj, '')
                scenetree.terrainMatEditor_PersistMan:saveDirty()
              end
              im.tooltip("Apply changes to the Terrain Material Texture Set object.")
            end
          end
        end
      end

      if editor_terrainEditor.getErrors()['deprecated_material_file'] == true then
        im.Dummy(im.ImVec2(0,20))
        im.PushTextWrapPos(im.GetContentRegionAvailWidth())
        im.TextColored(editor.color.warning.Value, "The Terrain Materials reside in a file with a deprecated format.")
        if im.Button("Upgrade Terrain Material file format", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
          upgradeTerrainMaterialFileFormat()
        end
        im.PopTextWrapPos()
      end
    end
    im.EndChild()
    im.NextColumn()
    -- MATERIAL PROPERTIES COLUMN
    -- local size = im.ImVec2(0, materialEditorWindowSize.y - (fontSize + 2 * editor_terrainEditor.getVars().style.FramePadding.y + editor_terrainEditor.getVars().style.WindowPadding.y) - (fontSize + editor_terrainEditor.getVars().style.WindowPadding.y + editor_terrainEditor.getVars().style.ItemSpacing.y) - (fontSize + editor_terrainEditor.getVars().style.ItemSpacing.y))
    local size = im.ImVec2(0, im.GetContentRegionAvail().y - (im.GetFontSize() + 2 * im.GetStyle().FramePadding.y + im.GetStyle().ItemSpacing.y))
    if im.BeginChild1("Material Properties##Child", size, true) then
      if editor_terrainEditor.getTerrainBlock() and terrainMtlCopyProxy and terrainMtlProxy then
        materialPropertiesGuiBase()
        if editor_terrainEditor.getTerrainBlock():getField('materialTextureSet', 0) == "" then
          materialPropertiesGuiV0()
        else
          materialPropertiesGuiV1()
        end

        local annotations = editor.getAnnotations()
        local annotationsTbl = editor.getAnnotationsTbl()
        local bgColor = nil
        local value = terrainMtlCopyProxy.material:getField("annotation", 0)
        if not annotationsTbl or not annotationsTbl[value] then
          bgColor = im.ImVec4(0, 0, 0, 1)
        else
          bgColor =
            im.ImVec4(
            annotationsTbl[value].r / 255,
            annotationsTbl[value].g / 255,
            annotationsTbl[value].b / 255,
            1.0)
        end
        im.TextUnformatted("Annotation:")
        im.SameLine()
        im.ColorButton("Annotation color", bgColor, 0, im.ImVec2(25, 19))
        im.SameLine()
        im.PushItemWidth(im.GetContentRegionAvailWidth())
        if im.BeginCombo("##annotation", value, im.ComboFlags_HeightLargest) then
          for n = 1, tableSize(annotations) do
            local isSelected = (value == annotations[n]) and true or false
            local bgColor = nil
            if not annotationsTbl or not annotationsTbl[annotations[n]] then
              bgColor = im.ImVec4(0, 0, 0, 1)
            else
              bgColor =
                im.ImVec4(
                annotationsTbl[annotations[n]].r / 255,
                annotationsTbl[annotations[n]].g / 255,
                annotationsTbl[annotations[n]].b / 255,
                1.0)
            end
            im.ColorButton("annotationColorButton", bgColor, 0, im.ImVec2(25, 19))
            im.SameLine()
            if im.Selectable1(annotations[n], isSelected) then
              value = annotations[n]
              if noAnnotationString == value then
                value = ""
              end
              terrainMtlCopyProxy.material:setField("annotation", 0, value)
            end
            if isSelected then
              -- set the initial focus when opening the combo
              im.SetItemDefaultFocus()
            end
          end
          im.EndCombo()
        end
        im.PopItemWidth()

      else
        im.TextUnformatted("No Terrain Material selected")
      end
    end
    im.EndChild()
    if notificationState == 1 then
      im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), "First character must not be a number.")
    elseif notificationState == 2 then
      im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), "Material name must not be empty.")
    elseif notificationState == 3 then
      im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), "This material already exists.")
    end
    if terrainMtlCopyProxy then
      if not terrainMtlCopyProxy.isNew then
        if im.Button("Save Changes To File") then
          terrainMaterialEditor_Accept()
        end
      else
        if im.SmallButton("Add Material") then
          terrainMaterialEditor_Accept()
        end
        im.SameLine()
        if im.SmallButton("Cancel") then
          terrainMtlCopyProxy.material:deleteObject()
          terrainMtlCopyProxy = nil
        end
      end
    end
    im.Columns(1)
  end
  editor.endWindow()
end

local function showTerrainMaterialsEditor(internalName)
  for id, mtl in pairs(editor_terrainEditor.getMaterialsInJson()) do
    if mtl.internalName == internalName then
      editMaterial(mtl)
    end
  end
  editor.showWindow(terrainMaterialEditorWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(terrainMaterialEditorWindowName, im.ImVec2(710,530))
  editor.showTerrainMaterialsEditor = showTerrainMaterialsEditor

  editor.registerModalWindow("bulkChangeTexturesModal", im.ImVec2(200, 300))
  editor.registerModalWindow("upgradeTerrainMaterialsModal", im.ImVec2(600, 300))
  editor.registerModalWindow("upgradeTerrainMaterialsFileFormatModal", im.ImVec2(700, 340))
end

local function onEditorActivated()
  -- we need to update (load) the material library so we can show the list of materials
  if editor.isWindowVisible(terrainMaterialEditorWindowName) then
    editor_terrainEditor.updateMaterialLibrary()
  end
end

-- public interface
M.dependencies = {"editor_terrainEditor"}
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onEditorActivated = onEditorActivated

return M