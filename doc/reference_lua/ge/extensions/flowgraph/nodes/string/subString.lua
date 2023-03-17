-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'SubString'
C.icon = "mode_edit"
C.color = ui_flowgraph_editor.nodeColors.string
C.description = "Gets the substring of the input string."
C.category = 'simple'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'value', description = 'The string which should be trimmed.' },
  { dir = 'out', type = 'string', name = 'value', description = 'The resulting substring.' },
}

C.tags = {}

function C:init()
  self.data.from = 0
  self.data.to = -1
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.data.from ..  " / " .. self.data.to)
end

function C:work()
  self.pinOut.value.value = string.sub(self.pinIn.value.value, self.data.from, self.data.to)
end


return _flowgraph_createNode(C)
