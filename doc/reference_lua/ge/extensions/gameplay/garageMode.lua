-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'core_jobsystem', 'core_vehicle_manager'}
local levelName = "garage_v2"
local garageLevelPath = "/levels/garage_v2/main.level.json"
local testLevelPath = "/levels/gridmap_v2/main.level.json"
local ceilingZPos = 108.1
local pillarsEastXPos = -10
local pillarsWestXPos = 10
local ceilingObjectGroup = "hide_from_camera"
local westObjectGroup = "hide_from_camera_pillars_west"
local eastObjectGroup = "hide_from_camera_pillars_east"
local lightObjectGroups = {"lights_group_west", "lights_group_middle", "lights_group_east"}
local lightObjectState = {true, true, true}
local blockedInputActions = core_input_actionFilter.createActionTemplate({"funStuff", "bigMap", "vehicleMenues", "vehicleTeleporting", "physicsControls", "aiControls", "walkingMode", "resetPhysics"})

local zoomSpeed = 0.5
local defaultFov = 48

local vehicleToLoad
local freezeVehicleCounter

local previousFOV
local previousDefaultRotation

local startTestCoroutine
local garageMenuState

local lastOwnedVehicleId

local camPresets = {
  default = vec3(145, -5, 0),
  front = vec3(180, 0, 0),
  back = vec3(0, 0, 0),
  side = vec3(90, 0, 0),
  top = vec3(90, -90, 0), -- may produce an unwanted rotation for a few degrees depending on a starting vector
}

local active = false
local hiddenGroups = {}
local objectsAutohide = true

local function setVehicleDirty(vehicleDirty, switchedToNewVehicle)
  if not career_career.isCareerActive() then return end
  guihooks.trigger("garageVehicleDirtied", {vehicleDirty = vehicleDirty, switchedToNewVehicle = switchedToNewVehicle})
end

local function setGarageMenuState(state)
  garageMenuState = state

  -- set dirty in the "paint" menu because we cant tell if something actually changed
  if state == "paint" then
    setVehicleDirty(true)
  end
end

local function getGarageMenuState()
  return garageMenuState
end

local saveTheGame
local function onEnterVehicleFinished(vehicleId)
  if vehicleId then
    lastOwnedVehicleId = vehicleId
  end
  if saveTheGame then
    career_saveSystem.saveCurrent()
    saveTheGame = nil
  end
end

local function endGarageMode()
  if not active then return end

  setVehicleDirty(false)
  active = false
  garageMenuState = nil
  core_input_actionFilter.setGroup('garageModeBlockedActions', blockedInputActions)
  core_input_actionFilter.addAction(0, 'garageModeBlockedActions', false)
  popActionMap("GarageMode")
  if career_career.isCareerActive() then
    -- TODO should check if the right vehicle is already spawned
    saveTheGame = true
    if career_modules_inventory.getCurrentVehicle() then
      career_modules_inventory.enterVehicle(career_modules_inventory.getCurrentVehicle())
    else
      career_modules_inventory.enterVehicle(lastOwnedVehicleId)
    end
  end

  local camData = core_camera.getCameraDataById(be:getPlayerVehicleID(0))
  if camData and camData.orbit then
    camData.orbit:setMaxDistance(nil)
    camData.orbit:setDefaultRotation(previousDefaultRotation)
    camData.orbit:setFOV(previousFOV)
    camData.orbit:setSkipFovModifier(false)
    camData.orbit:init()
  end
  objectsAutohide = false
  -- TODO weird sound here
  core_gamestate.setGameState('freeroam','freeroam','freeroam')
  core_vehicleBridge.executeAction(be:getPlayerVehicle(0),'setFreeze', false)
end

local function setCameraInJob(job)
  -- This changes the default rotation. Changing it back is probably not worth it because it requires waiting for several frames until the reset is done
  commands.setGameCamera()
  core_camera.setByName(0, "orbit", false)
  job.sleep(0.00001) -- sleep for one frame so the orbit cam can update correctly
  core_camera.setDefaultRotation(be:getPlayerVehicleID(0), camPresets[job.args[1] or "default"])
  core_camera.resetCamera(0)
end

local function setCamera(preset)
  core_jobsystem.create(setCameraInJob, nil, preset)
end

local newVehSpawned = false
local function vehicleSpawnedOrGarageModeStarted(vehicleId)
  if not active then return end
  if getCurrentLevelIdentifier() == levelName then
    -- get the level info
    local levelInfo = {}
    for _, level in ipairs(core_levels.getList()) do
      if string.lower(level.levelName) == string.lower(getCurrentLevelIdentifier()) then
        levelInfo = level
      end
    end

    -- TODO we probably need to use this, to keep the vehicles roughly on the same spot when we replace a vehicle
    -- teleport the vehicle to be centered on the spawn point
    local spawnPointName = levelInfo.spawnPoints[1].objectname
    local spawnPoint = scenetree.findObject(spawnPointName)
    if spawnPoint then
      local vehicle = scenetree.findObjectById(vehicleId)
      spawn.safeTeleport(vehicle, spawnPoint:getPosition(), quat(0,0,1,0) * spawnPoint:getRotation(), nil, nil, nil, true)
    end
  end
  -- We have to call the vlua functions a few frames later, because otherwise they can get reset by another init call in vlua
  freezeVehicleCounter = 5
  newVehSpawned = true
end

local function onVehicleSpawned(vehicleId)
  if not active then return end

  -- These are hacks until we use the correct part changing functions
  setVehicleDirty((garageMenuState ~= "vehicles") and (garageMenuState ~= "myCars"), garageMenuState == "vehicles")

  if career_career.isCareerActive() then
    if career_modules_inventory.getCurrentVehicle() and ((garageMenuState == "parts") or (garageMenuState == "tuning")) then
      career_modules_inventory.applyPartConditions(career_modules_inventory.getCurrentVehicle(), vehicleId)
    elseif garageMenuState == "vehicles" then
      career_modules_inventory.enterVehicle(nil, true)
    end
  end
  vehicleSpawnedOrGarageModeStarted(vehicleId)
end

local function onSpawnCCallback(vehicleId)
  if not active then return end

  -- turn off the engine on spawn
  local additionalVehicleData = {spawnWithEngineRunning = false}
  core_vehicle_manager.queueAdditionalVehicleData(additionalVehicleData, vehicleId)
end

local function getCurrentVehicle()
  local result = nil
  if gameplay_walk and gameplay_walk.isWalking() then
    return result
  end

  -- get the current vehicle to load it in the garage
  local vehicle = be:getPlayerVehicle(0)
  local playerVehicleData = core_vehicle_manager.getPlayerVehicleData()
  if vehicle and playerVehicleData then
    local config = serialize(playerVehicleData.config) -- when using "vehicle.partConfig" here, the color of the vehicle will be wrong if you use a custom default config
    local model = vehicle.JBeam
    result = { model, {config=config} }
  end
  return result
end

local function activateGarageMode()
  core_gamestate.setGameState('garage', 'garage', 'garage')
  active = true
  objectsAutohide = true

  -- block some input actions
  core_input_actionFilter.setGroup('garageModeBlockedActions', blockedInputActions)
  core_input_actionFilter.addAction(0, 'garageModeBlockedActions', true)

  pushActionMap("GarageMode")

  if career_career.isCareerActive() then
    lastOwnedVehicleId = career_modules_inventory.getCurrentVehicle()
  end
  vehicleSpawnedOrGarageModeStarted(be:getPlayerVehicleID(0))
end

local garageInitModules = {"career_modules_inventory", "career_modules_fuel", "gameplay_garageMode"}
local garageInitCurrentStep = 1
local function callNextInitStep()
  extensions[garageInitModules[garageInitCurrentStep]].garageModeStartStep()
end

local function initStepFinished()
  garageInitCurrentStep = garageInitCurrentStep + 1
  if garageInitCurrentStep > tableSize(garageInitModules) then
    garageInitCurrentStep = 1
    return
  end
  callNextInitStep()
end

local garageModeInitActive
local function garageModeStartStep()
  garageModeInitActive = true
  career_saveSystem.saveCurrent()
end

local function onVehicleSaveFinished()
  if garageModeInitActive then
    initStepFinished()
    garageModeInitActive = nil
  end
end

local activateGarageModeOnLevelLoad
local function start(useCurrentLocation)
  if useCurrentLocation then
    if career_career.isCareerActive() then
      -- clearing the cache because of some garage specific filters
      core_vehicles.clearCache()
    end
    core_camera.setByName(0, "orbit", false)
    core_vehicleBridge.executeAction(be:getPlayerVehicle(0),'setIgnitionLevel', 0)
    activateGarageMode()
    if career_career.isCareerActive() then
      callNextInitStep()
    end
  else
    -- load the level
    core_levels.startLevel(garageLevelPath, true, nil, getCurrentVehicle())
    activateGarageModeOnLevelLoad = true
  end
end

local function stop()
  core_vehicleBridge.executeAction(be:getPlayerVehicle(0),'setIgnitionLevel', 3)
  endGarageMode()
end

local zoomDirectionLastFrame = 0
local stopZooming = 0
local function zoom(value)
  if not active then return end
  if value ~= 0 then
    local zoomVal = -zoomSpeed * value
    if zoomDirectionLastFrame ~= (value > 0) then
      stopZooming = 0
    end
    stopZooming = stopZooming + 0.05
    core_camera.cameraZoom(zoomVal * stopZooming)
    zoomDirectionLastFrame = value > 0
  end
end

local function setHiddenRec(object, hidden)
  object.hidden = hidden
  if object:isSubClassOf("SimSet") then
    for i=0, object:size() - 1 do
      setHiddenRec(object:at(i), hidden)
    end
  end
end

local function hideGroup(groupName, hidden)
  local group = scenetree.findObject(groupName)
  if group then setHiddenRec(group, hidden) end
  hiddenGroups[groupName] = hidden
end

local function objectsShouldBeHidden()
  return objectsAutohide and not editor.isEditorActive()
end

local function setObjectGroupVisibility(west)
  local groupName = west and westObjectGroup or eastObjectGroup
  local pillarsShouldBeHidden
  if west then
    pillarsShouldBeHidden = function(x) return objectsShouldBeHidden() and x > pillarsWestXPos end
  else
    pillarsShouldBeHidden = function(x) return objectsShouldBeHidden() and x < pillarsEastXPos end
  end

  if not hiddenGroups[groupName] and pillarsShouldBeHidden(getCameraPosition().x) then
    hideGroup(groupName, true)
  end

  if hiddenGroups[groupName] and not pillarsShouldBeHidden(getCameraPosition().x) then
    hideGroup(groupName, false)
  end
end

local function ceilingGroupShouldBeHidden(z)
  return objectsShouldBeHidden() and z > ceilingZPos
end

local function setCeilingGroupVisibility()
  if not hiddenGroups[ceilingObjectGroup] and ceilingGroupShouldBeHidden(getCameraPosition().z) then
    hideGroup(ceilingObjectGroup, true)
  end

  if hiddenGroups[ceilingObjectGroup] and not ceilingGroupShouldBeHidden(getCameraPosition().z) then
    hideGroup(ceilingObjectGroup, false)
  end
end

local function onUpdate(dtReal)
  if not active then return end
  if freezeVehicleCounter then
    freezeVehicleCounter = freezeVehicleCounter - 1
    if freezeVehicleCounter <= 0 then
      core_vehicleBridge.executeAction(be:getPlayerVehicle(0),'setFreeze', true)
      freezeVehicleCounter = false
    end
  end
  setObjectGroupVisibility(true)
  setObjectGroupVisibility(false)
  setCeilingGroupVisibility()

  -- stop the zoom after a set amount of time
  if stopZooming > 0 then
    stopZooming = stopZooming - dtReal
    if stopZooming <= 0 then
      core_camera.cameraZoom(0)
      stopZooming = 0
    end
  end

  -- when spawning a new vehicle, set the cameras max distance and default rotation
  if newVehSpawned and core_camera.getActiveCamName(0) == "orbit" then
    local vehCamData = core_camera.getCameraDataById(be:getPlayerVehicleID(0)).orbit
    if vehCamData then
      previousFOV = vehCamData.fov
      previousDefaultRotation = vehCamData.defaultRotation

      core_camera.setMaxDistance(be:getPlayerVehicleID(0), vehCamData.defaultDistance)
      core_camera.setDefaultRotation(be:getPlayerVehicleID(0), camPresets.default)
      core_camera.setFOV(be:getPlayerVehicleID(0), defaultFov)
      core_camera.setSkipFovModifier(be:getPlayerVehicleID(0), true)
      core_camera.resetCamera(0)
    end
    newVehSpawned = false
  end
end

local function setLighting(state)
  if state then
    lightObjectState = state
  else
    lightObjectState = {true, true, true}
  end
  for i = 1, 3 do
    hideGroup(lightObjectGroups[i], not lightObjectState[i])
  end
end

local function getLighting()
  return lightObjectState
end

local function onClientStartMission(levelPath)
  if vehicleToLoad then
    core_vehicles.replaceVehicle(unpack(vehicleToLoad))
    vehicleToLoad = nil
  end

  if active then
    -- this already gets called in activateGarageMode, but sometimes needs to be set again here, because it can get overwritten
    core_gamestate.setGameState('garage', 'garage', 'garage')
  end
end

local function onClientPreStartMission(levelPath)
  if activateGarageModeOnLevelLoad and not active then
    activateGarageMode()
    activateGarageModeOnLevelLoad = nil
  elseif active then
    endGarageMode()
  end
end

local function onSerialize()
  local data = {}
  data.active = active
  return data
end

local function onDeserialized(v)
  active = v.active
end

local function isActive()
  return active == true
end

local function setObjectsAutohide(v)
  objectsAutohide = v
end

local function isObjectsAutohide()
  return objectsAutohide
end

local function onThumbnailTriggered(active)
  if getCurrentLevelIdentifier() == levelName then
    if active then
      guihooks.trigger("GarageModeBlackscreen", {active = true})
      -- When taking a thumbnail, end the garage mode
      endGarageMode()
      hideGroup(eastObjectGroup, true)
      hideGroup(westObjectGroup, false)
      hideGroup(ceilingObjectGroup, false)
    else
      activateGarageMode()
      guihooks.trigger("GarageModeBlackscreen", {active = false})
    end
  end
end

local function startTestWorkitem(job)
  -- move the camera to the default position
  core_camera.speedFactor = 10000
  setCameraInJob(job)
  job.sleep(0.5)
  core_camera.speedFactor = 1
  commands.setFreeCamera()
  setCameraFovDeg(defaultFov)

  -- let the vehicle drive forward
  local playerVeh = be:getPlayerVehicle(0)
  core_vehicleBridge.executeAction(playerVeh, 'setFreeze', false)
  playerVeh:queueLuaCommand('ai.driveUsingPath({wpTargetList = {"garageExit"}})')
  job.sleep(2)

  -- fade to black
  ui_fadeScreen.start(1)
  job.sleep(1.5)

  -- load the test level
  freeroam_freeroam.startFreeroam(testLevelPath, nil, nil, getCurrentVehicle())
end

local function testVehicle()
  core_jobsystem.create(startTestWorkitem)
end

local function getLastOwnedVehicleId()
  return lastOwnedVehicleId
end

M.start = start
M.stop = stop
M.isActive = isActive
M.zoom = zoom
M.setCamera = setCamera
M.setObjectsAutohide = setObjectsAutohide
M.isObjectsAutohide = isObjectsAutohide
M.testVehicle = testVehicle
M.setLighting = setLighting
M.getLighting = getLighting
M.setGarageMenuState = setGarageMenuState
M.getGarageMenuState = getGarageMenuState
M.setVehicleDirty = setVehicleDirty
M.getLastOwnedVehicleId = getLastOwnedVehicleId
M.initStepFinished = initStepFinished
M.garageModeStartStep = garageModeStartStep

M.onUpdate = onUpdate
M.onVehicleSpawned = onVehicleSpawned
M.onSpawnCCallback = onSpawnCCallback
M.onClientPreStartMission = onClientPreStartMission
M.onClientStartMission = onClientStartMission
M.onDeserialized = onDeserialized
M.onSerialize = onSerialize
M.onThumbnailTriggered = onThumbnailTriggered
M.onEnterVehicleFinished = onEnterVehicleFinished
M.onVehicleSaveFinished = onVehicleSaveFinished

return M