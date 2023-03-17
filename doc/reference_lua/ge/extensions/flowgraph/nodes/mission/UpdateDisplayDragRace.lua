-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'Update Display Drag Race'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Updates the lights for the Drag Races missions.'
C.todo = ""
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Reset this node.', impulse = true},
  {dir = 'in', type = 'number', name = 'time', description = 'Time of the players vehicle'},
  {dir = 'in', type = 'number', name = 'velocity', description = 'Velocity of the players vehicle'},
  {dir = 'in', type = 'string', name = 'side', default = 'l', description = 'Velocity of the players vehicle'},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
}

function C:postInit()
  self.pinInLocal.side.hardTemplates = {
    { label = 'left', value = 'l' },
    { label = 'right', value = 'r' }
  }
end

function C:updateDisplay(side, finishTime, finishSpeed)
  --log("D","updateDisplay",dumps(side).." = "..dumps(finishTime).." ="..dumps(finishSpeed))

  local timeDisplayValue = {}
  local speedDisplayValue = {}
  local timeDigits = {}
  local speedDigits = {}

  if side == "r" then
    timeDigits = self.rightTimeDigits
    speedDigits = self.rightSpeedDigits
  else
    timeDigits = self.leftTimeDigits
    speedDigits = self.leftSpeedDigits
  end

  if finishTime < 10 then
    table.insert(timeDisplayValue, "empty")
  end

  if finishSpeed < 100 then
    table.insert(speedDisplayValue, "empty")
  end

  -- Three decimal points for time
  for num in string.gmatch(string.format("%.3f", finishTime), "%d") do
    table.insert(timeDisplayValue, num)
  end

  -- Two decimal points for speed
  for num in string.gmatch(string.format("%.2f", finishSpeed), "%d") do
    table.insert(speedDisplayValue, num)
  end

  if #timeDisplayValue > 0 and #timeDisplayValue < 6 then
    for i,v in ipairs(timeDisplayValue) do
      timeDigits[i]:preApply()
      timeDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_".. v ..".dae")
      timeDigits[i]:setHidden(false)
      timeDigits[i]:postApply()
    end
  end

  for i,v in ipairs(speedDisplayValue) do
    speedDigits[i]:preApply()
    speedDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_".. v ..".dae")
    speedDigits[i]:setHidden(false)
    speedDigits[i]:postApply()
  end
end

function C:insertDigits()
  for i=1, 5 do
    local leftTimeDigit = scenetree.findObject("display_time_" .. i .. "_l")
    table.insert(self.leftTimeDigits, leftTimeDigit)

    local rightTimeDigit = scenetree.findObject("display_time_" .. i .. "_r")
    table.insert(self.rightTimeDigits, rightTimeDigit)

    local rightSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_r")
    table.insert(self.rightSpeedDigits, rightSpeedDigit)

    local leftSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_l")
    table.insert(self.leftSpeedDigits, leftSpeedDigit)
  end
end

function C:_executionStarted()
  self.pinOut.flow.value = false
  self.rightTimeDigits = {}
  self.rightSpeedDigits = {}
  self.leftTimeDigits = {}
  self.leftSpeedDigits = {}
end

function C:init()
  self.pinOut.flow.value = false
  self.rightTimeDigits = {}
  self.rightSpeedDigits = {}
  self.leftTimeDigits = {}
  self.leftSpeedDigits = {}
end

function C:work()
  self.pinOut.flow.value = false

  if self.pinIn.reset.value then
    self:insertDigits()
    self:updateDisplay(self.pinIn.side.value, 0.0, 0.0)
    return
  end

  if self.pinIn.time.value and self.pinIn.velocity.value and self.pinIn.side.value then
    self:updateDisplay(self.pinIn.side.value, self.pinIn.time.value, self.pinIn.velocity.value == 0 and self.pinIn.velocity.value or self.pinIn.velocity.value*2.237) -- multiply velocity to go to mph
  end

  self.pinOut.flow.value = true
end

return _flowgraph_createNode(C)
