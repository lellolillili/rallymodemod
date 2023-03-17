-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Sigmoid Smoother'
C.description = 'Provides sigmoid smoothing for a given signal.'
C.category = 'simple'

C.todo = "Requires testing and should have flow pins."
C.pinSchema = {
  {dir = 'in', type = 'number', name = 'value', description = 'TODO'},
  {dir = 'in', type = 'number', name = 'dt', description = 'TODO'},
  {dir = 'in', type = 'number', name = 'upRateLimit', description = 'TODO'},
  {dir = 'in', type = 'number', name = 'downRateLimit', description = 'TODO'},
  {dir = 'in', type = 'number', name = 'upStartAccel', description = 'TODO'},
  {dir = 'in', type = 'number', name = 'downStartAccel', description = 'TODO'},
  {dir = 'in', type = 'number', name = 'upStopAccel', description = 'TODO'},
  {dir = 'in', type = 'number', name = 'downstopAccel', description = 'TODO'},
  {dir = 'in', type = 'number', name = 'set', description = 'TODO'},
  {dir = 'out', type = 'number', name = 'value', description = 'TODO'},
}

C.tags = {}

function C:init()
  C.oldSet = 0
  C.smoother = newTemporalSigmoidSmoothing()
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

    local limit = 1
    local start = 1
    local stop = 1
    if sample > self.smoother.state then
      limit = self.pinIn.upRateLimit.value or limit
      start = self.pinIn.upStartAccel.value or start
      stop = self.pinIn.upStopAccel.value or stop
    end
    if sample < self.smoother.state then
      limit = self.pinIn.downRateLimit.value or limit
      start = self.pinIn.downStartAccel.value or start
      stop = self.pinIn.downStopAccel.value or stop
    end
    self.pinOut.value.value = self.smoother:getWithRateAccel(sample,dt,limit, start, stop)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.smoother then
    im.Text("%0.4f", self.smoother.state)
  end
end

return _flowgraph_createNode(C)
