-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local min = math.min
local max = math.max
local abs = math.abs
local ceil = math.ceil
local floor = math.floor
local huge = math.huge
local log10 = math.log10

local C = {}

local borderSize = 50

local borderColor = im.GetColorU322(im.ImVec4(1, 1, 1, 0.3), 1)
local gridColor = im.GetColorU322(im.ImVec4(1, 1, 1, 0.15), 1)

local textColor = im.ImVec4(1, 1, 1, 0.5)

local p --= LuaProfiler("JBeam_Table_Visualizer")

-- USAGE
-- params.scale = {xMin, xMax, yMin, yMax} or nil
-- params.initData = data or nil
-- params.autoScale = true or false
-- params.showCatmullRomCurve = true or false
-- params.catmullromCurveLines = x or nil (x > 200 preferably)
function C:init(params)
  self._cmT = {}
  self._cmY0, self._cmY1, self._cmY2, self._cmY3 = {}, {}, {}, {}
  self._cmC1, self._cmC2, self._cmC3 = {}, {}, {}

  self.catmullDataPoints = nil

  self.screenPos = {x = 0, y = 0}
  self.innerSize = {x = 0, y = 0}
  self.scale = {}

  if not params then
    self:setScale(-5, 5, -5, 5)
    return
  end

  if params.scale then
    self:setScale(params.scale.xMin, params.scale.xMax, params.scale.yMin, params.scale.yMax)
  else
    self:setScale(-5, 5, -5, 5)
  end

  self.autoScale = params.autoScale

  self.showCatmullRomCurve = params.showCatmullRomCurve
  self.catmullromCurveLines = params.catmullromCurveLines or 10

  if params.initData then
    self:setData(params.initData)
  end
end

-- Method to set graph data
-- Must be in this format (multiple y values for one x allowed):
-- {{x0, y0, ...}, {x1, y1, ...}, ...}
function C:setData(data)
  self.data = data

  if self.autoScale then
    self:scaleToFitData()
  end

  if self.showCatmullRomCurve then
    self:generateCatmullSplinePoints(data, self.catmullromCurveLines)
  end
end
-- sets the names of the series. is a list of names
function C:setSeriesNames(names)
  self.seriesNames = names
end

-- Sets the domain/range of the graph to fit all data points in view
function C:scaleToFitData()
  if not self.data then return end

  local xMin = huge
  local xMax = -huge
  local yMin = huge
  local yMax = -huge

  for _, d in ipairs(self.data) do
    local count = tableSize(d)

    -- Allows for multiple y's for one x
    for i = 2, count do
      local ptX = d[1]
      local ptY = d[i]

      xMin = min(xMin, ptX)
      xMax = max(xMax, ptX)
      yMin = min(yMin, ptY)
      yMax = max(yMax, ptY)
    end
  end

  local marginX = (xMax - xMin) / 10
  local marginY = (yMax - yMin) / 10

  self:setScale(xMin - marginX, xMax + marginX, yMin - marginY, yMax + marginY)
end

-- Sets the domain/range of the graph.
-- All parameters are optional so you can just set one of them and leave rest nil for example
function C:setScale(xMin, xMax, yMin, yMax)
  if xMin then
    self.scale.xMin = xMin
  end
  if xMax then
    self.scale.xMax = xMax
  end
  if yMin then
    self.scale.yMin = yMin
  end
  if yMax then
    self.scale.yMax = yMax
  end
  self.centerPos = {(xMax - xMin) / 2.0, (yMax - yMin) / 2.0}
end

-- Moves graph when dragging mouse with left mouse button
function C:moveGraph(dt)
  if im.IsMouseDragging(0) then
    if not self.isMouseDragging then
      -- First time
      -- Mouse must be inside graph first time
      if not self.mouseInGraph then return end

      self.originalScale = deepcopy(self.scale)

      self.isMouseDragging = true
    end

    local mouseDragDelta = im.GetMouseDragDelta(0)

    local xDelta = (self.originalScale.xMax - self.originalScale.xMin) * mouseDragDelta.x / self.innerSize.x
    local yDelta = (self.originalScale.yMax - self.originalScale.yMin) * mouseDragDelta.y / self.innerSize.y

    self:setScale(
      self.originalScale.xMin - xDelta,
      self.originalScale.xMax - xDelta,
      self.originalScale.yMin + yDelta,
      self.originalScale.yMax + yDelta
    )
  else
    self.isMouseDragging = false
  end
end

-- Zooms graph with mouse scroll wheel and based on mouse position
function C:zoomGraph(dt)
  if not self.mouseInGraph then return end

  local mZoom = -self.mouseWheel * 20

  local xZoom = (self.scale.xMax - self.scale.xMin) * mZoom
  local yZoom = (self.scale.yMax - self.scale.yMin) * mZoom

  self:setScale(
    self.scale.xMin - xZoom * self.mousePosInWindowX / self.windowSize.x * dt,
    self.scale.xMax + xZoom * (self.windowSize.x - self.mousePosInWindowX) / self.windowSize.x * dt,
    self.scale.yMin - yZoom * (self.windowSize.y - self.mousePosInWindowY) / self.windowSize.y * dt,
    self.scale.yMax + yZoom * self.mousePosInWindowY / self.windowSize.y * dt
  )
end

-- Main method to call on every graphics update
function C:draw(width, height, dt)
  self.io = im.GetIO()
  self.mousePos = self.io.MousePos
  self.mouseWheel = self.io.MouseWheel

  self.windowPos = im.GetWindowPos()
  self.windowSize = im.GetWindowSize()

  self.mousePosInWindowX = self.mousePos.x - self.windowPos.x
  self.mousePosInWindowY = self.mousePos.y - self.windowPos.y

  if self.mousePosInWindowX >= 0 and self.mousePosInWindowX <= self.windowSize.x
  and self.mousePosInWindowY >= 0 and self.mousePosInWindowY <= self.windowSize.y then
    -- Cursor inside window
    self.mouseInWindow = true

    -- Cursor inside graph
    self.mouseInGraph =
      self.mousePosInWindowX >= borderSize and self.mousePosInWindowX <= self.windowSize.x - borderSize
      and self.mousePosInWindowY >= borderSize and self.mousePosInWindowY <= self.windowSize.y - borderSize
  else
    self.mouseInWindow = false
    self.mouseInGraph = false
  end

  self:moveGraph(dt)
  self:zoomGraph(dt)

  if p then p:start() end

  self.size = im.ImVec2(width, height)
  self.innerSize = im.ImVec2(width-2*borderSize, height-2*borderSize)
  im.BeginChild1('curve_'..self.id, self.size)
  self.dl = im.GetWindowDrawList()
  self.screenPos = im.GetCursorScreenPos()
  self.btnPos = im.GetCursorPos()
  if p then p:add("imgui init") end

  -- drawList
  if not self.data then return end

  self:drawGridAndAxesLabels()
  if p then p:add("drawGridAndAxesLabels()") end

  self:drawData()
  if p then p:add("drawData()") end

  if self.showCatmullRomCurve then
    self:drawCatmullSpline()
    if p then p:add("drawCatmullSpline()") end
  end

  if p then p:finish(true) end

  im.EndChild()
end

-- From lua/vehicle/ve_utils.lua and modified to allow multiple y values
function C:generateCatmullSplinePoints(points, linesToDraw)
  -- For 2 or less points

  if #points < 2 then return end
  if #points == 2 then
    self.catmullDataPoints = points
    return
  end

  -- Else for 3 or more points

  local res = linesToDraw and table.new(linesToDraw + 1, 0) or {}

  local pointSize = #points

  for i = 1, pointSize - 1 do
    local p0, p1, p2, p3 = points[max(i - 1, 1)], points[i], points[i + 1], points[min(i + 2, pointSize)]

    local valsPerPoint = tableSize(p0)

    local step = 0
    local numSteps = 0

    if linesToDraw then
      step = (p2[1] - p1[1]) / linesToDraw
      numSteps = linesToDraw
    else
      step = 1
      numSteps = floor(p2[1] - p1[1])
    end

    for j = 1, valsPerPoint - 1 do
      self._cmT[j] = 0
      self._cmY0[j], self._cmY1[j], self._cmY2[j], self._cmY3[j] = p0[j + 1], p1[j + 1], p2[j + 1], p3[j + 1]
      self._cmC1[j] = 3*(self._cmY1[j] - self._cmY2[j]) + self._cmY3[j] - self._cmY0[j]
      self._cmC2[j] = 2*self._cmY0[j] - 5*self._cmY1[j] + 4*self._cmY2[j] - self._cmY3[j]
      self._cmC3[j] = self._cmY2[j] - self._cmY0[j]
    end

    for x = 0, numSteps do
      local vals = {p1[1] + x * step}

      for j = 1, valsPerPoint - 1 do
        vals[j + 1] = self._cmY1[j] + 0.5*self._cmT[j]*(self._cmC3[j] + (self._cmC1[j]*self._cmT[j] + self._cmC2[j])*self._cmT[j])
        self._cmT[j] = self._cmT[j] + (1 / numSteps)
      end

      res[#res + 1] = vals
    end
  end

  self.catmullDataPoints = res
end

function C:drawCatmullSpline()
  if not self.catmullDataPoints then return end

  for i = 1, tableSize(self.catmullDataPoints) - 1 do
    local p0 = self.catmullDataPoints[i]
    local p1 = self.catmullDataPoints[i + 1]

    local count = tableSize(p0)

    -- Allows for multiple y's for one x
    for i = 2, count do
      local color = rainbowColor(count - 1, i, 1)
      local theColor = im.GetColorU322(im.ImVec4(color[1], color[2], color[3], color[4]))

      local x0 = p0[1]
      local y0 = p0[i]
      local x1 = p1[1]
      local y1 = p1[i]

      if x0 and y0 and x1 and y1 then
        local pt0 = self:graphPtToImSS(x0, y0)
        local pt1 = self:graphPtToImSS(x1, y1)

        if pt0 and pt1 then
          im.ImDrawList_AddLine(self.dl, pt0, pt1, theColor, 1)
        end
      end
    end
  end
end

-- Draws the gridlines
function C:drawGridAndAxesLabels()
  -- Try to have roughly this many ticks
  local majorTicksX = 10
  local majorTicksY = 10

  local rangeX = self.scale.xMax - self.scale.xMin
  local rangeY = self.scale.yMax - self.scale.yMin

  -- Figure out the optimal increment to get closet to majorTicks
  -- increments of 1, 2, or 5 (in relation to magnitude of range)
  local incX = self:getOptimalTickIncrement(majorTicksX, rangeX)
  local incY = self:getOptimalTickIncrement(majorTicksY, rangeY)

  majorTicksX = rangeX / incX
  majorTicksY = rangeY / incY

  -- Draw Graph Border Outline
  im.ImDrawList_AddLine(self.dl, self:normToImSS(0,0), self:normToImSS(0,1), borderColor, 1)
  im.ImDrawList_AddLine(self.dl, self:normToImSS(0,1), self:normToImSS(1,1), borderColor, 1)
  im.ImDrawList_AddLine(self.dl, self:normToImSS(1,1), self:normToImSS(1,0), borderColor, 1)
  im.ImDrawList_AddLine(self.dl, self:normToImSS(1,0), self:normToImSS(0,0), borderColor, 1)

  local txt, txtSize

  -- Draw Vertical lines and labels
  for i = 0, majorTicksX do
    local graphX = i * incX + ceil(self.scale.xMin / incX) * incX

    local topPos = self:graphPtToImSS(graphX, self.scale.yMax, true)
    local botPos = self:graphPtToImSS(graphX, self.scale.yMin, true)

    im.ImDrawList_AddLine(self.dl, topPos, botPos, gridColor, 1)

    local txtPos = self:graphPtToImWS(graphX, self.scale.yMin)
    if txtPos then
      txt = tostring(abs(graphX))

      if #txt <= 5 then
        txt = tostring(graphX)
      else
        txt = string.format("%.3e", graphX)
      end
      txtSize = im.CalcTextSize(txt)

      txtPos.x = txtPos.x - txtSize.x / 2

      im.SetCursorPos(txtPos)
      im.TextColored(textColor, txt)
    end
  end

  -- Draw Horizontal Lines and labels
  for i = 0, majorTicksY do
    local graphY = i * incY + ceil(self.scale.yMin / incY) * incY

    local leftPos = self:graphPtToImSS(self.scale.xMax, graphY, true)
    local rightPos = self:graphPtToImSS(self.scale.xMin, graphY, true)

    im.ImDrawList_AddLine(self.dl, leftPos, rightPos, gridColor, 1)

    local txtPos = self:graphPtToImWS(self.scale.xMin, graphY)
    if txtPos then
      txt = tostring(abs(graphY))

      if #txt <= 5 then
        txt = tostring(graphY)
      else
        txt = string.format("%.3e", graphY)
      end

      txtSize = im.CalcTextSize(txt)

      txtPos.x = txtPos.x - txtSize.x - #txt / txtSize.x
      txtPos.y = txtPos.y - txtSize.y / 2

      im.SetCursorPos(txtPos)
      im.TextColored(textColor, txt)
    end
  end
end

-- Figure out the optimal increment to get closet to ticks
-- increments of 1, 2, or 5 (in relation to magnitude of range using incOneMagLess)
function C:getOptimalTickIncrement(ticks, range)
  local inc = range / ticks
  local rndInc = 10^self:getOrderOfMagnitude(inc)

  if abs(ticks - range / (rndInc * 10)) < abs(ticks - range / (rndInc * 5)) then
    return rndInc * 10
  elseif abs(ticks - range / (rndInc * 5)) < abs(ticks - range / (rndInc * 2)) then
    return rndInc * 5
  elseif abs(ticks - range / (rndInc * 2)) < abs(ticks - range / (rndInc * 1)) then
    return rndInc * 2
  else
    return rndInc * 1
  end
end

function C:drawData()
  local btnWidth = 10
  local btnSize = im.ImVec2(btnWidth,btnWidth)

  local j = 0

  for _, d in ipairs(self.data) do
    local count = tableSize(d)

    -- Allows for plotting multiple y's for one x
    for i = 2, count do
      local color = rainbowColor(count - 1, i, 1)
      local circleColor = im.GetColorU322(im.ImVec4(color[1], color[2], color[3], color[4]))

      local ptX = d[1]
      local ptY = d[i]

      local ptOnGraph = self:graphPtToImSS(ptX, ptY)

      -- nil means pt not visible
      if ptOnGraph then
        -- Draw point
        --ImDrawList_ctx, ImVec2_center, float_radius, ImU32_col, int_num_segments, float_thickness
        im.ImDrawList_AddCircle(self.dl, ptOnGraph, 4, circleColor, 8, 2)

        -- Draw Tooltip
        local ptOnGraphWS = self:graphPtToImWS(ptX, ptY)

        ptOnGraphWS.x = ptOnGraphWS.x - btnWidth / 2
        ptOnGraphWS.y = ptOnGraphWS.y - btnWidth / 2

        local strX = string.format("%0.3f", ptX)
        local strY = string.format("%0.3f", ptY)

        im.SetCursorPos(ptOnGraphWS)
        im.InvisibleButton('##pointTooltipButton'..j, btnSize)
        local name = "Series " .. (i - 1)
        if self.seriesNames then
          name = self.seriesNames[(i - 1)] or name
        end
        im.tooltip(name .. " (" .. strX .. ", " .. strY .. ")")

        j = j + 1
      end
    end
  end
end

-- Returns IMGUI coordinates (screen space) on graph from normalized coordinates
-- x,y = 0 : bottom left
-- x,y = 1 : top right
function C:normToImSS(x,y)
  return im.ImVec2(borderSize + self.screenPos.x + x * self.innerSize.x,  borderSize + self.screenPos.y + (1-y) * self.innerSize.y)
end

-- Returns IMGUI coordinates (screen space) on graph from graph coordinates
function C:graphPtToImSS(x,y, clampVal)
  local newX = (x - self.scale.xMin) / (self.scale.xMax - self.scale.xMin)
  local newY = (y - self.scale.yMin) / (self.scale.yMax - self.scale.yMin)

  if clampVal then
    newX = clamp(newX, 0, 1)
    newY = clamp(newY, 0, 1)
  end

  -- If point goes out of bounds of graph, return nil
  if newX > 1 or newY > 1 or newX < 0 or newY < 0 then
    return nil
  end

  return self:normToImSS(newX, newY)
end

-- Returns IMGUI coordinates (window space) on graph from normalized coordinates
-- x,y = 0 : bottom left
-- x,y = 1 : top right
function C:normToImWS(x,y)
  return im.ImVec2(borderSize + x * self.innerSize.x,  borderSize + (1-y) * self.innerSize.y)
end

-- Returns IMGUI coordinates (window space) on graph from graph coordinates
function C:graphPtToImWS(x,y)
  local newX = (x - self.scale.xMin) / (self.scale.xMax - self.scale.xMin)
  local newY = (y - self.scale.yMin) / (self.scale.yMax - self.scale.yMin)

  -- If point goes out of bounds of graph, return nil
  if newX > 1 or newY > 1 or newX < 0 or newY < 0 then
    return nil
  end

  return self:normToImWS(newX, newY)
end

function C:roundToDigits(num, dec)
  local multiple = 10^dec

  return floor(num * multiple + 0.5) / multiple
end

-- Returns exponent of num represented in scientific notation (a * 10^x, where x is returned)
function C:getOrderOfMagnitude(num)
  return floor(log10(abs(num)))
end

function C:scaleX(x) return self.scale.xMin + (self.scale.xMax - self.scale.xMin) * x end
function C:scaleY(y) return self.scale.yMin + (self.scale.yMax - self.scale.yMin) * y end

local idCounter = 0
return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o.id = idCounter
  idCounter = idCounter + 1
  o:init(...)
  return o
end