-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Look At'
C.description = 'Gives the quaternion that describes rotation looking into a certain direction.'
C.category = 'simple'

C.pinSchema = {
  { dir = 'in', type = 'vec3', name = 'from', description = 'The origin of the look-vector.' },
  { dir = 'in', type = 'vec3', name = 'to', description = 'The target of the look-vector.' },
  { dir = 'in', type = 'vec3', name = 'up', default = { 0, 0, 1 }, hidden = true, hardcoded = true, description = 'Up-Vector, default is (0,0,1).' },
  { dir = 'out', type = 'quat', name = 'value', description = 'The rotation as a quaternion.' },
}

C.tags = {}

function C:init()
  self.up = vec3(0,0,1)
end


function C:drawCustomProperties()
  local reason = nil
  im.Columns(2)
  im.Text("Up Vector")
  im.NextColumn()
  local pos = im.ArrayFloat(3)
  pos[0] = im.Float(self.up.x)
  pos[1] = im.Float(self.up.y)
  pos[2] = im.Float(self.up.z)
  if im.DragFloat3("##pos"..self.id,pos, 0.5) then
    self.up:set(pos[0], pos[1], pos[2])
    reason = "Changed up vector"
  end
  im.Columns(1)
  return reason
end

function C:work()
  local quat = quatFromDir(vec3(self.pinIn.to.value) - vec3(self.pinIn.from.value), self.pinIn.up.value and vec3(self.pinIn.up.value):normalized() or self.up)
  self.pinOut.value.value = {quat.x, quat.y, quat.z, quat.w}
end

return _flowgraph_createNode(C)
