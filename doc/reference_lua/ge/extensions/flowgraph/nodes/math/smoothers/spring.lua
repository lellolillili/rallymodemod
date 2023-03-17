-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Spring Smoother'
C.description = 'Provides spring smoothing for a given signal.'
C.category = 'simple'
C.todo = "Requires testing and should have flow pins."

C.pinSchema = {
    { dir = 'in', type = 'number', name = 'value', description = 'TODO' },
    { dir = 'in', type = 'number', name = 'dt', description = 'TODO' },
    { dir = 'in', type = 'number', name = 'upSpring', description = 'TODO' },
    { dir = 'in', type = 'number', name = 'downSpring', description = 'TODO' },
    { dir = 'in', type = 'number', name = 'upDamp', description = 'TODO' },
    { dir = 'in', type = 'number', name = 'downDamp', description = 'TODO' },
    { dir = 'in', type = 'number', name = 'set', description = 'TODO' },
    { dir = 'out', type = 'number', name = 'value', description = 'TODO' },
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

    local spring = 1
    local damp = 1
    if sample > self.smoother.state then
      spring = self.pinIn.upSpring.value or spring
      damp = self.pinIn.upDamp.value or damp
    end
    if sample < self.smoother.state then
      spring = self.pinIn.downSpring.value or spring
      damp = self.pinIn.downDamp.value or damp
    end
    self.pinOut.value.value = self.smoother:getWithSpringDamp(sample,dt,spring, damp)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.smoother then
    im.Text("%0.4f", self.smoother.state)
  end
end

return _flowgraph_createNode(C)
