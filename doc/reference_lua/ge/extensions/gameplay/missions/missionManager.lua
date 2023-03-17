-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local missions = {}

local logTag = "missionManager"

------------- helper functions ----------------
local foregroundMissionId -- holds the one non-background-mission that is allowed to run at the same time

local taskData = {
  steps = {},
  data = {},
  active = false,
  currentStep = 0
}


local function taskStartFadeStep(step, task)
  if not step.waitForFade then
    ui_fadeScreen.start(M.fadeDuration)
    step.waitForFade = true
  end
  if step.fadeState1 then
    step.complete = true
  end
end
local function taskStartPreMissionHandling(step, task)
  if career_career and career_career.isCareerActive() then
    if not step.sentToCareer then
      career_modules_missionWrapper.preMissionHandling(step, task)
      step.sentToCareer = true
    end
    if step.handlingComplete then
      step.complete = true
    end
  else
    step.complete = true
  end
end
local function taskStartPartsConditionStep(step, task)
  step.complete = true
end
local function taskStartTrafficStep(step, task)
  local trafficSetup = taskData.data.mission.setupModules.traffic
  local userSettings = taskData.data.userSettings or {}

  if userSettings.spawnTraffic and trafficSetup.usePrevTraffic and gameplay_traffic.getState() == 'on' then -- use existing traffic
    step.activated = true
    gameplay_traffic.forceTeleportAll()
  end

  if not step.waitForTraffic then
    if not trafficSetup._prevTraffic and not trafficSetup.usePrevTraffic and gameplay_traffic.getState() == 'on' then
      trafficSetup._prevTraffic, trafficSetup._prevParkedCars = gameplay_traffic.freezeState() -- stash previous traffic
      log("I", logTag, "Now stashing all traffic vehicles")
    end

    if trafficSetup.enabled and userSettings.spawnTraffic and not step.activated then -- spawn new traffic
      local options = {ignoreDelete = true, ignoreAutoAmount = true}
      if not trafficSetup.useGameOptions then
        options.allMods = false
        options.allConfigs = true
        options.simpleVehs = trafficSetup.useSimpleVehs
      end

      gameplay_traffic.queueTeleport = true -- forces vehicles to teleport after spawning
      local valid = gameplay_traffic.setupTraffic(trafficSetup.amount, 0, 0, trafficSetup.parkedAmount, options)
      if not valid then -- traffic failed, just continue
        step.complete = true
        gameplay_traffic.queueTeleport = false
      end
    else
      step.complete = true
    end
    step.waitForTraffic = true
  end
  if step.activated then -- runs after the traffic step spawned traffic, or if previous traffic is used
    gameplay_traffic.setTrafficVars({activeAmount = trafficSetup.activeAmount, spawnValue = trafficSetup.respawnRate, enableRandomEvents = false})
    step.complete = true
  end
end
local function taskStartMissionStep(step, task)
  if step.handled then return end
  step.handled = true
  local mission = taskData.data.mission
  local userSettings = taskData.data.userSettings
  -- save the players car, position etc from where they started the mission.
  local startingInfo = {}
  local veh = be:getPlayerVehicle(0)
  if veh then
    startingInfo.vehPos = veh:getPosition()
    startingInfo.vehRot = quatFromDir(vec3(veh:getDirectionVector()), vec3(veh:getDirectionVectorUp()))
    startingInfo.vehId = veh:getID()
    startingInfo.startedFromVehicle = true
  else
    startingInfo.camPos = getCameraPosition()
    startingInfo.camRot = getCameraQuat()
    startingInfo.startedFromCamera = true
  end
  mission._startingInfo = startingInfo
  mission.restoreStartingInfoSetup = nil

  if not userSettings then
    local settings = mission:getUserSettingsData() or {}
    userSettings = {}
    for _, elem in ipairs(settings) do
      userSettings[elem.key] = elem.value
    end
  end
  if mission:processUserSettings(userSettings or {}) then
    log("E", logTag, "Couldn't start mission, 'processUserSettings' didn't return nil/false: "..dumps(mission.id))
    --return
  end
  --[[
    -- load associated prefabs
    if mission.prefabs then
      mission._spawnedPrefabs = {}
      mission._vehicleTransforms = {}
      for i, p in ipairs(mission.prefabs) do
        local obj = spawnPrefab(mission.id.."_prefab_" .. i , p, "0 0 0", "0 0 0 1", "1 1 1")
        if obj == nil then
          log("E", "", "Couldn't start mission "..dumps(mission.id)..", could not load prefab: "..dumps(p))
          unloadMissionPrefabs(mission)
          return true
        else
          log("D", "", "Loaded prefab for mission"..dumps(mission.id) .. " - " .. dumps(p))
          table.insert(mission._spawnedPrefabs, obj)
          for i = 0, obj:size() - 1 do
            local sObj = obj:at(i)
            local name = sObj:getClassName()
            if sObj then
              if name == 'BeamNGVehicle' then
                sObj = Sim.upcast(sObj)
                mission._vehicleTransforms[sObj:getId()] = {
                  pos = vec3(sObj:getPosition()),
                  rot = quat(sObj:getRotation())
                }
              end
            end
          end
        end
      end
    end
  ]]

  bullettime.pause(false)
  bullettime.setInstant(1)
  be:resetTireMarks()

  -- setupModules
  if mission.setupModules.timeOfDay.enabled then
    mission.setupModules.timeOfDay._processed = true
    mission.setupModules.timeOfDay._originalTimeOfDay = deepcopy(core_environment.getTimeOfDay())
    local tod = deepcopy(core_environment.getTimeOfDay())
    tod.time = mission.setupModules.timeOfDay.time
    core_environment.setTimeOfDay(tod)
  end

  if mission.setupModules.traffic.enabled then
    mission.setupModules.traffic._processed = true
  end

  mission._isOngoing = true -- in case onStart guys ask about our own state - yes, we're kinda ongoing now...
  if mission:onStart() then
    mission._isOngoing = false -- ...but we'll stop in case of problems
    log("E", logTag, "Couldn't start mission, 'onStart' didn't return nil/false: "..dumps(mission.id))
    --unloadMissionPrefabs(mission)
    --return true
  end
  --if mission._spawnedPrefabs and mission.prefabsRequireCollisionReload then
  --  be:reloadCollision()
  --end

  -- set exclusivity
  if not mission.background then
    foregroundMissionId = mission.id
  end

  extensions.hook("onAnyMissionChanged", "started", mission)
  step.complete = true
end

local function taskStopMissionStep(step, task)
  local mission = taskData.data.mission
  if step.handled then
    if mission.mgr.runningState == 'stopped' then
      step.complete = true
      extensions.hook("onAnyMissionChanged", "stopped", mission)
    end
    return
  end
  step.handled = true

  local data = taskData.data.data
  data = data or {}
  mission:onStop(data)
  mission._isOngoing = false
  --unloadMissionPrefabs(mission.mission)
  if foregroundMissionId == mission.id then
    foregroundMissionId = nil
  end

  bullettime.pause(false)
  bullettime.setInstant(1)
  be:resetTireMarks()

  -- setupModules
  if mission.setupModules.timeOfDay._processed then
    core_environment.setTimeOfDay(mission.setupModules.timeOfDay._originalTimeOfDay)
    mission.setupModules.timeOfDay._originalTimeOfDay = nil
    mission.setupModules.timeOfDay._processed = nil
  end

  gameplay_traffic.deleteVehicles()
  if mission.setupModules.traffic._prevTraffic then
    gameplay_traffic.unfreezeState(mission.setupModules.traffic._prevTraffic, mission.setupModules.traffic._prevParkedCars)
    log("I", logTag, "Now restoring previous traffic vehicles")
  end
  mission.setupModules.traffic._prevTraffic = nil
  mission.setupModules.traffic._prevParkedCars = nil
  mission.setupModules.traffic._processed = nil
end
local function taskStopFadeStep(step, task)
  if not step.waitForFade then
    ui_fadeScreen.stop(M.fadeDuration)
    step.waitForFade = true
  end
  if step.fadeState3 then
    step.complete = true
  end
end

local function trafficActivated()
  if not taskData.active or not taskData.steps[taskData.currentStep] or not taskData.steps[taskData.currentStep].waitForTraffic then
    return
  end
  taskData.steps[taskData.currentStep].activated = true
end

M.onTrafficStarted = trafficActivated
M.onParkingVehiclesActivated = trafficActivated -- triggers if parked cars spawn but no traffic spawns

M.fadeDuration = 0.75
M.onScreenFadeState = function(state)
  if not taskData.active or not taskData.steps[taskData.currentStep] or not taskData.steps[taskData.currentStep].waitForFade then
    return
  end
  taskData.steps[taskData.currentStep]["fadeState"..state] = true
end

local function startWithFade(mission, userSettings)
  if not mission then
    log("E", logTag, "Couldn't start mission, mission id not found: "..dumps(mission.id))
    return true
  end
  if mission._isOngoing then
    log("E", logTag, "Couldn't start mission, it's already ongoing: "..dumps(mission.id))
    return true
  end
  if taskData.active then
    log("W", logTag, "Attempting to start an mission while another there is an active task.")
    return
  end

  taskData.data = {mission = mission, userSettings = userSettings}
  taskData.steps = {
    {
      name = "taskStartFadeStep",
      processTask = taskStartFadeStep
    }, {
      name = "taskStartPartsConditionStep",
      processTask = taskStartPartsConditionStep
    }, {
      name = "taskStartPreMissionHandling",
      processTask = taskStartPreMissionHandling
    }, {
      name = "taskStartTrafficStep",
      processTask = taskStartTrafficStep
    }, {
      name = "taskStartMissionStep",
      processTask = taskStartMissionStep
    }
  }
  taskData.active = true
  taskData.currentStep = 1
  log("I", logTag, "Starting Mission with Fade.")
end

local function startAsScenario(mission, userSettings)
  if not mission then
    log("E", logTag, "Couldn't start mission, mission id not found: "..dumps(mission.id))
    return true
  end
  if mission._isOngoing then
    log("E", logTag, "Couldn't start mission, it's already ongoing: "..dumps(mission.id))
    return true
  end
  if taskData.active then
    log("W", logTag, "Attempting to start an mission while another there is an active task.")
    return
  end

  taskData.data = {mission = mission, userSettings = userSettings}
  taskData.steps = {
    {
      name = "taskStartTrafficStep",
      processTask = taskStartTrafficStep,
    }, {
      name = "taskStartMissionStep",
      processTask = taskStartMissionStep,
    }
  }
  taskData.active = true
  taskData.currentStep = 1
  log("I", logTag, "Starting Mission startAsScenario.")
end



local function startFromWithinMission(mission, userSettings)
  if not foregroundMissionId then return end
  delayedStartFromWithinMission = {
    current = gameplay_missions_missions.getMissionById(foregroundMissionId),
    mission = mission,
    userSettings = userSettings
  }
  ui_fadeScreen.start(M.fadeDuration)
  log("I", logTag, "Delaying start of mission from within another mission for fade.")
end
M.startFromWithinMission = startFromWithinMission



local function attemptAbandonMissionWithFade(mission)
  if not mission then
    log("E", logTag, "Couldn't stop mission, mission id not found: "..dumps(mission.id))
    return true
  end
  if not mission._isOngoing then
    log("E", logTag, "Couldn't stop mission, it's not ongoing: "..dumps(mission.id))
    return true
  end
  if taskData.active then
    log("W", logTag, "Attempting to stop an mission while another there is an active task.")
    return
  end
  mission.restoreStartingInfoSetup = true

  -- this mission handles stopping themselves..
  if mission:attemptAbandonMission() then
    log("I", logTag, "Requesting faded abandon for mission, not force stopping. : "..dumps(mission.id))
    return true
  end

  taskData.data = {mission = mission, data = {}}
  taskData.active = true
  taskData.steps = {
    {
      name = "taskStartFadeStep",
      processTask = taskStartFadeStep,
    }, {
      name = "taskStopMissionStep",
      processTask = taskStopMissionStep,
    }, {
      name = "taskStopFadeStep",
      processTask = taskStopFadeStep,
    }
  }
  taskData.currentStep = 1

  -- stop, if attempt was not successfull.

  ui_fadeScreen.start(M.fadeDuration)
  log("I", logTag, "Delaying abandonment of mission for fade.")
end


local function stop(mission, data)
  if not mission then
    log("E", logTag, "Couldn't stop mission, mission id not found: "..dumps(mission.id))
    return true
  end
  if not mission._isOngoing then
    log("E", logTag, "Couldn't stop mission, it's not ongoing: "..dumps(mission.id))
    return true
  end
  if taskData.active then
    log("W", logTag, "Attempting to stop an mission while another there is an active task.")
    return
  end
  taskData.data = {mission = mission, data = data}
  taskData.active = true
  taskData.steps = {
    {
      name = "taskStopMissionStep",
      processTask = taskStopMissionStep,
    }
  }
  taskData.currentStep = 1
  if not data.ignoreFade then
    table.insert(taskData.steps,{
      name = "taskStopFadeStep",
      processTask = taskStopFadeStep,
    })
  end
end

-- WIP for allowing or disallowing missions
M.allowMissionInteraction = function()
  if core_gamestate.state and core_gamestate.state.state ~= "freeroam" then
    return false
  end
  return true
end

local showDebugWindow = false
local debugApprove = false
local function onUpdate(dtReal, dtSim, dtRaw)
  if showDebugWindow then
    local im = ui_imgui
    im.Begin("Mission Manager Debug")
    im.Text("Steps")
    if not taskData.active then im.BeginDisabled() end
    for i, step in ipairs(taskData.steps) do
      im.TextWrapped(string.format("%s%d - %s",taskData.currentStep == i and "ACTIVE " or "", i, step.name or "Unnamed Step"))
      im.Text(dumps(step))
      if debugApprove and i==taskData.currentStep and step.complete then
        if im.Button("Approve##"..i) then
          step.approved = true
        end
      end
      im.Separator()
    end
    im.TextWrapped(dumpsz(taskData.data, 3))
    if not taskData.active  then im.EndDisabled() end
    im.End()
  end


  if taskData.active then
    local stepToHandle = taskData.steps[taskData.currentStep]
    while stepToHandle do
      stepToHandle.processTask(stepToHandle, taskData)
      if stepToHandle.complete then
        log("I", logTag, string.format("Completed Step: %s", stepToHandle.name or "Unnamed Task"))
        taskData.currentStep = taskData.currentStep + 1
        stepToHandle = taskData.steps[taskData.currentStep]
        if not stepToHandle then
          taskData.active = false
        end
      else
        stepToHandle = nil
      end
    end
  end

  if not M.allowMissionInteraction() then return end

  -- run all ongoing activities
  for _, mission in ipairs(gameplay_missions_missions.get()) do
    if mission._isOngoing then
      mission:onUpdate(dtReal, dtSim, dtRaw)
    end
  end
  --[[
  if delayedStartFromWithinMission then
    if delayedStartFromWithinMission.delay > 0 then
      delayedStartFromWithinMission.delay = delayedStartFromWithinMission.delay -1
      if delayedStartFromWithinMission.delay == 0 then
        local failure = M.start(delayedStartFromWithinMission.mission, delayedStartFromWithinMission.userSettings)
        if failure then
          ui_fadeScreen.stop(0)
        end
        delayedStartFromWithinMission = nil
      end
    end
  end]]
end


-- when we change level, immediately stop mission, but don't clean up.
local function onClientEndMission()
  if M.getForegroundMissionId() then
    --M.stop(,{instant = true, ignoreFade = true, ignoreTrafficRespawn = true})
    taskStopMissionStep({},{mission = gameplay_missions_missions.getMissionById(M.getForegroundMissionId()), data = {instant = true}})
  end
end

-- external callbacks
M.onUpdate = onUpdate

M.onClientEndMission      = onClientEndMission    -- this is related to level load, not to missions

M.startWithFade = startWithFade
M.startAsScenario = startAsScenario
M.stop = stop
M.attemptAbandonMissionWithFade = attemptAbandonMissionWithFade

-- exclusivity
M.getForegroundMissionId = function() return foregroundMissionId end

local function onExtensionLoaded() end
M.onExtensionLoaded = onExtensionLoaded
return M
