-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Xor'
C.icon = 'fg_gate_icon_xor'
C.description = "Only lets flow through if exactly one of the input pins has flow."
C.category = 'logic'

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'a', description = 'First flow input.' },
    { dir = 'in', type = 'flow', name = 'b', description = 'Second flow input.' },
    { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}


function C:work()
  self.pinOut.flow.value = self.pinIn.a.value ~= self.pinIn.b.value
end

return _flowgraph_createNode(C)
