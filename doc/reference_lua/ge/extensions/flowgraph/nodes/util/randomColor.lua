-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Random Color'
C.tags = {"random", 'color', 'colour'}
C.icon = "casino"
C.description = "Provides a random color."
C.category = 'provider'
C.todo = "Add a 'onlyCuteColor' bool"

C.pinSchema = {
  { dir = 'out', type = 'color', name = 'color', description = "The color value." },
}


function C:work()
  self.pinOut.color.value = {math.random(), math.random(), math.random(), math.random()}
end

return _flowgraph_createNode(C)
