-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'im Text'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Displays a text in an imgui window."
C.category = 'repeat_instant'

C.todo = ""
C.pinSchema = {
  { dir = 'in', type = 'any', name = 'text', description = 'Text to display.' },
}

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
end

function C:work()
  local avail = im.GetContentRegionAvail()
  im.PushTextWrapPos(avail.x)
  im.TextWrapped(tostring(self.pinIn.text.value))
  im.PopTextWrapPos()
end

return _flowgraph_createNode(C)
