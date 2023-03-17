-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Stop Project'
C.description = 'Stops the execution of this Project when triggered.'
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.category = 'logic'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Stops the execution when this has flow.' },
}

function C:work()
  self.graph.mgr:setRunning(false)
end

return _flowgraph_createNode(C)
