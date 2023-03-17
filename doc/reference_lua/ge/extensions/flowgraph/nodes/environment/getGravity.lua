-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Get Gravity'
C.description = "Returns the current gravity."
C.category = 'provider'

C.pinSchema = {
    { dir = 'out', type = 'number', name = 'gravity', description = 'Current gravity in m/s^2.' },
}

C.tags = {}

function C:work()
  self.pinOut.gravity.value = core_environment.getGravity()
end

return _flowgraph_createNode(C)
