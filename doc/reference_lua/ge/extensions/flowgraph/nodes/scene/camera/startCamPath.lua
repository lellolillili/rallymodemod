-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Start Cam Path'
C.description = "Lets the camera follow the path defined by a CameraPath object."
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'pathName', description = 'Path to load camera path from.' },
  { dir = 'in', type = 'bool', name = 'loop', description = 'If the path should loop.' },
  { dir = 'out', type = 'flow', name = 'activated', description = 'Outflow once when the path has been started.', impulse = true },
  { dir = 'out', type = 'number', name = 'id', description = 'Id of the camera path.' },
}

C.tags = {'campath','pathcam','path','camera'}
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera
function C:init()
end

function C:postInit()
  self.pinInLocal.pathName.allowFiles = {
    {"Camera Path Files",".camPath.json"}
  }
end

function C:workOnce()
  local id = self.mgr.modules.camera:findPath(self.pinIn.pathName.value)
  self.mgr.modules.camera:startPath(id, self.pinIn.loop.value)
  self.pinOut.id.value = id
  self.pinOut.activated.value = true
  self.activatedFlag = true
end

function C:work()
  if not self.activatedFlag then
    self.pinOut.activated.value = false
  else
    self.activatedFlag = false
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()

end

return _flowgraph_createNode(C)
