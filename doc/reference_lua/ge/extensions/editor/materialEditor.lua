-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local ffi = require('ffi')

local init = false

local M = {}
local logTag = 'editor_materiaEditor: '
local dbg = false
local setWidth = 10

local toolWindowName = 'materialEditor'
local createCubemapWindowName = "materialEditorCreateCubemap"
local createMaterialWindowName = "materialEditorCreateMaterial"
local materialPreviewWindowName = "materialEditorMaterialPreview"
local materialsByTagsWindowName = "materialEditorMaterialsByTag"

local focusWindow = false

local im = ui_imgui
local v = {}

-- bit operators
local tobit, band, bor, tohex, bxor = bit.tobit, bit.band, bit.bor, bit.tohex, bit.bxor

-- copy/paste
local copiedValues = {}

-- filter
local matFilter = im.ImGuiTextFilter()

-- material preview
local previewMeshesPath = "/art/shapes/material_preview/"
local previewMeshes = nil
local previewMeshNamesPtr = nil
local previewMeshIndex = im.IntPtr(0)

local groundModels = nil
local tags = nil
local sortedTags = nil

local matPreview = ShapePreview()
local extMatPreview = ShapePreview()
local matPreviewBackgroundColor = ColorI(128,128,128,255)
local extMatPreviewBackgroundColor = ColorI(128,128,128,255)

local matPreviewRenderSize = 256
local extMatPreviewRenderSize = matPreviewRenderSize
-- rotation, view, sun, zoom, resetView
matPreview:setInputEnabledEx(true, false, true, false, true)
extMatPreview:setInputEnabledEx(true, false, true, true, true)
local dimRdr = RectI()
local extDimRdr = RectI()
dimRdr:set(0, 0, matPreviewRenderSize, matPreviewRenderSize)
extDimRdr:set(0, 0, matPreviewRenderSize, matPreviewRenderSize)

local levelPath = nil
local lastPath = nil
local lastCreateMaterialPath = nil

local formerEditMode = nil

local openPickMapToFromObjectPopup = false
local pickMapToFromObjectPopupPos = nil
local pickMapToFromObjectPopupHeight = nil
local pickMapToFromObjectPopupMaxHeight = 400
local pickMaterialFromObject = false
local pickingFromObjectMaterials = nil
local pickingFromObjectMapTos = nil
local pickingFromObjectMode_enum = {
  new_material = 1,
  existing_material = 2
}
local pickingFromObjectMode = 0

local createMaterialMessage = nil
local createMaterialName = ""
local createMaterialError = false

-- serialization
v.serializationPath = "/settings/editor/materialEditor_settings.json"
v.dirtyMaterials = {}

-- options
local options = {}
-- options.thumbnailSize = 64
-- options.maxMaterialPreviewSize = 256
-- options.materialName = {}
-- options.textFilterResultsWithSameFirstCharAtTop = true

local updateMaterialPreviewRender = false

--
v.picking = false

-- imgui
v.style = nil
v.inputWidgetHeight = nil

--
local newMatName = im.ArrayChar(128)
local newMatMapTo = im.ArrayChar(128)
local newMatPath = im.ArrayChar(512)
local newMatMapToLocked = false

-- Materials
v.materialNameList = nil
v.materialNamesPtr = nil

-- Object materials
local objectMaterialNames = nil
local objectMaterialNamesPtr = nil
local objectMaterialIndex = im.IntPtr(0)

-- cubemap
-- array containing all cubemap names
local cubemaps = nil
local selectedCubemapObj = nil
local cubemapNamePtr = im.ArrayChar(32)
local cubemapFaceThumbnailSize = 128
local cubemapDirty = false

-- Max number of layers for materials v1.5
local maxLayers = 4

-- cobj representing the current selected obj
local currentMaterial = nil
v.currentMaterialIndex = 0

-- ### Material Properties ###
local o = {}
o.layer = im.IntPtr(0)
o.reflectionMode = im.IntPtr(0)
--
local tempUndoValue = nil
local tempBoolPtr = im.BoolPtr(true)

local customMaterialsArray = {'Standard', 'MetalicCarPaint'}
local customMaterialsArrayPtr = im.ArrayCharPtrByTbl(customMaterialsArray)

if not scenetree.matLuaEd_PersistMan then
  local persistenceMgr = PersistenceManager()
  persistenceMgr:registerObject('matLuaEd_PersistMan')
end

local enum_animFlags = {
  scroll   = tobit(0x00000001), -- 1
  rotate   = tobit(0x00000002), -- 2
  wave     = tobit(0x00000004), -- 4
  scale    = tobit(0x00000008), -- 8
  sequence = tobit(0x00000010)  -- 16
}

local function _openPickMapToFromObjectPopup()
  if pickingFromObjectMaterials and type(pickingFromObjectMaterials) == "table" and #pickingFromObjectMaterials > 0 then
    table.sort(pickingFromObjectMaterials)
    openPickMapToFromObjectPopup = true
  end
  if formerEditMode then
    editor.selectEditMode(formerEditMode)
    formerEditMode = nil
  end
end

local function editMode_PickMapTo()
  return {
    onActivate = function() end,
    onDeactivate = function()
      pickMaterialFromObject = false
    end,
    onUpdate = function()
      if pickMaterialFromObject == true then
        local res = getCameraMouseRay()

        if not im.GetIO().WantCaptureMouse and editor.isViewportHovered() and not editor.isAxisGizmoHovered() then
          if core_forest.getForestObject() and not worldEditorCppApi.getClassIsSelectable("Forest") then core_forest.getForestObject():disableCollision() end
          local defaultFlags = bit.bor(SOTTerrain, SOTWater, SOTStaticShape, SOTPlayer, SOTItem, SOTVehicle, SOTForest)
          if not worldEditorCppApi.getClassIsSelectable("TSStatic") then
            defaultFlags = bit.band(defaultFlags, bit.bnot(SOTStaticShape))
          end
          local rayCastInfo = cameraMouseRayCast(true, defaultFlags)
          if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end

          if rayCastInfo then
            if rayCastInfo.object then
              editor.drawSelectedObjectBBox(rayCastInfo.object, ColorF(1, 0, 0, 1))
            end
            if im.IsMouseClicked(0) then
              if rayCastInfo.object.___type == "class<TSStatic>" then
                pickingFromObjectMaterials = rayCastInfo.object:getMeshMaterialNames()
                _openPickMapToFromObjectPopup()
              elseif rayCastInfo.object.___type == "class<Forest>" then
                local rayForest = getCameraMouseRay()
                local forestItem = rayCastInfo.object:castRayRendered(rayForest.pos, rayForest.pos + rayForest.dir * vec3(1000, 1000, 1000)).forestItem
                pickingFromObjectMaterials = forestItem:getMaterialNames()
                _openPickMapToFromObjectPopup()
              elseif rayCastInfo.object.___type == "class<BeamNGVehicle>" then
                pickingFromObjectMaterials = rayCastInfo.object:getMaterialNames()
                _openPickMapToFromObjectPopup()
              end
            elseif im.IsKeyReleased(im.GetKeyIndex(im.Key_Escape)) then
              -- Cancel mapTo picking.
              pickingFromObjectMaterials = nil
              pickMaterialFromObject = false
              if formerEditMode then
                editor.selectEditMode(formerEditMode)
                formerEditMode = nil
              end
            end
          end
        end
      end
    end,
    onDeselect = function() end,
    iconTooltip = "Pick mapTo value from TSStatic"
    -- actionMap = "materialEditor", -- if available, not required
  }
end

local function mapTagsJob()
  -- local timer = hptimer()
  -- timer:reset()
  tags = {}
  local matNames = scenetree.findClassObjects('Material')
  local matNamesSize = #matNames
  local mat = nil
  for i=1, matNamesSize do
    local matName = matNames[i]
    mat = scenetree.findObject(matName)
    if mat and mat.___type == "class<Material>" and not mat:isAutoGenerated() then
      local addedTo = {}
      for tagId = 0, 2 do
        local tag = mat:getField("materialTag", tostring(tagId))
        if tag and tag ~= "" then
          if not tags[tag] then tags[tag] = {} end
          if not addedTo[tag] then
            table.insert(tags[tag], matName)
            addedTo[tag] = true
          end
        end
      end
    end
  end

  local sortFunc = function(a,b) return string.lower(a) < string.lower(b) end

  sortedTags = tableKeys(tags)
  table.sort(sortedTags, sortFunc)
  for tagName, materials in pairs(tags) do
    table.sort(materials, sortFunc)
  end
  -- print(string.format("%0.2f", timer:stopAndReset()))
  -- dump(tags)
end

local function updateMaterialProperties()
  if not be then return end
  if dbg then editor.logInfo(logTag .. 'Update texture maps') end

  -- simple check if material editor is present or not
  if not v.materialNameList then return end

  local materialName = v.materialNameList[v.currentMaterialIndex]
  if not materialName then return end
  currentMaterial = scenetree.findObject(materialName)
  if not currentMaterial then return end

  if matPreview and currentMaterial then
    matPreview:setMaterial(currentMaterial)
    matPreview:renderWorld(dimRdr)
  end
  if extMatPreview and currentMaterial then
    extMatPreview:setMaterial(currentMaterial)
    extMatPreview:renderWorld(extDimRdr)
  end

  o.reflectionMode[0] = (currentMaterial:getField("dynamicCubemap", 0) == "1" and 1 or currentMaterial:getField("cubemap", 0) == "" and 0 or 2)
end

local function selectMaterialByName(matName)
  if v.materialNameList then
    --reset filter else pick doesn't work
    im.ImGuiTextFilter_Clear(matFilter)
    for k, val in ipairs(v.materialNameList) do
      if val == matName then
        v.currentMaterialIndex = k
        updateMaterialProperties()
        local levelMaterialNames = editor.getPreference("materialEditor.general.levelMaterialNames")
        levelMaterialNames[getMissionPath()] = v.materialNameList[v.currentMaterialIndex]
        editor.setPreference("materialEditor.general.levelMaterialNames", levelMaterialNames)
        return
      end
    end
    v.currentMaterialIndex = 0
  else
    -- editor.logWarn(logTag .. "No materials to select from.")
  end
end

local function setMaterialDirty(materialObj)
  local mat = (materialObj or currentMaterial)
  if not v.dirtyMaterials[mat:getField("name", 0)] then
    v.dirtyMaterials[mat:getField("name", 0)] = true
  end
end

local function setProperty(materialObj, property, layer, value)
  local matObj = (materialObj or currentMaterial)
  if not tempUndoValue then
    tempUndoValue = matObj:getField(property, layer)
  end
  if editor.setMaterialProperty(matObj, property, layer, value) then
    setMaterialDirty(matObj)
    if editor.isWindowVisible(materialPreviewWindowName) == true then
      if extMatPreview then
        extMatPreview:renderWorld(extDimRdr)
      end
    else
      if matPreview then
        matPreview:renderWorld(dimRdr)
      end
    end
  end
end

local function propertyUndo(actionData)
  local obj = scenetree.findObjectById(actionData.objectId)
  if obj then
    setProperty(obj, actionData.property, actionData.layer, actionData.oldValue)
  end
  if o.layer[0] ~= actionData.layer then
    o.layer[0] = actionData.layer
  end
  tempUndoValue = nil
end

local function propertyRedo(actionData)
  local obj = scenetree.findObjectById(actionData.objectId)
  if obj then
    setProperty(obj, actionData.property, actionData.layer, actionData.newValue)
  end
  tempUndoValue = nil
end

local function setPropertyWithUndo(property, layer, value)
  editor.history:commitAction(
    "SetMaterialProperty_" .. property .. "_layer" .. tostring(layer),
    {
      objectId = currentMaterial:getId(),
      property =  property,
      layer = layer,
      newValue = value,
      oldValue = tempUndoValue or currentMaterial:getField(property, layer)
    },
    propertyUndo,
    propertyRedo
  )
  tempUndoValue = nil
end

local function dragDropTarget(property, layer)
  if im.BeginDragDropTarget() then
    local payload = im.AcceptDragDropPayload("ASSETDRAGDROP")
    if payload~=nil then
      assert(payload.DataSize == ffi.sizeof"char[2048]")
      local data = ffi.string(ffi.cast("char*",payload.Data))
      -- editor.logInfo(logTag .. "Setting property '" .. property .. "' on layer '" .. tostring(layer or o.layer[0]) .. "' to .. '" .. data .. "'")
      setPropertyWithUndo(property, layer or o.layer[0], data)
    end
    im.EndDragDropTarget()
  end
end

local function saveCurrentMaterial()
  scenetree.matLuaEd_PersistMan:setDirty(currentMaterial, '')
  scenetree.matLuaEd_PersistMan:saveDirty()
  v.dirtyMaterials[currentMaterial:getField("name", 0)] = nil
  editor.logInfo(logTag .. "Material '" .. currentMaterial:getName() .. "' has been saved.")
  editor.showNotification("Material '" .. currentMaterial:getName() .. "' has been saved.")

  core_jobsystem.create(mapTagsJob, 1)
end

local function saveAllDirtyMaterials()
  for matName, _ in pairs(v.dirtyMaterials) do
    local mat = scenetree.findObject(matName)
    if mat then
      scenetree.matLuaEd_PersistMan:setDirty(mat, '')
    end
    v.dirtyMaterials[matName] = nil
  end
  scenetree.matLuaEd_PersistMan:saveDirty()
  editor.logInfo(logTag .. 'All dirty materials have been saved.')
  editor.showNotification("All dirty materials have been saved.")

  core_jobsystem.create(mapTagsJob, 1)
end

local function updateExtMaterialPreviewMesh()
  extMatPreview:setObjectModel(previewMeshes[previewMeshIndex[0] + 1].path)
  extMatPreview:setMaterial(currentMaterial)
  extMatPreview:setRenderState(false,false,false,false,false,false)
  extMatPreview:setCamRotation(0.6, 3.9)
  extMatPreview:fitToShape()
  extMatPreview:renderWorld(extDimRdr)
end

local function getPreviewMeshes()
  previewMeshes = FS:findFiles(previewMeshesPath, "*.dae", -1, true, false)
  local previewMeshNames = {}
  for index, filePath in ipairs(previewMeshes) do
    local _, file, _ = path.splitWithoutExt(filePath)
    previewMeshes[index] = {path = filePath, name = file}
    table.insert(previewMeshNames, file)
  end
  previewMeshNamesPtr = im.ArrayCharPtrByTbl(previewMeshNames)
  previewMeshIndex[0] = 0
  updateExtMaterialPreviewMesh()
end

local function getGroundmodels()
  local sortFunc = function(a,b) return string.lower(a) < string.lower(b) end
  groundModels = tableKeys(core_environment.groundModels) ---
  table.sort(groundModels, sortFunc)
end

local function isMapHovered(tex, path, absPath)
  if im.IsItemHovered() then
    if #absPath > 0 then
      im.BeginTooltip()
      im.PushTextWrapPos(im.GetFontSize() * 35.0)
      if path ~= absPath then im.TextUnformatted(path) end
      im.TextUnformatted(absPath)
      im.TextUnformatted(string.format("Dimensions: %d x %d\nFormat: %s", tex.size.x, tex.size.y, tex.format))
      im.PopTextWrapPos()
      im.EndTooltip()
    end
  end
end

local function deleteMapButton(label, property, layer)
  local layer = layer or o.layer[0]
  im.PushID1(property .. layer .. '_RemoveMapButton')
  if editor.uiIconImageButton(
    editor.icons.material_texturemap_remove,
    im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight)
  ) then
    setPropertyWithUndo(property, layer, "")
  end
  im.tooltip("Remove " .. label)
  im.PopID()
end

-- Widgets
local function inputText(label, property, layer, setOnEditEndedOnly, widthMod, onEditEndedCallback)
  layer = layer or o.layer[0]
  tempBoolPtr[0] = false

  if label then
    im.TextUnformatted(label)
    im.SameLine()
  end
  im.PushItemWidth(im.GetContentRegionAvailWidth() + (widthMod or 0))
  if editor.uiInputText(
    "##" .. property .. tostring(layer),
    editor.getTempCharPtr(currentMaterial:getField(property, layer)),
    nil,
    im.InputTextFlags_AutoSelectAll,
    nil,
    nil,
    tempBoolPtr
  ) then
    if not setOnEditEndedOnly or setOnEditEndedOnly == false then
      setProperty(nil, property, layer, editor.getTempCharPtr())
    end
  end
  im.PopItemWidth()

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(property, layer, editor.getTempCharPtr())
    if onEditEndedCallback and type(onEditEndedCallback) == "function" then
      onEditEndedCallback()
    end
  end
end

local function imageButton(label, property, layer, additionalGuiFn)
  layer = layer or o.layer[0]
  local imgPath = currentMaterial:getField(property, layer)
  local absPath = imgPath
  local isTaggedTexture = string.startswith(imgPath, '@')
  -- Check if path is absolute or relative (exclude tagged textures)
  if absPath ~= "" and not isTaggedTexture then
    absPath = (string.find(absPath, "/") ~= nil and absPath or (currentMaterial:getPath() .. absPath))
    if absPath ~= imgPath then
      editor.logInfo(logTag .. string.format([[
Changed texture path from '%s' to '%s' for material '%s'!
Texture paths should not rely on the path of the material file. This feature will be deprecated soon.
Hit the "Save material" button to save the changes to the material.]],
        imgPath, absPath, currentMaterial:getName())
      )
      setProperty(nil, property, layer, absPath)
    end
  end

  local function openFileDialog()
    editor_fileDialog.openFile(
      function(data)
        if absPath ~= data.filepath then
          setPropertyWithUndo(property, layer, data.filepath)
        end
        lastPath = data.path
      end,
      {{"Any files", "*"},{"Images",{".png", ".dds", ".jpg"}},{"DDS",".dds"},{"PNG",".png"},{"Color maps",".color.png"}, {"Normal maps",".normal.png"}, {"Data maps",".data.png"}},
      false,
      -- Open up lastPath dir in case there's no texture path set
      -- (absPath == "" and lastPath or path.splitWithoutExt(absPath)),
      -- Open up material's dir in case there's no texture path set
      (absPath == "" and (path.splitWithoutExt(currentMaterial:getFilename()) or lastPath) or path.splitWithoutExt(absPath)),
      true
    )
  end

  im.TextUnformatted((label or property))
  inputText("Path", property, layer, true, -(2*v.inputWidgetHeight * im.uiscale[0] + 2*v.style.ItemSpacing.x + 10))
  im.SameLine()
  if editor.uiIconImageButton(
    editor.icons.folder,
    im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight)
  ) then
    openFileDialog()
  end
  im.tooltip("Open file dialog")
  im.SameLine()
  deleteMapButton(label, property, layer)

  local texture = editor.getTempTextureObj(absPath)
  local size = im.ImVec2(options.thumbnailSize, options.thumbnailSize)
  if texture and texture.size.x ~= 0 and texture.size.y ~= 0 then
    local x = options.thumbnailSize * texture.size.x / texture.size.y
    local y = options.thumbnailSize
    local mul = 1
    if x > im.GetContentRegionAvailWidth() then
      mul = im.GetContentRegionAvailWidth()/x
    end
    size.x = x * mul
    size.y = y * mul
  end

  if additionalGuiFn then
    im.Columns(2, property .. tostring(layer))
    im.SetColumnWidth(0, size.x + v.style.WindowPadding.x)
    im.SetCursorPosX(im.GetCursorPosX() - v.style.ItemSpacing.x)
  end

  im.PushID1(property .. tostring(layer))
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
  im.PopID()
  dragDropTarget(property, layer)
  isMapHovered(editor.getTempTextureObj(), imgPath, absPath)

  if additionalGuiFn then
    im.NextColumn()
    if im.GetContentRegionAvailWidth() > 160 then
      additionalGuiFn()
      im.Columns(1)
    else
      im.Columns(1)
      additionalGuiFn()
    end
  end
end

local function fileWidget(label, property, layer, fileTypes, columnsId)
  layer = layer or o.layer[0]
  if columnsId then im.Columns(2, columnsId) end
  im.TextUnformatted((label or property))
  if columnsId then im.NextColumn() end

  local function openFileDialog()
    editor_fileDialog.openFile(
      function(data)
        if currentMaterial:getField(property, layer) ~= data.filepath then
          setPropertyWithUndo(property, layer, data.filepath)
        end
        lastPath = data.path
      end,
      fileTypes,
      false,
      lastPath,
      true
    )
  end

  inputText(nil, property, layer, true, -(2*v.inputWidgetHeight * im.uiscale[0] + 2*v.style.ItemSpacing.x  + 10))
  im.SameLine()
  if editor.uiIconImageButton(
    editor.icons.folder,
    im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight)
  ) then
    openFileDialog()
  end
  im.tooltip("Open file dialog")
  im.SameLine()
  deleteMapButton(label, property, layer)

  if columnsId then
    im.NextColumn()
    im.Columns(1)
  end
end

local function colorEdit4(label, property, id, layer, labelSameLine)
  layer = layer or o.layer[0]
  if label and #label > 0 then
    im.TextUnformatted(label)
    if labelSameLine then im.SameLine() end
  end
  -- im.SameLine()
  tempBoolPtr[0] = false
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  if editor.uiColorEdit4(
    "##rgb_" .. (id or property) .. tostring(layer),
    editor.getTempFloatArray4_StringString(currentMaterial:getField(property, layer)),
    im.flags(im.ColorEditFlags_AlphaPreviewHalf, im.ColorEditFlags_AlphaBar, im.ColorEditFlags_HDR),
    tempBoolPtr
  ) then
    setProperty(nil, property, layer, editor.getTempFloatArray4_StringString())
  end

  -- Additional HSV input fields.
  -- tempBoolPtr[0] = false
  -- if editor.uiColorEdit4(
  --   "##hsv" .. (id or property),
  --   editor.getTempFloatArray4_StringString(currentMaterial:getField(property, layer)),
  --   im.flags(im.ColorEditFlags_NoSmallPreview, im.ColorEditFlags_HSV, im.ColorEditFlags_HDR, im.ColorEditFlags_NoAlpha),
  --   tempBoolPtr
  -- ) then
  --   setProperty(nil, property, layer, editor.getTempFloatArray4_StringString())
  -- end

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(property, layer, editor.getTempFloatArray4_StringString())
    tempBoolPtr[0] = false
  end
  im.PopItemWidth()
end

local function sliderInt(label, property, min, max, string_format, layer)
  layer = layer or o.layer[0]
  tempBoolPtr[0] = false
  im.TextUnformatted(label)
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  if editor.uiSliderInt(
    "##" .. property .. tostring(layer),
    editor.getTempInt_StringString(currentMaterial:getField(property, layer)),
    min or 0,
    max or 1,
    string_format or "%d",
    tempBoolPtr
  ) then
    setProperty(nil, property, layer, editor.getTempInt_StringString())
  end

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(property, layer, editor.getTempInt_StringString())
    tempBoolPtr[0] = false
  end
  im.PopItemWidth()
end

local function sliderFloat(label, property, min, max, string_format, layer)
  layer = layer or o.layer[0]
  tempBoolPtr[0] = false
  im.TextUnformatted(label)
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  if editor.uiSliderFloat(
    "##" .. property .. tostring(layer),
    editor.getTempFloat_StringString(currentMaterial:getField(property, layer)),
    min or 0,
    max or 1,
    string_format or "%.3f",
    nil,
    tempBoolPtr
  ) then
    setProperty(nil, property, layer, editor.getTempFloat_StringString())
  end

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(property, layer, editor.getTempFloat_StringString())
    tempBoolPtr[0] = false
  end
  im.PopItemWidth()
end

local function checkbox(label, property, layer, tooltip)
  layer = layer or o.layer[0]
  im.TextUnformatted(label)
  if tooltip then
    im.ShowHelpMarker(tooltip, true)
  end
  im.SameLine()
  if im.Checkbox(
    "##" .. property .. tostring(layer),
    editor.getTempBool_StringString(currentMaterial:getField(property, layer))
  ) then
    setPropertyWithUndo(property, layer, editor.getTempBool_StringString())
  end
end

local function checkboxFlag(label, property, hex, layer)
  layer = layer or o.layer[0]
  local animFlags = tobit(currentMaterial:getField(property, layer))
  im.TextUnformatted(label)
  im.SameLine()
  if im.Checkbox(
    "##" .. label .. property .. tostring(layer),
    editor.getTempBool_StringString((band(animFlags, hex) == hex))
  ) then
    setPropertyWithUndo(property, layer, "0x" .. tohex(bxor(animFlags, hex)))
  end
end

local function radio(label, labelValue, property, value, layer)
  layer = layer or o.layer[0]
  if im.RadioButton1(labelValue .. "##" .. label .. tostring(layer), (currentMaterial:getField(property, layer) == value)) then
    setPropertyWithUndo(property, layer, value)
  end
end

local function inputFloat(label, property, float_step, float_step_fast, string_format, layer, tooltip)
  layer = layer or o.layer[0]
  tempBoolPtr[0] = false
  im.TextUnformatted(label)
  if tooltip then
    im.ShowHelpMarker(tooltip, true)
  end
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  if editor.uiInputFloat(
    "##" .. property .. tostring(layer),
    editor.getTempFloat_StringString(currentMaterial:getField(property, layer)),
    float_step or 0.01,
    float_step_fast or 0.1,
    string_format or "%.2f",
    nil,
    tempBoolPtr
  ) then
    setProperty(nil, property, layer, editor.getTempFloat_StringString())
  end

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(property, layer, editor.getTempFloat_StringString())
    tempBoolPtr[0] = false
  end
  im.PopItemWidth()
end

local function inputFloat2(label, property, string_format, layer)
  layer = layer or o.layer[0]
  tempBoolPtr[0] = false
  im.TextUnformatted(label)
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  if editor.uiInputFloat2(
    "##" .. property .. tostring(layer),
    editor.getTempFloatArray2_StringString(currentMaterial:getField(property, layer)),
    string_format or "%.2f",
    nil,
    tempBoolPtr
  ) then
    setProperty(nil, property, layer, editor.getTempFloatArray2_StringString())
  end

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(property, layer, editor.getTempFloatArray2_StringString())
    tempBoolPtr[0] = false
  end
  im.PopItemWidth()
end

local function sliderFloat2(label, labelA, labelB, property, min, max, string_format, layer)
  layer = layer or o.layer[0]
  if label then im.TextUnformatted(label) end
  im.TextUnformatted(labelA)
  local fltArr2 = editor.getTempFloatArray2_StringString(currentMaterial:getField(property, layer))
  local valueA = editor.getTempFloat_StringString(fltArr2[0])
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  tempBoolPtr[0] = false
  if editor.uiSliderFloat(
    "##" .. property .. labelA .. tostring(layer),
    valueA,
    min or 0,
    max or 1,
    string_format or "%.3f",
    nil,
    tempBoolPtr
  ) then
    fltArr2[0] = valueA[0]
    setProperty(nil, property, layer, editor.getTempFloatArray2_StringString())
  end

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(property, layer, editor.getTempFloatArray2_StringString())
    tempBoolPtr[0] = false
  end
  im.PopItemWidth()

  local valueB = editor.getTempFloat_StringString(fltArr2[1])
  im.TextUnformatted(labelB)
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  tempBoolPtr[0] = false
  if editor.uiSliderFloat(
    "##" .. property .. labelB .. tostring(layer),
    valueB,
    min or 0,
    max or 1,
    string_format or "%.3f",
    nil,
    tempBoolPtr
  ) then
    fltArr2[1] = valueB[0]
    setProperty(nil, property, layer, editor.getTempFloatArray2_StringString())
  end

  if tempBoolPtr[0] == true then
    setPropertyWithUndo(property, layer, editor.getTempFloatArray2_StringString())
    tempBoolPtr[0] = false
  end
  im.PopItemWidth()
end

local function combo(label, property, items, layer, columnsId)
  layer = layer or o.layer[0]
  local index = -1
  local field = currentMaterial:getField(property, layer)
  for k, v in pairs(items) do
    if v == field then
      index = (k - 1)
      break
    end
  end
  local cptr = im.ArrayCharPtrByTbl(items)
  if columnsId then im.Columns(2, columnsId) end
  im.TextUnformatted(label)
  if columnsId then
    im.NextColumn()
  else
    im.SameLine()
  end
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  if im.Combo1("##" .. label .. property .. tostring(layer), editor.getTempInt_StringString(index), cptr) then
    setPropertyWithUndo(property, layer, items[tonumber(editor.getTempInt_StringString()) + 1])
  end
  im.PopItemWidth()
  if columnsId then im.Columns(1) end
end

local function text(property, layer)
  im.TextUnformatted(currentMaterial:getField(property, layer or o.layer[0]))
end
-- ~Widgets

-- Cubemaps
local function cubemapFaceUndo(actionData)
  local obj = scenetree.findObject(actionData.objectId)
  if obj then
    obj:setField(actionData.property, actionData.layer, actionData.oldValue)
  end
end

local function cubemapFaceRedo(actionData)
  local obj = scenetree.findObject(actionData.objectId)
  if obj then
    obj:setField(actionData.property, actionData.layer, actionData.newValue)
  end
end

local function dragDropTargetCubemapFace(index)
  if im.BeginDragDropTarget() then
    local payload = im.AcceptDragDropPayload("ASSETDRAGDROP")
    if payload~=nil then
      assert(payload.DataSize == ffi.sizeof"char[2048]")
      local data = ffi.string(ffi.cast("char*",payload.Data))
      local oldValue = selectedCubemapObj:getField("cubeFace", index)
      if oldValue ~= data then
        editor.history:commitAction(
          "SetCubeMapFace_" .. tostring(index),
          {
            objectId = selectedCubemapObj:getId(),
            property =  "cubeFace",
            layer = index,
            newValue = data,
            oldValue = selectedCubemapObj:getField("cubeFace", index)
          },
          cubemapFaceUndo,
          cubemapFaceRedo
        )
        cubemapDirty = true
      end
    end
    im.EndDragDropTarget()
  end
end

-- TODO: Check if cubemapIndex exceeds size of table
local function selectCubemap(cubemapIndex)
  local cubemapName = cubemaps[cubemapIndex or 1]
  ffi.copy(cubemapNamePtr, cubemapName)
  selectedCubemapObj = scenetree.findObject(cubemapName)
end

local function selectLastCubemapOrFirst()
  -- Gets previously selected cubemap and selects it
  local selectionIndex = 1
  for index, cubemap in ipairs(cubemaps) do
    if selectedCubemapObj:getName() == cubemap then
      selectionIndex = index
      break
    end
  end
  selectCubemap(selectionIndex)
end

local function refreshCubemaps()
  cubemaps = scenetree.findClassObjects("CubemapData")
end

local function saveCubemap()
  selectedCubemapObj:setName(ffi.string(cubemapNamePtr))
  scenetree.matLuaEd_PersistMan:setDirty(selectedCubemapObj, "")
  scenetree.matLuaEd_PersistMan:saveDirtyObject(selectedCubemapObj)

  refreshCubemaps()
  selectLastCubemapOrFirst()
end

local function newCubemap()
  local newCubemap = editor.createCustomClassObject("CubemapData")
  if newCubemap then
    -- Updates list
    refreshCubemaps()
    -- Selects new cubemap
    ffi.copy(cubemapNamePtr, newCubemap:getName())
    selectedCubemapObj = newCubemap
  end
end

local function deleteCubemap()
  local parent = selectedCubemapObj:getGroup()
  if parent then
    parent:removeObject(selectedCubemapObj)
  end
  selectedCubemapObj:delete()
  refreshCubemaps()
  selectCubemap()
end

local function cubemapFaceImageButton(index, tooltip)
  im.PushID1("cubeFace" .. tostring(index))
  if im.ImageButton(
    editor.getTempTextureObj(selectedCubemapObj:getField("cubeFace", index)).texId,
    im.ImVec2(cubemapFaceThumbnailSize, cubemapFaceThumbnailSize),
    im.ImVec2Zero,
    im.ImVec2One,
    1,
    im.ImColorByRGB(255,255,255,255).Value,
    im.ImColorByRGB(255,255,255,255).Value
  ) then
    editor_fileDialog.openFile(
      function(data)
        local oldValue = selectedCubemapObj:getField("cubeFace", index)
        if oldValue ~= data.filepath then
          editor.history:commitAction(
            "SetCubeMapFace_" .. tostring(index),
            {
              objectId = selectedCubemapObj:getId(),
              property =  "cubeFace",
              layer = index,
              newValue = data.filepath,
              oldValue = selectedCubemapObj:getField("cubeFace", index)
            },
            cubemapFaceUndo,
            cubemapFaceRedo
          )
        end
      end,
      {{"Any files", "*"},{"Images",{".png", ".dds", ".jpg"}},{"DDS",".dds"},{"PNG",".png"},{"JPG",".jpg"}},
      false,
      path.splitWithoutExt(selectedCubemapObj:getField("cubeFace", index)),
      true
    )
  end
  im.PopID()
  dragDropTargetCubemapFace(index)

  if tooltip then
    im.tooltip(tooltip .. "\n" .. selectedCubemapObj:getField("cubeFace", index))
  else
    im.tooltip(selectedCubemapObj:getField("cubeFace", index))
  end
end

local function createCubemapWindowGui()
  if editor.beginWindow(createCubemapWindowName, "Create Cubemap") then
    -- get cubemaps
    if not cubemaps then
      refreshCubemaps()
      selectCubemap()
    end
    im.Columns(2, "CreateCubemapColumn")

    im.SameLine()
    if im.SmallButton("Save") then
      saveCubemap()
    end
    if im.IsItemHovered() then
      im.SetTooltip("Save modifications of selected Cubemap")
    end
    im.SameLine()
    if im.SmallButton("New") then
      newCubemap()
    end
    if im.IsItemHovered() then
      im.SetTooltip("Create a new Cubemap under selected SceneTree group")
    end
    im.SameLine()
    if im.SmallButton("Delete") then
      deleteCubemap()
    end
    if im.IsItemHovered() then
      im.SetTooltip("Delete selected Cubemap")
    end

    if im.BeginChild1("CreateCubemapsLeftChild", nil, true) then
      for index, cubemap in ipairs(cubemaps) do
        im.PushStyleColor2(im.Col_Button, (selectedCubemapObj:getName() == cubemap) and im.GetStyleColorVec4(im.Col_ButtonActive) or im.ImVec4(1,1,1,0))
        im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
        if im.Button(cubemap) then
          selectCubemap(index)
        end
        im.PopItemWidth()
        im.PopStyleColor()
      end
    end
    im.EndChild()

    im.NextColumn()

    im.TextUnformatted("Name:")
    im.SameLine()
    im.InputText("##cubemapName", cubemapNamePtr, nil, im.flags(im.InputTextFlags_CharsNoBlank))

    -- local childSize = im.ImVec2(0, )
    cubemapFaceThumbnailSize = (im.GetContentRegionAvailWidth() - (3 * v.style.ItemSpacing.x) - 8) / 4 -- -8 = remove 4 times the ImageButton border size (2px)

    -- -Y Back[2]
    im.SetCursorPosX(im.GetCursorPosX() + cubemapFaceThumbnailSize + v.style.ItemSpacing.x + 2) -- +2 = ImageButton border
    cubemapFaceImageButton(2, "-Y Back[2]")
    -- -X Left[1] / +Z Top[4] / +X Right[0] / -Z Bottom[5]
    cubemapFaceImageButton(1, "-X Left[1]")
    im.SameLine()
    cubemapFaceImageButton(4, "+Z Top[4]")
    im.SameLine()
    cubemapFaceImageButton(0, "+X Right[0]")
    im.SameLine()
    cubemapFaceImageButton(5, "-Z Bottom[5]")
    -- +Y Front[3]
    im.SetCursorPosX(im.GetCursorPosX() + cubemapFaceThumbnailSize + v.style.ItemSpacing.x + 2) -- +2 = ImageButton border
    cubemapFaceImageButton(3, "+Y Front[3]")

    if im.Button("Select") then
      if currentMaterial:getField("cubemap", 0) ~= selectedCubemapObj:getName() then
        setPropertyWithUndo("cubemap", 0, selectedCubemapObj:getName())
      end
      editor.hideWindow(createCubemapWindowName)
    end
    im.SameLine()
    if im.Button("Cancel") then
      editor.hideWindow(createCubemapWindowName)
    end

    im.Columns(1)
  end
  editor.endWindow()
end

local function setMaterialPropertiesColumnWidth()
  if setWidth > 0 then
    im.SetColumnWidth(0, 110)
    setWidth = setWidth - 1
  end
end

local function cubemap()
  im.Columns(2, "Material Properties")
  setMaterialPropertiesColumnWidth()
  im.TextUnformatted("Reflection Mode")
  im.NextColumn()
  im.PushItemWidth(120)
  local currentReflectionMode = o.reflectionMode[0]
  if im.Combo2("##reflectionMode", o.reflectionMode, "None\0Level\0Cubemap\0\0") then
    if o.reflectionMode[0] == 0 and currentReflectionMode ~= 0 then
      setProperty(nil, "cubemap", 0, "")
      setProperty(nil, "dynamicCubemap", 0, "0")
    elseif o.reflectionMode[0] == 1 and currentReflectionMode ~= 1 then
      setProperty(nil, "cubemap", 0, "")
      setProperty(nil, "dynamicCubemap", 0, "1")
    elseif o.reflectionMode[0] == 2 and currentReflectionMode ~= 2 then
      setProperty(nil, "cubemap", 0, "")
      setProperty(nil, "dynamicCubemap", 0, "0")
    end
  end
  im.PopItemWidth()
  im.tooltip("None = Material doesn't use any reflection information\nLevel = Material uses reflection information from the level\nCubemap = Material uses reflection information from a custom cubemap")

  if o.reflectionMode[0] == 2 then
    createCubemapWindowGui()

    im.SameLine()
    local cubemapName = currentMaterial:getField("cubemap", 0)
    if im.Button("Choose") then
      refreshCubemaps()
      editor.showWindow(createCubemapWindowName)
      if cubemapName ~= "" then
        for index, name in ipairs(cubemaps) do
          if name == cubemapName then
            selectCubemap(index)
            break
          end
        end
      else
        selectCubemap()
      end
    end
    im.NextColumn()
    im.TextUnformatted("Cubemap")
    im.NextColumn()
    im.TextUnformatted(cubemapName == "" and "none" or cubemapName)
    if cubemapName == "" then
      im.TextColored(editor.color.warning.Value, "Please choose a cubemap.\nReflection won't work without a cubemap.")
    end
  end
  im.Columns(1)
end
-- ~Cubemap

-- old material editor
local function layer()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  if im.Combo2("##MaterialEditorLayer", o.layer, "Layer 0\0Layer 1\0Layer 2\0Layer 3\0\0") then
    if dbg then editor.logInfo(logTag .. 'Layer has changed!') end
    updateMaterialProperties()
  end
  im.PopItemWidth()
end

local function materialInfo()
  if im.CollapsingHeader1("Material Info", im.TreeNodeFlags_DefaultOpen) then
    im.Columns(2, "Material Properties")
    setMaterialPropertiesColumnWidth()

    -- Name
    im.TextUnformatted("Name")
    im.NextColumn()
    text("name", 0)
    im.NextColumn()

    -- MapTo
    im.TextUnformatted("Map To")
    im.NextColumn()
    inputText(nil, "mapTo", 0, true, -(v.inputWidgetHeight * im.uiscale[0] + 10))
    im.SameLine()
    if editor.uiIconImageButton(
      editor.icons.material_pick_mapto,
      im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight),
      pickMaterialFromObject and editor.color.white.Value or editor.color.grey.Value
    ) then
      pickingFromObjectMode = pickingFromObjectMode_enum.existing_material
      pickMaterialFromObject = not pickMaterialFromObject
      if pickMaterialFromObject == true then
        formerEditMode = editor.editMode
        editor.selectEditMode(editMode_PickMapTo())
      else
        editor.selectEditMode(formerEditMode)
        formerEditMode = nil
      end
    end
    im.tooltip("Enable to pick a material from a mesh.")
    im.NextColumn()

    -- Path
    local filepath = currentMaterial:getFilename()
    local dir, filename, ext = "", "", ""
    if filepath then
      dir, filename, ext = path.splitWithoutExt(filepath)
    end

    im.TextUnformatted("Directory")
    im.NextColumn()
    im.TextUnformatted(dir)
    im.NextColumn()

    im.TextUnformatted("Filename")
    im.NextColumn()
    im.TextUnformatted(string.format("%s.%s", filename, ext))
    im.NextColumn()

    -- Version
    im.TextUnformatted("Version")
    im.NextColumn()
    im.TextUnformatted(currentMaterial:getField('version', 0))
    im.SameLine()

    local version = tonumber(currentMaterial:getField('version', 0))
    if version and version < 1.5 then
      im.PushStyleColor2(im.Col_Button, im.ImVec4(0, .5, 0, 0.5))
      im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(0, .7, 0, 0.6))
      im.PushStyleColor2(im.Col_ButtonActive, im.ImVec4(0, .8, 0, 0.7))
      if im.Button("Switch to V1.5 (PBR)") then
        -- Disabled deprecated 'glow' feature when switching to new materials
        setProperty(nil, 'glow', 0, '0')
        currentMaterial:setField('version', 0, '1.5')
      end
      im.PopStyleColor(3)
    end

    -- disabled for now
    if version and version > 1 then
      if im.Button("Revert to V1") then
        currentMaterial:setField('version', 0, '1')
      end
    end

    im.NextColumn()

    -- Active Layers
    if version and version > 1 then
      im.TextUnformatted("active layers")
      im.NextColumn()
      im.TextUnformatted(tostring(currentMaterial.activeLayers) .. ' of ' .. tostring(maxLayers))
      im.SameLine()

      local disabled = currentMaterial.activeLayers >= maxLayers
      if disabled then im.BeginDisabled() end
      if editor.uiIconImageButton(editor.icons.add, im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight)) then
        if currentMaterial.activeLayers < maxLayers then
          setPropertyWithUndo('activeLayers', 0, currentMaterial.activeLayers + 1)
        end
      end
      if disabled then im.EndDisabled() end
      im.tooltip(currentMaterial.activeLayers >= maxLayers and "You can't have more than " .. tostring(maxLayers) .. " layers" or "Add layer")
      im.SameLine()
      disabled = currentMaterial.activeLayers <= 1
      if disabled then im.BeginDisabled() end
      if editor.uiIconImageButton(editor.icons.remove, im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight)) then
        if currentMaterial.activeLayers > 1 then
          setPropertyWithUndo('activeLayers', 0, currentMaterial.activeLayers - 1)
        end
      end
      if disabled then im.EndDisabled() end
      im.tooltip(currentMaterial.activeLayers <= 1 and "You have to have at least one layer" or "Remove layer")
      im.NextColumn()
    end

    --
    im.Columns(1)
  end
end

local function basicTextureMaps()
  if im.CollapsingHeader1("Basic Properties", im.TreeNodeFlags_DefaultOpen) then
    -- Color Map
    imageButton("Color Map", "diffuseMap", nil, function()
      -- Color Map Color
      colorEdit4("Color", "diffuseColor", nil, nil, true)
      local availWidth = im.GetContentRegionAvailWidth()
      checkbox("Instance Diffuse", "instanceDiffuse", nil, "If enabled the material multiplies the color value by the SimObject's instanceColor value.")
      if availWidth > 240 then
        im.SameLine(nil, 20)
      end
      -- Vertex Color
      checkbox("Vertex Color", "vertColor")
    end)
    im.Separator()
    -- Normal Map
    imageButton('Normal Map', "normalMap")
    im.Separator()
    -- Specular Map
    imageButton("Specular Map", "specularMap")
  end
end

local function advancedTextureMaps()
  if im.CollapsingHeader1("Advanced Properties") then
    -- Reflectivity Map
    imageButton("Reflectivity Map", "reflectivityMap", nil, function()
      sliderFloat("Reflectivity Map Factor", "reflectivityMapFactor", 0, 1)
      if currentMaterial:getField("reflectivityMap", o.layer[0]) ~= "" and currentMaterial:getField("cubemap", 0) == "" then
        im.TextColored(editor.color.warning.Value, "The cubemap for this material is not set.\nThe reflectivity map won't work without a cubemap assigned to this material.")
      end
    end)
    im.Separator()

    -- Detail Map
    imageButton("Detail Map", "detailMap", nil, function()
      -- Detail Map Scale
      inputFloat2("Scale:", "detailScale", "%.2f")
    end)
    im.Separator()

    -- Detail Normal Map
    imageButton("Detail Normal Map", "detailNormalMap", nil, function()
      -- Detail Normal Map Strength
      inputFloat("Detail Normal Map Strength", "detailNormalMapStrength")
    end)
    im.Separator()

    -- Overlay Map
    imageButton("Overlay Map", "overlayMap", nil, function()
      im.TextUnformatted("This texture uses the 2nd UV channel")
    end)
    im.Separator()

    -- Color Palette Map
    imageButton("Color Palette Map", "colorPaletteMap", nil, function()
      combo("Color Palette Map UV Layer", "colorPaletteMapUV", {"0", "1"})
    end)
    im.Separator()

    -- Opacity Map
    imageButton("Opacity Map", "opacityMap")
  end
end

local function deprecatedFeatures()
  if im.CollapsingHeader1("Deprecated Features") then
    -- Vertex Lit
    checkbox("Vertex Lit", "vertLit", nil, "Enables the use of vertex lightning for this layer.")

    -- TODO
    -- Subsurface
    checkbox("Sub Surface", "subSurfacaae", nil, "Subsurafece.")

    -- Minnaert Constant
    inputFloat("Minnaert Constant", "minnaertConstant", 0.1, 1, "%.1f")
  end
end

local function lightingProperties()
  if im.CollapsingHeader1("Lighting Properties") then
    -- Specular
    checkbox("Pixel Specular", "pixelSpecular")
    colorEdit4("Specular Color", 'specular')
    sliderFloat("Roughness Factor", "roughnessFactor", 0, 1)
    -- Emissive
    checkbox("Emisive", "emissive")
    -- Glow
    checkbox("Glow", "glow")
    colorEdit4("Glow Factor", 'glowFactor')
    -- Anisotropic Filtering
    checkbox("Anisotropic filtering", "useAnisotropic")
  end
end

local function animationProperties(layer)

  if im.CollapsingHeader1("Animation Properties" .. (layer and "##" .. tostring(layer) or "")) then
    -- Rotation Animation
    checkboxFlag("Rotation Animation", "animFlags", enum_animFlags.rotate, layer)
    sliderFloat2("Rotation Pivot Offset", "U", "V", "rotPivotOffset", -1, 0, nil, layer)
    sliderFloat("Rotation Animation Speed", "rotSpeed", nil, nil, nil, layer)
    im.Separator()
    -- Scroll Animation
    checkboxFlag("Scroll Animation ", "animFlags", enum_animFlags.scroll, layer)
    sliderFloat2(nil, "U", "V", "scrollDir", -1, 1, nil, layer)
    sliderFloat("Scroll Animation Speed", "scrollSpeed", 0, 10, nil, layer)
    im.Separator()

    -- Wave Animation
    checkboxFlag("Wave Animation", "animFlags", enum_animFlags.wave, layer)
    im.TextUnformatted("Wave Type")
    radio("Wave Type", "Sin", "waveType", "Sin", layer)
    im.SameLine()
    radio("Wave Type", "Square", "waveType", "Square", layer)
    im.SameLine()
    radio("Wave Type", "Triangle", "waveType", "Triangle", layer)
    im.SameLine()
    checkboxFlag("Scale", "animFlags", enum_animFlags.scale, layer)
    sliderFloat("Amplitude", "waveAmp", nil, nil, nil, layer)
    sliderFloat("Frequency", "waveFreq", 0, 10, nil, layer)
    im.Separator()

    -- Image Sequence
    checkboxFlag("Image Sequence", "animFlags", enum_animFlags.sequence, layer)
    sliderFloat("Frames / Sec", "sequenceFramePerSec", 0, 30, nil, layer)
    sliderFloat("Frames", "sequenceSegmentSize", 0, 100, nil, layer)
  end
end

local function alphaBlendCombo()
  local version = tonumber(currentMaterial:getField('version', 0)) or 1

  local items = version >= 1.5 and {"None", "PreMulAlpha", "Add", "AddAlpha", "LerpAlpha", "Mul", "Sub"} or {"None", "Add", "AddAlpha", "LerpAlpha", "Mul", "Sub"}
  local cptr = im.ArrayCharPtrByTbl(items)

  --Translucent Blend Operation
  local translucent = currentMaterial:getField("translucent", 0)
  local translucentBlendOp = currentMaterial:getField("translucentBlendOp", 0)

  local index = -1
  if translucent == "0" or translucentBlendOp == "None" then
    index = 0
  else
    for k, v in pairs(items) do
      if v == translucentBlendOp then
        index = (k - 1)
        break
      end
    end
  end

  im.TextUnformatted("Alpha Blend Mode")
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
  if im.Combo1("##Alpha Blend Mode_translucent0", editor.getTempInt_StringString(index), cptr) then
    local value = items[tonumber(editor.getTempInt_StringString()) + 1]
    if value == "None" then
      setProperty(currentMaterial, 'translucent', 0, "0")
      setProperty(currentMaterial, 'translucentBlendOp', 0, "None")
    else
      setProperty(currentMaterial, 'translucent', 0, "1")
      setProperty(currentMaterial, 'translucentBlendOp', 0, value)
    end
  end
  im.PopItemWidth()
end

local function advanced()
  if im.CollapsingHeader1("Advanced - All Layers") then

    alphaBlendCombo()

    checkbox("Z-Write", "translucentZWrite", 0)
    im.SameLine()
    checkbox("Receive shadows", "translucentRecvShadows", 0)

    im.Separator()
    -- alphaTest
    checkbox("Alpha Clip", "alphaTest", 0)
    im.SameLine()
    sliderInt("Alpha Clip Threshold", "alphaRef", 0, 255, nil, 0)

    checkbox("Double Sided", "doubleSided", 0)
    im.SameLine()
    checkbox("Invert backface normals", "invertBackFaceNormals", 0)
    checkbox("Cast Shadows", "castShadows", 0)
    im.Separator()

    cubemap()
  end
end

local function annotationWidget()
  local annotations = editor.getAnnotations()
  local annotationsTbl = editor.getAnnotationsTbl()
  local bgColor = nil
  local value = currentMaterial:getField("annotation", 0)
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
  im.Columns(2, "Material Properties")
  im.TextUnformatted("Annotation")
  im.NextColumn()
  im.ColorButton("Annotation color", bgColor, 0, im.ImVec2(25, 19))
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 10)
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
        setPropertyWithUndo('annotation', 0, value)
      end
      if isSelected then
        -- set the initial focus when opening the combo
        im.SetItemDefaultFocus()
      end
    end
    im.EndCombo()
    im.NextColumn()
    im.Columns(1)
  end
  im.PopItemWidth()
end

local function additionalInfo()
  if im.CollapsingHeader1("Additional Info") then
    im.Columns(2, "Material Properties")
    setMaterialPropertiesColumnWidth()
    im.TextUnformatted("Material Tag 0")
    im.NextColumn()
    inputText(nil, "materialTag", 0, true, nil, function() core_jobsystem.create(mapTagsJob, 1) end)
    im.NextColumn()

    im.TextUnformatted("Material Tag 1")
    im.NextColumn()
    inputText(nil, "materialTag", 1, true, nil, function() core_jobsystem.create(mapTagsJob, 1) end)
    im.NextColumn()

    im.TextUnformatted("Material Tag 2")
    im.NextColumn()
    inputText(nil, "materialTag", 2, true, nil, function() core_jobsystem.create(mapTagsJob, 1) end)
    im.NextColumn()
    im.Columns(1)

    im.Separator()

    if groundModels then
      combo("Ground Type", "groundType", groundModels, 0, "Material Properties")
    end

    fileWidget(
      "Annotation Map",
      "annotationMap",
      0,
      {{"Any files", "*"},{"PNG",".png"}},
      "Material Properties"
    )

    annotationWidget()
  end
end

local function materialPropertiesVersion0()
  basicTextureMaps()
  advancedTextureMaps()
  deprecatedFeatures()

  lightingProperties()
  animationProperties()
  advanced()
  additionalInfo()
end

local function materialPropertiesVersion1()
  for i = 1, currentMaterial.activeLayers do
    local lyr = i-1
    if im.CollapsingHeader1("Layer " .. tostring(i), i == 1 and im.TreeNodeFlags_DefaultOpen or nil) then
      im.Indent()

      if im.CollapsingHeader1("Basic Properties##" .. tostring(lyr), im.TreeNodeFlags_DefaultOpen) then
        -- Color Map
        imageButton("BaseColor Map", "diffuseMap", lyr, function()
          colorEdit4("Color", "diffuseColor", nil, lyr, true)
          combo("UV Layer", "diffuseMapUV", {"0", "1"}, lyr)
          local availWidth = im.GetContentRegionAvailWidth()
          checkbox("Instance BaseColor", "instanceDiffuse", lyr, "If enabled the material multiplies the color value by the SimObject's instanceColor value.")
          if availWidth > 240 then
            im.SameLine(nil, 20)
          end
          -- Vertex Color
          checkbox("Vertex Color", "vertColor", lyr)
        end)
        im.Separator()

        -- Color Detail Map
        imageButton("BaseColor Detail Map", "detailMap", lyr, function()
          inputFloat2("Scale:", "detailScale", "%.2f", lyr)
          combo("UV Layer", "detailMapUV", {"0", "1"}, lyr)
        end)
        im.Separator()

        -- Metallic Factor
        imageButton("Metallic Map", "metallicMap", lyr, function()
          sliderFloat("Factor", "metallicFactor", 0, 1, nil, lyr)
          combo("UV Layer", "metallicMapUseUV", {"0", "1"}, lyr)
        end)
        im.Separator()

        -- Normal Map
        imageButton('Normal Map', "normalMap", lyr, function()
          inputFloat("Strength", "normalMapStrength", nil, nil, nil, lyr)
          combo("UV Layer", "normalMapUV", {"0", "1"}, lyr)
        end)
        im.Separator()
        -- Normal Detail Map
        imageButton("Normal Detail Map", "detailNormalMap", lyr, function()
          inputFloat("Normal Detail Map Strength", "detailNormalMapStrength", nil, nil, nil, lyr)
          combo("UV Layer", "normalDetailMapUV", {"0", "1"}, lyr)
        end)
        im.Separator()

        -- Roughness
        imageButton("Roughness Map", "roughnessMap", lyr, function()
          sliderFloat("Factor", "roughnessFactor", 0, 1, nil, lyr)
          combo("UV Layer", "roughnessMapUseUV", {"0", "1"}, lyr)
        end)
        im.Separator()

        -- Opacity Map
        imageButton("Opacity Map", "opacityMap", lyr, function()
          sliderFloat("Factor", "opacityFactor", 0, 1, nil, lyr)
          combo("UV Layer", "opacityMapUV", {"0", "1"}, lyr)
        end)
        im.Separator()

        -- AO Map
        imageButton("Ambient Occlusion Map", "ambientOcclusionMap", lyr, function()
          combo("UV Layer", "ambientOcclusionMapUseUV", {"0", "1"}, lyr)
        end)
        im.Separator()
      end

      if im.CollapsingHeader1("Advanced Properties##" .. tostring(lyr)) then
        -- BaseColor Palette
        imageButton("BaseColor Palette Map", "colorPaletteMap", lyr, function()
          combo("UV Layer", "colorPaletteMapUV", {"0", "1"}, lyr)
        end)
        im.Separator()

        -- Emissive
        imageButton("Emissive Map", "emissiveMap", lyr, function()
          combo("UV Layer", "emissiveMapUseUV", {"0", "1"}, lyr)
        end)
        colorEdit4("Factor", "emissiveFactor", nil, lyr)
        checkbox("Instance Emissive", "instanceEmissive", lyr, "If enabled the material multiplies the color value by the SimObject's instanceColor value.")
        im.Separator()

        -- clear coat
        imageButton("Clear Coat Map", "clearCoatMap", lyr, function()
          sliderFloat("Factor", "clearCoatFactor", 0, 1, nil, lyr)
          sliderFloat("Factor roughness", "clearCoatRoughnessFactor", 0, 1, nil, lyr)
          combo("UV Layer", "clearCoatMapUseUV", {"0", "1"}, lyr)
        end)
        im.Separator()
        imageButton("Clear Coat Bottom Normal Map", "clearCoatBottomNormalMap", lyr, function()
          inputFloat("Strength", "clearCoatBottomNormalMapStrength", nil, nil, nil, lyr)
        end)
        im.Separator()

        -- Anisotropic Filtering
        checkbox("Anisotropic filtering", "useAnisotropicFilter", lyr)
      end

      animationProperties(lyr)
      im.Unindent()
    end
  end

  advanced()
  additionalInfo()
end

local function materialPreview(previewSize)
  if previewSize then
    if extMatPreviewRenderSize ~= previewSize then
      extMatPreviewRenderSize = previewSize
      extDimRdr:set(0, 0, extMatPreviewRenderSize, extMatPreviewRenderSize)
      extMatPreview:renderWorld(extDimRdr)
    end

    local cPosA = im.GetCursorPos()
    extMatPreview:ImGui_Image(extMatPreviewRenderSize, extMatPreviewRenderSize)
    local cPosB = im.GetCursorPos()
    im.SetCursorPos(im.ImVec2(cPosA.x + im.GetStyle().ItemSpacing.y, cPosA.y + im.GetStyle().ItemSpacing.y))
    if editor.uiColorEdit3(
      "##extMaterialPreviewBackgroundColorEdit",
      editor.getTempFloatArray3_TableTable({extMatPreviewBackgroundColor.r/255,extMatPreviewBackgroundColor.g/255,extMatPreviewBackgroundColor.b/255}),
      im.ColorEditFlags_NoInputs
    ) then
      local val = editor.getTempFloatArray3_TableTable()
      extMatPreviewBackgroundColor.r = val[1] * 255
      extMatPreviewBackgroundColor.g = val[2] * 255
      extMatPreviewBackgroundColor.b = val[3] * 255
      extMatPreview.mBgColor = extMatPreviewBackgroundColor
      extMatPreview:renderWorld(extDimRdr)
    end
    im.tooltip("Background Color")
    im.SetCursorPos(cPosB)
  else
    if im.GetContentRegionAvailWidth() ~= matPreviewRenderSize or updateMaterialPreviewRender == true  then
      matPreviewRenderSize = im.GetContentRegionAvailWidth()
      matPreviewRenderSize = matPreviewRenderSize > options.maxMaterialPreviewSize and options.maxMaterialPreviewSize or matPreviewRenderSize
      dimRdr:set(0, 0, matPreviewRenderSize, matPreviewRenderSize)
      matPreview:renderWorld(dimRdr)
    end

    local cPosA = im.GetCursorPos()
    matPreview:ImGui_Image(matPreviewRenderSize, matPreviewRenderSize)
    local cPosB = im.GetCursorPos()
    im.SetCursorPos(im.ImVec2(cPosA.x + im.GetStyle().ItemSpacing.y, cPosA.y + im.GetStyle().ItemSpacing.y))
    if editor.uiColorEdit3(
      "##materialPreviewBackgroundColorEdit",
      editor.getTempFloatArray3_TableTable({matPreviewBackgroundColor.r/255,matPreviewBackgroundColor.g/255,matPreviewBackgroundColor.b/255}),
      im.ColorEditFlags_NoInputs
    ) then
      local val = editor.getTempFloatArray3_TableTable()
      matPreviewBackgroundColor.r = val[1] * 255
      matPreviewBackgroundColor.g = val[2] * 255
      matPreviewBackgroundColor.b = val[3] * 255
      matPreview.mBgColor = matPreviewBackgroundColor
    end
    im.tooltip("Background Color")
    im.SetCursorPos(cPosB)
  end
end

local function drawGui()
  if currentMaterial then
    if editor.isWindowVisible(materialPreviewWindowName) == false then
      if im.CollapsingHeader1("Material Preview", im.TreeNodeFlags_DefaultOpen) then
        materialPreview()
        if im.Button("Open in dedicated window") then
          editor.showWindow(materialPreviewWindowName)
        end
      end
    end

    im.Dummy(im.ImVec2(0,4))
    materialInfo()
    im.Dummy(im.ImVec2(0,4))

    local version = tonumber(currentMaterial:getField("version", 0))
    if version then
      if version >= 2 then
        --
      elseif version >= 1.5 then
        materialPropertiesVersion1()
      else
        layer()
        materialPropertiesVersion0()
      end
    else
      layer()
      materialPropertiesVersion0()
    end
  else
    im.TextUnformatted("No material selected!")
  end
end

local function showMaterialEditor()
  if editor.isWindowVisible(toolWindowName) == false then
    editor.showWindow(toolWindowName)
  else
    focusWindow = true
  end
end

local function getMaterials()
  local sortFunc = function(a,b) return string.lower(a) < string.lower(b) end

  local currentMaterialName = nil
  local materialObjectNames = nil

  if v.materialNameList then
    currentMaterialName = v.materialNameList[v.currentMaterialIndex]
  end

  -- List all materials of the current selected object be it a TSStatic or a ForestItem
  if editor.selection and options and options.updateMaterialListBasedOnSelection == true then
    -- Check if there's a single SceneObject selected.
    if editor.selection.object and #editor.selection.object > 0 then
      materialObjectNames = {}
      local tbl = {}

      for _, objName in ipairs(editor.selection.object) do
        local obj = scenetree.findObject(objName)
        if obj and (obj.___type == "class<TSStatic>" or obj.___type == "class<BeamNGVehicle>") then
          local matNames = obj:getMaterialNames()
          for _, matName in ipairs(matNames) do
            if not tbl[matName] then
              tbl[matName] = 1
            end
          end
        end
      end

      for mat, _ in pairs(tbl) do
        if mat ~= "" then
          table.insert(materialObjectNames, mat)
        end
      end

      if #materialObjectNames == 0 then
        materialObjectNames = scenetree.findClassObjects('Material')
      end
    elseif editor.selection.forestItem and table.getn(editor.selection.forestItem) > 0 then
      materialObjectNames = {}
      local tbl = {}
      for _, forestItem in ipairs(editor.selection.forestItem) do
        local matNames = forestItem:getMaterialNames()
        for _, matName in ipairs(matNames) do
          if not tbl[matName] then
            tbl[matName] = 1
          end
        end
      end

      for mat, _ in pairs(tbl) do
        table.insert(materialObjectNames, mat)
      end
    else -- No object is selected, list all loaded materials.
      materialObjectNames = scenetree.findClassObjects('Material')
    end

    -- Check if selection has any materials applied to it, if not get all available materials.
    if #materialObjectNames == 0 then
      materialObjectNames = scenetree.findClassObjects('Material')
    end
  else
    materialObjectNames = scenetree.findClassObjects('Material')
  end

  local sortedMaterialObjectNames = {}
  local sortedMaterialObjectNamesAtTop = {}

  local textFilterString = string.lower(ffi.string(im.TextFilter_GetInputBuf(matFilter)))

  for k, v in pairs(materialObjectNames) do
    if im.ImGuiTextFilter_PassFilter(matFilter, v) and v then
      if options and options.textFilterResultsWithSameFirstCharAtTop == true and #textFilterString > 0 and string.startswith(string.lower(v), textFilterString) then
        table.insert(sortedMaterialObjectNamesAtTop, v)
      else
        table.insert(sortedMaterialObjectNames, v)
      end
    end
  end

  if tableIsEmpty(sortedMaterialObjectNames) and tableIsEmpty(sortedMaterialObjectNamesAtTop) then
    sortedMaterialObjectNames = deepcopy(materialObjectNames)
  end

  table.sort(sortedMaterialObjectNames, sortFunc)
  table.sort(sortedMaterialObjectNamesAtTop, sortFunc)

  v.materialNameList= {}

  local i = 0
  for k, val in pairs(sortedMaterialObjectNamesAtTop) do
    local mat = scenetree.findObject(val)
    if mat and mat.___type == "class<Material>" then
      if not mat:isAutoGenerated() then
        v.materialNameList[i] = val
        i = i + 1
      end
    end
  end
  for k, val in pairs(sortedMaterialObjectNames) do
    local mat = scenetree.findObject(val)
    if mat and mat.___type == "class<Material>" then
      if not mat:isAutoGenerated() then
        v.materialNameList[i] = val
        i = i + 1
      end
    end
  end

  v.materialNamesPtr = im.ArrayCharPtrByTbl(v.materialNameList)
  v.materialNamesPtrCount = i

  if init == false then
    if editor and editor.getPreference then
      local levelMaterialNames = editor.getPreference("materialEditor.general.levelMaterialNames")
      if levelMaterialNames[getMissionPath()] and levelMaterialNames[getMissionPath()] ~= "" then
        selectMaterialByName(levelMaterialNames[getMissionPath()])
      end
      init = true
    end
  else
    -- Get the previous selected material.
    if currentMaterialName then
      selectMaterialByName(currentMaterialName)
    else
      v.currentMaterialIndex = 0
    end
  end

  updateMaterialProperties()
end

local function menu()
  local wpos = im.GetWindowPos()
  local cpos = im.GetCursorPos()
  local p1 = im.ImVec2(wpos.x + cpos.x - v.style.WindowPadding.x, wpos.y + cpos.y - v.style.WindowPadding.y)
  local p2 = im.ImVec2(wpos.x + cpos.x + im.GetContentRegionAvailWidth() + 2 * v.style.WindowPadding.x, wpos.y + cpos.y + v.inputWidgetHeight * 1.5)
  im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), p1, p2, im.GetColorU321(im.Col_MenuBarBg))
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(6, 2))
  im.PushStyleColor2(im.Col_Button, im.ImVec4(1,0.5647,0,1))
  if editor.uiIconImageButton(editor.icons.material_new, im.ImVec2(v.inputWidgetHeight * 1.5, v.inputWidgetHeight * 1.5)) then
    ffi.copy(newMatPath, lastCreateMaterialPath .. "main.materials.json")
    editor.showWindow(createMaterialWindowName)
  end
  im.tooltip("New material")
  im.SameLine(nil, v.style.ItemSpacing.x)
  if editor.uiIconImageButton(editor.icons.material_tag, im.ImVec2(v.inputWidgetHeight * 1.5, v.inputWidgetHeight * 1.5)) then
    editor.showWindow(materialsByTagsWindowName)
  end
  im.tooltip("Open materials by tag window")
  im.SameLine(nil, v.style.ItemSpacing.x)
  if editor.uiIconImageButton(editor.icons.refresh, im.ImVec2(v.inputWidgetHeight * 1.5, v.inputWidgetHeight * 1.5)) then
    if currentMaterial then
      local maxLayers = currentMaterial.activeLayers
      local files = {}
      for k,v in pairs(currentMaterial:getFields()) do
        if v.type == "filename" then
          for i=0,maxLayers-1 do
            local filepath = currentMaterial:getField(k, i)
            if tmp ~= "" and string.sub(filepath, 1, 1) ~= '/' then
              filepath = "/"..filepath
            end
            if tmp ~= "" and FS:fileExists(filepath) then
              log("D", "reloadTex", dumps(k).."["..dumps(i).."]="..dumps(filepath))
              files[#files+1] = filepath
            end
          end
        end
      end
      if #files then
        FS:triggerFilesChanged(files)
      end
    else
      log("E","reloadTex", "no current mat")
    end
  end
  im.tooltip("Reload textures of current material")
  im.PopStyleColor()
  im.PopStyleVar()
  im.Dummy(im.ImVec2(0, v.style.ItemSpacing.y))
end

local function pickFromTSStatic()
  if pickMapToFromObjectPopupPos then
    im.SetWindowPos1(pickMapToFromObjectPopupPos, im.Cond_Appearing)
  else
    im.SetWindowPos1(im.GetMousePos(), im.Cond_Appearing)
  end
  if pickMapToFromObjectPopupHeight then im.SetNextWindowSize(im.ImVec2(0, pickMapToFromObjectPopupHeight)) end
  if im.BeginPopup("PickMapToFromObjectPopup") then
    local maxWidth = im.GetContentRegionAvailWidth()
    if pickingFromObjectMaterials then
      for _, matName in ipairs(pickingFromObjectMaterials) do
        if im.Selectable1(matName) then
          if pickingFromObjectMode == pickingFromObjectMode_enum.new_material then
            ffi.copy(newMatMapTo, matName)
          elseif pickingFromObjectMode == pickingFromObjectMode_enum.existing_material then
            setPropertyWithUndo("mapTo", 0, matName)
          end
          pickingFromObjectMaterials = nil
          pickMaterialFromObject = false
          if formerEditMode then
            editor.selectEditMode(formerEditMode)
            formerEditMode = nil
          end
          im.CloseCurrentPopup()
        end
        if im.IsItemHovered() then
          if maxWidth < (im.CalcTextSize(matName).x + 2 * v.style.WindowPadding.x) then
            im.SetTooltip(matName)
          end
        end
      end
    end
    im.EndPopup()
  end
end

local function materialsByTagWindow()
  if editor.beginWindow(materialsByTagsWindowName, "Materials by Tag") then
    if sortedTags then
      for _, tagName in ipairs(sortedTags) do
        if im.TreeNodeEx1(tagName) then
          for _, material in ipairs(tags[tagName]) do
            if im.SmallButton(material) then
              -- Clear search filter before selecting a material, it might not be part of the mat list yet.
              ffi.copy(matFilter.InputBuf, "")
              getMaterials()
              selectMaterialByName(material)
            end
          end
          im.TreePop()
        end
      end
    end
  end
  editor.endWindow()
end

local function createMaterialWindowGui()
  if editor.beginWindow(createMaterialWindowName, "Create Material") then
    local cursorPosY = im.GetCursorPosY()
    im.Text("Material Name:")
    im.SameLine()
    im.PushItemWidth(im.GetContentRegionAvailWidth() - (v.inputWidgetHeight * im.uiscale[0] + v.style.ItemSpacing.x + 10))
    im.InputText("##NewMatName", newMatName, nil, im.flags(im.InputTextFlags_CharsNoBlank))
    im.PopItemWidth()

    im.SameLine()
    local size = im.ImVec2(v.inputWidgetHeight, 2* v.inputWidgetHeight + v.style.ItemSpacing.y)
    local pos = im.GetCursorPos()
    if editor.uiIconImageButton((newMatMapToLocked == true and editor.icons.lock_outline or editor.icons.lock_open), size, im.ImVec4(1,1,1,0)) then
      newMatMapToLocked = not newMatMapToLocked
      if newMatMapToLocked == true and #ffi.string(newMatName) == 0 and #ffi.string(newMatMapTo) > 0 then
        ffi.copy(newMatName, ffi.string(newMatMapTo))
      end
    end
    im.SetCursorPos(im.ImVec2(pos.x,pos.y + size.y/4))
    editor.uiIconImage((newMatMapToLocked == true and editor.icons.lock_outline or editor.icons.lock_open), im.ImVec2(size.x, size.x))
    -- icon, size, col, borderCol, label
    im.SetCursorPosY(cursorPosY + v.inputWidgetHeight + v.style.ItemSpacing.y)
    im.Text("Map to:")
    im.SameLine()
    if newMatMapToLocked == true then
      im.PushItemWidth(im.GetContentRegionAvailWidth() - (v.inputWidgetHeight * im.uiscale[0] + v.style.ItemSpacing.x + 10))
    else
      im.PushItemWidth(im.GetContentRegionAvailWidth() - (v.inputWidgetHeight * im.uiscale[0] + 3 * v.style.ItemSpacing.x + im.CalcTextSize("Pick from TSStatic").x + 10))
    end
    im.InputText("##NewMatMapTo", (newMatMapToLocked == true and newMatName or newMatMapTo), nil, im.flags(im.InputTextFlags_CharsNoBlank))
    im.PopItemWidth()
    if newMatMapToLocked == false then
      im.SameLine()
      im.PushStyleColor2(im.Col_Button, pickMaterialFromObject and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Button))
      if im.Button("Pick from TSStatic") then
        pickMaterialFromObject = true
        pickingFromObjectMode = pickingFromObjectMode_enum.new_material
        if pickMaterialFromObject == true then
          formerEditMode = editor.editMode
          editor.selectEditMode(editMode_PickMapTo())
        else
          editor.selectEditMode(formerEditMode)
          formerEditMode = nil
        end
      end
      im.tooltip("Enable to pick a material from a mesh.")
      im.PopStyleColor()
    end

    im.Text("Path:")
    im.SameLine()
    im.PushItemWidth(im.GetContentRegionAvailWidth() - (v.style.ItemSpacing.x + 2 * v.style.FramePadding.x + im.CalcTextSize("...").x))
    im.InputText("##NewMatPath", newMatPath, nil, im.flags(im.InputTextFlags_CharsNoBlank))
    im.PopItemWidth()
    im.SameLine()
    if im.Button("...") then
      editor_fileDialog.saveFile(
        function(data)
          lastCreateMaterialPath = data.path
          ffi.copy(newMatPath, data.filepath)
        end,
        {{"Any files", "*"},{"Material file",".materials.json"}},
        false,
        lastCreateMaterialPath,
        "File already exists.\nDo you want to merge the material into this file?"
      )
    end

    if createMaterialName ~= ffi.string(newMatName) then
      createMaterialName = ffi.string(newMatName)
      local mat = scenetree.findObject(createMaterialName)
      if mat then
        createMaterialMessage = "Error: Object with name \""..createMaterialName.."\" already exists. Please choose a different name."
        createMaterialError = true
      else
        createMaterialMessage = ""
        createMaterialError = false
      end
    end

    im.SetCursorPosX(im.GetCursorPosX() + im.GetContentRegionAvailWidth() - (v.style.ItemSpacing.x + 4 * v.style.FramePadding.x + im.CalcTextSize("Create").x + im.CalcTextSize("Cancel").x))
    if createMaterialError then im.BeginDisabled() end
    if im.Button("Create") then
      if editor.createMaterial(ffi.string(newMatName), ffi.string(newMatPath), (newMatMapToLocked == true and ffi.string(newMatName) or ffi.string(newMatMapTo))) then
        editor.hideWindow(createMaterialWindowName)
        getMaterials()
        selectMaterialByName(ffi.string(newMatName))
        ffi.copy(newMatName, "")
        ffi.copy(newMatMapTo, "")
        v.dirtyMaterials[currentMaterial:getField('name', 0)] = true
      end
    end
    if createMaterialError then im.EndDisabled() end
    im.SameLine()
    if im.Button("Cancel") then
      editor.hideWindow(createMaterialWindowName)
    end
  end

  if createMaterialMessage and createMaterialMessage ~= "" and createMaterialError then
    im.SetCursorPos(im.ImVec2(im.GetCursorPosX(), im.GetContentRegionAvail().y + im.GetCursorPosY() - im.GetTextLineHeight()))
    im.TextColored(im.ImVec4(1, 1, 0, 1), createMaterialMessage)
  end
  editor.endWindow()
end

local function materialPreviewWindowGui()
  if editor.beginWindow(materialPreviewWindowName, "Material Preview##Window") then
    if not v.style then v.style = im.GetStyle() end
    local availableSize = im.GetContentRegionAvail()
    availableSize.y = availableSize.y - 28
    local size = (availableSize.x < availableSize.y) and availableSize.x or availableSize.y
    size = (size < 64 and 64 or size)

    if previewMeshes then
      im.TextUnformatted("Preview Meshes")
      im.ShowHelpMarker("RMB: Orbit view\nScroll Wheel (+ Ctrl): Zoom view\nShift + RMB: Move sun" , true)
      im.SameLine()
      im.PushItemWidth(size - (im.CalcTextSize("Preview Meshes(?)").x + 3 * v.style.ItemSpacing.x + 24))
      if im.Combo1("##MaterialPreviewMeshCombo", previewMeshIndex, previewMeshNamesPtr) then
        updateExtMaterialPreviewMesh()
      end
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.refresh, im.ImVec2(24, 24)) then
        getPreviewMeshes()
      end
      im.tooltip("Refresh Preview Mesh List\n\nThe tool fetches all dae files from `\\art\\shapes\\material_preview`")
      im.PopItemWidth()
    end

    materialPreview(size)
  end
  editor.endWindow()
end

local function onEditorGui()
  materialPreviewWindowGui()

  if focusWindow == true then
    im.SetNextWindowFocus()
    focusWindow = false
  end

  if editor.beginWindow(toolWindowName, "Material Editor") then
    v.style = im.GetStyle()
    v.inputWidgetHeight = 20 + v.style.FramePadding.y
    createMaterialWindowGui()
    materialsByTagWindow()
    menu()

    if openPickMapToFromObjectPopup == true then
      local popupHeight = #pickingFromObjectMaterials * v.inputWidgetHeight + v.style.WindowPadding.y
      pickMapToFromObjectPopupHeight = popupHeight > pickMapToFromObjectPopupMaxHeight and pickMapToFromObjectPopupMaxHeight or popupHeight
      im.OpenPopup("PickMapToFromObjectPopup")
      openPickMapToFromObjectPopup = false
    end

    pickFromTSStatic()

    if im.BeginChild1("MATERIALEDITORMAIN") then

      if editor.uiInputSearchTextFilter("Filter materials (inc, -exc)", matFilter, im.GetContentRegionAvailWidth()) then
        v.currentMaterialIndex = 0
        getMaterials()
      end

      im.TextUnformatted("Materials")
      if not v.materialNamesPtr or not v.materialNameList then
        im.End()
        return
      end
      -- Set width of the Combo widget. The width dpends on whether there're dirty materials or not,
      -- so whether we have display additional buttons next to the combo widget or not.
      im.PushItemWidth(
        next(v.dirtyMaterials) == nil and
        (im.GetContentRegionAvailWidth() - (math.ceil(17 * im.uiscale[0]) + 2 * v.style.FramePadding.y + v.style.ItemSpacing.x))
        or
        (im.GetContentRegionAvailWidth() - (2 * (math.ceil(17 * im.uiscale[0]) + 2 * v.style.FramePadding.y) + 2 * v.style.ItemSpacing.x))
      )
      if v.materialNamesPtrCount == 0 then im.BeginDisabled() end
      if im.Combo1("##Materials", editor.getTempInt_NumberNumber(v.currentMaterialIndex), v.materialNamesPtr, (#v.materialNameList + 1), 20) then
        if dbg then editor.logInfo(logTag .. "Material has changed!") end
        v.currentMaterialIndex = editor.getTempInt_NumberNumber()
        updateMaterialProperties()
        local levelMaterialNames = editor.getPreference("materialEditor.general.levelMaterialNames")
        levelMaterialNames[getMissionPath()] = v.materialNameList[v.currentMaterialIndex]
        editor.setPreference("materialEditor.general.levelMaterialNames", levelMaterialNames)
      end
      if v.materialNamesPtrCount == 0 then
        im.EndDisabled()
        im.SameLine()
        editor.uiIconImageButton(editor.icons.warning, im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight), editor.color.warning.Value)
        im.tooltip("The selected object either has no materials assigned to it or all the materials were auto-generated and can't be changed using the material editor.")
      end
      im.PopItemWidth()
      if currentMaterial and v.dirtyMaterials and v.dirtyMaterials[currentMaterial:getField("name", 0)] then
        im.SameLine()
        if editor.uiIconImageButton(editor.icons.material_save_current, im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight)) then
          saveCurrentMaterial()
        end
        im.tooltip("Save current material")
      end

      if (next(v.dirtyMaterials)) then
        im.SameLine()
        if editor.uiIconImageButton(editor.icons.material_save_all, im.ImVec2(v.inputWidgetHeight, v.inputWidgetHeight)) then
          saveAllDirtyMaterials()
        end
        if im.IsItemHovered() then
          im.BeginTooltip()
          local tooltipMsg = "Save all dirty materials:\n"
          for k,v in pairs(v.dirtyMaterials) do
            tooltipMsg = tooltipMsg .. "* " .. k .. "\n"
          end
          im.TextUnformatted(tooltipMsg)
          im.EndTooltip()
        end
      end

      drawGui()

      im.EndChild()
    end

  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
  editor.hideWindow(createCubemapWindowName)
  editor.hideWindow(createMaterialWindowName)
end

local function onVehicleSwitched(oid, nid, player)
  --TODO: need more investigation on reload scripts the editor is not yet created, while vehicle is switched
  if editor and editor.isWindowVisible and editor.active and editor.isWindowVisible(toolWindowName) == true then
    core_jobsystem.create(mapTagsJob, 1)
    getMaterials()
    updateMaterialProperties()
  end
end

local function onFilesChanged(files)
  for _,v in pairs(files) do
    local path = v.filename
    local levelName, levelFilepath = string.match(path, "/levels/([%w_]+)(.+)")
    local artFilepath = string.match(path, "/art/(.+)")
    if levelName or artFilepath then
      local filename = string.match(path, "[^/]*$")
      if filename == "main.materials.json" then
        getMaterials()
        return
      end
    end
  end
end

local function onEditorPreferenceValueChanged(path, value)
  if path == "materialEditor.general.thumbnailSize" then
    options.thumbnailSize = value
    updateMaterialPreviewRender = true
  end
  if path == "materialEditor.general.maxMaterialPreviewSize" then
    options.maxMaterialPreviewSize = value
    updateMaterialPreviewRender = true
  end
  if path == "materialEditor.general.updateMaterialListBasedOnSelection" then
    options.updateMaterialListBasedOnSelection = value
    getMaterials()
  end
  if path == "materialEditor.general.textFilterResultsWithSameFirstCharAtTop" then
    options.textFilterResultsWithSameFirstCharAtTop = value
    getMaterials()
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("materialEditor")
  prefsRegistry:registerSubCategory("materialEditor", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {thumbnailSize = {"int", 64, "", nil, 32, 256 }},
    {maxMaterialPreviewSize = {"int", 256, "", nil, 64, 1024}},
    {updateMaterialListBasedOnSelection = {"bool", true, "If enabled the material dropdown will only list materials which are applied on the current selected scene object.\nWorks for TSStatics, BeamNGVehicle and ForestItems."}},
    {textFilterResultsWithSameFirstCharAtTop = {"bool", true, "List materials starting with the same chars as the text filter at top of materials list."}},
    -- hidden
    {columnSizes = {"table", {29, 53, 300, 145, 97, 280}, "", nil, nil, nil, true}},
    {levelMaterialNames = {"table", {}, "", nil, nil, nil, true}},
  })
end

local function onEditorActivated()
  if not v.materialNameList then
    getMaterials()
  end

  getGroundmodels()
  getPreviewMeshes()

  matPreview:setObjectModel("/art/shapes/material_preview/cube_1m.dae")
  matPreview:setRenderState(false,false,false,false,false,false)
  matPreview:setCamRotation(0.6, 3.9)
  matPreview:setSunRotation(135,90)
  matPreview:fitToShape()
  matPreview:setZoom(1.4)
  matPreview:renderWorld(dimRdr)

  extMatPreview:setObjectModel("/art/shapes/material_preview/cube_1m.dae")
  extMatPreview:setRenderState(false,false,false,false,false,false)
  extMatPreview:setCamRotation(0.6, 3.9)
  extMatPreview:setSunRotation(135,90)
  extMatPreview:fitToShape()
  extMatPreview:setZoom(1.4)
  extMatPreview:renderWorld(dimRdr)

  levelPath = getMissionPath()
  lastPath = levelPath
  lastCreateMaterialPath = (FS:directoryExists(levelPath .. "art/") and (levelPath .. "art/") or levelPath)

  updateMaterialProperties()
end

local function onEditorDeactivated()
  v.materialNameList = nil
  v.materialNamesPtr = nil

  previewMeshes = nil
  groundModels = nil
  -- tags = nil
end

local function onEditorInitialized()
  editor.addWindowMenuItem("Material Editor", onWindowMenuItem, nil, true)
  editor.registerWindow(toolWindowName, im.ImVec2(310, 580))
  editor.registerWindow(createCubemapWindowName, im.ImVec2(750, 380))
  editor.registerWindow(createMaterialWindowName, im.ImVec2(450, 150))
  editor.registerWindow(materialPreviewWindowName, im.ImVec2(300, 300))
  editor.registerWindow(materialsByTagsWindowName, im.ImVec2(260, 320))
  editor.hideWindow(createCubemapWindowName)
  editor.hideWindow(createMaterialWindowName)
  editor.hideWindow(materialPreviewWindowName)
  editor.hideWindow(materialsByTagsWindowName)

  core_jobsystem.create(mapTagsJob, 1)

  -- load vehicle materials too
  loadDirRec("vehicles/")
end

local function onEditorObjectSelectionChanged()
  getMaterials()
end

local function onEditorDeleteSelection()
  refreshCubemaps()
  selectCubemap()
end

M.dbg = dbg
M.setProperty = setProperty
M.deleteMapButton = deleteMapButton
M.v = v
M.o = o
M.customMaterialsArray = customMaterialsArray
M.customMaterialsArrayPtr = customMaterialsArrayPtr

M.imageButton = imageButton
M.inputFloat = inputFloat
M.colorEdit4 = colorEdit4

M.onFilesChanged = onFilesChanged
M.onVehicleSwitched = onVehicleSwitched

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorActivated = onEditorActivated
M.onEditorDeactivated = onEditorDeactivated

M.showMaterialEditor = showMaterialEditor
M.selectMaterialByName = selectMaterialByName
M.setMaterialDirty = setMaterialDirty

M.onEditorObjectSelectionChanged = onEditorObjectSelectionChanged
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged
M.onEditorDeleteSelection = onEditorDeleteSelection

return M
