-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Complete Scenario'

C.description = [[Completes a scenario.]]
C.category = 'once_instant'

C.pinSchema = {
    { dir = 'in', type = 'string', name = 'reason', description = 'Final message.' },
    { dir = 'in', type = 'bool', name = 'fail', description = 'If true, scenario will fail.' },
}

function C:workOnce()
    if not scenario_scenarios then return end
    local p = {}
    if self.pinIn.fail.value == true then
      p.failed = (self.pinIn.reason.value or "Failed")
    else
      p.msg = (self.pinIn.reason.value or "Completed")
    end
    scenario_scenarios.finish(p)
end

function C:drawMiddle(builder, style)
  builder:Middle()
end



return _flowgraph_createNode(C)
