-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Receive Message'

C.description = [[Sends a message to another running project.]]

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "In Flow", fixed = true},
  {dir = 'in', type = 'flow', name = 'reset', impulse=true, description = "Resets this node.", fixed = true},
  {dir = 'in', type = 'bool', name = 'isNetwork', description = "if Networked", fixed = true, hidden=true},
  {dir = 'in', type = 'string', name = 'name', description = "Filter for message names. Only matches exactly.", fixed = true},
  {dir = 'out', type = 'flow', name = 'flow', description = "Out Flow always", fixed = true},
  {dir = 'out', type = 'flow', name = 'receiving', impulse=true, description = "Outflow when this node has a new message", fixed = true},
  {dir = 'out', type = 'flow', name = 'received', description = "Outflow when this node has received a message in the past", fixed = true},
}

-- add extensions you require in here, instead of loading them through "extensions.foo". this will increase performance
C.dependencies = {}

C.color = ui_flowgraph_editor.nodeColors.thread
C.icon = ui_flowgraph_editor.nodeIcons.thread

C.type = 'node' -- can also be 'simple', then it wont have a header
C.allowedManualPinTypes = {
  flow = false,
  impulse = false,
  string = true,
  number = true,
  bool = true,
  any = true,
  table = true,
  vec3 = true,
  quat = true,
  color = true,
}

function C:init()
  self.savePins = true
  self.allowCustomOutPins = true
end

function C:onThreadMessageProcess(message)

  if not self.done then
    self.message = message
  end
end

-- This gets called when the node should execute it's actual function in the flowgraph.
function C:work()
  if self.pinIn.reset.value then
    self.done = false
    self.pinOut.receiving.value = false
    self.pinOut.received.value = false
  end
  self.pinOut.receiving.value = false
  if not self.done and self.pinIn.flow.value and self.pinIn.name.value and self.message then
    for name, pin in pairs(self.pinOut) do
      self.pinOut[name].value = self.message[name] or nil
    end
    self.message = nil
    self.done = true
    self.pinOut.receiving.value = true
    self.pinOut.received.value = true
  end
  self.pinOut.flow.value = self.pinIn.flow.value
end

function C:_executionStarted()
  self.done = false
end

function C:drawMiddle(builder, style)
  builder:Middle()
end


return _flowgraph_createNode(C)
