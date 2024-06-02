-- This is a slightly modded version of the original waypoints.lua file.

-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--[[
TODO
 * Move logic for winning the race into onRaceWaypoint path for when a vehicle crosses the last waypoint
 * Branching waypoints - Add an option to suggest best route
 * Improve activateWaypointBranch processing of vehicle waypoint after activation of a branch
]]--

local M = {}
M.state = {}
M.dependencies = {'scenario_scenarios'}

local logTag = 'waypointsNoSound'

local raceMarker = require("scenario/race_marker")

local function clearState()
  M.state = {}
  M.state.vehicleWaypointsData = {}
  M.state.nextWpForVehicle = {}
  M.state.waypointBranches = {}
  M.state.currentWaypointChoice = {}
  M.state.currentBranch = nil
  M.state.waypointsConfigData = {}
  M.state.branchGraph = {}
  M.state.pathnodes = {}
end

-- returns the next waypoint
local function getNextWaypoint(w, diff)
  local scenario = scenario_scenarios.getScenario()

  if not scenario then
    return nil, nil
  end

  if w.waypointConfig[w.cur] and w.waypointConfig[w.cur].isFinalWaypoint then
    if w.lap + 1 < scenario.lapCount or scenario.lapCount == 0 then
      -- new lap
      return 1, 1
    else
      -- all done
      return nil, nil
    end
  end
  -- no new lap, just new waypoint
  return w.cur+1, 0
end

local function processWaypoint(vid)
  local scenario = scenario_scenarios.getScenario()

  if not scenario then
    return nil
  end

  local bo = be:getObjectByID(vid)

  if not bo then
    return nil
  end

  local vehicleWaypointsData = M.state.vehicleWaypointsData
  local w = vehicleWaypointsData[vid]

  w.cur = w.next
  local lapDiff = -1


  -- before we even do anything, include a dummy wp if we encounter a waypoint after which we branch
  if w.cur == 0 then
    w.next = 1
    lapDiff = 0
  else
    w.next, lapDiff = getNextWaypoint(w, 1)
  end
  local modes = {}
  if scenario.rollingStart and w.next == 0 and scenario.startTimerCheckpoint ~= nil then
    w.nextWps = {{branch = M.state.lapConfigName, cpName = scenario.startTimerCheckpoint}}
    local nwp = scenario.nodes[w.nextWps[1].cpName]
    --raceMarker.setModes({nwp}, 'start')
    modes[w.nextWps[1].cpName] = 'start'
  else
    -- show markers
    local nextWps = {}
    if w.cur == 0 then
      -- case for rendering the first marker (when the race has not started)
      modes[w.waypointConfig[1].cpName] = 'default'
      nextWps = {w.waypointConfig[1]}
    else
      -- put all successors of the current wp in the list and show them
      for i, s in ipairs(w.waypointConfig[w.cur].successors) do

        local isLastWP = M.state.branchGraph[s.branch][s.index].isFinalWaypoint
        nextWps[i] = s
        if isLastWP then
          if (w.lap + 1 < scenario.lapCount or scenario.lapCount == 0) then
            modes[s.cpName] = 'lap' -- green for final wp within a lap
          else
            modes[s.cpName] = 'final' -- blue for final wp of the final lap
          end
        else
          if w.waypointConfig[w.cur].isBranching and #w.waypointConfig[w.cur].successors > 1 then
            modes[s.cpName] = 'branch' -- yellow for branching
          else
            modes[s.cpName] = 'default' -- red for regular
          end
        end
      end
    end

    -- add all successors of successors to a list and render them
    for _, from in pairs(nextWps) do
      for i, s in pairs(M.state.branchGraph[from.branch][from.index].successors) do
        if not (M.state.branchGraph[from.branch][from.index].isFinalWaypoint and not (w.lap + 1 < scenario.lapCount or scenario.lapCount == 0)) then
        -- only add those if the waypoint is not the last waypoint.
          modes[s.cpName] = 'next'
        end
      end
    end
    w.nextWps = nextWps
  end

  if not w.nextWps or #w.nextWps == 0 then
    log('E', logTag, 'No successors for waypoint found!')
  end
  M.state.nextWpForVehicle[vid] = w.next
  if not w.next then
    modes = {}
  end
  if (bo.playerUsable == true or bo.playerUsable == '1') then
    raceMarker.setModes(modes)
  end
  return lapDiff
end

local function copyInitialWaypointConfig(vid)
  local scenario = scenario_scenarios.getScenario()
  local waypointConfig = {}
  for i = 1, #scenario.BranchLapConfig do
    if M.state.branchGraph[M.state.lapConfigName][i] then
      table.insert(waypointConfig, deepcopy(M.state.branchGraph[M.state.lapConfigName][i]))
    end
  end
  M.state.vehicleWaypointsData[vid].waypointConfig = waypointConfig
end



local function initialiseVehicleData(vid)
  local scenario = scenario_scenarios.getScenario()

  if not scenario then
    return
  end

  local vehicleWaypointsData = M.state.vehicleWaypointsData
  local vehicle = be:getObjectByID(vid)

  if vehicle and ((vehicle.playerUsable == true or vehicle.playerUsable == '1') or (scenario and scenario.aiControlledVehiclesById[vid])) then
    if scenario.rollingStart and scenario.startTimerCheckpoint ~= nil then
      vehicleWaypointsData[vid] = { cur = -2, next = -1, lap = 0, waypointConfig = {}, nextWps = {}, historicalLapConfig = {}}
    else
      vehicleWaypointsData[vid] = { cur = -1, next = 0, lap = 0, waypointConfig = {}, nextWps = {}, historicalLapConfig = {}}
    end
    local vData = vehicleWaypointsData[vid]
    vData.wheelOffsets = {}
    vData.currentCorners = {}
    vData.previousCorners = {}
    local wCount = vehicle:getWheelCount()-1
    if wCount > 0 then
      local vehiclePos = vehicle:getPosition()
      local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
      local x,y,z = vRot * vec3(1,0,0),vRot * vec3(0,1,0),vRot * vec3(0,0,1)
      --local oobbz = vec3(vehicle:getSpawnWorldOOBB():getHalfExtents()).z/2
      for i=0, wCount do
        local axisNodes = vehicle:getWheelAxisNodes(i)
        local nodePos = vec3(vehicle:getNodePosition(axisNodes[1]))
        local pos = vec3(nodePos:dot(x), nodePos:dot(y), nodePos:dot(z))
        table.insert(vData.wheelOffsets, pos)
        table.insert(vData.currentCorners, vRot*pos + vehiclePos)
        table.insert(vData.previousCorners, vRot*pos + vehiclePos)
      end
    end
    copyInitialWaypointConfig(vid)
    processWaypoint(vid)
  end
end

local function getVehicleLapConfig(vid)
  local w = M.state.vehicleWaypointsData[vid]
  if not vid or not w then return {} end
  local ret = {}
  for i,p in ipairs(w.waypointConfig) do
    ret[i] = p.cpName
  end
  return ret
end

-- callback for the waypoint system
-- called when a vehicle drives through the targeted waypoint
local function onScenarioVehicleTrigger(vid, wpData, dtOff)
  -- decide upon progress here and update the UI
  local scenario = scenario_scenarios.getScenario()

  if not scenario then
    return
  end
  local bo = be:getObjectByID(vid)
  if not bo then return end

  local lapDiff = processWaypoint(vid)
  local vehicleWaypointsData = M.state.vehicleWaypointsData
  local w = vehicleWaypointsData[vid]

  if scenario.rollingStart and w.cur == 0 then -- hit the starting line
    scenario_scenarios.rollingStartTriggered()
    if (bo.playerUsable == true or bo.playerUsable == '1') then
      -- Engine.Audio.playOnce('AudioGui', "event:>UI>Special>Checkpoint")
      extensions.hook( 'onRaceWaypoint', data)
    end
  elseif w.cur ~= -1 then
    local data = {cur = w.cur, curPos = wpData.pos, curRot = wpData.rot, curRadius = wpData.radius, next = w.next,
                  vehicleId = vid, vehicleName = bo:getField('name', ''),
                  waypointName = w.waypointConfig[w.cur] and w.waypointConfig[w.cur].cpName or "", time = scenario.timer - dtOff, lapDiff = lapDiff,
                  currentLapConfig = getVehicleLapConfig(vid)
                }

    extensions.hook('onRaceWaypointReached', data)

    if (bo.playerUsable == true or bo.playerUsable == '1') then
      -- Engine.Audio.playOnce('AudioGui', "event:>UI>Special>Checkpoint")
      extensions.hook( 'onRaceWaypoint', data)
    end
  end

  if w.next == nil then
    -- all done
    w.nextWps = {}
    scenario_scenarios.endRace()
    return
  end

  if lapDiff and lapDiff > 0 then

    w.historicalLapConfig[w.lap+1] = getVehicleLapConfig(vid)
    w.lap = w.lap + lapDiff
    scenario.currentLap = w.lap
    extensions.hook('onRaceLap',
      {
        lap = w.lap,
        time = scenario.timer - dtOff,
        vehicleId = vid,
        vehicleName = bo:getField('name', ''),
        currentLapConfig = getVehicleLapConfig(vid),
        historicalLapConfig = w.historicalLapConfig
      })
    copyInitialWaypointConfig(vid)
  end
end



local function onScenarioChange(scenario)
  if not scenario then
    clearState()
    return
  end

end
local function insertWaypoints(branchName, vid)

 -- still having problems if the there is a branch inside a branch
  local scenario = scenario_scenarios.getScenario()
  if not scenario or not scenario.lapConfig or not branchName or not vid then
    return
  end
  local w = M.state.vehicleWaypointsData[vid]
  local index = w.cur+1

  for i = 1, #scenario.lapConfigBranches[branchName] do
    if M.state.branchGraph[branchName][i] then
      table.insert(w.waypointConfig, index, deepcopy(M.state.branchGraph[branchName][i]))
      --table.insert(scenario.lapConfig, index, M.state.branchGraph[branchName][i].cpName)
      index = index+1
    end
  end
end

local function removeWaypoints(data)
  local scenario = scenario_scenarios.getScenario()
  if not scenario or not scenario.lapConfig or not data then
    return
  end

  local newLapConfig = {}
  for _,wpName in ipairs(scenario.lapConfig) do
    if not tableContains(data, wpName) then
      table.insert(newLapConfig, wpName)
    end
  end

  scenario.lapConfig = newLapConfig
end

local function deactivateWaypointBranch(branchName)
  do return end
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end

  local waypointBranches = M.state.waypointBranches
  if waypointBranches[branchName] then
    removeWaypoints(waypointBranches[branchName])
  end

  if M.state.currentBranch == branchName then
    M.state.currentBranch = nil
  end
end

local function activateWaypointBranch(branchName, vehicleId, dtOff)
  if not branchName then
    return
  end
  local scenario = scenario_scenarios.getScenario()
  local vehWpData = M.state.vehicleWaypointsData[vehicleId]
  local vehicle = be:getObjectByID(vehicleId)
  if not scenario or not vehicle or not vehWpData then
    return
  end

  insertWaypoints(branchName, vehicleId)
  vehWpData.nextWp = vehWpData.cur + 1
  extensions.hook( 'onRaceBranchChosen', {
    branchName = branchName,
    time = scenario.timer - dtOff,
    vehicleId = vehicleId,
    vehicleName = vehicle:getField('name', ''),
  })
end

local function getLastElementsFromBranch(branchName)
  local ret = {}
  local branchWaypoint = scenario_scenarios.getScenario().lapConfigBranches[branchName]
  local cur = branchWaypoint[#branchWaypoint]
  if type(cur) == 'string' then
      return {{branch = branchName, index = #branchWaypoint, cpName = cur }}
  elseif  type(cur) == 'table' then
    for i,b in ipairs(cur) do
      local ends = getLastElementsFromBranch(b)
      for _,e in ipairs(ends) do
        table.insert(ret, e)
      end
    end
  end
  return ret
end

local function createFromToGraph(from, to)
  -- insert successors into graph
  for _,f in pairs(from) do
    -- if the branch does nt exist, create it
    if M.state.branchGraph[f.branch] == nil then
      M.state.branchGraph[f.branch] = {}
    end
    -- if the CP at this index in the branch does not exist, create it
    if M.state.branchGraph[f.branch][f.index] == nil then
      M.state.branchGraph[f.branch][f.index] = {
        cpName = f.cpName,
        successors = {},
        index = f.index,
        branch = f.branch
      }
    end
    for _,t in pairs(to) do
     -- check if successor already exists
      local existing = false
      for _,s in pairs(M.state.branchGraph[f.branch][f.index].successors) do
        if s.index == t.index and s.branch == t.branch then
          existing = true
        end
      end
      -- only add if not existing
      if not existing then
        table.insert(M.state.branchGraph[f.branch][f.index].successors,
          {
            branch = t.branch,
            index = t.index,
            cpName = t.cpName,
            insertBranch = t.index == 1
          })
        if  t.branch ~= M.state.lapConfigName and t.branch ~= f.branch then
          M.state.branchGraph[f.branch][f.index].isBranching = true
        end
      end
    end
  end
end

local function createSuccessorGraph()
  local scenario = scenario_scenarios.getScenario()
  local from = {}
  local to = {}
  -- create a list of all paths including main path
  local paths = {}
  for name, branch in pairs(scenario.lapConfigBranches or {}) do
    paths[name] = branch
  end
  -- in case someone names one branch "mainPath"...
  local name = "mainPath"
  while paths[name] ~= nil do name = name.."x" end
  paths[name] = scenario.BranchLapConfig
  M.state.originalBranches = paths
  M.state.lapConfigName = name
  for pName, path in pairs(paths) do
    --M.state.branchGraph[pName] = {}
    -- the first element of this list must always be a singular waypoint.
    from = {{index = 1, branch = pName, cpName = path[1]}}
    for i = 2, #path do
      -- generate successor list
      to = {}
      local cur = path[i]
      if type(cur) == 'string' then
        to =  {
          {
          cpName = cur,
          branch = pName,
          index = i
          }
        }
      elseif  type(cur) == 'table' then
        to = {}
        for i, branchName in ipairs(cur) do
          to[i] = {
            cpName = M.state.waypointBranches[branchName][1],
            branch = branchName,
            index = 1
          }
        end
      end

      createFromToGraph(from, to)

      -- generate next from-list
      if type(cur) == 'string' then
        from = {{branch = pName, index = i, cpName = cur}}
      elseif  type(cur) == 'table' then
        from = {}
        for i, branchName in ipairs(cur) do
          -- first elements of a branch must always be a singular waypoint
          for _, f in ipairs(getLastElementsFromBranch(branchName)) do
            table.insert(from, {branch = f.branch, index = f.index, cpName = f.cpName})
          end
        end
        --dump(from)
      end

    end
  end

  -- manually add last/first waypoint
  local from  ={}

  local cur = scenario.BranchLapConfig[#scenario.BranchLapConfig]
  if type(cur) == 'string' then
    from =  {
      {
      cpName = cur,
      branch = M.state.lapConfigName,
      index = #scenario.BranchLapConfig
      }
    }
  elseif  type(cur) == 'table' then
    for i, branchName in ipairs(cur) do
      -- first elements of a branch must always be a singular waypoint
      for _, f in ipairs(getLastElementsFromBranch(branchName)) do
        table.insert(from, {branch = f.branch, index = f.index, cpName = f.cpName})
      end
    end
  end
  createFromToGraph(from, {{index = 1, branch = M.state.lapConfigName, cpName = scenario.BranchLapConfig[1]}})
  for _, f in ipairs(from) do
    M.state.branchGraph[f.branch][f.index].isFinalWaypoint = true
    for _, s in ipairs(M.state.branchGraph[f.branch][f.index].successors) do
      s.insertBranch = false
    end
  end

end

local function onScenarioRestarted(scenario)
  scenario.lapConfig = deepcopy(scenario.initialLapConfig)
  clearState()
  local scenario = scenario_scenarios.getScenario()
  -- initialize branching stuff
  if scenario then
    scenario.disableWaypointTimes = scenario.lapConfigBranches
    M.state.waypointBranches = {}

    if scenario.BranchLapConfig then
      for bName, branch in pairs(scenario.lapConfigBranches or {}) do
        M.state.waypointBranches[bName] = {}
        for i, v in ipairs(branch) do
          if type(v) == 'string' then
            table.insert(M.state.waypointBranches[bName],v)
          end
        end
      end
    end
  end
  createSuccessorGraph()
end

local function initialise()
  log('I', logTag, 'Using rallyMode \"waypoints\" module.')
  clearState()
  local scenario = scenario_scenarios.getScenario()
  if not scenario.lapConfig or #scenario.lapConfig == 0 then
       log('I', logTag,'No lapconfig found or lapconfig empty. Not initializing waypoints system')
    return
  end
  -- initialize branching stuff
  if scenario then
    scenario.disableWaypointTimes = scenario.lapConfigBranches
    M.state.waypointBranches = {}
    if scenario.BranchLapConfig then
      for bName, branch in pairs(scenario.lapConfigBranches or {}) do
        M.state.waypointBranches[bName] = {}
        for i, v in ipairs(branch) do
          if type(v) == 'string' then
            table.insert(M.state.waypointBranches[bName],v)
          end
        end
      end
    end
  end
  createSuccessorGraph()

  --[[ old campaign stuff
  local waypointsConfigData = M.state.waypointsConfigData
  if campaign_campaigns and campaign_campaigns.getCampaignActive() then

    local campaign = campaign_campaigns.getCampaign()
    local configData = campaign.meta.waypoints or {}
    waypointsConfigData.highlightLastWaypoint = configData.highlightLastWaypoint and configData.highlightLastWaypoint.enabled == true

    if waypointsConfigData.highlightLastWaypoint then
     local color = configData.highlightLastWaypoint.color or { 0, 0.07, 1, 1}
     waypointsConfigData.lastWaypointColor = ColorF(color[1], color[2], color[3], color[4])
    end
  end]]

    -- notify race_markers of all nodes used in this race.
  local allWPs = {}
  for _, wpb in pairs(M.state.branchGraph) do
    for _, wp in pairs(wpb) do
      allWPs[wp.cpName] = true
    end
  end
  if scenario.startTimerCheckpoint then
    allWPs[scenario.startTimerCheckpoint] = true
  end
  local wpList = {}
  for wp, _ in pairs(allWPs) do
    local node = scenario.nodes[wp]
    table.insert(wpList, {name = wp, pos = vec3(node.pos), radius = node.radius, normal = node.rot, up = node.up })
    local pn = require('/lua/ge/extensions/gameplay/race/pathnode')(nil, wp, -1)
    pn.pos = vec3(node.pos)
    pn.radius = node.radius
    pn:setNormal(node.rot or nil)
    M.state.pathnodes[wp] = pn
  end
  table.sort(wpList, function(a,b) return a.name < b.name end)
  local markers = nil
  if scenario.track and scenario.track.customMarker and scenario.track.customMarker~='default' then
    markers = scenario.track.customMarker
  end
  raceMarker.setupMarkers(wpList, markers)

  -- Set waypoint for all vehicles
  if scenario.lapConfig and #scenario.lapConfig > 0 then
    for _, vid in pairs(scenario.vehicleNameToId) do
      initialiseVehicleData(vid)
    end
  end

  --[[ For Prototype idea of highlighting the final waypoint always
  if waypointsConfigData.highlightLastWaypoint and scenario.lapConfig and #scenario.lapConfig > 0 then
    local numWaypoints = #scenario.lapConfig
    local lastWpName = scenario.lapConfig[numWaypoints]
    local lastWp = scenario.nodes[lastWpName]
    if lastWp then
      raceMarker.setFinalMarkerPosition(vec3(lastWp.pos),  lastWp.radius, waypointsConfigData.lastWaypointColor)
    end
  end
  ---- End of Prototype idea]]



end

local function onPreRender(dtReal, dtSim, dtRaw)
  if not scenario_scenarios then return end
  local scenario = scenario_scenarios.getScenario()
  local playerVehicleId = be:getPlayerVehicleID(0)
  if not scenario or not playerVehicleId then return end

  -- see if a vehicle has driven through a target waypoint
  local vehicleWaypointsData = M.state.vehicleWaypointsData or {}
  for vid, vehWpData in pairs(vehicleWaypointsData) do
    local vehicle = be:getObjectByID(vid)
    local vehicleData = map.objects[vid]

    -- advance corners
    local vPos = vehicle:getPosition()
    local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
    for i, corner in ipairs(vehWpData.wheelOffsets) do
      vehWpData.previousCorners[i]:set(vehWpData.currentCorners[i])
      vehWpData.currentCorners[i]:set(vPos + vRot*corner)
    end

    --local nextWp = vehWpData.nextWp -- target waypoint
    local successors = vehWpData.nextWps
    local triggered = false
    if successors and vehicle and vehicleData then
      for k, v in pairs(successors) do
        local nextWp = scenario.nodes[v.cpName]
        local pn = M.state.pathnodes[v.cpName]
        if not pn then
          log("E","","Pathnode " .. v.cpName ..  " is missing!")
        end
        if not triggered and vehicle and vehicleData and pn then
          local hit, tNorm = pn:intersectCorners(vehWpData.previousCorners, vehWpData.currentCorners)
          if hit then
            local dtOff = dtSim * (1-tNorm)
            --print("closest hit was at " .. tNorm..", saving you " .. dtOff .. "s :)")
            vehWpData.nextWp = nil
            if v.insertBranch then
              activateWaypointBranch(v.branch, vid, dtOff)
            end
            onScenarioVehicleTrigger(vid, nextWp, dtOff)
            triggered = true
          end
        end
      end
    end
  end
end

local function drawDebug()
  for vid, vehWpData in pairs(M.state.vehicleWaypointsData or {}) do
    for i = 1, #vehWpData.previousCorners do
      debugDrawer:drawLine(vec3(vehWpData.previousCorners[i]), vec3(vehWpData.currentCorners[i]),  ColorF(1,0,0,1))
      debugDrawer:drawSphere(vec3(vehWpData.currentCorners[i]), 0.025, ColorF(1,0,0,0.25))
    end
  end
end
--M.onDrawDebug = drawDebug

-- todo: this always returns false or what?
local function isFinalWaypoint(vehicleId, waypointName)
  local scenario = scenario_scenarios.getScenario()

  if not scenario or not scenario.lapConfig then
    return false
  end

  local vehWaypointData = M.state.vehicleWaypointsData[vehicleId]
  if not vehWaypointData then
    return false
  end

  return false --M.state.finalWaypoints[waypointName] and vehWaypointData.lap >= scenario.lapCount
end

local function getVehicleWaypointData(vehicleId)
  local data = deepcopy(M.state.vehicleWaypointsData[vehicleId])
  return data
end

local function onSerialize()
  -- log('D', logTag, 'onSerialize called...')
  local data = {}
  data.vehicleWaypointsData = convertVehicleIdKeysToVehicleNameKeys(M.state.vehicleWaypointsData)
  data.nextWpForVehicle = convertVehicleIdKeysToVehicleNameKeys(M.state.nextWpForVehicle)
  data.waypointBranches = M.state.waypointBranches
  data.currentWaypointChoice = M.state.currentWaypointChoice
  data.currentBranch = M.state.currentBranch
  -- dump(data)
  return data
end

local function onDeserialized(data)
  -- log('D', logTag, 'onDeserialized called...')
  M.state.vehicleWaypointsData = convertVehicleNameKeysToVehicleIdKeys(data.vehicleWaypointsData)
  M.state.nextWpForVehicle = convertVehicleNameKeysToVehicleIdKeys(data.nextWpForVehicle)
  M.state.waypointBranches = data.waypointBranches
  M.state.currentWaypointChoice = data.currentWaypointChoice
  M.state.currentBranch = data.currentBranch
end

local function onVehicleAIStateChanged(data)
  if data and data.aiControlled == true and not M.state.vehicleWaypointsData[data.vehicleId] then
    initialiseVehicleData(data.vehicleId)
  end
end

local function updateResetVehicleData(vehicleId, curWpIndex, nextWpIndex)

  local vehicleWaypointsData = M.state.vehicleWaypointsData
  if vehicleWaypointsData and not vehicleWaypointsData[vehicleId] or not curWpIndex then
    initialiseVehicleData(vehicleId)
  elseif curWpIndex and nextWpIndex then
    M.state.vehicleWaypointsData[vehicleId].cur = curWpIndex - 1
    M.state.vehicleWaypointsData[vehicleId].next = nextWpIndex - 1
    processWaypoint(vehicleId)
  end
end

local function onClientEndMission()
  clearState()
end

-- system
M.onPreRender               = onPreRender
M.onUpdate                  = onUpdate
M.onSerialize               = onSerialize
M.onDeserialized            = onDeserialized
M.onClientEndMission        = onClientEndMission

-- public interface
M.onScenarioChange          = onScenarioChange -- from scenario
M.onScenarioRestarted       = onScenarioRestarted -- from scenarios
M.initialise                = initialise -- from scenarios

M.getVehicleWaypointData    = getVehicleWaypointData -- getter
M.onVehicleAIStateChanged   = onVehicleAIStateChanged


-- private
M.onScenarioVehicleTrigger  = onScenarioVehicleTrigger
M.deactivateWaypointBranch  = deactivateWaypointBranch
M.activateWaypointBranch    = activateWaypointBranch
M.addWaypointBranch         = addWaypointBranch

-- used by checkpoints.lua?!
M.isFinalWaypoint           = isFinalWaypoint
M.updateResetVehicleData    = updateResetVehicleData


return M

