-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Send Message'

C.description = [[Sends a message to another running project.]]

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "In Flow", fixed = true},
  {dir = 'in', type = 'flow', name = 'reset', impulse=true, description = "Resets this node.", fixed = true},
  {dir = 'in', type = 'bool', name = 'networked', description = "if Networked", fixed = true, hidden=true},
  {dir = 'in', type = 'number', name = 'id', description = "ID of the receiver project. Use -1 for parent.", fixed = true},
  {dir = 'in', type = 'string', name = 'name', description = "Name of the message", fixed = true},
  {dir = 'out', type = 'flow', name = 'flow', description = "Out Flow", fixed = true},
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
  self.allowCustomInPins = true
end

-- This gets called when the node should execute it's actual function in the flowgraph.
function C:work()
  if self.pinIn.reset.value then
    self.done = false
  end

  if not self.done and self.pinIn.flow.value and self.pinIn.id.value then
    local tData = {}
    local added = false
    for name, pin in pairs(self.pinIn) do
      if not pin.fixed then
        tData[name] = pin.value
        added = true
      end
    end
    if self.pinIn.networked.value then
      local result = self.mgr.modules.thread:sendNetworkedMessage(self.pinIn.id.value, tData or nil, self)
    else
      local result = self.mgr.modules.thread:sendMessage(self.pinIn.id.value, tData or nil, self)
    end
    self.done = true
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
