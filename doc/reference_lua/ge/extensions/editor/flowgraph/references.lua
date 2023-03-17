-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local imu = require('ui/imguiUtils')
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')
local disabledColor = im.ImVec4(0.5, 0.5, 0.5, 1)
local enabledColor = im.ImVec4(1, 1, 1, 1)
local matchColor = im.ImVec4(1, 0.5, 0, 1)
local columnBackground = im.ImVec4(0.21, 0.21, 0.21, 1)
local filterModes = { { mode = 'All', tooltip = 'Filters through all nodes.' }, { mode = 'Current', tooltip = 'Filters through the nodes of the current project.' }, { mode = 'unused', tooltip = 'Filters through all unused nodes.' } }
local buttonSize = im.ImVec2(32, 32)
local pinPreviewSize = 24
local C = {}
local logTag = 'references'
C.windowName = 'fg_references'
C.windowDescription = 'References'

function C:init()
  editor.registerWindow(self.windowName, im.ImVec2(150, 300), nil, false)
  self.searchResult = {}
  self.searchText = im.ArrayChar(128)
  self.nodeTable = nil
  self.filteredNodes = {}
  self.sortedProjects = {}
  self.sortedCategories = {}
  self.viewMode = 1
  self.filterMode = filterModes[1].mode
  self.nodeStatistics = { usedNoteTypeAmount = 0, usedNodeInstances = 0, categories = {} }
  --self:createNodeTable()
end

function C:createNodeTable()

  self.nodeTable = {}

  -- gathers all existing nodes
  self:findNodesRecursive(core_flowgraphManager.getAvailableNodeTemplates())

  -- fills the nodeTable
  self:checkFilesForNodes(true)
end

-- recursively goes through node directories
function C:findNodesRecursive(nodeDirectory)
  for k, _ in pairs(nodeDirectory) do
    if k == "nodes" then
      for node, nodeData in pairs(nodeDirectory[k]) do

        -- add entry
        self.nodeTable[node] = { displayName = nodeData.node.name, amount = 0, pins = { inPins = {}, outPins = {} }, category = nodeData.node.category or "none", behaviour = nodeData.node.behaviour or {}, amountForProjects = {} }

        -- add pins
        if nodeData.node.pinSchema then
          for _, pin in ipairs(nodeData.node.pinSchema) do
            if pin.dir == "in" then
              table.insert(self.nodeTable[node].pins.inPins, pin)
            else
              table.insert(self.nodeTable[node].pins.outPins, pin)
            end
          end
        end

        -- add pins and behaviours that are only added during runtime
        self:addPinsAndBehavioursForCategory(node, nodeData.node.category)

        -- update node statistics
        if self.nodeStatistics.categories[self.nodeTable[node].category] == nil then
          self.nodeStatistics.categories[self.nodeTable[node].category] = { nodeTypeAmount = 1, nodeInstancesAmount = 0 }
        else
          self.nodeStatistics.categories[self.nodeTable[node].category].nodeTypeAmount = self.nodeStatistics.categories[self.nodeTable[node].category].nodeTypeAmount + 1
        end
      end
    else
      self:findNodesRecursive(nodeDirectory[k])
    end
  end
end

function C:checkFilesForNodes(initialCheck)

  -- clear old entries, if not initial creation
  if not initialCheck then
    for _, nodeData in pairs(self.nodeTable) do
      nodeData.amount = 0
      nodeData.amountForProjects = {}
    end

    self.nodeStatistics = { usedNoteTypeAmount = 0, usedNodeInstances = 0, categories = {} }
  end

  -- check directory
  self:fillNodeTable(FS:findFiles("/levels/", '*.flow.json', -1, true, false))
  self:fillNodeTable(FS:findFiles("/gameplay/", '*.flow.json', -1, true, false))
  self:fillNodeTable(FS:findFiles("/lua/ge/extensions/flowgraph/examples", '*.flow.json', -1, true, false))

  -- check current project, if exists
  if self.mgr then
    for node in self.mgr:allNodes() do
      for k, v in pairs(self.nodeTable) do
        if v.displayName == node.name then
          -- fileName might not exist, so just use CurrentLocalFile as placeholder
          self:updateNodeOccurrence(k, "CurrentLocalFile")
        end
      end
    end
  end

  -- creates self.filteredNodes for display
  self:filterNodes()
  self:sortCategories()
end

function C:sortCategories()
  local res = {}

  for k, v in pairs(self.nodeStatistics.categories) do
    table.insert(res, { category = k, nodeTypeAmount = v.nodeTypeAmount, nodeInstancesAmount = v.nodeInstancesAmount })
  end

  table.sort(res, function(a, b)
    return a.nodeTypeAmount > b.nodeTypeAmount
  end)

  self.sortedCategories = res
end

-- goes through all flowgraphs in directory
function C:fillNodeTable(flowgraphDirectory)
  for _, filename in ipairs(flowgraphDirectory) do
    local data = jsonReadFile(filename)

    if data then
      for _, graph in pairs(data.graphs or {}) do
        for _, node in pairs(graph.nodes) do
          self:updateNodeOccurrence(string.gsub(node.type, "(.*/)(.*)", "%2"), filename)
        end
      end
    end
  end
end

-- updates nodeTable for occurence of node in project
function C:updateNodeOccurrence(nodeName, fileName)
  self.nodeStatistics.usedNodeInstances = self.nodeStatistics.usedNodeInstances + 1

  -- check if node has a nodeTable entry
  if self.nodeTable[nodeName] ~= nil then
    local category = self.nodeTable[nodeName].category
    -- if first time that usage of this node was detected, update usedNoteTypeAmount
    if self.nodeTable[nodeName].amount == 0 then
      self.nodeStatistics.usedNoteTypeAmount = self.nodeStatistics.usedNoteTypeAmount + 1
    end

    -- update nodeTable entry
    self.nodeTable[nodeName].amount = self.nodeTable[nodeName].amount + 1
    if self.nodeTable[nodeName].amountForProjects[fileName] == nil then
      self.nodeTable[nodeName].amountForProjects[fileName] = 1
    else
      self.nodeTable[nodeName].amountForProjects[fileName] = self.nodeTable[nodeName].amountForProjects[fileName] + 1
    end

    self.nodeStatistics.categories[category].nodeInstancesAmount = self.nodeStatistics.categories[category].nodeInstancesAmount + 1
  else
    -- This shouldn't happen, only would if there was a node in a project that has no node file
    self.nodeTable[nodeName] = { amount = 1, category = "OBSOLETE", amountForProjects = { filename = 1 } }
    self.nodeStatistics.usedNoteTypeAmount = self.nodeStatistics.usedNoteTypeAmount + 1

    if self.nodeStatistics.categories["OBSOLETE"] == nil then
      self.nodeStatistics.categories["OBSOLETE"] = { nodeTypeAmount = 1, nodeInstancesAmount = 0 }
    else
      self.nodeStatistics.categories["OBSOLETE"].nodeTypeAmount = self.nodeStatistics.categories["OBSOLETE"].nodeTypeAmount + 1
    end
  end
end

function C:filterNodes()
  local res = {}

  -- include all nodes if filterMode 'all'
  if self.filterMode == 'All' then
    for k, v in pairs(self.nodeTable) do
      if string.find(k, ffi.string(self.searchText)) then
        table.insert(res, { nodeName = k, nodeData = v })
      end
    end
    -- filter for only current project
  elseif self.filterMode == 'Current' then
    for node in self.mgr:allNodes() do

      -- prevents multiple entries for a node, how can this be done more efficiently ?
      local alreadyExist = false
      for _, n in ipairs(res) do
        if self.nodeTable[n.nodeName].displayName == node.name then
          alreadyExist = true
        end
      end

      -- add node entry
      if not alreadyExist then
        for k, v in pairs(self.nodeTable) do
          if v.displayName == node.name then
            if string.find(k, ffi.string(self.searchText)) then
              table.insert(res, { nodeName = k, nodeData = v })
            end
          end
        end
      end
    end
    -- only filters for unused nodes
  elseif self.filterMode == 'Unused' then
    for k, v in pairs(self.nodeTable) do
      if v.amount == 0 then
        if string.find(k, ffi.string(self.searchText)) then
          table.insert(res, { nodeName = k, nodeData = v })
        end
      end
    end
  end

  -- sort for most occurrences
  table.sort(res, function(a, b)
    return a.nodeData.amount > b.nodeData.amount
  end)

  self.filteredNodes = res
end

-- because some pins are only created during runtime, we need to make mockups for the nodeTable (Same logic as in basenode)
function C:addPinsAndBehavioursForCategory(nodeName, category)
  if category then
    -- check if functional
    if ui_flowgraph_editor.isFunctionalNode(category) then

      -- check if simple
      if ui_flowgraph_editor.isSimpleNode(category) then
        self.nodeTable[nodeName].behaviour['simple'] = true
      else


        if not self:pinExists(nodeName,'in','flow') then
          table.insert(self.nodeTable[nodeName].pins.inPins, { name = 'flow', dir = 'in', type = 'flow', description = 'Inflow for this node.' })
        end
        if not self:pinExists(nodeName,'out','flow') then
          table.insert(self.nodeTable[nodeName].pins.outPins, { name = 'flow', dir = 'out', type = 'flow', description = 'Outflow for this node.' })
        end
        -- check if duration
        if ui_flowgraph_editor.isDurationNode(category) then
          self.nodeTable[nodeName].behaviour['duration'] = true

          -- check if f_duration
          if ui_flowgraph_editor.isF_DurationNode(category) then
            if not self:pinExists(nodeName,'out','incomplete') then
              table.insert(self.nodeTable[nodeName].pins.outPins, { name = 'incomplete', dir = 'out', type = 'flow', description = "Puts out flow, while this node's functionality is not completed." })
            end
            if not self:pinExists(nodeName,'out','complete') then
              table.insert(self.nodeTable[nodeName].pins.outPins, { name = 'complete', dir = 'out', type = 'flow', description = "Puts out flow continuously, after the node's functionality is complete." })
            end
            if not self:pinExists(nodeName,'out','flow') then
              table.insert(self.nodeTable[nodeName].pins.outPins, { name = 'completed', dir = 'out', type = 'flow', description = "Puts out flow once, after the node's functionality is completed.", impulse = true })
            end
          end
        end
        -- check if once
        if ui_flowgraph_editor.isOnceNode(category) then
          if not self:pinExists(nodeName,'in','reset') then
            table.insert(self.nodeTable[nodeName].pins.inPins, { name = 'reset', dir = 'in', type = 'flow', description = 'Resets the node.', impulse = true })
          end
          self.nodeTable[nodeName].behaviour['once'] = true
        end
      end
    end
  end
end

function C:pinExists(nodeName, direction, pinName)
  if direction == 'in' then
    for _, pin in ipairs(self.nodeTable[nodeName].pins.inPins) do
      if pin.name == pinName then
        return true
      end
    end
  else
    for _, pin in ipairs(self.nodeTable[nodeName].pins.outPins) do
      if pin.name == pinName then
        return true
      end
    end
  end
end
-- this is copied almost completely from nodeLibrary
function C:highlightText(label, highlightText)
  if highlightText == "" then
    im.Text(label)
    return
  end
  im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 0))
  local pos1 = 1
  local pos2 = 0
  local labelLower = label:lower()
  local highlightLower = highlightText:lower()
  local highlightLowerLen = string.len(highlightLower) - 1
  for i = 0, 6 do
    -- up to 6 matches overall ...
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


-- sorts projects for most occurrences
function C:sortProjects()
  local res = {}
  for k, v in pairs(self.nodeTable[self.inspectedNode].amountForProjects) do
    table.insert(res, { projectFile = k, amount = v })
  end

  table.sort(res, function(a, b)
    return a.amount > b.amount
  end)

  self.sortedProjects = res
end

-- not sure why this is actually needed
local columnsBasic = {}
columnsBasic.selected = im.IntPtr(-1)

function C:draw()
  if not editor.isWindowVisible(self.windowName) then
    return
  end
  self:Begin('References')
  if not self.nodeTable or self.nodeTable == {} then
    if im.Button("Load Data", im.ImVec2(-1, 0)) then
      self:createNodeTable()
    end
  else
    if editor.uiIconImageButton(editor.icons.keyboard_arrow_left, buttonSize, self.viewMode == 2 and enabledColor or disabledColor) then
      if self.viewMode == 2 then
        self.viewMode = 1
      end
    end
    im.SameLine()
    if editor.uiIconImageButton(editor.icons.keyboard_arrow_right, buttonSize, self.viewMode == 1 and self.inspectedNode ~= nil and enabledColor or disabledColor) then
      if self.viewMode == 1 and self.inspectedNode ~= nil then
        self.viewMode = 2
      end
    end
    im.SameLine()

    if self.viewMode == 1 then
      self:drawViewMode1()
    end
    if self.viewMode == 2 then
      self:drawViewMode2()
    end
  end
  self:End()
end

function C:drawViewMode1()
  im.HeaderText("\t Find:")
  im.SameLine()
  im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(6, 6.5 * editor.getPreference("ui.general.scale")))
  im.PushItemWidth(im.GetContentRegionAvailWidth() * 0.55)
  if im.InputText("##findReferenceByName", self.searchText, nil) then
    im.TextUnformatted('Looking for ' .. ffi.string(self.searchText) .. ' ....')

    self:filterNodes()
  end
  im.PopItemWidth()
  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - buttonSize.x * editor.getPreference("ui.general.scale") - 5)
  if im.BeginCombo("##paths", self.filterMode) then
    for _, modeData in ipairs(filterModes) do
      if im.Selectable1(modeData.mode) then
        self.filterMode = modeData.mode
        self:filterNodes()
      end
      im.tooltip(modeData.tooltip)
    end
    im.EndCombo()
  end
  im.PopItemWidth()
  im.PopStyleVar()
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.refresh, buttonSize) then
    self:checkFilesForNodes(false)
  end
  im.Separator()
  im.Spacing()
  if editor.getPreference("flowgraph.general.showAdvancedReferenceData") then
    if im.CollapsingHeader1("Advanced Data", im.TreeNodeFlags_DefaultOpen) then
      if im.BeginTable('', 5) then
        im.TableSetupColumn("Category")
        im.TableSetupColumn("Node Types")
        im.TableSetupColumn("") -- For Percentage
        im.TableSetupColumn("Node Instances")
        im.TableSetupColumn("") -- For Percentage
        im.TableHeadersRow()
        im.TableNextColumn()
        for _, categoryData in pairs(self.sortedCategories) do
          im.TableSetBgColor(im.TableBgTarget_CellBg, im.GetColorU322(columnBackground), 0)
          im.TextWrapped(tostring(categoryData.category))
          im.TableNextColumn()
          im.TextWrapped(string.format("%-3d", categoryData.nodeTypeAmount))
          im.TableNextColumn()
          im.TextWrapped(string.format("(%.2f", (categoryData.nodeTypeAmount / self.nodeStatistics.usedNoteTypeAmount) * 100) .. "%%)")
          im.TableNextColumn()
          im.TextWrapped(tostring(categoryData.nodeInstancesAmount))
          im.TableNextColumn()
          im.TextWrapped(string.format("(%.2f", (categoryData.nodeInstancesAmount / self.nodeStatistics.usedNodeInstances) * 100) .. "%%)")
          im.TableNextColumn()
        end
      end
      im.EndTable()
      im.Separator()
      im.Text("Existing Node Types: ")
      im.SameLine()
      im.PushStyleColor2(im.Col_Text, matchColor)
      im.Text(tostring(tableSize(self.nodeTable)))
      im.PopStyleColor()
      im.SameLine()
      im.Text("Used Node Types: ")
      im.SameLine()
      im.PushStyleColor2(im.Col_Text, matchColor)
      im.Text(tostring(self.nodeStatistics.usedNoteTypeAmount))
      im.PopStyleColor()
      im.SameLine()
      im.Text("Node Instances: ")
      im.SameLine()
      im.PushStyleColor2(im.Col_Text, matchColor)
      im.Text(tostring(self.nodeStatistics.usedNodeInstances))
      im.PopStyleColor()
    end
  end
  if im.BeginTable('NodeRef', 4) then

    im.TableSetupColumn("Node", 0, 2)
    im.TableSetupColumn("Occurrences")
    im.TableSetupColumn("Projects used in")
    im.TableSetupColumn("Categories")

    im.TableHeadersRow()
    im.TableNextColumn()
    local rowCount = 1
    for _, n in pairs(self.filteredNodes) do
      if editor.uiIconImageButton(editor.icons.subdirectory_arrow_right, im.ImVec2(24, 24)) then
        self.inspectedNode = n.nodeName
        self:sortProjects()
        self.viewMode = 2
      end
      ui_flowgraph_editor.tooltip("Inspect Node")
      if n.nodeName == self.inspectedNode then
        im.PushStyleColor2(im.Col_Text, matchColor)
      end
      im.SameLine()
      if im.Selectable1(tostring(rowCount) .. ". ", columnsBasic.selected[0] == rowCount, im.SelectableFlags_SpanAllColumns) then
        columnsBasic.selected[0] = rowCount
      end
      im.SameLine()
      self:highlightText(tostring(n.nodeName), string.lower(ffi.string(self.searchText)))
      im.TableNextColumn()
      im.Text(tostring(n.nodeData.amount))
      im.TableNextColumn()
      im.Text(tostring(tableSize(n.nodeData.amountForProjects)))
      im.TableNextColumn()
      im.Text(tostring(n.nodeData.category))
      im.TableNextColumn()

      if n.nodeName == self.inspectedNode then
        im.PopStyleColor()
      end

      rowCount = rowCount + 1
    end
    im.EndTable()
  end
end

function C:drawViewMode2()
  im.HeaderText("\t Node: " .. self.inspectedNode)
  local rows = math.max(#self.nodeTable[self.inspectedNode].pins.inPins, #self.nodeTable[self.inspectedNode].pins.outPins)
  if rows > 0 then
    if im.BeginTable('', 4) then
      im.TableSetupColumn("Input Pins", 0, im.GetContentRegionAvailWidth() / 6)
      im.TableSetupColumn("Description", 0, im.GetContentRegionAvailWidth() / 3)
      im.TableSetupColumn("Output Pins", 0, im.GetContentRegionAvailWidth() / 6)
      im.TableSetupColumn("Description", 0, im.GetContentRegionAvailWidth() / 3)
      im.TableHeadersRow()
      im.TableNextColumn()
      for i = 1, 4 do
        im.TableSetBgColor(im.TableBgTarget_CellBg, im.GetColorU322(columnBackground), 0)
        im.TableSetBgColor(im.TableBgTarget_CellBg, im.GetColorU322(columnBackground), 2)
        im.Dummy(im.ImVec2(0, 3))
        im.TableNextColumn()
      end

      for i = 1, rows do

        local pin = self.nodeTable[self.inspectedNode].pins.inPins[i]
        im.TableSetBgColor(im.TableBgTarget_CellBg, im.GetColorU322(columnBackground), 0)
        im.TableSetBgColor(im.TableBgTarget_CellBg, im.GetColorU322(columnBackground), 2)

        if pin then
          self.mgr:DrawTypeIcon(pin.chainFlow and 'chainFlow' or pin.impulse and 'impulse' or pin.type, true, 1, pinPreviewSize)
          im.SameLine()
          im.TextWrapped(pin.name)
          im.TableNextColumn()
          im.TextWrapped(pin.description or "This pin has no description.")
          im.TableNextColumn()
        else
          if i == 1 then
            im.TextWrapped("-")
            im.TableNextColumn()
            im.TextWrapped("-")
            im.TableNextColumn()
          else
            im.TableNextColumn()
            im.TableNextColumn()
          end
        end

        pin = self.nodeTable[self.inspectedNode].pins.outPins[i]
        if pin then
          self.mgr:DrawTypeIcon(pin.chainFlow and 'chainFlow' or pin.impulse and 'impulse' or pin.type, true, 1, pinPreviewSize)
          im.SameLine()
          im.TextWrapped(pin.name)
          im.TableNextColumn()
          im.TextWrapped(pin.description or "This pin has no description.")
          im.TableNextColumn()
        else
          if i == 1 then
            im.TextWrapped("-")
            im.TableNextColumn()
            im.TextWrapped("-")
            im.TableNextColumn()
          else
            im.TableNextColumn()
            im.TableNextColumn()
          end
        end
      end
    end
    im.EndTable()
  end

  if tableSize(self.nodeTable[self.inspectedNode].behaviour) > 0 then

    if im.BeginTable("", 2) then
      im.TableSetupColumn("Behaviour", 0, im.CalcTextSize("Behaviour").x + 10)
      im.TableSetupColumn("Description", 0, im.GetContentRegionAvailWidth())
      im.TableHeadersRow()
      im.TableNextColumn()
      im.Dummy(im.ImVec2(0, 3))
      im.TableNextColumn()
      im.Dummy(im.ImVec2(0, 3))
      im.TableNextColumn()
      for behaviour, _ in pairs(self.nodeTable[self.inspectedNode].behaviour) do
        editor.uiIconImage(editor.icons[ui_flowgraph_editor.getBehaviourIcon(behaviour)], buttonSize)
        im.TableNextColumn()
        im.SetCursorPosY(im.GetCursorPosY() + 4)
        im.TextWrapped(ui_flowgraph_editor.getBehaviourDescription(behaviour))
        im.SetCursorPosY(im.GetCursorPosY() - 4)
        im.TableNextColumn()
      end
    end
    im.EndTable()
  end

  if im.BeginTable('ProjectsForNode', 2) then
    im.TableSetupColumn("Project", 0, 3.25)
    im.TableSetupColumn("Occurrences")
    im.TableHeadersRow()
    im.TableNextColumn()

    if #self.sortedProjects > 0 then
      local rowCount = 1
      for _, p in ipairs(self.sortedProjects) do

        if editor.uiIconImageButton(editor.icons.folder_open, im.ImVec2(24, 24)) then
          editor_flowgraphEditor.openFile({ filepath = p.projectFile }, true)
        end
        ui_flowgraph_editor.tooltip("Open Project")

        im.SameLine()
        if im.Selectable1(tostring(rowCount) .. ". ", columnsBasic.selected[0] == rowCount, im.SelectableFlags_SpanAllColumns) then
          columnsBasic.selected[0] = rowCount
        end
        im.SameLine()
        im.TextWrapped(tostring(p.projectFile))
        im.TableNextColumn()
        im.Text(tostring(p.amount))
        im.TableNextColumn()
        rowCount = rowCount + 1
      end
    else
      im.Text("None")
      im.TableNextColumn()
      im.Text("None")
    end
  end
  im.EndTable()
end

return _flowgraph_createMgrWindow(C)
