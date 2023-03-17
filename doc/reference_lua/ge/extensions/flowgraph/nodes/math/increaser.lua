-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Increaser'
C.description = 'If the input value is bigger than the internal value, the internal value will be set to the input value.'
C.category = 'repeat_instant'
C.todo = "Not tested a lot."

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
    { dir = 'in', type = 'flow', name = 'clear', description = 'Resets the value back to the reset-value.', impulse = true },
    { dir = 'in', type = 'number', name = 'value', description = 'The value to check.' },
    { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
    { dir = 'out', type = 'flow', name = 'changed', description = 'Outflow when the value inside has changed.', impulse = true },
    { dir = 'out', type = 'number', name = 'result', description = 'The current value.' },
}

C.legacyPins = {
    _in = {
        reset = 'clear'
    }
}

C.tags = { 'add', 'points' }

function C:init()
    self.data.currentValue = 0
    self.data.resetValue = 0
end

function C:_executionStopped()
    self.data.currentValue = self.data.resetValue
end

function C:work()
  local v = self.data.currentValue

    if self.pinIn.clear.value then
        v = self.data.resetValue
    end

  if self.pinIn.value.value then
    self.pinOut.changed.value = false
    if self.pinIn.value.value > v then
      v = self.pinIn.value.value
      self.pinOut.changed.value = true
    end
  end

  self.data.currentValue = v
  self.pinOut.result.value = v
  self.pinOut.flow.value = self.pinIn.flow.value
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text("%0.4f", self.data.currentValue)
end

return _flowgraph_createNode(C)
