-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Show Apps'
C.description = 'Shows or hides Apps.'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.author = 'BeamNG'
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'value', description = 'If the Apps should be visible or not.' },
}

C.tags = {'show', 'hide', 'Apps'}

function C:_executionStarted()
  self._doHide = nil
end

function C:workOnce()
  self._doHide = self.pinIn.value.value
end

function C:_afterTrigger()
  if self._doHide ~= nil then
    guihooks.trigger('ShowApps', self.pinIn.value.value)
    self._doHide = nil
  end
end


return _flowgraph_createNode(C)
