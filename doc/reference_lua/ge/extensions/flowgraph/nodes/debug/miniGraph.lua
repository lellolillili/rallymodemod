-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Mini Graph'
C.description = "A small graph window which only shows one value. Viewport can be clamped. Autoscale will adjust the viewport to the scale of the the data."
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.category = 'repeat_instant'

C.todo = "Improve automatic scaling, otherwise works fine"
C.pinSchema = {
  {dir = 'in', type = 'number', name = 'value', description = 'Value to be logged into the graph'},
}

C.tags = {'util'}

function C:init()
  self.inputLabels = {}
  self.inputColors = {}
  self.graphData = {}
  self.graphDataCount = 100
  self.data.scaleMin = 0
  self.data.scaleMax = 1
  self.data.autoScale = true
  self.data.stop = false
end

function C:work()
  if not self.data.stop then
    local val = self.pinIn.value.value or 0
    table.insert(self.graphData, val)
    if self.data.autoScale then
      self.data.scaleMax = math.max(val, self.data.scaleMax)
      self.data.scaleMin = math.min(val, self.data.scaleMin)
    end
    if #self.graphData >= self.graphDataCount then
      table.remove(self.graphData, 1)
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if #self.graphData > 0 then
    im.PlotMultiLines("", 1, {"val"}, {im.ImColorByRGB(255,255,255,255)}, {self.graphData}, self.graphDataCount-1, "", self.data.scaleMin, self.data.scaleMax, im.ImVec2(200,60))
  end
end

return _flowgraph_createNode(C)
