-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local defaultSpawnPoint = "garagePoint"
local defaultVehicle = {model = "covet", config = "DXi_M"}

local vehicles = {}
local dirtiedVehicles = {}
local parts = {}
local objIdToVehicleId = {}
local vehicleIdToObjId = {}
local currentVehicle

local carConfigToLoad
local carModelToLoad
local savedTransform

local vehicleToEnterId

-- TODO we should save when entering the garage

local function onExtensionLoaded()
  if not career_career.isCareerActive() then return false end

  -- load from saveslot
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end
  local inventoryData = jsonReadFile(savePath .. "/career/inventory.json")
  if inventoryData then
    parts = inventoryData.parts
    vehicleToEnterId = inventoryData.currentVehicle

    if inventoryData.vehiclePos then
      savedTransform = {}
      savedTransform.pos = inventoryData.vehiclePos
      savedTransform.rot = inventoryData.vehicleRot
    else
      savedTransform = nil -- will force spawning at garage
    end
  end

  -- load the vehicles
  table.clear(vehicles)
  local files = FS:findFiles(savePath .. "/career/vehicles/", '*.json', 0, false, false)
  for i = 1, tableSize(files) do
    local vehicleData = jsonReadFile(files[i])
    vehicleData.partConditions = lpack.decode(vehicleData.partConditions)
    vehicles[vehicleData.id] = vehicleData
  end
end

local function saveVehiclesData(currentSavePath, oldSaveDate)
  local vehiclesCopy = deepcopy(vehicles)
  local currentDate = os.date("!%Y-%m-%dT%XZ")
  for id, vehicle in pairs(vehiclesCopy) do
    if dirtiedVehicles[id] or not vehicle.dirtyDate then
      vehicles[id].dirtyDate = currentDate
      vehicle.dirtyDate = currentDate
      dirtiedVehicles[id] = nil
    end
    if (vehicle.dirtyDate > oldSaveDate) then
      vehicle.partConditions = lpack.encode(vehicle.partConditions)
      jsonWriteFile(currentSavePath .. "/career/vehicles/" .. id .. ".json", vehicle, true)
    end
  end

  if currentVehicle then
    dirtiedVehicles[currentVehicle] = true
  end

  -- Remove vehicle files for vehicles that have been deleted
  local files = FS:findFiles(currentSavePath .. "/career/vehicles/", '*.json', 0, false, false)
  for i = 1, tableSize(files) do
    local dir, filename, ext = path.split(files[i])
    local fileNameNoExt = string.sub(filename, 1, -6)
    local vehicleId = tonumber(fileNameNoExt)
    if not vehicles[vehicleId] then
      FS:removeFile(dir .. filename)
    end
  end
end

local function saveVehiclesCallback(currentVehiclePartConditions, currentSavePath, oldSaveDate)
  vehicles[currentVehicle].partConditions = currentVehiclePartConditions
  saveVehiclesData(currentSavePath, oldSaveDate)
  extensions.hook("onVehicleSaveFinished")
  guihooks.trigger("saveFinished")
end

local function onSaveCurrentSaveSlot(currentSavePath, oldSaveDate, forceSyncSave)
  local data = {}
  data.parts = parts
  data.currentVehicle = currentVehicle
  local veh = be:getPlayerVehicle(0)

  if veh and currentVehicle then
    if career_modules_playerDriving.getPlayerData().parking.event == "valid" then -- save position if vehicle is correctly parked in a parking spot
      data.vehiclePos = veh:getPosition()
      data.vehicleRot = quat(0,0,1,0) * quat(veh:getRefNodeRotation())
    end
    if not forceSyncSave then
      queueCallbackInVehicle(veh, "career_modules_inventory.saveVehiclesCallback", "partCondition.getConditions()", currentSavePath, oldSaveDate)
    else
      saveVehiclesData(currentSavePath, oldSaveDate)
    end
  else
    saveVehiclesData(currentSavePath, oldSaveDate)
  end
  jsonWriteFile(currentSavePath .. "/career/inventory.json", data, true)

  if not (veh and currentVehicle) then
    extensions.hook("onVehicleSaveFinished")
    guihooks.trigger("saveFinished")
  end
end

local function addVehicle(objId, vehId)
  local vehicle = scenetree.findObjectById(objId)
  local vehicleData = core_vehicle_manager.getVehicleData(objId)
  if vehicle and vehicleData then
    local carConfigToLoad = vehicleData.config
    local carModelToLoad = vehicle.JBeam

    if not vehId then
      vehId = 1
      while vehicles[vehId] do
        vehId = vehId + 1
      end
    end
    local niceName
    if vehicleData.vdata and vehicleData.vdata.information then
      niceName = vehicleData.vdata.information.name
    end

    vehicles[vehId] = vehicles[vehId] or {}
    vehicles[vehId].model = carModelToLoad
    vehicles[vehId].config = carConfigToLoad
    vehicles[vehId].id = vehId
    vehicles[vehId].niceName = niceName
    return vehId
  end
end

local function removeVehicle(vehId)
  vehicles[vehId] = nil
  if currentVehicle == vehId then
    currentVehicle = nil
  end

   -- remove the actual game engine object
  local objId = vehicleIdToObjId[vehId]
  if objId then
    local obj = scenetree.findObjectById(objId)
    if obj then
      obj:deleteObject()
    end
    objIdToVehicleId[objId] = nil
    vehicleIdToObjId[vehId] = nil
  end
end

local function updatePartConditions(vehId)
  queueCallbackInVehicle(be:getPlayerVehicle(0), "career_modules_inventory.getPartConditionsCallback", "partCondition.getConditions()", vehId)
end

local function applyPartConditions(vehId, objId)
  local veh = scenetree.findObjectById(objId)
  veh:queueLuaCommand("partCondition.initConditions(" .. serialize(vehicles[vehId].partConditions) .. ")")
end

local function enterVehicleActual(id, dontLoadVehicle)
  if dontLoadVehicle or not id then
    currentVehicle = id
  else
    local carConfigToLoad = vehicles[id].config
    local carModelToLoad = vehicles[id].model
    if carConfigToLoad then

      -- if the vehicle doesnt exist (deleted mod) then spawn the default vehicle
      if tableIsEmpty(core_vehicles.getModel(carModelToLoad)) then
        carConfigToLoad = {config = defaultVehicle.config}
        carModelToLoad = defaultVehicle.model
      end

      local vehicleData = {}
      vehicleData.config = carConfigToLoad
      core_vehicles.replaceVehicle(carModelToLoad, vehicleData)
      currentVehicle = id
      objIdToVehicleId[be:getPlayerVehicleID(0)] = id
      vehicleIdToObjId[id] = be:getPlayerVehicleID(0)

      if vehicles[id].partConditions then
        be:getPlayerVehicle(0):queueLuaCommand("partCondition.initConditions(" .. serialize(vehicles[id].partConditions) .. ")")
      else
        be:getPlayerVehicle(0):queueLuaCommand(string.format("partCondition.initConditions() obj:queueGameEngineLua('career_modules_inventory.updatePartConditions(%d)')", id))
      end
    end
  end
  if currentVehicle then
    dirtiedVehicles[currentVehicle] = true
  end
  extensions.hook("onEnterVehicleFinished", currentVehicle)
end

local function getPartConditionsCallback(partConditions, vehicleId)
  vehicles[vehicleId].partConditions = partConditions
end

local function enterVehicleCallback(partConditions, oldVehicleId, newVehicleId)
  vehicles[oldVehicleId].partConditions = partConditions
  enterVehicleActual(newVehicleId)
end

local function enterVehicle(newVehicleId, dontLoadVehicle)
  if dontLoadVehicle then
    enterVehicleActual(newVehicleId, dontLoadVehicle)
    return
  end
  if currentVehicle then
    queueCallbackInVehicle(be:getPlayerVehicle(0), "career_modules_inventory.enterVehicleCallback", "partCondition.getConditions()", currentVehicle, newVehicleId)
  else
    enterVehicleActual(newVehicleId)
  end
end

local saveCareer
local function onCareerActivatedWhileLevelLoaded()
  if not vehicleToEnterId then
    -- spawn a default vehicle
    core_vehicles.replaceVehicle(defaultVehicle.model, {config = defaultVehicle.config})
    local vehId = be:getPlayerVehicleID(0)
    if vehId then
      vehicleToEnterId = addVehicle(vehId)
      saveCareer = true
    end
  end
  enterVehicle(vehicleToEnterId)
  if be:getPlayerVehicle(0) then
    if savedTransform then
      spawn.safeTeleport(be:getPlayerVehicle(0), savedTransform.pos, savedTransform.rot)
    else
      local parkingSpot = freeroam_facilities.getBestParkingSpot()
      if parkingSpot then
        parkingSpot:moveResetVehicleTo(be:getPlayerVehicleID(0), true) -- uses low precision mode
      end
    end
    career_modules_playerDriving.validatePlayer()
    savedTransform = nil
  end

  commands.setGameCamera()
end

local function onClientStartMission(levelPath)
  onCareerActivatedWhileLevelLoaded()
end

local function onExtensionUnloaded()
end

local function onBigMapActivated()
  if currentVehicle then
    core_vehicleBridge.executeAction(be:getPlayerVehicle(0), 'createPartConditionSnapshot', "beforeTeleport")
    core_vehicleBridge.executeAction(be:getPlayerVehicle(0), 'setPartConditionResetSnapshotKey', "beforeTeleport")
  end
end

local function teleportedFromBigmap()
  if currentVehicle then
    career_saveSystem.saveCurrent()
  end
end

local function onApplyTuning(vehicleId)
  local partConditions = vehicles[currentVehicle].partConditions
  addVehicle(be:getPlayerVehicleID(0), currentVehicle)
  vehicles[currentVehicle].partConditions = partConditions
  enterVehicle(currentVehicle)
end

local function getCurrentVehicle()
  return currentVehicle
end

local function getObjectIdFromVehicleId(vehId)
  if vehId then
    return vehicleIdToObjId[vehId]
  end
end

local function getCurrentVehicleObjectId()
  return getObjectIdFromVehicleId(currentVehicle)
end

local function onUpdate()
  if saveCareer then
    career_saveSystem.saveCurrent() -- this is the save just after starting a new career
    saveCareer = nil
  end
end

local function onBeforeWalkingModeToggled(enabled, vehicleToEnterObjId)
  if enabled then
    enterVehicle(nil)
  elseif objIdToVehicleId[vehicleToEnterObjId] then
    enterVehicleActual(objIdToVehicleId[vehicleToEnterObjId], true)
  end
end

local function sendCareerVehiclesToUI()
  guihooks.trigger("allCareerSaveSlots", res)
end

local garageModeInitActive
local function garageModeStartStep()
  -- When entering the garage with no vehicle, for example in walking mode, delete all player vehicles and then enter one of them
  if not currentVehicle then
    garageModeInitActive = true
    local vehicleIdToEnter
    for objId, vehId in pairs(objIdToVehicleId) do
      vehicleIdToEnter = vehicleIdToEnter or vehId
      local obj = be:getObjectByID(objId)
      if obj then
        obj:delete()
      end
    end
    table.clear(objIdToVehicleId)
    table.clear(vehicleIdToObjId)
    if not vehicleIdToEnter then
      local vehId, _ = next(vehicles)
      vehicleIdToEnter = vehId
    end
    enterVehicle(vehicleIdToEnter)
  else
    gameplay_garageMode.initStepFinished()
  end
end

local function onEnterVehicleFinished()
  if garageModeInitActive then
    gameplay_garageMode.initStepFinished()
    garageModeInitActive = nil
  end
end

M.addVehicle = addVehicle
M.removeVehicle = removeVehicle
M.enterVehicle = enterVehicle
M.updatePartConditions = updatePartConditions
M.onCareerActivatedWhileLevelLoaded = onCareerActivatedWhileLevelLoaded

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onClientStartMission = onClientStartMission
M.onBigMapActivated = onBigMapActivated
M.onUpdate = onUpdate
M.onBeforeWalkingModeToggled = onBeforeWalkingModeToggled
M.garageModeStartStep = garageModeStartStep

M.enterVehicleCallback = enterVehicleCallback
M.saveVehiclesCallback = saveVehiclesCallback
M.getPartConditionsCallback = getPartConditionsCallback
M.onApplyTuning = onApplyTuning
M.applyTuningCallback = applyTuningCallback
M.applyPartConditions = applyPartConditions
M.teleportedFromBigmap = teleportedFromBigmap

-- Debug
M.getCurrentVehicle = getCurrentVehicle
M.getCurrentVehicleObjectId = getCurrentVehicleObjectId
M.getObjectIdFromVehicleId = getObjectIdFromVehicleId
M.vehicles = vehicles

return M
