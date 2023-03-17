-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Get Camera FOV'
C.description = "Gets the camera's Field of View as an angle."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'number', name = 'curFOV', description = 'Puts out the current FOV as an angle.' },
}

C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera
C.tags = {}


function C:work()
  if not commands.isFreeCamera() then
    commands.setFreeCamera()
  end
  self.pinOut.curFOV.value = getCameraFovDeg()
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.pinOut.curFOV.value then
    im.Text("Current FOV: %0.1f", self.pinOut.curFOV.value )
  end
end

return _flowgraph_createNode(C)
