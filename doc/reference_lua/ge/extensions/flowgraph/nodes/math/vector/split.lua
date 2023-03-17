-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Split'
C.type = 'simple'
C.description = 'Splits a vector into its components. Max size of 4.'
C.category = 'simple'

C.pinSchema = {
  { dir = 'in', type = { 'vec3', 'color', 'quat' }, name = 'value', description = 'A Vector, color or quaternion.' },
  { dir = 'out', type = 'number', name = 'x', description = 'First element.' },
  { dir = 'out', type = 'number', name = 'y', description = 'Second element.' },
  { dir = 'out', type = 'number', name = 'z', description = 'Third element.' },
  { dir = 'out', type = 'number', name = 'w', description = 'Fourth element.' },
}

C.tags = {}

function C:init()
end

function C:work()
  local table = self.pinIn.value.value or {}
  self.pinOut.x.value = table[1]
  self.pinOut.y.value = table[2]
  self.pinOut.z.value = table[3]
  self.pinOut.w.value = table[4]
end

return _flowgraph_createNode(C)
