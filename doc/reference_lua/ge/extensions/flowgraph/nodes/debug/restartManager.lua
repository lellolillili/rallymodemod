-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Restart Project'
C.description = 'Restarts the Project.'
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.category = 'logic'
C.behaviour = { duration = true }
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Restarts the project when this has flow.' },
}

function C:work()
  self.graph.mgr:queueForRestart()
end

return _flowgraph_createNode(C)
