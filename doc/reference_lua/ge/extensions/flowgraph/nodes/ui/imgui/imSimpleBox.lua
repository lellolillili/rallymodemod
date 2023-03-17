-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'im Simple Text Box'
C.description = 'Simple imgui Text Box'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'title', default = 'Some Title', description = 'Displayed title.' },
  { dir = 'in', type = 'string', name = 'text', default = 'Some Text', description = 'Displayed text.' },
}

C.tags = {}

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:work()
  im.Begin((self.pinIn.title.value or "Title") ..'##'.. tostring(self.id), im.BoolPtr(true))
  im.Text((self.pinIn.text.value or "Text"))
  im.End()

end


return _flowgraph_createNode(C)
