-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- TODO:
-- * draw GridPoints
-- * serialization
-- * brush only works when mouse is moving
-- * render GridPoints in brush
-- * keep worldPos when mouse is not moving instead of raycasting every frame the new pos

-- * importer: filter out non-image files
local debug = true

local M = {}
local var = {}
local im = ui_imgui
local imUtils = require('ui/imguiUtils')
local terrainPainterWindowName = "terrainPainter"
local terrainImportDialogName = "terrainImportDialog"
local terrainExportDialogName = "terrainExportDialog"
local terrainBrushSoftnessCurveDialogName = "terrainBrushSoftnessCurveDialog"
local minFloatValue = -1000000000
local maxFloatValue = 1000000000
local terrainFolder = "/art/terrain/"
local matFilePath = "/art/terrain/main.materials.json"
local startDragHeight
local brushCenter
--TODO: delete this logic after all terrain materials were upgraded with groundmodelName instead of internalName
local hasConversionsToGroundmodel = nil
local errors = {}

var.levelName = nil
var.levelPath = nil
var.style = nil
var.io = nil
var.fontSize = nil
var.menuBarHeight = nil
var.inputWidgetHeight = nil

local terrainPainterWindowSize = {}

local serializationPath = '/settings/editor/terrainEditor.json'
local active = false
-- 0: terrain sculpting, 1: terrain painting
local stateEnum = {sculpting = 0, painting = 1}
local state = stateEnum.sculpting
-- 0: released, 1: mouse down, 2: move mouse
local mouseStateEnum = {
  released = 0,
  down = 1,
  moving = 2
}
local mouseState = mouseStateEnum.released
local notifications = {}
local dragDropId = "ASSETDRAGDROP"
local brushSettingSliderWidth = 100

-- initialized in initialize()
local terrainEditor = nil
local gui3DMouseEvent = nil

-- table containing all TerrainBlock objects of the current level
local terrainBlockProxies = {}
local terrainBlockId = nil

local terrainBrushes = nil
local paintBrush = nil
local brushTypes = nil
local brushSettings = nil

local paintMaterialProxies = {}
local paintMaterialCount = nil
local selectedPaintMaterialProxy = nil
local selectedPaintMaterialProxyIndex = nil
local materialsInJson = {}

local currentAction = nil

local potentialDragDropPayload = nil
local dragDropPayload = nil
local hoveredMatIndex

local changeBrushSizeAutoRepeatOn = false
local changeBrushSizeTimer = 0
local changeBrushSizeDirection = 0

-- terrain import/export
local terrainImpExp = {}
-- import
terrainImpExp.terrainName = im.ArrayChar(32, "theTerrain")
terrainImpExp.metersPerPixel = im.FloatPtr(1)
terrainImpExp.heightScale = im.FloatPtr(50) -- maxHeight
terrainImpExp.heightMapTexture = im.ArrayChar(128)
terrainImpExp.holeMapTexture = im.ArrayChar(128)
terrainImpExp.textureMaps = {
  -- {path="/levels/gridmap/ter.png", selected=false},
}
terrainImpExp.applyTransform = im.BoolPtr(false)
-- change values based on terrain size
-- 1/2 * terrain width, 1/2 * terrain height
terrainImpExp.transformPos = {
  x = im.FloatPtr(-512),
  y = im.FloatPtr(-512),
  z = im.FloatPtr(0),
}
terrainImpExp.flipYAxis = im.BoolPtr(false)

-- export
terrainImpExp.exportPath = im.ArrayChar(128)

-- terrain import gui
var.paintMaterialNamesArray = nil
var.paintMaterialNamesArrayPtr = nil
var.channelComboWidth = 0
var.maxMaterialNameWidth = 0
var.materialComboWidth = 0
var.buttonColor = im.GetStyleColorVec4(im.Col_Button)
var.transparentColor = im.GetStyleColorVec4(im.Col_WindowBg)

var.lastPath = nil

-- brush softness curve window
var.softSelectFilter = {1.000000, 0.833333, 0.666667, 0.500000, 0.333333, 0.166667, 0.000000}
var.softSelectFilterDefault = {1.000000, 0.833333, 0.666667, 0.500000, 0.333333, 0.166667, 0.000000}
var.softSelectFilterBackup = nil
var.sc_frameCol = im.GetColorU322(im.ImVec4(1,1,1,1))
var.sc_backgroundCol = im.GetColorU322(im.ImVec4(0.8,0.8,0.8,1))
var.sc_identityLineCol = im.GetColorU322(im.ImVec4(0.5,0.5,0.5,0.5))
var.sc_curveColor = im.GetColorU322(im.ImVec4(0,0,0,1))
var.sc_knotColor = im.GetColorU322(im.ImVec4(1,0,0,0.5))
var.sc_knotColorActive = im.GetColorU322(im.ImVec4(1,0,0,0.75))
var.sc_dragId = nil
var.sc_curveWidgetPosA = nil
var.sc_curveWidgetSize = nil

--TODO
var.brushSizeMin = 1
var.brushSizeMax = 256
var.brushPressureMin = 0.1
var.brushPressureMax = 100
var.brushSoftnessMin = 0.1
var.brushSoftnessMax = 100
var.brushHeightMin = 0
var.brushHeightMax = 2047
var.brushHeightPicking = false

var.brushSegments = 50
var.brushRatio = 1
var.brushRotation = 0
var.currentBrushType = nil

local autoPaint = {
  heightMin = -10000,
  heightMax = 10000,
  slopeMin = 0,
  slopeMax = 90,
  coverage = 100
}

local tempBoolPtr = im.BoolPtr(false)
local tempIntPtr = im.IntPtr(0)
local tempFloatPtr = im.FloatPtr(0)

local function getTempBool(value)
  if value ~= nil then
    if value == true then
      tempBoolPtr[0] = true
      return tempBoolPtr
    elseif value == false then
      tempBoolPtr[0] = false
      return tempBoolPtr
    end
  else
    return tempBoolPtr[0]
  end
end

local function getTempInt(value)
  if value then
    tempIntPtr[0] = value
    return tempIntPtr
  else
    return tempIntPtr[0]
  end
end

local function getTempFloat(value)
  if value then
    tempFloatPtr[0] = value
    return tempFloatPtr
  else
    return tempFloatPtr[0]
  end
end

local function getMtlIdByName(matName) --terrain layers
  for k, mat in ipairs(var.paintMaterialNamesArray) do
    if mat == matName then
      return k, matName
    end
  end
  editor.logWarn("Not able to find paint material with the given name '".. matName .."'. Defaulting to '".. paintMaterialProxies[1].internalName .. "'")
  return 1, paintMaterialProxies[1].internalName
end

local function getMtlByName(matName) --terrain layers
  for k, mat in ipairs(paintMaterialProxies) do
    if mat == matName then
      return mat
    end
  end
  editor.logWarn("Not able to find paint material with the given name '".. matName .."'. Defaulting to '".. paintMaterialProxies[1].internalName .. "'")
  return paintMaterialProxies[1]
end

local function getGlobalMtlIdByName(matName) --all terrain material
  for k, mat in ipairs(paintMaterialProxies) do
    if mat.internalName == matName then
      return k, matName
    end
  end
  editor.logWarn("Not able to find paint material with the given name '".. matName .."'. Defaulting to '".. paintMaterialProxies[1].internalName .. "'")
  return 1, paintMaterialProxies[1].internalName
end

local function clearTextureMaps()
  terrainImpExp.textureMaps = {}
end

local function addTextureMap(path)
  if type(path) ~= 'string' or #path == 0 then
    log('W', '', 'The given path is either not a string or is empty.')
  end

  for k, map in ipairs(terrainImpExp.textureMaps) do
    if path == map.path then
      log('W', "", "The path you want to add already exists.")
      return
    end
  end

  local mat = string.match(path, "layerMap_%d*_(.*)%.(%w*)$")
  local matId = 0
  local matName = " "

  if mat ~= nil then
    matId, matName = getMtlIdByName(mat)
    -- Decrementing matId here not to break anything that depends on getMatIdByName
    matId = matId - 1
  end
  table.insert(terrainImpExp.textureMaps, {path=path, selected=false, material=matName or "", materialId = im.IntPtr(matId or 0), channel="R", channelId=im.IntPtr(0)})
end

local function removeTextureMap()
  for i = #terrainImpExp.textureMaps, 1, -1 do
    if terrainImpExp.textureMaps[i].selected == true then
      table.remove(terrainImpExp.textureMaps, i)
    end
  end
end

local function updateMap(mtlProxy, map, path)
  if map == "diffuse" then
    mtlProxy.diffuseMap = path
    mtlProxy.diffuseMapObj = imUtils.texObj(mtlProxy.diffuseMap)
  elseif map == "macro" then
    mtlProxy.macroMap = path
    mtlProxy.macroMapObj = imUtils.texObj(mtlProxy.macroMap)
  elseif map == "detail" then
    mtlProxy.detailMap = path
    mtlProxy.detailMapObj = imUtils.texObj(mtlProxy.detailMap)
  elseif map == "normal" then
    mtlProxy.normalMap = path
    mtlProxy.normalMapObj = imUtils.texObj(mtlProxy.normalMap)
  -- Terrain Importer/Exporter
  elseif map == "heightMap" then
    terrainImpExp.heightMapTexture = im.ArrayChar(128, path)
  elseif map == "holeMap" then
    terrainImpExp.holeMapTexture = im.ArrayChar(128, path)
  elseif map == "textureMap" then
    addTextureMap(path)
  end
end

-- drag'n'drop
local function dragDropTarget(mtlProxy, map, cbData)
  if im.BeginDragDropTarget() then
    local payload = im.AcceptDragDropPayload(dragDropId)
    -- if payload~=nil and editor.dragDropAsset~=nil then
    if payload ~= nil then
      assert(payload.DataSize == ffi.sizeof"char[2048]")
      local path = ffi.string(ffi.cast("char*",payload.Data))
      updateMap(mtlProxy, map, path)
    end
    im.EndDragDropTarget()
  end
end

local function brushSoftnessCurve_Set(value)
  value = value or var.softSelectFilter
  if value then
    local softSelectFilterString = string.format( "%.6f %.6f %.6f %.6f %.6f %.6f %.6f", value[1], value[2], value[3], value[4], value[5], value[6], value[7])
    terrainEditor:setField('softSelectFilter', 0, softSelectFilterString)
    editor.setPreference("terrainEditor.general.softSelectFilter", value)
  end
end

local function brushSoftnessCurve_Show()
  var.softSelectFilterBackup = deepcopy(var.softSelectFilter)
  editor.showWindow(terrainBrushSoftnessCurveDialogName)
end

local function brushSoftnessCurve_Hide()
  editor.hideWindow(terrainBrushSoftnessCurveDialogName)
end

local function brushSoftnessCurve_Toggle()
  if editor.isWindowVisible(terrainBrushSoftnessCurveDialogName) == true then
    brushSoftnessCurve_Hide()
  else
    brushSoftnessCurve_Show()
  end
end

local function brushSoftnessCurve_Default()
  var.softSelectFilter = deepcopy(var.softSelectFilterDefault)
  if editor.getPreference("terrainEditor.general.brushSoftnessCurveLiveUpdate") == true then
    brushSoftnessCurve_Set()
  end
end

local function brushSoftnessCurve_Reset()
  if var.softSelectFilterBackup then
    var.softSelectFilter = deepcopy(var.softSelectFilterBackup)
  end
  if editor.getPreference("terrainEditor.general.brushSoftnessCurveLiveUpdate") == true then
    brushSoftnessCurve_Set()
  end
end

local function brushSoftnessCurve_Cancel()
  brushSoftnessCurve_Reset()
  brushSoftnessCurve_Hide()
end

local function brushSoftnessCurve_Accept()
  brushSoftnessCurve_Set()
  brushSoftnessCurve_Hide()
end

local function updateAutoRepeatChangeBrushSize()
  changeBrushSizeTimer = changeBrushSizeTimer + editor.getDeltaTime()
  if changeBrushSizeTimer >= editor.getPreference("terrainEditor.general.brushSizeChangeIntervalWithKeys") then
    changeBrushSizeTimer = 0
    editor_terrainEditor.changeBrushSize(changeBrushSizeDirection, editor.getPreference("terrainEditor.general.brushSizeChangeStepWithKeys"))
  end
end

local function switchAction(action, doSerialization)
  if not action then return end
  currentAction = action
  editor.setPreference("terrainEditor.general.brush", currentAction.name)
  terrainEditor:setAction(currentAction.name)

  if action == paintBrush then
    state = stateEnum.painting
    if editor.isWindowVisible(terrainBrushSoftnessCurveDialogName) == true then
      brushSoftnessCurve_Cancel()
    end
    editor.showWindow(terrainPainterWindowName)
  else
    state = stateEnum.sculpting
    editor.hideWindow(terrainPainterWindowName)
  end

  if doSerialization == true then
    --TODO: is doSerialization referring to window state or preferences ?
  end
end

local function getBrushByName(brushName)
  for _, brush in ipairs(terrainBrushes) do
    if brush.name == brushName and (brush.disabled == nil or brush.disabled == false) then
      return brush
    end
  end
end

local function switchBrushType(brushType, doSerialization)
  var.currentBrushType = brushType
  terrainEditor:setBrushType(brushType.name)
  editor.setPreference("terrainEditor.general.brushType", var.currentBrushType.name)

  if doSerialization == true then
    --TODO: is this referring to window state ?
  end
end

local function setTerrainDirty()
  editor.setDirty()
  notifications["terrainDirty"] = "You have unsaved terrain changes, save level"
end

local function setMaterialsDirty()
  editor.setDirty()
  notifications["materialsDirty"] = "You have unsaved material changes, save level"
end

local function selectPreset(data)
  local preset = jsonReadFile(data.filepath)
  if preset and preset.type and preset.type=="TerrainData" then
    if preset.name then
      ffi.copy(terrainImpExp.terrainName, preset.name)
    end
    if preset.squareSize then
      terrainImpExp.metersPerPixel[0] = preset.squareSize
    end
    if preset.heightScale then
      terrainImpExp.heightScale[0] = preset.heightScale
    end
    if preset.heightMapPath then
      ffi.copy(terrainImpExp.heightMapTexture, preset.heightMapPath)
    end
    if preset.holeMapPath then
      ffi.copy(terrainImpExp.holeMapTexture, preset.holeMapPath)
    end
    if preset.opacityMaps then
      clearTextureMaps()
      for k, map in ipairs(preset.opacityMaps) do
        addTextureMap(map)
      end
    end

    if preset.pos then
      terrainImpExp.applyTransform[0] = true
      terrainImpExp.transformPos.x[0] = preset.pos.x
      terrainImpExp.transformPos.y[0] = preset.pos.y
      terrainImpExp.transformPos.z[0] = preset.pos.z
    end
  end
end

local function copyMaterialProxyWithInputs(mtlProxy)
  local mtlProxyCopy = deepcopy(mtlProxy)

  mtlProxyCopy.nameInput = im.ArrayChar(32, mtlProxyCopy.internalName)
  -- if we dont have a groundmodel name, then we legacy copy the gm name from internalName

  if mtlProxyCopy.groundmodelName == "" and mtlProxyCopy.internalName ~= "" then
    mtlProxyCopy.groundmodelName = string.upper(mtlProxyCopy.internalName)
    mtlProxyCopy.material:setGroundmodelName(mtlProxyCopy.groundmodelName)
  end

  mtlProxyCopy.groundmodelNameInput = im.ArrayChar(32, mtlProxyCopy.groundmodelName)
  mtlProxyCopy.diffuseSizeInput = im.FloatPtr(mtlProxyCopy.diffuseSize)
  mtlProxyCopy.useSideProjectionInput = im.BoolPtr(mtlProxyCopy.useSideProjection)
  mtlProxyCopy.macroStrengthInput = im.FloatPtr(mtlProxyCopy.macroStrength)
  mtlProxyCopy.macroSizeInput = im.FloatPtr(mtlProxyCopy.macroSize)
  mtlProxyCopy.macroDistanceInput = im.FloatPtr(mtlProxyCopy.macroDistance)
  mtlProxyCopy.detailStrengthInput = im.FloatPtr(mtlProxyCopy.detailStrength)
  mtlProxyCopy.detailSizeInput = im.FloatPtr(mtlProxyCopy.detailSize)
  mtlProxyCopy.detailDistanceInput = im.FloatPtr(mtlProxyCopy.detailDistance)
  mtlProxyCopy.parallaxScaleInput = im.FloatPtr(mtlProxyCopy.parallaxScale)

  return mtlProxyCopy
end

-- Background: in the past the groundmodel name was actually the internalName of the terrain material, but now we have a new groundmodel field in the
-- terrain material where we store the groundmodel name and use the internalName for the actual name of the terrain material
-- to fix this improper usage, we now check if the groundmodel field is empty and we set it from the internalName
local function fixGroundmodelName(name, mtlObject, isNew)
  -- if we dont have a groundmodel name, then we legacy copy the gm name from internalName
  if mtlObject:getGroundmodelName() == "" and name ~= "" then
    local gmName = ""
    -- only set a default when the material was newly created
    if isNew then
      gmName = "ASPHALT" -- TODO: maybe choose the first groundmodel from the global list of models, but if ASPHALT will be valid forever, we can keep this
    else
      -- otherwise get the legacy way of storing groundmodel name, which was in the internalName
      gmName = string.upper(name)
    end
    mtlObject:setGroundmodelName(gmName)
    -- we force dirty so it can be saved with proper groundmodel field from now on
    setMaterialsDirty()
    editor.logWarn("Terrain Material Format Upgrade: filled groundmodelName field for: '" .. name .. "'")
    if mtlObject:getFileName() and mtlObject:getFileName() ~= "" then
      scenetree.terrEd_PersistMan:setDirty(mtlObject, mtlObject:getFileName())
      hasConversionsToGroundmodel = true
    end
  end
end

local function createMaterialProxy(index, pid, mtlObject, name, dirty, isNew)
  fixGroundmodelName(name, mtlObject, isNew)

  local mtlProxy = {
    index = index,
    internalName = name or "",
    groundmodelName = mtlObject:getGroundmodelName(),
    fileName = mtlObject:getFileName(),
    material = mtlObject,
    diffuseMap = mtlObject:getDiffuseMap(),
    diffuseMapObj = imUtils.texObj(mtlObject:getDiffuseMap()),
    diffuseSize = mtlObject:getDiffuseSize(),
    normalMap = mtlObject:getNormalMap(),
    normalMapObj = imUtils.texObj(mtlObject:getNormalMap()),
    detailMap = mtlObject:getDetailMap(),
    detailMapObj = imUtils.texObj(mtlObject:getDetailMap()),
    macroMap = mtlObject:getMacroMap(),
    macroMapObj = imUtils.texObj(mtlObject:getMacroMap()),
    detailSize = mtlObject:getDetailSize(),
    detailStrength = mtlObject:getDetailStrength(),
    detailDistance = mtlObject:getDetailDistance(),
    macroSize = mtlObject:getMacroSize(),
    macroDistance = mtlObject:getMacroDistance(),
    macroStrength = mtlObject:getMacroStrength(),
    useSideProjection = mtlObject:useSideProjection(),
    parallaxScale = mtlObject:getParallaxScale(),
    uniqueID = name .. "-" .. pid,
    persistentId = pid
  }
  if dirty == true then
    mtlProxy.dirty = true
    setTerrainDirty()
  else
    mtlProxy.dirty = false
  end
  return mtlProxy
end

local function getUniqueMtlName(initialName, counter)
  if not initialName then initialName = "NewMaterial" end
  local name = initialName .. (counter or "")
  for k, mtl in pairs(materialsInJson) do
    if mtl.internalName == name then
      return getUniqueMtlName(initialName, (counter or -1) + 1)
    end
  end
  return name
end

-- TODO: move this to terrainMaterialsEditor.lua
local function updateMaterialLibrary()
  local content = readFile(var.levelPath .. matFilePath)
  local jsonMaterials = json.decode(content)

  -- no main.materials.json file present, this shouldn't be the case unless you're in main menu.
  if not jsonMaterials then materialsInJson = {} return end
  if not materialsInJson then materialsInJson = {} end

  for uniqueID, jsonMtl in pairs(jsonMaterials) do
    if jsonMtl.class ~= "TerrainMaterialTextureSet" then
      local cachedMtlProxy = materialsInJson[uniqueID] or {}

      if not cachedMtlProxy.material then
       -- get an unique name if there is already one named the same
        local newName = getUniqueMtlName(jsonMtl.internalName)
        local terrainMtl = TerrainMaterial.findOrCreate(newName)
        terrainMtl:setInternalName(newName)
        cachedMtlProxy.material = terrainMtl
        cachedMtlProxy.persistentId = jsonMtl.persistentId
      end

      materialsInJson[uniqueID] = createMaterialProxy(-1, cachedMtlProxy.persistentId, cachedMtlProxy.material, cachedMtlProxy.material.internalName)
      materialsInJson[uniqueID].fileName = var.levelPath .. matFilePath
      materialsInJson[uniqueID].uniqueID = uniqueID
      materialsInJson[uniqueID].material:setFileName(materialsInJson[uniqueID].fileName)
    end

  end

  if hasConversionsToGroundmodel == true then
    editor.logWarn("Converted terrain material(s) to use groundmodelName, please save level")
    editor_terrainEditor.setMaterialsDirty()
  end
end

local function selectPaintMaterial(matProxy)
  if not matProxy then return end
  selectedPaintMaterialProxyIndex = matProxy.index
  selectedPaintMaterialProxy = matProxy
  terrainEditor:setPaintMaterialIndex(matProxy.index - 1)
end

local function selectPaintMaterialByName(internalName)
  for _, mtl in pairs(paintMaterialProxies) do
    if mtl.internalName == internalName then
      selectPaintMaterial(mtl)
      break
    end
  end
end

local function updatePaintMaterialProxies()
  local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
  if not terrainBlock then return end
  local selectedPaintMaterialName = ""

  if selectedPaintMaterialProxy then
    selectedPaintMaterialName = selectedPaintMaterialProxy.internalName
  end

  paintMaterialProxies = {}
  var.paintMaterialNamesArray = {}
  local paintMaterialIndices = {}
  local mtls = terrainBlock:getMaterials()

  for k, mtl in ipairs(mtls) do
    local mtlName = mtl:getInternalName()
    local mtlNameWidth = im.CalcTextSize(mtlName).x
    paintMaterialProxies[k] = createMaterialProxy(k, mtl:getOrCreatePersistentID(), mtl, mtlName)
    if mtlNameWidth > var.maxMaterialNameWidth then
      var.maxMaterialNameWidth = mtlNameWidth
    end
    table.insert(var.paintMaterialNamesArray, mtlName)
    local terrainBlockMtl = terrainBlock:getMaterial(k - 1)
    if terrainBlockMtl then
      paintMaterialIndices[terrainBlockMtl:getID()] = k
    end
  end

  local count = 0
  -- set indices
  for k, mtlProxy in ipairs(paintMaterialProxies) do
    if paintMaterialIndices[mtlProxy.material:getID()] ~= nil then
      mtlProxy.inTerrainBlock = true
      mtlProxy.index = paintMaterialIndices[mtlProxy.material:getID()]
      count = count + 1
    end
  end

  var.paintMaterialNamesArrayPtr = im.ArrayCharPtrByTbl(var.paintMaterialNamesArray)
  paintMaterialCount = terrainBlock:getMaterialCount()

  if paintMaterialCount ~= count then
    editor.logWarn("Material count mismatch! paintMaterialCount = " .. tostring(paintMaterialCount) .. " count = " .. tostring(count))
  end

  selectPaintMaterialByName(selectedPaintMaterialName)
end

local function reorderMaterial(from, to)
  local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
  if not terrainBlock then return end
  local mtl = terrainBlock:getMaterial(from - 1)
  if mtl and terrainBlock:getMaterialCount() >= to then
    terrainBlock:reorderMaterial(from - 1, to - 1)
    terrainBlock:updateGridMaterials(vec3(minFloatValue, minFloatValue, 0), vec3(maxFloatValue, maxFloatValue, 0))
    updatePaintMaterialProxies()
  end
end

local function removePaintMaterial(index)
  if not index then
    editor.logError("No index specified")
    return
  end
  local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
  if not terrainBlock then return end
  terrainBlock:removeMaterial(index - 1)
  terrainBlock:updateGridMaterials(vec3(minFloatValue, minFloatValue, 0), vec3(maxFloatValue, maxFloatValue, 0))
  updatePaintMaterialProxies()
end

local function removeMap(mtlProxy, mapType)
  --TODO mtlProxy from where?
  updateMap(mtlProxy, mapType, "")
end

local function saveMaterials()
  editor.logInfo("TerrainEditor: Saving materials")
  scenetree.terrEd_PersistMan:saveDirty(true)
end

local function saveTerrainAndMaterials()
  saveMaterials()
  local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
  if terrainBlock then
    terrainBlock:save(terrainBlock:getTerrFileName())
    notifications = {}
    editor.showNotification("Saved TerrainBlock")
  end
end

local function updateTerrainBlockProxies()
  -- get current level's TerrainBlock objects
  terrainBlockProxies = {}
  for _, name in ipairs(scenetree.findClassObjects("TerrainBlock")) do
    terrainBlockProxies[name] = {selected = false, id = scenetree.findObject(name):getID()}
  end
end

-- Terrain Map Importer
local function openImportTerrainDialog()
  terrainImpExp.terrainName = im.ArrayChar(32, "theTerrain")
  editor.showWindow(terrainImportDialogName)
end

local function closeImportTerrainDialog()
  editor.hideWindow(terrainImportDialogName)
end

local function updateEditorTerrainBlocks()
  updateTerrainBlockProxies()
  updatePaintMaterialProxies()
  local idx, mtl = next(paintMaterialProxies)
  selectPaintMaterial(mtl)
  -- detach old terrain blocks
  local tb = terrainEditor:getTerrainBlock(0)
  local counter = 0
  while tb do
    terrainEditor:detachTerrain(tb)
    counter = counter + 1
    tb = terrainEditor:getTerrainBlock(counter)
  end

  -- attach all terrain blocks
  for tbName, tbData in pairs(terrainBlockProxies) do
    local tb = scenetree.findObjectById(tbData.id)
    if tb then
      terrainEditor:attachTerrain(tb)
      terrainBlockId = tbData.id
    end
  end
  gui3DMouseEvent = Gui3DMouseEvent()
end

local function terrainImporter_Accept()
  updateTerrainBlockProxies()
  local success = false
  local createNewTerrainBlock = true
  local terrBlockName = ffi.string(terrainImpExp.terrainName)
  local heightMapTexturePath = ffi.string(terrainImpExp.heightMapTexture)

  if #terrBlockName == 0 then
    editor.logWarn("TerrainBlock name has not been set!")
    return
  end
  if #heightMapTexturePath == 0 then
    editor.logWarn("HeightMap Texture has not been set!")
    return
  end
  local terrBlock = nil
  -- check if the TerrainBlock with the given name already exist
  for tbName, tbData in pairs(terrainBlockProxies) do
    if string.lower(tbName) == string.lower(terrBlockName) then
      if debug == true then log('I', '', "Found TerrainBlock with the given name '".. terrBlockName .."'") end
      -- TODO: a TerrainBlock with the same name has been found: can we overwrite it?
      terrBlock = scenetree.findObjectById(tbData.id)
      createNewTerrainBlock = false
    end
  end
  -- there's no TerrainBlock with such a name? Create one!
  if terrBlock == nil then
    if debug == true then log('I', '', "Creating a new TerrainBlock called '".. terrBlockName .."'") end
    terrBlock = TerrainBlock()
    terrBlock:setName(terrBlockName)
    terrBlock:registerObject(terrBlockName)
    if terrainImpExp.applyTransform[0] == true then
      terrBlock:setPosition(vec3(terrainImpExp.transformPos.x[0], terrainImpExp.transformPos.y[0], terrainImpExp.transformPos.z[0]))
    end
    terrBlock:setTerrFileLvlFolder("/levels/".. (true and getCurrentLevelIdentifier() or "") )
    -- TODO: Update 'terrainBlocks' table that contains all existing TerrainBlock objects
  end

  local materials = {}
  for _,map in ipairs(terrainImpExp.textureMaps) do
    table.insert(materials,map.material)
  end

  success = terrBlock:importMaps(heightMapTexturePath, terrainImpExp.metersPerPixel[0], terrainImpExp.heightScale[0], ffi.string(terrainImpExp.holeMapTexture), materials, terrainImpExp.textureMaps, terrainImpExp.flipYAxis[0])

  if success == true then
    if createNewTerrainBlock == true then
      local missionGroup = scenetree.MissionGroup
      if missionGroup then
        missionGroup:addObject(terrBlock)
      else
        editor.logDebug("MissionGroup does not exist")
      end
    end
    setTerrainDirty()
    terrainBlockId = terrBlock:getID() --fix issue when map doesn't have terrain before
    updateEditorTerrainBlocks()
    -- notifications["terrainDirty"] = "You have unsaved terrain changes!"
    closeImportTerrainDialog()
  end
end

local function terrainImporter_Cancel()
  closeImportTerrainDialog()
end

-- Terrain Map Exporter
local function openExportTerrainDialog()
  terrainImpExp.exportPath = im.ArrayChar(128, var.lastPath)
  editor.showWindow(terrainExportDialogName)
end

local function closeExportTerrainDialog()
  editor.hideWindow(terrainExportDialogName)
end

local function terrainExporter_Accept()
  local dir = ffi.string(terrainImpExp.exportPath)
  if #dir == 0 then
    log('W', "", "Export path has not been set.")
    editor.showNotification("Export path has not been set!")
    return
  end
  if not string.endswith(dir, '/') then
    dir = dir .. '/'
  end
  local success = false
  for tbName, tbData in pairs(terrainBlockProxies) do
    local tb = scenetree.findObjectById(tbData.id)
    if tb and (tbData.selected == true) then
      --TODO: check if file exists and display popup
      local heightMapPath = dir .. tbName .. "_heightmap.png"
      local ret = tb:exportHeightMap(dir .. tbName .. "_heightmap.png", "png")
      if ret == true then
        local data = {}
        data.name = tbName
        local pos = tb:getPosition()
        data.type = "TerrainData"
        data.pos = {x=pos.x, y=pos.y, z=pos.z}
        data.squareSize = tb:getSquareSize()
        data.heightScale = tb:getHeightScaleUser()
        data.heightMapPath = heightMapPath

        tb:exportLayerMaps(dir .. tbName .. "_layerMap", "png")
        local opMaps = FS:findFiles(dir, tbName .. "_layerMap_*.png", -1, false, true)
        data.opacityMaps = {}
        local time = os.time()
        for _,map in ipairs(opMaps) do
          local stat = FS:stat(map)
          -- found map has recently been regenerated
          if math.abs(stat.modtime - time) <= 10 then
            table.insert(data.opacityMaps, map)
          end
        end

        local holeMapPath = dir .. tbName .. "_holemap.png"
        data.holeMapPath = holeMapPath
        tb:exportHoleMaps(dir .. tbName, "png")
        jsonWriteFile(dir .. tbName .. "_terrainPreset.json", data, true)
        success = true
        if debug == true then log('I', '', "Exported maps for TerrainBlock '" .. tbName .. "'") end
      end
    end
  end
  if success == true then
    terrainImpExp.exportPath = im.ArrayChar(128)
    closeExportTerrainDialog()
  else
    log('W','',"No TerrainBlock has been selected.")
    editor.showNotification("No TerrainBlock has been selected!")
  end
end

local function terrainExporter_Cancel()
  closeExportTerrainDialog()
end

local function toggleTextureMap(map, addToSelection)
  if addToSelection == true then
    map.selected = not map.selected
  else
    for k,m in ipairs(terrainImpExp.textureMaps) do
      m.selected = false
    end
    map.selected = true
  end
end

local function toggleTerrainBlock(tb, addToSelection)
  if addToSelection == true then
    tb.selected = not tb.selected
  else
    for name, tbData in pairs(terrainBlockProxies) do
      if tbData then tbData.selected = false end
    end
    tb.selected = true
  end
end

-- ##### GUI WINDOWS #####

local function hasPaintMaterial(name)
  for _, mat in ipairs(paintMaterialProxies) do
    if mat.internalName == name then
      return true
    end
  end
  return false
end

local function showAddLayerMaterialGui()
  local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
  if not terrainBlock then return end
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if im.BeginCombo("##availableMaterials", "<Add Terrain Material>") then
    for id, mat in pairs(materialsInJson) do
      if not hasPaintMaterial(mat.internalName) then
        if im.Selectable1(mat.internalName .. "##availableTerrainMaterials" .. id, false, nil, nil, 0) then
          -- create a new TerrainMaterial object
          local newMat = TerrainMaterial.findOrCreate(mat.internalName)
          local terrainMtlProxy

          terrainMtlProxy = createMaterialProxy(-1, newMat:getOrCreatePersistentID(), newMat, mat.internalName)
          terrainMtlProxy.fileName = var.levelPath .. matFilePath
          terrainMtlProxy.dirty = true
          terrainBlock:addMaterial(terrainMtlProxy.internalName, -1)
          terrainBlock:updateMaterial(terrainMtlProxy.index - 1, terrainMtlProxy.internalName)
          scenetree.terrEd_PersistMan:setDirty(terrainMtlProxy.material, terrainMtlProxy.fileName or "")
          updatePaintMaterialProxies()
          terrainMtlProxy.index = tableSize(paintMaterialProxies)

          for _, mat in ipairs(paintMaterialProxies) do
            if mat.index == terrainMtlProxy.index then
              selectPaintMaterial(mat)
              break
            end
          end
          setMaterialsDirty()
          setTerrainDirty()
        end
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()
end

local function terrainPainterMaterialWindow()
  if editor.beginWindow(terrainPainterWindowName, "Terrain Painter") then
    if tableIsEmpty(terrainBlockProxies) and not selectedPaintMaterialProxy then
      im.Text("No terrain blocks.\nAdd at least one for the paint terrain tool to be available.")
    else
      if selectedPaintMaterialProxy and editor.beginModalWindow("autoPaintModal", "Auto Paint " .. selectedPaintMaterialProxy.internalName) then
        im.TextUnformatted("Generate") im.SameLine()
        im.TextColored(editor.color.warning.Value, selectedPaintMaterialProxy.internalName) im.SameLine()
        im.TextUnformatted("layer mask.")

        if editor.uiSliderFloat("Height Min", editor.getTempFloat_NumberNumber(autoPaint.heightMin), -10000, autoPaint.heightMax - 0.1, "%.1f") then
          autoPaint.heightMin = editor.getTempFloat_NumberNumber()
        end
        if editor.uiSliderFloat("Height Max", editor.getTempFloat_NumberNumber(autoPaint.heightMax), autoPaint.heightMin + 0.1, 10000, "%.1f") then
          autoPaint.heightMax = editor.getTempFloat_NumberNumber()
        end
        if editor.uiSliderFloat("Slope Min", editor.getTempFloat_NumberNumber(autoPaint.slopeMin), 0, autoPaint.slopeMax - 0.1, "%.1f") then
          autoPaint.slopeMin = editor.getTempFloat_NumberNumber()
        end
        if editor.uiSliderFloat("Slope Max", editor.getTempFloat_NumberNumber(autoPaint.slopeMax), autoPaint.slopeMin + 0.1, 90, "%.1f") then
          autoPaint.slopeMax = editor.getTempFloat_NumberNumber()
        end
        if editor.uiSliderFloat("Coverage in %", editor.getTempFloat_NumberNumber(autoPaint.coverage), 0, 100, "%.1f") then
          autoPaint.coverage = editor.getTempFloat_NumberNumber()
        end

        im.PushTextWrapPos(im.GetContentRegionAvailWidth())
        im.TextColored(editor.color.warning.Value, "Warning: This action may take a while. BeamNG.drive wont not be responsive during this time.")
        im.PopTextWrapPos()
        im.Dummy(im.ImVec2(0, 10))

        if im.Button("Close") then
          editor.closeModalWindow("autoPaintModal")
        end
        im.SameLine()
        if im.Button("Auto Paint##doAutoPaint") then
          terrainEditor:autoMaterialLayer(autoPaint.heightMin, autoPaint.heightMax, autoPaint.slopeMin, autoPaint.slopeMax, autoPaint.coverage)
          setTerrainDirty()

          editor.history:commitAction(
            "Terrain_AutoPaint",
            {
              objectId = 0,
              property =  "auto_paint",
              layer = 0,
              newValue = "",
              oldValue = ""
            },
            function()
              if scenetree.EUndoManager then
                scenetree.EUndoManager:undo()
              end
            end,
            function()
              if scenetree.EUndoManager then
                scenetree.EUndoManager:redo()
              end
            end
          )

          editor.closeModalWindow("autoPaintModal")
        end
      end
      editor.endModalWindow()

      terrainPainterWindowSize = im.GetWindowSize()

      local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
      if terrainBlock and terrainBlock:getField('materialTextureSet', 0) == "" then
        if im.TreeNodeEx1("Material Preview", im.TreeNodeFlags_DefaultOpen) then
          local size = im.GetContentRegionAvailWidth()
          size = size > editor.getPreference("terrainEditor.general.maxMaterialPreviewSize") and editor.getPreference("terrainEditor.general.maxMaterialPreviewSize") or size
          if selectedPaintMaterialProxy then
            im.Columns(2)
            im.Text("Diffuse")
            im.Image(selectedPaintMaterialProxy.diffuseMapObj.texId, im.ImVec2(size/2,size/2))
            im.Text("Detail")
            im.Image(selectedPaintMaterialProxy.detailMapObj.texId, im.ImVec2(size/2,size/2))

            im.NextColumn()

            im.Text("Macro")
            im.Image(selectedPaintMaterialProxy.macroMapObj.texId, im.ImVec2(size/2,size/2))
            im.Text("Normal")
            im.Image(selectedPaintMaterialProxy.normalMapObj.texId, im.ImVec2(size/2,size/2))
            im.Columns(1)
          end
          im.TreePop()
        end
      end

      if im.TreeNodeEx1("Material Selector", im.TreeNodeFlags_DefaultOpen) then
        local cursorPos = im.GetCursorPos()
        local childSize = im.ImVec2(
          0,
          terrainPainterWindowSize.y - cursorPos.y - (tableSize(notifications) * (var.fontSize + var.style.ItemSpacing.y)) - var.style.WindowPadding.y - (var.fontSize + 2*var.style.FramePadding.y + var.style.ItemSpacing.y)
        )
        local bottomButtonPosX = im.GetCursorPosX()
        if im.BeginChild1("MaterialSelectorChild", childSize) and tableSize(paintMaterialProxies) then
          local btnHeight = math.ceil(im.GetFontSize()) + 2
          local thisFrameHoveredIndex = nil
          for index, matProxy in ipairs(paintMaterialProxies) do
            if matProxy.inTerrainBlock then
              if dragDropPayload and dragDropPayload == index then
                local logColor = im.ImVec4(1,1,1,0.5)
                im.PushStyleColor2(im.Col_Text, logColor)
              end
              im.Selectable1(matProxy.internalName .. "##" .. index, selectedPaintMaterialProxyIndex == index or dragDropPayload == index or hoveredMatIndex == index, nil, im.ImVec2(im.GetContentRegionAvailWidth() - (var.style.ItemSpacing.x + btnHeight * im.uiscale[0] + 10), 0))
              if editor.IsItemClicked() then
                selectPaintMaterial(matProxy)
              end
              if dragDropPayload and dragDropPayload == index then
                im.PopStyleColor()
              end
              if editor.IsItemDoubleClicked(0) then
                selectPaintMaterial(matProxy)
                editor.showTerrainMaterialsEditor(matProxy.internalName)
              end
              if im.IsItemHovered(im.HoveredFlags_AllowWhenBlockedByActiveItem) then
                if im.IsMouseClicked(0) then
                  potentialDragDropPayload = index
                end
                if potentialDragDropPayload and im.IsMouseDragging(0) then
                  dragDropPayload = potentialDragDropPayload
                end
                if dragDropPayload then
                  thisFrameHoveredIndex = index
                  if im.IsMouseReleased(0) then
                    reorderMaterial(dragDropPayload, index)
                  end
                end
              end
              im.SameLine()
              if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(btnHeight, btnHeight)) then
                -- TODO: Add a `remove material`-modal
                removePaintMaterial(matProxy.index)
              end
              im.Separator()
            end
          end
          showAddLayerMaterialGui()
          hoveredMatIndex = thisFrameHoveredIndex
        end
        im.EndChild()
        im.TreePop()

        im.SetCursorPosX(bottomButtonPosX)
        local autoPaintButtonPosX = im.GetCursorPosX() + im.GetContentRegionAvailWidth() - im.GetStyle().ItemSpacing.x - im.GetStyle().FramePadding.x - im.GetStyle().ItemInnerSpacing.x - im.CalcTextSize("Auto Paint").x
        if im.Button("Terrain Material Library...") then
          editor.showTerrainMaterialsEditor()
        end
        im.SameLine()
        im.SetCursorPosX(autoPaintButtonPosX)
        if im.Button("Auto Paint##OpenModal") then
          editor.openModalWindow("autoPaintModal")
        end
        im.tooltip("Add, edit, delete terrain materials")
      end
      for id, notification in pairs(notifications) do
        im.TextColored(im.ImVec4(1.0, 0.73, 0.04, 1.0), notification)
      end
    end
  end
  editor.endWindow()

  if im.IsMouseReleased(0) then
    potentialDragDropPayload = nil
    dragDropPayload = nil
    hoveredMatIndex = nil
  end
end

local function savePreset(fddata)
  local data = {}

  data.name = ffi.string(terrainImpExp.terrainName)
  data.type = "TerrainData"
  data.squareSize = terrainImpExp.metersPerPixel[0]
  data.heightScale = terrainImpExp.heightScale[0]
  data.pos = {x = terrainImpExp.transformPos.x[0], y = terrainImpExp.transformPos.y[0], z = terrainImpExp.transformPos.z[0]}
  data.heightMapPath = ffi.string(terrainImpExp.heightMapTexture)
  data.holeMapPath = ffi.string(terrainImpExp.holeMapTexture)
  data.opacityMaps = {}

  local time = os.time()
  for k, map in ipairs(terrainImpExp.textureMaps) do
    table.insert(data.opacityMaps, map.path)
  end

  jsonWriteFile(fddata.filepath, data, true)
end

local function importTerrainDialogMenu()
  if im.BeginMenuBar() then
    if im.MenuItem1("Load preset") then
      editor_fileDialog.openFile(function(data) selectPreset(data) end, {{"Any files", "*"},{"Terrain Data", "terrainPreset.json"}}, false, var.lastPath)
    end
    if im.MenuItem1("Save Preset") then
      editor_fileDialog.saveFile(function(data) savePreset(data) end, {{"Terrain Data", "terrainPreset.json"}}, false, var.lastPath)
    end
    im.EndMenuBar()
  end
end

local function importTerrainDialog()
  if var.style == nil then return end
  if editor.beginWindow(terrainImportDialogName, "Import Terrain##Dialog", im.WindowFlags_MenuBar) then
    importTerrainDialogMenu()
    -- TERRAIN: NAME
    im.TextUnformatted("Terrain Name")
    im.SameLine()
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    im.InputText('##TerrainName', terrainImpExp.terrainName)
    im.PopItemWidth()
    -- TERRAIN: METERS PER PIXEL
    im.TextUnformatted("Meters per Pixel")
    im.SameLine()
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    im.InputFloat('##MetersPerPixel', terrainImpExp.metersPerPixel, 0.1, 1, "%.1f")
    im.PopItemWidth()
    -- TERRAIN: MAX HEIGHT
    im.TextUnformatted("Max Height")
    im.SameLine()
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    im.InputFloat('##MaxHeight', terrainImpExp.heightScale, 1, 5, "%.1f")
    im.PopItemWidth()
    --TERRAIN: HEIGHT MAP IMAGE
    im.Separator()
    im.TextUnformatted("Height Map Image:")
    local inputTextWidth = im.GetContentRegionAvailWidth() - (var.inputWidgetHeight or 24) - var.style.ItemSpacing.x
    im.PushItemWidth(inputTextWidth)
    im.InputText('##HeightMapImage', terrainImpExp.heightMapTexture, nil, im.InputTextFlags_CharsNoBlank)
    dragDropTarget(nil, "heightMap")
    im.PopItemWidth()
    im.SameLine()
    if im.Button("...##HeightMapImage", im.ImVec2(var.inputWidgetHeight, var.inputWidgetHeight)) then
      editor_fileDialog.openFile(function(data) terrainImpExp.heightMapTexture = im.ArrayChar(128, data.filepath) end, {{"Any files", "*"},{"Images",{".png", ".dds", ".jpg"}},{"PNG", ".png"}, {"JPG", ".jpg"}, {"DDS", ".dds"}}, false, var.lastPath, true)
    end
    im.tooltip("Browse...")
    --TERRAIN: HOLE MAP IMAGE
    im.TextUnformatted("Hole Map Image:")
    im.PushItemWidth(inputTextWidth)
    im.InputText('##HoleMapImage', terrainImpExp.holeMapTexture)
    dragDropTarget(nil, "holeMap")
    im.PopItemWidth()
    im.SameLine()
    if im.Button("...##HoleMapImage", im.ImVec2(var.inputWidgetHeight, var.inputWidgetHeight)) then
      editor_fileDialog.openFile(function(data) terrainImpExp.holeMapTexture = im.ArrayChar(128, data.filepath) end, {{"Any files", "*"},{"Images",{".png", ".dds", ".jpg"}},{"PNG", ".png"}, {"JPG", ".jpg"}, {"DDS", ".dds"}}, false, var.lastPath, true)
    end
    im.tooltip("Browse...")

    if im.CollapsingHeader1("Texture Maps", im.TreeNodeFlags_DefaultOpen) then
      for k, map in ipairs(terrainImpExp.textureMaps) do
        -- im.Spacing()
        local clr = (map.selected == true) and var.buttonColor or var.transparentColor
        im.PushStyleColor2(im.Col_Button, clr)
        local btnWidth = im.GetContentRegionAvailWidth() - (var.channelComboWidth + var.materialComboWidth + 2*var.style.ItemSpacing.x)
        if im.Button(map.path, im.ImVec2(btnWidth, var.inputWidgetHeight)) then
          if im.GetIO().KeyCtrl == true then
            toggleTextureMap(map, true)
          else
            toggleTextureMap(map)
          end
        end
        if btnWidth < im.CalcTextSize(map.path).x + 2*var.style.ItemSpacing.x then
          im.tooltip(map.path)
        end
        im.PopStyleColor()

        im.SameLine()
        im.SetCursorPosX(im.GetCursorPosX() + im.GetContentRegionAvailWidth() - (var.channelComboWidth + var.materialComboWidth + var.style.ItemSpacing.x))
        im.PushItemWidth(var.materialComboWidth)

        if im.Combo1("##MaterialCombo_" .. map.path, map.materialId, var.paintMaterialNamesArrayPtr) then
          map.material = var.paintMaterialNamesArray[map.materialId[0] + 1]
        end
        im.PopItemWidth()
        im.SameLine()
        im.PushItemWidth(var.channelComboWidth)
        if im.Combo2("##ChannelCombo_" .. map.path, map.channelId, "R\0G\0B\0\0") then
          map.channel = (map.channelId[0] == 0) and 'R' or ((map.channelId[0] == 1) and 'G' or 'B')
        end
        im.PopItemWidth()
      end
      -- a dedicated Selectable widget where users can drag and drop maps on to add them to the list of texture maps
      im.PushStyleColor2(im.Col_HeaderHovered, im.ImColorByRGB(0, 0, 0, 0).Value)
      im.PushStyleColor2(im.Col_HeaderActive, im.ImColorByRGB(0, 0, 0, 0).Value)
      im.Selectable1("##DragAndDropField", false)
      im.PopStyleColor(2)
      dragDropTarget(nil, "textureMap")
      im.Separator()
      if im.Button("+##AddTextureMap", im.ImVec2(var.inputWidgetHeight, var.inputWidgetHeight)) then
        editor_fileDialog.openFile(function(data) addTextureMap(data.filepath) end, {{"Any files", "*"},{"Images",{".png", ".dds", ".jpg"}},{"PNG", ".png"}, {"JPG", ".jpg"}, {"DDS", ".dds"}}, false, var.lastPath, true)
      end
      im.SameLine()
      if im.Button("-##RemoveTextureMap", im.ImVec2(var.inputWidgetHeight, var.inputWidgetHeight)) then
        removeTextureMap()
      end
    end

    -- TODO: apply to TerrainBlock if values have changed
    if im.CollapsingHeader1("Additional Data", im.TreeNodeFlags_DefaultOpen) then
      im.TextUnformatted("Apply Transform")
      im.SameLine()
      im.Checkbox("##ApplyTransform", terrainImpExp.applyTransform)

      im.TextUnformatted("Position")
      im.SameLine()
      local inputPosWidth = (im.GetContentRegionAvailWidth() - 2 * var.style.ItemInnerSpacing.x) / 3
      im.PushItemWidth(inputPosWidth)
      if im.InputFloat("##transformPosX", terrainImpExp.transformPos.x) then
        terrainImpExp.applyTransform[0] = true
      end
      im.SameLine()
      if im.InputFloat("##transformPosY", terrainImpExp.transformPos.y) then
        terrainImpExp.applyTransform[0] = true
      end
      im.SameLine()
      if im.InputFloat("##transformPosZ", terrainImpExp.transformPos.z) then
        terrainImpExp.applyTransform[0] = true
      end
      im.PopItemWidth()
    end

    im.Spacing()
    im.Separator()
    im.Spacing()

    im.TextUnformatted("Flip Y Axis? (old exporter)")
    im.SameLine()
    im.Checkbox("##FlipYAxis", terrainImpExp.flipYAxis)

    im.SameLine()
    im.SetCursorPosX((im.GetCursorPosX() + im.GetContentRegionAvailWidth()) - (im.CalcTextSize("Import").x + im.CalcTextSize("Cancel").x + 4*var.style.FramePadding.x +var.style.ItemSpacing.x ))
    if im.Button("Import##ImportTerrainAccept", im.ImVec2(0, var.inputWidgetHeight)) then
      terrainImporter_Accept()
    end
    im.SameLine()
    if im.Button("Cancel##ImportTerrainCancel", im.ImVec2(0, var.inputWidgetHeight)) then
      terrainImporter_Cancel()
    end
  end
  editor.endWindow()
end

local function exportTerrainDialog()
  if editor.beginWindow(terrainExportDialogName, "Export Terrain##Dialog") then
    if im.CollapsingHeader1("Select Terrain(s)", im.TreeNodeFlags_DefaultOpen) then
      for tbName, tbData in pairs(terrainBlockProxies) do
        im.Spacing()
        if im.Selectable1(tbName, tbData.selected) then
          if im.GetIO().KeyCtrl == true then
            toggleTerrainBlock(tbData, true)
          else
            toggleTerrainBlock(tbData)
          end
        end
      end
    end

    im.Spacing()
    im.Separator()
    im.Spacing()

    -- EXPORT PATH
    im.TextUnformatted("Export path:")
    local inputTextWidth = im.GetContentRegionAvailWidth() - var.inputWidgetHeight - var.style.ItemSpacing.x
    im.PushItemWidth(inputTextWidth)
    im.InputText("##TerrainExportPath_InputField", terrainImpExp.exportPath)
    im.PopItemWidth()
    im.SameLine()

    if im.Button("...##TerrainExportPath", im.ImVec2(var.inputWidgetHeight, var.inputWidgetHeight)) then
      editor_fileDialog.openFile(function(data) terrainImpExp.exportPath=im.ArrayChar(128, data.path) end, nil, true, var.lastPath)
    end
    im.tooltip("Browse...")

    im.Spacing()
    im.Separator()
    im.Spacing()

    if im.Button("Export##ExportTerrainAccept", im.ImVec2(0, var.inputWidgetHeight)) then
      terrainExporter_Accept()
    end
    im.SameLine()
    if editor.uiButtonRightAlign("Cancel", im.ImVec2(0, var.inputWidgetHeight), true, "ExportTerrainCancel") then
      terrainExporter_Cancel()
    end
  end
  editor.endWindow()
end

local function brushSoftnessCurveWindow()
  if editor.beginWindow(terrainBrushSoftnessCurveDialogName, "Brush Softness Curve##Dialog") then
    local drawList = im.GetWindowDrawList()
    local winPos = im.GetWindowPos()
    local winSize = im.GetWindowSize()
    local textWidthLeftBound = (im.CalcTextSize("Hard").x + var.style.ItemSpacing.x)
    local width = winSize.x-2*var.style.WindowPadding.x - textWidthLeftBound
    local height = (winSize.y-2*var.style.WindowPadding.y - (var.menuBarHeight + 2*var.inputWidgetHeight + 4*var.style.ItemSpacing.y + var.fontSize))
    var.sc_curveWidgetSize = (width > height) and height or width

    if im.Checkbox("Live Brush Update", getTempBool(editor.getPreference("terrainEditor.general.brushSoftnessCurveLiveUpdate"))) then
      editor.setPreference("terrainEditor.general.brushSoftnessCurveLiveUpdate", getTempBool())
      if editor.getPreference("terrainEditor.general.brushSoftnessCurveLiveUpdate") == true then
        brushSoftnessCurve_Set()
      end
    end

    if editor.uiButtonRightAlign("Default", nil, true, "brushSoftnessCurve", (var.sc_curveWidgetSize - im.GetContentRegionAvailWidth()) - (im.CalcTextSize("Reset").x + var.style.ItemSpacing.x + 2*var.style.FramePadding.x) + textWidthLeftBound) then
      brushSoftnessCurve_Default()
    end

    if editor.uiButtonRightAlign("Reset", nil, true, "brushSoftnessCurve", var.sc_curveWidgetSize - im.GetContentRegionAvailWidth() + textWidthLeftBound) then
      brushSoftnessCurve_Reset()
    end

    var.sc_curveWidgetPosA = im.ImVec2(winPos.x + im.GetCursorPosX() + textWidthLeftBound, winPos.y + im.GetCursorPosY())
    local posY = im.GetCursorPosY()

    im.TextUnformatted("Hard")
    im.SetCursorPosY(im.GetCursorPosY() + var.sc_curveWidgetSize - 2*var.fontSize - var.style.ItemSpacing.y)
    im.TextUnformatted("Soft")
    -- draw background
    im.ImDrawList_AddRectFilled(drawList, var.sc_curveWidgetPosA, im.ImVec2(var.sc_curveWidgetPosA.x+var.sc_curveWidgetSize, var.sc_curveWidgetPosA.y+var.sc_curveWidgetSize), var.sc_backgroundCol)
    -- draw background frame
    im.ImDrawList_AddRect(drawList, var.sc_curveWidgetPosA, im.ImVec2(var.sc_curveWidgetPosA.x+var.sc_curveWidgetSize, var.sc_curveWidgetPosA.y+var.sc_curveWidgetSize), var.sc_frameCol, 0, 0,2)
    -- draw the indentity line
    im.ImDrawList_AddLine(drawList, var.sc_curveWidgetPosA, im.ImVec2(var.sc_curveWidgetPosA.x+var.sc_curveWidgetSize, var.sc_curveWidgetPosA.y+var.sc_curveWidgetSize), var.sc_identityLineCol, 1)
    for i = 1, #var.softSelectFilter do
      im.SetCursorPos(im.ImVec2(var.style.WindowPadding.x + textWidthLeftBound +
        ((i - 1) / (#var.softSelectFilter - 1) * (var.sc_curveWidgetSize -
        editor.getPreference("terrainEditor.general.brushSoftnessCurveKnotSize"))),
        posY + (1 - var.softSelectFilter[i]) * (var.sc_curveWidgetSize - editor.getPreference("terrainEditor.general.brushSoftnessCurveKnotSize")) ))
      -- draw the knots
      im.PushStyleColor1(im.Col_Button, (i == var.sc_dragId) and var.sc_knotColorActive or var.sc_knotColor)
      im.PushStyleColor1(im.Col_ButtonHovered, var.sc_knotColorActive)
      im.PushStyleColor1(im.Col_ButtonActive, var.sc_knotColorActive)
      im.Button(
        "##softSelectButton" .. i,
        im.ImVec2(
          editor.getPreference("terrainEditor.general.brushSoftnessCurveKnotSize"),
          editor.getPreference("terrainEditor.general.brushSoftnessCurveKnotSize"))
      )
      if im.IsItemHovered() and not var.sc_dragId then
        im.tooltip(string.format("%.2f", var.softSelectFilter[i]))
        if im.IsMouseClicked(0) then
          var.sc_dragId = i
        end
      end
      im.PopStyleColor(3)
      -- draw the softness-'curve'
      -- TODO: draw an actual curve instead of a line -> guiFilterCtrl.cpp:158
      if i ~= #var.softSelectFilter then
        im.ImDrawList_AddLine(
          drawList,
          im.ImVec2(var.sc_curveWidgetPosA.x+((i-1)/(#var.softSelectFilter-1)*var.sc_curveWidgetSize), var.sc_curveWidgetPosA.y+((1-var.softSelectFilter[i])*var.sc_curveWidgetSize)),
          im.ImVec2(var.sc_curveWidgetPosA.x+(i/(#var.softSelectFilter-1)*var.sc_curveWidgetSize), var.sc_curveWidgetPosA.y+((1-var.softSelectFilter[i+1])*var.sc_curveWidgetSize)),
          var.sc_curveColor,
          1
        )
      end
    end

    if var.sc_dragId ~= nil then
      local delta = im.GetIO().MouseDelta.y / (var.sc_curveWidgetSize - editor.getPreference("terrainEditor.general.brushSoftnessCurveKnotSize"))
      var.softSelectFilter[var.sc_dragId] = var.softSelectFilter[var.sc_dragId] - (im.GetIO().MouseDelta.y / (var.sc_curveWidgetSize - editor.getPreference("terrainEditor.general.brushSoftnessCurveKnotSize")))
      if var.softSelectFilter[var.sc_dragId] < 0 then
        var.softSelectFilter[var.sc_dragId] = 0
      elseif var.softSelectFilter[var.sc_dragId] > 1 then
        var.softSelectFilter[var.sc_dragId] = 1
      end
    end

    if var.sc_dragId and im.IsMouseReleased(0) then
      var.sc_dragId = nil
      if editor.getPreference("terrainEditor.general.brushSoftnessCurveLiveUpdate") == true then
        brushSoftnessCurve_Set()
      end
    end

    im.SetCursorPos(im.ImVec2(textWidthLeftBound + var.style.WindowPadding.x, var.menuBarHeight + var.style.WindowPadding.y + var.sc_curveWidgetSize + 1*var.style.ItemSpacing.y + var.inputWidgetHeight))
    im.TextUnformatted("Inside")
    editor.uiTextUnformattedRightAlign("Outside", true, var.sc_curveWidgetSize - im.GetContentRegionAvailWidth() + textWidthLeftBound)
    im.SetCursorPosY(im.GetCursorPosY() + 2*var.style.ItemSpacing.y)
    if im.Button("Cancel##brushSoftnessCurve", im.ImVec2(0.5*((var.sc_curveWidgetSize + textWidthLeftBound)-var.style.ItemSpacing.x),var.inputWidgetHeight)) then
      brushSoftnessCurve_Cancel()
    end
    if editor.uiButtonRightAlign("Ok", im.ImVec2(0.5*((var.sc_curveWidgetSize + textWidthLeftBound)-var.style.ItemSpacing.x),var.inputWidgetHeight), true, "brushSoftnessCurve", var.sc_curveWidgetSize - im.GetContentRegionAvailWidth() + textWidthLeftBound) then
      brushSoftnessCurve_Accept()
    end
  end
  editor.endWindow()
end

local function setupVars()
  var.style = im.GetStyle()
  var.io = im.GetIO()
  var.fontSize = math.ceil(im.GetFontSize())
  var.menuBarHeight = 2*var.style.FramePadding.y + var.fontSize
  var.inputWidgetHeight = var.menuBarHeight
  var.channelComboWidth = im.CalcTextSize("R").x + 2*var.style.FramePadding.x + var.inputWidgetHeight
  var.materialComboWidth = var.maxMaterialNameWidth + 2*var.style.FramePadding.x + var.inputWidgetHeight
end

local function onEditorGui()
  profilerPushEvent("terrainEditor onEditorGui")
  importTerrainDialog()
  exportTerrainDialog()
  if active == true then
    setupVars()

    if state == stateEnum.sculpting then
      brushSoftnessCurveWindow()
    elseif state == stateEnum.painting then
      terrainPainterMaterialWindow()
    end
  end
  profilerPopEvent("terrainEditor onEditorGui")

  --TODO: nicusor: make a generic input action repeater
  if changeBrushSizeAutoRepeatOn then
    updateAutoRepeatChangeBrushSize()
  end
end
-- ##### GUI WINDOWS END #####

-- ##### GUI TOOLBAR #####
local function sliderFloat(text, id, val, vmin, vmax, format, power, editEnded, fn, tooltip)
  im.TextUnformatted(text)
  im.SameLine()
  local res = editor.uiSliderFloat(id, val, vmin, vmax, format, power, editEnded)
  if tooltip then
    im.tooltip(tooltip)
  end
  return res
end

local function inputFloat(text, id, val, vmin, vmax, step, stepFast, format, extra_flags, editEnded, tooltip)
  im.TextUnformatted(text)
  im.SameLine()
  local res = editor.uiInputFloat(id, val, step, stepFast, format, extra_flags, editEnded)
  val[0] = clamp(val[0], vmin, vmax)
  if tooltip then
    im.tooltip(tooltip)
  end
  return res
end

local function setBrushSize(value)
  value = (value or editor.getPreference("terrainEditor.general.brushSize"))
  editor.setPreference("terrainEditor.general.brushSize", value)
  local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
  if terrainBlock then
    terrainEditor:setBrushSize(value, value)
  end
end

local function setBrushPressure(value)
  value = (value or editor.getPreference("terrainEditor.general.brushPressure"))
  editor.setPreference("terrainEditor.general.brushPressure", value)
  terrainEditor:setBrushPressure(value / 100)
end

local function setBrushSoftness(value)
  value = (value or editor.getPreference("terrainEditor.general.brushSoftness"))
  editor.setPreference("terrainEditor.general.brushSoftness", value)
  terrainEditor:setBrushSoftness(value / 100)
end

local function setBrushHeight(value)
  value = (value or editor.getPreference("terrainEditor.general.brushHeight"))
  editor.setPreference("terrainEditor.general.brushHeight", value)
  terrainEditor:setField('setHeightVal', 0, value)
end

local function setBrushSlopeMaskMin(value)
  value = (value or editor.getPreference("terrainEditor.general.brushSlopeMaskMin"))
  editor.setPreference("terrainEditor.general.brushSlopeMaskMin", value)
  terrainEditor:setSlopeMinAngle(value)
end

local function setBrushSlopeMaskMax(value)
  value = (value or editor.getPreference("terrainEditor.general.brushSlopeMaskMax"))
  editor.setPreference("terrainEditor.general.brushSlopeMaskMax", value)
  terrainEditor:setSlopeMaxAngle(value)
end

local function changeBrushSize(value, step)
  if value == 1 then
    editor.setPreference("terrainEditor.general.brushSize", editor.getPreference("terrainEditor.general.brushSize") + step)
  elseif value == 0 then
    editor.setPreference("terrainEditor.general.brushSize", editor.getPreference("terrainEditor.general.brushSize") - step)
  end

  if value == 1 or value == 0 then
    editor.setPreference("terrainEditor.general.brushSize", clamp(editor.getPreference("terrainEditor.general.brushSize"), 1, 256))
    setBrushSize()
  end
end

local function terrainEditorEditModeToolbarBrushTypeButton(brushType, sameLine)
  local bgColor = (var.currentBrushType == brushType) and im.GetStyleColorVec4(im.Col_ButtonActive) or nil
  if editor.uiIconImageButton(brushType.icon, nil, nil, nil, bgColor) then
    switchBrushType(brushType, true)
  end
  if im.IsItemHovered() then im.tooltip(brushType.tooltip) end
  if sameLine == true then im.SameLine() end
end

local function terrainEditorEditModeToolbarBrushButton(brush)
  if brush.disabled and brush.disabled == true then
    im.BeginDisabled()
  end
  local bgColor = ((state == stateEnum.sculpting and currentAction == brush) or (state == stateEnum.painting and brush == paintBrush)) and im.GetStyleColorVec4(im.Col_ButtonActive) or nil
  if editor.uiIconImageButton(brush.icon, nil, nil, nil, bgColor) then
    switchAction(brush, true)
  end
  if im.IsItemHovered() then im.tooltip(brush.tooltip) end
  if brush.disabled and brush.disabled == true then
    im.EndDisabled()
  end
  im.SameLine()
end

local function brushSettingsSlider_common()
  local editEndedBrushSize = im.BoolPtr(false)
  local editEndedBrushPressure = im.BoolPtr(false)

  if sliderFloat("Size", "##brushSize", getTempFloat(editor.getPreference("terrainEditor.general.brushSize")), var.brushSizeMin, var.brushSizeMax, "%.0f", nil, editEndedBrushSize, setBrushSize, "Brush Size") then
    editor.setPreference("terrainEditor.general.brushSize", getTempFloat())
    setBrushSize()
  end
  im.SameLine()
  if sliderFloat("Pressure", "##brush pressure", getTempFloat(editor.getPreference("terrainEditor.general.brushPressure")), var.brushPressureMin, var.brushPressureMax, "%.2f", nil, editEndedBrushPressure, setBrushPressure, "Brush Pressure") then
    editor.setPreference("terrainEditor.general.brushPressure", getTempFloat())
    setBrushPressure()
  end
  im.SameLine()

  -- check if user used brush setting sliders
  if editEndedBrushSize[0] == true then
    -- clamp value
    if editor.getPreference("terrainEditor.general.brushSize") < var.brushSizeMin then
      editor.setPreference("terrainEditor.general.brushSize", var.brushSizeMin)
    elseif editor.getPreference("terrainEditor.general.brushSize") > var.brushSizeMax then
      editor.setPreference("terrainEditor.general.brushSize", var.brushSizeMax)
    end
    setBrushSize()
  end
  if editEndedBrushPressure[0] == true then
    -- clamp value
    if editor.getPreference("terrainEditor.general.brushPressure") < var.brushPressureMin then
      editor.setPreference("terrainEditor.general.brushPressure", var.brushPressureMin)
    elseif editor.getPreference("terrainEditor.general.brushPressure") > var.brushPressureMax then
      editor.setPreference("terrainEditor.general.brushPressure", var.brushPressureMax)
    end
    setBrushPressure()
  end
end

local function brushSettingsSlider_sculpting()
  local editEndedBrushSoftness = im.BoolPtr(false)
  local editEndedBrushHeight = im.BoolPtr(false)

  im.SameLine()
  if sliderFloat("Softness", "##brush softness", getTempFloat(editor.getPreference("terrainEditor.general.brushSoftness")), var.brushSoftnessMin, var.brushSoftnessMax, "%.2f", nil, editEndedBrushSoftness, setBrushSoftness, "Brush Softness") then
    editor.setPreference("terrainEditor.general.brushSoftness", getTempFloat())
    setBrushSoftness()
  end
  im.SameLine()
  im.SetCursorPosY(im.GetCursorPosY() - 4)
  local bgcol = (editor.isWindowVisible(terrainBrushSoftnessCurveDialogName) == true) and im.GetStyleColorVec4(im.Col_ButtonActive) or nil
  if editor.uiIconImageButton(editor.icons.tb_scurve_softer, nil, nil, nil, bgcol, "brushSettings_sculpting_brushSoftnessCurve") then
    brushSoftnessCurve_Toggle()
  end
  im.tooltip("Changes the softness curve")
  im.SameLine()
  im.SetCursorPosY(im.GetCursorPosY() + 4)
  if inputFloat("Height", "##brush height", getTempFloat(editor.getPreference("terrainEditor.general.brushHeight")), var.brushHeightMin, var.brushHeightMax, 1, 10, "%.2f", nil, editEndedBrushHeight, "Height") then
    editor.setPreference("terrainEditor.general.brushHeight", getTempFloat())
    setBrushHeight()
  end
  -- terrain height picking icon
  im.SameLine()
  im.SetCursorPosY(im.GetCursorPosY() - 4)
  bgcol = (var.brushHeightPicking == true) and im.GetStyleColorVec4(im.Col_ButtonActive) or nil
  if editor.uiIconImageButton(editor.icons.terrain_height_picking, nil, nil, nil, bgcol, "pickTerrainHeight") then
    var.brushHeightPicking = not var.brushHeightPicking
  end
  im.tooltip("Terrain Height Picker")
  if editEndedBrushSoftness[0] == true then
    if editor.getPreference("terrainEditor.general.brushSoftness") < var.brushSoftnessMin then
      editor.setPreference("terrainEditor.general.brushSoftness", var.brushSoftnessMin)
    elseif editor.getPreference("terrainEditor.general.brushSoftness") > var.brushSoftnessMax then
      editor.setPreference("terrainEditor.general.brushSoftness", var.brushSoftnessMax)
    end
    setBrushSoftness()
  end
  if editEndedBrushHeight[0] == true then
    if editor.getPreference("terrainEditor.general.brushHeight") < var.brushHeightMin then
      editor.setPreference("terrainEditor.general.brushHeight", var.brushHeightMin)
    elseif editor.getPreference("terrainEditor.general.brushHeight") > var.brushHeightMax then
      editor.setPreference("terrainEditor.general.brushHeight", var.brushHeightMax)
    end
    setBrushHeight()
  end
end

local function brushSettingsSlider_painting()
  local editEndedBrushSlopeMaskMin = im.BoolPtr(false)
  local editEndedBrushSlopeMaskMax = im.BoolPtr(false)

  im.SameLine()
  im.TextUnformatted("Slope Mask")
  im.SameLine()
  if sliderFloat("Min", "##brushSlopeMaskMin", getTempFloat(editor.getPreference("terrainEditor.general.brushSlopeMaskMin")), 0, editor.getPreference("terrainEditor.general.brushSlopeMaskMax") - 0.1, "%.1f", nil, editEndedBrushSlopeMaskMin, setBrushSlopeMaskMin) then
    editor.setPreference("terrainEditor.general.brushSlopeMaskMin", getTempFloat())
    setBrushSlopeMaskMin()
  end
  im.SameLine()
  if sliderFloat("Max", "##brushSlopeMaskMax", getTempFloat(editor.getPreference("terrainEditor.general.brushSlopeMaskMax")), editor.getPreference("terrainEditor.general.brushSlopeMaskMin") + 0.1, 90, "%.1f", nil, editEndedBrushSlopeMaskMax, setBrushSlopeMaskMax) then
    editor.setPreference("terrainEditor.general.brushSlopeMaskMax", getTempFloat())
    setBrushSlopeMaskMax()
  end

  if editEndedBrushSlopeMaskMin[0] == true then
    if editor.getPreference("terrainEditor.general.brushSlopeMaskMin") <= 0 then
      editor.setPreference("terrainEditor.general.brushSlopeMaskMin", 0)
    elseif editor.getPreference("terrainEditor.general.brushSlopeMaskMin") >= editor.getPreference("terrainEditor.general.brushSlopeMaskMax") then
      editor.setPreference("terrainEditor.general.brushSlopeMaskMin", editor.getPreference("terrainEditor.general.brushSlopeMaskMax") - 0.1)
    end
    setBrushSlopeMaskMin()
  end
  if editEndedBrushSlopeMaskMax[0] == true then
    if editor.getPreference("terrainEditor.general.brushSlopeMaskMax") >= 90 then
      editor.setPreference("terrainEditor.general.brushSlopeMaskMax", 90)
    elseif editor.getPreference("terrainEditor.general.brushSlopeMaskMax") <= editor.getPreference("terrainEditor.general.brushSlopeMaskMin") then
      editor.setPreference("terrainEditor.general.brushSlopeMaskMax", editor.getPreference("terrainEditor.general.brushSlopeMaskMin") + 0.1)
    end
    setBrushSlopeMaskMax()
  end
end

local function terrainToolsEditModeToolbar()
  local bgColor = editor.isWindowVisible(terrainImportDialogName) and im.GetStyleColorVec4(im.Col_ButtonActive) or nil
  if editor.uiIconImageButton(editor.icons.terrain_import, nil, nil, nil, bgColor, "ImportTerrainButton") then
    openImportTerrainDialog()
  end
  im.tooltip("Import Terrain")
  im.SameLine()

  bgColor = editor.isWindowVisible(terrainExportDialogName) and im.GetStyleColorVec4(im.Col_ButtonActive) or nil
  if editor.uiIconImageButton(editor.icons.terrain_export, nil, nil, nil, bgColor, "ExportTerrainButton") then
    openExportTerrainDialog()
  end
  im.tooltip("Export Terrain")
  editor.uiVertSeparator(32)

  for i, brushType in ipairs(brushTypes) do
    terrainEditorEditModeToolbarBrushTypeButton(brushType, true)
  end
  editor.uiVertSeparator(32)

  for i, brush in ipairs(terrainBrushes) do
    terrainEditorEditModeToolbarBrushButton(brush)
  end
  editor.uiVertSeparator(32)

  terrainEditorEditModeToolbarBrushButton(paintBrush)

  im.PushItemWidth(brushSettingSliderWidth)
  im.SetCursorPosY(im.GetCursorPosY()+4)
  brushSettingsSlider_common()

  if state == stateEnum.sculpting then
    brushSettingsSlider_sculpting()
  elseif state == stateEnum.painting then
    brushSettingsSlider_painting()
  end

  im.PopItemWidth()
end
-- ##### GUI TOOLBAR END #####

local function checkForTerrainMaterialFileFormat()
  -- If there is no "terrain" folder, use the deprecated "terrains" instead
  matFilePath = "/art/terrain/main.materials.json"
  terrainFolder = "/art/terrain/"
  if not FS:fileExists(var.levelPath .. matFilePath) then
    if FS:fileExists(var.levelPath .. "/art/terrains/main.materials.json") then
      matFilePath = "/art/terrains/main.materials.json"
      terrainFolder = "/art/terrains/"
    elseif FS:fileExists(var.levelPath .. "/art/terrains/materials.json") then
      editor.logWarn("Deperecated Terrain Material file.")
      errors["deprecated_material_file"] = true
      -- use new location in case user wants to upgrade their materials
      matFilePath = "/art/terrain/main.materials.json"
      terrainFolder = "/art/terrain/"
    end
  end
end

local function initialize()
  if not scenetree.terrEd_PersistMan then
    local persistenceMgr = PersistenceManager()
    persistenceMgr:registerObject("terrEd_PersistMan")
  end

  var.levelPath = '/levels/'
  var.levelName = ""
  local i = 1
  for str in string.gmatch(getMissionFilename(),"([^/]+)") do
    if i == 2 then
      var.levelPath = var.levelPath .. str
      var.levelName = str
    end
    i = i + 1
  end

  checkForTerrainMaterialFileFormat()

  var.lastPath = var.levelPath
  terrainEditor = TerrainEditor()
  gui3DMouseEvent = Gui3DMouseEvent()

  terrainBrushes = {
    -- brushAdjustHeight is disabled for the time being since MouseLock is not implemented yet in the new editor api
    {
      name = "brushAdjustHeight",
      tooltip = "Grab Terrain",
      description = "Description",
      icon = editor.icons.terrain_grab,
      disabled = true
    },
    {
      name = "raiseHeight",
      tooltip = "Raise Height",
      description = "Description",
      icon = editor.icons.terrain_height_raise
    },
    {
      name = "lowerHeight",
      tooltip = "Lower Height",
      description = "Description",
      icon = editor.icons.terrain_height_lower,
    },
    {
      name = "smoothHeightNew",
      tooltip = "Really smooth (new)",
      description = "Description",
      icon = editor.icons.terrain_reall_smooth_new
    },
    {
      name = "smoothSlope",
      tooltip = "Smooth Slope",
      description = "Description",
      icon = editor.icons.terrain_smooth_slope
    },
    {
      name = "paintNoise",
      tooltip = "Paint Noise",
      description = "Description",
      icon = editor.icons.terrain_paint_noise
    },
    {
      name = "flattenHeight",
      tooltip = "Flatten",
      description = "Description",
      icon = editor.icons.terrain_flatten
    },
    {
      name = "setHeight",
      tooltip = "Set Height",
      description = "Description",
      icon = editor.icons.terrain_set_height
    },
    {
      name = "setEmpty",
      tooltip = "Clear Terrain",
      description = "Description",
      icon = editor.icons.terrain_clear,
      destructive = true
    },
    {
      name = "clearEmpty",
      tooltip = "Restore Terrain",
      description = "Description",
      icon = editor.icons.terrain_restore
    },
    -- {
    --   name = "thermalErode",
    --   tooltip = "Thermal Erosion",
    --   description = "Description",
    -- brushColor = ColorF(1,0,0,1),--
    -- icon = editor.icons.donut_small
    -- },
    {
      name = "smoothBroken",
      tooltip = "Average Height (old smooth)",
      description = "Description",
      icon = editor.icons.terrain_average_height
    },
    {
      name = "alignMeshUp",
      tooltip = "Align with mesh (up)",
      description = "Description",
      icon = editor.icons.terrain_align_up
    },
    {
      name = "alignMeshDown",
      tooltip = "Align with mesh (down)",
      description = "Description",
      icon = editor.icons.terrain_align_down
    },
    {
      name = "substractMesh",
      tooltip = "Substract Mesh",
      description = "Description",
      icon = editor.icons.terrain_mesh_subtract
    }
  }

  paintBrush = {
    name = "paintMaterial",
    tooltip = "Terrain Painter",
    description = "Description",
    icon = editor.icons.terrain_painting
  }

  brushTypes = {
    {name = "ellipse", tooltip = "Circle Brush", description = "Description", icon = editor.icons.terrain_brush_circle},
    {name = "box", tooltip = "Box Brush", description = "Description", icon = editor.icons.terrain_brush_box}
  }

  updateTerrainBlockProxies()

  -- set default terrainBlock
  if next(terrainBlockProxies) then
    terrainBlockId = terrainBlockProxies[next(terrainBlockProxies)].id
  else
    log('E', "", "No TerrainBlock object present")
  end

  local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
  if terrainBlock then
    -- attach TerrainBlock to TerrainEditor
    terrainEditor:attachTerrain(terrainBlock)
    updatePaintMaterialProxies()
    local idx, mtl = next(paintMaterialProxies)
    selectPaintMaterial(mtl)
  end
end

local function undo()
  if scenetree.EUndoManager then
    scenetree.EUndoManager:undo()
  end
end

local function redo()
  if scenetree.EUndoManager then
    scenetree.EUndoManager:redo()
  end
end

local function terrainToolsEditModeUpdate()
  profilerPushEvent("terrainEditor terrainToolsEditModeUpdate")
  for tbName, tbData in pairs(terrainBlockProxies) do
    local tb = scenetree.findObjectById(tbData.id)
    if not tb then updateEditorTerrainBlocks() break end
  end
  terrainEditor:onPreRender()
  local hit
  if im.GetIO().WantCaptureMouse == false then
    hit = cameraMouseRayCast(false, im.flags(SOTTerrain))
    if not brushCenter and hit or brushCenter then
      if var.brushHeightPicking == false then
        local mouseRay = getCameraMouseRay()
        gui3DMouseEvent.pos = mouseRay.pos
        gui3DMouseEvent.vec = mouseRay.dir

        if not brushCenter or im.GetIO().MouseDelta.x ~= 0 or im.GetIO().MouseDelta.y ~= 0 then
          brushCenter = hit and hit.pos or nil
        end

        if brushCenter then
          local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
          if terrainBlock then
            local color = nil
            if not currentAction.destructive then
              color = editor.getPreference("gizmos.brush.createBrushColor")
            else
              color = editor.getPreference("gizmos.brush.deleteBrushColor")
            end

            editor.drawBrush(
              var.currentBrushType.name,
              brushCenter,
              (editor.getPreference("terrainEditor.general.brushSize") / 2) * terrainBlock:getSquareSize(),
              var.brushSegments,
              color,
              terrainBlock,
              var.brushRatio,
              var.brushRotation,
              true
            )
          end

          -- Mouse down.
          if im.IsMouseClicked(0) and hit then
            terrainEditor:on3DMouseDown(gui3DMouseEvent)
            terrainEditor:scheduleGridUpdate()
            startDragHeight = hit.pos.z
            mouseState = mouseStateEnum.down
          end

          -- Mouse drag.
          if im.GetIO().MouseDelta.x ~= 0 or im.GetIO().MouseDelta.y ~= 0 then
            if im.IsMouseDown(0) and startDragHeight then
              terrainEditor:on3DMouseDragged(gui3DMouseEvent, true)
            else
              terrainEditor:on3DMouseMove(gui3DMouseEvent)
            end
            mouseState = mouseStateEnum.moving
          end

          -- Mouse released.
          if im.IsMouseReleased(0) and startDragHeight then
            if mouseState == mouseStateEnum.moving or mouseState == mouseStateEnum.down then
              terrainEditor:on3DMouseUp(gui3DMouseEvent, true)
              mouseState = mouseStateEnum.released
              setTerrainDirty()

              editor.history:commitAction(
                "TerrainEditor",
                {},
                undo,
                redo,
                true
              )
            end
            startDragHeight = nil
          end
        end

      -- Terrain Height picker tool active
      else
        debugDrawer:drawSphere(hit.pos, 0.1, ColorF(1,0,0,1))
        if im.IsMouseClicked(0) then
          var.brushHeightPicking = false
          local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
          if terrainBlock then
            local height = terrainBlock:getHeight(vec3(hit.pos.x,hit.pos.y,0)) - terrainBlock:getPosition().z
            editor.setPreference("terrainEditor.general.brushHeight", height)
            setBrushHeight()
          end
        elseif im.IsMouseClicked(1) then
          var.brushHeightPicking = false
        end
      end
    end
  else
    mouseState = mouseStateEnum.released
  end

  if not hit and startDragHeight then
    terrainEditor:on3DMouseUp(gui3DMouseEvent, true)
    mouseState = mouseStateEnum.released
    setTerrainDirty()

    editor.history:commitAction(
      "TerrainEditor",
      {},
      undo,
      redo,
      true
    )
    startDragHeight = nil
  end
  profilerPopEvent("terrainEditor terrainToolsEditModeUpdate")
end

local function terrainToolsEditModeActivate()
  active = true
  if state == 1 then
    editor.showWindow(terrainPainterWindowName)
  end

  if not scenetree.EUndoManager then
    local undoManager = UndoManager()
    undoManager:registerObject('EUndoManager')
  end

  updateMaterialLibrary()
end

local function terrainToolsEditModeDeactivate()
  editor.hideWindow(terrainPainterWindowName)
  editor.hideWindow(terrainImportDialogName)
  editor.hideWindow(terrainExportDialogName)
  editor.hideWindow(terrainBrushSoftnessCurveDialogName)
  brushSoftnessCurve_Cancel()
  active = false
end

local function onEditorBeforeSaveLevel()
  if notifications["materialsDirty"] then
    saveMaterials()
    -- we only clear dirty when not autosaving
    if not editor.autosavingNow then
      notifications["materialsDirty"] = nil
    end
    editor.showNotification("Saved TerrainMaterials")
  end
  if notifications["terrainDirty"] then
    local terrainBlock = terrainBlockId and scenetree.findObjectById(terrainBlockId)
    if terrainBlock then
      terrainBlock:save(terrainBlock:getTerrFileName())
    end
    -- we only clear dirty when not autosaving
    if not editor.autosavingNow then
      notifications["terrainDirty"] = nil
    end
    editor.showNotification("Saved TerrainBlock")
  end
end

local function onEditorAfterSaveLevel()
  materialsInJson = {}
  updateMaterialLibrary()
end

local function onEditorPreferenceValueChanged(path, value)
  --TODO: perhaps use the preferences directly without the var table
  if path == "terrainEditor.general.brushSize" then setBrushSize() end
  if path == "terrainEditor.general.brushPressure" then setBrushPressure() end
  if path == "terrainEditor.general.brushSoftness" then setBrushSoftness() end
  if path == "terrainEditor.general.brushHeight" then setBrushHeight() end
  if path == "terrainEditor.general.brushSlopeMaskMin" then setBrushSlopeMaskMin() end
  if path == "terrainEditor.general.brushSlopeMaskMax" then setBrushSlopeMaskMax() end
  if path == "terrainEditor.general.softSelectFilter" then var.softSelectFilter = deepcopy(value) brushSoftnessCurve_Set(var.softSelectFilter) end

  local function getFirstBrush()
    local found = false
    for i = 1, #terrainBrushes do
      if found == false then
        if terrainBrushes[i].disabled == true then
        else
          switchAction(terrainBrushes[i])
          found = true
        end
      end
    end
  end

  -- set brush/action
  if path == "terrainEditor.general.brush" then
    local brushName = value
    -- if no brush was saved, take the first non-disabled entry
    if brushName ~= "" then
      if brushName == "paintMaterial" then
        switchAction(paintBrush)
      else
        local brush = getBrushByName(brushName)
        if brush then
          switchAction(getBrushByName(brushName))
        else
          getFirstBrush()
        end
      end
    else
      getFirstBrush()
    end
  end

  if path == "terrainEditor.general.brushType" then
    local brushTypeName = value
    -- if no brush type was saved, take ellipse brush type as default
    if brushTypeName ~= "" then
      for _, brushType in ipairs(brushTypes) do
        if brushTypeName == brushType.name then
          switchBrushType(brushType)
        end
      end
    else
      switchBrushType(brushTypes[1])
    end
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("terrainEditor")
  prefsRegistry:registerSubCategory("terrainEditor", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {maxMaterialPreviewSize = {"float", 256, "Maximum material preview size", nil, 64, 1024}},
    {brushSoftnessCurveKnotSize = {"float", 8, "", nil, 4, 32}},
    {brushSoftnessCurveLiveUpdate = {"bool", true, ""}},
    {brushSize = {"float", 1, "", nil, var.brushSizeMin, var.brushSizeMax}},
    {brushSizeChangeIntervalWithKeys = {"float", 0.001, "When using [ ] keys to resize brush, time in seconds between two steps", nil, 0.0001, 1}},
    {brushSizeChangeStepWithKeys = {"float", 0.5, "When using [ ] keys to resize brush", nil, 0.01, 100}},
    {brushSizeChangeStepWithWheel = {"float", 1, "When using mouse wheel to resize brush", nil, 0.01, 100}},
    {brushPressure = {"float", 100, "", nil, var.brushPressureMin, var.brushPressureMax}},
    {brushSoftness = {"float", 100, "", nil, var.brushSoftnessMin, var.brushSoftnessMax}},
    {brushHeight = {"float", 100, "", nil, var.brushHeightMin, var.brushHeightMax}},
    {brushSlopeMaskMin = {"float", 0, "", nil, 0, 90}},
    {brushSlopeMaskMax = {"float", 90, "", nil, 0, 90}},
    -- hidden
    {softSelectFilter = {"table", var.softSelectFilterDefault, "", nil, nil, nil, true}},
    {brush = {"string", "", "", nil, nil, nil, true}},
    {brushType = {"string", "", "", nil, nil, nil, true}},
  })
  prefsRegistry:registerSubCategory("terrainEditor", "terrainMaterialLibrary", nil,
  {
  {keepSizeForAllMaps = {"bool", true, [[
When modifying a size property the same property will be changed for all maps of this material.

Applies to 'texture size', 'macro texture size' and 'detail texture size'.
]]}},
  })
end

local function onEditorInitialized()
  editor.registerWindow(terrainPainterWindowName, im.ImVec2(240,550))
  editor.registerWindow(terrainImportDialogName, im.ImVec2(350,480), nil, false)
  editor.registerWindow(terrainExportDialogName, im.ImVec2(230,270), nil, false)
  editor.registerWindow(terrainBrushSoftnessCurveDialogName, im.ImVec2(330,400), nil, false)

  editor.registerModalWindow("autoPaintModal", im.ImVec2(430, 320))

  editor.editModes.terrainToolsEditMode =
  {
    displayName = "Edit Terrain",
    onActivate = terrainToolsEditModeActivate,
    onDeactivate = terrainToolsEditModeDeactivate,
    onUpdate = terrainToolsEditModeUpdate,
    onToolbar = terrainToolsEditModeToolbar,
    actionMap = "terrainTools", -- if available, not required
    icon = editor.icons.terrain_tools,
    iconTooltip = "Terrain Tools",
    hideObjectIcons = true
  }

  initialize()
end

local function onEditorDeactivated()
end

local function onClientEndMission()
  materialsInJson = {}
end

local function onEditorObjectAdded(id)
  local obj = scenetree.findObjectById(id)
  if obj and obj:getClassName() == "TerrainBlock" then
    updateTerrainBlockProxies()
    updateEditorTerrainBlocks()
  end
end

-- public interface
M.onEditorInitialized = onEditorInitialized
M.onEditorDeactivated = onEditorDeactivated
M.onEditorGui = onEditorGui
M.onEditorBeforeSaveLevel = onEditorBeforeSaveLevel
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged
M.onEditorObjectAdded = onEditorObjectAdded
M.onClientEndMission = onClientEndMission

M.changeBrushSize = changeBrushSize
M.updateTerrainBlockProxies = updateTerrainBlockProxies
M.updateMaterialLibrary = updateMaterialLibrary
M.getUniqueMtlName = getUniqueMtlName
M.createMaterialProxy = createMaterialProxy
M.getMtlIdByName = getMtlIdByName
M.setMaterialsDirty = setMaterialsDirty
M.setTerrainDirty = setTerrainDirty
M.saveMaterials = saveMaterials
M.saveTerrainAndMaterials = saveTerrainAndMaterials
M.copyMaterialProxyWithInputs = copyMaterialProxyWithInputs
M.setupVars = setupVars
M.dragDropTarget = dragDropTarget
M.updatePaintMaterialProxies = updatePaintMaterialProxies
M.updateMap = updateMap
M.removeMap = removeMap
M.selectPaintMaterial = selectPaintMaterial
M.fixGroundmodelName = fixGroundmodelName
M.checkForTerrainMaterialFileFormat = checkForTerrainMaterialFileFormat

M.deleteMaterialInJson = function (name)
  for id, value in pairs(materialsInJson) do
    if value.internalName == name then
      materialsInJson[id] = nil
      break
    end
  end
end

M.getTerrainBlockMaterialIndex = function (name)
  for id, value in pairs(paintMaterialProxies) do
    if value.internalName == name then
      return value.index
    end
  end
  return -1
end

M.getVars = function () return var end
M.getTerrainEditor = function() return terrainEditor end
M.getTerrainBlock = function() return terrainBlockId and scenetree.findObjectById(terrainBlockId) end
M.getMaterialsInJson = function() return materialsInJson end
M.getSelectedPaintMaterialProxy = function() return selectedPaintMaterialProxy end
M.getPaintMaterialProxies = function() return paintMaterialProxies end
M.getTerrainBlockProxies = function() return terrainBlockProxies end
M.getMatFilePath = function() return matFilePath end
M.getTerrainFolder = function() return terrainFolder end
M.getErrors = function() return errors end
M.getLevelPath = function() return var.levelPath end
M.fixedFileFormat = function() errors["deprecated_material_file"] = nil end
M.beginChangeBrushSizeWithKeys = function (direction) changeBrushSizeAutoRepeatOn = true changeBrushSizeTimer = 0 changeBrushSizeDirection = direction end
M.endChangeBrushSizeWithKeys = function () changeBrushSizeAutoRepeatOn = false changeBrushSizeTimer = 0 end

return M