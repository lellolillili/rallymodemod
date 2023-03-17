-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Show Monitor'
C.description = 'Enables the FG monitor and hides the editor.'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.category = 'once_instant' -- kind of edge case, because reset doesn't serve much purpose

C.author = 'BeamNG'
C.pinSchema = {
  {dir = 'in', type = 'bool', name = 'showStates', description = 'Shows or hides the States section.', hidden=true},
  {dir = 'in', type = 'bool', name = 'showLog', description = 'Shows or hides the Log section.', hidden=true},
}

C.tags = {}

function C:workOnce()
  self.done = true
  dumpz(self.mgr.fgEditor, 1)
  self.mgr.fgEditor.switchToSmallWindow = true
  self.mgr.fgEditor.forceOpen.states = self.pinIn.showStates.value
  self.mgr.fgEditor.forceOpen.log = self.pinIn.showLog.value
  dumpz(self.mgr.fgEditor, 1)
end


return _flowgraph_createNode(C)
