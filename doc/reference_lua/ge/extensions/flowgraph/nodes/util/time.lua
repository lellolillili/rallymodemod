-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Time'
C.description = "Gets the current time."
C.category = 'provider'

C.pinSchema = {
    { dir = 'out', type = 'number', name = 'time', description = 'Time since start of project.' },
    { dir = 'out', type = 'number', name = 'dtReal', description = "Real time that elapsed between frames, ignoring pause. In seconds" },
    { dir = 'out', type = 'number', name = 'dtSim', description = "Simulation elapsed time, will be 0 when the game is paused, or scaled down if slow-motion is activated. In seconds" }
}

C.tags = {"delta"}

function C:init(mgr, ...)
end

function C:work()
  self.pinOut.time.value = getTime()
  self.pinOut.dtReal.value = self.mgr.dtReal
  self.pinOut.dtSim.value = self.mgr.dtSim
end

function C:drawMiddle(builder, style)
end


return _flowgraph_createNode(C)
