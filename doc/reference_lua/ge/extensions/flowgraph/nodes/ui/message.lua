-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Message'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Shows a Message in the small message app."
C.todo = "Message app does not like only numbers as input, so make sure to prepend some other string."
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
  {dir = 'in', type = 'any', name = 'message', description = "The message that will be displayed. Bug: can not start directly with a number."},
  {dir = 'in', type = 'number', name = 'duration',  default = 5,  description = "Duration of display in seconds."},
  {dir = 'in', type = 'string', name = 'category',  default = 'flowgraph',  description = "Category for the message. Only one message per category can be displayed."},
  {dir = 'in', type = 'string', name = 'icon',  default = 'info', hardcoded = true, hidden = true,  description = "The icon used for displaying. Find icons under Tools / Material Icons."},
}

C.tags = {'string','util'}

local pulseTime = 0.05


function C:_executionStarted()
  self._timer = 0
  self.underscoreIdCache = '__'..self.id
end
function C:_afterTrigger()
  if not self.pinIn.flow.value then
    self._timer = 0
  end
end
function C:drawCustomProperties()
  if im.Button("Open Icons overview") then
    if editor_iconOverview then
      editor_iconOverview.open()
    end
  end
end
local helper = {}
function C:work()
  if self._timer <= 0 then
    helper.clear = self.pinIn.message.value == nil
    helper.ttl = self.pinIn.duration.value or 5
    helper.msg = self.pinIn.message.value or nil
    helper.category = self.pinIn.category.value or (self.underscoreIdCache)
    helper.icon = self.pinIn.icon.value or nil
    --print(self.pinIn.message.value)
    --ui_message(tostring(self.pinIn.message.value), self.pinIn.duration.value or 5, self.pinIn.category.value or ("__"..self.id), self.pinIn.icon.value)
    guihooks.trigger('Message',helper)
    self._timer = self._timer + pulseTime
  end
  self._timer = self._timer - self.mgr.dtReal
  self.pinOut.flow.value = self.pinIn.flow.value
end

return _flowgraph_createNode(C)
