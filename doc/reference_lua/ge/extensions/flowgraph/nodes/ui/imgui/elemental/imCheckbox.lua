-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'im Checkbox'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Displays a Checkbox in an imgui window."
C.category = 'repeat_instant'

C.todo = ""
C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'enabled', hidden = true, hardcoded = true, default = true, description = 'If this checkbox can be used or not.' },
  { dir = 'in', type = 'flow', name = 'setOn', hidden = true, description = 'Check the box.', impulse = true},
  { dir = 'in', type = 'flow', name = 'setOff', hidden = true, description = 'Uncheck the box.', impulse = true },
  { dir = 'out', type = 'flow', name = 'on', description = 'When box is checked.' },
  { dir = 'out', type = 'flow', name = 'off', description = 'When box is not checked.' },
  { dir = 'out', type = 'flow', name = 'changed', hidden = true, description = 'When state is switched.', impulse = true },
  { dir = 'out', type = 'bool', name = 'checked', description = 'Box is checked or not.' },
  { dir = 'in', type = 'any', name = 'text', description = 'Name of the box.' },
}

function C:init()
  self.data.startState = false
end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
  self.state = self.data.startState
  self.pinOut.on.value = self.state
  self.pinOut.off.value = not self.state
end

function C:work()
  if self.pinIn.setOn.value then
    self.state = true
    self.pinOut.changed.value = true
  end
  if self.pinIn.setOff.value then
    self.state = false
    self.pinOut.changed.value = true
  end
  if not self.pinIn.enabled.value then
    im.BeginDisabled()
  end
  local imVal = im.BoolPtr(self.state)
  if im.Checkbox(tostring(self.pinIn.text.value or "Checkbox")  ..'##'.. tostring(self.id), imVal) then
    self.state = imVal[0]
    self.pinOut.changed.value = true
  else
    self.pinOut.changed.value = false
  end
  if not self.pinIn.enabled.value then
    im.EndDisabled()
  end
  self.pinOut.on.value = self.state
  self.pinOut.off.value = not self.state
end

return _flowgraph_createNode(C)
