-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init()
  self.path = nil
  self.vehIds = {}
  self.states = {}
  self.recoveryStates = {}
  self.time = 0
  self.lapCount = 1
  self.started = false
  self.useHotlappingApp = true
  self.useDebugDraw = false
  self.useWaypointAudio = true
  self.sortPlacements = function (a, b)
    -- sorts by descending lap, then descending index, then ascending distance to next waypoint
    if a.lap == b.lap then
      if a.wpIdx == b.wpIdx then
        return a.dist < b.dist
      else
        return a.wpIdx > b.wpIdx
      end
    else
      return a.lap > b.lap
    end
  end
end

function C:setPathFile(file)
  if not file then return end
  local json = readJsonFile(file)
  if not json then
    log('E', 'race', 'unable to find race file: ' .. tostring(file))
    return
  end
  local path = require('/lua/ge/extensions/gameplay/race/path')("New Race")
  path:onDeserialized(json)
  self:setPath(path)
end

function C:calcAIPath()
  --dump("Making AI Path")
  self.aiPath = self.path:getAiPath(true)


end

function C:setPath(path)
  self.path = path
  self.path:autoConfig()
  self:calcAIPath()
end

function C:setVehicleIds(ids)
  self.vehIds = ids
  self.states = {}
  self.recoveryStates = {}
  for _, id in ipairs(ids) do
    self.states[id] = {}
    self.recoveryStates[id] = {}
  end
end

function C:getPlacementData(id)

end

local sorted = {}
function C:getPlacements()
  if tableSize(self.states) == 1 then
    self.states[next(self.states)].placement = 1
    return
  end

  local completedCount = 0
  local sortedNextIndex = 1
  for id, data in pairs(self.states) do
    if data.complete then
      completedCount = completedCount + 1
    else
      local lap = data.currentLap
      local segName = data.currentSegments[1]
      local wpIdx = math.huge
      local bestDist = 0

      if segName then
        wpIdx = self.path.config.graph[segName].linearCPIndex

        local nPos = self.path.pathnodes.objects[self.path.config.graph[segName].targetNode].pos
        bestDist = math.huge

        for _, corner in ipairs(data.currentCorners) do
          local dist = corner:squaredDistance(nPos)
          if dist < bestDist then
            bestDist = dist
          end
        end
      end
      if not sorted[sortedNextIndex] then
        sorted[sortedNextIndex] = {}
      end
      sorted[sortedNextIndex].id = id
      sorted[sortedNextIndex].lap = lap
      sorted[sortedNextIndex].wpIdx = wpIdx
      sorted[sortedNextIndex].dist = bestDist
      sortedNextIndex = sortedNextIndex + 1
    end
  end

  -- Cut the array down if the size has shrunk
  if sortedNextIndex-1 < #sorted then
    for i=sortedNextIndex, #sorted do
      sorted[i] = nil
    end
  end

  if sorted[2] then
    table.sort(sorted, self.sortPlacements)
  end

  for i, v in ipairs(sorted) do
    self.states[v.id].placement = i + completedCount
  end
end

function C:onUpdate(dt)
  if not self.started then return end

  for _, id in ipairs(self.vehIds) do

    if self.time > 0 then
      self:clearEvents(id)
    end

    if self.states[id].requestRecover then
      self:handleRecover(id)
    end
    if self.states[id].active then
      if not self.suspended then
        self:updateVehicle(id, dt)
      end
      if self.useDebugDraw then
        self:drawDebug(id)
      end
      self:digestEvents(id)

    end
  end
  if not self.suspended then
    if not self.path.branching and next(self.states) then
      self:getPlacements()
    end
    self.time = self.time + dt
  end
end

function C:doSuspend(sus)
  self.suspended = sus
  if self.useHotlappingApp then
    if sus then
      guihooks.trigger('HotlappingTimerPause')
    else
      guihooks.trigger('HotlappingTimerUnpause')
    end
  end

end

function C:startRace()
  self.started = true
  self.time = 0
  for _, id in ipairs(self.vehIds) do
    self.recoveryStates[id] = {}
    self.states[id] = {
      waitingForRollingStart = self.path.config.rollingStart, -- if we are not started yet, but wait for reachng the first CP.
      active = true, -- if this vehicle is currently racing.
      currentSegments = {}, -- the segments the vehicle is currently in.
      completedPacenotes = {}, --  all the pacenotes that have been triggered
      currentLap = 0, -- current lap
      currentTimes = {}, -- times (with begin/end/duration) for the current lap
      currentHistory = {}, -- segments for the current lap
      historicTimes = {}, -- all the times so far.
      historicSegments = {}, -- all the segments reached so far.
      bestLapTime = {},
      nextPathnodes = {}, -- currently reachable pathnodes
      overNextPathnodes = {}, -- all pathnodes reachable after the next ones.
      nonBranchingShiftedPathnodes = {}, -- all future pathnodes, if the path is not branching. loops around back to the player
      events = {},
      eventLog = {},
      placement = 0,
      startTime = 0,
      endTime = 0,
      reverse = self.path.config.reverse,
      recoveriesUsed = 0
    }
    self.states[id].events.raceStarted = true
    if not self.path.config.rollingStart then
      self.states[id].currentSegments = self.path.config.startSegments
    else
      self.states[id].currentSegments = {}
    end

    local vehicle = be:getObjectByID(id)
    self.states[id].wheelOffsets = {}
    self.states[id].currentCorners = {}
    self.states[id].previousCorners = {}
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
        table.insert(self.states[id].wheelOffsets, pos)
        table.insert(self.states[id].currentCorners, vRot*pos + vehiclePos)
        table.insert(self.states[id].previousCorners, vRot*pos + vehiclePos)
      end
    end

    --self.states[id].insideSegments = self.path.config.startSegments
    self:findNextPathnodes(id)
  end
  if self.useHotlappingApp then
    -- load hotlapping for the hotlapping app.
    if not core_hotlapping then
      extensions.load({'core_hotlapping'})
      guihooks.trigger('setQuickRaceMode')
      guihooks.trigger("HotlappingResetApp")
    end
  end
end

function C:stopRace()
  self.started = false
end

-- this should probably be improved at some point
function C:getVehiclePosition(id)
  local veh = scenetree.findObjectById(id)
  if veh then
    return veh:getPosition()
  else
    if map and map.objects[id] then
      return map.objects[id].pos
    end
  end
  log("E","","No Vehicle position found! " .. id)
  return vec3()
end

function C:abortRace(id)
  local state = self.states[id]
  if state.complete or not state.active then return end
  state.currentSegments = {}
  state.active = false
  state.events.raceAborted = true
  state.endTime = self.time
end

function C:createRecoveryPoint(id, recovery)
  table.insert(self.recoveryStates[id], {
    state = deepcopy(self.states[id]),
    time = self.time,
    recovery = recovery}
    )
end

function C:hasRecoveryPosition(id)
  if not self.recoveryStates[id][#self.recoveryStates[id]] then
    return false
  end
  return true
end

-- returns only true if a recovery state exists
function C:requestRecover(id)
  if not self:hasRecoveryPosition(id) then return false end
  self.states[id].requestRecover = true
  return true
end

function C:handleRecover(id)
  local snap = self.recoveryStates[id][#self.recoveryStates[id]]
  self.states[id] = deepcopy(snap.state)
  if self.recoverAffectsTotalTime then
    self.time = snap.time
  end
  self.states[id].events.recovered = #self.recoveryStates
  snap.recovery:moveResetVehicleTo(id)
  local veh = scenetree.findObjectById(id)
  veh:resetBrokenFlexMesh()
  veh:queueLuaCommand('recovery.recoverInPlace()')
end

function C:completeLap(id, endTime)
  local state = self.states[id]
  table.insert(state.historicSegments, state.currentHistory)
  local timeInfo = {
    lap = state.currentLap,
    beginTime = state.currentTimes[1].beginTime,
    endTime = endTime,
    segmentTimes = state.currentTimes
  }
  timeInfo.duration = timeInfo.endTime - timeInfo.beginTime

  table.insert(state.historicTimes, timeInfo)

  state.currentTimes = {}
  state.currentHistory = {}
  state.currentLap = state.currentLap+1
  if state.currentLap < self.lapCount then
    state.currentSegments = self.path.config.startSegments
    state.events.lapComplete = true
    state.completedPacenotes = {}
  else
    state.currentSegments = {}
    state.complete = true
    state.active = false
    state.events.raceComplete = true
    state.endTime = endTime
    local veh = scenetree.findObjectById(id) or {partConfig = "None?!", JBeam = "None!?"}
    local simpleInfo = {
      totalTime = state.endTime,
      totalTimeFormatted = self:raceTime(state.endTime),
      vehConfig = veh.partConfig,
      vehModel = veh.JBeam,
      lapTimes = {},
      lapTimesFormatted = {}
    }
    for _, l in ipairs(state.historicTimes) do
      table.insert(simpleInfo.lapTimes, l.duration)
      table.insert(simpleInfo.lapTimesFormatted, self:raceTime(l.duration))
    end
    --do
    --  local fullpath = "raceRecord/"..os.date("!%Y-%m-%d--%H-%M-%S")..(self.saveFileSuffix and ("-"..self.saveFileSuffix) or "").."/"
    --  jsonWriteFile(fullpath.."path.path.json",self.path:onSerialize(), true)
    --  jsonWriteFile(fullpath.."times.json",state.historicTimes, true)
    --  jsonWriteFile(fullpath.."simpleInfo.json",simpleInfo, true)
    --  log("I","","Written complete race history to "..fullpath)
    --end
  end
end

function C:findNextPathnodes(id)
  local state = self.states[id]
  table.clear(state.nextPathnodes)
  table.clear(state.overNextPathnodes)
  table.clear(state.nonBranchingShiftedPathnodes)
  local lastLap = state.currentLap == self.lapCount-1
  -- find all pathnodes at the end of the current segments and following segments
  local nextIdMap = {}
  local overNextIdMap = {}
  for _, curId in ipairs(state.currentSegments) do
    local elem = self.path.config.graph[curId]
    for _, n in ipairs(elem.nextVisibleSegments) do
      local tn = self.path.config.graph[n].targetNode
      if not nextIdMap[tn] then
        table.insert(state.nextPathnodes, {self.path.pathnodes.objects[tn], elem.overNextCrossesFinish})
        nextIdMap[tn] = true
      end
    end
    if not (elem.overNextCrossesFinish and lastLap) then
      for _, n in ipairs(elem.overNextVisibleSegments) do
        local tn = self.path.config.graph[n].targetNode
        if not overNextIdMap[tn] then
          table.insert(state.overNextPathnodes, {self.path.pathnodes.objects[tn]})
          overNextIdMap[tn] = true
        end
      end
    end
    -- only do this list if the race is completely linear (no branches)
    if not self.path.branching then
      local done = false
      local lastId = state.currentSegments[1]
      table.insert(state.nonBranchingShiftedPathnodes, state.currentSegments[1])
      -- stop alread if ths is the last segment in the last lap
      if lastLap and self.path.config.graph[lastId].overNextCrossesFinish then
        done = true
      end

      while not done do
        local last = self.path.config.graph[lastId]
        local nextIdx = last.overNextVisibleSegments[1]
        if not nextIdx then
          -- if there is no successor, stop here
          done = true
        elseif nextIdx == state.currentSegments[1] then
          -- stop if we reached the original segment.
          done = true
        else
          lastId = nextIdx
          table.insert(state.nonBranchingShiftedPathnodes, nextIdx)
          if lastLap and self.path.config.graph[nextIdx].overNextCrossesFinish then
            done = true
          end
        end
      end
    end
  end
  if state.waitingForRollingStart then
    local ssId = self.path.config.startSegments[1]
    local ss = self.path.segments.objects[ssId]
    table.insert(state.nextPathnodes, {ss:getFrom()})
  end

  if #state.nextPathnodes > 1 then
    for _, pn in ipairs(state.nextPathnodes) do
      pn[2] = 'branch'
    end
  else
    local pn = state.nextPathnodes[1]
    if pn then
      if not self.path.startPositions.objects[pn[1].recovery].missing then
        pn[2] = 'recovery' --lap color is used for recovery as well
      elseif pn[2] and lastLap then
        pn[2] = 'final'
      elseif pn[2] and not lastLap then
        pn[2] = 'lap'
      elseif state.waitingForRollingStart then
        pn[2] = 'start'
      else
        pn[2] = 'default'
      end
    end
  end

  -- sort lists for consistency
  table.sort(state.nextPathnodes, function(a,b) return a[1].sortOrder<b[1].sortOrder end)
  table.sort(state.overNextPathnodes, function(a,b) return a[1].sortOrder<b[1].sortOrder end)
end

function C:detectRollingStart(id, dt)
  local state = self.states[id]
  local pos = self:getVehiclePosition(id)
  local inside = {}
  table.clear(state.currentSegments)
  for _, segId in ipairs(self.path.config.startSegments) do
    local currentSegment = self.path.segments.objects[segId]
    local hit, t = currentSegment:contains(pos,state)
    inside[segId] = hit and t or nil
  end
  local t = math.huge
  for k, v in pairs(inside) do
    if v ~= nil then
      table.insert(state.currentSegments, k)
      t = math.min(t,v)
    end
  end
  state.startTime = self.time
  if #state.currentSegments > 0 then
    print("Rolling Started!")
    state.startTime = self.time + dt * t
    state.waitingForRollingStart = false
    state.events.rollingStarted = true
    self:findNextPathnodes(id)
  end
end

function C:updateVehicle(id, dt)
  local state = self.states[id]
  if state.complete then return end
  local vehicle = be:getObjectByID(id)
  if not vehicle then return end
    -- advance corners
  local vPos = vehicle:getPosition()
  local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
  for i, corner in ipairs(state.wheelOffsets) do
    state.previousCorners[i]:set(state.currentCorners[i])
    state.currentCorners[i]:set(vPos + vRot*corner)
    --debugDrawer:drawLine(vec3(state.previousCorners[i]), vec3(state.currentCorners[i]),  ColorF(1,0,0,1))
    --debugDrawer:drawSphere(vec3(state.currentCorners[i]), 0.025, ColorF(1,0,0,0.25))
  end

  if state.waitingForRollingStart then
    self:detectRollingStart(id, dt)
    return
  end
  self:handlePacenotes(id)
  -- figure out if we entered any next segments
  local pos = self:getVehiclePosition(id)
  --debugDrawer:drawSphere(pos, 0.125, ColorF(1,0,0,0.25))
  -- id of the segment we have completed (and then advance to its successors)
  local finishedSegmentId = -1
  local finishedSegmentT = 1
  -- if we have lapped in reaching a pathnode.
  local lapped = false

  -- go through all current segments. check if the segment is finished (reaching its end)
  for _,currentId in ipairs(state.currentSegments) do
    local currentSegment = self.path.config.graph[currentId]

    if currentSegment.lastInLap then
      -- is this element the last in lap?
      -- if we do, we can stop here.
      local segment = self.path.segments.objects[currentId]
      if segment:finished(pos, state) then
        finishedSegmentId = currentId
        lapped = true
      end
    else
      -- if we have at least one successor, we continue.
      for _, segId in ipairs(self.path.config.graph[currentId].successors) do
        local segment = self.path.segments.objects[segId]
        local hit, t = segment:contains(pos, state)

        if hit then
          finishedSegmentId = currentId
          finishedSegmentT = t
        end
      end
    end
  end
  -- if no segment is finished, we are done here.
  if finishedSegmentId == -1 then
    return
  end
  -- otherwise, record the advancement and set up next segments.

  -- add the segments we were in into the history.
  table.insert(state.currentHistory, state.currentSegments)
  local graphElem = self.path.config.graph[finishedSegmentId]
  local timeInfo = nil
  if self.path.pathnodes.objects[graphElem.targetNode].visible then
    -- create event that we reached a pathnode that was visible
    state.events.pathnodeReached = true
    state.events.pathnodeReachedId = self.path.segments.objects[finishedSegmentId]:getTo().id

    -- record time.
    timeInfo = {
      segment = finishedSegmentId,
      endTime = self.time + finishedSegmentT * dt
    }
    -- get correct startTime for this segment.
    if #state.currentTimes > 0 then
      timeInfo.beginTime = state.currentTimes[#state.currentTimes].endTime
    elseif #state.historicTimes > 0 then
      timeInfo.beginTime = state.historicTimes[#state.historicTimes].endTime
    else
      timeInfo.beginTime = state.startTime
    end
    timeInfo.duration = timeInfo.endTime - timeInfo.beginTime
    table.insert(state.currentTimes, timeInfo)
  end
  if lapped then
    -- complete lap if we have done so.
    self:completeLap(id, timeInfo.endTime)
  else
    -- otherwise set current segments to successors of completed segment.
    state.currentSegments = self.path.config.graph[finishedSegmentId].successors
  end

  -- find the next pathnodes (for displaying them)
  self:findNextPathnodes(id)

  -- check if we have reached a recovery point
  local rec = self.path.pathnodes.objects[graphElem.targetNode]:getRecovery()
  if not rec.missing then
    print("Reached Recovery")
    state.events.recoveryReached = rec
  end


end

function C:handlePacenotes(id)
  local state = self.states[id]
  if state.complete then return end

  for _, segId in ipairs(state.currentSegments) do
    local pnIds = self.path.config.segmentToPacenotes[segId]
    for _, pni in ipairs(pnIds) do
      if not state.completedPacenotes[pni] then
        local pn = self.path.pacenotes.objects[pni]
        if not pn.missing then
          if pn:intersectCorners(state.previousCorners, state.currentCorners) then
            state.events.pacenoteReached = true
            state.events.pacenoteIdReached = pni
            state.completedPacenotes[pni] = true
            return
          end
        end
      end
    end
  end

end

function C:digestEvents(id)
  local state = self.states[id]
  local events = state.events
  --digest hotlapping event exclusively
  if self.useHotlappingApp and core_hotlapping and id == be:getPlayerVehicleID(0) then -- assumes that the UI should only trigger for the player vehicle
    if events.raceStarted  then
      if state.waitingForRollingStart then
        guihooks.trigger('setQuickRaceMode')
        guihooks.trigger("HotlappingResetApp")
      else
        core_hotlapping.newRaceStart(self)
      end
    elseif events.rollingStarted then
      core_hotlapping.newRaceStart(self)
    elseif events.lapComplete then
      core_hotlapping.newRacePathnodeReached(state,{lapped = true})
    elseif events.pathnodeReached then
      core_hotlapping.newRacePathnodeReached(state,{lapped = false})
    elseif events.raceComplete then
      core_hotlapping.newRacePathnodeReached(state,nil)
    end
  end

  if events.raceStarted then
    table.insert(state.eventLog, {name = "Race Started.", time = self.time})
  end
  if events.pathnodeReached then
    table.insert(state.eventLog, {name = "Reached " .. self.path.pathnodes.objects[events.pathnodeReachedId].name ..".", time = self.time})
  end
  if events.lapComplete then
    table.insert(state.eventLog, {name = "Lap " .. state.currentLap.." Complete.", time = self.time})
  end
  if events.raceComplete then
    table.insert(state.eventLog, {name = "Race Complete!", time = self.time})
  end
  if events.raceAborted then
    table.insert(state.eventLog, {name = "Race Aborted.", time = self.time})
  end
  if events.rollingStarted then
    table.insert(state.eventLog, {name = "Rolling Started.", time = self.time})
  end
  if events.recovered then
    table.insert(state.eventLog, {name = 'Recovered', time = self.time})
    self.recoveryStates[id][events.recovered] = deepcopy(self.states[id])
    state.recoveriesUsed = state.recoveriesUsed + 1
    state.requestRecover = false
  end
  if events.recoveryReached then
    self:createRecoveryPoint(id, events.recoveryReached)
  end

  if self.useWaypointAudio and (events.rollingStarted or events.pathnodeReached or events.lapComplete or events.raceComplete) then
    Engine.Audio.playOnce('AudioGui', "event:UI_Checkpoint")
  end

  if events.pacenoteReached then
    table.insert(state.eventLog, {name = "Pacenote reached: " .. dumps(self.path.pacenotes.objects[events.pacenoteIdReached].note), time = self.time})
  end
end

function C:clearEvents(id)
  local state = self.states[id]
  local events = state.events
  table.clear(events)
end


------------- DEBUG AND IMGUI STUFF ---------------

function C:drawDebug(id)
  local state = self.states[id]
  for _, node in ipairs(state.nextPathnodes) do
    node[1]:drawDebug('simple', {1,0.16,0.08,1}, dumps(node[2]))
  end
  for _, node in ipairs(state.overNextPathnodes) do
    node[1]:drawDebug('simple', {0.91,0.64,0.1,1}, dumps(node[2]))
  end
  for _, segId in ipairs(state.currentSegments) do
    local pnIds = self.path.config.segmentToPacenotes[segId]
    for _, pni in ipairs(pnIds) do
      if not state.completedPacenotes[pni] then
        self.path.pacenotes.objects[pni]:drawDebug('simple')
      end
    end
  end

end

function C:inDrawEventlog(id, im)
  local eventLog = self.states[id].eventLog or {}
  local colWidth = im.CalcTextSize("99:99:999").x + 15 * im.uiscale[0]
  im.Text("Vehicle " .. id)
  im.Columns(2)
  im.SetColumnWidth(0,colWidth)
  im.Text("Time")
  im.NextColumn()
  im.Text("Event")
  im.NextColumn()
  im.Separator()
  if self.states[id].active then
    im.Text(self:raceTime(self.time))
    im.NextColumn()
    im.NextColumn()
  end
  for i = #eventLog, 1, -1 do
    local e = eventLog[i]
    im.Text(self:raceTime(e.time))
    im.NextColumn()
    im.Text(e.name)
    im.NextColumn()
  end
  im.Columns(1)
end

function C:inDrawTimes(id, im, detail)
  local state = self.states[id]
  local colWidth = im.CalcTextSize("Total 99").x + 15 * im.uiscale[0]
  local ret = false
  im.Columns(2)
  im.SetColumnWidth(0,colWidth)
  if editor and editor.icons then
    editor.uiIconImage(editor.icons.search, im.ImVec2(20, 20))
  else
    im.Text("Det")
  end
  if im.IsItemClicked(0) then
    ret = true
  end
  im.NextColumn()
  if state.complete then
    im.Text("Complete!")
  else
    im.Text("Lap " .. (state.currentLap+1) .."/".. self.lapCount )
  end
  im.NextColumn()
  im.Separator()
  if state.active then
    if self.lapCount > 1 then
      im.Text("Total")
      im.NextColumn()
      im.Text(self:raceTime(self.time - state.startTime))
      im.NextColumn()
    end

    local currentLapStart = state.currentLap == 0 and state.startTime or state.historicTimes[#state.historicTimes].endTime
    im.Text("Lap " .. (state.currentLap+1))
    im.NextColumn()
    im.Text(self:raceTime(self.time - currentLapStart))
    im.NextColumn()
  end
  if state.complete then
    im.Text("Total")
    im.NextColumn()
    im.Text(self:raceTime(state.endTime - state.startTime))
    im.NextColumn()
  end
  if detail then
    self:inDrawSegmentTimes(state.currentTimes, im, 'index', (state.currentLap+1) .. " - ")
    for i = #state.historicTimes, 1, -1 do
      self:inDrawLapTimes(state.historicTimes[i], im)
    end
  else
    for i = #state.historicTimes, 1, -1 do
      im.Text("Lap " .. (state.historicTimes[i].lap+1))
      im.NextColumn()
      im.Text(self:raceTime(state.historicTimes[i].duration))
      im.NextColumn()
    end
  end
  im.Columns(1)
  return ret
end


function C:inDrawSegmentTimes(sTimes, im, mode, prefix)
  mode = mode or "index"
  prefix = prefix or ""
  for i = #sTimes, 1, -1 do
    local seg = sTimes[i]
    local txt = ""
    if mode == 'names' then
      txt = self.path.segments.objects[seg.segment].name
    elseif mode == 'index' then
      txt = "" .. i
    elseif mode == 'id' then
      txt = seg.segment
    end
    im.Text(prefix .. txt)
    im.NextColumn()
    im.Text(self:raceTime(seg.duration))
    im.NextColumn()
  end
end

function C:inDrawLapTimes(lTimes, im)
  im.Text("Lap " ..(1+lTimes.lap) )
  im.NextColumn()
  im.Text(self:raceTime(lTimes.duration))
  im.NextColumn()
  self:inDrawSegmentTimes(lTimes.segmentTimes, im, "index", (1+lTimes.lap) .. " - ")
end

function C:raceTime(time)
  local minutes = math.floor(time/60)
  local seconds = math.floor(time - minutes*60)
  local millis = (time - minutes*60 - seconds)*1000
  return string.format("%02d:%02d.%03d",minutes, seconds, millis)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end