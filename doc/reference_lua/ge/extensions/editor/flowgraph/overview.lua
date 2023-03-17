-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local fge = ui_flowgraph_editor
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local C = {}
C.windowName = 'fg_treeview'
C.windowDescription = 'Overview'

C.passedGraphIds = {}

function C:init()
  self.filter = im.ImGuiTextFilterPtr()
  self.contextMenuElement = nil
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
end

function C:attach(mgr)
  self.mgr = mgr
end

function C:drawPopups()
  if im.BeginPopup("nodeOverviewPopup") then
    if self.contextMenuNode and im.MenuItem1('Focus##' .. tostring("self_id")) then
      self:selectNode(self.contextMenuNode, false)
      fge.NavigateToSelection(true, 0.0001)
    end
    if self.contextMenuNode and im.MenuItem1('Delete##' .. tostring("self_id")) then
      self.mgr.graph:deleteNode(self.contextMenuNode)
    end
    --[[
    im.Separator()
    if im.MenuItem1('Copy##' .. tostring("self_id")) then

    end
    if im.MenuItem1('Paste##' .. tostring("self_id")) then

    end
    ]]--
    im.EndPopup()
  end
end

function C:skipDrawing(graph)
  if self.passedGraphIds[graph.id] then
    return false
  end

  -- Check if any parent passed the filter
  local parent = graph.parent
  while parent do
    if self.passedGraphIds[parent.id] then
      return false
    end
    parent = parent.parent
  end

  -- Check if any child passed the filter
  for _,child in ipairs(graph:getChildren()) do
    if self.passedGraphIds[child.id] then
      return false
    end
  end

  -- Check childs recursively
  for _,child in ipairs(graph:getChildren()) do
    if not self:skipDrawing(child) then
      return false
    end
  end

  return true
end


function C:drawGraph(graph)
  if self:skipDrawing(graph) then
    return
  end


  local graphId = graph.id

  local isLeaf = not next(graph:getChildren()) and not (editor.getPreference("flowgraph.debug.displayNodesInOverview") and next(graph.nodes))
  local selected = self.mgr.graph == graph
  if not selected and graph.type == 'instance' then
    selected = (self.mgr.recentInstance == graph) and (self.mgr.graph.id == graph.macroID )
  end
  local flags = bit.bor(im.TreeNodeFlags_OpenOnArrow, im.TreeNodeFlags_OpenOnDoubleClick, selected and im.TreeNodeFlags_Selected or 0, im.TreeNodeFlags_DefaultOpen, isLeaf and im.TreeNodeFlags_Leaf or 0)

  local txt = graph.name
  if editor.getPreference("flowgraph.debug.displayIds") then
    txt = txt .. ' (' .. tostring(graph.id) .. ')'
  end
  txt = txt .. (graph.dirty and "*" or "")

  local selectThisGraph = false
  local treeNodeOpen = im.TreeNodeEx1(txt .. '##'.. graph.id, flags)

  selectThisGraph = selectThisGraph or im.IsItemClicked()

  im.SameLine()
  local graphTypeStr = ui_flowgraph_editor.getGraphTypes()[graph.type].name
  if graph.type == 'graph' and graph.parentId then
    graphTypeStr = 'Sub Graph'
  end
  im.TextColored(ui_flowgraph_editor.getGraphTypes()[graph.type].color, "[" .. graphTypeStr .. "]")
  selectThisGraph = selectThisGraph or im.IsItemClicked()
  --im.SameLine()
  --im.TextColored(im.ImVec4(1,0.6,0,1), '[' .. tostring(tableSize(graph.nodes)) .. ']')
  --selectThisGraph = selectThisGraph or im.IsItemClicked()

  if selectThisGraph then
    dumpz(graph,1)
    self.mgr:selectGraph(graph)
  end

  if treeNodeOpen then
    for _,child in ipairs(graph:getChildren()) do
      self:drawGraph(child)
    end
  end

  if treeNodeOpen and editor.getPreference("flowgraph.debug.displayNodesInOverview") then
    -- Sort nodes by nodeid
    local sortedNodeIds = {}
    for id, node in pairs(graph.nodes) do
      table.insert(sortedNodeIds, id)
    end
    table.sort(sortedNodeIds)

    for _, id in ipairs(sortedNodeIds) do
      local node = graph.nodes[id]
      if node.nodeType ~= "macro/integrated" then
        if im.ImGuiTextFilter_PassFilter(self.filter, tostring(node.id)) or im.ImGuiTextFilter_PassFilter(self.filter, node.name) or self.passedGraphIds[node.graph.id] then
          local txt = node.name
          if editor.getPreference("flowgraph.debug.displayIds") then
            txt = txt .. ' - ' .. node.id
          end
          local clicked = false
          im.Selectable1(txt)
          if im.IsItemClicked() then clicked = true end
          im.SameLine()
          im.TextColored(im.ImVec4(1,0.6,0,1), " [Node]")

          if im.IsItemClicked() or clicked then
            self.mgr:selectGraph(node.graph)
            self:selectNode(node, im.GetIO().KeyCtrl)
          end
          --[[
          if im.IsItemHovered() then
            if im.IsMouseDoubleClicked(0) then
              fge.NavigateToSelection(false, 0.3)
            elseif im.IsMouseClicked(1) then
              --print("fge_mgr_win_overview.lua >> RMB")
              self.contextMenuNode = node
              im.OpenPopup("nodeOverviewPopup" .. tostring("self_id"))
            end
          end
          ]]
        end
      end
    end
  end
  if treeNodeOpen then
    im.TreePop()
  end

  return self.mgr.graph ~= graph
end

function C:fillPassedGraphsArray()
  for id, graph in pairs(self.mgr.graphs) do
    -- Check if the graph passes the filter
    if im.ImGuiTextFilter_PassFilter(self.filter, graph.name) then
      self.passedGraphIds[id] = true
    end

    -- Check if any of the nodes pass the filter
    if not self.passedGraphIds[id] and editor.getPreference("flowgraph.debug.displayNodesInOverview") then
      for _, node in pairs(graph.nodes) do
        if node.nodeType ~= "macro/integrated" and im.ImGuiTextFilter_PassFilter(self.filter, node.name) then
          self.passedGraphIds[id] = true
          break
        end
      end
    end
  end
  for id, graph in pairs(self.mgr.macros) do
    -- Check if the graph passes the filter
    if im.ImGuiTextFilter_PassFilter(self.filter, graph.name) then
      self.passedGraphIds[id] = true
    end

    -- Check if any of the nodes pass the filter
    if not self.passedGraphIds[id] and editor.getPreference("flowgraph.debug.displayNodesInOverview") then
      for _, node in pairs(graph.nodes) do
        if node.nodeType ~= "macro/integrated" and im.ImGuiTextFilter_PassFilter(self.filter, node.name) then
          self.passedGraphIds[id] = true
          break
        end
      end
    end
  end
end

function C:TreeView()
 if self:Begin('Overview') then
    -- sort graphs, macro originals and macro instances
    local rootGraphIDs = {}
    self.passedGraphIds = {}
    for id, graph in pairs(self.mgr.graphs) do
      if graph.parentId == nil then
        table.insert(rootGraphIDs,id)
      end
    end
    for id, graph in pairs(self.mgr.macros) do
      if graph.parentId == nil then
        table.insert(rootGraphIDs,id)
      end
    end
    self:fillPassedGraphsArray()
    table.sort(rootGraphIDs)

    self:drawPopups()

    im.ImGuiTextFilter_Draw(self.filter, "##nodeFilter" .. "self_id", 120)
    im.SameLine()
    if im.SmallButton('X') then
      im.ImGuiTextFilter_Clear(self.filter)
    end
    if editor.getPreference("flowgraph.debug.editorDebug") then
      im.SameLine()
      if im.SmallButton("Print Graphs") then
        print("-- Current child path --")
        dump(self.mgr.graph:getChildPosition())
        print("-- Current graphs children: --")
        print("-- Graphs --")
        for id, gr in pairs(self.mgr.graphs) do
          gr:printStructure()
          --if gr.parentId and not arrayFindValueIndex(gr.parent.children, gr) then
          --  print("Orphaned Graph: " .. gr:toString() .. " parent: " .. gr.parent:toString())
          --end
        end
        print("-- Macros --")
        for id, gr in pairs(self.mgr.macros) do
          gr:printStructure()
          --if gr.parent and not arrayFindValueIndex(gr.parent.children, gr) then
          --  print("Orphaned Graph: " .. gr:toString() .. " parent: " .. gr.parent:toString())
          --end
        end
      end
    end
    im.Separator()
    im.TextColored(im.ImVec4(0.8,0.8,1,1), "Graphs")
    im.BeginChild1("overviewchild###")
      -- GRAPHS
      for _, index in ipairs(rootGraphIDs) do
        local graph = self.mgr.graphs[index]
        if graph then
          self:drawGraph(graph)
        end
      end
      --[[
      if next(self.mgr.macros) then
        im.Separator()
        im.TextColored(im.ImVec4(0.8,0.8,1,1), "Macros")

        for _, macro in pairs(self.mgr.macros) do
          if macro.parent == nil then
            if self:drawGraph(macro) then
            --[[for _,instanceID in ipairs(macroList.sortedInstanceIDs) do
              self:drawGraph(self.mgr.graphs[instanceID])
            end]
            end
          end
        end
        im.Separator()
      end
      ]]
    im.EndChild()
  end
  self:End()
end

function C:draw()
  --if not self.mgr.mainWindow then return end
  if not editor.isWindowVisible(self.windowName) then return end
  --if not self.fgEditor.dockspaces["NE_LeftTopPanel_Dockspace"] then self.fgEditor.dockspaces["NE_LeftTopPanel_Dockspace"] = im.GetID1("NE_LeftTopPanel_Dockspace") end

  --im.SetNextWindowDockID(self.fgEditor.dockspaces["NE_LeftTopPanel_Dockspace"])
  self:TreeView()

end

function C:selectNode(node, append)
  fge.SelectNode(node.id, append)
end

return _flowgraph_createMgrWindow(C)
