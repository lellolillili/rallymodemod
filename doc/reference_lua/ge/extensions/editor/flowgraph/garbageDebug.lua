-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}
C.windowName = 'fg_garbage'
C.windowDescription = 'Garbage Debug'
local disabledColor = im.ImVec4(0.5,0.5,0.5,1)

function C:attach(mgr)
  self.mgr = mgr

end
local colorPerMagnitude = {}

function C:init()
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
  local maxMag = 20
  for i = 1, maxMag do
    colorPerMagnitude[i] = im.ImVec4(clamp(2*i/maxMag,0,1), clamp(2*(1-(i/maxMag)),0,1), 0,1)
  end
end

function C:computeStats(entry)
  local newHistory, newTotalHistory = {}, {}
  local lastTotal = entry.totalHistory[1] or 0
  local activeList = {}
  local existingEntries = 0
  local changeSorted = {}
  for i = 1, self.mgr.garbageData.frames or 1 do
    activeList[i] = entry.history[i] and math.huge or -math.huge
    existingEntries = existingEntries + (entry.history[i] and 1 or 0)
    newHistory[i] = entry.history[i] or 0
    newTotalHistory[i] = entry.totalHistory[i] or lastTotal
    lastTotal = newTotalHistory[i]
    if entry.history[i] then
      table.insert(changeSorted, entry.history[i])
    end
  end
  if existingEntries > 10 then
    entry.averageChange = round(entry.total / (existingEntries + 10e-10))
    table.sort(changeSorted)
    entry.q25 = changeSorted[clamp(round(existingEntries*0.25), 1 , existingEntries)]
    entry.q50 = changeSorted[clamp(round(existingEntries*0.50), 1 , existingEntries)]
    entry.q75 = changeSorted[clamp(round(existingEntries*0.75), 1 , existingEntries)]
    entry.q90 = changeSorted[clamp(round(existingEntries*0.90), 1 , existingEntries)]
  end
  entry.activePercent = existingEntries / self.mgr.garbageData.frames
  entry.activeCount = existingEntries
  entry.activeList = activeList
  entry.totalHistory = newTotalHistory
  entry.history = newHistory
  entry.minChange, entry.maxChange = 0,0
  entry.minTotal, entry.maxTotal = 0,0
  entry.historyLength = #(entry.history or {})
  for _, h in ipairs(entry.history or {}) do
    entry.minChange = math.min(entry.minChange, h)
    entry.maxChange = math.max(entry.maxChange, h)
  end
  for _, h in ipairs(entry.totalHistory or {}) do
    entry.minTotal = math.min(entry.minTotal, h)
    entry.maxTotal = math.max(entry.maxTotal, h)
  end



end

function C:setSortingValue(entry)
  entry.value = entry[self.valueKey] or -1
  entry.valueMagnitude = 1
  while entry.value > 2^entry.valueMagnitude do
    entry.valueMagnitude = entry.valueMagnitude + 1
  end

end

local valueKeys = {'total','averageChange','maxChange','q25','q50','q75','q90','activeCount'}
local valueLabels = {
  total = "Total Allocation over all Frames",
  averageChange = "Average Allocation per active Frame",
  maxChange = "Highest single Allocation per active Frame",
  q25 = "25%-Quantile Allocated per active Frame",
  q50 = "50%-Quantile Allocated per active Frame",
  q75 = "75%-Quantile Allocated per active Frame",
  q90 = "90%-Quantile Allocated per active Frame",
  activeCount = "Active Frame Count",
}
local valueUnits = {
  activeCount = "Frames"
}

function C:computeAllStats()
  if not self.mgr.garbageData.statsComputed then
    self.mgr.garbageData.statsComputed = true

    for id, gr in pairs(self.mgr.garbageData.graphs) do self:computeStats(gr) gr.meta = {type = "graph", graph = self.mgr.graphs[id]} end
    for id, n  in pairs(self.mgr.garbageData.nodes) do self:computeStats(n) n.meta = {type = "node", node = self.mgr.graphs[n.graphId].nodes[id]} end

    local graphSum = {
      total = 0,
      history = {},
      totalHistory = {}
    }
    for _, gr in pairs(self.mgr.garbageData.graphs) do
      graphSum.total = graphSum.total + gr.total
      for k, v in ipairs(gr.history) do graphSum.history[k] = (graphSum.history[k] or 0) + v end
      for k, v in ipairs(gr.totalHistory) do graphSum.totalHistory[k] = (graphSum.totalHistory[k] or 0) + v end
    end
    self:computeStats(graphSum)
    self.mgr.garbageData.graphSum = graphSum
  end

  if not self.mgr.garbageData.sorted then
    self.mgr.garbageData.sorted = true
    self.valueKey = editor.getPreference("flowgraph.debug.garbageSort")
    self.valueUnit = valueUnits[self.valueKey] or " Bytes"
    self.maxValue = 0
    for _, gr in pairs(self.mgr.garbageData.graphs) do self:setSortingValue(gr) end
    for _, n  in pairs(self.mgr.garbageData.nodes) do self:setSortingValue(n) end
    self:setSortingValue(self.mgr.garbageData.graphSum)
    local graphIdsSortedByTotalGarbage = tableKeys(self.mgr.garbageData.graphs or {})
    table.sort(graphIdsSortedByTotalGarbage, function(a,b) return self.mgr.garbageData.graphs[a].value > self.mgr.garbageData.graphs[b].value end)

    local nodeIdsSortedByTotalGarbage = tableKeys(self.mgr.garbageData.nodes or {})
    table.sort(nodeIdsSortedByTotalGarbage, function(a,b) return self.mgr.garbageData.nodes[a].value > self.mgr.garbageData.nodes[b].value end)

    self.mgr.garbageData.graphIdsSortedByTotalGarbage = graphIdsSortedByTotalGarbage
    self.mgr.garbageData.nodeIdsSortedByTotalGarbage = nodeIdsSortedByTotalGarbage
  end
end

local whiteColor = im.ImColorByRGB(255,255,255,255)
local orangeColor = im.ImColorByRGB(255,128,0,255)
local blueColor = im.ImColorByRGB(128,220,255,128)

local scale = 1
function C:drawStats(label, entry)
  if not entry or entry.value == -1 or entry.activeCount == 0 then return end
  scale = editor.getPreference("ui.general.scale")
  im.PushID1(label)
  local flags = bit.bor(im.WindowFlags_NoScrollbar, im.WindowFlags_NoScrollWithMouse)
  local winWidth = im.GetContentRegionAvailWidth()
  local fillPercent = 0.33
  im.BeginChild1(label.."Child", im.ImVec2(winWidth, scale*(24)+16), true, (not entry.expanded) and flags)

  if entry.meta and entry.meta.type == 'node' then
    local node = entry.meta.node
    local icon = node.customIcon or node.icon
    if icon and editor.icons[icon] then
      editor.uiIconImage(editor.icons[icon], im.ImVec2(20,20), node.customIconColor or node.iconColor)
      im.SameLine()
    end
  end
  im.Text(label)
  im.PushFont2(1)
  local valueText = tostring(entry.value) .. " " .. self.valueUnit
  local valueTextSize = im.CalcTextSize(valueText)
  im.SameLine()
  im.SetCursorPosX(winWidth - (valueTextSize.x + 16))

  im.TextColored(colorPerMagnitude[entry.valueMagnitude] or colorPerMagnitude[10], valueText)
  im.PopFont()
  im.EndChild()
  if im.IsItemHovered() and im.IsMouseReleased(0) then
    entry.expanded = not (entry.expanded or false)
  end
  if entry.expanded then
    if entry.historyLength > 0 then
      self:handleMeta(entry)
      if not im.IsWindowFocused(im.FocusedFlags_RootAndChildWindows) then im.BeginDisabled() end
      im.Text("Total")
      im.PlotMultiLines("Total##total"..label, 2, {"Total","Active"}, {whiteColor,blueColor}, {entry.totalHistory, entry.activeList}, self.mgr.garbageData.frames, "", entry.minTotal, entry.maxTotal, im.ImVec2(im.GetContentRegionAvailWidth(),100))
      im.Text(string.format("Change | Avg: %d | Q25: %d | Q75: %d | Q90: %d   | (only active)", entry.averageChange or -1, entry.q25 or -1, entry.q50 or -1, entry.q75 or -1))
      im.PlotMultiLines("Change##change"..label, 2, {"Change","Active"}, {orangeColor,blueColor}, {entry.history, entry.activeList}, self.mgr.garbageData.frames, "", -0.25 * entry.maxChange, entry.maxChange, im.ImVec2(im.GetContentRegionAvailWidth(),100))
      if not im.IsWindowFocused(im.FocusedFlags_RootAndChildWindows) then im.EndDisabled() end
    else
      im.Text("No History!")
    end
  end
  im.PopID()
end


function C:handleMeta(e)
  if not e.meta then return end
  if e.meta.type == 'node' and e.meta.node then
    if im.Button("View Node##".. e.meta.node.name.."/"..e.meta.node.id, im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
      self.mgr:selectGraph(e.meta.node.graph)
      self.mgr:unselectAll()
      ui_flowgraph_editor.SelectNode(e.meta.node.id, false)
      e.meta.node.graph.focusSelection = true
      e.meta.node.graph.focusDelay = 1
    end
  end

  if e.meta.type == 'graph' and e.meta.graph then
    if im.Button("View Graph##" ..e.meta.graph.name.."/"..e.meta.graph.id, im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
      self.mgr:unselectAll()
      self.mgr:selectGraph(e.meta.graph)
      e.meta.node.graph.focusContent = true
      e.meta.node.graph.focusDelay = 1
    end
  end
end

function C:draw()
  if not editor.isWindowVisible(self.windowName) then return end
  self:Begin(self.windowDescription)
  im.SameLine()
  local debugEnabled = editor.getPreference("flowgraph.debug.debugGarbage") or false
  if im.Checkbox('Debug Garbage', im.BoolPtr(debugEnabled)) then
    debugEnabled = not debugEnabled
    editor.setPreference("flowgraph.debug.debugGarbage", debugEnabled)
  end

  local show = self.mgr.garbageData
  if show then
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if im.BeginCombo("garbageSort","Sort by: " .. valueLabels[editor.getPreference("flowgraph.debug.garbageSort")]) then
      for _, key in ipairs(valueKeys) do
        if im.Selectable1(valueLabels[key], key == editor.getPreference("flowgraph.debug.garbageSort")) then
          editor.setPreference("flowgraph.debug.garbageSort", key)
          self.mgr.garbageData.sorted = false
        end
      end
      im.EndCombo()
    end
    im.PopItemWidth()
    self:computeAllStats()
    im.Spacing()
    im.Separator()
    im.Spacing()
    self:drawStats("Complete Project", self.mgr.garbageData.graphSum)
    im.Spacing()
    im.Separator()
    im.Spacing()
    for _, grId in ipairs(self.mgr.garbageData.graphIdsSortedByTotalGarbage or {}) do
      local graph = self.mgr.graphs[grId]
      local entry = self.mgr.garbageData.graphs[grId]
      local label = graph:getLocation(editor.getPreference("flowgraph.debug.displayIds"))
      self:drawStats(label, entry)
    end
    im.Spacing()
    im.Separator()
    im.Spacing()
    for _, nId in ipairs(self.mgr.garbageData.nodeIdsSortedByTotalGarbage or {}) do
      local entry = self.mgr.garbageData.nodes[nId]
      local node = self.mgr.graphs[entry.graphId].nodes[nId]
      if node then
        local nLabel = string.format("%s (%d)", node.name, node.id, entry.value or -1)
        self:drawStats(nLabel, entry)
      end
    end
  else
    im.Text("Info only shows after running.")
  end

  self:End()
end

function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

return _flowgraph_createMgrWindow(C)
