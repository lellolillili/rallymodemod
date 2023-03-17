-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local jbeamIO = require('jbeam/io')

local vehicles = {}

local materialsCache = {}

local function loadVehicleMaterialsDirectory(path)
  if materialsCache[path] then return end
  local files = FS:findFiles(path, '*materials.json\t*.cs', -1, true, false)
  for _, filename in ipairs(files) do
    if filename:find('.json') then
      loadJsonMaterialsFile(filename)
    else
      TorqueScriptLua.exec(filename)
    end
  end
  materialsCache[path] = true
end

local function onClientEndMission()
  -- invalidate all materials
  materialsCache = {}
end

local function onFileChanged(filename, type)
  jbeamIO.onFileChanged(filename, type)
  local path = string.match(filename, "^(/vehicles/[^/]*/)[^%.]*%.materials%.json$")
  if path then
    log('D', 'vehicleLoader', 'Materials changed in vehicle path, invalidating cache: ' .. tostring(path))
    materialsCache[path] = nil
  end
end

local function onFileChangedEnd()
  jbeamIO.onFileChangedEnd()
end

local additionalVehicleData
local additionalDataId
local function queueAdditionalVehicleData(data, vehId)
  additionalVehicleData = data
  additionalDataId = vehId
end

local function spawnCCallback(objID, vehicleDir, configDataIn)
  profilerPushEvent('spawn')
  local vehicleObj = scenetree.findObject(objID)
  if not vehicleObj then
    log('E', 'loader', 'Spawning vehicle failed, missing vehicle obj: '..dumps(objID, vehicleDir, configDataIn))
    additionalVehicleData = nil
    return
  end

  loadVehicleMaterialsDirectory(vehicleDir)
  loadVehicleMaterialsDirectory('/vehicles/common/')

  -- makes the object available for every call, etc
  be:addObject(vehicleObj, false)

  local timer = hptimer()
  local jbeamLoader = require("jbeam/loader")
  log('D', 'vehicleLoader', 'partConfigData [' .. type(configDataIn) .. '] = ' .. dumps(configDataIn))
  local vehicleConfig = extensions.core_vehicle_partmgmt.buildConfigFromString(vehicleDir, configDataIn)

  extensions.hook("onSpawnCCallback", objID)

  if additionalVehicleData and additionalDataId == objID then
    vehicleConfig.additionalVehicleData = additionalVehicleData
    additionalVehicleData = nil
  end

  local luaVMType = 0 -- 0 = vehicle, 1 = object pool, 2 = none

  local vehicleBundle

  local status, err = xpcall(function () vehicleBundle = jbeamLoader.loadVehicleStage1(objID, vehicleDir, vehicleConfig) end, debug.traceback)
  vehicles[objID] = vehicleBundle

  if not vehicleBundle then
    log('E', 'loader', 'Spawning vehicle failed, missing stage 1 data: '..dumps(objID, vehicleDir, configDataIn))
    if err then log('E', 'loader', err) end
  else
    log('D', 'loader', "GE load time: " .. tostring(timer:stopAndReset() / 1000) .. ' s')

    vehicleSpawned(objID) -- callback to main function
    if vehicleObj.autoEnterVehicle ~= "false" then
      be:enterVehicle(0, vehicleObj) -- will trigger onVehicleSwitched
    end

    --jsonWriteFile('jbeam_loading_NEW_stage1.json', vehicleBundle, true)
    local spawnPhysics = true
    if vehicleObj.NoPhysics == 'true' then
      spawnPhysics = false
    end

    local dataString

    if spawnPhysics then
      profilerPushEvent('serialize')
      -- do not send everything, filter some UI things that are not required
      dataString = lpack.encode({
        vdata  = vehicleBundle.vdata,
        config = vehicleBundle.config,
      })
      profilerPopEvent() -- serialize
    end

    -- this enables the UI to react on the changed vehicle
    guihooks.trigger('VehicleChange', vehicleBundle.vdata.vehicleDirectory, spawnPhysics)
    profilerPushEvent('continueSpawnObject')
    vehicleObj:continueSpawnObject(dataString or '', spawnPhysics, luaVMType)
    profilerPopEvent() -- spawnObjectPhysics

    -- remove the additionalVehicleData, because it's only supposed to be temporary
    if vehicleBundle.config then
      vehicleBundle.config.additionalVehicleData = nil
    end
  end

  profilerPopEvent()
end

local function onVehicleSwitched(oldID, newID, player)
  if vehicles[oldID] then
    vehicles[oldID].activePlayer = nil
    local vehicle = scenetree.findObjectById(oldID)
    if not vehicle then return end

    vehicle:queueLuaCommand('input.event("clutch", 0, 0)')
  end
  if vehicles[newID] then
    vehicles[newID].activePlayer = player
  end
end

local function onDespawnObject(id, isReloading)
  if isReloading == false then
    vehicles[id] = nil
  end
end

local function getPlayerVehicleData()
  return vehicles[be:getPlayerVehicleID(0)]
end

local function getVehicleData(id)
  return vehicles[id]
end

local function liveUpdateVehicleColors(objID, _vehicleObj, index, paint)
  local vehicleObj = _vehicleObj or scenetree.findObjectById(objID)
  if not vehicleObj or not vehicles[objID] or not vehicles[objID].config or not vehicles[objID].config.paints then return end

  if paint and type(paint) == 'table' then
      local paintsData = {}
      validateVehiclePaint(paint)
      if     index == 1 then
        vehicleObj.color         = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
        paintsData[1] = paint
      elseif index == 2 then
        vehicleObj.colorPalette0 = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
        paintsData[2] = paint
      elseif index == 3 then
        vehicleObj.colorPalette1 = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
        paintsData[3] = paint
      end

      vehicleObj:setMetallicPaintData(paintsData)
  end
end

local function setVehicleColorsNames(id, paintNames, optional)
  id = id or be:getPlayerVehicleID(0)
  local vehicle = scenetree.findObjectById(id)
  if not vehicle or not paintNames then return end

  local data = core_vehicles.getModel(vehicle.jbeam)
  if optional ~= nil and vehicle.color == vehicle.colorPalette0 == vehicle.colorPalette1 then return end

  for i = 1, 3 do
    if paintNames[i] and data.model.paints[paintNames[i]] then
      liveUpdateVehicleColors(id, nil, i, data.model.paints[paintNames[i]])
    end
  end
end

-- to support Lua reloads, we serialize the data
local function onDeserialized(data)
  vehicles = {}
  for k, v in pairs(data) do
    vehicles[k] = lpack.decode(v)
  end
end

local function onSerialize()
  local data = {}
  for k, v in pairs(vehicles) do
    data[k] = lpack.encode(v)
  end
  return data
end

local function toggleModifyKey()
  --extensions.core_vehicle_inplaceEdit.toggleShowWindow()
end

local function reloadVehicle(playerId)
  if be then
    core_vehicles.reloadVehicle(playerId)
    be:reloadVehicle(playerId)
  end
end

local function reloadAllVehicles()
  if be then
    be:reloadAllVehicles()
    core_vehicles.reloadVehicle(0)
  end
end

-- callbacks
M.onVehicleSwitched  = onVehicleSwitched
M.onDespawnObject    = onDespawnObject
M.onSerialize        = onSerialize
M.onDeserialized     = onDeserialized
M.onClientEndMission = onClientEndMission
M.onFileChanged      = onFileChanged
M.onFileChangedEnd   = onFileChangedEnd

-- API
M.getPlayerVehicleData = getPlayerVehicleData
M.setVehicleColorsNames = setVehicleColorsNames
M.setVehiclePaintsNames = setVehicleColorsNames
M.liveUpdateVehicleColors = liveUpdateVehicleColors
M.getVehicleData = getVehicleData

M.toggleModifyKey = toggleModifyKey

M.queueAdditionalVehicleData = queueAdditionalVehicleData
M._spawnCCallback = spawnCCallback

M.reloadVehicle = reloadVehicle
M.reloadAllVehicles = reloadAllVehicles

return M
