-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'File Race'
C.description = 'Manages a Race from a given path.'
-- C.category = 'repeat_instant'
C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'idle', hidden = true, description = 'If this pin has flow, the race will not count the timer and not count as active.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'lapCount', default = 1, hardcoded = true, hidden = true, description = 'Number of laps (min 1).' },
  { dir = 'in', type = 'table', name = 'pathData', tableType = 'pathData', description = 'Path data' },
  { dir = 'in', type = 'bool', name = 'rolling', description = 'If the path should be with a rolling start, if possible.'},

  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
  { dir = 'out', type = 'table', name = 'raceData', tableType = 'raceData',  description = 'Data from the race for other nodes to process.' },
  { dir = 'out', type = 'table', name = 'aiPath', tableType = 'navgraphPath',  description = 'AI navgraph path; can be used with the Follow Waypoints node.' },
  { dir = 'out', type = 'flow', name = 'active', description = 'Outflow when race is active.' },
  { dir = 'out', type = 'flow', name = 'complete', description = 'Outflow when race is complete.' },
  { dir = 'out', type = 'number', name = 'time', description = 'Total time when completed.' }
}

C.tags = {'scenario'}

C.legacyPins = {
  _in = {
    vehID = 'vehId_1',
    vehId = 'vehId_1',
    vehID_1 = 'vehId_1'
  }
}

function C:init(mgr, ...)
  self.started = false
  self.race = nil
  self.count = 1
  self.data.useHotlappingApp = true
  self.data.useDebugDraw = false
  self.data.useWaypointAudio = true
end

function C:postInit()
  self:updatePins(0,self.count)
end

function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Vehicle Count")
  im.NextColumn()
  local ptr = im.IntPtr(self.count)
  if im.InputInt('##count'..self.id, ptr) then
    if ptr[0] < 1 then ptr[0] = 1 end
    self:updatePins(self.count, ptr[0])
    reason = "Changed Value count to " .. ptr[0]
  end

  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then
    for i = old, new+1, -1 do
      for _, lnk in pairs(self.graph.links) do
        if lnk.sourcePin == self.pinInLocal['vehId_'..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinInLocal['vehId_'..i])
    end
  else
    for i = old+1, new do
      self:createPin('in','number','vehId_'..i)
    end
  end
  self.count = new
end

function C:_onSerialize(res)
  res.count = self.count
end

function C:_onDeserialized(res)
  self.count = res.count or 1
  self:updatePins(1, self.count)
end
function C:_executionStarted()
  self.race = nil
  self.started = false
end

function C:_executionStopped()
  if self.race then self.race:stopRace() end
  self.race = nil
  self.started = false
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.started and "Started" or "Stopped")
end

function C:work(args)
  if self.pinIn.reset.value then
    self.started = false
    self.pinOut.flow.value = false
    self.pinOut.complete.value = false
  end
  if self.pinIn.flow.value then
    if not self.started then
      self.race = require('/lua/ge/extensions/gameplay/race/race')()
      self.race:setPath(self.pinIn.pathData.value)
      self.race.path.config.rollingStart = self.pinIn.rolling.value
      self.race.lapCount = self.pinIn.pathData.value.config.closed and math.max(self.pinIn.lapCount.value or 1, 1) or 1
      self.race.useHotlappingApp = self.data.useHotlappingApp
      self.race.useDebugDraw = self.data.useDebugDraw
      self.race.useWaypointAudio = self.data.useWaypointAudio

      if self.mgr.activity then
        self.race.saveFileSuffix = self.mgr.activity.id
      end
      local vids = {}
      for i = 1, self.count do
        if be:getObjectByID(self.pinIn['vehId_'..i].value) then
          table.insert(vids, self.pinIn['vehId_'..i].value)
        end
      end
      self.race:setVehicleIds(vids)
      self.race:startRace()
      self.started = true
    end
    if not self.race then return end
    if not self.pinIn.idle.value then
      self.race:onUpdate(self.mgr.dtSim)
    end
    self.pinOut.raceData.value = self.race
    self.pinOut.aiPath.value = self.race.aiPath
    self.pinOut.flow.value = self.pinIn.flow.value
    self.pinOut.complete.value = self.race.states[self.pinIn.vehId_1.value].complete or false
    if self.pinOut.complete.value then
      local state = self.race.states[self.pinIn.vehId_1.value]
      self.pinOut.time.value = state.historicTimes[#state.historicTimes].endTime
    end
    self.pinOut.active.value = self.race.states[self.pinIn.vehId_1.value].active
    if not self.pinOut.active.value and self.pinIn.idle.value ~= nil then
      self.pinOut.active.value = not self.pinIn.idle.value
    end
  end
end


return _flowgraph_createNode(C)
