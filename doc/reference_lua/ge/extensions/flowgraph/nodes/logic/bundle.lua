-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Bundle'
C.description = "Bundles Flow to increase readability of the graph."
C.type = 'simple'
C.category = 'logic'

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
    { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}


function C:work()
  self.pinOut.flow.value = self.pinIn.flow.value
end

return _flowgraph_createNode(C)
