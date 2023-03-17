-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--  Supplies code-created scenario info for the quickrace selection screen.
--  The created scenarios contain the available tracks.
--  This code also loads the scenario, creating the vehicle, needed prefabs
--  and race checkpoints, and also sets the scenario data so that the scenario_race.lua
--  can be used to handle the race logic.

local M = {}
local fg = nil
local times = {}

-- load the prefabs defined in the quickrace track, and also the vehicle.
-- it is loaded here, so that the scenario code can work with the vehicle.
local function onLoadCustomPrefabs(sc)
  log( 'I', 'quickRaceLoad', 'onLoadCustomPrefabs' )
  if sc and sc.track and sc.track.flowgraph then
    fg = core_flowgraphManager.loadManager(sc.track.flowgraph.file)
    for name, value in pairs(sc.track.flowgraph.variables or {}) do
      fg.variables:changeBase(name, value)
    end
    fg.transient = true
    fg:setRunning(true)
  end

  if sc and sc.track and sc.track.raceFile then
    local file = sc.track.raceFile
    local json = readJsonFile(file)
    if not json then
      log('E',nil, 'could not read race file for time trials: ' .. tostring(file))
    else
      local path = require('/lua/ge/extensions/gameplay/race/path')("New Path")
      path:onDeserialized(json)
      sc.path = path
    end
    if sc.path then
      sc.track.startTransform = {}
      local id = nil
      if sc.track.rollingStart then
        if sc.track.reverse then
          id = 'rollingReverseStartPosition'
        else
          id = 'rollingStartPosition'
        end
      else
        if sc.track.reverse then
          id = 'reverseStartPosition'
        else
          id = 'defaultStartPosition'
        end
      end
      local sp = sc.path.startPositions.objects[sc.path[id]]
      local rot = quatFromEuler(0,0,math.pi) * sp.rot
      local x, y, z = rot * vec3(1,0,0), rot * vec3(0,1,0), rot * vec3(0,0,1)
      local pos = vec3(sp.pos + 1.5*y + 0.33*z)
      sc.track.startTransform = {
        pos = pos,
        rot = rot
      }
    end
  end
  M.loadVehicle(sc)
end

M.getNodesOnBranch = function(segment,config)
  local ret = {}
  local path = segment.path
  local graphData = segment.path.config.graph[segment.id]
  repeat
    table.insert(ret, segment:getTo()._generatedName)
    graphData = segment.path.config.graph[segment.id]
    segment = path.segments.objects[graphData.successors[1]]
  until segment.missing or #graphData.successors ~= 1 or graphData.lastInLap
  if #graphData.successors > 1 then
    local split = {}
    config.branches = config.branches or {}
    for _, succ in ipairs(graphData.successors) do
      table.insert(split, '__b'..succ)
      config.branches['__b'..succ] = M.getNodesOnBranch(path.segments.objects[succ], config)
    end
    table.insert(ret, split)
  end
  return ret
end


local function onCustomWaypoints(sc)
  if sc and sc.path then
    local path = sc.path
    if sc.track.reverse then
      path:reverse()
    end
    path:autoConfig()

    -- patch nodes into scenario.nodes
    sc.generatedNodes = {}
    for _, node in ipairs(path.pathnodes.sorted) do
      local nodeName = '__generated_from_path__' .. node.id
      node._generatedName = nodeName
      sc.generatedNodes[nodeName] = {
        pos = vec3(node.pos),
        radius = node.radius,
        rot = node.hasNormal and vec3(node.normal) or nil
      }
    end
    sc.startTimerCheckpoint = path.pathnodes.objects[path.startNode]._generatedName
    -- convert into lapconfig-format using Depth-first search
    local config = {
      lapConfig = nil
    }
    config.lapConfig = M.getNodesOnBranch(path.segments.objects[path.config.startSegments[1]], config)
    if config.branches then
      sc.BranchLapConfig = config.lapConfig
      sc.lapConfigBranches = config.branches
      local lc = {}
      for _, e in ipairs(config.lapConfig) do
        if type(e) == 'string' then
          table.insert(lc, e)
        end
      end
      sc.lapConfig = lc
      sc.initialLapConfig = deepcopy(lc)
    else
      sc.initialLapConfig = deepcopy(config.lapConfig)
      sc.BranchLapConfig = deepcopy(config.lapConfig)
      sc.lapConfig = deepcopy(config.lapConfig)
    end
    sc.path = nil
  end

  if sc.generatedNodes then
    for k, v in pairs(sc.generatedNodes) do
      sc.nodes[k] = v
    end
  end
end

local function onClientEndMission()
  if fg then
    fg:setRunning(false)
    core_flowgraphManager.removeManager(fg)
    fg = nil
  end
end

local function onScenarioLoaded(sc)
  if not sc.track then return end
  --dump(sc.track.tod .. " = TOD")
  if sc.track.tod == 0 or sc.track.tod == 1 or sc.track.tod == 8 then
    local playerVehicle = be:getPlayerVehicle(0)
    if playerVehicle then
      playerVehicle:queueLuaCommand("electrics.set_fog_lights(1) ; electrics.setLightsState(2)")
    end
  end
  if sc.track.reverse then
    for _, node in pairs(sc.nodes) do
      if node.rot ~= nil then
        node.rot = node.rot * -1
      end
    end
  end
end

--loads the vehicle by creating a TS-snipped which has the position and vehicle information embedded.
local function loadVehicle(scenario)
  local vehicle = scenario.vehicle
  if not vehicle then return end

--  local createVehicle = [[
--    if(isObject(scenario_player0)) {
--      scenario_player0.delete();
--    }]]

  --TorqueScript.eval(createVehicle)
  --jbeam, configString, pos, rot, color, color2, color3, name, cling
  local pos = vec3()
  local rot = quat()
  if scenario.track.raceFile then
    pos = scenario.track.startTransform.pos
    rot = scenario.track.startTransform.rot
  else
        -- figure out which spawnSphere we should use for this scenario_race.
    local spawnSphere = ''
    if scenario.track.rollingStart then
      if scenario.track.reverse then
        spawnSphere = scenario.track.spawnSpheres.rollingReverse
      else
        spawnSphere = scenario.track.spawnSpheres.rolling
      end
    else
      if scenario.track.reverse then
        spawnSphere = scenario.track.spawnSpheres.standingReverse
      else
        spawnSphere = scenario.track.spawnSpheres.standing
      end
    end
    local spawnObj = scenetree.findObject(spawnSphere)
    if spawnObj ~= nil then
      pos = vec3(spawnObj:getPosition())
      rot = quat(spawnObj:getRotation())
    else
      log('E', "QuickRace", "Could not find spawnSphere " .. spawnSphere .. "! Using 0/0/0 instead.")
    end
  end

  vehicle.vehicleName = 'scenario_player0'
  vehicle.pos = pos
  vehicle.rot = rot
  vehicle = fillVehicleSpawnOptionDefaults(vehicle.model, vehicle)
  local veh = core_vehicles.spawnNewVehicle(vehicle.model, vehicle)

  veh:setPositionRotation(pos.x,pos.y,pos.z,rot.x,rot.y,rot.z,rot.w)
  --[[
  print("----")
  print("ID:")
  print(veh:getId())
  print("Vehcle by ID")
  print(be:getObjectByID(veh:getId()))
  print("Vehcle rotation through ID")
  print(be:getObjectByID(veh:getId()) and be:getObjectByID(veh:getId()):getRotation())
  print("Vehicle Rotation:")
  print(veh:getRotation())
  print("VS rotation given:")
  print(rot)
  print("----")
  ]]
  scenetree.ScenarioObjectsGroup:addObject(veh)
end

-- callback for the UI: called when it finishes counting down
local function onCountdownEnded()
  local playerVehicle = be:getPlayerVehicle(0)
  if playerVehicle then
    playerVehicle:queueLuaCommand('controller.setFreeze(0)')
  else
    log('E','quickRaceLoad','No player vehicle found!')
  end

  times = {}
end

local function getConfigKey(rolling, reverse, laps)

  local scenario = scenario_scenarios.getScenario()

  if rolling == nil then rolling = scenario.rollingStart end
  if reverse == nil then reverse = scenario.isReverse end
  if laps == nil then laps = scenario.lapCount end

  local mode = "standing"

  if rolling then mode = "rolling" end
  if reverse then mode = mode.."Reverse" end
  if laps then mode = mode .. laps end

  return mode
end


local function onRaceStart( )
  times = {}
end

local function onRaceWaypointReached( wpInfo )
  if not scenario_scenarios.getScenario().isQuickRace then return end

  if not wpInfo.next or wpInfo.next == 1 then
    times[#times+1] = wpInfo.time
    for i = 1, (#times)-1 do
      times[#times] = times[#times] - times[i]
    end
    --dump(wpInfo)
    --dump(times)
    local scenario = scenario_scenarios.getScenario()
    local playerVehicle = be:getPlayerVehicle(0)
    local record = {
      playerName = core_vehicles.getVehicleLicenseText(playerVehicle),
      vehicleBrand = scenario.vehicle.file.Brand,
      vehicleName = scenario.vehicle.file.Name,
      vehicleConfig = string.gsub(scenario.vehicle.config,"(.*/)(.*)/(.*).pc", "%3"),
      vehicleModel = scenario.vehicle.model
    }

    local place = core_highscores.setScenarioHighscoresCustom(times[#times]*1000,record,scenario.levelName,scenario.scenarioName,M.getConfigKey(false,nil,0))

    if scenario.highscores == nil then
      scenario.highscores = {}
    end
    if scenario.highscores.singleRound == nil then
      scenario.highscores.singleRound = {}
    end

    if place == -1 then
      return
    end

    --dump("place is "..place)
    local incIndexes = {}
    for k,v in ipairs(scenario.highscores.singleRound) do
      if place <= v then
        incIndexes[#incIndexes+1] = k
      end
    end
    --dump(incIndexes)
    for k,v in ipairs(incIndexes) do
      scenario.highscores.singleRound[k] = scenario.highscores.singleRound[k]+1
    end
    scenario.highscores.singleRound[#scenario.highscores.singleRound+1] = place
    --dump(scenario.highscores.singleRound)

  end
end

local function getVehicleBrand(scenario)
  return scenario.vehicle.file.Brand
end

local function getVehicleName(scenario)
return scenario.vehicle.file.Name
end

local function onRaceResult(final)
  if not scenario_scenarios.getScenario().isQuickRace then return end
  local scenario = scenario_scenarios.getScenario()
  local vehicle = be:getPlayerVehicle(0)

  --highscores.setScenarioHighscores(,M.getVehicleName(),core_vehicles.getVehicleLicenseText(vehicle),scenario.map,scenario.scenarioName,M.getConfigKey(),0)

  local record = {
    playerName = core_vehicles.getVehicleLicenseText(vehicle),
    vehicleBrand = scenario.vehicle.file.Brand,
    vehicleName = scenario.vehicle.file.Name,
    vehicleConfig = string.gsub(scenario.vehicle.config,"(.*/)(.*)/(.*).pc", "%3"),
    vehicleModel = scenario.vehicle.model
  }

  local place = core_highscores.setScenarioHighscoresCustom(final.finalTime*1000, record ,scenario.levelName,scenario.scenarioName,M.getConfigKey())
  local scores = core_highscores.getScenarioHighscores(scenario.levelName, scenario.scenarioName, M.getConfigKey())
  if scenario.highscores == nil then
    scenario.highscores = {}
  end
  scenario.highscores.scores = scores
  if place ~= -1 then
    scenario.highscores.scores[place].current = true
  end
  scenario.highscores.place = place
  scenario.highscores.singleScores = core_highscores.getScenarioHighscores(scenario.levelName, scenario.scenarioName, M.getConfigKey(false,nil,0))
  for _,v in ipairs(scenario.highscores.singleRound) do
    if v <= #(scenario.highscores.singleScores) then
      scenario.highscores.singleScores[v].current = true
    end
  end
  scenario.viewDetailed = 0
  if place == -1 then
    scenario.detailedRecord = {
      playerName = core_vehicles.getVehicleLicenseText(vehicle),
      vehicleBrand = scenario.vehicle.file.Brand,
      vehicleName = scenario.vehicle.file.Name,
      place = " / ",
      formattedTimestamp = os.date("!%c",os.time())
    }
  else
    scenario.detailedRecord = scores[place]
  end
end

local showingTimeScreen = false

local function changeTimeTrialConfig()
  -- dump('toggleTimeTrialsScreen called....')
  if M.timeTrialOpen == nil then
    M.timeTrialOpen = false
  end

  M.timeTrialOpen = not M.timeTrialOpen
  if M.timeTrialOpen then
    guihooks.trigger('MenuItemNavigation', 'toggleMenues')
    guihooks.trigger('ChangeState', {state = 'menu.quickraceOverview'})
    bullettime.pause(true)
  else
    bullettime.pause(false)
  end
end

local function onUiChangedState (curUIState, prevUIState)
  if curUIState == 'menu' and prevUIState == 'menu.quickraceOverview' then
    if M.timeTrialOpen then
      changeTimeTrialConfig()
    end
  end
end

M.onClientEndMission = onClientEndMission
M.changeTimeTrialConfig = changeTimeTrialConfig
M.onUiChangedState = onUiChangedState

M.onScenarioLoaded = onScenarioLoaded
M.onLoadCustomPrefabs = onLoadCustomPrefabs

M.addCheckPoint = addCheckPoint
M.onCountdownEnded = onCountdownEnded
M.loadVehicle = loadVehicle
M.loadCheckpoints = loadCheckpoints
M.getConfigKey = getConfigKey

M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceResult = onRaceResult

M.getVehicleBrand = getVehicleBrand
M.getVehicleName = getVehicleName
M.onCustomWaypoints = onCustomWaypoints
return M

