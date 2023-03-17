-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Play Replay'
C.description = 'Plays a replay.'
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'string', name = 'filename', description = 'The prefix for the generated filename.'},
  {dir = 'in', type = 'flow', name = 'play', description = 'Plays the replay', impulse = true},
}

function C:work()
  if self.pinIn.play.value then
    local file, succ = self.mgr:getRelativeAbsolutePath({self.pinIn.filename.value})
    if succ then
      core_replay.loadFile(file)
    end
  end
end


return _flowgraph_createNode(C)
