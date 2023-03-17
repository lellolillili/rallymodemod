-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Bool'
C.description = "Provides a boolean value."
C.category = 'provider'

C.pinSchema = {
    { dir = 'out', type = 'bool', name = 'value', description = 'The boolean value.' },
}


function C:init()
  self.data.value = true
end

function C:work()
  self.pinOut.value.value = self.data.value
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.TextUnformatted(tostring(self.data.value))
end

return _flowgraph_createNode(C)
