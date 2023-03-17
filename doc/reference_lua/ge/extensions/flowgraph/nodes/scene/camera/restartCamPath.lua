-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Restart Cam Path'
C.description = "Restarts the currently active a campath."
C.behaviour = { once = true }
C.category = 'once_instant'

C.pinSchema = {
    { dir = 'in', type = 'number', name = 'id', description = 'Id of the camera path. If no ID given, tries to use the currently active camera path.', hidden = true }
}

C.tags = {'campath','pathcam','path','camera'}
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera

function C:workOnce()
    self.mgr.modules.camera:restartActivePath(self.pinIn.id.value)
end

function C:drawMiddle(builder, style)
    builder:Middle()
end

return _flowgraph_createNode(C)
