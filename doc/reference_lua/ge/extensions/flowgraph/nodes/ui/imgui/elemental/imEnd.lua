-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'im End'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Ends an imgui window. Make sure to begin it with im Begin."
C.category = 'repeat_instant'

C.todo = ""
C.pinSchema = {}

function C:work()
  im.End()
end

return _flowgraph_createNode(C)
