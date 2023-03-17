-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local max = math.max
local abs = math.abs
local rad = math.rad
local ceil = math.ceil

local M = {}
M.dependencies = {'scenario_scenarios', 'core_groundMarkers'}
local helper = require('scenario/scenariohelper')
local logTag = 'scenario_busdriver'

local finalWaypointName = 'scenario_finish1'
local playerInstance = 'scenario_player0'
local running = false
local playerWon = false
local wpList = {}
local busConfig = {}
local passedWp={}
local currentLine = {}
local nextStop = nil
local stopTimer = -1
local markers = {}
local monitorMarker = false
local currentAlphaMarker = 0
local setpointAlphaMarker = 0
local nameMarkers = {"busMarkerTL","busMarkerTR","busMarkerBL","busMarkerBR"}
local markerIndexCorrection = {{3,4,2,1},{1,2,4,3} }
local stopComplete = false
local timeToWaitAtStop = 5
local exitTggBeforeTimer = false
local origSpawnAABB = nil
local stats = {}
local prevVel = nil
local prevPos = nil
local prevAcc = nil
local initialDamage = nil
local smootherJer = nil
local smootherAcc = nil
local paused = false

local function newStat()
  return {
    stopAngle    = {fill = 1, mark = 1},
    stopDistance = {fill = 0, mark = 0},
    damage       = {fill = 0, mark = 0},
    smoothness   = {fill = 0, mark = 0}
  }
end

local function reset()
  running = false
  playerWon = false
  exitTggBeforeTimer = false
  local playerVehicle = scenetree.findObject(playerInstance)
  if playerVehicle then
    playerVehicle:queueLuaCommand('controller.setFreeze(1)')
  end
  passedWp={}
  nextStop = nil
  for _,m in ipairs(markers) do
    m:setField('instanceColor', 0, '1 1 1 0')
    m:setPosition(vec3(0, 0, 0))
  end
  setpointAlphaMarker,currentAlphaMarker = 0,0
  monitorMarker = false
  stats = {}
  prevVel = nil
  prevPos = nil
  prevAcc = nil
  smootherJer = nil
  smootherAcc = nil
  initialDamage = nil

  if playerVehicle then
    playerVehicle:setSpawnLocalAABB(Box3F())
  end
end

local function fail(reason)
  --log('E', logTag,"FAIL ======="..reason)
  scenario_scenarios.finish({failed = reason})
  reset()
end

local function getCurrentStop()
  local result = 1
  if currentLine.tasklist and nextStop then
    for i=1, #currentLine.tasklist, 1 do
      if currentLine.tasklist[i][1] == nextStop[1] then
        result = i
        break
      end
    end
  end
  return result
end

local function computeStats(stats)
  local result = {
      damage       = {total=100, fill=100, mark=100}
    , smoothness   = {total=100, fill=100, mark=100}
    , stopAngle    = {total=  0, fill=  0, mark=  0}
    , stopDistance = {total=100, fill=100, mark=100}
  }

  local nStops = #stats
  local lastDamage = initialDamage
  for k,v in ipairs(stats) do
    local damage = 0
    if v.damage.mark > lastDamage then damage = 1 end
    result.damage.fill = 100 - damage*(100)
    result.damage.mark = 100 - damage*(100)
    result.damage.total= result.damage.total- damage*(100/nStops + 15)
    lastDamage = v.damage.mark

    v.smoothness.mark = clamp(v.smoothness.mark,0,1)
    v.smoothness.fill = clamp(v.smoothness.fill,0,1)
    if v.smoothness.fill < 0.55 then v.smoothness.fill = 0 end
    result.smoothness.fill = 100 - 100*square(v.smoothness.fill)
    result.smoothness.mark = 100 - 100*square(v.smoothness.mark)
    result.smoothness.total= result.smoothness.total- 100*square(v.smoothness.fill) / nStops

    local a = v.stopAngle.fill*v.stopAngle.fill
    local b = a*a; a = b*b; b = a*a; a = b*b; b = a*a -- cheap power
    local r = round(100*clamp(b,0,1)*4)/4
    if r > 99 then r = 100 end
    result.stopAngle.fill = r
    result.stopAngle.mark = r
    result.stopAngle.total= result.stopAngle.mark + r / nStops

    local r = 100*smoothstep(abs(v.stopDistance.fill)/8)
    if r < 1 then r = 0 end
    result.stopDistance.fill = 100 - r
    result.stopDistance.mark = 100 - r
    result.stopDistance.total= result.stopDistance.total - r / nStops
  end

  -- clamp all stats
  for k,v in pairs(result) do
    result[k].fill = clamp(v.fill, 0,100)
    result[k].mark = clamp(v.mark, 0,100)
    result[k].total= clamp(v.total,0,100)
  end

  return result
end

local function success(reason)
  if false then -- temporarily disabled bus stats, #2783
    local st = computeStats(stats)
    local playerVehicle = scenetree.findObject(playerInstance)
    statistics_statistics.initialiseArbitraryStat(   "busDamage",        "ui.stats.damage", playerVehicle, playerInstance, 100, 100)
    statistics_statistics.initialiseArbitraryStat(  "smoothness",    "ui.stats.smoothness", playerVehicle, playerInstance, 100, 100)
    statistics_statistics.initialiseArbitraryStat(   "stopAngle",    "ui.stats.stopAngle", playerVehicle, playerInstance, 100, 100)
    statistics_statistics.initialiseArbitraryStat("stopDistance", "ui.stats.stopDistance", playerVehicle, playerInstance, 100, 100)

    local playerVehicleID = playerVehicle:getID()
    statistics_statistics.setStatProgress(playerVehicleID,   "smoothness", playerInstance, {status=  st.smoothness.total < 50 and 'failed' or 'pass', value=  st.smoothness.total, maxValue=100})
    statistics_statistics.setStatProgress(playerVehicleID,    "stopAngle", playerInstance, {status=   st.stopAngle.total < 50 and 'failed' or 'pass', value=   st.stopAngle.total, maxValue=100})
    statistics_statistics.setStatProgress(playerVehicleID, "stopDistance", playerInstance, {status=st.stopDistance.total < 50 and 'failed' or 'pass', value=st.stopDistance.total, maxValue=100})
    statistics_statistics.setStatProgress(playerVehicleID,    "busDamage", playerInstance, {status=      st.damage.total < 50 and 'failed' or 'pass', value=      st.damage.total, maxValue=100})
  end

  --log('E', logTag,"success ======="..reason)
  scenario_scenarios.finish({msg = reason})
  reset()
end


local function initBusLine()
  busConfig = scenario_scenarios.getScenario().busdriver
  local playerVehicle = scenetree.findObject(playerInstance)
  if playerVehicle then
    local playerVehicleID = playerVehicle:getID()
    currentLine = extensions.core_busRouteManager.setLine(playerVehicleID,busConfig.routeID,busConfig.variance)
    nextStop = currentLine.tasklist[1]
    -- log("E", logTag, "onRaceStart  nextStop '"..dumps(nextStop).."'   currentLine.tasklist ='"..dumps(currentLine.tasklist).."'")
  else
    currentLine = nil
  end

  if currentLine == nil then
    fail('Failed to load the line data for '..tostring(busConfig.routeID).."  "..tostring(busConfig.variance))
  end  --core_busRouteManager.onAtStop({cur=1,next=2,vehicleId=playerVehicleID})
end

local function onScenarioRestarted(scenario)
  reset()
  initBusLine()
end

local function createBusMarker(markerName)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/position_marker.dae")
  marker:setPosition(vec3(0, 0, 0))
  marker.scale = vec3(1, 1, 1)
  marker:setField('rotation', 0, '1 0 0 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 1 1 0')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject(markerName)
  scenetree.MissionGroup:addObject(marker)
  return marker
end

local function hex2rgb(hex)
  if not hex then
    return
  end
  local hex = hex:gsub("#","")
  if hex:len() == 3 then
    return (tonumber("0x"..hex:sub(1,1))*17)/255, (tonumber("0x"..hex:sub(2,2))*17)/255, (tonumber("0x"..hex:sub(3,3))*17)/255
  else
    return tonumber("0x"..hex:sub(1,2))/255, tonumber("0x"..hex:sub(3,4))/255, tonumber("0x"..hex:sub(5,6))/255
  end
end

local function onRaceStart()
  -- log('I', logTag,'onRaceStart called')
  reset()
  initBusLine()
  local playerVehicle = be:getPlayerVehicle(0)
  if playerVehicle then
    playerVehicle:queueLuaCommand('controller.setFreeze(0)')
  end
  if scenetree.ScenarioObjectsGroup then
    stats = {newStat()}
    prevVel = nil
    prevPos = nil
    prevAcc = nil
    smootherJer = nil
    smootherAcc = nil
    initialDamage = nil

    log('I', logTag,'Creating markers')
    local ScenarioObjectsGroup = scenetree.ScenarioObjectsGroup
    if #markers == 0 then
      for k,v in pairs(nameMarkers) do
        local mk = scenetree.findObject(v)
        if mk == nil then
          log('I', logTag,'Creating marker '..tostring(v))
          mk = createBusMarker(v)
          ScenarioObjectsGroup:addObject(mk.obj)
        end
        table.insert(markers, mk)
      end
    end
  end

  -- check navhelp
  if currentLine.navhelp then
    local mapData = map.getMap()
    for k, v in pairs(currentLine.navhelp) do
      for _, wp in pairs(v) do
        if not mapData.nodes[wp] then
          log('W', logTag,'Missing navhelp '.. wp)
        end
      end
    end
  end

  --log('I', logTag,'get scenar . lapConfig')
  --wpList = scenario_scenarios.getScenario().lapConfig
  --be:getObjectByID(vehicleId):queueLuaCommand("controller.getController('busNextStopDsp').onDepartedStop( "..dumps({unpack(wpList, 1,#wpList)}).." )")


  --scenario_scenarios.trackVehicleMovementAfterDamage(playerInstance, {waitTimerLimit=2})

  initBusLine()
  local wps = {}
  --print("Building Bus route:")
  --for _, task in ipairs(currentLine.tasklist) do
  local task = currentLine.tasklist[1]
  if currentLine.navhelp then
    for _, help in ipairs(currentLine.navhelp[task[1]] or {}) do
      table.insert(wps, help)
      print("  " .. help)
    end
  end
  table.insert(wps, vec3(task[3][1], task[3][2], core_terrain.getTerrainHeight(vec3(task[3]))))
  core_groundMarkers.setFocus(wps, nil, nil, nil, nil, nil, {hex2rgb(currentLine.routeColor)})
  running = true
end

local function moveBusMarkers()
  local tpos,pos = vec3(nextStop[3]) + vec3(0,0,3), vec3(0,0,0)
  local tr = quat(nextStop[4])
  local r
  local zVec,yVec,xVec = tr*vec3(0,0,1), tr*vec3(0,1,0), tr*vec3(1,0,0)

  local d = nextStop[5][1]*0.5-1.0
  local w = nextStop[5][2]*0.5-1.0
  -- local bext = ob:getHalfExtents()
  -- if bext.x*1.25 < d then d = bext.x*1.25 end
  -- if bext.y*1.25 < w then w = bext.y*1.25 end
  for k,marker in pairs(markers)do
    if k == 1 then --top left
      pos = (tpos-xVec*d+yVec*w)
      r = tr * quatFromEuler(0, 0, rad(90))
    elseif k == 2 then --Top Right
      pos = (tpos+xVec*d+yVec*w)
      r = tr * quatFromEuler(0, 0, rad(180))
    elseif k == 3 then --Bottom Right
      pos = (tpos+xVec*d-yVec*w)
      r = tr * quatFromEuler(0, 0, rad(270))
    elseif k == 4 then --Botton Left
      pos = (tpos-xVec*d-yVec*w)
      r = tr
    end
    local heightCorrection = be:castRay( (pos), (pos-vec3(0,0,13)) )
    if heightCorrection < 1 then
      local tHeight = be:castRay( (tpos), (tpos-vec3(0,0,13)) )
      if tHeight *0.8 > heightCorrection then
        pos.z = pos.z-tHeight*0.8
        heightCorrection = be:castRay( (pos), (pos-vec3(0,0,13)) )
      end
    end
    pos.z = pos.z-heightCorrection
    marker:setPosRot(pos.x, pos.y, pos.z, r.x,r.y,r.z,r.w)
    marker:setField('instanceColor', 0, "1 0 0 1")
  end

end

--duplicate code at vehicle/controller/busLineCtrl.lua:123
local function isTriggerOnBusLine(tasks,tname)
  for k,v in pairs(tasks) do
    if v[1] == tname then return true end
  end
  return false
end

local function onBeamNGTrigger(data)
  if running == false then return end
  -- log('E', logTag,'onBeamNGTrigger called '..dumps(data))
  if data.type and data.type == "busstop" and data.subjectName == playerInstance and isTriggerOnBusLine(currentLine.tasklist,data.triggerName) then

    --core_busRouteManager.onAtStop(data)

    if data.event == "enter" then
      exitTggBeforeTimer = false
      if tableContains(passedWp, data.triggerName) then guihooks.trigger('ScenarioRealtimeDisplay', {msg = 'scenarios.busRoutes.alreadyStop'});return end
      -- if busConfig.strictStop then
        stopTimer = 0
        stopComplete = false
        local cur =1
        if currentLine.tasklist then
          for i=1, #currentLine.tasklist, 1 do
            if currentLine.tasklist[i][1] == data.triggerName then cur=i; break end
          end
        end
        if cur > 1 and not tableContains(passedWp, currentLine.tasklist[cur-1][1]) then
          fail( "scenarios.busRoutes.skip" )
        end
      -- end
    end

    if data.event == "exit" then
      -- if not busConfig.strictStop then
      --   if not tableContains(passedWp, data.triggerName) then
      --     table.insert( passedWp, data.triggerName )
      --   end
      -- end
      guihooks.trigger('ScenarioRealtimeDisplay', {msg = ''})

      if (not stopComplete or stopTimer < timeToWaitAtStop) then
        -- fail("you didn't wait !!! timer="..tostring(stopTimer))
        exitTggBeforeTimer = true
        return
      end

      monitorMarker = false
      for _,m in ipairs(markers) do
        m:setField('instanceColor', 0, '0 1 0 1')
        currentAlphaMarker=1
      end
      setpointAlphaMarker = 0

      local cur =1
      if currentLine.tasklist then
        for i=1, #currentLine.tasklist, 1 do
          if currentLine.tasklist[i][1] == data.triggerName then cur=i; break end
        end
      end
      if currentLine.tasklist and cur == #currentLine.tasklist then success("scenarios.busRoutes.success")end

      if currentLine.navhelp then
        for k,v in pairs(currentLine.navhelp) do --reset passedWp because of navhelp
          for i2,v2 in ipairs(v) do
            if passedWp[v2] then
              passedWp[v2] = false
            end
          end
        end
      end
    end
  end

  if data.type and data.type == "buswp" and data.event == "enter" then
    if not tableContains(passedWp, data.triggerName) then
      table.insert( passedWp, data.triggerName )
    end
  end

end

local function onRaceResult(final)
  if playerWon == true then
    local scenario = scenario_scenarios.getScenario()
    local vehicle = core_vehicles.getCurrentVehicleDetails()
    local playerVehicle = be:getPlayerVehicle(0)
    local record = {
      playerName = core_vehicles.getVehicleLicenseText(playerVehicle),
      vehicleBrand = vehicle.model.Brand,
      vehicleName = vehicle.model.Name,
      vehicleConfig = vehicle.current.pc_file,
      vehicleModel = vehicle.model
    }
    core_highscores.setScenarioHighscoresCustom(final.finalTime*1000, record, scenario.levelName, scenario.name, "busRoute")
  end
end

local function onVehicleStoppedMoving(vehicleID, damaged)
  if running then
    local playerVehicleID = scenetree.findObject(playerInstance):getID()
    if vehicleID == playerVehicleID and damaged then
      if not playerWon then
        fail('scenarios.utah.chapter_2.chapter_2_6_canyon.fail.msg')
      end
    end
  end
end

local function onVehicleSwitched(oldId, newId, player)
  log('I', logTag,'onVehicleSwitched called: '..dumps(oldId, newId, player))
  if player == 0 then
    reset()
    local playerVehicle = be:getPlayerVehicle(0)
    if playerVehicle then
      playerVehicle:queueLuaCommand('controller.setFreeze(1)')
    else
      log("E", "", "could not freeze, obj invalid")
    end
    busConfig = scenario_scenarios.getScenario().busdriver
    currentLine = extensions.core_busRouteManager.setLine(newId,busConfig.routeID,busConfig.variance)
    if currentLine == nil then
      fail('Failed to load the line data for '..tostring(busConfig.routeID).."  "..tostring(busConfig.variance))
    end
  end
end

local isRightNode = function(triggerPos, first, second)
  local mapData = map.getMap()
  local pos0 = mapData.nodes[first].pos
  local pos1 = mapData.nodes[second].pos
  return (pos1-pos0):normalized():cross(vec3(0, 0, 1)):dot((triggerPos-pos0):normalized()) > 0
end


local function renderDebugLine()
  local wps = {}
  for i, stop in ipairs(currentLine.tasklist) do
    local vec3Destination = vec3(stop[3])
    debugDrawer:drawTextAdvanced(vec3Destination, String('['..i..'] '..stop[2] .. ' / ' .. stop[1]), ColorF(0,0,0,1), true, false, ColorI(255, 255, 255, 255))
    local firstDest, secondDest, distanceDest = map.findClosestRoad(vec3Destination)
    local trigger = scenetree.findObject(nextStop[1])
    if not isRightNode(vec3Destination, firstDest, secondDest) then
      local temp = firstDest
      firstDest = secondDest
      secondDest = temp
    end
    if currentLine.navhelp and currentLine.navhelp[stop[1]] then
      for i, wp in ipairs(currentLine.navhelp[stop[1]]) do
        table.insert(wps, wp)
      end
    end

    table.insert(wps, firstDest)
    table.insert(wps, secondDest)
  end
  core_groundMarkers.setFocus(wps, 10, 150 * 1000, 200 * 1000, vec3Destination, true, {hex2rgb(currentLine.routeColor)})
end

local function onPreRender(dt, dtSim)
  --local debugPath = true

  --core_groundMarkers.setFocus(nil)
  if (not nextStop) or nextStop == "nil" then return end
  if nextStop == nil then return end

  if currentAlphaMarker ~= setpointAlphaMarker and #markers > 0 then
    if currentAlphaMarker > setpointAlphaMarker then currentAlphaMarker=currentAlphaMarker-dt*0.5
    elseif currentAlphaMarker < setpointAlphaMarker then currentAlphaMarker=currentAlphaMarker+dt*0.5 end
    if currentAlphaMarker < 0 then currentAlphaMarker = 0 elseif currentAlphaMarker > 1 then currentAlphaMarker=1 end
    for _,m in ipairs(markers) do
      m:setField('instanceColor', 0, (setpointAlphaMarker ==0 and '0 1 0 ' or '1 0 0 ')..tostring(currentAlphaMarker))
    end
    monitorMarker = currentAlphaMarker ==1
  end

  local pv = be:getPlayerVehicle(0)
  if not pv then return end

  -- update ratings
  if running and dtSim > 0 then
    local stop = getCurrentStop()
    if stats[stop] == nil then stats[stop] = newStat() end

    -- calculate smoothness rating
    local fwd  = vec3(pv:getDirectionVector()):normalized()
    local up   = vec3(pv:getDirectionVectorUp()):normalized()
    local currPos = vec3(pv:getPosition())
    local currVel = (prevPos and (currPos - prevPos) or vec3()) / dtSim
    local currAcc = (prevVel and (currVel - prevVel) or vec3()) / dtSim
    local currJer = (prevAcc and (currAcc - prevAcc) or vec3()) / dtSim
    local acc = currAcc:rotated(quatFromDir(fwd, up):inversed():normalized())
    if not smootherAcc then smootherAcc = newTemporalSmoothing(15, 5) end

    -- Prevents division by zero gravity
    local gravity = core_environment.getGravity()
    gravity = max(0.1, abs(gravity)) * sign2(gravity)

    local smAcc = smootherAcc:getUncapped(acc.x, dtSim) / abs(gravity)
    local jerkMultiplier = 1/5000
    local jer = currJer:length() * jerkMultiplier
    if not smootherJer then smootherJer = newTemporalSmoothing(30000*jerkMultiplier, jerkMultiplier*5000000) end
    local smJer = smootherJer:getUncapped(jer, dtSim)
    if smJer > 2 then smootherJer:set(2) smJer = 2 end
    local smoothness = max(abs(smAcc) + smJer)
    --log("I", "", graphs(20*smAcc, 20)..graphs(20*smJer, 20)..graphs(20*smoothness, 20)..dumps(smoothness).." \t "..dumps(smAcc).." \t "..dumps(smJer))
    stats[stop].smoothness.mark = smoothness
    stats[stop].smoothness.fill = max(smoothness, stats[stop].smoothness.fill)
    prevVel = currVel
    prevPos = currPos
    prevAcc = currAcc

    -- calculate damage rating
    local trakedObj = map.getTrackedObjects()[pv:getID()]
    if not trakedObj then return end
    local damage = trakedObj.damage
    if not initialDamage then initialDamage = damage end
    stats[stop].damage.mark = damage

    -- stop distance rating
    local busStop = scenetree.findObject(nextStop[1])
    local busStopPos = vec3(busStop:getPosition())
    currPos = currPos + vec3(pv:getNodePosition(0))
    local diff = (currPos-busStopPos):rotated(quatFromDir(fwd, up):inversed():normalized())
    local stopDistance = diff.y
    stats[stop].stopDistance.mark = stopDistance
    stats[stop].stopDistance.fill = stopDistance

    -- stop angle rating
    local dotAngle = 0
    if abs(stopDistance) < 20 then
      local fwd = vec3(pv:getDirectionVector()):normalized()
      local busStopFwd = vec3(busStop:getTransform():getColumn(1)):normalized()
      local busStopUp = vec3(busStop:getTransform():getColumn(2)):normalized()
      local fwdAligned = fwd:projectToOriginPlane(busStopUp):normalized()
      dotAngle = abs(fwdAligned:dot(busStopFwd))
      if dotAngle < 0.70710678118 then
        -- compensate for misaligned bus stops (those that are wider than longer and then rotated 90deg)
        busStopFwd = busStopFwd:cross(busStopUp):normalized()
        dotAngle = abs(fwdAligned:dot(busStopFwd))
      end
    end
    stats[stop].stopAngle.mark = dotAngle
    stats[stop].stopAngle.fill = dotAngle

    -- send all computed ratings
    local data = computeStats(stats)
    data.busStopping = abs(stopDistance) < 20
    if false then -- temporarily disabled bus stats, #2783
      guihooks.trigger('BusRouteStats', data)
    end
  end

  --log("E", logTag, "onPreRender  nextStop("..dumps(type(nextStop))..")="..dumps(nextStop))
  local vec3Destination = vec3(nextStop[3])
  local proj = vec3(0,0,5)
  local heightCorrection = be:castRay( (vec3Destination+proj), (vec3Destination-proj*3) )
  if debugPath then
    debugDrawer:drawSphere(vec3Destination, 1.6, ColorF(1.0,0.0,0.0,1.0))
    debugDrawer:drawSphere(vec3(vec3Destination.x,vec3Destination.y,vec3Destination.z-heightCorrection+proj.z ), 0.9, ColorF(0.5,0.0,0.0,1.0))
    debugDrawer:drawLine((vec3Destination+proj), (vec3Destination-proj*2), ColorF(0.5,0.0,0.5,1.0))
  end
  vec3Destination.z = vec3Destination.z-heightCorrection+proj.z
  local firstDest, secondDest, distanceDest = map.findClosestRoad(vec3Destination)

  local trigger = scenetree.findObject(nextStop[1])
  if not trigger.bidirectional and not isRightNode(vec3Destination, firstDest, secondDest) then
    local temp = firstDest
    firstDest = secondDest
    secondDest = temp
  end

  --[[
  local wps = {}
  do
    local mapData = map.getMap()
    local vehPos = vec3(playerVehicle:getPosition())
    local distanceToWp = function(wp)
      return (mapData.nodes[wp] and vehPos:distance(vec3(mapData.nodes[wp].pos))) or 0
    end

    if currentLine.navhelp and currentLine.navhelp[nextStop[1] ] then
      for i, wp in ipairs(currentLine.navhelp[nextStop[1] ]) do
        if passedWp[wp] or distanceToWp(wp) < 15 then
          passedWp[wp] = true
        else
          table.insert(wps, wp)
        end
      end
    end
  end
  table.insert(wps, firstDest)
  table.insert(wps, secondDest)

  core_groundMarkers.setFocus(wps, 10, 150, 200, vec3Destination, nil, {hex2rgb(currentLine.routeColor)})
  --]]
  if M.enabledLineDebug then
    renderDebugLine()
  end

  if exitTggBeforeTimer then
    local vpos = vec3(pv:getPosition())
    -- disabled for now, sometimes make fail the scenario when maneuvering the bus.
    -- 20m is from the center of the trigger, with big trigger can fail after exit 1m from trigger
    --if vec3Destination:distance(vpos) > 20 then fail("scenarios.busRoutes.exitTggBeforeTimer") end
  end

  if monitorMarker then
    local ob = pv:getSpawnWorldOOBB()
    local vDirVec=vec3(pv:getDirectionVector())
    local tr = quat(nextStop[4])
    local yVec = tr*vec3(0,1,0)
    local trigger = scenetree.findObject(nextStop[1])
    trigger = Sim.upcast(trigger)
    -- local vUpVec=vec3(pv:getDirectionVectorUp())
    -- local vLeftVec=vDirVec:cross(vUpVec)
    local front = ((vDirVec:dot(yVec) > 0) and 1 or 0) +1
    local contained = false
    for i=0, 3, 1 do
      contained = trigger:isPointContained(ob:getPoint(i*2)) and trigger:isPointContained(ob:getPoint(i*2+1))
      markers[markerIndexCorrection[front][i+1]]:setField('instanceColor', 0, (contained and "1 0.5 0 1" or "1 0 0 1") )
    end
  end

end

local prevCamera = nil
local function onBusUpdate(state)
  -- log('E', logTag..".onBusUpdate",'event='..dumps(state))
  if state.event == "onTriggerTick" and not stopComplete and nextStop and nextStop[1] == state.triggerName then
    local playerVehicle = be:getPlayerVehicle(0)
    if not origSpawnAABB then
      origSpawnAABB = playerVehicle:getSpawnLocalAABB()
    end

    if state.speed > 0.1 and stopTimer < timeToWaitAtStop then
      playerVehicle:setSpawnLocalAABB(origSpawnAABB)
      stopTimer = 0
      guihooks.trigger('ScenarioRealtimeDisplay', {msg = "scenarios.busRoutes.stop"})
    elseif (not state.bus_dooropen or not state.bus_kneel) and busConfig.strictStop and stopTimer < timeToWaitAtStop then
      -- shrink bus box to avoid kneeling out of bus stop bounds
      do
        local box = Box3F()
        box:setExtents(origSpawnAABB:getExtents() * 0.75)
        box:setCenter(origSpawnAABB:getCenter())
        playerVehicle:setSpawnLocalAABB(box)
      end

      prevCamera = prevCamera or core_camera.getActiveCamName()
      core_camera.setByName(0, "onboard.rider", true)
      stopTimer = 0
      if not state.bus_kneel then
        guihooks.trigger('ScenarioRealtimeDisplay', {msg = "scenarios.busRoutes.kneel"})
      elseif not state.bus_dooropen then
        guihooks.trigger('ScenarioRealtimeDisplay', {msg = "scenarios.busRoutes.open"})
      end
    elseif stopTimer < timeToWaitAtStop then
      prevCamera = prevCamera or core_camera.getActiveCamName()
      core_camera.setByName(0, "external", true)
      guihooks.trigger('ScenarioRealtimeDisplay', {msg = "scenarios.busRoutes.wait", context = {remaining=tostring(ceil(timeToWaitAtStop - stopTimer))}})
      if paused == false then stopTimer = stopTimer + 0.1 end
    elseif (state.bus_dooropen or state.bus_kneel) and busConfig.strictStop then
      core_camera.setByName(0, "onboard.rider", true)
      if state.bus_dooropen then
        guihooks.trigger('ScenarioRealtimeDisplay', {msg = "scenarios.busRoutes.close"})
      elseif state.bus_kneel then
        guihooks.trigger('ScenarioRealtimeDisplay', {msg = "scenarios.busRoutes.raise"})
      end
    else
      if prevCamera ~= nil then core_camera.setByName(0, prevCamera, true) end
      prevCamera = nil
      stopComplete = true
      monitorMarker = false
      local cur =1
      if currentLine.tasklist then
        for i=1, #currentLine.tasklist, 1 do
          if currentLine.tasklist[i][1] == state.triggerName then
            cur=i
            break
          end
        end
      end

      if currentLine.tasklist and cur == #currentLine.tasklist then
        success("scenarios.busRoutes.success")
        return
      end
      guihooks.trigger('ScenarioRealtimeDisplay', { msg = 'scenarios.busRoutes.proceed'})
      -- if busConfig.strictStop then
        if not tableContains(passedWp, state.triggerName) then
          table.insert( passedWp, state.triggerName )
        end
      -- end
      for _,m in ipairs(markers) do
        m:setField('instanceColor', 0, '0 1 0 1')
      end

      -- next stop
      local cur = 1
      if currentLine.tasklist then
        for i=1, #currentLine.tasklist, 1 do
          if currentLine.tasklist[i][1] == nextStop[1] then cur=i; break end
        end
        if cur < #currentLine.tasklist then
          nextStop = currentLine.tasklist[cur+1]
          local wps = {}


          local task = nextStop
          if currentLine.navhelp then
            for _, help in ipairs(currentLine.navhelp[task[1]] or {}) do
              table.insert(wps, help)
              print("  " .. help)
            end
          end
          table.insert(wps, vec3(task[3][1], task[3][2], core_terrain.getTerrainHeight(vec3(task[3]))))
          core_groundMarkers.setFocus(wps, nil, nil, nil, nil, nil, {hex2rgb(currentLine.routeColor)})
        else
          nextStop = nil
        end
        -- log("E", logTag, "onBeamNGTrigger  nextStop '"..dumps(nextStop).."'   cur ='"..dumps(cur).."'")
      end

    end
  end
  if state.event == "onApproachStop" then
    if nextStop then
      moveBusMarkers()
      -- monitorMarker = true
      setpointAlphaMarker = 1
    end
  elseif state.event == "onDepartedStop" then
    local playerVehicle = be:getPlayerVehicle(0)
    if origSpawnAABB then playerVehicle:setSpawnLocalAABB(origSpawnAABB) end
  end
end

local function onScenarioLoaded(scenario)
  markers = {}

  if scenario.busdriver.simulatePassengers then
    -- getting current vehicle
    local playerVehicle = be:getPlayerVehicle(0)
    local configPath = playerVehicle:getField('partConfig', '0')
    -- reading in config file so we can add seat ballast
    local vehicleConfig = jsonReadFile(configPath)
    vehicleConfig.parts.citybus_seats_ballast = "citybus_seats_ballast"
    -- applying new config to vehicle
    extensions.core_vehicle_partmgmt.setConfig(vehicleConfig)
  end
  if scenario.busdriver.traffic and gameplay_traffic.getState() == "off" then
    local amount = core_settings_settings.getValue('trafficAmount')
    if amount == 0 then amount = getMaxVehicleAmount(12) end
    gameplay_traffic.setupTraffic(amount)
    gameplay_traffic.setTrafficVars({spawnValue = 1.3, spawnDirBias = 0.3})
  end
end

local function onExtensionUnloaded()
  markers = {}
  core_groundMarkers.setFocus(nil)

  --we freeze in the reset(), we need to unfreeze manually
  local playerVehicle = be:getPlayerVehicle(0)
  if playerVehicle then
    playerVehicle:queueLuaCommand('controller.setFreeze(0)')
  end
end

local function onPhysicsPaused()
  paused = true
end

local function onPhysicsUnpaused()
  paused = false
end

local function requestState()
  local tmp = currentLine
  local bsList = {}
  local cur = 1
  if nextStop then
    for i=1, #currentLine.tasklist, 1 do
      if currentLine.tasklist[i][1] == nextStop[1] then cur=i; break end
    end
  end
  for i=cur, #currentLine.tasklist, 1 do table.insert(bsList, currentLine.tasklist[i]) end
  tmp.tasklist = bsList
  guihooks.trigger('BusDisplayUpdate', tmp)
end

local function onClientEndMission()
  markers = {}
end

M.onBusUpdate = onBusUpdate
M.onPreRender = onPreRender
M.onVehicleSwitched = onVehicleSwitched
M.onRaceStart = onRaceStart
M.onBeamNGTrigger = onBeamNGTrigger
M.onRaceResult = onRaceResult
M.onExtensionUnloaded = onExtensionUnloaded
M.fail = fail
M.onScenarioRestarted = onScenarioRestarted
M.onScenarioLoaded = onScenarioLoaded
M.enabledLineDebug = false
M.requestState = requestState
M.onPhysicsPaused = onPhysicsPaused
M.onPhysicsUnpaused = onPhysicsUnpaused
M.onClientEndMission = onClientEndMission


--M.onVehicleStoppedMoving = onVehicleStoppedMoving
return M
