-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Accumulator'
C.description = 'Adds together values whenever it is triggered. Can be reset by trigger.'
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'add', description = "Triggering this pin will cause this node to add from the value pin to its own value." },
    { dir = 'in', type = 'flow', name = 'reset', description = "Triggering this pin will reset the value back to the default. Has priority over add.", impulse = true },
    { dir = 'in', type = 'number', name = 'value', description = "This value will be added to the stack." },
    { dir = 'out', type = 'flow', name = 'changed', description = "Triggers when the value inside has changed.", impulse = true },
    { dir = 'out', type = 'number', name = 'result', description = "The current value." },
}

C.tags = {'sum','points'}

function C:init()
  self.data.currentSum = 0
  self.data.resetValue = 0
end

function C:_executionStarted()
  self.data.currentSum = self.data.resetValue
  self.pinOut.result.value = self.data.currentSum
end

function C:_executionStopped()
  self.data.currentSum = self.data.resetValue
  self.pinOut.result.value = self.data.currentSum
end

function C:work()
  local v = self.data.currentSum

  if self.pinIn.reset.value then
    v = self.data.resetValue
  end
  self.pinOut.changed.value = false

  if self.pinIn.add.value then
    v = v + (self.pinIn.value.value or 0)
    self.pinOut.changed.value = true
  end

  self.data.currentSum = v
  self.pinOut.result.value = v
end

function C:_onDeserialized()
  self.data.currentSum = self.data.resetValue
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text("%0.4f", self.data.currentSum)
end

return _flowgraph_createNode(C)
