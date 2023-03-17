-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Race Config'

C.description = "Gives info about how the race was configured by the user."
C.category = 'provider'

C.pinSchema = {
  {dir = 'out', type = 'number', name = 'laps', description = 'Amount of Laps chosen.'},
  {dir = 'out', type = 'bool', name = 'reverse', description = 'If the user picked the reverse option.'},
  {dir = 'out', type = 'bool', name = 'rollingStart', description = 'If the user picked the rolling start option.'},
}


C.tags = {'input'}

function C:init(mgr, ...)
  self.done = false
  self.clearOutPinsOnStart = false
end

function C:_executionStarted()
  self.done = false
end

function C:work()
  if not self.done then
    local scenario = scenario_scenarios.getScenario()
    if not scenario then return end
    self.pinOut.rollingStart.value = scenario.rollingStart
    self.pinOut.reverse.value = scenario.isReverse
    self.pinOut.laps.value = scenario.lapCount
    self.done = true
  end
end



function C:onScenarioRestarted()
  self:_executionStarted()
end

return _flowgraph_createNode(C)
