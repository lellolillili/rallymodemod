-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'on Execution Started'
C.description = "Triggers once at the beginning of the execution of this project."
C.category = 'logic'

C.todo = "Might trigger to early and not work correctly."
C.color = ui_flowgraph_editor.nodeColors.event
C.icon = ui_flowgraph_editor.nodeIcons.event
C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow once when this project started.', impulse = true },
}


C.tags = {}

function C:init(mgr, ...)
  self.pinOut.flow.value = true
end
function C:onExecutionStarted()
  self.pinOut.flow.value = true
  self:trigger()
end

return _flowgraph_createNode(C)
