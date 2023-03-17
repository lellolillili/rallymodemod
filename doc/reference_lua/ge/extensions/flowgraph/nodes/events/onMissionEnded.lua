-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'on Level End'
C.description = "Triggers once when the current level is unloaded."
C.category = 'logic'

C.color = ui_flowgraph_editor.nodeColors.event
C.icon = ui_flowgraph_editor.nodeIcons.event
C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node.", impulse = true },
}
C.tags = {}

function C:init(mgr, ...)
end

function C:onClientEndMission()
  self.pinOut.flow.value = true
  self:trigger()
end

function C:work(args)
end

return _flowgraph_createNode(C)
