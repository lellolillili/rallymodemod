-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Show Editor'
C.description = 'Shows or hides the World Editor.'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.category = 'once_instant'
C.author = 'BeamNG'

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'value', description = 'If the editor should be visible or not.' },
}

C.tags = {'show', 'hide', 'editor'}

function C:workOnce()
  self._doHide = self.pinIn.value.value
end

function C:_afterTrigger()
  if self._doHide ~= nil then
    if editor.active ~= self._doHide then
      editor.setEditorActive(self._doHide)
    end
    self._doHide = nil
  end
end


return _flowgraph_createNode(C)
