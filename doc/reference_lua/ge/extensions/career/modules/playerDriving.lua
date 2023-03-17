-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local playerData = {traffic = {}, parking = {}, savedPos = vec3(), ready = false} -- traffic data, parking data, etc.
local defaultPoliceCar = {model = "fullsize", config = "bcpd"} -- TEMP

local function getPlayerData()
  return playerData
end

local function validatePlayer()
  playerData.savedPos:set(be:getPlayerVehicle(0):getPosition())
  playerData.ready = true
  log("I", "career", "Player data ready")
end

local function setupTraffic()
  if gameplay_traffic.getState() == "off" then
    log("I", "career", "Now spawning traffic for career mode")
    if not gameplay_traffic.getTrafficList()[1] then
      gameplay_traffic.queueTeleport = true -- forces traffic vehicles to teleport away
      gameplay_traffic.setupTraffic(6, 0, 0, 5, {simpleVehs = true})
    end
  end
  gameplay_parking.enableTracking()
  gameplay_parking.precision = 0.2 -- allows for easy parking
end

local function onSaveCurrentSaveSlot(currentSavePath)
end

local function onVehicleParkingStatus(vehId, data)
  -- player vehicle should not be able to retrigger rapid career saving in the same parking spot
  if not gameplay_missions_missionManager.getForegroundMissionId() and playerData.ready and vehId == be:getPlayerVehicleID(0) and data.event == "valid"
  and playerData.savedPos:squaredDistance(be:getPlayerVehicle(0):getPosition()) > 4 then
    playerData.savedPos:set(be:getPlayerVehicle(0):getPosition())
    career_saveSystem.saveCurrent()
    log("I", "career", "Player saved progress in parking spot")
  end
end

local function onTrafficStarted()
  playerData.traffic = gameplay_traffic.getTrafficData()[be:getPlayerVehicleID(0)]
  playerData.parking = gameplay_parking.getTrackingData()[be:getPlayerVehicleID(0)]

  if not gameplay_missions_missionManager.getForegroundMissionId() then
    -- hide police vehicles for a while
    for id, v in pairs(gameplay_traffic.getTrafficData()) do
      if v.isAi and v.role.name == "police" then
        be:getObjectByID(id):setActive(0)
        v.enableRespawn = false -- and then at some place or condition, enable police vehicles to be visible again
      end
    end
  end
end

local function onTrafficStopped()
  --table.clear(playerData.traffic)
end

local function onPlayerCameraReady()
  setupTraffic() -- spawns traffic while the loading screen did not fade out yet
end

local function onVehicleSwitched(oldId, id)
  if not gameplay_missions_missionManager.getForegroundMissionId() then
    gameplay_parking.disableTracking(oldId)
    gameplay_parking.enableTracking(id)
    playerData.traffic = gameplay_traffic.getTrafficData()[be:getPlayerVehicleID(0)]
    playerData.parking = gameplay_parking.getTrackingData()[be:getPlayerVehicleID(0)]
  end
end

local function onCareerActivatedWhileLevelLoaded()
  setupTraffic()
end

local function onExtensionLoaded()
end

local function onClientStartMission()
  onCareerActivatedWhileLevelLoaded()
end

local teleportDestination
local function startResetTeleport(destination)
  ui_fadeScreen.start(1)
  teleportDestination = destination
end

local function towVehicle(destination)
  core_vehicleBridge.executeAction(be:getPlayerVehicle(0), 'createPartConditionSnapshot', "beforeTeleport")
  core_vehicleBridge.executeAction(be:getPlayerVehicle(0), 'setPartConditionResetSnapshotKey', "beforeTeleport")
  core_vehicleBridge.requestValue(be:getPlayerVehicle(0), function() startResetTeleport(destination) end, 'ping')
end

local function onScreenFadeState(state)
  if teleportDestination == "garage" then
    freeroam_bigMapMode.teleportToGarage()
    ui_fadeScreen.stop(0.5)
    ui_message("ui.career.towed", 5, "career")
    teleportDestination = nil
    freeroam_bigMapMode.navigateToMission(nil)
  elseif teleportDestination == "road" then
    local veh = be:getPlayerVehicle(0)
    spawn.teleportToLastRoad(veh)
    teleportDestination = nil
    ui_fadeScreen.stop(0.5)
  end
end

local function onResetGameplay(playerID)
  if not gameplay_missions_missionManager.getForegroundMissionId() then
    local data = {text = "ui.career.towPrompt", buttons = {
      { label = "ui.career.towToRoad", luaCallback = "career_modules_playerDriving.towVehicle('road')", default = true },
      { label = "ui.career.towToGarage", luaCallback = "career_modules_playerDriving.towVehicle('garage')"},
      { label = "Cancel",  isCancel = true }
    }}

    guihooks.trigger('showConfirmationDialog', data)
  end
end

M.getPlayerData = getPlayerData
M.validatePlayer = validatePlayer
M.towVehicle = towVehicle

M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onPlayerCameraReady = onPlayerCameraReady
M.onTrafficStarted = onTrafficStarted
M.onTrafficStopped = onTrafficStopped
M.onVehicleParkingStatus = onVehicleParkingStatus
M.onVehicleSwitched = onVehicleSwitched
M.onCareerActivatedWhileLevelLoaded = onCareerActivatedWhileLevelLoaded
M.onClientStartMission = onClientStartMission
M.onExtensionLoaded = onExtensionLoaded
M.onResetGameplay = onResetGameplay
M.onScreenFadeState = onScreenFadeState

return M