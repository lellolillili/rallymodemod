-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Multi Graph'
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.description = "Draws multiple lines in the same graph."
C.category = 'repeat_instant'

C.todo = "Automatic pin add/remove sometimes bugs. Number of used values could be changed to be a property"
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'value 1', description = 'Value 1 to display.' },
}

C.tags = {'util','draw'}

function C:init()
  self.inputPinCount = 0
  self.inputLabels = {}
  self.inputColors = {}
  self.graphData = {}
  self.graphDataCount = 400
  self.data.scaleMin = 0
  self.data.scaleMax = 1

end

function C:work()
  local i = 1
  for l, pin in pairs(self.pinIn) do
    if pin.value and type(pin.value) == "number" then
      if not self.graphData[i] then self.graphData[i] = {} end
      table.insert(self.graphData[i], pin.value)
      self.data.scaleMax = math.max(pin.value, self.data.scaleMax)
      self.data.scaleMin = math.min(pin.value, self.data.scaleMin)
      if #self.graphData[i] >= self.graphDataCount then
        table.remove(self.graphData[i], 1)
      end
      i = i + 1
    end
  end
end

function C:resetgraphData()
  self.inputPinCount = tableSize(self.pinIn)
  self.inputLabels = {}
  self.inputColors = {}
  self.graphData = {}
  local i = 0
  for _, pin in pairs(self.pinIn) do
    table.insert(self.inputLabels, pin.name)
    local c = rainbowColor(self.inputPinCount, i, 255)
    table.insert(self.inputColors, im.ImColorByRGB(c[1], c[2], c[3], 255))
    table.insert(self.graphData, {})
    i = i + 1
  end
end

function C:onLinkDeleted(link)
  self:resetgraphData()
end

function C:onLink(link)
  local numEmptyPins = 0
  for _, pin in ipairs(self.pinList) do
    if pin.direction == "in" and pin.type ~= "flow" then
      if not pin:isUsed() then
        numEmptyPins = numEmptyPins + 1
      end
    end
  end

  if numEmptyPins < 1 then
    self:createPin('in', "number", 'value ' .. tableSize(self.pinIn) + 1, 0, 'Value ' .. (tableSize(self.pinIn) + 1) .. ' to display.')
  end

  self:resetgraphData()
end

function C:onUnlink(link)
  self:resetgraphData()
end


function C:drawMiddle(builder, style)
  builder:Middle()
  --print('self.inputPinCount = ' .. dumps(self.inputPinCount))
  --print('self.inputLabels = ' .. dumps(self.inputLabels))
  --print('self.inputColors = ' .. dumps(self.inputColors))
  if self.inputPinCount > 0 then
    im.PlotMultiLines("", self.inputPinCount, self.inputLabels, self.inputColors, self.graphData, self.graphDataCount, "", self.data.scaleMin, self.data.scaleMax, im.ImVec2(400,300))
    -- im.PlotMultiLines("", self.inputPinCount, self.inputLabels, self.inputColors, self.graphData, self.graphDataCount, "", im.Float(3.402823466E38), im.Float(3.402823466E38), im.ImVec2(600,400))
  end
end

return _flowgraph_createNode(C)
