-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Set Camera FOV'
C.description = "Sets the cameras Field of View as an angle."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'value', description = 'Defines the FOV to set as an angle.' },
}

C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera
C.tags = {}


function C:work()
  if not commands.isFreeCamera() then
    commands.setFreeCamera()
  end
  setCameraFovDeg(self.pinIn.value.value)
end

function C:_executionStarted()
  self._storedFov = getCameraFovDeg()
end
function C:_executionStopped()
  if self._storedFov then
    setCameraFovDeg(self._storedFov)
  end
  self._storedFov = nil
end
function C:drawMiddle(builder, style)
  builder:Middle()
  if self.pinIn.value.value then
    im.Text("%0.2f", self.pinIn.value.value )
  end
end


return _flowgraph_createNode(C)
