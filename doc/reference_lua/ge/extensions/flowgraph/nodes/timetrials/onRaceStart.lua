-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Race Started'

C.description = "Checks if the race has started.."
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'started', description = 'Outflow when the race is started.' },
  { dir = 'out', type = 'flow', name = 'stopped', description = 'Outflow when the race is not yet started.' },
}


C.tags = {'input'}

function C:init(mgr, ...)
  self.started = false
end

function C:_executionStarted()
  self.started = false
end

function C:work()
  self.pinOut.started.value = self.started
  self.pinOut.stopped.value = not self.started
end

function C:onRaceStart()
  self.started = true
end

function C:onScenarioRestarted()
  self:_executionStarted()
end

return _flowgraph_createNode(C)
