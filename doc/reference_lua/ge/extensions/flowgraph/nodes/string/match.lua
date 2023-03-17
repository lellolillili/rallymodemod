-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Match'
C.icon = "mode_edit"
C.color = ui_flowgraph_editor.nodeColors.string
C.description = "Matches a string using a given pattern."
C.category = 'simple'

C.todo = "Explain what patterns can be used and needs testing. Maybe merge with substring into a 'stringOperation' node similar to math expression."
C.pinSchema = {
  {dir = 'in', type = 'string', name = 'value', description = 'The string which should be tested.'},
  {dir = 'out', type = 'string', name = 'value', description = 'The result of the matching.'},
}

C.tags = {}

function C:init()
  self.data.pattern = "%d"
end

function C:work()
  self.pinOut.value.value = string.match(self.pinIn.value.value, self.data.pattern.value)
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.data.pattern)
end

return _flowgraph_createNode(C)
