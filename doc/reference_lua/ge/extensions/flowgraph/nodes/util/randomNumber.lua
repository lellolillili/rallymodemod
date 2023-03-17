-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Random Number'

C.description = [[Outputs random numbers, between the specified range, as long it receives flow.]]
C.icon = "casino"
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'number', name = 'rangeStart', default = 0, hardcoded = true, description = "The smallest number in the range."},
  {dir = 'in', type = 'number', name = 'rangeEnd', default = 10, hardcoded = true, description = "The biggest number in the range."},
  {dir = 'in', type = 'bool', name = 'float', hidden = true, default = false, hardcoded = true, description = "If enabled, the random number is a float, otherwise an integer."},
  {dir = 'out', type = 'number', name = 'random', description = "The random number."},
}

C.tags = {"random", 'number', 'utils'}

function C:work()
  local random = 0;

  if self.pinIn.rangeStart.value and self.pinIn.rangeEnd.value then
    if (self.pinIn.float.value == true) then
      random = self.pinIn.rangeStart.value + math.random() * (self.pinIn.rangeEnd.value - self.pinIn.rangeStart.value)
    else
      random = math.random(self.pinIn.rangeStart.value, self.pinIn.rangeEnd.value)
    end
  end

  self.pinOut.random.value = random
end

return _flowgraph_createNode(C)