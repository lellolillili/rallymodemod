-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Hide Game UI'
C.description = 'Shows or hides the normal game UI (apps etc)'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.category = 'repeat_instant'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'value', description = 'Defines if the game UI should be hidden.' },
}

C.tags = {}

function C:work()
  extensions.ui_visibility.setCef(not (self.pinIn.value.value or false))
end


return _flowgraph_createNode(C)
