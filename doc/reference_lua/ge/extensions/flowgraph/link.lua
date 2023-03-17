-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

function C:init(graph, sourcePin, targetPin)
  self.graph = graph
  self.id = self.graph.mgr:getNextFreePinLinkId()
  self.hiddenId = self.graph.mgr:getNextFreePinLinkId()
  if self.graph.mgr.__safeIds then
    if self.graph.mgr:checkDuplicateId(self.id) then
      log("E","","Duplicate ID error! Link")
      print(debug.tracesimple())
    end
  end
    if self.graph.mgr.__safeIds then
    if self.graph.mgr:checkDuplicateId(self.hiddenId) then
      log("E","","Duplicate ID error! Link")
      print(debug.tracesimple())
    end
  end

  self.sourcePin = sourcePin
  self.targetPin = targetPin
  self.sourceNode = sourcePin.node
  self.targetNode = targetPin.node

  self.data = {}

  self.hidden = false
  self.disabled = false

  -- DEBUG print:
  --print('new link from node ' .. self.sourceNode.graph.id .. '.' .. self.sourceNode.id .. '.' .. self.sourcePin.id ..' > ' .. self.targetNode.graph.id .. '.' .. self.targetNode.id .. '.' .. self.targetPin.id )
  if targetPin.type == 'flow' then
    local mFlow = self.targetNode._mInFlow
    mFlow[targetPin.name] = mFlow[targetPin.name] or {}

    if self.targetNode.pinIn[targetPin.name] == nil then
      table.clear(mFlow[targetPin.name])
    end

    table.insert(mFlow[targetPin.name], sourcePin)
  end

  rawset(self.targetNode.pinIn, targetPin.name, sourcePin)
  self.graph.links[self.id] = self

  self.sourcePin:_onLink(self)
  self.targetPin:_onLink(self)
  self.sourceNode:_onLink(self)
  self.targetNode:_onLink(self)
  self.color = ui_flowgraph_editor.getTypeColor(sourcePin.type)
  if sourcePin.impulse then
    self.color = ui_flowgraph_editor.getTypeColor('impulse')
  end
  if sourcePin.chainFlow then
    self.color = ui_flowgraph_editor.getTypeColor('chainFlow')
  end
  --self.label = "Label"
--  if sourcePin.type == 'state' and targetPin.type == 'state' then
--    self.type =
end

function C:drawLinkTooltip()
  ui_flowgraph_editor.Suspend()
  -- Push style changes
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(5, 5))
  im.PushStyleColor2(im.Col_Separator, im.ImVec4(1.0, 1.0, 1.0, 0.175))
  if self.graph.mgr.runningState ~= "running" then
    im.PushStyleColor2(im.Col_Border, im.ImVec4(1.0, 1.0, 1.0, 0.25))
  end
  im.BeginTooltip()
  self.graph.mgr:DrawTypeIcon(self.sourcePin.type, true, 1)
  im.SameLine()
  im.TextUnformatted(dumps(self.sourcePin.type))
  ui_flowgraph_editor.fullDisplay(self.sourcePin._value, self.sourcePin.hardCodeType and self.sourcePin.hardCodeType or self.sourcePin.type)
  --im.TextUnformatted(dumps(self.sourcePin._frameLastUsed))
  im.EndTooltip()
  -- Pop style changes
  im.PopStyleVar()
  im.PopStyleColor()
  if self.graph.mgr.runningState ~= "running" then
    im.PopStyleColor()
  end
  ui_flowgraph_editor.Resume()
end

function C:getDirPins()
  if not self.targetNode.nodePosition or not self.sourceNode.nodePosition then return nil, nil end
  local dX, dY = self.targetNode.nodePosition[1] - self.sourceNode.nodePosition[1], self.targetNode.nodePosition[2] - self.sourceNode.nodePosition[2]
  if math.abs(dX) > math.abs(dY) then
    if dX > 0 then
      return 'E','W'
    else
      return 'W','E'
    end
  else
    if dY > 0 then
      return 'S','N'
    else
      return 'N','S'
    end
  end

end

function C:draw()

  local drawAsShortcut = self.hidden -- TODO: improve me to only draw with long lines

  local label = '<' .. tostring(self.sourcePin.accessName or self.sourcePin.name) .. '>'

  local sId, tId, sPin, tPin = self.sourcePin.id, self.targetPin.id, nil, nil
  if self.targetPin.type == 'state' then
    local d1, d2 = self:getDirPins()
    if d1 and d2 then
      sPin, tPin = self.sourceNode.transitionPins._out[d1], self.targetNode.transitionPins._in[d2]
      sId, tId = sPin.id, tPin.id
    end
  end

  ui_flowgraph_editor.Link(self.id, sId, tId, self.color, 2 * im.uiscale[0], drawAsShortcut, label)
  if self._highlight then
    ui_flowgraph_editor.Link(self.hiddenId, sId, tId, im.ImVec4(self.color.x, self.color.y, self.color.z, 0.6), 10, false, label)
    self._highlight = false
  end

  if ui_flowgraph_editor.GetHotObjectId() == self.id then
    if editor_flowgraphEditor.allowTooltip then
      self:drawLinkTooltip()
    end
  end
  if drawAsShortcut then
    return
  end
  -- StyleColor_Flow, StyleColor_FlowMarker
  -- StyleVar_FlowMarkerDistance, StyleVar_FlowSpeed, StyleVar_FlowDuration, StyleVar_FlowMarkerSize
  local flowing
  local markerColor = self.color
  if self.sourcePin.type == 'flow' or self.sourcePin.type == 'state' then
    flowing = self.sourcePin.value and self.targetNode._frameLastUsed == self.graph.mgr.frameCount
    ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_FlowMarkerDistance, 40)
    ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_FlowMarkerSize, 4)
  else
    flowing = self.sourcePin._frameLastUsed and self.sourcePin._frameLastUsed == self.graph.mgr.frameCount
    ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_FlowMarkerDistance, 10)
    ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_FlowMarkerSize, 1)
    markerColor = im.ImVec4(self.color.x * 0.5, self.color.y * 0.5, self.color.z * 0.5, self.color.w)
  end
  if self.graph.mgr.runningState == "stopped" then
    flowing = false
  end
  if self.graph.mgr.runningState == "paused" then
    ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_FlowSpeed, 0) --(1 / (self.graph.mgr.frameCount - self.sourcePin._frameLastUsed + 1)) * 30)
  else
    ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_FlowSpeed, 30) --(1 / (self.graph.mgr.frameCount - self.sourcePin._frameLastUsed + 1)) * 30)
  end
  ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_FlowDuration, 0.5)
--  ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_FlowMarkerDistance, 5)

  ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_Flow, self.color)
  ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_FlowMarker, markerColor)

  if flowing or self._queueFlow then
    ui_flowgraph_editor.Flow(self.id)
    self._queueFlow = nil
  end

  ui_flowgraph_editor.PopStyleVar(4)
  ui_flowgraph_editor.PopStyleColor(1)
  if self.sourcePin and self.sourcePin.type == 'state' and sPin and tPin then
    self.label = self.sourcePin.name
    self:drawLabel(sPin, tPin)
  end
  self.used = false
end

function C:doFlow()
  self._queueFlow = true
end

function C:drawLabel(sPin, tPin)
  if sPin.imPos and tPin.imPos then
    --ui_flowgraph_editor.Suspend()
    local txtSize = im.CalcTextSize(self.label)
    txtSize.x = txtSize.x + 6
    txtSize.y = txtSize.y + 6
    local center = im.ImVec2((sPin.imPos.x + tPin.imPos.x)/2+8,(sPin.imPos.y + tPin.imPos.y)/2+8)
    local off = im.GetWindowPos()
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(),
      im.ImVec2(center.x - txtSize.x/2 + off.x, center.y - txtSize.y/2 + off.y),
      im.ImVec2(center.x + txtSize.x/2 + off.x, center.y + txtSize.y/2 + off.y),
      im.GetColorU322(im.ImVec4(0.3, 0.3, 0.3, 1)), 3
      )
    im.ImDrawList_AddRect(im.GetWindowDrawList(),
      im.ImVec2(center.x - txtSize.x/2 + off.x, center.y - txtSize.y/2 + off.y),
      im.ImVec2(center.x + txtSize.x/2 + off.x, center.y + txtSize.y/2 + off.y),
      im.GetColorU322(im.ImVec4(self.color.x, self.color.y, self.color.z, 0.6)), 3, nil , 2
      )
    im.SetCursorPos(im.ImVec2(center.x - txtSize.x/2+3, center.y - txtSize.y/2+3))
    im.Text(self.label)
    --ui_flowgraph_editor.Resume()
  else
    print("? no imPos!")
    dumpz(sPin, 2)
    dumpz(tPin, 2)
  end
end

function C:showContextMenu(menuPos)
  im.SetWindowFontScale(editor.getPreference("ui.general.scale"))
  if im.MenuItem1("Toggle Hide") then
    self.hidden = not self.hidden
  end
  if self.graph.mgr.allowEditing then
    if im.MenuItem1("Delete") then
      self.graph.mgr:deleteSelection()
      self.graph.mgr.fgEditor.addHistory("Deleted Link from " .. self.sourcePin.name .. " to " .. self.targetPin.name)
    end
  end
  if editor.getPreference("flowgraph.debug.displayIds") then
    im.Separator()
    im.Text("id: %s", tostring(self.id))
    im.Text("From: %s", tostring(self.sourcePin.id))
    im.Text("To: %s", tostring(self.targetPin.id))
  end
end

function C:convertToQuickAccess()
  local sourcePin = self.sourcePin
  local targetPins = {}
  for _, link in pairs(self.graph.links) do
    if link.sourcePin == sourcePin then
      table.insert(targetPins, link.targetPin)
    end
  end
  local originalName = sourcePin.name
  local name = originalName
  local nameOK = false
  local iter = 1
  while not nameOK do
    local foundName = false
    for _, node in pairs(self.graph.nodes) do
      for _, pin in pairs(node.pinList) do
        if pin.quickAccess and pin.accessName == name then
          foundName = true
        end
      end
    end
    nameOK = not foundName
    if foundName then
      name = originalName .. iter
    end
    iter = iter +1
  end

  sourcePin.quickAccess = true
  sourcePin.accessName = name
  for _,pin in pairs(targetPins) do
    pin.quickAccess = true
    pin.accessName = name
  end
  self.graph.mgr:deleteSelection()
end

function C:__onSerialize()
  return {
    self.sourceNode.id,
    self.sourcePin.name,
    self.targetNode.id,
    self.targetPin.name,
    self.hidden
  }
end

function C:__onDeserialized(data)
  if data[5] then
    self.hidden = true
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end