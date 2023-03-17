-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- constants
local M = {}

local triggerName = 'hotlappingCheckPoint'
local logTag = 'hotLapping'
local markerTS = [[if(isObject(hotlappingMarker)) {
          hotlappingMarker.delete();
        }
        new TSStatic(hotlappingMarker) {
           shapeName = "art/shapes/interface/checkpoint_marker.dae";
           playAmbient = "1";
           meshCulling = "0";
           originSort = "0";
           collisionType = "Collision Mesh";
           decalType = "Collision Mesh";
           allowPlayerStep = "1";
           renderNormals = "0";
           forceDetail = "-1";
           position = "0 0 -500";
           rotation = "1 0 0 0";
           scale = "6 6 100";
           useInstanceRenderData = "1"; // this activate per instace properties as instanceColor
           instanceColor = "1 1 1 1";
           canSave = "0";
           canSaveDynamicFields = "0";
           hidden = "false";
        };
        HotlappingGroup.add(hotlappingMarker);

        if(isObject(hotlappingMarkerNext)) {
          hotlappingMarkerNext.delete();
        }
        new TSStatic(hotlappingMarkerNext) {
               shapeName = "art/shapes/interface/checkpoint_marker.dae";
               playAmbient = "1";
               meshCulling = "0";
               originSort = "0";
               collisionType = "Collision Mesh";
               decalType = "Collision Mesh";
               allowPlayerStep = "1";
               renderNormals = "0";
               forceDetail = "-1";
               position = "0 0 -500";
               rotation = "1 0 0 0";
               scale = "3 3 100";
               useInstanceRenderData = "1"; // this activate per instace properties as instanceColor
               instanceColor = "1 1 1 1";
               canSave = "0";
               canSaveDynamicFields = "0";
               hidden = "true";
            };
        HotlappingGroup.add(hotlappingMarkerNext);
        ]]

-- whether the hotlapping is allowPlacingCP or not.
local allowPlacingCP = false
-- once the first lap is completed, the circuit is closed
local closed = false
-- Wether the timer is started or not
local started = false
-- used to signalize that this is the last iteration, and after this the race is ended.
local finalize = false
-- whether the course should be started instantly or after the first lap
--local instantStart = false
--local firstRoundIgnored = false

local useScenarioTimer = false
local useCustomTimerFunc = nil
-- The starting time of the current hotlapping.
local startTime
local totalTime

local pausedStart = 0
local currentPauseTime = 0
local totalPauseTime = 0

-- Contains all times for all checkPoints, starting from starttime
local times = {}

local currentLap = 0
local currentCP = 0

local bestLapIndex = -1

--stores all checkPoints
local checkPoints = {}
-- stores amount of checkPoints
local checkPointCount = 0
-- stores the amount of passed checkPoints
local checkPointIndex = 0
-- stores the positions of all checkpoints (for saving)
local checkPointPosAndSize = {}
-- stores the index of the next checkpoint to be passed
local nextCheckPointToBePassed = 0

local aiRacers = {}

-- timer when no updates should be posted
local lastRealMillis = 0

local justPassedCPWithinLap = false
local justLapped = false
local justStarted = false

local size = 2
local forceSendToGui = true
local isBranchingScenario = false
local invisible = false

--------------------------------------------------------------------
-- Starting and stopping of hotlapping,
-- placing, removing and passing markers,
-- starting, pausing and stopping of the race
--------------------------------------------------------------------

-- Called when the hotlapping starts.
local function startHotlapping()
  --log('E',logTag,'ERROR startHotlapping')
  useCustomTimerFunc = nil
  allowPlacingCP = true
  started = false

  checkPointIndex = 0
  TorqueScript.eval([[
  if(isObject(HotlappingGroup)) {
    HotlappingGroup.delete();
  }
  new SimGroup(HotlappingGroup);
  HotlappingGroup.clear();
  ]])
  TorqueScript.eval(markerTS)
  scenetree.hotlappingMarker.hidden = true
  scenetree.hotlappingMarkerNext.hidden = true
  --M.clearAllCP()
  checkPointCount = 0
  nextCheckPointToBePassed = 0
  times = {}
  checkPointPosAndSize = {}
  closed = false
  bestLapIndex = -1
  --firstRoundIgnored = false

  local vehicle = be:getPlayerVehicle(0)
  if not vehicle then
    log('E', logTag, 'No vehicle found!')
    allowPlacingCP = false
    return
  end

  local startPosition = vehicle:getPosition()

  -- TorqueScript.eval(markerTS)

  M.addCheckPoint(startPosition)
  --dump(levelName)
  pausedStart = 0
  currentPauseTime = 0
  totalPauseTime = 0
  useScenarioTimer = false
end

-- Called when the hotlapping stops.
local function stopHotlapping()
  --log('E',logTag,'clearAllCP')
  allowPlacingCP = false
  started = false
  closed = false
  M.clearAllCP()
  bestLapIndex = -1
  times = {}
end

local function startAi()
  if not checkPoints[0] then return end

  local route = {}
  for i = 1, tableSize(checkPoints) do
    local pos = checkPoints[i - 1]:getPosition()
    local name_a, name_b, distance = map.findClosestRoad(pos)
    if not name_a then
      log('E', logTag, 'Unable to find road node for AI path!')
      table.clear(route)
    end

    local a, b = map.getMap().nodes[name_a], map.getMap().nodes[name_b]
    if clamp(pos:xnormOnLine(a.pos, b.pos), 0, 1) > 0.5 then -- if we are closer to point b, swap it around
      name_a, name_b = name_b, name_a
    end

    table.insert(route, name_a)
  end
  if not route[1] then return end
  table.insert(route, route[1])

  for _, veh in ipairs(getAllVehiclesByType()) do
    local id = veh:getID()
    if not veh:isPlayerControlled() and not arrayFindValueIndex(gameplay_traffic.getTrafficList(), id) then
      if not aiRacers[id] then
        aiRacers[id] = {pos = veh:getPosition(), rot = quatFromDir(veh:getDirectionVector(), veh:getDirectionVectorUp())}
      else
        local pos = aiRacers[id].pos
        local rot = quat(0, 0, 1, 0) * aiRacers[id].rot
        veh:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
        veh:resetBrokenFlexMesh()
      end
      veh:queueLuaCommand('ai.driveUsingPath({wpTargetList = '..serialize(route)..', noOfLaps = 100, avoidCars = true})')
      veh:queueLuaCommand('ai.setParameters({turnForceCoef = 4, awarenessForceCoef = 0.15})') -- slightly improves racing

      if not aiRacers[id].ready then
        veh:queueLuaCommand('ai.setAggression(0.92)') -- sets aggression once
        aiRacers[id].ready = true
      end
    end
  end
end

local function stopAi()
  for i, v in ipairs(getAllVehiclesByType()) do
    local id = v:getID()
    if aiRacers[id] then
      v:queueLuaCommand('ai.setMode("stop")')
    end
  end
end

-- starts the scenario_race. Gets called when the first checkpoint with index 0 is passed
local function start()
  started = true
  startTime = os.clock()*1000
  currentCP = 1
  currentLap = 0
  bestLapIndex = -1
  totalTime = 0
  forceSendToGui = true
  justStarted = true
end

-- skips the current lap
local function skipLap()
  if not times[currentLap] then return end
  times[currentLap]['skipped'] = true
  currentCP = checkPointCount
  nextCheckPointToBePassed = 0
  for i = 1, checkPointCount do
    scenetree['markerBase'..(i)].instanceColor = ColorF( 1, 1,1, 1):asLinear4F()
    scenetree['markerBase'..(i)]:updateInstanceRenderData()
  end
  M.positionMarkers()
  forceSendToGui = true
end

-- stops the timer
local function stopTimer()
  log('D',logTag,'stopTimer')
  allowPlacingCP = true
  started = false
  checkPointIndex = 0
  nextCheckPointToBePassed = 0
  times = {}
  for i = 1, checkPointCount do
    if scenetree['markerBase'..(i)] then
      scenetree['markerBase'..(i)].instanceColor = ColorF(1, 1, 1, 1):asLinear4F()
      scenetree['markerBase'..(i)]:updateInstanceRenderData()
    end
  end
  stopAi()
  table.clear(aiRacers)
  M.positionMarkers()
end

-- adds a checkpoint to the track.
local function addCheckPoint(cpPos, cpSize)
  if not allowPlacingCP then
    return
  end
  if cpPos == nil then -- use the current players position
    local vehicle = be:getPlayerVehicle(0)
    cpPos = vehicle and vehicle:getPosition() or vec3(0,0,0)
  end
  if cpSize == nil then
    cpSize = vec3(size*4,size*4,8)
  end

  --create checkPoint object with id in name
  local checkPoint = createObject('BeamNGTrigger')
  checkPoint.loadMode = 1 --'Manual'
  --checkPoint.triggerType = 'Sphere'
  checkPoint:setField("triggerType", 0, 'Sphere')
  --checkPoint.debug = true
  --checkPoint.luaFunction = 'core_hotlapping.onHotLapTrigger'
  checkPoint:registerObject(triggerName .. checkPointCount)
  checkPoint:setPosition(cpPos)
  checkPoint:setScale(cpSize)
  --print("adding CP index " .. checkPointCount)
  --add checkPoint to list of checkPoints
  checkPoints[checkPointCount] = checkPoint
  checkPointPosAndSize[checkPointCount+1] = {}
  checkPointPosAndSize[checkPointCount+1].position = {cpPos.x, cpPos.y, cpPos.z}
  checkPointPosAndSize[checkPointCount+1].size = {cpSize.x, cpSize.y, cpSize.z}
  --dump(checkPointPosAndSize)
  checkPointCount= checkPointCount +1

  local marker = [[
    if(isObject(markerBase]]..checkPointCount..[[)) {
      racemarkerBase]]..checkPointCount..[[.delete();
    }
    new TSStatic(markerBase]]..checkPointCount..[[) {
      shapeName = "art/shapes/interface/checkpoint_marker_base.dae";
      playAmbient = "1";
      meshCulling = "0";
      originSort = "0";
      collisionType = "Collision Mesh";
      decalType = "Collision Mesh";
      allowPlayerStep = "1";
      renderNormals = "0";
      forceDetail = "-1";
      position = "]]..cpPos.x..' '.. cpPos.y..' '.. cpPos.z..[[";
      rotation = "1 0 0 0";
      scale = "]]..(1.72*cpSize.x)..' '.. (1.72*cpSize.y)..' '..cpSize.z..[[";
      useInstanceRenderData = "1"; // this activate per instace properties as instanceColor
      instanceColor = "1 1 1 1";
      canSave = "0";
      canSaveDynamicFields = "0";
    };
    HotlappingGroup.add(markerBase]]..checkPointCount..[[);
  ]]
  TorqueScript.eval(marker)
  if checkPointCount == 1 then
    scenetree.markerBase1.instanceColor = ColorF( 1, 0.07, 0, 1):asLinear4F()
    scenetree.markerBase1:updateInstanceRenderData()
  end
end

-- removes all checkpoints and clears the array saving them
local function clearAllCP()
  --log('E',logTag,"Removed All CP")
  --print("Deleting " .. #checkPoints .. " cps")
  for _,v in pairs(checkPoints) do
    if v ~= nil then
      v:delete()
    end
  end
  checkPoints = {}
  checkPointPosAndSize = {}
  checkPointCount = 0
  TorqueScript.eval([[
    if(isObject(HotlappingGroup)) {
      HotlappingGroup.clear();
    }
  ]])
  stopAi()
  table.clear(aiRacers)
end

-- positions the markers. The big marker will be on the next checkpoint, the small marker on the one after
local function positionMarkers( )
  if not scenetree.hotlappingMarker then
    return
  end
  scenetree.hotlappingMarker:setPosition((vec3(checkPointPosAndSize[nextCheckPointToBePassed+1].position)))
  scenetree.hotlappingMarker.hidden = invisible
  if checkPointCount > 1 then
    scenetree.hotlappingMarkerNext:setPosition((vec3(checkPointPosAndSize[((nextCheckPointToBePassed+1)%checkPointCount)+1].position)))
    scenetree.hotlappingMarkerNext.hidden = invisible
  end
  -- set color of checkpoint bases
  scenetree['markerBase'..(nextCheckPointToBePassed+1)].instanceColor = ColorF( 1, 0.07, 0, 1):asLinear4F()
  scenetree['markerBase'..(nextCheckPointToBePassed+1)]:updateInstanceRenderData()
  scenetree['markerBase'..(((nextCheckPointToBePassed+checkPointCount-1)%checkPointCount)+1)].instanceColor = ColorF( 1, 1,1, 1):asLinear4F()
  scenetree['markerBase'..(((nextCheckPointToBePassed+checkPointCount-1)%checkPointCount)+1)]:updateInstanceRenderData()
end

-- sets all marker objects as visible or invisible
local function setVisible(value)
  invisible = not value and true or false

  if scenetree.hotlappingMarker then
    scenetree.hotlappingMarker.hidden = invisible
  end
  if scenetree.hotlappingMarkerNext then
    scenetree.hotlappingMarkerNext.hidden = invisible
  end
  for i = 1, checkPointCount do
    if scenetree['markerBase'..i] then
      scenetree['markerBase'..i].hidden = invisible
    end
  end
end

-- internal trigger function. starts the race, closes the track and registers if the right checkpoints gets passed
local function onBeamNGTrigger(data)
   if allowPlacingCP and data.event == 'exit' and data.subjectID == be:getPlayerVehicleID(0) and string.startswith(tostring(data.triggerName), triggerName) then
    local cpNumber = tonumber(string.match (data.triggerName, "%d+"))
    --log('E',logTag,"Passed CP nr. "..cpNumber)
    if not started and cpNumber == 0 then

      --if ( (not instantStart) and firstRoundIgnored) or instantStart then
      M.start()
      --else
        --   firstRoundIgnored = true
          --  return
        --end
      -- log('E',logTag,"start racing " .. firstRoundIgnored .. " and " .. instantStart)
    else
      if not closed and cpNumber == 0 then
        closed = true
        scenetree.markerBase1.instanceColor = ColorF( 1, 1, 1, 1):asLinear4F()
        scenetree.markerBase1:updateInstanceRenderData()
        --log('E',logTag,"curcuit now closed. checkPointCount "..checkPointCount)
        nextCheckPointToBePassed = 0
      end
    end
    M.onCheckPointPassed(cpNumber)
  end
end

-- gets called when a checkpoint gets passed. takes the time and updates the checkpoint indices
local function onCheckPointPassed(index)
  --dump("onCheckPointPassed")
  if index == nextCheckPointToBePassed then
    -- log('E',logTag,"Passed checkPoint "..index)
    --times[currentLap][currentCP]['current'] = false;

    local finishedRound = false
    if index == 0 then
      -- lapped!
      currentLap = currentLap+1
      currentCP = 1
      justLapped = true
    else
      currentCP = currentCP+1
      justPassedCPWithinLap = true
    end

    nextCheckPointToBePassed = nextCheckPointToBePassed + 1

    if closed then
      -- wrap index
      nextCheckPointToBePassed = nextCheckPointToBePassed%checkPointCount

      --position marker and next marker, if more than one checkpoint
      M.positionMarkers()
    end
  end
end

--------------------------------------------------------------------
-- periodically called functions for rendering stuff,
-- updating the times, sending those to the app,
-- also formatting the times into a format usable by the app
--------------------------------------------------------------------

local function onUpdate()
  --dump(scenario.state)
  if not be:getEnabled() then
    if pausedStart == 0 then
      pausedStart = os.clock()*1000
      guihooks.trigger("HotlappingTimerPause")
    end
    currentPauseTime = os.clock()*1000 - pausedStart
  end

  if started and be:getEnabled() then
    if currentPauseTime > 0 then
      totalPauseTime = totalPauseTime + currentPauseTime
      currentPauseTime = 0
      pausedStart = 0
      forceSendToGui = true
      justStarted = true
    end
    if useCustomTimerFunc then
      totalTime = useCustomTimerFunc()
    else
      if not useScenarioTimer or not scenario_scenarios.getScenario().timer  then
        totalTime = (os.clock()*1000 - startTime) - totalPauseTime
      else
        totalTime = scenario_scenarios.getScenario().timer*1000
      end
    end
    M.setTime()
    M.passTimeToGUI()

    justStarted = false
    justPassedCPWithinLap = false
    justLapped = false
  end

  -- rendering stuff
  if closed and scenetree.hotlappingMarker then
    local camPos = getCameraPosition()
    local nextIndex = nextCheckPointToBePassed+1
    local overNextIndex = ((nextIndex)%checkPointCount)+1

    local camdistSqt = vec3(checkPointPosAndSize[nextIndex].position):squaredDistance(camPos)
    local markerAlpha = camdistSqt / 2000
    if markerAlpha > 1 then markerAlpha = 1 end
    scenetree.hotlappingMarker.instanceColor = ColorF( 1, 0.07, 0, markerAlpha * 0.9 + 0.1):asLinear4F()
    scenetree.hotlappingMarker:updateInstanceRenderData()
    scenetree['markerBase'..nextIndex].instanceColor = ColorF( 1, 1, 1, markerAlpha/2 + 0.5):asLinear4F()
    scenetree['markerBase'..nextIndex]:updateInstanceRenderData()

    if checkPointCount > 1 then
      local camdistSqt = vec3(checkPointPosAndSize[overNextIndex].position):squaredDistance(camPos)
      local markerAlpha = camdistSqt / 2000
      if markerAlpha > 1 then markerAlpha = 1 end
      scenetree.hotlappingMarkerNext.instanceColor = ColorF( 0.5,0.5,0.5, markerAlpha * 0.9 + 0.1):asLinear4F()
      scenetree.hotlappingMarkerNext:updateInstanceRenderData()
      scenetree['markerBase'..overNextIndex].instanceColor = ColorF( 1,1,1, markerAlpha/2 + 0.5):asLinear4F()
      scenetree['markerBase'..overNextIndex]:updateInstanceRenderData()
    end
  end

  lastRealMillis = os.clock()*1000
end

local function passTimeToGUI()
  local dt = os.clock()*1000 - lastRealMillis
  local info = M.getTimeInfo()
  info.stop = justPassedCPWithinLap
  info.justLapped = justLapped
  info.delta = dt
  info.closed = closed
  info.running = started
  info.justStarted = justStarted
  --dump(info.justLapped)
  if info.stop or info.justLapped or forceSendToGui then
    guihooks.trigger("HotlappingTimer", info)
  end
  forceSendToGui = false
end

local function setEndTime()
  -- adjust data for current lap and cp.
  times[currentLap][currentCP]['endTime'] = totalTime
  times[currentLap][currentCP]['duration'] = times[currentLap][currentCP]['endTime'] - times[currentLap][currentCP]['startTime']
  times[currentLap][currentCP]['current'] = false
  times[currentLap]['endTime'] = totalTime
  times[currentLap]['duration'] = times[currentLap]['endTime'] - times[currentLap]['startTime']

  -- after first lap, and if there is a best lap, calc diff for this lap vs best lap.
  -- also calc lap curation until current cp for this lap and best lap, store diff in cp record.
  if currentLap > 1 and bestLapIndex ~= -1 then
    times[currentLap]['diff'] = times[currentLap]['duration'] - times[bestLapIndex]['duration']
    local bestLapDurationUntilThisCP = times[bestLapIndex][currentCP]['endTime'] - times[bestLapIndex]['startTime']
    local currentLapDurationUntilThisCP = times[currentLap][currentCP]['endTime'] - times[currentLap]['startTime']
    times[currentLap][currentCP]['diff'] = currentLapDurationUntilThisCP - bestLapDurationUntilThisCP
  end

  -- after lapping and at least second lap, without having skipped this or the previous lap,
  -- check if just completed lap is better than the best lap and adjust if needed.
  if currentLap>1 and not times[currentLap]['skipped']  then
    if bestLapIndex == -1 then
      bestLapIndex = currentLap
    elseif times[currentLap]['duration'] < times[bestLapIndex]['duration']  then
      bestLapIndex = currentLap
    end
  end
end

-- saves the time, diffs and so on
local function setTime(ignoreNewLap)
  local act = false

  -- create new lap record if not existing.
  if times[currentLap] == nil then
    times[currentLap] = {}
    times[currentLap]['startTime'] = totalTime
    times[currentLap]['lap'] = currentLap
    act = true
    -- adjust diff from best lap
    if currentLap > 2 and bestLapIndex ~= -1 then
      times[currentLap-1]['diff'] = times[currentLap-1]['duration'] - times[bestLapIndex]['duration']
    end
    --set end time for previous lap, if it was not skipped.
    if currentLap > 1 and not times[currentLap-1]['skipped'] then
      times[currentLap-1]['endTime'] = totalTime
      times[currentLap-1]['duration'] = times[currentLap-1]['endTime'] - times[currentLap-1]['startTime']
    end
  end

  -- create new cp record if not existing.
  if times[currentLap][currentCP] == nil then
    times[currentLap][currentCP] = {}
    times[currentLap][currentCP]['startTime'] = totalTime
    times[currentLap][currentCP]['cp'] = currentCP
    act = true

    -- after changing checkpoint, adjust endTime, duration and diff for previous checkpoint.
    -- figure out which cp and lap to change.
    local lapToChange = currentLap
    local cpToChange = currentCP-1
    if currentCP == 1 then
      lapToChange = currentLap-1
      if lapToChange >= 1 then
        cpToChange = #times[lapToChange]
      end
    end
    -- if the lap to change is valid, change endTime and Duration. also adjust cp diff to best lap.
    if lapToChange >= 1 and not times[lapToChange]['skipped'] then
      times[lapToChange][cpToChange]['endTime'] = totalTime
      times[lapToChange][cpToChange]['duration'] = times[lapToChange][cpToChange]['endTime'] - times[lapToChange][cpToChange]['startTime']
      if bestLapIndex ~= -1 then
        times[lapToChange]['diff'] = times[lapToChange]['duration'] - times[bestLapIndex]['duration']
        local bestLapDurationUntilCP = times[bestLapIndex][cpToChange]['endTime'] - times[bestLapIndex]['startTime']
        local currentLapDurationUntilCP = times[lapToChange][cpToChange]['endTime'] - times[lapToChange]['startTime']
        times[lapToChange][cpToChange]['diff'] = currentLapDurationUntilCP - bestLapDurationUntilCP
      end
    end
  end

  -- adjust data for current lap and cp.
  times[currentLap][currentCP]['endTime'] = totalTime
  times[currentLap][currentCP]['duration'] = times[currentLap][currentCP]['endTime'] - times[currentLap][currentCP]['startTime']
  times[currentLap][currentCP]['current'] = true
  times[currentLap]['endTime'] = totalTime
  times[currentLap]['duration'] = times[currentLap]['endTime'] - times[currentLap]['startTime']

  -- only compare laps if not branching
  if not isBranchingScenario then
    -- after first lap, and if there is a best lap, calc diff for this lap vs best lap.
    -- also calc lap curation until current cp for this lap and best lap, store diff in cp record.
    if currentLap > 1 and bestLapIndex ~= -1 then
      times[currentLap]['diff'] = times[currentLap]['duration'] - times[bestLapIndex]['duration']
      local bestLapDurationUntilThisCP = times[bestLapIndex][currentCP]['endTime'] - times[bestLapIndex]['startTime']
      local currentLapDurationUntilThisCP = times[currentLap][currentCP]['endTime'] - times[currentLap]['startTime']
      times[currentLap][currentCP]['diff'] = currentLapDurationUntilThisCP - bestLapDurationUntilThisCP
    end

    -- after lapping and at least second lap, without having skipped this or the previous lap,
    -- check if just completed lap is better than the best lap and adjust if needed.
    if justLapped and currentLap>1 and not times[currentLap]['skipped'] and not times[currentLap-1]['skipped']  then
      if bestLapIndex == -1 then
        bestLapIndex = currentLap-1
      elseif times[currentLap-1]['duration'] < times[bestLapIndex]['duration']  then
        bestLapIndex = currentLap-1
      end
    end
  end

   -- if act then
   --     dump(times)
  --  end
end

local function getTimeInfoRaw( )
  return times
end

-- gets the full time info for a certain index
local retNormal = {}
local retDetail = {}
local function getTimeInfo( )
  local i = 0
  table.clear(retNormal)
  table.clear(retDetail)
  for lapIndex,lapValue in ipairs(times) do

    -- normal times
    retNormal[lapIndex] = {}
    retNormal[lapIndex].lap = lapIndex
    retNormal[lapIndex].total = M.formatMillis(lapValue['endTime'])
    retNormal[lapIndex].duration = M.formatMillis(lapValue['duration'])
    retNormal[lapIndex].durationMillis = lapValue['duration']
    retNormal[lapIndex].durationStyle = ''
    if lapValue['skipped'] then
      retNormal[lapIndex].durationStyle = retNormal[lapIndex].durationStyle ..'text-decoration:line-through; '
    end
    if lapIndex == bestLapIndex then
      retNormal[lapIndex].durationStyle = retNormal[lapIndex].durationStyle ..'font-weight:bold; '
      retNormal[lapIndex].best = true
    end
    if lapValue['diff'] or lapValue['skipped'] then
      if lapValue['skipped'] then
        retNormal[lapIndex].diff = 'Skipped'
      else
        if not isBranchingScenario then
          if lapIndex == currentLap and justPassedCPWithinLap then
            retNormal[lapIndex].diff = M.formatMillis(lapValue[#lapValue-1]['diff'],true)
            retNormal[lapIndex].diffColor = M.getDiffColor(lapValue[#lapValue-1]['diff'])
          end

          if lapIndex ~= currentLap or not started then
            retNormal[lapIndex].diff = M.formatMillis(lapValue['diff'],true)
            retNormal[lapIndex].diffColor = M.getDiffColor(lapValue['diff'])
          end
        end
      end
    end

    -- detail times
    i = i + 1
    -- first, all sections
    for cpIndex,cpValue in ipairs(times[lapIndex]) do
      retDetail[i] = {}
      retDetail[i].lap = lapIndex ..'-'.. cpIndex
      retDetail[i].duration = M.formatMillis(cpValue['duration'])
      retDetail[i].durationMillis = cpValue['duration']
      retDetail[i].total = M.formatMillis(cpValue['endTime'])
      retDetail[i].durationStyle = 'text-align:center; '
      retDetail[i].isSection = true
      retDetail[i].isLap = false

      if lapValue['skipped'] then
        retDetail[i].durationStyle = retDetail[i].durationStyle ..'text-decoration:line-through; '
      end
      if lapIndex == bestLapIndex then
        retDetail[i].durationStyle = retDetail[i].durationStyle ..'font-weight:bold; '
      end
      if cpValue['diff'] or lapValue['skipped'] then
        if lapValue['skipped'] then
          retDetail[i].diff = 'Skipped'
        else
          retDetail[i].diff = M.formatMillis(cpValue['diff'], true)
          retDetail[i].diffColor = M.getDiffColor(cpValue['diff'])
        end
      end
      i = i + 1
    end

    -- previous laps. include all sections with diffs, then summary of the lap
    retDetail[i] = {}
    retDetail[i].lap = lapIndex
    retDetail[i].duration = M.formatMillis(lapValue['duration'])
    retDetail[i].durationStyle = 'text-align:left; '
    retDetail[i].isSection = false
    retDetail[i].isLap = true
    if lapValue['skipped'] then
      retDetail[i].durationStyle = retDetail[i].durationStyle ..'text-decoration:line-through; '
    end
    if lapIndex == bestLapIndex then
      retDetail[i].durationStyle = retDetail[i].durationStyle ..'font-weight:bold; '
    end
    if lapValue['diff'] or lapValue['skipped']  then
      if lapValue['skipped'] then
        retDetail[i].diff = 'Skipped'
      else
        retDetail[i].diff = M.formatMillis(lapValue['diff'], true)
        retDetail[i].diffColor = M.getDiffColor(lapValue['diff'])
      end
    end
  end

  return {normal = retNormal, detail = retDetail}
end

-- formats the time given nicely.
local function formatMillis( timeInMillis, addSign )
  if timeInMillis == nil then
    return nil
  end

  if addSign then
    if timeInMillis >= 0 then
      return '+' .. M.formatMillis(timeInMillis,false)
    else
      return '-' .. M.formatMillis(-timeInMillis,false)
    end
  else
    timeInMillis = math.floor(timeInMillis+ .5)
    return string.format("%.2d:%.2d.%.3d", (timeInMillis/1000)/60, (timeInMillis/1000)%60, timeInMillis%1000)
  end
end

-- gets the diff color of a diff
local function getDiffColor( val )
  if val > 0 then
    return 'red'
  elseif val < 0 then
    return 'green'
  else
    return ''
  end
end

--------------------------------------------------------------------
-- loading and saving of tracks,
-- changing size of the checkpoints
--------------------------------------------------------------------

-- restores the track from the given file
local function load( originalFilename )
  local filename = 'settings/hotlapping/'.. M.getCurrentTrackName()..'/'..originalFilename..'.json'
  --dump(filename)
  --log('E',logTag,'loading file '..filename..' ...')
  if FS:fileExists(filename) then
    local data = jsonReadFile(filename)
    if not data or #data == 0 then
      log('I', logTag, 'No checkpoints found in file Documents/BeamNG.drive/'..filename)
      return
    end

    M.clearAllCP()
    M.startHotlapping()
    M.clearAllCP()
    TorqueScript.eval(markerTS)
    allowPlacingCP = true
    started = false
    checkPointPosAndSize = {}
    checkPointIndex = 0

    checkPointCount = 0
    nextCheckPointToBePassed = 0
    times = {}
    closed = true

    for k, v in ipairs(data) do
      M.addCheckPoint(vec3(v.position[1],v.position[2],v.position[3]),vec3(v.size[1],v.size[2],v.size[3]))
    end
    log('I',logTag,'Loaded '..#checkPointPosAndSize..' checkpoints from file Documents/BeamNG.drive/'..filename)
    M.positionMarkers()
    guihooks.trigger('HotlappingSuccessfullyLoaded', originalFilename)
  else
    log('I',logTag,'Could not find file Documents/BeamNG.drive/'..filename)
  end
end

-- saves the positions of the current checkpoints to the given file
local function save( filename )
  --log('E',logTag,'saving to file '..filename..' ...')
  if #checkPointPosAndSize == 0 then
      log('I',logTag,'Could not serialize course: No checkpoints there!')
      return
  end
  local date = os.date("*t")
  local now = string.format("%.4d-%.2d-%.2d_%.2d-%.2d-%.2d", date.year,date.month,date.day, date.hour,date.min,date.sec)
  fn = M.getCurrentTrackName()
  filename = 'settings/hotlapping/'..fn..'/'..now..'.json'
  jsonWriteFile(filename,checkPointPosAndSize, false)
  log('I',logTag,'Serialized '..#checkPointPosAndSize..' checkpoints to file Documents/BeamNG.drive/'..filename)
  guihooks.trigger('HotlappingSuccessfullySaved', now)
  M.refreshTracklist()
end

-- renames a file
local function rename( oldName, newName )
  --log('E',logTag,'saving to file '..filename..' ...')
  local pre = 'settings/hotlapping/' .. M.getCurrentTrackName() ..'/'
  if not FS:fileExists(pre..oldName..'.json') then
      log('I',logTag,'Failed renaming '..oldName..' to '..newName..': File not found')
      return
  end
  FS:renameFile(pre..oldName..'.json', pre..newName..'.json')
  FS:removeFile(pre..oldName..'.json')
end

-- get the name of the current track, without extension
local function getCurrentTrackName()
    local missionFile = getMissionFilename()
    local _, fn, e = path.split(missionFile)
    fn = fn:sub(1,#fn - #e - 1)
    return fn
end

-- changes the size of all checkpoints, according to first parameter( +1 / -1)
local function changeSize( sign, all )
  if all then
    if sign > 0 then
      size = size + 0.1
    elseif sign < 0 then
      size = size - 0.1
    else
      size = 2
    end
    size = clamp(size, 1, 5)
    -- change all CP sizes
    local i = 1
    for k, v in pairs(checkPoints) do
      v:setScale(vec3(4 * size, 4 * size, 8))
      scenetree['markerBase'..i]:setScale(vec3(6.8 * size, 6.8 * size, 7))
      i = i+1
    end
  else
    -- change on CP size
    --deactivated for now
  end
end

-- reloads the list of all available tracks, sends those to the app
local function refreshTracklist(  )
  local tracks = {}
  local fn = M.getCurrentTrackName()
  local trackfiles = FS:findFiles('settings/hotlapping/'..M.getCurrentTrackName()..'/','*.json',-1,true,false)
  for i, file in ipairs(trackfiles) do
      local _, fn, e = path.split(file)
      tracks[i] = fn:sub(1,#fn - #e - 1)
  end

  --dump(tracks)
  return tracks
end

-- resets the app on level load
local function onClientStartMission( )
  M.stopTimer()
  M.stopHotlapping()
  guihooks.trigger("HotlappingResetApp")
end

local function onClientEndMission()
  M.stopTimer()
  if not scenetree then
    checkPoints = {}
  end
  M.stopHotlapping()
end

local function  onExtensionUnloaded()
  M.stopTimer()
  if not scenetree then
    checkPoints = {}
  end
  M.stopHotlapping()
end

--------------------------------------------------------------------
-- New Race System hooks
--------------------------------------------------------------------

local function newRaceStart(race)
  M.start()
  closed = true
  times = {}
  nextCheckPointToBePassed = 1
  currentLap = 1
  useCustomTimerFunc = function() return race.time*1000 end
  checkPointCount = #(race.path.pathnodes)-1
  forceSendToGui = true
  started = true
  isBranchingScenario = race.path.config.branching
  if isBranchingScenario then
    log('I',logTag,'This race has branches. Lap and Checkpoint comparisons will be disabled.')
  end
end

local function newRacePathnodeReached(state, info)
  if state.complete then -- end raced
    started = false
    totalTime = useCustomTimerFunc()
    M.setEndTime()
    justPassedCPWithinLap = true
    justLapped = true
    M.passTimeToGUI()
  else
    if info.lapped then
        -- lapped!
        currentLap = currentLap+1
        currentCP = 1
        justLapped = true
        nextCheckPointToBePassed = 0
    else
        currentCP = currentCP+1
        justPassedCPWithinLap = true
    end
    nextCheckPointToBePassed = nextCheckPointToBePassed +1
    totalTime = useCustomTimerFunc()
    M.setTime()
  end
end
M.newRaceStart = newRaceStart
M.newRacePathnodeReached = newRacePathnodeReached

M.newRaceStop = function()
  started = false
end

--------------------------------------------------------------------
-- Old Race scenario hooks
--------------------------------------------------------------------

local function onRaceStart( )
  --log('D',logTag,'onRaceStart')
  useCustomTimerFunc = nil
  M.start()
  closed = true
  times = {}
  nextCheckPointToBePassed = 1
  currentLap = 1
  useScenarioTimer = true
  checkPointCount = #(scenario_scenarios.getScenario().lapConfig)
  forceSendToGui = true
  started = true
  isBranchingScenario = scenario_scenarios.getScenario().lapConfigBranches ~= nil
  if isBranchingScenario then
    log('I',logTag,'This race has branches. Lap and Checkpoint comparisons will be disabled.')
  end
end

local function onRaceWaypointReached( wpInfo )

 --[[ local prevTimes = 0

  if currentLap > 1 then
    for i = 1, currentLap-1 do
      prevTimes = prevTimes + times[i]["duration"]
    end
  end


  --times[currentLap][currentCP]["endTime"] = wpInfo.time
  --times[currentLap]["duration"] = wpInfo.time - prevTimes
    ]]
 --   totalTime = wpInfo.time
  if not wpInfo.next then -- end raced
    started = false
    totalTime = scenario_scenarios.getScenario().timer*1000
    M.setEndTime()
    justPassedCPWithinLap = true
    justLapped = true

    M.passTimeToGUI()
  else
    if wpInfo.lapDiff and wpInfo.lapDiff == 1 then
        -- lapped!

        currentLap = currentLap+1
        currentCP = 1
        justLapped = true
        nextCheckPointToBePassed = 0
    else
        currentCP = currentCP+1
        justPassedCPWithinLap = true

        --highscores.setScenarioHighscores(times[currentLap]["duration"],"vehicleName","playerName","eca","track","reverse",0)
    end
    nextCheckPointToBePassed = nextCheckPointToBePassed +1

    totalTime = scenario_scenarios.getScenario().timer*1000

    M.setTime()
  end
end

local function onRaceResult( final)
  local scenario = scenario_scenarios.getScenario()
  started = false
  scenario.detailedTimes = M.getTimeInfo()
end

--------------------------------------------------------------------
-- public interface
--------------------------------------------------------------------

M.startHotlapping = startHotlapping
M.stopHotlapping = stopHotlapping

M.start = start
M.skipLap = skipLap

M.startAi = startAi
M.stopAi = stopAi

M.addCheckPoint = addCheckPoint
M.positionMarkers = positionMarkers
M.setVisible = setVisible

M.onBeamNGTrigger = onBeamNGTrigger
M.onCheckPointPassed = onCheckPointPassed

M.getTimeInfoRaw = getTimeInfoRaw

M.onUpdate = onUpdate
M.setTime  = setTime
M.setEndTime = setEndTime

M.passTimeToGUI = passTimeToGUI
M.getTimeInfo = getTimeInfo
M.formatMillis = formatMillis
M.getDiffColor = getDiffColor

M.clearAllCP = clearAllCP
M.stopTimer = stopTimer

M.load = load
M.save = save
M.rename = rename

M.getCurrentTrackName = getCurrentTrackName
M.changeSize = changeSize
M.refreshTracklist = refreshTracklist

M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onExtensionUnloaded = onExtensionUnloaded

-- Race Interface
M.onRaceStart = onRaceStart
M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceResult = onRaceResult

return M
