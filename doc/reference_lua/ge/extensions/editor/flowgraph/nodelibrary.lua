-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local C = {}
C.windowName = 'fg_nodelib'
C.windowDescription = 'Node library'
local arrowPressed = false
C.arrowControllable = true
local matchStringFunction = require('/lua/ge/extensions/editor/util/searchUtil')().matchStringScore
local sharedFrecency = nil
function C:init()
  self.searchText = im.ArrayChar(128)
  self.pinFiltered = false
  self.formerPinType = nil
  self.newNodeLinkPin = nil

  self.selectedButtonListIndex = nil
  self.createNodeButtonListIndex = nil
  self.focusTextInput = true
  self.resetScrollY = true
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, true)
  self.search =  require('/lua/ge/extensions/editor/util/searchUtil')()
  if sharedFrecency == nil then
    sharedFrecency = editor.getPreference("flowgraph.general.nodeFrecency")
  end
  self.search:setFrecencyData(sharedFrecency)
end

function C:clear()
  self.searchText = im.ArrayChar(128)
  self:filterTemplates(self.pinFiltered,'nodes')
  self:filterMacroTemplates(self.pinFiltered)
  self.createNodeButtonListIndex = nil
  self.selectedButtonListIndex = 1
  self.focusTextInput = true
  self.resetScrollY = true
  self.setTreeNodesOpen = false
  self.lastmode = nil
end

function C:hasFoldersOnly(dir)
  for k,v in pairs(dir) do
    if type(v) == 'table' then
      return self:hasFoldersOnly(v)
    else
      return false
    end
  end
  return false
end

function C:setStatic()
  self.static = true
  self.windowWasOpen = false
end

function C:setNewNodeLinkPin(newNodeLinkPin)
  self.newNodeLinkPin = newNodeLinkPin
end

function C:drawTextFilter(usedForContextMenu)
  im.Text("Search:")
  im.SameLine()

  -- This is a little hack because SetKeyboardFocusHere() doesnt work when you call it only once.
  -- We call it, until the text input has focus
  if self.focusTextInput then
    im.SetKeyboardFocusHere()
  end

  if usedForContextMenu then
    im.PushItemWidth(176)
  end

  if im.InputText("##searchInProject", self.searchText, nil, im.InputTextFlags_AutoSelectAll) then
    self.resetScrollY = true
    self.selectedButtonListIndex = 1
    self.lastmode = nil
    --self:filterTemplates(self.pinFiltered, mode)
    --self:filterMacroTemplates(self.pinFiltered)
    --if im.ImGuiTextFilter_IsActive(self.nodeFilter[0]) then
    --  self.setTreeNodesOpen = true
    --else
    --  self.setTreeNodesOpen = false
    --end
    self.searchChanged = true
  end
  if usedForContextMenu then
    im.PopItemWidth()
  end
  ui_flowgraph_editor.tooltip("Put in filter")

  if (im.IsItemActive()) then
    self.focusTextInput = false
  end

  im.SameLine()

  im.PushStyleColor2(im.Col_Button, im.ImVec4(0, 0, 0, 0))
  if editor.uiIconImageButton(editor.icons.close, im.ImVec2(22, 22)) then
    self:clear()
  end
  ui_flowgraph_editor.tooltip("Clear Filter")

  if usedForContextMenu then
    im.SameLine()
    if tableIsEmpty(self.fgEditor.copyData) then
      editor.uiIconImage(editor.icons.content_paste, im.ImVec2(22, 22), im.ImVec4(0.5, 0.5, 0.5, 1.0))
    else
      if editor.uiIconImageButton(editor.icons.content_paste, im.ImVec2(22, 22)) then
        self.mgr:pasteNodes()
        im.CloseCurrentPopup()
      end
    end
    -- if im.IsItemHovered() then im.BeginTooltip() im.Text("Paste") im.EndTooltip() end
    ui_flowgraph_editor.tooltip("Paste Node")
  end

  im.PopStyleColor()
end

function C:createNode()
  if self.buttonListIndex > 0 then
    self.createNodeButtonListIndex = self.selectedButtonListIndex
  else
    self.focusTextInput = true
  end
end

function C:navigateList(up)
  if self.selectedButtonListIndex then
    if up then
      self.selectedButtonListIndex = math.max(self.selectedButtonListIndex - 1, 1)
    else
      self.selectedButtonListIndex = math.min(self.selectedButtonListIndex + 1, self.numberOfButtons)
    end
    arrowPressed = true
  end
end

local function createStateExitNode(self, menuPos, label)
  local _, lookup = core_flowgraphManager.getAvailableNodeTemplates()
  local node = self:createNodeFromButon(menuPos, lookup["states/stateExit"])
  if label then
    node.transitionName = label
  end
end

local function createStateNode(self, menuPos, label)
  local graph, node = self.mgr:createGraphAsState("New State")
  graph:createNode("events/onUpdate")
  if not menuPos then
    -- If there is no pos, use the middle of the screen
    local bounds = ui_flowgraph_editor.GetVisibleCanvasBounds()
    menuPos = im.ImVec2((bounds.x + bounds.z) / 2, (bounds.y + bounds.w) / 2)
  end
  ui_flowgraph_editor.SetNodePosition(node.id, menuPos)
  --ui_flowgraph_editor.SelectNode(node.id, false)
  node:alignToGrid()
  self:linkState(node)
  self.fgEditor.addHistory("Created new empty State")
end

local function createGroupStateNode(self, menuPos, label)
  local graph, node = self.mgr:createGroupState("New Group State")
  --graph:createNode("events/onUpdate")
  if not menuPos then
    -- If there is no pos, use the middle of the screen
    local bounds = ui_flowgraph_editor.GetVisibleCanvasBounds()
    menuPos = im.ImVec2((bounds.x + bounds.z) / 2, (bounds.y + bounds.w) / 2)
  end
  ui_flowgraph_editor.SetNodePosition(node.id, menuPos)
  --ui_flowgraph_editor.SelectNode(node.id, false)
  node:alignToGrid()
  self:linkState(node)
  self.fgEditor.addHistory("Created new Group State")
end

-- window which shows all available nodes incl drag'n' drop functionality
function C:drawContentAsTreeNodes(menuPos)
  if self.windowWasOpen == false then
    self.windowWasOpen = true
    self:clear()
  end
  -- Navigate the list with the keyboard
  --[[if im.IsKeyPressed(im.GetKeyIndex(im.Key_Enter)) then self.createNodeButtonListIndex = self.selectedButtonListIndex end
  if self.selectedButtonListIndex then
    if im.IsKeyPressed(im.GetKeyIndex(im.Key_UpArrow)) then
      self.selectedButtonListIndex = math.max(self.selectedButtonListIndex - 1, 1)
    end
    if im.IsKeyPressed(im.GetKeyIndex(im.Key_DownArrow)) then
      self.selectedButtonListIndex = math.min(self.selectedButtonListIndex + 1, self.numberOfButtons)
    end
  end]]
  if im.IsMouseClicked(0) then
    self.selectedButtonListIndex = nil
  end

  if self.newNodeLinkPin then
    if self.formerPinType ~= self.newNodeLinkPin.type then
      self.pinFiltered = false
    end
    self.formerPinType = self.newNodeLinkPin.type
  else
    self.formerPinType = nil
  end

  -- check if mgr.newNodeLinkPin exists so we have to filter by pins as well
  if not self.pinFiltered and self.newNodeLinkPin then
    self.pinFiltered = true
    self.filteredTemplates = nil
  elseif self.pinFiltered and not self.newNodeLinkPin then
    self.pinFiltered = false
    self.filteredTemplates = nil
  end

  self.buttonListIndex = 0

  -- only draw the actual nodeLib if we are NOT in the state graph
  if self.mgr.graph and not self.mgr.graph.isStateGraph then

    self:filterTemplates(self.pinFiltered, 'nodes')
    --self:drawTextFilter('nodes')
    im.BeginChild1("nodelib###")
      local sorted = {}
      for dir, v in pairs(self.filteredTemplates) do if not v.isEmpty then table.insert(sorted,dir) end end
      table.sort(sorted)

      for n, d in ipairs(sorted) do
        if self.filteredFolders[d]  then
          -- This is the same as im.SetNextTreeNodeOpen, except it actually works
          if self.setTreeNodesOpen ~= nil then
            local state = self.setTreeNodesOpen and 1 or 0
            im.ImGuiStorage_SetInt(im.GetStateStorage(),im.GetID1(d), state)
          end
          if im.TreeNodeEx1(d) then
            self:displayDir(self.filteredTemplates[d], menuPos,'nodes',self.displayNode)
            im.TreePop()
          end
        end
      end
    im.EndChild()

    im.BeginChild1("Variables###")
      local padding = im.GetStyle().FramePadding

      -- This is the same as im.SetNextTreeNodeOpen, except it actually works
      if self.setTreeNodesOpen ~= nil then
        local state = self.setTreeNodesOpen and 1 or 0
        im.ImGuiStorage_SetInt(im.GetStateStorage(),im.GetID1("Variables"), state)
      end

      local showGet = true
      local showSet = true
      if self.pinFiltered then
        showGet = self.newNodeLinkPin ~= nil and self.newNodeLinkPin.direction == 'in'
        showSet = self.newNodeLinkPin ~= nil and self.newNodeLinkPin.direction == 'out'
      end
      if im.TreeNodeEx1("Variables") then
        if self.setTreeNodesOpen ~= nil then
          local state = self.setTreeNodesOpen and 1 or 0
          im.ImGuiStorage_SetInt(im.GetStateStorage(),im.GetID1("Project Variables"), state)
        end
        if im.TreeNodeEx1("Project Variables") then
          for _, nm  in pairs(self.mgr.variables.sortedVariableNames) do
            local var = self.mgr.variables:getFull(nm)
            if self:variablePinFilter(var,'in') then
              --if im.ImGuiTextFilter_PassFilter(self.nodeFilter,"Get " ..  nm) and showGet then
                self:displayVariable(var ,menuPos, true, true)
              --end
            end
            if self:variablePinFilter(var,'out') then
              --if im.ImGuiTextFilter_PassFilter(self.nodeFilter,"Set " ..  nm) and showSet then
                self:displayVariable(var ,menuPos, false, true)
              --end
            end
          end
          im.TreePop()
        end

        if self.setTreeNodesOpen ~= nil then
          local state = self.setTreeNodesOpen and 1 or 0
          im.ImGuiStorage_SetInt(im.GetStateStorage(),im.GetID1("Graph Variables"), state)
        end
        if im.TreeNodeEx1("Graph Variables") then
          for _, nm  in pairs(self.mgr.graph.variables.sortedVariableNames) do
            local var = self.mgr.graph.variables:getFull(nm)
            if self:variablePinFilter(var,'in') then
              --if im.ImGuiTextFilter_PassFilter(self.nodeFilter,"Get " ..  nm) and showGet then
                self:displayVariable(var,menuPos, true, false)
              --end
            end
            if self:variablePinFilter(var,'out') then
              --if im.ImGuiTextFilter_PassFilter(self.nodeFilter,"Set " ..  nm) and showSet then
                self:displayVariable(var,menuPos, false, false)
              --end
            end
          end
          im.TreePop()
        end
        im.TreePop()
      end
    im.EndChild()

    im.BeginChild1("Macros###")
      local padding = im.GetStyle().FramePadding

      -- This is the same as im.SetNextTreeNodeOpen, except it actually works
      if self.setTreeNodesOpen ~= nil then
        local state = self.setTreeNodesOpen and 1 or 0
        im.ImGuiStorage_SetInt(im.GetStateStorage(),im.GetID1("Macros"), state)
      end

      if im.TreeNodeEx1("Macros") then
        if not self.filteredMacro then self:filterMacroTemplates(self.pinFiltered) end
        if self.filteredMacro then
          self:refreshMacro()
          for mn,data in pairs(self.filteredMacro) do
            self:displayMacro(mn,data,menuPos)
          end
        end
        im.TreePop()
      end
    im.EndChild()
  else
    -- draw state library
    --self:drawTextFilter('states')
    self:refreshStateTemplates()
    self:filterTemplates(nil, 'states')
    --if not im.ImGuiTextFilter_IsActive(self.nodeFilter[0]) then
    self:displaySimpleElement(menuPos, "New State", createStateNode)
    self:displaySimpleElement(menuPos, "New Group State", createGroupStateNode)
    self:displaySimpleElement(menuPos, "State Exit", createStateExitNode)

    local exits = {}
    local parent = self.mgr.graph:getParent()
    if parent then
      for _, nd in pairs(parent.nodes) do
        if nd:representsGraph() and nd:representsGraph().id == self.mgr.graph.id then
          for _, pin in pairs(nd.pinOut) do
            table.insert(exits, pin.name)
          end
        end
      end
    end
    table.sort(exits)
    for _, e in ipairs(exits) do
      self:displaySimpleElement(menuPos, "State Exit -> " .. e, createStateExitNode, e)
    end
    local _, lookup = core_flowgraphManager.getAvailableNodeTemplates()
    self:displayNode(nil, menuPos, "Create Comment", lookup['debug/comment'])
    --end
    im.BeginChild1("statelib###")
      local sorted = {}
      for dir, v in pairs(self.filteredTemplates) do if not v.isEmpty then table.insert(sorted,dir) end end
      table.sort(sorted)

      for n, d in ipairs(sorted) do

        if self.filteredFolders[d]  then
          -- This is the same as im.SetNextTreeNodeOpen, except it actually works
          if self.setTreeNodesOpen ~= nil then
            local state = self.setTreeNodesOpen and 1 or 0
            im.ImGuiStorage_SetInt(im.GetStateStorage(),im.GetID1(d), state)
          end
          if im.TreeNodeEx1(d) then
            self:displayDir(self.filteredTemplates[d], menuPos,'states',self.displayStateTemplate)
            im.TreePop()
          end
        end

      end
    im.EndChild()

  end
  self.numberOfButtons = self.buttonListIndex
  self.setTreeNodesOpen = nil
end


function C:variablePinFilter(var, dir)
  if not self.newNodeLinkPin then return true end

  if type(self.newNodeLinkPin.type) == "table" then
    for _, t in ipairs(self.newNodeLinkPin.type) do
      if t == var.type then return true end
    end
    return false
  elseif self.newNodeLinkPin.type == 'any' then
    return true
  elseif self.newNodeLinkPin.type == 'flow' and self.newNodeLinkPin.direction == 'out' and dir =='out' then
    return true
  elseif self.newNodeLinkPin.type == var.type and (not dir or dir == self.newNodeLinkPin.direction) then
    return true
  end
end

local typeOrder = {}
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


local function flowNodeScoringFunction(elem, match)
  local score = matchStringFunction(elem.name, match)
  local matchedTags = {}
  for _, tag in ipairs(elem.info.node.tags or {}) do
    local tagScore = matchStringFunction(tag, match, true) * 0.75
    if tagScore > 0 then
      table.insert(matchedTags, tag)
      if tagScore > score then
        score = tagScore
      end
    end
  end
  elem.tags = next(matchedTags) and ("["..table.concat(matchedTags,", ") .. "]") or nil
  elem.score = score
  return score
end

function C:findFlowNodes()
  -- find basic nodes
  local _, flat = core_flowgraphManager.getAvailableNodeTemplates()
  for path, info in pairs(flat) do
    if not info.node.hidden and self:pinsFilter(info) and (editor.getPreference("flowgraph.general.showObsoleteNodes") or not info.node.obsolete) then
      self.search:queryElement({
          name = info.node.name,
          type = 'node',
          score = score,
          frecencyId = info.path,
          info = info
      }, flowNodeScoringFunction)
    end
  end

  -- find mgr variables
  self:findVar(self.mgr.variables,'Project Variable','mgr')
  self:findVar(self.mgr.graph.variables,'Graph Variable','graph')
end

local dirs = {{'Get ','get','in'},{'Set ','set','out'}}
function C:findVar(source, sourceName, sourceNameTag)
  for _, nm  in pairs(source.sortedVariableNames) do
    local var = source:getFull(nm)
    for _, d in ipairs(dirs) do
      if self:variablePinFilter(var,d[3]) then
        self.search:queryElement({
            name = d[1] ..var.name,
            type = 'variable',
            score = score,
            varInfo = sourceName,
            frecencyId = 'var_'..var.name,
            info = var,
            dir = d[2],
            source = sourceNameTag
          })
      end
    end
  end
end

local function stateNodeScoringFunction(elem, match)
  local score = matchStringFunction(elem.name, match)
  local matchedTags = {}
  for i, tag in ipairs(elem.info.data.splitPath or {}) do
    if i < #info.splitPath then
      local tagScore = matchStringFunction(tag, self.matchString, true) * 0.75
      if tagScore > 0 and score == 0 then
        table.insert(matchedTags, tag)
        if tagScore > score then
          score = tagScore
        end
      end
    end
  end
  elem.tags = next(matchedTags) and ("["..table.concat(matchedTags,", ") .. "]") or nil
  elem.score = score
  return score
end

function C:findStateNodes()
  -- find basic nodes
  local _, flat = core_flowgraphManager.getAvailableStateTemplates()
  for path, info in pairs(flat) do
    self.search:queryElement({
        name = info.data.name,
        type = 'state',
        frecencyId = info.path,
        info = info
      }, stateNodeScoringFunction)
  end

  self.search:queryElement({
    name = "New State",
    type = "custom",
    frecencyId = "newStateManual",
    info = {customFunction = createStateNode}
  })
  self.search:queryElement({
    name = "New Group State",
    type = "custom",
    frecencyId = "newGroupStateManual",
    info = {customFunction = createGroupStateNode}
  })
  self.search:queryElement({
    name = "State Exit",
    type = "stateExit",
    frecencyId = "stateExitManual",
    label = nil
  })
  local exits = {}
  local parent = self.mgr.graph:getParent()
  if parent then
    for _, nd in pairs(parent.nodes) do
      if nd:representsGraph() and nd:representsGraph().id == self.mgr.graph.id then
        for _, pin in pairs(nd.pinOut) do
          table.insert(exits, pin.name)
        end
      end
    end
  end
  table.sort(exits)
  for _, e in ipairs(exits) do
    self.search:queryElement({
      name = "State Exit -> " .. e,
      type = "stateExit",
      frecencyId = "stateExitGenerated"..e,
      label = e
    })
  end
  local _, lookup = core_flowgraphManager.getAvailableNodeTemplates()
  self.search:queryElement({
    name = "Comment",
    type = "node",
    frecencyId = lookup['debug/comment'].path,
    info = lookup['debug/comment']
  })
end


local function sortFun(a,b)
  if a.frecency and b.frecency then
    if a.frecency ~= b.frecency then
      return a.frecency > b.frecency
    end
  end
  return a.score > b.score
end
function C:drawContent(menuPos, usedForContextMenu)
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
  self:drawTextFilter(usedForContextMenu)
  self.buttonListIndex = 0
  im.PushStyleColor2(im.Col_ScrollbarGrab, im.GetStyleColorVec4(im.Col_ButtonActive))
  im.PushStyleColor2(im.Col_ScrollbarGrabHovered, im.GetStyleColorVec4(im.Col_TitleBgActive))
  im.PushStyleColor2(im.Col_ScrollbarGrabActive, im.GetStyleColorVec4(im.Col_SliderGrabActive))
  if ffi.string(self.searchText) == '' then
    self:drawContentAsTreeNodes(menuPos)
  else
    im.BeginChild1('##nodfinder')
    if self.searchChanged then
      self.searchType, self.matchString = self:getFilterType()
      self.search:setFrecencyData(sharedFrecency)
      self.search:startSearch(self.matchString)
      if self.matchString ~= nil then
        if self.mgr.graph and not self.mgr.graph.isStateGraph then
          self:findFlowNodes()
        end
        if self.mgr.graph and self.mgr.graph.isStateGraph then
          self:findStateNodes()
        end
      end
      self.searchResults = self.search:finishSearch()
      self.searchChanged = nil
    end
    self:displayResults(menuPos)
    self.numberOfButtons = self.buttonListIndex
    arrowPressed = nil
    im.EndChild()
  end
  im.PopStyleColor()
  im.PopStyleColor()
  im.PopStyleColor()
end

local matchColor = im.ImVec4(1,0.5,0,1)
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

local iconSize = im.ImVec2(24, 24)
local iconColor = im.ImVec4(0.5,0.5,0.5,1)
function C:displayResults(menuPos)
  local debugEnabled = editor.getPreference("flowgraph.debug.editorDebug")
  for i, result in ipairs(self.searchResults) do
    local prePos = im.GetCursorPos()
    im.BeginGroup()
    im.BeginDisabled()
    im.Text(result.type..":")
    im.SameLine()
    im.EndDisabled()
    self:highlightText(result.name, self.matchString)
    im.BeginDisabled()
    if result.type == 'node' then
      if result.tags then
        im.SameLine()
        self:highlightText(result.tags, self.matchString)
      end
      im.SameLine()
      self:highlightText(result.info.path, self.matchString)
    end
    if result.type == 'variable' then
      im.SameLine()
      im.Text(result.varInfo)
    end
    if result.type == 'state' then
      if result.tags then
        im.SameLine()
        self:highlightText(result.tags, self.matchString)
      end
      im.SameLine()
      self:highlightText(result.info.path, self.matchString)
    end
    if debugEnabled then
      im.SameLine()
      im.Text(string.format(" | %d%%%% Match" ,100*result.score))
      if result.frecency then
        im.SameLine()
        im.Text(string.format(" | %d%%%% Frecency", result.frecency *100))
      end
    end
    im.EndDisabled()
    im.EndGroup()
    local hoverFun = nop
    if result.type == 'node' then
      hoverFun = function() self.fgEditor.nodePreviewPopup:setNode(result.info) end
    end
    self:arrowHelper(prePos, im.GetItemRectSize(), true, hoverFun)
    im.SetCursorPos(prePos)
    if im.InvisibleButton("invBtnResult_" .. i, im.GetItemRectSize()) or self.createNodeButtonListIndex == self.buttonListIndex then
      if result.type == 'node' then
        self:createNodeFromButon(menuPos, result.info)
      elseif result.type == 'variable' then
        self:createVariableButton(result.info, menuPos, result.dir == 'get', result.source == 'mgr')
      elseif result.type == 'state' then
        self:createStateButton(menuPos, result.info)
      elseif result.type == 'stateExit' then
        createStateExitNode(self, menuPos, result.label)
      elseif result.type == 'custom' then
        dump(result)
        result.info.customFunction(self, menuPos, result.info)
      end
      im.CloseCurrentPopup()
    end
    if result.type == 'node' and not menuPos then self.mgr:dragDropSource("NodeDragDropPayload", result.info) end
  end

end

function C:draw()
  -- This is only called for the node library and NOT for the context menu
  if not editor.isWindowVisible(self.windowName) then
    self.setTreeNodesOpen = false
    return
  end

  --if not self.fgEditor.dockspaces["NE_RightTopPanel_Dockspace"] then self.fgEditor.dockspaces["NE_RightTopPanel_Dockspace"] = im.GetID1("NE_RightTopPanel_Dockspace") end
  --im.SetNextWindowDockID(self.fgEditor.dockspaces["NE_RightTopPanel_Dockspace"])
  -- if im.Begin('Node Library', self.windowOpen) then
  if self:Begin('Node Library') then
    self:drawContent()
  end
  self:End()
end

function C:pinsFilter(node)
  if self.mgr and self.newNodeLinkPin then
    if node.id == self.newNodeLinkPin.node.id then return false end

    -- check if availablePinTypes for node and that not empty
    if node.availablePinTypes and (next(node.availablePinTypes['_in'])~=nil or next(node.availablePinTypes['_out'])~=nil) then

      local nodeAvailableTableTypes = {}
      for _, p in ipairs(node.node.pinSchema or {}) do
        if p.type == "table" then
          if self.newNodeLinkPin.direction == 'in' and p.dir == 'out' then
            nodeAvailableTableTypes[p.tableType or 'generic'] = true
          elseif self.newNodeLinkPin.direction == 'out' and p.dir == 'in' then
            nodeAvailableTableTypes[p.tableType or 'generic'] = true
          end
        end
      end


      -- check if multiple types allowed
      local pinTypesToCheck = {}
      if type(self.newNodeLinkPin.type) == 'table' then
        for i=1,#self.newNodeLinkPin.type do
          table.insert(pinTypesToCheck, self.newNodeLinkPin.type[i])
        end
      else
        table.insert(pinTypesToCheck, self.newNodeLinkPin.type)
      end

      -- check if any pin
      if self.newNodeLinkPin.type == 'any' then
        return true
      end

      -- check direction
      local direction = '_in'
      if self.newNodeLinkPin.direction == 'in' then
        direction = '_out'
      end

      -- check if pin types are available
      for i=1,#pinTypesToCheck do
        if node.availablePinTypes[direction]['any'] then
          return true
        end
        if node.availablePinTypes[direction][pinTypesToCheck[i]] then
          if pinTypesToCheck[i]=="table" then
            if nodeAvailableTableTypes[self.newNodeLinkPin:getTableType()] then
              return true
            end
          else
            return true
          end
        end


        --
        --if pinTypesToCheck[i]=="table" then
          -- assumes that there is only one tableType for a pin (even if pin can have multiple types)
          --if node.availablePinTypes[direction][pinTypesToCheck[i]] and nodeAvailableTableTypes[self.newNodeLinkPin:getTableType()] then
            --return true
          --end
        --else
          --if node.availablePinTypes[direction][pinTypesToCheck[i]] or node.availablePinTypes[direction]['any'] then
            --return true
          --end
        --end
      end
    end
    return false
  else
    return true
  end
end


C._sortFunc = function(a,b) return string.lower(a.name) < string.lower(b.name) end

function C:filterNodes(dir, filterPins, mode)
  local res = nil

  for k,v in pairs(dir) do
    if k == mode then
      for nName, nVal in pairs(v) do
        local passedNameFilter = true--self:namesFilter(nVal, mode)
        local passedTagsFilter = true--mode == 'nodes' and self:tagsFilter(nVal)
        local passedTypeFilter = true--mode == 'nodes' and self:typeFilter(nVal)
        local passedPathFilter = true--self:pathFilter(nVal)

        local passedPinsFilter = true
        local isHidden = mode == 'nodes' and (nVal.node.hidden and nVal.node.hidden == true) and true or false
        if mode == 'nodes' and filterPins then
          passedPinsFilter = self:pinsFilter(nVal)
        end
        if ((passedNameFilter or passedTagsFilter or passedTypeFilter or passedPathFilter) and passedPinsFilter) and not isHidden then
          if not res then res = {} end
          if not res[mode] then res[mode] = {} end
          res[mode][nName] = nVal
        end
      end
    else
      if not res then res = {} end
      res[k] = {}
      local nodes = self:filterNodes(v, filterPins, mode)
      if not res[mode] and nodes then
        res[mode] = {}
      end
      res[k] = nodes
    end
  end
  -- find if a series of folders is empty to the top. then remove it.
  return res
end




function C:checkEmpty(dir, mode)
  local dirs = {}
  for n, d in pairs(dir) do
    if n ~= mode then
      table.insert(dirs, n)
    end
  end
  for _, dName in ipairs(dirs) do
    self:checkEmpty(dir[dName], mode)
  end
  -- simple case: if we have nodes, we are not empty.
  if dir[mode] and next(dir[mode]) then
    dir.isEmpty = false
  else
    -- if we have no nodes, and no further
    if not next(dirs) then
      if dir[mode] and next(dir[mode]) then
        dir.isEmpty = false
      else
        dir.isEmpty = true
      end
    end
    dir.isEmpty = true
    for _, dName in ipairs(dirs) do
      if not dir[dName].isEmpty then
        dir.isEmpty = false
      end
    end
  end

end

function C:filterMacros(dir,filterPins)
  local res = nil
  for k,v in pairs(dir) do
    local passedNameFilter = true--self:macroNameFilter(k)
    local passedTagFilter  = true--self:macroTagFilter(v)
    if passedNameFilter or passedTagFilter then
      if not res then res = {} end
      res[k] = v
    end
  end
  return res
end

function C:refreshMacro()
  if self.mgr and self.mgr.newMacroAdded then
    self.macroTemplates = self.mgr:getAvailableMacros()
    self.mgr.newMacroAdded = false
  end
end

function C:refreshStateTemplates()
  --if self.mgr and self.mgr.newStateTemplateAdded then
    self.stateTemplates = self.mgr:getAvailableStateTemplates()
    self.stateTemplatesSorted = {}
    for name, s in pairs(self.stateTemplates) do
      table.insert(self.stateTemplatesSorted, name)
    end
    table.sort(self.stateTemplatesSorted)
    self.mgr.newStateTemplateAdded = false
  --end
end

function C:filterMacroTemplates(filterPins)
  self.macroTemplates = self.mgr:getAvailableMacros()
  self.filteredMacro = {}
  self.filteredMacro = self:filterMacros(self.macroTemplates,filterPins)
end

function C:filterTemplates(filterPins, mode)
  if self.lastmode ~= mode then
    self.lastmode = mode
    local templates = nil
    if mode == 'nodes' then
      templates = self.mgr:getAvailableNodeTemplates()
    elseif mode == 'states' then
      templates = self.mgr:getAvailableStateTemplates()
    end

    self.filteredTemplates = {}
    self.filteredFolders = {}
    for k,v in pairs(templates) do
      local nd = self:filterNodes(v, filterPins, mode)
      self.filteredTemplates[k] = nd
      if nd and nd[mode] then
        self.filteredFolders[k] = true
      end
    end
    for name, dir in pairs(self.filteredTemplates) do
      if name ~= mode then
        self:checkEmpty(dir, mode)
      end
    end
  end
end

function C:displayVariable(var,menuPos, read, fromMgr)
  if self.resetScrollY then
    im.SetScrollY(0)
    self.resetScrollY = false
  end
  local padding = im.GetStyle().FramePadding
  local cursor = im.GetCursorPos()
  im.BulletText((read and "Get " or "Set ")..var.name)
  im.SetCursorPos(cursor)
  local itemSize = im.CalcTextSize((read and "Get " or "Set ")..var.name)
  itemSize.x = itemSize.x + im.GetFontSize() + padding.x * 3

  if im.InvisibleButton((read and "Get " or "Set ") .. "invBtn_" .. var.name, itemSize) or self.createNodeButtonListIndex == self.buttonListIndex+1 then
    self.createNodeButtonListIndex = nil
    self.selectedButtonListIndex = self.buttonListIndex
    self:createVariableButton(var,menuPos, read, fromMgr)
    im.CloseCurrentPopup()
  end
  if not menuPos then self.mgr:dragDropSource("variableNodeDragDropPayload", {read = read, varName = var.name, path = "Get " .. var.name, global = fromMgr}) end
  if self.buttonListIndex == self.selectedButtonListIndex then
    im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                          cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                          im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                          cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                          im.GetColorU321(im.Col_HeaderActive), 1, 1)

    -- Set the scrollbar to show the selected node
    if arrowPressed then
      if cursor.y > im.GetScrollY() + im.GetWindowHeight() then
        im.SetScrollY(math.min(cursor.y - im.GetWindowHeight()/2, im.GetScrollMaxY()))
      end
      if cursor.y < im.GetScrollY() then
        im.SetScrollY(math.max(cursor.y - im.GetWindowHeight()/2, 0))
      end
      arrowPressed = false
    end

  end
  if im.IsItemHovered() then
    im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                          cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                          im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                          cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                          im.GetColorU321(im.Col_HeaderHovered), 1, 1)
  end
end

function C:createVariableButton(var,menuPos, read, fromMgr)
  self.search:updateFrecencyEntry("var_"..var.name)
  sharedFrecency = self.search:getFrecencyData()
  editor.setPreference("flowgraph.general.nodeFrecency", sharedFrecency)
  local bounds = ui_flowgraph_editor.GetVisibleCanvasBounds()
  local pos = im.ImVec2((bounds.x + bounds.z) / 2, (bounds.y + bounds.w) / 2)
  if menuPos then pos = menuPos end
  local node = self.mgr.graph:createNode(read and "types/getVariable" or "types/setVariable")
  ui_flowgraph_editor.SetNodePosition(node.id, pos)
  ui_flowgraph_editor.SelectNode(node.id, false)
  node:alignToGrid()
  node:setGlobal(fromMgr)
  node:setVar(var.name)
  if self.newNodeLinkPin then
    if read then
      self.mgr.graph:createLink(node.pinOut[var.name], self.newNodeLinkPin)
    else
      if self.newNodeLinkPin.type == 'flow' then
        self.mgr.graph:createLink(self.newNodeLinkPin, node.pinInLocal.flow)
      else
        self.mgr.graph:createLink(self.newNodeLinkPin, node.pinInLocal[var.name])
      end
    end
  end
  self.fgEditor.addHistory("Added Variable node for " .. var.name)
end

function C:displayMacro(macroName,macro,menuPos)
  if self.resetScrollY then
    im.SetScrollY(0)
    self.resetScrollY = false
  end
  local padding = im.GetStyle().FramePadding
  local cursor = im.GetCursorPos()
  im.BulletText(macroName)
  im.SetCursorPos(cursor)
  local itemSize = im.CalcTextSize(macroName)
  itemSize.x = itemSize.x + im.GetFontSize() + padding.x * 3
  if im.InvisibleButton("invBtn_" .. macroName, itemSize) then
    self.mgr:createNewMacroNode(macro.path)
    im.CloseCurrentPopup()
  end

  if not menuPos then self.mgr:dragDropSource("macroDragDropPayload", macro) end
  if im.IsItemHovered() then
    im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                          cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                          im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                          cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                          im.GetColorU321(im.Col_HeaderHovered), 1, 1)
    self.fgEditor.nodePreviewPopup:setMacro(macro)
  end
end

function C:ratePinSimilarity(a, b)
  a.__matchScore = 0
  if a.name == b.name then
    a.__matchScore = 1000
  end
  -- matching type exactly?
  if a.type == b.type then
    a.__matchScore = a.__matchScore + 300
  end
  -- similar name?
  if string.find(a.name:lower(), b.name:lower()) or string.find(b.name:lower(), a.name:lower()) then
    a.__matchScore = a.__matchScore + 100
  end
  if a.name == 'reset' or b.name == 'reset' then
    a.__matchScore = a.__matchScore - 1150
  end

end

function C:displayDir(dir, menuPos, elementFieldName, elementFunction)
  if self.resetScrollY then
    im.SetScrollY(0)
    self.resetScrollY = false
  end
  -- display subfolder tree nodes
  for dirName, dirVal in pairs(dir) do
    if dirName ~= elementFieldName and dirName ~= 'isEmpty' then
      if dirVal[elementFieldName] then
        -- This is the same as im.SetNextTreeNodeOpen, except it actually works
        if self.setTreeNodesOpen ~= nil then
          local state = self.setTreeNodesOpen and 1 or 0
          im.ImGuiStorage_SetInt(im.GetStateStorage(),im.GetID1(dirName), state)
        end

        if im.TreeNodeEx1(dirName) then
          self:displayDir(dirVal, menuPos,elementFieldName, elementFunction)
          im.TreePop()
        end
      end
    end
  end

  -- display Elements
  if dir[elementFieldName] then
    for elemName, elem in pairs(dir[elementFieldName]) do
      elementFunction(self, dir, menuPos, elemName, elem)
    end
  end
end


function C:displaySimpleElement(menuPos, text, clickFun, ...)
  if self.resetScrollY then
    im.SetScrollY(0)
    self.resetScrollY = false
  end
  local padding = im.GetStyle().FramePadding
  local cursor = im.GetCursorPos()
  local btnText = text
  im.BulletText(btnText)
  im.SetCursorPos(cursor)
  local itemSize = im.CalcTextSize(btnText)
  itemSize.x = itemSize.x + im.GetFontSize() + padding.x * 3

  if im.InvisibleButton(btnText .. "invBtn_" .. "new_state", itemSize) or self.createNodeButtonListIndex == self.buttonListIndex+1 then
    self.createNodeButtonListIndex = nil
    self.selectedButtonListIndex = self.buttonListIndex
    if clickFun then
      clickFun(self, menuPos, ...)
    end
    im.CloseCurrentPopup()
  end
  -- TODO: add drag/drop functionality for states
  --if not menuPos then self.mgr:dragDropSource("variableNodeDragDropPayload", {read = read, varName = var.name, path = "Get " .. var.name, global = fromMgr}) end
  self:arrowHelper(cursor, itemSize, true)
end



function C:displayStateExitButton(menuPos, label)
  if self.resetScrollY then
    im.SetScrollY(0)
    self.resetScrollY = false
  end
  local padding = im.GetStyle().FramePadding
  local cursor = im.GetCursorPos()
  local btnText = "State Exit ".. (label and ("-> " .. label) or "")
  im.BulletText(btnText)
  im.SetCursorPos(cursor)
  local itemSize = im.CalcTextSize(btnText)
  itemSize.x = itemSize.x + im.GetFontSize() + padding.x * 3

  if im.InvisibleButton(btnText .. "invBtn_" .. "new_GroupState", itemSize) or self.createNodeButtonListIndex == self.buttonListIndex+1 then
    self.createNodeButtonListIndex = nil
    self.selectedButtonListIndex = self.buttonListIndex
    --local node = self.mgr.graph:createNode(read and "types/getVariable" or "types/setVariable")

    im.CloseCurrentPopup()
  end
  -- TODO: add drag/drop functionality for states
  --if not menuPos then self.mgr:dragDropSource("variableNodeDragDropPayload", {read = read, varName = var.name, path = "Get " .. var.name, global = fromMgr}) end
  self:arrowHelper(cursor, itemSize, true)
end

function C:linkState(node)
  if self.newNodeLinkPin then
    -- create link
    if self.newNodeLinkPin.direction == 'out' then
      self.mgr.graph:createLink(self.newNodeLinkPin, node.pinInLocal.flow )
    else
      local p = nil
      for _, pin in pairs(node.pinOut) do
        p = pin
        break
      end
      if p then
        self.mgr.graph:createLink(p, self.newNodeLinkPin )
      end
    end
  end
end

function C:displayStateTemplate(dir, menuPos, stateName, state)
  if self.resetScrollY then
    im.SetScrollY(0)
    self.resetScrollY = false
  end
  local padding = im.GetStyle().FramePadding
  local cursor = im.GetCursorPos()
  im.BulletText(stateName)
  im.SetCursorPos(cursor)
  local itemSize = im.CalcTextSize(stateName)
  itemSize.x = itemSize.x + im.GetFontSize() + padding.x * 3
  self.buttonListIndex = self.buttonListIndex + 1
  if im.InvisibleButton("invBtn_" .. stateName, itemSize) then
    self:createStateButton(menuPos, state)

  end
  --  if not menuPos then self.mgr:dragDropSource("macroDragDropPayload", macro) end
  self:arrowHelper(cursor, itemSize, true)

end
function C:createStateButton(menuPos, state)
  local graph, node = self.mgr:createStateFromLibrary(state.data)
  self.search:updateFrecencyEntry(state.path)
  sharedFrecency = self.search:getFrecencyData()
  editor.setPreference("flowgraph.general.nodeFrecency", sharedFrecency)
  if not menuPos then
    -- If there is no pos, use the middle of the screen
    local bounds = ui_flowgraph_editor.GetVisibleCanvasBounds()
    menuPos = im.ImVec2((bounds.x + bounds.z) / 2, (bounds.y + bounds.w) / 2)
  end
  ui_flowgraph_editor.SetNodePosition(node.id, menuPos)
  ui_flowgraph_editor.SelectNode(node.id, false)
  node:alignToGrid()
  self:linkState(node)
  self.fgEditor.addHistory("Added new state "..state.data.name)
end

function C:displayNode(dir, menuPos, nodeName, node)
  if editor.getPreference("flowgraph.general.showObsoleteNodes") or not node.node.obsolete then
    local padding = im.GetStyle().FramePadding
    nodeName = node.node.name or nodeName
    local cursor = im.GetCursorPos()
    im.BulletText(nodeName)

    im.SetCursorPos(cursor)
    local itemSize = im.CalcTextSize(nodeName)
    itemSize.x = itemSize.x + im.GetFontSize() + padding.x * 3

    if im.InvisibleButton("invBtn_" .. nodeName, itemSize) or self.createNodeButtonListIndex == self.buttonListIndex+1 then
      self:createNodeFromButon(menuPos, node)
    end

    if not menuPos then self.mgr:dragDropSource("NodeDragDropPayload", node) end
    self:arrowHelper(cursor, itemSize, true, function() self.fgEditor.nodePreviewPopup:setNode(node) end)
  end
end

function C:createNodeFromButon(menuPos, node)
  self.createNodeButtonListIndex = nil
  self.selectedButtonListIndex = self.buttonListIndex
  self.search:updateFrecencyEntry(node.path)
  sharedFrecency = self.search:getFrecencyData()
  editor.setPreference("flowgraph.general.nodeFrecency", sharedFrecency)
  if not menuPos then
    -- If there is no pos, use the middle of the screen
    local bounds = ui_flowgraph_editor.GetVisibleCanvasBounds()
    menuPos = im.ImVec2((bounds.x + bounds.z) / 2, (bounds.y + bounds.w) / 2)
  end

  if menuPos then
    local n = self.mgr.graph:createNode(node.path)
    ui_flowgraph_editor.SetNodePosition(n.id, menuPos)
    ui_flowgraph_editor.SelectNode(n.id, false)
    n:alignToGrid()
    im.CloseCurrentPopup()
    if self.newNodeLinkPin then
      -- create link
      if self.newNodeLinkPin.direction == 'out' then
        local availablePins = {}
        for _, pin in pairs(n.pinInLocal) do
          if self.mgr.graph:canCreateLink(self.newNodeLinkPin, pin) then
            -- matching name?
            self:ratePinSimilarity(pin, self.newNodeLinkPin)
            table.insert(availablePins, pin)
          end
        end
        table.sort(availablePins, function(a,b) return a.__matchScore > b.__matchScore end)
        if availablePins[1] then
          self.mgr.graph:createLink(self.newNodeLinkPin, availablePins[1])
        end
        for _, p in ipairs(availablePins) do p.__matchScore = nil end

      elseif self.newNodeLinkPin.direction == 'in' then
        local availablePins = {}
        for _, pin in pairs(n.pinOut) do
          if self.mgr.graph:canCreateLink(pin, self.newNodeLinkPin) then
            -- matching name?
            self:ratePinSimilarity(pin, self.newNodeLinkPin)
            table.insert(availablePins, pin)
          end
        end
        table.sort(availablePins, function(a,b) return a.__matchScore > b.__matchScore end)
        if availablePins[1] then
          self.mgr.graph:createLink(availablePins[1], self.newNodeLinkPin )
        end
        for _, p in ipairs(availablePins) do p.__matchScore = nil end

      end
    end
    self.fgEditor.addHistory("Created new node "..node.path)
    return n
  end
end

function C:arrowHelper(cursor, itemSize, doHover, hoverFun)
  self.buttonListIndex = self.buttonListIndex +1
  if self.buttonListIndex == self.selectedButtonListIndex then
      im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                            cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                            im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                            cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                            im.GetColorU321(im.Col_HeaderActive), 1, 1)

      -- Set the scrollbar to show the selected node
      if arrowPressed then
        if cursor.y > im.GetScrollY() + im.GetWindowHeight() then
          im.SetScrollY(math.min(cursor.y - im.GetWindowHeight()/2, im.GetScrollMaxY()))
        end
        if cursor.y < im.GetScrollY() then
          im.SetScrollY(math.max(cursor.y - im.GetWindowHeight()/2, 0))
        end
        arrowPressed = false
      end

    end
    if doHover then
      if im.IsItemHovered() then
        -- display blue rectangle when node is hovered
        im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                              cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                              im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                              cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                              im.GetColorU321(im.Col_HeaderHovered), 1, 1)
        if hoverFun then hoverFun() end
      end
    end
  end


--- Exporter functionality ---

function C:printNodesWithTags()
  -- gather all tags
  local tags = {}
  local pins = {names = {}, pins = {}}
  for dir, list in pairs(self.mgr:getAvailableNodeTemplates()) do
    self:recursiveGetTags(list, tags, pins)
  end
  table.sort(pins.names, function(a,b) return #pins.pins[a] > #pins.pins[b] end)
  local libtxt = {}
  local header = 'Name\tFile\tPath\tPin Schema\tTodo\tDescription'
  table.insert(libtxt, header)
  for dir, list in pairs(self.mgr:getAvailableNodeTemplates()) do
    self:printDir(list, dir, tags, libtxt)
  end
  writeFile('nodeLib.csv', table.concat(libtxt, '\n'))
  editor.logDebug("Written Nodelib to nodeLib.csv")

  libtxt = {}
  header = 'Pin\tCount\tNode\tDesc'
  table.insert(libtxt, header)
  for _, name in ipairs(pins.names) do
    for _, node in ipairs(pins.pins[name]) do
      table.insert(libtxt,name..'\t'..(#pins.pins[name])..'\t'..node.name..'\t'..(node.pin.description or "(NONE)"))
    end
  end
  writeFile('pinLib.csv', table.concat(libtxt, '\n'))
  editor.logDebug("Written pinlist to pinLib.csv")
end

function C:printDir(dir, name, tagIndex, libtxt)

  for nName, node in pairs(dir.nodes) do
    local vals = {}
    table.insert(vals, node.node.name)
    table.insert(vals, nName)
    table.insert(vals, name)
    local mode = "mixed"
    local pinOld = 0
    local pinNew = 0
    for _, p in ipairs(node.node.pinSchema or {}) do
      if p.dir or p.type then
        pinNew = pinNew +1
      else
        pinOld = pinOld +1
      end
    end
    if pinNew == 0 and pinOld > 0 then
      mode = "old"
    elseif pinNew > 0 and pinOld == 0 then
      mode = "new"
    else
      mode = "mixed ("..pinNew.." new, " ..pinOld .. " old)"
    end

    table.insert(vals, mode)

    local t = node.node.todo or " "
    table.insert(vals, '' .. t .. '')
    local d = node.node.description or " "
    d = string.gsub(d,"\n",' | ')
    table.insert(vals, '' .. d .. '')
    --for _, tag in ipairs(tagIndex) do
    --  if arrayFindValueIndex(node.node.tags or {}, tag) then
    --    table.insert(vals,tag)
    --  else
    --    table.insert(vals,'')
    --  end
    --end

    table.insert(libtxt,(table.concat(vals, '\t')))
  end
    for dName, dir in pairs(dir) do
    if dName ~= 'nodes' then
      self:printDir(dir, name.."/"..dName, tagIndex, libtxt)
    end
  end
end

function C:recursiveGetTags(dir, list, pins)
  for dName, c in pairs(dir) do
    if dName ~= 'nodes' then
      self:recursiveGetTags(c, list, pins)
    end
  end
  for nName, node in pairs(dir.nodes) do
    -- manage Tags
    for _, tag in pairs(node.node.tags or {} ) do
      if arrayFindValueIndex(list, tag) == false then
        table.insert(list, tag)
      end
    end

    for _, p in ipairs(node.node.pinSchema or {}) do
      local pin = p.name
      if not pins.pins[pin] then
        table.insert(pins.names,pin)
        pins.pins[pin] = {}
      end
      table.insert(pins.pins[pin],{name = nName, pin = p})
    end
  end
end
return _flowgraph_createMgrWindow(C)
