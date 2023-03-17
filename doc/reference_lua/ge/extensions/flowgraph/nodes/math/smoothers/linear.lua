-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Linear Smoother'
C.description = 'Provides linear smoothing for a given signal.'
C.category = 'simple'
C.todo = "Requires testing and should have flow pins."

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'value', description = 'TODO' },
  { dir = 'in', type = 'number', name = 'dt', description = 'TODO' },
  { dir = 'in', type = 'number', name = 'upRate', description = 'TODO' },
  { dir = 'in', type = 'number', name = 'downRate', description = 'TODO' },
  { dir = 'in', type = 'number', name = 'set', description = 'TODO' },
  { dir = 'out', type = 'number', name = 'value', description = 'TODO' },
}

C.tags = {}

function C:init()
  C.oldSet = 0

end

function C:_executionStarted()
  self.smoother = newTemporalSmoothing()
end


function C:checkSetValue()
  if self.pinIn.set.value and self.pinIn.set.value ~= self.oldSet then
    self.oldSet = self.pinIn.set.value
    print(self.oldSet)
    self.smoother:set(self.oldSet)
  end
end

function C:work()
  self:checkSetValue()
  local dt = self.pinIn.dt.value
  local sample = self.pinIn.value.value
  if not sample then
    self.pinOut.value.value = self.smoother.state
  else

    local rate = 1
    if sample > self.smoother.state then
      rate = self.pinIn.upRate.value or rate
    end
    if sample < self.smoother.state then
      rate = self.pinIn.downRate.value or rate
    end
    self.pinOut.value.value = self.smoother:getWithRateUncapped(sample,dt,rate)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.smoother then
    im.Text("%0.4f", self.smoother.state)
  end
end

return _flowgraph_createNode(C)
