-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'imguiUtils'
local ffi = require("ffi")
local imgui = ui_imgui

local style = ffi.new('ImGuiStyle[1]')

function M.changeUIScale(uiscale)
  imgui.uiscale[0] = uiscale
  local io = imgui.GetIO(io)
  io.FontGlobalScale = imgui.uiscale[0]
end

function M.drawCursorPos(posX, posY)
  posX = posX or (imgui.GetWindowPos().x + imgui.GetCursorPosX())
  posY = posY or (imgui.GetWindowPos().y + imgui.GetCursorPosY())
  imgui.ImDrawList_AddLine(imgui.GetWindowDrawList(), imgui.ImVec2(posX - 4, posY), imgui.ImVec2(posX + 4, posY) , imgui.GetColorU322(imgui.ImVec4(1, 0, 0, 0.75)))
  imgui.ImDrawList_AddLine(imgui.GetWindowDrawList(), imgui.ImVec2(posX, posY - 4), imgui.ImVec2(posX, posY + 4) , imgui.GetColorU322(imgui.ImVec4(1, 0, 0, 0.75)))
end

function M.texObj(path)
  local res = {}
  res.file = string.match(path, "^.+/(.+)$")
  res.path = path
  res.tex = imgui.ImTextureHandler(path)
  res.texId = res.tex:getID()
  res.size = res.tex:getSize()
  return res
end

function M.DropdownItem(label, icon, func, tooltip)
  local item = {}
  item.label = label
  item.icon = icon
  item.func = func
  item.tooltip = tooltip
  return item
end

function M.DropdownSelectableItem(label, active, func, tooltip)
  local item = {}
  item.label = label
  item.active = active
  item.func = func
  item.tooltip = tooltip
  return item
end

function M.DropdownButton(label, size, items, icon, horizontal)
  local x = imgui.GetCursorPosX()
  local y = imgui.GetCursorPosY()
  local open_popup
  if not icon then
    open_popup = imgui.Button(label, size)
  else
    open_popup = editor.uiIconImageButton(icon, size, nil, nil, nil, label)
  end

  if #items == 0 then return end

  local windowPos = imgui.GetWindowPos()
  local popupPos = imgui.ImVec2(0,0)

  if not size then size = imgui.ImVec2(32 * imgui.uiscale[0], 32 * imgui.uiscale[0]) else size = imgui.ImVec2(size.x * imgui.uiscale[0], size.y * imgui.uiscale[0]) end

  if not horizontal then
    popupPos.x = x + windowPos.x - 8
    popupPos.y = y + windowPos.y + size.y * imgui.uiscale[0] + 4 - imgui.GetScrollY()
  else
    popupPos.x = x + windowPos.x + size.x * imgui.uiscale[0] + 4
    popupPos.y = y + windowPos.y - 8 - imgui.GetScrollY()
  end

  if open_popup == true then
    imgui.OpenPopup(label)
    return true
  end
  imgui.SetNextWindowPos(popupPos)
  imgui.SetNextWindowSize(imgui.ImVec2(0, 0), imgui.Cond_Always)
  if imgui.BeginPopup(label) then
    for k, item in pairs(items) do
      local lbl = item.label .. "###" .. label .. tostring(k)
      if not item.icon then
        if imgui.Button(lbl, size) then
          if item.func then item.func() end
          imgui.CloseCurrentPopup()
        end
      else
        if editor.uiIconImageButton(item.icon, imgui.ImVec2(size.x, size.y), nil, nil, nil, lbl) then
          if item.func then item.func() end
          imgui.CloseCurrentPopup()
        end
      end
      if item.tooltip and imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text(item.tooltip) imgui.EndTooltip() end
      if horizontal then imgui.SameLine() end
    end
    imgui.EndPopup()
  end
  return false
end

function M.DropdownSelectable(label, items, icon, iconSize, popupWidth, onChangeFunc, tooltip, itemsRMB)
  local x = imgui.GetCursorPosX()
  local y = imgui.GetCursorPosY()
  local open_popup
  local open_popup_rmb
  if not iconSize then iconSize = imgui.ImVec2(32 * imgui.uiscale[0], 32 * imgui.uiscale[0]) else iconSize = imgui.ImVec2(iconSize.x * imgui.uiscale[0], iconSize.y * imgui.uiscale[0]) end

  if not icon then
    open_popup = imgui.SmallButton(label)
  else
    open_popup = editor.uiIconImageButton(icon, iconSize, nil, nil, nil, label)
  end
  if itemsRMB and imgui.IsItemClicked(1) then
    open_popup_rmb = true
  end
  if tooltip then imgui.tooltip(tooltip) end

  if #items == 0 then return end

  local fontSize = imgui.GetFontSize()
  -- hardcoded for the time being
  -- 2 * (padding to border + border) + #items * (fontsize + item padding)
  local popupHeight = 2 * (5 + 1) + #items * 17

  local popupRMBHeight = 100
  if itemsRMB then
    popupRMBHeight = 2 * (5 + 1) + #itemsRMB * 17
  end

  local windowPos = imgui.GetWindowPos()

  local popupPos = imgui.ImVec2(0,0)

  popupPos.x = x + windowPos.x
  popupPos.y = y + windowPos.y + iconSize.y * imgui.uiscale[0] + 4 - imgui.GetScrollY()

  if open_popup == true then
    imgui.OpenPopup(label)
    return true
  end

  imgui.SetNextWindowPos(popupPos)
  imgui.SetNextWindowSize(imgui.ImVec2(0, 0), imgui.Cond_Always)
  if imgui.BeginPopup(label) then
    for k, item in pairs(items) do
      local curX = imgui.GetCursorPosX()
      if item.active[0] == true then
        editor.uiIconImage(editor.icons.done, imgui.ImVec2(14,14))
        imgui.SameLine()
      end
      imgui.SetCursorPosX(curX + 20 * imgui.uiscale[0])
      if imgui.Selectable1(item.label .. "##", nil, imgui.ImGuiSelectableFlags_DontClosePopups) then
        if item.active[0] == true then item.active[0] = false else item.active[0] = true end
        if onChangeFunc then onChangeFunc(item) end
        if item.func then item.func(item) end
      end
      if item.tooltip and imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text(item.tooltip) imgui.EndTooltip() end
    end
    imgui.EndPopup()
  end

  if open_popup_rmb == true then
    imgui.OpenPopup(label.."rmb")
  end

  imgui.SetNextWindowPos(popupPos)
  imgui.SetNextWindowSize(imgui.ImVec2(0, 0), imgui.Cond_Always)
  if imgui.BeginPopup(label.."rmb") then
    for k, item in pairs(itemsRMB) do
      if imgui.SmallButton(item.label.."##") then
        if item.func then item.func(item.args) end
        imgui.CloseCurrentPopup()
      end
      if item.tooltip and imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text(item.tooltip) imgui.EndTooltip() end
    end
    imgui.EndPopup()
  end
  return false
end

function M.DropdownSelect(label, size, selectedItem, items, horizontal, excludeCurrent)
  local x = imgui.GetCursorPosX()
  local y = imgui.GetCursorPosY()
  local open_popup
  local curItem = items[selectedItem[0]]
  if not curItem.icon then
    open_popup = imgui.Button(curItem.label .. "##" .. label, size)
  else
    open_popup = editor.uiIconImageButton(curItem.icon, size, nil, nil, nil, curItem.label)
  end

  local windowPos = imgui.GetWindowPos()
  local popupPos = imgui.ImVec2(0,0)

  if not size then size = imgui.ImVec2(32 * imgui.uiscale[0], 32 * imgui.uiscale[0]) else size = imgui.ImVec2(size.x * imgui.uiscale[0], size.y * imgui.uiscale[0]) end

  if not horizontal then
    popupPos.x = x + windowPos.x - 8
    popupPos.y = y + windowPos.y + size.y * imgui.uiscale[0] + 4 - imgui.GetScrollY()
  else
    popupPos.x = x + windowPos.x + size.x * imgui.uiscale[0] + 4
    popupPos.y = y + windowPos.y - 8 - imgui.GetScrollY()
  end

  if open_popup == true then
    imgui.OpenPopup(label)
    return true
  end
  imgui.SetNextWindowPos(popupPos)
  imgui.SetNextWindowSize(imgui.ImVec2(0, 0), imgui.Cond_Always)
  if imgui.BeginPopup(label) then
    for k, item in pairs(items) do
      if excludeCurrent then
        if k ~= selectedItem[0] then
          local lbl = item.label .. "##" .. label .. '_' .. tostring(k)
          if not item.icon then
            if imgui.Button(lbl, size) then
              selectedItem[0] = k
              if item.func then item.func() end
              imgui.CloseCurrentPopup()
            end
            imgui.tooltip(item.label)
          else
            if editor.uiIconImageButton(item.icon, imgui.ImVec2(size.x, size.y), nil, nil, nil, lbl) then
              selectedItem[0] = k
              if item.func then item.func() end
              imgui.CloseCurrentPopup()
            end
            imgui.tooltip(item.label)
          end
          if item.tooltip and imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text(item.tooltip) imgui.EndTooltip() end
          if horizontal then imgui.SameLine() end
        end
      else
        local lbl = item.label .. "##" .. label .. tostring(k)
        if not item.icon then
          if imgui.Button(lbl, size) then
            selectedItem[0] = k
            if item.func then item.func() end
            imgui.CloseCurrentPopup()
          end
          imgui.tooltip(item.label)
        else
          if editor.uiIconImageButton(item.icon, imgui.ImVec2(size.x, size.y), nil, nil, nil, lbl) then
            selectedItem[0] = k
            if item.func then item.func() end
            imgui.CloseCurrentPopup()
          end
          imgui.tooltip(item.label)
        end
        if item.tooltip and imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text(item.tooltip) imgui.EndTooltip() end
        if horizontal then imgui.SameLine() end
      end
    end
    imgui.EndPopup()
  end
  return false
end

-- check if a window with given pos and size is hovered
-- local windowPos = im.GetWindowPos()
-- local windowSize = im.GetWindowSize()
function M.IsWindowHovered(windowPos, windowSize)
  local mousePos = imgui.GetMousePos()
  if (mousePos.x > windowPos.x and mousePos.x < (windowPos.x + windowSize[0].x)) and (mousePos.y > windowPos.y and mousePos.y < (windowPos.y + windowSize[0].y)) then
    return true
  else
    return false
  end
end

-- displays key/values aof a lua table
function M.displayKeyValues(tbl)
  if tbl then
    for k,v in pairs(tbl) do
      if type(v) ~= 'table' then
        imgui.TextUnformatted(tostring(k) .. ' :')
        imgui.SameLine()
        imgui.TextUnformatted(tostring(v))
        -- imgui.Separator()
      else
        if imgui.TreeNode1(tostring(k)) then
          M.displayKeyValues(v)
          imgui.TreePop()
        end
      end
    end
  end
end

-- Creates a simple Key/Value app with a lua table
function M.CreateKeyValApp( window, section, tbl, callback )
  if imgui.Begin(window, imgui.BoolPtr(true), 0) then
    if imgui.TreeNode1(section) then
      -- call callback function when TreeNode is open
      if callback then callback() end
      M.displayKeyValues(tbl)
      imgui.TreePop()
    end
  end
  imgui.End()
end

local function itemCallback(begin, fullpath, k, val)
  if type(val) ~= 'table' then return end
  if begin then
    if val.active then
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.5, 1, 0.5, 1))
    else
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.6, 0.6, 0.6, 1))
    end
  else
    imgui.PopStyleColor()
  end
  return true
end

local function testTableRecursive(t)
  local primaryType = 0
  local tableType = 0
  for _, tv in pairs(t) do
    if type(tv) == 'table' then
      tableType = tableType + 1
    else
      primaryType = primaryType + 1
    end
  end
  return tableType > primaryType
end

local function getTableKeysSorted(t)
  local sortedKeys = {}
  for k in pairs(t) do table.insert(sortedKeys, k) end
  table.sort(sortedKeys)
  return sortedKeys
end

function M.keyValueTable(data, fullpath, highlightCallback, itemCallback)
  local sortedKeys = getTableKeysSorted(data)

  -- key value table for simplicity
  imgui.Columns(2, tostring(k))
  --imgui.SetColumnOffset(-1, 40)
  for _, k in ipairs(sortedKeys) do
    local val = data[k]
    local display = true
    local newPath = fullpath .. '/' .. tostring(k)

    if itemCallback then display = itemCallback(true, newPath, k, val) end

    if display then
      imgui.Text(tostring(k))
      imgui.NextColumn()
      M.addRecursiveTreeTable(val, newPath, true, highlightCallback, itemCallback)
      imgui.NextColumn()
    end

    if itemCallback then itemCallback(false, newPath, k, val) end

  end
  imgui.Columns(1)
end

local function renderSubTree(data, fullpath, highlightCallback, itemCallback)

  local sortedKeys = getTableKeysSorted(data)

  for _, k in ipairs(sortedKeys) do
    local val = data[k]
    local display = true
    local newPath = fullpath .. '/' .. tostring(k)

    if itemCallback then display = itemCallback(true, newPath, k, val) end

    if display then
      if imgui.TreeNode2(newPath, tostring(k)) then
        M.addRecursiveTreeTable(val, newPath, noColumns, highlightCallback, itemCallback)
        imgui.TreePop()
      end
      if highlightCallback and imgui.IsItemHovered() then
        highlightCallback(newPath, k, val)
      end
    end

    if itemCallback then itemCallback(false, newPath, k, val) end
  end
end
--[[
Returns the name and the value of the local variable with index local of the function
]]
local function getlocal(func)
  local index = 2
  local param = debug.getlocal( func, 1 )
  if not param then
    imgui.Text('NIL')
    return
  end
  while param ~= nil do
    imgui.Text(tostring(param))
    param = debug.getlocal( func, index )
    index = index + 1
  end

end
function M.addRecursiveTreeTable(data, fullpath, noColumns, highlightCallback, itemCallback)
  local _, level = string.gsub(fullpath, "%/", "")
  if type(data) == 'table' then
    local tsize = tableSize(data)
    if tsize == 0 then
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.7, 0.7, 0.7, 1))
      imgui.Text('{empty}')
      imgui.PopStyleColor()
    else
      if testTableRecursive(data) or noColumns then
        if level > 2 and tsize > 3 then
          if imgui.CollapsingHeader1(tostring(tsize)..' items##' .. fullpath) then
            renderSubTree(data, fullpath, highlightCallback, itemCallback)
          end
        else
          renderSubTree(data, fullpath, highlightCallback, itemCallback)
        end
      else
        M.keyValueTable(data, fullpath, highlightCallback, itemCallback)
      end
    end

  elseif type(data) == 'boolean' then
    if data then
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.7, 1, 0.7, 1))
    else
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(1, 0.7, 0.7, 1))
    end
    imgui.Text(tostring(data))
    imgui.PopStyleColor()

  elseif type(data) == 'number' then
    imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.7, 0.7, 1, 1))
    imgui.Text(tostring(data))
    imgui.PopStyleColor()

  elseif type(data) == 'string' then
    if string.len(data) == 0 then
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.7, 0.7, 0.7, 1))
      imgui.Text('{empty string}')
      imgui.PopStyleColor()
    else
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(1, 0.7, 1, 1))
      imgui.Text(tostring(data))
      imgui.PopStyleColor()
    end

  elseif type(data) == 'userdata' then
    -- implement some LuaIntF types
    local ctype = getmetatable(data).___type
    ctype = string.match(ctype, "class<([^>]*)>")
    if ctype == 'float3' then
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.7, 1, 1, 1))
      imgui.Text(string.format('float3(%g,%g,%g)', data.x, data.y, data.z))
      imgui.PopStyleColor()
    else
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.7, 0.8, 0.5, 1))
      imgui.Text('class instance: ' .. tostring(ctype))
      imgui.PopStyleColor()
    end
  elseif type(data) == 'function' then
      imgui.PushStyleColor2(imgui.Col_Text, imgui.ImVec4(0.7, 0.6, 0.4, 1))
      getlocal(data)
      imgui.PopStyleColor()
  else
    imgui.Text(tostring(data))
  end
end

function M.cell(a, b)
  imgui.Text(a)
  imgui.NextColumn()
  imgui.Text(b)
  imgui.NextColumn()
end

local function pointToLine(nodePos,startPos,endPos)
  local v = vec3(endPos - startPos)
  local w = vec3(nodePos - startPos)
  local c1 = w:dot(v)
  local c2 = v:dot(v)
  local b = c1/c2
  local p = startPos + b * v
  return nodePos:distance(p) --nodePos:distanceToLine(startPos,endPos)
end

--== ValueSampler ==--
local ValueSampler = {}
ValueSampler.__index = ValueSampler

-- creation method of the object, inits the member variables
local function newValueSampler(sampleTimeInSeconds, startingValue)
  if sampleTimeInSeconds == nil then sampleTimeInSeconds = 1 end
  local data = {
    timer = hptimer(),
    time = 0,
    st = startingValue or 0,
    minVal = math.huge,
    maxVal = -math.huge,
    sampleTime = sampleTimeInSeconds,
  }
  setmetatable(data, ValueSampler)
  return data
end

function ValueSampler:get(sample)
  self.time = self.time + (self.timer:stopAndReset() / 1000)
  self.minVal = math.min(self.minVal, sample)
  self.maxVal = math.max(self.maxVal, sample)
  if self.time >= self.sampleTime then
    self.time = self.time - self.sampleTime
    self.st = sample
  end
  return self.st, self.minVal, self.maxVal
end

function ValueSampler:reset()
  self.minVal = math.huge
  self.maxVal = -math.huge
  self.st = 0
  self.time = 0
end

M.sampleFloatDisplayState = {}
local dataPlotLen = 300
local dataPlot = ffi.new("float[" .. dataPlotLen .. "]", 0)
local offset = 0
local dataTbl = {}
local sampleTbl ={}
--local flag = false
function M.CreateSampleFloatDisplay(sampleTimeInSeconds, startingValue, precision)
  local res = newValueSampler(sampleTimeInSeconds, startingValue)
  res.precision = precision or 6
  res.draw = function(self, newValue)
    local sampledVal, minVal, maxVal = self:get(newValue)
      table.insert(sampleTbl,sampledVal)
      dataPlot[offset] = sampleTbl[offset+1]
      offset = offset + 1
      if offset >= dataPlotLen then
        offset =0
        sampleTbl = {}
      end
    --if not M._monospaceFontReference then
    --  -- assumes font 2 is monospaced
    --  local f = ffi.cast("ImFont*", imgui.GetIO().Fonts.Fonts.Data) -- Data is an ImVector, so do some pointer math
    --  print('font 1: ' .. tostring(f))
    --  f = f + ffi.sizeof('ImFont') -- second font
    --  print('font 2: ' .. tostring(f))
    --  M._monospaceFontReference = f
    --end
    --imgui.PushItemWidth(120) -- TODO: de-hardcode
    --imgui.PushFont(M._monospaceFontReference)
    local formatString = "%0." .. tostring(self.precision) .. "f"
    imgui.Text(formatString, sampledVal)
    if imgui.IsItemClicked(1) then
     self:reset()
    end
    --[[if imgui.IsItemClicked(0) then
     flag = not flag
    end--]]

    if imgui.IsItemHovered() then
      imgui.BeginTooltip()
      imgui.TextUnformatted("Last: " .. string.format(formatString, newValue))
      imgui.TextUnformatted("Sampled: " .. string.format(formatString, sampledVal))
      imgui.TextUnformatted("Min: " .. string.format(formatString, minVal))
      imgui.TextUnformatted("Max: " .. string.format(formatString, maxVal))
      imgui.TextUnformatted("Update interval: " .. string.format('%0.1f', self.sampleTime) .. 's')
      imgui.Separator()
      imgui.TextUnformatted("- right click to reset")
      imgui.TextUnformatted("- PageUp/Down to change interval")
      imgui.EndTooltip()
      if imgui.IsKeyPressed(imgui.GetKeyIndex(imgui.Key_PageUp)) then
        self.sampleTime = self.sampleTime + 0.05
      elseif imgui.IsKeyPressed(imgui.GetKeyIndex(imgui.Key_PageDown)) then
        self.sampleTime = math.max(0, self.sampleTime - 0.05)
      end
    end
    --imgui.PopFont(M._monospaceFontReference)
    --[[if flag then
      if imgui.BeginChild1("plot", imgui.ImVec2(0,130), true) then
        imgui.PlotLines1("",dataPlot, dataPlotLen, offset, "", FLT_MAX, FLT_MAX, imgui.ImVec2(300, 100))
        imgui.EndChild()
      end
    end--]]
  end
  return res
end
--imguiUtils.SampleFloatDisplay('engineLoad' .. device.name, device.engineLoad, 0.8)
function M.SampleFloatDisplay(id, value, sampleTimeInSeconds, precision)
  local id = imgui.GetID1(id)
  if not M.sampleFloatDisplayState[id] then
    M.sampleFloatDisplayState[id] = M.CreateSampleFloatDisplay(sampleTimeInSeconds, value, precision)
  end
  table.insert(dataTbl,value)
  M.sampleFloatDisplayState[id]:draw(value)
end

return M