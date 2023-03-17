-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

-- WIP conversion of the c++ class ...

local im = ui_imgui

local imu = require('ui/imguiUtils')
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')



local function createRect(minR, maxR)
  local res = {
    x = minR.x,
    y = minR.y,
    w = maxR.x - minR.x,
    h = maxR.y - minR.y,
  }
  res.top_left = function() return im.ImVec2(res.x, res.y) end
  res.top_right = function() return im.ImVec2(res.x + res.w , res.y) end
  res.bottom_left = function() return im.ImVec2(res.x, res.y + res.h) end
  res.bottom_right = function() return im.ImVec2(res.x + res.w, res.y + res.h) end
  res.is_empty = function() return w == 0 and h == 0 end
  return res
end

local function GetItemRect()
  return createRect(im.GetItemRectMin(), im.GetItemRectMax())
end

function C:init()
  self.CurrentNodeId = 0 -- NodeId
  self.CurrentStage = 'invalid'
  self.HeaderColor = im.ImVec4(0,0,0,0)
  self.NodeRect = nil -- rect
  self.HeaderRect = nil -- rect
  self.ContentRect = nil -- rect
  self.HasHeader = false
  self.drawDebug = true
  self.leftPinSize = 0
  self.leftPadSize = 0
  self.centerSize = 0
  self.rightPadSize = 0
  self.headerTexture = imu.texObj('art/imgui_node_header_alt.png')
  ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_NodeBorder, im.ImVec4(0, 0, 0, 0.2))

  ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_NodeRounding, 5)
end

function C:Begin(nodeID)
  --print('------------------- ' .. tostring(nodeID))
  self.HasHeader  = false
  self.HeaderRect = nil --rect()

  ui_flowgraph_editor.PushStyleVar4(ui_flowgraph_editor.StyleVar_NodePadding, im.ImVec4(4,4,4,4))

  ui_flowgraph_editor.BeginNode(nodeID)
  im.PushID4(nodeID)
  self.CurrentNodeId = nodeID
  self:SetStage('begin')
end

function C:End(node)
  self:SetStage('end')
  if node.customDrawEnd then
    node:customDrawEnd(self)
  end
  ui_flowgraph_editor.EndNode()

  if im.IsItemVisible() then
    local alpha = im.GetStyle().Alpha
    local drawList = ui_flowgraph_editor.GetNodeBackgroundDrawList(self.CurrentNodeId)
    local halfBorderWidth = ui_flowgraph_editor.GetStyle().NodeBorderWidth * 0.5

    if self.HeaderRect and not self.HeaderRect.is_empty() and self.headerTexture.texId then
      local uv = im.ImVec2(self.HeaderRect.w / (4 * im.uiscale[0] * self.headerTexture.size.x), self.HeaderRect.h / (4 * im.uiscale[0] * self.headerTexture.size.y))

      local a = self.HeaderRect.top_left()
      a.x = a.x - 4 + halfBorderWidth
      a.y = a.y - 4 + halfBorderWidth

      local b = self.HeaderRect.bottom_right()
      b.x = b.x + 4 - halfBorderWidth

      im.ImDrawList_AddImageRounded(im.GetWindowDrawList(), self.headerTexture.texId, a, b, im.ImVec2(0, 0), uv, im.GetColorU322(self.HeaderColor), ui_flowgraph_editor.GetStyle().NodeRounding, 3)

      local headerSeparatorRect = createRect(self.HeaderRect.bottom_left(), self.ContentRect.top_right())
      if not headerSeparatorRect.is_empty() then
        local a = headerSeparatorRect.top_left()
        a.x = a.x - 4 + halfBorderWidth
        a.y = a.y - 0.5

        local b = headerSeparatorRect.top_right()
        b.x = b.x + 4 - halfBorderWidth
        b.y = b.y - 0.5

        im.ImDrawList_AddLine(im.GetWindowDrawList(), a, b, im.GetColorU322(im.ImVec4(0, 0, 0, 0.38 * (alpha / 2)), 1)) -- (alpha / 3)
      end
    end

    if self.drawDebug then
      if self.NodeRect then im.ImDrawList_AddRect(im.GetWindowDrawList(), self.NodeRect.top_left(), self.NodeRect.bottom_right(), im.GetColorU322(im.ImVec4(1, 0, 0, 1))) end
      if self.HeaderRect then im.ImDrawList_AddRect(im.GetWindowDrawList(), self.HeaderRect.top_left(), self.HeaderRect.bottom_right(), im.GetColorU322(im.ImVec4(0, 1, 0, 1))) end
      if self.ContentRect then im.ImDrawList_AddRect(im.GetWindowDrawList(), self.ContentRect.top_left(), self.ContentRect.bottom_right(), im.GetColorU322(im.ImVec4(0, 0, 1, 1))) end
    end

    -- vertical divider lines test
    if self.ContentRect then
      if self.leftPinSize then
      --  im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(self.ContentRect.x + self.leftPinSize, self.ContentRect.y), im.ImVec2(self.ContentRect.x + self.leftPinSize, self.ContentRect.y + self.ContentRect.h), im.GetColorU322(im.ImVec4(1, 1, 1, 0.2)))
      end
      if self.rightPinSize then
      --  im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(self.ContentRect.x + self.ContentRect.w - self.rightPinSize, self.ContentRect.y), im.ImVec2(self.ContentRect.x + self.ContentRect.w - self.rightPinSize, self.ContentRect.y + self.ContentRect.h), im.GetColorU322(im.ImVec4(1,1,1, 0.2)))
      end
    end
  end
  self.CurrentNodeId = 0
  im.PopID()
  ui_flowgraph_editor.PopStyleVar(1)
  self:SetStage('invalid')
end

function C:Header(color)
  self.HeaderColor = color
  self:SetStage('header')
end

function C:EndHeader()
  self:SetStage('content')
end

function C:Input(pin)
  if self.CurrentStage == 'begin' then
    self:SetStage('content')
  end

  local applyPadding = (self.CurrentStage == 'input')
  self:SetStage('input')
  if applyPadding then
  end
  self:Pin(pin, ui_flowgraph_editor.PinKind_Input)
  --im.BeginHorizontal3(pinId)
  --im.SameLine()
end

function C:EndInput()
  --im.EndHorizontal()
  self:EndPin()
end

function C:BeginPinDynamic(pin)
  if pin.direction == 'in' then
    self:Input(pin)
  elseif pin.direction == 'out' then
    self:Output(pin)
  end
end

function C:EndPinDynamic(pin)
  if pin.direction == 'in' then
    self:EndInput()
  elseif pin.direction == 'out' then
    self:EndOutput()
  end
end

function C:Middle()
  if self.CurrentStage == 'begin' then
    self:SetStage('content')
  end
  self:SetStage('middle')
end

function C:Output(pin)
  if self.CurrentStage == 'begin' then
    self:SetStage('content')
  end

  local applyPadding = (self.CurrentStage == 'output')
  self:SetStage('output')
  if applyPadding then
  end
  self:Pin(pin, ui_flowgraph_editor.PinKind_Output)
  --im.BeginHorizontal3(pinId)
  --im.SameLine()
end

function C:EndOutput()
  --im.EndHorizontal()
  self:EndPin()
end

function C:expectOutPinWidth(width)
  self.expectedOutPinWidth = width
end

function C:setExpectedHeaderSize(width)
  self.expectedHeaderWidth = width
end

function C:SetStage(stage)
  --self.drawDebug = true
  if stage == self.CurrentStage then
    return false
  end

  local oldStage = self.CurrentStage
  self.CurrentStage = stage

  --print(' SetStage = ' .. tostring(oldStage) .. ' -> ' .. tostring(stage))

  if oldStage == 'begin' then
    self.leftPinSize = 0
    self.leftPadSize = 0
    self.centerSize = 0
    self.rightPadSize = 0
    self.headerSize = 0
    self.expectedOutPinWidth = 0
    self.expectedHeaderWidth = 0
  elseif oldStage == 'header' then
    --im.EndHorizontal()
    im.EndGroup()
    im.PopID()
    self.HeaderRect = GetItemRect()
    self.HeaderRect.h = (im.GetTextLineHeightWithSpacing()+2) * im.uiscale[0]

    -- spacing between header and content
  elseif oldStage == 'content' then
  elseif oldStage == 'input' then
    ui_flowgraph_editor.PopStyleVar(2)
    local endPos = im.GetCursorPos()
    --print("...")
    --dump(self.inputBeginPos.y)
    --dump(endPos.y)
    self.noInputPin = endPos.y <= self.inputBeginPos.y+10
    self.inputBeginPos = nil
    im.EndGroup()
    im.PopID()
    im.SameLine()
    local itemRect = GetItemRect()
    self.leftPinSize = itemRect.w
    if self.drawDebug then
      im.ImDrawList_AddRect(im.GetWindowDrawList(), itemRect.top_left(), itemRect.bottom_right(), im.GetColorU322(im.ImVec4(1, 0.25, 0, 1)))
    end
  elseif oldStage == 'middle' then
    --im.EndVertical()
    im.EndGroup()
    im.PopID()
    im.SameLine()
    local itemRect = GetItemRect()
    self.centerSize = itemRect.w
    if self.drawDebug then
      im.ImDrawList_AddRect(im.GetWindowDrawList(), itemRect.top_left(), itemRect.bottom_right(), im.GetColorU322(im.ImVec4(1, 1, 0.25, 1)))
    end
  elseif oldStage == 'output' then
    ui_flowgraph_editor.PopStyleVar(2)
    --im.EndVertical()
    im.EndGroup()
    local itemRect = GetItemRect()
    self.rightPinSize = itemRect.w
    im.PopID()
    if self.drawDebug then
      local itemRect = GetItemRect()
      im.ImDrawList_AddRect(im.GetWindowDrawList(), itemRect.top_left(), itemRect.bottom_right(), im.GetColorU322(im.ImVec4(1, 0, 1, 1)))
    end
  elseif oldStage == 'end' then
  elseif oldStage == 'invalid' then
  end


  if stage == 'begin' then
    --im.BeginVertical1('node')
    im.PushID1("node")
    im.BeginGroup()
  elseif stage == 'header' then
    self.HasHeader = true
    --im.BeginHorizontal1('header')
    im.PushID1("header")
    im.BeginGroup()
  elseif stage == 'content' then
    if oldStage == 'begin' then
    end

    --im.BeginHorizontal1('content')
    im.PushID1("content")
    im.BeginGroup()
  elseif stage == 'input' then
    --im.BeginVertical1('inputs', im.ImVec2(0, 0), 0)
    im.PushID1("inputs")
    im.BeginGroup()
    self.inputBeginPos = im.GetCursorPos()

    ui_flowgraph_editor.PushStyleVar2(ui_flowgraph_editor.StyleVar_PivotAlignment, im.ImVec2(0, 0.5))
    ui_flowgraph_editor.PushStyleVar2(ui_flowgraph_editor.StyleVar_PivotSize, im.ImVec2(0, 0))

    if not self.HasHeader then
    end
  elseif stage == 'middle' then
    --im.Dummy(im.ImVec2(4,0))
    --im.SameLine()
    --local tempRect = GetItemRect()
    --self.leftPadSize = tempRect.w
    --if self.drawDebug then
    --  im.ImDrawList_AddRect(im.GetWindowDrawList(), tempRect.top_left(), tempRect.bottom_right(), im.GetColorU322(im.ImVec4(1, 1, 1, 1)))
    --end

    --im.BeginVertical1('middle', im.ImVec2(0, 0), 1)
    im.PushID1("middle")
    im.BeginGroup()
  elseif stage == 'output' then
    --if oldStage == 'middle' or oldStage == 'input' then
    --else
    --end
    --im.Dummy(im.ImVec2(4,0))
    --im.SameLine()
    --local tempRect = GetItemRect()
    --self.rightPadSize = tempRect.w
    --if self.drawDebug then
    --  im.ImDrawList_AddRect(im.GetWindowDrawList(), tempRect.top_left(), tempRect.bottom_right(), im.GetColorU322(im.ImVec4(1, 1, 1, 1)))
    --end


      if self.leftPinSize == 0 then
        self.leftPadSize = 4
        self.rightPadSize = 8
      end
      local currentTotalWidth = self.leftPinSize + self.leftPadSize + self.centerSize + self.rightPadSize

      local expectedWidth = currentTotalWidth + self.expectedOutPinWidth+3
      local paddingRequired = 14-(expectedWidth%14)
      if self.expectedHeaderWidth  > expectedWidth then
        local headerPadding = self.expectedHeaderWidth - (expectedWidth)
        paddingRequired = 14-(self.expectedHeaderWidth%14) + headerPadding
      end
      if self.leftPinSize < 10 then
        paddingRequired = paddingRequired - 1
      end
      if paddingRequired >= 0 then
        --im.SameLine()
        im.Dummy(im.ImVec2(paddingRequired,2))
        im.SameLine()
      end

    if self.drawDebug then
      local tempRect = GetItemRect()
      im.ImDrawList_AddRect(im.GetWindowDrawList(), tempRect.top_left(), tempRect.bottom_right(), im.GetColorU322(im.ImVec4(1, 0, 0, 1)))
    end


    --im.BeginVertical1('outputs', im.ImVec2(0, 0), 1)
    im.PushID1("outputs")
    im.BeginGroup()

    ui_flowgraph_editor.PushStyleVar2(ui_flowgraph_editor.StyleVar_PivotAlignment, im.ImVec2(1, 0.5))
    ui_flowgraph_editor.PushStyleVar2(ui_flowgraph_editor.StyleVar_PivotSize, im.ImVec2(0, 0))

    if not self.HasHeader then
    end
  elseif stage == 'end' then
    if oldStage == 'input' then
    end
    --im.EndHorizontal()
    im.EndGroup()

    self.ContentRect = GetItemRect()

    --im.EndVertical()
    im.EndGroup()
    self.NodeRect = GetItemRect()
    if self.HeaderRect then
      self.HeaderRect.w = math.max(self.HeaderRect.w, self.NodeRect.w)
    end
  elseif stage == 'invalid' then
  end

  return true
end

function C:Pin(pin, kind)
  --if pin.type == 'state' then
  --  ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_LinkStrength,0)
  --  if pin.direction == 'in' then
   --   ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_PinArrowSize,20)
   --   ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_PinArrowWidth,20)
   -- end
  --end
  --ui_flowgraph_editor.PushStyleVar2(ui_flowgraph_editor.StyleVar_PivotSize,im.ImVec2(1,1))
  --ui_flowgraph_editor.PushStyleVar2(ui_flowgraph_editor.StyleVar_PivotScale,im.ImVec2(50,50))

  ui_flowgraph_editor.BeginPin(pin.id, kind)
  --if pin.type == 'state' then
  --  ui_flowgraph_editor.PopStyleVar(1)
  ---  if pin.direction == 'in' then
   --   ui_flowgraph_editor.PopStyleVar(2)
  --  end
  --end
end

function C:EndPin()
  ui_flowgraph_editor.EndPin()

  if self.drawDebug then
    local rMin = im.GetItemRectMin()
    local rMax = im.GetItemRectMax()
    local col = im.GetColorU322(im.ImVec4(1, 0, 0, 0.4))
    --im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), rMin, rMax, col)
  end
end

function C:makeAlignmentPin(pin)
  pin.direction = 'in'
  self:BeginPinDynamic(pin)
  --ui_flowgraph_editor.BeginPin(pin.id, "invis")
  im.SetCursorPosY(im.GetCursorPosY() + 12 )
  im.Dummy(im.ImVec2(00,12))
  --ui_flowgraph_editor.EndPin()
  self:EndPinDynamic(pin)
  im.SetCursorPosY(im.GetCursorPosY() + 1 )
  if self.drawDebug then
    local rMin = im.GetItemRectMin()
    local rMax = im.GetItemRectMax()
    local col = im.GetColorU322(im.ImVec4(0.6, 0.9, 0, 0.4))
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), rMin, rMax, col)
  end
end

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end