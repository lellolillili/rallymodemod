-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Record Replay'
C.description = 'Records a replay of the current vehicle.'
C.category = 'repeat_f_duration'

C.todo = "Replay system currently has no way to select other vehicles i think"
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'start', description = 'Trigger to start the recording.', impulse = true},
  {dir = 'in', type = 'flow', name = 'stop', description = 'Trigger to stop the recording and save to file.', impulse = true},
  {dir = 'in', type = 'string', name = 'prefix', description = 'The prefix for the generated filename.'},
  {dir = 'out', type = 'string', name = 'filename', description = 'The complete generated filename.'},
}

C.tags = {}

function C:init()
  self.state = "none"
end

function C:_executionStarted()
  self:setDurationState('inactive')
end

function C:onReplayStateChanged(state)
  if state.state == 'recording' then
    self.pinOut.filename.value = state.loadedFile
  end
end

function C:saveFile()

  local fn = self.pinIn.prefix.value or ("Recording_"..self.id)
  fn = fn .. "--" .. ((#core_replay.getRecordings())+1)

end

function C:work()
  if self.durationState == 'inactive' then
    if self.pinIn.start.value then
      print("Starting recording!")
      core_replay.toggleRecording(false)
      self:setDurationState('started')
      return
    end
  end
  if self.durationState == 'started' then
    if self.pinIn.stop.value then
      print("Stopping Recording!")
      core_replay.toggleRecording(false)
      self:setDurationState('finished')
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.durationState)

end


return _flowgraph_createNode(C)
