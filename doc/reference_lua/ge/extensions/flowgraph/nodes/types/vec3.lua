-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Vec3'
C.description = "Provides a vector3."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'x', description = 'The x value.' },
  { dir = 'in', type = 'number', name = 'y', description = 'The y value.' },
  { dir = 'in', type = 'number', name = 'z', description = 'The z value.' },
  { dir = 'out', type = 'vec3', name = 'value', description = 'The vector3 value.' },
}

function C:work()
  self.pinOut.value.value = {self.pinIn.x.value or 0, self.pinIn.y.value or 0, self.pinIn.z.value or 0}
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(tostring(vec3(self.pinIn.x.value or 0, self.pinIn.y.value or 0, self.pinIn.z.value or 0)))
end

function C:drawProperties()
end

function C:_onSerialize(res)
end

function C:_onDeserialized(nodeData)
end

return _flowgraph_createNode(C)
