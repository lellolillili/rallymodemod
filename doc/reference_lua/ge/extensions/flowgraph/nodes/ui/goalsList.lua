-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Goal List'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Shows a Goal in the Goal List App."
C.category = 'once_instant'
C.todo = "Message app does not like only numbers as input, so make sure to prepend some other string."

C.pinSchema = {
  {dir = 'in', type = 'any', name = 'label', description = "The Label of the goal that will be displayed. Bug: can not start directly with a number."},
  {dir = 'in', type = 'string', name = 'identifier',  default = 'flowgraph',  description = "ID for the goal. Only one message per category can be displayed."},
  {dir = 'in', type = 'bool', name = 'done', description = "If the goal has been fulfilled", hardcoded = true, default = false},
  {dir = 'in', type = 'bool', name = 'fail', description = "If the goal has failed", hidden=true},
  {dir = 'in', type = 'bool', name = 'active', description = "If the goal is active", hardcoded=true, default=true, hidden=true},
}

C.tags = {'goal','goals'}

function C:workOnce()
    guihooks.trigger('SetGoalForList', {
      clear = self.pinIn.clear.value,
      label = self.pinIn.label.value,
      done = self.pinIn.done.value,
      fail = self.pinIn.fail.value,
      active = self.pinIn.active.value,
      id = self.pinIn.identifier.value or ("__"..self.id)}
    )

  self.pinOut.flow.value = self.pinIn.flow.value
end

return _flowgraph_createNode(C)
