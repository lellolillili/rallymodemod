-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Direction'
C.description = 'Gives a quaternion that describes the rotation around the z axis of a given amoutn of degrees clockwise.'
C.category = 'simple'
C.todo = "Maybe merge into math."

C.pinSchema = {
    { dir = 'in', type = 'number', name = 'deg', description = 'Input angle in degrees.' },
    { dir = 'out', type = 'quat', name = 'value', description = 'Quaternion describing the rotation.' },
}

C.tags = {}

function C:init()
  self.rot = nil
  self.oldIn = nil
end

function C:work()
  if self.oldIn ~= self.pinIn.deg.value then
    self.oldIn = self.pinIn.deg.value
    self.rot = quatFromEuler(0,0,(self.oldIn / 180) * math.pi)
  end
  self.pinOut.value.value =  {self.rot.x,self.rot.y,self.rot.z,self.rot.w}
end

return _flowgraph_createNode(C)
