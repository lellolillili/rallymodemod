-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}
C.windowName = 'fg_events'
C.windowDescription = 'Event Log'
local colWhite = im.ImVec4(1,1,1,1)
local logColors = {
  D = im.ImVec4(0.12,0.75,1,1), I = im.ImVec4(0.3,1,0.3,1), W = im.ImVec4(1,1,0,1), E = im.ImVec4(1,0.2,0.2,1), S = im.ImVec4(0.8, 0.8, 1, 1), T = im.ImVec4(0.75, 0.75, 0.9, 1)
}
local logNames = {
  D = "Debug", I = "Info", W = "Warning", E = "Error", S = "States"
}
function C:attach(mgr)
  self.mgr = mgr
end

function C:init()
    editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
end

local function formatTime(time)
  return string.format("%d:%02d:%03d",time/60, time%60, (time%1)*1000)
end

function C:drawContent()
  local hideDuplicates = editor.getPreference("flowgraph.general.hideDuplicateEvents")
  if im.Checkbox('Hide Duplicates', im.BoolPtr(hideDuplicates)) then
    hideDuplicates = not hideDuplicates
    editor.setPreference("flowgraph.general.hideDuplicateEvents", hideDuplicates)
  end
  im.SameLine()
  im.PushItemWidth(100)
  local timeFormat = editor.getPreference("flowgraph.general.eventTimeFormat")
  if im.BeginCombo("Time Format", timeFormat) then
    for _, format in ipairs({'Project Time','Global Time','Frame'}) do
      if im.Selectable1(format, format == timeFormat) then
        timeFormat = format
        editor.setPreference("flowgraph.general.eventTimeFormat", format)
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()
  im.SameLine()
  local autoScroll = editor.getPreference("flowgraph.general.eventAutoScroll")
  if im.Checkbox('Auto Scroll', im.BoolPtr(autoScroll)) then
    autoScroll = not autoScroll
    editor.setPreference("flowgraph.general.eventAutoScroll", autoScroll)
  end
  im.PopItemWidth()
  local avail = im.GetContentRegionAvail()
  im.Columns(3)
  im.SetColumnWidth(0, 86)
  im.SetColumnWidth(1, 30)
  if timeFormat == 'Frame' then
    im.Text("Frame")
  else
    im.Text("Time")
  end
  im.NextColumn()
  im.Text("")
  im.NextColumn()
  im.Text("Event")
  im.Columns(1)
  im.BeginChild1("eventLogChild", im.ImVec2(avail.x-1, avail.y -24))

  im.Columns(3)
  im.SetColumnWidth(0, 80)
  im.SetColumnWidth(1, 30)
  for i, e in ipairs(self.mgr.events) do
    if  hideDuplicates and  e.isDuplicate then

    else
      if timeFormat == 'Project Time' then
        im.Text(formatTime(e.time - self.mgr.startTime))
      elseif timeFormat == 'Global Time' then
        im.Text(e.globalTime)
      elseif timeFormat == 'Frame' then
        im.Text(e.frame.."")
      end
      ui_flowgraph_editor.tooltip("Project Time: " ..formatTime(e.time - self.mgr.startTime))
      ui_flowgraph_editor.tooltip("Global Time: " .. e.globalTime)
      ui_flowgraph_editor.tooltip("Frame: " .. dumps(e.frame))
      im.NextColumn()
      im.TextColored(logColors[e.type] or colWhite, e.type)
      ui_flowgraph_editor.tooltip(logNames[e.type] or e.type)
      im.NextColumn()
      local name = e.name
      if hideDuplicates and e.duplicates then
        name = e.name.. " (x" .. e.duplicates..")"
      end
      im.TextColored(logColors[e.type] or colWhite, name)

      if e.meta then
        self:handleMeta(e)
      end
      im.NextColumn()
      if e.description and e.description ~= "" then
        ui_flowgraph_editor.tooltip(e.description)
      end
    end
  end
  im.Columns(1)
  if self.mgr._newEvent then
    self.mgr._newEvent = nil
    if autoScroll then
      im.SetScrollY(im.GetScrollMaxY())
    end
  end
  im.EndChild()
end

function C:draw()
  if not editor.isWindowVisible(self.windowName) then return end
  self:Begin('Event Log')
  self:drawContent()
  self:End()
end

function C:handleMeta(e)
  if e.meta.type == 'node' and e.meta.node then
    ui_flowgraph_editor.tooltip("Double Click to jump to " .. e.meta.node.name.."/"..e.meta.node.id)
    if im.IsItemHovered() and im.IsMouseDoubleClicked(0) then
      self.mgr:selectGraph(e.meta.node.graph)
      self.mgr:unselectAll()
      ui_flowgraph_editor.SelectNode(e.meta.node.id, false)
      e.meta.node.graph.focusSelection = true
      e.meta.node.graph.focusDelay = 1
    end
  end

  if e.meta.type == 'graph' and e.meta.graph then
    ui_flowgraph_editor.tooltip("Double Click to jump to " .. e.meta.graph.name.."/"..e.meta.graph.id)
    if im.IsItemHovered() and im.IsMouseDoubleClicked(0) then
      self.mgr:unselectAll()
      self.mgr:selectGraph(e.meta.graph)
      e.meta.node.graph.focusContent = true
      e.meta.node.graph.focusDelay = 1

    end
  end
end

function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

return _flowgraph_createMgrWindow(C)
