-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Edge Detector'
C.icon = ui_flowgraph_editor.nodeIcons.logic
C.description = "Lets the flow through once when input value changes"
C.category = 'logic'

C.pinSchema = {
    { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
    { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
    { dir = 'in', type = 'any', name = 'signal', description = 'Input signal to detect change in.' },
    { dir = 'in', type = 'number', name = 'threshold', default = 0, description = "Allows to specify a threshold value when input signal is numeric" }
}

C.legacyPins = {
  _in = {
    value = 'flow'
  },
  out = {
    value = 'flow'
  }
}

C.tags = { 'util' }

function C:work()
  if type(self.pinIn.signal.value) == "number" and type(self.lastSignal) == "number" and type(self.pinIn.threshold.value) == "number" then
    self.pinOut.flow.value = math.abs(self.pinIn.signal.value - self.lastSignal) > (self.pinIn.threshold.value or 0.0001)
  elseif type(self.pinIn.signal.value) == "table" and type(self.lastSignal) == "table" then
    local changed = false
    if #self.pinIn.signal.value ~= #self.lastSignal then
      changed = true
    else
      for i, v in ipairs(self.pinIn.signal.value) do
        if type(v) == "number" and type(self.lastSignal[i]) == "number" and type(self.pinIn.threshold.value) == "number" then
          changed = changed or math.abs(v - self.lastSignal[i]) > self.pinIn.threshold.value
        elseif v ~= self.lastSignal then
          changed = changed or v ~= self.lastSignal[i]
        end
      end
    end
    self.pinOut.flow.value = changed
  elseif type(self.pinIn.signal.value) ~= type(self.lastSignal) then
    self.pinOut.flow.value = true
  else
    self.pinOut.flow.value = self.pinIn.signal.value ~= self.lastSignal
  end
  self.lastSignal = self.pinIn.signal.value
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.TextUnformatted(dumpsz(self.lastSignal, 2))
end

return _flowgraph_createNode(C)
