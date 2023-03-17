-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local createBuilder = require('/lua/ge/extensions/flowgraph/builder')

local initialWindowSize = im.ImVec2(400, 400)

local drawnThisFrame = false
local drawmodeNames = {
  default = "Default",
  simple = "Simple",
  heatmap = "Heatmap",
}
local drawmodesSorted = {"default","heatmap","simple"}
local C = {}
C.windowName = 'fg_main'
C.windowDescription = 'Main view'

function C:attach(mgr)
  self.mgr = mgr

  self.borderColors = {
    running = im.ImVec4(1,0,0,0.5),
    paused = im.ImVec4(1,1,0,0.5),
    stopped = im.ImVec4(0,0,0,0),
    macro = ui_flowgraph_editor.getGraphTypes().macro.color
  }
  self.mgr.focusGraph = self.mgr.graph
end

function C:init()

  self.quickAccessTextfield = im.ArrayChar(64, "")
  self.fpsSmoother = newExponentialSmoothing(50, 1)
  self.restoreView = nil
  self.fgMgr = extensions['core_flowgraphManager']
  self.contextNodeId = ffi.new('fge_NodeId[1]', 0)
  self.contextPinId  = ffi.new('fge_PinId[1]', 0)
  self.contextLinkId = ffi.new('fge_LinkId[1]', 0)

  self.editorid = 'FlowGraphEditor_main_'

  self.windowPos = nil
  self.windowSize = nil

  self.fgEditor.dockspaces = {}

  self.isColumnWidthSet = false
  self.columnZeroWidth = 230
  self.columnTwoWidth = 280


  -- TODO: calculate by using window.TitleBarHeight & window.MenuBarHeight
  self.menuHeight = 48

  self.vertSliderHeight = 8
  self.vertSliderColor = im.GetColorU322(im.ImVec4(0.3,0.3,0.3,1))
  self.vertSliderColorHovered = im.GetColorU322(im.ImVec4(0.2,0.4,0.8,1))

  editor.registerWindow(self.windowName, im.ImVec2(600,600), nil, false)

end



function C:drawMenu()
  if im.BeginMenuBar() then
    if im.BeginMenu("File") then
      if im.MenuItem1("New Project") then
        local m = self.fgMgr.addManager()
        self.fgEditor.setManager(m)
      end
      if im.MenuItem1("Load Project...") then
        extensions.editor_fileDialog.openFile(function(data)self.fgEditor.openFile(data, true)end, {{"Any files", "*"},{"Node graph Files",".flow.json"}}, false, self.fgEditor.lastOpenedFolder)
      end
      if im.BeginMenu("Recent Files...") then
        local recentFiles = editor.getPreference("flowgraph.general.recentFiles") or {}
        if #recentFiles == 0 then
          im.BeginDisabled()
          im.Text("No Recent Files!")
          im.EndDisabled()
        else
          for idx, file in ipairs(recentFiles) do
            if FS:fileExists(file) then
              if im.MenuItem1(idx.." - " .. file) then
                self.fgEditor.openFile({filepath = file}, true)
              end
            else
              im.BeginDisabled()
              im.Text(idx.." - " .. file)
              im.EndDisabled()
              ui_flowgraph_editor.tooltip("No File Found under " .. dumps(file) .. " !")
            end
          end
        end
        im.EndMenu()
      end
      self.fgEditor.drawRestoreMenu()
      im.Separator()
      if im.MenuItem1("Save", nil, nil, self.mgr.allowEditing) then
        self.fgEditor.save()
      end
      if im.MenuItem1("Save as...", nil, nil, self.mgr.allowEditing) then
        extensions.editor_fileDialog.saveFile(function(data)self.fgEditor.saveAsFile(data)end, {{"Node graph Files",".flow.json"}}, false, self.fgEditor.lastOpenedFolder)

      end
      if im.MenuItem1("Save as Scenario...") then
        extensions.editor_fileDialog.saveFile(function(data)
          self.fgEditor.saveAsFile(data)
          local scenarioJson = {{
            name = self.mgr.name,
            description =  self.mgr.description,
            authors = "BeamNG",
            difficulty = 40,
            date= os.time(),
            flowgraph = self.mgr.savedDir..self.mgr.savedFilename,
          }}
          local fn =self.mgr.savedDir.. self.mgr.savedFilename:sub(0,-10)..'json'
          jsonWriteFile(fn, scenarioJson, true, 20)
          --dump("write to " .. fn)
        end, {{"Node graph Files",".flow.json"}}, false, self.fgEditor.lastOpenedFolder)
      end
      im.tooltip("Creates an additional .json file so this Project can be loaded as a scenario.")
      im.Separator()
      if im.MenuItem1("New Graph", nil, nil, self.mgr.allowEditing) then
        self.mgr:createGraph()
      end
      if im.MenuItem1("New Node", nil, nil, self.mgr.allowEditing) then
        local dirToOpen = self.fgMgr.nodePath
        if self.mgr.savedDir then
          dirToOpen = self.mgr.savedDir.."/customNodes"
        end

        extensions.editor_fileDialog.saveFile(
                function(data)
                  local nodeData = readFile('/lua/ge/extensions/flowgraph/newNodeTemplate.lua')
                  nodeData = nodeData:gsub("New Node Template", data.filename:sub(1,-5)) -- change name
                  data.filepath = data.filepath:gsub(".lua","Node.lua") -- add Node for customNodes system
                  writeFile(data.filepath, nodeData)
                  Engine.Platform.openFile(data.filepath)
                end,
                {{"Node",".lua"}},
                false,
                dirToOpen)
      end
      im.Separator()
      if im.MenuItem1("Close Project") then
        self.fgEditor.closeCurrent()
      end
      im.Separator()
      if im.MenuItem1("Load into current...") then
        extensions.editor_fileDialog.openFile(function(data)self.fgEditor.openFile(data, false)end, {{"Any files", "*"},{"Node graph Files",".flow.json"}}, false, self.fgEditor.lastOpenedFolder)
      end
      ui_flowgraph_editor.tooltip("Replaces the current projects contents with a loaded one.")
      if im.MenuItem1("Load Macro from file...") then
        extensions.editor_fileDialog.openFile(function(data)self.mgr:createNewMacroNode(data.filepath)end, {{"Any files", "*"},{"Node graph Files",".macro.flow.json"}}, false, self.fgEditor.lastOpenedFolder)
      end
      im.EndMenu()
    end
    if im.MenuItem1("Focus Selection") then
      self.fgEditor.uiFocusNodesShortcut()
    end


    --TODO: replace this settings window and point the menu to Preferences window with Flowgraph page selected
    if im.MenuItem1("Preferences...") then
      editor.showPreferences('flowgraph')
    end

    if im.BeginMenu("Windows") then
      self.fgEditor.windowsMenu()
      im.EndMenu()
    end

    if im.MenuItem1("Clear") then
      self.mgr:clearGraph()
    end

    local io = im.GetIO()
    local fps = self.fpsSmoother:get(io.Framerate)
    im.Text("FPS: %.2f (%.2gms)", fps, fps and 1000 / fps or 0)

    im.EndMenuBar()
  end
end

function C:drawGraph(graph, builder, style)
  if drawnThisFrame then return end
  drawnThisFrame = true
  if graph.restoreView then
    if graph.viewPos and graph.viewZoom then
      if graph.focusSelection then
        graph.viewZoom = im.FloatPtr(1)
      end
      ui_flowgraph_editor.setViewState(graph.viewPos, graph.viewZoom)
      --print(string.format(graph.name.. " Restoring View to: %d %d / %0.2f", graph.viewPos[0].x, graph.viewPos[1].y, graph.viewZoom[0]))
    else
      --print(graph.name .. " Nothing to restore, navigating to contend")
      ui_flowgraph_editor.NavigateToContent(0.01)
    end

    graph.restoreView = false
  else
    if not graph.viewPos or not graph.viewZoom then
      graph.viewPos = im.ImVec2Ptr(0, 0)
      graph.viewZoom = im.FloatPtr(0)
    end
--    local o1, o2, o3  = graph.viewPos[0].x, graph.viewPos[0].y, graph.viewZoom[0]
    ui_flowgraph_editor.getViewState(graph.viewPos, graph.viewZoom)
    --if o1 ~= graph.viewPos[0].x or o2 ~= graph.viewPos[0].y or o3 ~= graph.viewZoom[0] then
    --  print(string.format(graph.name.." Saved View to: %d %d / %0.2f", graph.viewPos[0].x, graph.viewPos[1].y, graph.viewZoom[0]))
    --end
  end
  for k, node in pairs(graph.nodes) do
    local status, err, res = xpcall(node.draw, debug.traceback, node, builder, style, drawType)
    if not status then
      log('E', 'node.'..tostring('drawGraph'), tostring(err))
      node:__setNodeError('work', 'Error while executing node:_drawMiddle(): ' .. tostring(err))
    end
  end
  -- draw hidden links after regular links
  local hiddenLinks = {}
  for _, link in pairs(graph.links) do
    if link.hidden then
      table.insert(hiddenLinks, link)
    else
      link:draw()
    end
  end
  for _, link in ipairs(hiddenLinks) do
    link:draw()
  end

  if graph.focusDelay == 0 then
    --[[print("Navigating to Content")
    if graph.viewPos and graph.viewZoom then
      graph.viewZoom[0] = 1
      print(string.format("Restoring to: %d %d / %0.2f", graph.viewPos[0].x, graph.viewPos[1].y, graph.viewZoom[0]))
      ui_flowgraph_editor.setViewState(graph.viewPos, graph.viewZoom)
    end]]
    if graph.focusSelection then
      ui_flowgraph_editor.NavigateToSelection(false, 0.30)
    end
    if graph.focusContent then
      ui_flowgraph_editor.NavigateToContent(0.30)
    end
    graph.focusSelection = nil
    graph.focusContent = nil
    graph.focusDelay = nil
  else
    if graph.focusDelay then
      graph.focusDelay = graph.focusDelay -1
    end
  end
  -- PIN-IN link debug:
end

local leftHovered = false
local dragging = false

local winPos
local showMenu =  im.BoolPtr(false)
local deltaYSum = 0
local deltaYSumBounds = {}
local isColumnWidthSet = false
local initialLeftColumnWidth = 250
local initialRightColumnWidth = 250

local flags = im.flags(im.WindowFlags_MenuBar, im.WindowFlags_NoScrollbar, im.WindowFlags_NoCollapse)




function C:drawSelf()

  --if winPos then im.SetNextWindowPos(winPos) end
  --im.SetNextWindowSize(initialWindowSize, im.Cond_FirstUseEver)

    --[[if im.IsWindowFocused(im.FocusedFlags_ChildWindows) then
      pushActionMap("FlowgraphMain")
      table.insert(editor.additionalActionMaps, "FlowgraphMain")
    else
      popActionMap("FlowgraphMain")
    end
    ]]

    self.windowSize = im.GetWindowSize()
    self.windowPos = im.GetWindowPos()
    self.windowPadding = im.GetStyle().WindowPadding

    self.dl = im.GetWindowDrawList()
    self.pos = im.GetCursorScreenPos()


    -- im.PopStyleVar() -- StyleVar_WindowPadding

    im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(8, 8))
    self:drawMenu()
    im.PopStyleVar()

    if self.mgr.dragging and im.IsMouseReleased(0) then
      if self:isMouseHovering() then
        self:resolveDragDropPayload()
      end
      self.mgr:onDragEnded()
    end

    self.fgEditor.nodePreviewPopup:setNode(nil)
    -- main dockspace for graph tabs - so they always are connected to the menu-"window"
    im.BeginChild1("MainPanelChild", nil, false)
    if not self.fgEditor.dockspaces["NE_Main_Dockspace"] then self.fgEditor.dockspaces["NE_Main_Dockspace"] = im.GetID1("NE_Main_Dockspace") end
    im.DockSpace(self.fgEditor.dockspaces["NE_Main_Dockspace"], im.ImVec2(0, 0), im.DockNodeFlags_None)
    im.EndChild()
    im.NextColumn()

    local allGraphs = {}
    if self.windowSize.y < (editor.getPreference("flowgraph.debug.minEditorHeight") or 150) then
      im.Text("Window too small!")
      return
    end
    for _,gr in pairs(self.mgr.graphs) do table.insert(allGraphs, gr) end
    -- graph tabs
    --dumpz(allGraphs,2)
    table.sort(allGraphs, function(a,b) return a.id < b.id end)
    local s = ""
    for _, gr in ipairs(allGraphs) do s = s..gr.name.."  " end
    local focusGraphNow = self.mgr.focusGraph
    local setGraphAfter = nil
    drawnThisFrame = false
    for _,gr in ipairs(allGraphs) do
      --print(gr:getLocation())
      local graph = gr
      local gridColor = ui_flowgraph_editor.getGraphTypes().graph.gridColor
      if gr.type == 'instance' then
        if self.mgr.runningState == 'stopped' then
          graph = gr:getMacro()
          gridColor = ui_flowgraph_editor.getGraphTypes().macro.gridColor
        else
          gridColor = ui_flowgraph_editor.getGraphTypes().instance.gridColor
        end
      end
      if graph.isStateGraph then
        gridColor = ui_flowgraph_editor.getGraphTypes().state.gridColor
      end

      if self.mgr.runningState == 'running' then
        gridColor = ui_flowgraph_editor.getGraphTypes().instance.gridColor
      end

      local prettyInfo = ui_flowgraph_editor.getGraphTypes()[gr.type]

      local name = prettyInfo.abbreviation ..gr.name
      if gr.isStateGraph then name = "[S]"..name end
      local focussed = false
      if focusGraphNow and focusGraphNow == gr then
        --print("Focusgraph to " .. self.mgr.focusGraph.name .. "/" ..self.mgr.focusGraph.id)
        self.mgr.focusGraph.showTab[0] = true
        im.SetNextWindowFocus()
        self.mgr.focusGraph = nil
        focussed = true
        --focusGraphNow = nil
      end

      --dumpz(gr,1)
      if graph and gr.showTab[0] then
        local tabColors = nil
        if gr.isStateGraph then tabColors = ui_flowgraph_editor.getGraphTypes()['state'] end
        if tabColors then
          im.PushStyleColor2(im.Col_TabActive ,tabColors.tabSelected)
          im.PushStyleColor2(im.Col_TabHovered ,tabColors.tabHovered)
          im.PushStyleColor2(im.Col_Tab ,tabColors.tabColor)
          im.PushStyleColor2(im.Col_TabUnfocused ,tabColors.tabUnfocused)
          im.PushStyleColor2(im.Col_TabUnfocusedActive ,tabColors.tabUnfocusedActive)
        end
        --im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(6, 6))
        im.SetNextWindowDockID(self.fgEditor.dockspaces["NE_Main_Dockspace"])
        --im.PushStyleColor2(im.Col_TabActive ,prettyInfo.tabColor)
        local windowFlags = im.WindowFlags_NoFocusOnAppearing
        if graph.dirty then
          windowFlags = windowFlags + im.WindowFlags_UnsavedDocument + im.WindowFlags_NoMove
        end
        if im.Begin(name..'##'..gr.id, gr.showTab, windowFlags) then
          --dump(im.GetWindowDrawList())
          if not focussed and ((not self.mgr.graph) or (gr.id ~= self.mgr.graph.id)) and im.IsWindowFocused() then
            --print("mgr graph " .. dumps(self.mgr.graph and self.mgr.graph.id) .. " vs this graphs id: " .. gr.id .." " .. gr.name)
            setGraphAfter = gr
          end
          if editor.getPreference("flowgraph.debug.editorDebug") then
            ui_flowgraph_editor.tooltip("Selected Graph: " .. gr:toString() .. ", displayed graph " .. graph:toString())
          end
          if self._storedAllowEdit ~= nil then
            self.mgr.allowEditing = self._storedAllowEdit
            self._storedAllowEdit = nil
          end
          if not editor.getPreference("flowgraph.debug.transientEditable") and self.mgr.transient then
            self._storedAllowEdit = self.mgr.allowEditing
            self.mgr.allowEditing = false
          end
          local graphReadOnly = not self.mgr.allowEditing

          im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(6, 6))
          if gridColor then
            ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_Grid, gridColor)
          end

          if self.mgr.graph then
            im.SetCursorPosY(im.GetCursorPosY()+5)
            im.Columns(3)
            editor.uiIconImage(self.mgr.runningState ~= "running" and editor.icons.pause_circle_outline or editor.icons.play_circle_filled, im.ImVec2(20, 20))
            ui_flowgraph_editor.tooltip(self.mgr.runningState == "running" and "Project Running" or "Project Stopped")
            im.SameLine()
            im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 0))
            local _, lNames, lIds = gr:getLocation()
            for i, n in ipairs(lNames) do
              local txt = n
              if editor.getPreference("flowgraph.debug.displayIds") then txt = string.format("[%d] " .. n, lIds[i]) end
              local cursor = im.GetCursorPos()
              if self.mgr.graphs[lIds[i]].isStateGraph then
                im.PushStyleColor2(im.Col_Text, ui_flowgraph_editor.nodeColors.state)
                im.Text(txt)
                im.PopStyleColor()
              else
                im.Text(txt)
              end
              im.SameLine()
              local isClicked, isHovered = im.IsItemClicked(), im.IsItemHovered()
              local itemSize = im.GetItemRectSize()
              editor.uiIconImage(editor.icons.navigate_next, im.ImVec2(20,20))
              if im.IsItemClicked() then
                im.OpenPopup("FG_SiblingGraphs")
                self._siblings = self.mgr.graphs[lIds[i]]:getChildrenWithStates()
              end
              im.SameLine()
              if i < #lNames then
                if isHovered then
                  -- display blue rectangle when node is hovered
                  im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                                        cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                                        im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                                        cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                                        im.GetColorU321(im.Col_HeaderHovered), 1, 1)
                end
                if isClicked then
                  self.mgr:selectGraph(self.mgr.graphs[lIds[i]])
                end
              end
            end
            im.PopStyleVar()
            if im.BeginPopup("FG_SiblingGraphs") then
              for _, sib in ipairs(self._siblings or {}) do
                if sib.isStateGraph then
                  im.PushStyleColor2(im.Col_Text, ui_flowgraph_editor.nodeColors.state)
                end
                local txt = sib.name
                if editor.getPreference("flowgraph.debug.displayIds") then txt = string.format("[%d] " .. sib.name, sib.id) end
                if im.Selectable1(txt) then
                  self.mgr:selectGraph(sib)
                end
                if sib.isStateGraph then
                  im.PopStyleColor()
                end
              end
              if not self._siblings or #self._siblings == 0 then
                im.TextDisabled("No Entries!")
              end

              im.EndPopup()
            end
            --[[
              im.SameLine()
              if editor.uiIconImageButton(editor.icons.gesture, im.ImVec2(20,20)) then
                self.mgr:updateNodePositions()
              end
            ]]

            im.NextColumn()
            if self.mgr.runningState == "stopped" then

              if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(20, 20)) then
                self.mgr:setRunning(true)
                if editor.getPreference("flowgraph.general.minimizeFlowgraphWhenRunning") then
                  self.fgEditor.switchToSmallWindow = true
                end
              end
              ui_flowgraph_editor.tooltip("Start Execution")
              im.SameLine()
              if editor.uiIconImageButton(editor.icons.skip_next, im.ImVec2(20, 20)) then
                self.mgr:setRunning(true)
                self.mgr:setPaused(true)
              end
              ui_flowgraph_editor.tooltip("Start and immediatly pause")
            elseif self.mgr.runningState == "running" then

              editor.uiIconImage(editor.icons.play_arrow, im.ImVec2(20, 20))
              ui_flowgraph_editor.tooltip("Project running")

              im.SameLine()
              if editor.uiIconImageButton(editor.icons.pause, im.ImVec2(20, 20)) then
                self.mgr:setPaused(true)
              end
              ui_flowgraph_editor.tooltip("Pause")

            elseif self.mgr.runningState == "paused" then

              if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(20, 20)) then
                self.mgr:setPaused(false)
              end
              ui_flowgraph_editor.tooltip("Resume Execution")
              im.SameLine()
              if editor.uiIconImageButton(editor.icons.skip_next, im.ImVec2(20, 20)) then
                self.mgr:setPaused(false)
                self.mgr.steps = 1
              end
              ui_flowgraph_editor.tooltip("Step 1 Frame")
            end

            im.SameLine()
            --im.SetCursorPosX(im.GetCursorPosX()+20)
            if self.mgr.runningState ~= "stopped" then
              if editor.uiIconImageButton(editor.icons.stop, im.ImVec2(20, 20)) then
                self.mgr:setRunning(false)
              end
              ui_flowgraph_editor.tooltip("Stop Execution")
            else
              editor.uiIconImage(editor.icons.stop, im.ImVec2(20, 20))
              ui_flowgraph_editor.tooltip("Project stopped")
            end
            im.SameLine()
            im.Dummy(im.ImVec2(20,5))
            im.SameLine()
            if editor.getPreference("flowgraph.debug.editorDebug") then
              if editor.uiIconImageButton(editor.icons.replay, im.ImVec2(20, 20)) then
                local serialized = self.mgr:_onSerialize()
                self.mgr:_onDeserialized(serialized)
              end
              ui_flowgraph_editor.tooltip("Reserialize Mgr (debug)")
            end

            im.SameLine()
            if editor.uiIconImageButton(editor.icons.fullscreen_exit, im.ImVec2(20, 20)) then
              self.fgEditor.switchToSmallWindow = true
            end
            ui_flowgraph_editor.tooltip("Minimize Editor.")
            im.SameLine()
            local setHide = im.BoolPtr(editor.getPreference("flowgraph.general.minimizeFlowgraphWhenRunning"))
            if im.Checkbox("Use Monitor", setHide) then
              editor.setPreference("flowgraph.general.minimizeFlowgraphWhenRunning", setHide[0])
            end
            ui_flowgraph_editor.tooltip("Hides the editor when running and shows the Monitor instead.")
            if editor.getPreference("flowgraph.debug.duplicateIdCheck") then
              local ids = {}
              local duplicateIds = {}
              for node in self.mgr:allNodes() do
                if ids[node.id] then table.insert(duplicateIds,node.id) end
                ids[node.id] = true
              end
              for _, gr in ipairs(self.mgr.graphs) do
                if ids[gr.id] then table.insert(duplicateIds,gr.id) end
                ids[gr.id] = true
              end
              im.SameLine()
              if #duplicateIds > 0 then
                im.PushStyleColor2(im.Col_Button, im.ImVec4((os.clock()*3)%1,0,0,1))
                if im.Button("Duplicate id!!: " ..#duplicateIds) then
                  print("-------------")
                  for _, duplicateId in ipairs(duplicateIds) do
                    for node in self.mgr:allNodes() do
                      if node.id == duplicateId then
                        dump("Node " .. node.name .. "/"..node.id.." in " .. node.graph:getLocation(true))
                      end
                    end
                    for _, gr in ipairs(self.mgr.graphs) do
                      if gr.id == duplicateId then
                        dump("Graph "..gr.id.."/ in " .. gr:getLocation(true))
                      end
                    end
                    print("-------------")
                  end
                end
              else
                im.PushStyleColor2(im.Col_Button, im.ImVec4(0.2,0.75,0.25,0.6))
                if im.Button("All OK :) " .. table.getn(ids)) then
                  dump(ids)
                end

              end
              im.PopStyleColor()
            end
            im.NextColumn()
            im.Text("Viewmode: ")
            im.SameLine()
            im.PushItemWidth(100)
            local drawmode = editor.getPreference("flowgraph.debug.viewMode")
            if im.BeginCombo("##drawmode", drawmodeNames[drawmode]) then
              for _, m in ipairs(drawmodesSorted) do
                if im.Selectable1(drawmodeNames[m], m == drawmode) then
                  editor.setPreference("flowgraph.debug.viewMode", m)
                end
              end
              im.EndCombo()
            end
            im.PopItemWidth()
            if graph.type == 'instance' then
              im.SameLine()
              im.TextColored(im.ImVec4(1,0.25,0.25,1), "This is an Instance. Read only.")
            elseif graph.type == 'macro' then
              im.SameLine()
              im.Text("This is a Macro.")
            else
              if self.mgr.frameCount > 0 then
                --im.Text("Running for " .. self.mgr.frameCount .. " frames.")
                im.SameLine()
                im.Text("Frame " .. self.mgr.frameCount)
              --else
                --im.Text("Dirty: " .. tonumber(ui_flowgraph_editor.GetDirtyReason()))
              end
            end

            if editor.getPreference("flowgraph.debug.editorDebug") then
              for _, map in ipairs({"FlowgraphMain","Flowgraph","NodeLibrary"}) do
                im.Text("["..(self.fgEditor.isActionMapEnabled(map) and "Yes" or "No").."]".. map.."  ")
                im.SameLine()
              end
              im.SameLine()

              im.Text(string.format("Lows: %d/%d | Highs: %d", self.mgr.__graphNodeOffset or 0, self.mgr.__nextFreeGraphNodeStart or 0, -1*((2^29) - (self.mgr.__nextFreePinLinkStart or 2^29))))
              if im.IsItemClicked() then
                local nIds, boxes = {}, {}
                for _, g in pairs(self.mgr.graphs) do
                  for nid, _ in pairs(g.nodes) do
                    local box = math.ceil(nid/100)
                    if nIds[box] == nil then nIds[box] = {} table.insert(boxes, box) end
                    table.insert(nIds[box], nid)
                  end
                end
                table.sort(boxes)
                for _, b in ipairs(boxes) do
                  table.sort(nIds[b])
                  dump(string.format("%ders: %s", (b-1)*100, table.concat(nIds[b],", ")))
                end
              end
              im.SameLine()
            end
                --im.Text(self.mgr.graph:toString())
                --im.Text(self.mgr.recentInstance and  self.mgr.recentInstance:toString() or " - ")

            im.Columns(1)
            im.Separator()
            im.SetCursorPosY(im.GetCursorPosY()+1)

          end

          local clr = nil
          --[[
          if graph.type == "macro" then
            clr = self.borderColors.macro
          end
          ]]

            clr = self.borderColors[self.mgr.runningState]


          im.PushStyleColor2(im.Col_Border, clr)
          --im.BeginChild1("Borders",nil, 1)

          ui_flowgraph_editor.Begin(self.editorid, im.ImVec2(0, -5), graphReadOnly)
          if im.IsWindowFocused() then
            if not self.pushedActionMap then
              pushActionMapHighestPriority("Flowgraph")
              table.insert(editor.additionalActionMaps, "Flowgraph")
              self.pushedActionMap = true
            end
          else
            if self.pushedActionMap then
              popActionMap("Flowgraph")
              self.pushedActionMap = nil
            end
          end
          im.PopStyleVar()

          local cursorTopLeft = im.GetCursorScreenPos()

          local builder = createBuilder()
          builder.drawDebug = ui_flowgraph_editor.getDebugEnabled()
          if self.mgr.transient then
            local vp, vz = im.ImVec2Ptr(0,0), im.FloatPtr(0)
            ui_flowgraph_editor.getViewState(vp, vz)
            im.SetCursorPos(im.ImVec2(50/vz[0]-im.GetWindowPos().x+vp[0].x / vz[0], 5/vz[0]-im.GetWindowPos().y+vp[0].y / vz[0]))
            editor.uiIconImage(editor.icons.goat, im.ImVec2(300/vz[0],300/vz[0]), im.ImVec4(math.sin(os.clock()*3)*0.25+0.75,0.25,0.25,1))
          end

          local style = im.GetStyle()
          -- DBEUG: draw all graphs:
          --for _, g in pairs(self.mgr.graphs) do self:drawGraph(g, builder, style) end
          -- draw current graph only:


          if editor.getPreference("flowgraph.debug.displayFlowLinks") then
            local virtualPinLinkCol = im.ImVec4(1, 0, 0, 0.3)
            local virtualFlowPinLinkCol = im.ImVec4(1, 0.333, 0, 0.3)
            local lnks = {}
            for _, gr in pairs(self.mgr.graphs) do
              drawnThisFrame = false
              self:drawGraph(gr, builder, style)
              for k, node in pairs(gr.nodes) do
                for pinName, pin in pairs(node.pinInLocal) do
                  if pin.type ~= "flow" then
                    if node.pinIn[pin.name] and node.pinIn[pin.name].id then
                        table.insert(lnks,{pin.id, node.pinIn[pin.name].id, false})
                    end
                  else
                    for fName, flowPin in pairs(node._mInFlow[pinName] or {}) do
                      table.insert(lnks,{pin.id, flowPin.id, true})
                    end
                  end
                end
              end
            end
            if globIn and globOut then table.insert(lnks,{globIn,globOut,true}) end
            for i,lnk in pairs(lnks) do
               ui_flowgraph_editor.Link(9999999+i, lnk[1],lnk[2], lnk[3] and virtualFlowPinLinkCol or virtualPinLinkCol,15, false, "...")
            end
          else
           if graph then self:drawGraph(graph, builder, style) end
          end
          im.SetCursorScreenPos(cursorTopLeft)


          im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(6, 6))
          self:doContextMenus()
          im.PopStyleVar()

          -- these things show tooltips in the main window ...
          if self.mgr.allowEditing then
            self.mgr:creationWorkflow()
            self.mgr:deletionWorkflow()
          end

          --for _, node in pairs(gr.nodes) do
          --  node:overDraw()
          --end
          ui_flowgraph_editor.End()
          im.PopStyleColor(1)
          ui_flowgraph_editor.PopStyleColor(1)
          --print(im.IsWindowFocused(im.FocusedFlags_ChildWindows))

          if (bit.band(tonumber(ui_flowgraph_editor.GetDirtyReason()), ui_flowgraph_editor.Dirty_Position) ~= 0) then --and im.IsMouseReleased(0) then
            if self.mgr._ignoreMove then
              self.mgr._ignoreMove = nil
            else
              if self.fgEditor.delayedHistorySnapshot == nil and ui_flowgraph_editor.IsActive() then
                for _, node in pairs(graph.nodes) do
                  node:updateNodePosition()
                end
                self.fgEditor.addHistory("Moved Node(s) in " .. graph.name, nil)
              end
            end
          end
          ui_flowgraph_editor.ClearDirty()
        end
        im.End()
        if tabColors then  im.PopStyleColor(5) end
        --im.PopStyleVar(im.StyleVar_WindowPadding,)
        --          im.PopStyleColor(1)

      end

    end
    if setGraphAfter and focusGraphNow then
      --print("Setting graph but also focussing now..?")
    end
    if setGraphAfter and not focusGraphNow then
      --print("setgraph id is " .. dumps(setGraphAfter.id))
      self.mgr:selectGraph(setGraphAfter)
    end
  --end


  --self:End()
  --im.PopStyleVar()
end

function C:draw()
  self:drawSelf()
end


local orangeColor, whiteColor, whiteStrong = im.ImVec4(1,0.5,0,1), im.ImVec4(1,1,1,0.25), im.ImVec4(1,1,1,0.9)
local qaWidth = 200
function C:showQuickAccessSubmenu(menuPos, pin)

  if im.BeginMenu("Quick Connect") then
    im.SetWindowFontScale(1/editor.getPreference("ui.general.scale"))
    -- find targets and sorted names
    if self.quickConnectPins == nil then
      self.quickConnectPins = {}
      -- get unique names with their types
      for _, node in pairs(self.mgr.graph.nodes) do
        for _, p in pairs(node.pinList) do
          if p.quickAccess and p.direction ~= pin.direction then
            if self.mgr.graph:pinsCompatible(pin, p) then
              self.quickConnectPins[p.accessName] = p
            end
          end
        end
      end
      -- sort targets
      self.quickConnectSortedNames = {}
      for name,_ in pairs(self.quickConnectPins) do
        table.insert(self.quickConnectSortedNames, name)
      end
      table.sort(self.quickConnectSortedNames)
    end

    -- register quick connect
    if pin.quickAccess  then
      if im.Button("Remove Quick Access",im.ImVec2(200*editor.getPreference("ui.general.scale"),0)) then
        pin.quickAccess = nil
        pin.accessName = nil
        im.CloseCurrentPopup()
      end
    else
      if self.quickAccessTextfield == nil then
        self.quickAccessTextfield = im.ArrayChar(64, pin.name)
      end
      local entered = false
      im.PushItemWidth((200-30) * editor.getPreference("ui.general.scale"))
      entered = im.InputText("##quickAccessName", self.quickAccessTextfield,64, im.InputTextFlags_EnterReturnsTrue)
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.check, im.ImVec2(20,20)) or entered then
        local nameTaken = false
        local ffiName = ffi.string(self.quickAccessTextfield)
        for _, node in pairs(self.mgr.graph.nodes) do
          for _, p in pairs(node.pinList) do
            if p.direction == pin.direction and p.quickAccess and p.accessName == ffiName then
              nameTaken = true
              self.quickAccessError = 'There is already an out pin with this name.'
            end
          end
        end
        if not nameTaken then
          pin.quickAccess = true
          pin.accessName = ffi.string(self.quickAccessTextfield)
          im.CloseCurrentPopup()
        end
      end

      if self.quickAccessError then
        im.Text(self.quickAccessError)
      end
      im.PopItemWidth()
      im.Dummy(im.ImVec2(1,4))
      im.Separator()
    end


    -- list of buttons to select from
    if next(self.quickConnectSortedNames) then
      if pin.direction == 'in' and pin.type ~= 'flow' then
        im.Text("Replace Link with...")
      else
        im.Text("Connect Pin to...")
      end
      for _, name in ipairs(self.quickConnectSortedNames) do
        local cursor = im.GetCursorPos()
        im.BeginGroup()
        local action = "link"
        local other = self.quickConnectPins[name]
        --if pin.direction == 'out'
        if (other.type ~= 'flow' or pin.type ~= "flow") and (self.mgr.graph:hasLink(other) or self.mgr.graph:hasLink(pin)) then
            action = "replace"
        end
        local lnkRemove = nil
        for _, lnk in pairs(self.mgr.graph.links) do
          if lnk.sourcePin == pin and lnk.targetPin == other or lnk.sourcePin == other and lnk.targetPin == pin then
            action = "remove"
            lnkRemove = lnk
          end
        end
        local icon = editor.icons.link
        if action == "replace" then
          icon = editor.icons.autorenew
        elseif action == "remove" then
          icon = editor.icons.delete_forever
        end
        editor.uiIconImage(icon, im.ImVec2(22, 22), whiteStrong)
        im.SameLine()
        --  ui_flowgraph_editor.tooltip("Replacing original target link.")
        self.mgr:DrawTypeIcon(other.type, true, 1)
        im.SameLine()
        im.Text(name)

        im.SameLine()
        im.BeginDisabled()
        im.Text(other.node.name)
        im.EndDisabled()
        im.SameLine()
        im.Dummy(im.ImVec2(im.GetContentRegionAvailWidth()-5,1))
        im.EndGroup()
        if im.IsItemClicked() then
          if action == 'remove' then
            self.mgr.graph:deleteLink(lnkRemove)
            self.fgEditor.addHistory("Unlinked " ..name .. " and " .. pin.name)
          else
            if pin.direction == 'in' then
              if pin.type ~= 'flow' then
                -- remove existing link
                local toDelete = nil
                for _, lnk in pairs(self.mgr.graph.links) do
                  if lnk.targetPin.id == pin.id then
                    toDelete = lnk
                  end
                end
                if toDelete then
                  self.mgr.graph:deleteLink(toDelete)
                end
              end
              local lnk = self.mgr.graph:createLink(other, pin)
              self.fgEditor.addHistory("Linked " ..name .. " and " .. pin.name)
              lnk.hidden = true
            else
              if action == 'replace' then
                -- remove existing link
                local toDelete = nil
                for _, lnk in pairs(self.mgr.graph.links) do
                  if lnk.targetPin == other then
                    toDelete = lnk
                  end
                end
                if toDelete then
                  self.mgr.graph:deleteLink(toDelete)
                end
              end
              if action == 'replace' or action == 'link' then
                local lnk = self.mgr.graph:createLink(pin,other)
                self.fgEditor.addHistory("Linked " ..pin.name .. " and " .. name)
                lnk.hidden = true
              end
            end
          end
          im.CloseCurrentPopup()
        end
        local itemSize = im.GetItemRectSize()
        local clr = im.IsItemHovered() and orangeColor or whiteColor
        im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                            cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                            im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                            cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                            im.GetColorU322(clr), 1, 1)
      end
    else
      im.Text("No compatible pins found!")
    end
    im.SetWindowFontScale(1)
    im.EndMenu()
  else
    self.quickAccessError = nil
    self.quickAccessTextfield = nil
    self.quickConnectPins = nil
  end
end


function C:showNewNodeContextMenu(menuPos)
  im.PushStyleColor2(im.Col_Border, im.ImVec4(1.0, 1.0, 1.0, 0.25))
  im.BeginChild1("##createnodespopup", im.ImVec2(300 * editor.getPreference("ui.general.scale"), 300 * editor.getPreference("ui.general.scale")), false)
  if self.mgr.allowEditing then
    --if self.mgr.newNodeLinkPin then
    --  self:showQuickAccessSubmenu(menuPos, self.mgr.newNodeLinkPin)
    --end
    self.fgEditor.nodelib:drawContent(menuPos, true)
  else
    im.Text("Disabled.")
  end
  im.EndChild()
  im.PopStyleColor()
end

function C:resolveDragDropPayload()
  if self.mgr.allowEditing then
    if self.mgr.dragDropData.payloadType == "NodeDragDropPayload" then
      local node = self.mgr.graph:createNode(self.mgr.dragDropData.node.path)
      local pos = ui_flowgraph_editor.ScreenToCanvas(im.GetMousePos())
      ui_flowgraph_editor.SetNodePosition(node.id, pos)
      node:alignToGrid()
      self.fgEditor.addHistory("Created Node " .. self.mgr.dragDropData.node.path)
    end
    if self.mgr.dragDropData.payloadType == "macroDragDropPayload" then
      local node = self.mgr.graph:createNode('macro/integrated')
      local instance = self.mgr:createMacroInstanceFromPath(self.mgr.dragDropData.node.path, node)
      local pos = ui_flowgraph_editor.ScreenToCanvas(im.GetMousePos())
      ui_flowgraph_editor.SetNodePosition(node.id, pos)
      node:alignToGrid()
      node:setTargetGraph(instance)
      node:gatherPins()
      self.fgEditor.addHistory("Created macro " .. self.mgr.dragDropData.node.path)
    end
    if self.mgr.dragDropData.payloadType == "variableNodeDragDropPayload" then
      local read = self.mgr.dragDropData.node.read or false
      local varName = self.mgr.dragDropData.node.varName
      local nodePath = read and "types/getVariable" or "types/setVariable"
      local node = self.mgr.graph:createNode(nodePath)
      local pos = ui_flowgraph_editor.ScreenToCanvas(im.GetMousePos())
      ui_flowgraph_editor.SetNodePosition(node.id, pos)
      node:alignToGrid()
      node:setGlobal(self.mgr.dragDropData.node.global)
      node:setVar(varName)
      self.fgEditor.addHistory("Created variable node for " .. varName)
    end
  end
end

function C:isMouseHovering()
  local mousePos = im.GetIO().MousePos
  if (mousePos.x >= self.windowPos.x and mousePos.x <= (self.windowPos.x + self.windowSize.x)) and (mousePos.y >= self.windowPos.y and mousePos.y <= (self.windowPos.y + self.windowSize.y)) then
    return true
  else
    return false
  end
end

local openedContextMenu = true
function C:doContextMenus()
  local mousePos = im.GetMousePos()
  ui_flowgraph_editor.Suspend()


  if ui_flowgraph_editor.ShowNodeContextMenu(self.contextNodeId) then
    if not self.mgr.selectedNodes[tonumber(self.contextNodeId[0])] then
      ui_flowgraph_editor.ClearSelection()
      ui_flowgraph_editor.SelectNode(self.contextNodeId[0], true)
    end
    im.OpenPopup("Node Context Menu")
    self.mgr.openPopupPosition = mousePos
  elseif ui_flowgraph_editor.ShowPinContextMenu(self.contextPinId) then
    im.OpenPopup("Pin Context Menu")
    self.mgr.openPopupPosition = mousePos
  elseif ui_flowgraph_editor.ShowLinkContextMenu(self.contextLinkId) then
    if not self.mgr.selectedLinks[tonumber(self.contextLinkId[0])] then
      ui_flowgraph_editor.ClearSelection()
      ui_flowgraph_editor.SelectLink(self.contextLinkId[0], true)
    end
    im.OpenPopup("Link Context Menu")
    self.mgr.openPopupPosition = mousePos
  elseif im.IsWindowHovered() and ui_flowgraph_editor.ShowBackgroundContextMenu() then
    im.OpenPopup("BackgroundContextMenu")
    self.mgr._nodeTemplates = nil -- force refresh
    self.mgr.openPopupPosition = mousePos
    self.mgr.newNodeLinkPin = nil
    self.fgEditor.nodelib:setNewNodeLinkPin(nil)
  end
  local oldUiScale = im.uiscale[0]
  im.uiscale[0] = editor.getPreference("ui.general.scale")
  --im.SetNextWindowPos(im.GetCursorScreenPos())
  if im.BeginPopup("Node Context Menu") then
    --im.Begin('asd##contextMenuWrapper')
    local node = self.mgr.graph.nodes[tonumber(self.contextNodeId[0])]
    if node then
      node:showContextMenu(self.mgr.openPopupPosition)
    end
    im.EndPopup()
  end
  --im.End()

  if im.BeginPopup("Pin Context Menu") then
    local pin = self.mgr.graph:findPin(tonumber(self.contextPinId[0]))
    if pin then
      pin:showContextMenu(self.mgr.openPopupPosition, self)
    end
    im.EndPopup()
  end

  if im.BeginPopup("Link Context Menu") then
    local link = self.mgr.graph.links[tonumber(self.contextLinkId[0])]
    if link then
      link:showContextMenu(self.mgr.openPopupPosition)
    end
    im.EndPopup()
  end

  im.PushStyleColor2(im.Col_Border, im.ImVec4(1.0, 1.0, 1.0, 0.25))
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(9, 9))
  if im.BeginPopup("BackgroundContextMenu") then
    openedContextMenu = true
    self:showNewNodeContextMenu(self.mgr.openPopupPosition)
    im.EndPopup()
  else
    -- If the context menu has been closed, clear the filter
    if openedContextMenu then
      self.fgEditor.nodelib:clear()
      openedContextMenu = false
    end
    self.mgr.createNewNode = false
  end
  im.PopStyleColor()
  im.PopStyleVar()
  im.uiscale[0] = oldUiScale
  ui_flowgraph_editor.Resume()
end



function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end


return _flowgraph_createMgrWindow(C)