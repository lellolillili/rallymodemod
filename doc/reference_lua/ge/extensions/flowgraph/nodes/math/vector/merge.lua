-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Merge'
C.type = 'simple'
C.description = 'Merges up to 4 components into a table.'
C.category = 'simple'

C.pinSchema = {
    { dir = 'in', type = 'number', name = 'x', description = 'First element.' },
    { dir = 'in', type = 'number', name = 'y', description = 'Second element.' },
    { dir = 'in', type = 'number', name = 'z', description = 'Third element.' },
    { dir = 'in', type = 'number', name = 'w', description = 'Fourth element.' },
    { dir = 'out', type = { 'vec3', 'color', 'quat' }, name = 'value', description = 'All elements packed into a table.' },
}

C.tags = {}

function C:init()
end

function C:work()
  self.pinOut.value.value = {
   self.pinIn.x.value or nil,
   self.pinIn.y.value or nil,
   self.pinIn.z.value or nil,
   self.pinIn.w.value or nil
  }
end

return _flowgraph_createNode(C)
