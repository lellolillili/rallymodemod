-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Race Complete'

C.description = "Lets flow through once the race has been finished."
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'out', type = 'flow', name = 'complete', description = 'Outflow when the race is complete.'},
  {dir = 'out', type = 'flow', name = 'ongoing', description = 'Outflow when the race is not yet complete.'},
}


C.tags = {'input'}

function C:init(mgr, ...)
  self.complete = false
end

function C:_executionStarted()
  self.complete = false
end


function C:work()
  self.pinOut.complete.value = self.complete
  self.pinOut.ongoing.value = not self.complete
end

function C:onScenarioFinished()
  self.complete = true
end

function C:onScenarioRestarted()
  self:_executionStarted()
end

return _flowgraph_createNode(C)
