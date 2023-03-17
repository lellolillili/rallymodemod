-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Set allow donut'

C.description = 'Set whether the player can donut'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'allowDonut', description = "Self explenatory"},
}

C.tags = {'gameplay', 'utils'}

function C:work()
    self.mgr.modules.drift:setAllowDonut(self.pinIn.allowDonut.value)
end

return _flowgraph_createNode(C)