-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local json = require("json")
local jbeamIO = require('jbeam/io')

local vehManager = extensions.core_vehicle_manager

local vehsPartsHighlighted = {}

local function savePartConfigFileStage2(partsCondition, filename)
  local playerVehicle = be:getPlayerVehicle(0)
  local playerVehicleData = vehManager.getPlayerVehicleData()
  if not playerVehicle or not playerVehicleData then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end

  local data = playerVehicleData.config
  data.partConfigFilename = nil
  data.format = 2
  data.model = playerVehicleData.model or playerVehicleData.vehicleDirectory:gsub("vehicles/", ""):gsub("/", "")
  data.partsCondition = partsCondition
  if not data.paints or data.colors then
    data.paints = {}
    local colorTable = playerVehicle:getColorFTable()
    local colorTableSize = tableSize(colorTable)
    for i = 1, colorTableSize do
      local metallicPaintData = stringToTable(playerVehicle:getField('metallicPaintData', i - 1))
      local paint = createVehiclePaint({x = colorTable[i].r, y = colorTable[i].g, z = colorTable[i].b, w = colorTable[i].a}, metallicPaintData)
      validateVehiclePaint(paint)
      table.insert(data.paints, paint)
    end

    if #data.paints > 0 then
      data.colors = nil
    end
  end
  data.licenseName = extensions.core_vehicles.makeVehicleLicenseText()

  local res = jsonWriteFile(filename, data, true)
  if res then
    guihooks.trigger("VehicleconfigSaved", {})
  else
    log('W', "vehicles.save", "unable to save config: "..fn)
  end
  guihooks.trigger('Message', {ttl = 15, msg = 'Configuration saved', icon = 'directions_car'})
end

local function savePartConfigFile(filename)
  local savePartsCondition = false
  if savePartsCondition then
    local playerVehicle = be:getPlayerVehicle(0)
    if playerVehicle then
      queueCallbackInVehicle(playerVehicle, "extensions.core_vehicle_partmgmt.savePartConfigFileStage2", "partCondition.getConditions("..serialize(filename)..")")
    end
  else
    savePartConfigFileStage2(nil, filename)
  end
end


local function saveLocal(fn)
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end
  savePartConfigFile(playerVehicle.vehicleDirectory .. fn)
end

local function saveLocalScreenshot(fn)
  -- See ui/modules/vehicleconfig/vehicleconfig.js (line 420)
  -- Set up camera
  commands.setFreeCamera()
  setCameraFovDeg(35)
  -- Stage 1 happens on JS side for timing reasons
  guihooks.trigger("saveLocalScreenshot_stage1", {})
end

-- Stage 2
local function saveLocalScreenshot_stage2(fn)
  -- Take screenshot
  local playerVehicle = vehManager.getPlayerVehicleData()
  local screenshotName = (playerVehicle.vehicleDirectory .. fn)
  screenshot.doScreenshot(nil, nil, screenshotName, 'jpg')
  -- Stage 3 on JS side
  guihooks.trigger('saveLocalScreenshot_stage3', {})
end


local function savedefault()
  guihooks.trigger('Message', {ttl = 5, msg = 'New default vehicle has been set', icon = 'directions_car'})
  savePartConfigFile('settings/default.pc')
end

local function sendDataToUI()
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end

  local data = {
    mainPartName     = playerVehicle.mainPartName,
    chosenParts      = playerVehicle.chosenParts,
    variables        = playerVehicle.vdata.variables,
    availableParts   = jbeamIO.getAvailableParts(playerVehicle.ioCtx),
    slotMap          = jbeamIO.getAvailableSlotMap(playerVehicle.ioCtx),
  }

  -- enrich the data a bit for the UI
  for partName, part in pairs(data.availableParts) do
    if part.modName then
      local mod = core_modmanager.getModDB(part.modName)
      if mod and mod.modData then
        part.modTagLine    = mod.modData.tag_line
        part.modTitle      = mod.modData.title
        part.modLastUpdate = mod.modData.last_update
      end
    end
  end

  guihooks.trigger("VehicleConfigChange", data)
end

local function setDynamicTextureMaterials()
  local vehicle = be:getPlayerVehicle(0)
  local playerVehicleData = core_vehicle_manager.getPlayerVehicleData()

  if not vehicle or not playerVehicleData then return end

  local partName = vehicle.JBeam .. "_skin_dynamicTextures"
  local parts = jbeamIO.getAvailableParts(playerVehicleData.ioCtx)
  local skinfound = false
  for k, v in pairs(parts) do
    if k == partName then
      skinfound = true
    end
  end

  if not skinfound then return end

  local carConfigToLoad = playerVehicleData.config
  carConfigToLoad.parts["paint_design"] = partName
  local carModelToLoad = vehicle.JBeam
  local vehicleData = {}
  vehicleData.config = carConfigToLoad
  core_vehicles.replaceVehicle(carModelToLoad, vehicleData)
end

local function reset()
  sendDataToUI()
end


local function mergeConfig(inData, respawn)
  local veh = be:getPlayerVehicle(0)
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not veh or not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end

  if respawn == nil then respawn = true end -- respawn is required all the time except when loading the vehicle

  if not inData or type(inData) ~= 'table' then
    log('W', "partmgmt.mergeConfig", "invalid argument [" .. type(inData) .. '] = '..dumps(inData))
    return
  end

  tableMerge(playerVehicle.config, inData)

  if respawn then
    veh:respawn(serialize(playerVehicle.config))
  else
    local paintCount = tableSize(inData.paints)
    for i = 1, paintCount do
      vehManager.liveUpdateVehicleColors(veh:getId(), veh, i, inData.paints[i])
    end
    veh:setField('partConfig', '', serialize(playerVehicle.config))
  end
end

local function setConfigPaints (data, respawn)
  mergeConfig({paints = data}, respawn)
end

local function setConfigVars (data, respawn)
  mergeConfig({vars = data}, respawn)
end

local function setPartsConfig (data, respawn)
  mergeConfig({parts = data}, respawn)
end

local function getConfig()
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end
  return playerVehicle.config
end

local function loadPartConfigFile(filename, respawn)
  -- try to load json first
  local content = readFile(filename)
  if content ~= nil then
    local state, data = pcall(json.decode, content)
    if state == true then
      data.partConfigFilename = filename
      if data.colors or data.default_color or data.default_color_2 or data.default_color_3 then
        data.paints = convertVehicleColorsToPaints(data.colors)
        data.colors = nil
      end
      return mergeConfig(data, respawn)
    end
  end

  -- try loading the old lua file format now:
  content = readFile(filename)
  if not content then
    log('W', "partmgmt.load", "unable to open file for reading: "..filename)
    return
  end
  local data = deserialize(content)
  data.partConfigFilename = filename
  if data.colors or data.default_color or data.default_color_2 or data.default_color_3 then
    data.paints = convertVehicleColorsToPaints(data.colors)
    data.colors = nil
  end
  mergeConfig(data, respawn)
  return false
end

local function loadLocal(filename, respawn)
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end
  loadPartConfigFile(playerVehicle.vehicleDirectory .. filename, respawn)
end

local function removeLocal(filename)
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end
  FS:removeFile(playerVehicle.vehicleDirectory .. filename .. ".pc")
  FS:removeFile(playerVehicle.vehicleDirectory .. filename .. ".jpg") -- remove generated thumbnail
  guihooks.trigger("VehicleconfigRemoved", {})
  log('I', 'partmgmt', "deleted user configuration: " .. playerVehicle.vehicleDirectory .. filename .. ".pc")
end

local function isOfficialConfig(filename)
  local isOfficial
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end
  isOfficial = isOfficialContentVPath(playerVehicle.vehicleDirectory .. filename)
  return isOfficial
end

local function isPlayerConfig(filename)
  local isPlayerConfig
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end
  isPlayerConfig = isPlayerVehConfig(playerVehicle.vehicleDirectory .. filename)
  return isPlayerConfig
end


local function getConfigList()
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end

  local files = FS:findFiles(playerVehicle.vehicleDirectory, "*.pc", -1, true, false) or {}
  local result = {}

  for _, file in pairs(files) do
    local basename = string.sub(file, string.len(playerVehicle.vehicleDirectory) + 1, -1)
    table.insert(result,
    {
      fileName = basename,
      name = string.sub(basename,0, -4),
      official = isOfficialConfig(basename),
      player = isPlayerConfig(basename)
    })
  end
  return result
end

local function openConfigFolderInExplorer()
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then
    log('E', 'partmgmt', 'no active vehicle')
    return
  end

  if not fileExistsOrNil(playerVehicle.vehicleDirectory) then  -- create dir if it doesnt exist
    FS:directoryCreate(playerVehicle.vehicleDirectory, true)
  end
   Engine.Platform.exploreFolder(playerVehicle.vehicleDirectory)
end

local function highlightParts(parts, vehID)
  if vehID == -1 then return end

  local vehObj = vehID and be:getObjectByID(vehID) or be:getPlayerVehicle(0)
  vehID = vehObj:getID()

  if not vehObj then return end
  local vehData = vehManager.getVehicleData(vehID)
  if not vehData then return end

  local alpha = vehObj:getSpawnMeshAlpha()

  vehsPartsHighlighted[vehObj:getID()] = parts

  local flexHighlights = {}
  for i = 1, #parts do
    local highlight = parts[i].highlight
    local part = parts[i].val
    if part ~= nil and string.len(part) > 0 then
      flexHighlights[part] = highlight
    end
  end

  vehObj:setMeshAlpha(0, "", false)
  if vehData.vdata.flexbodies then
    for _, flexbody in pairs(vehData.vdata.flexbodies) do
      if flexbody.partOrigin == nil and flexbody.mesh then
        vehObj:setMeshAlpha(alpha, flexbody.mesh, false) -- if part doesnt have an origin, we just set the mesh to visible
      else
        if flexHighlights[flexbody.partOrigin] and flexbody.mesh then
          vehObj:setMeshAlpha(alpha, flexbody.mesh, false)
        end
      end
    end
  end

  if vehData.vdata.props then
    for _, part in pairs(parts) do
      for _, prop in pairs(vehData.vdata.props) do
        if prop.mesh and prop.partOrigin == part.val and part.highlight == true then
          vehObj:setMeshAlpha(alpha, prop.mesh, false)
        end
      end
    end
  end
end

local function selectReset(vehID)
  if vehID == -1 then return end

  local vehObj = vehID and be:getObjectByID(vehID) or be:getPlayerVehicle(0)
  vehID = vehObj:getID()

  -- show all highlighted parts
  if vehObj then
    if vehsPartsHighlighted[vehID] then
      highlightParts(vehsPartsHighlighted[vehID], vehID)
    else
      local alpha = vehObj:getSpawnMeshAlpha()
      vehObj:setMeshAlpha(alpha, "", false)
    end
  end
end

local function selectPart(partName, selectSubParts)
  -- TODO FIXME: childParts is not working anymore, thus selectSubParts is not working as well
  local vehObj = be:getPlayerVehicle(0)
  if not vehObj then return end
  local playerVehicle = vehManager.getPlayerVehicleData()
  if not playerVehicle then return end

  local alpha = vehObj:getSpawnMeshAlpha()

  -- make everything invisible
  vehObj:setMeshAlpha(0, "", true)

  local showedParts = false

  -- now show the flexbodies and parts that origin from that slot
  if playerVehicle.vdata.flexbodies then
    local partsToShow = {}
    for _, flexbody in pairs(playerVehicle.vdata.flexbodies) do
      if flexbody.partOrigin == partName then
        partsToShow[partName] = true
        if selectSubParts and type(flexbody.childParts) == "table" then
          for _, vv in pairs(flexbody.childParts) do
            partsToShow[vv] = true
          end
        end
      end
    end
    for _, flexbody in pairs(playerVehicle.vdata.flexbodies) do
       -- if not partsToShow[flexbody.partOrigin] then vehObj:setMeshAlpha(1, "", false) end
      if partsToShow[flexbody.partOrigin] and flexbody.mesh then
        vehObj:setMeshAlpha(alpha, flexbody.mesh, false)
        showedParts = true
      end
    end
  end
  if playerVehicle.vdata.props then
    local partsToShow = {}
    for _, prop in pairs(playerVehicle.vdata.props) do
      if prop.partOrigin == partName then
        partsToShow[partName] = true
        if selectSubParts and type(prop.childParts) == "table" then
          for _, vv in pairs(prop.childParts) do
            partsToShow[vv] = true
          end
        end
      end
    end
    for _, prop in pairs(playerVehicle.vdata.props) do
      if partsToShow[prop.partOrigin] and prop.mesh then
        vehObj:setMeshAlpha(alpha, prop.mesh, false)
        showedParts = true
      end
    end
  end

  if not showedParts then
    selectReset()
  end
end

local function onDeserialized()
end

local function resetConfig()
  mergeConfig({parts = {}, vars = {}}, true)
end

local function getDefaultConfigFileFromDir(vehicleDir, configDataIn)
  local vehicleInfo = jsonReadFile(vehicleDir .. '/info.json')
  if not vehicleInfo then
    return ""
  elseif not vehicleInfo.default_pc then
    return ""
  end

  log('W', 'main', "Supplied config file: " .. tostring(configDataIn) .. " not found. Using default config instead.")
  return vehicleDir .. vehicleInfo.default_pc .. ".pc"
end

local function buildConfigFromString(vehicleDir, configDataIn)
  local res = {}
  local dataType = type(configDataIn)
  if dataType == 'string' and configDataIn:sub(1, 1) == '{' then
    local fileData = deserialize(configDataIn)
    tableMerge(res, fileData)
  elseif dataType == 'table' then
    return configDataIn
  else
    local fileData = configDataIn ~= nil and configDataIn ~= '' and jsonReadFile(configDataIn)

    -- Default to default config if config not found
    if not fileData then
      configDataIn = getDefaultConfigFileFromDir(vehicleDir, configDataIn)
      if configDataIn ~= "" then
        fileData = jsonReadFile(configDataIn)
      end
    end

    res.partConfigFilename = configDataIn
    if fileData and fileData.format == 2 then
      fileData.format = nil
      tableMerge(res, fileData)
    else
      res.parts = fileData or {}
    end
  end

  return res
end

-- public interface
M.save = savePartConfigFile
M.savePartConfigFileStage2 = savePartConfigFileStage2
M.load = loadPartConfigFile

M.highlightParts = highlightParts
M.selectPart = selectPart
M.selectReset = selectReset
M.setConfig = mergeConfig
M.setConfigPaints = setConfigPaints
M.setConfigVars = setConfigVars
M.setPartsConfig = setPartsConfig
M.getConfig = getConfig
M.onDeserialized = onDeserialized
M.resetConfig = resetConfig
M.reset = reset
M.sendDataToUI = sendDataToUI
M.vehicleResetted = reset
M.getConfigSource = getConfigSource
M.getConfigList = getConfigList
M.openConfigFolderInExplorer = openConfigFolderInExplorer
M.loadLocal = loadLocal
M.removeLocal = removeLocal
M.saveLocal = saveLocal
M.saveLocalScreenshot = saveLocalScreenshot
M.saveLocalScreenshot_stage2 = saveLocalScreenshot_stage2
M.savedefault = savedefault
M.setDynamicTextureMaterials = setDynamicTextureMaterials

M.buildConfigFromString = buildConfigFromString
M.onPlayerChangeMeshVis = onPlayerChangeMeshVis
return M
