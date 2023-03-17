-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}
C.windowName = 'fg_search'
C.windowDescription = 'Search'
C.arrowControllable = true
local matchColor = im.ImVec4(1,0.5,0,1)

function C:attach(mgr)
  self.mgr = mgr
  self.searchChanged = true
  self.searchResultsByMgr[self.mgr.id] = self.searchResultsByMgr[self.mgr.id] or {}
  self.doClick = nil
end

function C:init()
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
  self.searchResultsByMgr = {}
  self.searchText = im.ArrayChar(128)
  self.search =  require('/lua/ge/extensions/editor/util/searchUtil')()
end

function C:createNode()
  self.doClick = true
end

function C:navigateList(up)
  if self.selectedButtonListIndex then
    if up then
      self.selectedButtonListIndex = math.max(self.selectedButtonListIndex - 1, 1)
    else
      self.selectedButtonListIndex = math.min(self.selectedButtonListIndex + 1, self.numberOfButtons)
    end
    self.arrowPressed = true
  end
end

function C:drawSearchInput()
  im.Text("Find: ")
  im.SameLine()
  if self.focusSearch and self.focusSearch > 0 then
    im.SetKeyboardFocusHere()
    self.focusSearch = self.focusSearch -1
  end
  if im.InputText("##searchInProject", self.searchText, nil, im.InputTextFlags_AutoSelectAll) then
    self.searchChanged = true
    self.selectedButtonListIndex = 0
    self.buttonListIndex = 0
    self.doClick = nil
  end
  im.SameLine()
  if im.Button("X") then
    self.searchChanged = true
    self.selectedButtonListIndex = 0
    self.buttonListIndex = 0
    self.doClick = nil
    self.searchText = im.ArrayChar(128)
  end
  im.SameLine()
  editor.uiIconImage(editor.icons.help, im.ImVec2(20,20))
  ui_flowgraph_editor.tooltip("Type any string to search for nodes, graphs and pins.\nBegin with 'node:', 'graph:' or 'pin:' to only search for those elements.")
end



function C:findNodes(match)
  for node in self.mgr:allNodes() do
    local grLoc = node.graph:getLocation()
    self.search:queryElement({
        id = node.id,
        name = node.customName or node.name,
        type = 'node',
        node = node,
        location = grLoc,
        frecencyId = "node_"..node.id,
        info = "In graph '" .. node.graph.name.."'"
      })
    for _, pin in ipairs(node.pinList) do
      self.search:queryElement({
        id = pin.id,
        name = pin.name,
        type = 'pin',
        pin = pin,
        location = node.name.."/"..grLoc,
        frecencyId = "nodePin_"..node.id.."-"..pin.name.."-"..pin.direction,
        info = pin.direction.."-Pin in node '" .. node.name .. "'' in graph '" .. node.graph.name.."'",
      })
    end
  end
end

function C:findGraphs(match)
  for _, graph in pairs(self.mgr.graphs) do
    if graph.type == 'graph' then
      self.search:queryElement( {
          id = graph.id,
          name = graph.name,
          type = 'graph',
          graph = graph,
          frecencyId = "graph_"..graph.id,
          location = graph:getLocation(),
          score = score,
        })
    end
  end
end
local typeOrder = {node = 0, graph = 1, pin = 2}
local sortFun = function(a,b)
  if a.type == b.type then
    return typeOrder[a.type] < typeOrder[b.type]
  else
    if a.location == b.location or not a.location or not b.location then
      return a.id<b.id
    else
      return a.location<b.location
    end
  end
end

function C:findStuff()
  if self.searchChanged then
    table.clear(self.searchResultsByMgr[self.mgr.id])
    local tpe, match = self:getFilterType()
    self.matchString = match
    self.filterByType = tpe
    self.search:setFrecencyData(self.mgr.frecency or {})
    self.search:startSearch(self.matchString)
    self.search:setSameScoreResolvingFunction(sortFun)
    if match ~= '' then
      self:findNodes(match)
      self:findGraphs(match)
    end
    self.searchResultsByMgr[self.mgr.id] = self.search:finishSearch()
    self.searchChanged = false
  end
end

function C:highlightText(label, highlightText)
  im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 0))
  local pos1 = 1
  local pos2 = 0
  local labelLower = label:lower()
  local highlightLower = highlightText:lower()
  local highlightLowerLen = string.len(highlightLower) - 1
  for i = 0, 6 do -- up to 6 matches overall ...
    pos2 = labelLower:find(highlightLower, pos1, true)
    if not pos2 then
      im.Text(label:sub(pos1))
      break
    elseif pos1 < pos2 then
      im.Text(label:sub(pos1, pos2 - 1))
      im.SameLine()
    end

    local pos3 = pos2 + highlightLowerLen
    im.TextColored(matchColor, label:sub(pos2, pos3))
    im.SameLine()
    pos1 = pos3 + 1
  end
  im.PopStyleVar()
end


function C:getFilterType()
  local match = string.lower(ffi.string(self.searchText))
  for _, t in ipairs(tableKeys(typeOrder)) do
    if match:find(t..": ") ~= nil then
      return t, string.sub(match, #t+3)
    end
    if match:find(t..":") ~= nil then
      return t, string.sub(match, #t+2)
    end
  end
  return nil, match
end

local iconSize = im.ImVec2(20,20)
function C:displayResults()
  local foundResult = false
    local debugEnabled = editor.getPreference("flowgraph.debug.editorDebug")
  for _, result in ipairs(self.searchResultsByMgr[self.mgr.id] or {}) do
    if self.filterByType and string.lower(result.type) == string.lower(self.filterByType) or not self.filterByType then
      local prePos = im.GetCursorPos()
      im.BeginGroup()
      im.BeginDisabled()
      im.Text(result.type..": ")
      im.EndDisabled()
      im.SameLine()
      local x = im.GetCursorPosX()
      self:highlightText(result.name, self.matchString)
      im.BeginDisabled()
      if editor.getPreference("flowgraph.debug.displayIds") then
        im.SameLine()
        im.Text("["..result.id.."]")
      end
      if debugEnabled then
        im.SameLine()
        im.Text(string.format(" | %d%%%% Match" ,100*result.score))
        if result.frecency and result.frecency > 0 then
          im.SameLine()
          im.Text(string.format(" | %d%%%% Frecency", result.frecency *100))
        end
      end

      if result.location then
        im.SetCursorPosX(x)
        im.Text("In: "..result.location)
        im.SameLine()
      end
      im.EndDisabled()
      im.EndGroup()
      if result.info then
        ui_flowgraph_editor.tooltip(result.info.."\nIn: "..result.location)
      end

      self:arrowHelper(prePos, im.GetItemRectSize())
      self:manageClick(result)
      foundResult = true
    end
  end
  if not foundResult then
    im.BeginDisabled()
    im.Text("No Results!")
    im.EndDisabled()
  end
  self.doClick = false
end

function C:manageClick(result)
  local doClick = im.IsItemClicked() or (self.buttonListIndex == self.selectedButtonListIndex and self.doClick)
  if doClick then
    self.search:updateFrecencyEntry(result.frecencyId)
    self.mgr.frecency = self.search:getFrecencyData()
    if result.type == 'node' then
      self.mgr:selectGraph(result.node.graph)
      self.mgr:unselectAll()
      ui_flowgraph_editor.SelectNode(result.node.id, false)
      result.node.graph.focusSelection = true
      result.node.graph.focusDelay = 1
    end
    if result.type == 'graph' then
      self.mgr:selectGraph(result.graph)
      self.mgr:unselectAll()
      result.graph.focusContent = true
      result.graph.focusDelay = 1
    end
    if result.type == 'pin' then
      self.mgr:selectGraph(result.pin.node.graph)
      self.mgr:unselectAll()
      ui_flowgraph_editor.SelectNode(result.pin.node.id, false)
      --ui_flowgraph_editor.NavigateToSelection(false, 0.1)
      result.pin.node.graph.focusSelection = true
      result.pin.node.graph.focusDelay = 1
    end
  end
end

function C:draw()
  if not editor.isWindowVisible(self.windowName) then return end
  self:Begin("Search")

  self.buttonListIndex = 0

  self:handleActionMap()
  self:drawSearchInput()
  self:findStuff()
  self:displayResults()

  self.numberOfButtons = self.buttonListIndex
  self.arrowPressed = nil

  self:End()
end


function C:handleActionMap()
  if im.IsWindowFocused(im.FocusedFlags_ChildWindows) then
    self.fgEditor.arrowControllableWindow = self
    if not self.pushedActionMap then
      pushActionMapHighestPriority("NodeLibrary")
      table.insert(editor.additionalActionMaps, "NodeLibrary")
      self.pushedActionMap = true
      self.fgEditor.pushedNodeLibActionMap = true
    end
  else
    self.pushedActionMap = nil
  end
end


function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

function C:arrowHelper(cursor, itemSize, doHover)
  self.buttonListIndex = self.buttonListIndex +1
  if self.buttonListIndex == self.selectedButtonListIndex then
    im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                          cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                          im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                          cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                          im.GetColorU321(im.Col_HeaderActive), 1, 1)

    -- Set the scrollbar to show the selected node
    if self.arrowPressed then
      if cursor.y > im.GetScrollY() + im.GetWindowHeight() then
        im.SetScrollY(math.min(cursor.y - im.GetWindowHeight()/2, im.GetScrollMaxY()))
      end
      if cursor.y < im.GetScrollY() then
        im.SetScrollY(math.max(cursor.y - im.GetWindowHeight()/2, 0))
      end
      self.arrowPressed = false
    end
  end
  if im.IsItemHovered() then
    -- display blue rectangle when node is hovered
    im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                          cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                          im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                          cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                          im.GetColorU321(im.Col_HeaderHovered), 1, 1)
  end
end

return _flowgraph_createMgrWindow(C)
