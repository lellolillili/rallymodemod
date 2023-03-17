-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Race Restarted'

C.description = "Checks if the race has been restarted."
C.category = 'logic'

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
    { dir = 'out', type = 'flow', name = 'restart', description = 'Outflow when the race is restarted.', impulse = true },
}


C.tags = {'input'}

function C:init(mgr, ...)
  self.restart = false
end

function C:_executionStarted()
  self.restart = false
end

function C:work()
  self.pinOut.restart.value = self.started
  self.restart = false
end

function C:onScenarioRestarted()
  self.restart = true
end

return _flowgraph_createNode(C)
