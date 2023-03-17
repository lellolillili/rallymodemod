-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {state={}}

local logTag = 'freeroam'

local inputActionFilter = extensions.core_input_actionFilter

local function startFreeroamHelper (level, startPointName, spawnVehicle)
  core_gamestate.requestEnterLoadingScreen(logTag .. '.startFreeroamHelper')
  loadGameModeModules()
  M.state = {}
  M.state.freeroamActive = true

  local levelPath = level
  if type(level) == 'table' then
    setSpawnpoint.setDefaultSP(startPointName, level.levelName)
    levelPath = level.misFilePath
  end

  inputActionFilter.clear(0)

  core_levels.startLevel(levelPath, nil, nil, spawnVehicle)
  core_gamestate.requestExitLoadingScreen(logTag .. '.startFreeroamHelper')
end

local function startAssociatedFlowgraph(level)
-- load flowgraphs associated with this level.
  if level.flowgraphs then
    for _, absolutePath in ipairs(level.flowgraphs or {}) do
      local relativePath = level.misFilePath..absolutePath
      local path = FS:fileExists(absolutePath) and absolutePath or (FS:fileExists(relativePath) and (relativePath) or nil)
      if path then
        local mgr = core_flowgraphManager.loadManager(path)
        --core_flowgraphManager.startOnLoadingScreenFadeout(mgr)
        mgr:setRunning(true)
        mgr.stopRunningOnClientEndMission = true -- make mgr self-destruct when level is ended.
        mgr.removeOnStopping = true -- make mgr self-destruct when level is ended.
        log("I", "Flowgraph loading", "Loaded level-associated flowgraph from file "..dumps(path))
       else
         log("E", "Flowgraph loading", "Could not find file in either '" .. absolutePath.."' or '" .. relativePath.."'!")
       end
    end
  end
end

local function startFreeroam(level, startPointName, wasDelayed, spawnVehicle)
  core_gamestate.requestEnterLoadingScreen(logTag)
  -- if this was a delayed start, load the FGs now.
  --if wasDelayed then
  --  startAssociatedFlowgraph(level)
  --end

  -- this is to prevent bug where freeroam is started while a different level is still loaded.
  -- Loading the new freeroam causes the current loaded freeroam to unload which breaks the new freeroam
  local delaying = false
  if scenetree.MissionGroup then
    log('D', logTag, 'Delaying start of freeroam until current level is unloaded...')
    M.triggerDelayedStart = function()
      log('D', logTag, 'Triggering a delayed start of freeroam...')
      M.triggerDelayedStart = nil
      startFreeroam(level, startPointName, true, spawnVehicle)
    end
    endActiveGameMode(M.triggerDelayedStart)
    delaying = true
  elseif not core_gamestate.getLoadingStatus(logTag .. '.startFreeroamHelper') then -- remove again at some point
    startFreeroamHelper(level, startPointName, spawnVehicle)
    core_gamestate.requestExitLoadingScreen(logTag)
  end
  -- if there was no delaying and the function call itself didnt
  -- come from a delayed start, load the FGs (starting from main menu)
  if not delaying then
    startAssociatedFlowgraph(level)
  end

  if false and not shipping_build and settings.getValue('enableCrashCam') then
    extensions.load('core_crashCamMode')
  end
end

local function startFreeroamByName(levelName, startPointName)
  local level = core_levels.getLevelByName(levelName)
  if level then
    startFreeroam(level, startPointName)
    return true
  end
  return false
end

local function onPlayerCameraReady()
  if M.state.freeroamActive and gameplay_traffic.getState() == 'off' and settings.getValue('trafficLoadForFreeroam') then
    log('I', logTag, 'Now spawning traffic for freeroam mode')
    gameplay_traffic.setupTraffic()
  end
end

local function onClientPreStartMission(levelPath)
  local path, file, ext = path.splitWithoutExt(levelPath)
  file = path .. 'mainLevel'
  if not FS:fileExists(file..'.lua') then return end
  extensions.loadAtRoot(file,"")
  if mainLevel and mainLevel.onClientPreStartMission then
    mainLevel.onClientPreStartMission(levelPath)
  end
end

local function onClientStartMission(levelPath)
  local path, file, ext = path.splitWithoutExt(levelPath)
  file = path .. 'mainLevel'

  if M.state.freeroamActive then
    extensions.hook('onFreeroamLoaded', levelPath)

    local am = scenetree.findObject("ExplorationCheckpointsActionMap")
    if am then am:push() end
  end
end

local function onClientEndMission(levelPath)
  if M.state.freeroamActive then
    M.state.freeroamActive = false
    local am = scenetree.findObject("ExplorationCheckpointsActionMap")
    if am then am:pop() end
  end

  if not mainLevel then return end
  local path, file, ext = path.splitWithoutExt(levelPath)
  extensions.unload(path .. 'mainLevel')
end

-- Resets previous vehicle alpha when switching between different vehicles
-- Used to fix multipart highlighting when switching vehicles
local function onVehicleSwitched(oldId, newId, player)
  if oldId then
    extensions.core_vehicle_partmgmt.selectReset(oldId)
  end
end

local function onResetGameplay(playerID)
  if scenario_scenarios and scenario_scenarios.getScenario() then return end
  if campaign_campaigns and campaign_campaigns.getCampaign() then return end
  if career_career and career_career.isCareerActive() then return end
  for _, mgr in ipairs(core_flowgraphManager.getAllManagers()) do
    if mgr:blocksOnResetGameplay() then return end
  end
  be:resetVehicle(playerID)
end

local function startTrackBuilder(levelName, forceLoad)
  extensions.load("trackbuilder_trackBuilder")

  if not trackbuilder_trackBuilder then
    log('E', logTag, 'Could not find trackbuilder extentions')
    return
  end

  if getCurrentLevelIdentifier() == nil or forceLoad then
    local level = core_levels.getLevelByName(levelName)
    if not level then
      log('E', logTag, 'Level not found: ' .. tostring(levelName))
      return
    end

    local callback = function ()
      log('I', logTag, 'startTrackBuilder callback triggered...')
      trackbuilder_trackBuilder.showTrackBuilder()
    end

    extensions.setCompletedCallback("onClientStartMission", callback);
    startFreeroam(level)
  else
    trackbuilder_trackBuilder.toggleTrackBuilder()
    guihooks.trigger("MenuHide")
  end
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if worldReadyState == 0 then
    -- When the world is ready, we have to set the camera we want to use. However, we want to do this
    -- when we have vehicles spawned.
    local vehicles = scenetree.findClassObjects('BeamNGVehicle')
    for k, vecName in ipairs(vehicles) do
      local to = scenetree.findObject(vecName)
      if to and to.obj and to.obj:getId() then
        commands.setGameCamera()
        break
      end
    end
  end
end

local function onAnyMissionChanged(state)
  if false and not shipping_build then
    if state == "started" then
      if core_crashCamMode then
        extensions.unload('core_crashCamMode')
      end
    elseif state == "stopped" then
      if settings.getValue('enableCrashCam') then
        extensions.load('core_crashCamMode')
      end
    end
  end
end

local function onSettingsChanged()
  if false and not shipping_build then
    if settings.getValue('enableCrashCam') then
      extensions.load('core_crashCamMode')
    elseif core_crashCamMode then
      extensions.unload('core_crashCamMode')
    end
  end
end

-- public interface
M.startFreeroam = startFreeroam
M.startFreeroamByName = startFreeroamByName
M.onPlayerCameraReady = onPlayerCameraReady
M.onClientPreStartMission = onClientPreStartMission
M.onClientPostStartMission = onClientPostStartMission
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onVehicleSwitched = onVehicleSwitched
M.onResetGameplay = onResetGameplay
M.startTrackBuilder = startTrackBuilder
M.onUpdate = onUpdate
M.onAnyMissionChanged = onAnyMissionChanged
M.onSettingsChanged = onSettingsChanged

return M
