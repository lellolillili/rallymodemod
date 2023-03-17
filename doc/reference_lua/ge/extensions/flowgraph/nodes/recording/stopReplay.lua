-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Stop Replay'
C.description = 'Stop the current replay.'
C.category = 'repeat_instant'


function C:work()
  if core_replay.state.state == "playing" then
    core_replay.stop()
  end
end


return _flowgraph_createNode(C)
