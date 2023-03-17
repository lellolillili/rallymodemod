-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Timeline Replay'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.behaviour = { duration = true }
C.description = [[Plays a vehicle replay at a specific time.]]
C.todo = "Prototypical node, not working correctly in all cases"
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'string', name = 'filename', description = 'filename' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle to replay.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'rotation'}

function C:init()
  self:_setupTimeline(5,10)
  self.replayName = ""
end

function C:work()
  if self.startReplay then
    if self.replayName or self.pinIn.filename.value then
      core_replay.loadFile(self.mgr:getRelativeAbsolutePath(self.pinIn.filename.value or self.replayName))
      self.startReplay = false
    end
  end
  if self.stopReplay then
    core_replay.stop()
    self.stopReplay = false
  end
end

function C:_executionStopped()
  core_replay.stop()
end

function C:drawCustomProperties()
  local reason = nil
  if im.Button("Load Replays") then
    self.replays = core_replay.getRecordings()
  end
  if self.replays then
    if im.BeginCombo("##repl" .. self.id, self.replayName) then
    for _, t in ipairs(self.replays) do
      if im.Selectable1(t.filename, t.filename == self.replayName) then
        if t.filename ~= self.replayName then
          self.currentReplay = t
          self.replayName = t.filename
        end
      end
    end
    im.EndCombo()
  end

  end
  return reason
end

function C:onTimelineBegin(globalTime, localTime)
  self.startReplay = true

end

function C:onTimelineEnd(globalTime, localTime)
  self.stopReplay = true
end


function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.replayName)
  im.Text(tostring(self.startReplay))
  im.Text(tostring(self.stopReplay))
  --im.BeginChild1("child",im.ImVec2(self.sliderWidth[0],50), true)
end

return _flowgraph_createNode(C)
