-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Clear Messages'
C.description = 'Clears all Messages.'
C.category = 'once_instant'
C.author = 'BeamNG'

C.pinSchema = {}
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.tags = {}

function C:workOnce()
  guihooks.trigger('ClearAllMessages')
end

return _flowgraph_createNode(C)
