-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'StartScreen NextPage'
C.color = ui_flowgraph_editor.nodeColors.ui
C.description = 'Attempts to create a string out of the input.'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = '', chainFlow = true },
  { dir = 'out', type = 'flow', name = 'flow', description = '', chainFlow = true },
}

C.tags = {'string'}

function C:work()
  self.mgr.modules.ui:nextPage()
end

return _flowgraph_createNode(C)
