-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')
local C = {}
C.windowName = 'fg_variables'
C.windowDescription = 'Variables'

local separatorColor = im.ImVec4(1,1,1,0.3)
local valueTextColor = im.ImVec4(1,1,1,0.7)
local highlightColor = im.ImVec4(1,0.5,0,1)
local imVec24x24 = im.ImVec2(24,24)
local imVec4Red = im.ImVec4(1,0.3,0.3,0.7)
local imVec4Green = im.ImVec4(0.3,1,0.3,0.7)

local localColor = im.ImVec4(1,0.8,0.6,0.75)
local globalColor = im.ImVec4(1,0.6,0,8,0.75)
local scale = 1
function C:init()
  self.target = nil
  self.newVariableNameField = im.ArrayChar(64,"")
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
  self.dragPayload = nil
  self.addVariableSettings = nil
  self.targets = {}
end

function C:draw()
  scale = editor.getPreference("ui.general.scale")
  if not editor.isWindowVisible(self.windowName) then return end
  if self:Begin("Variables") then

    local totalWidth = im.GetContentRegionAvailWidth()
    local prePos = im.GetCursorPos()
    im.PushFont3("cairo_regular_medium")
    im.TextColored(localColor,"Current Graph Variables")
    im.SameLine()
    im.TextColored(separatorColor, "|")
    ui_flowgraph_editor.tooltip("These variables are only available in this graph.")
    im.SameLine()
    local loc = self.mgr.graph:getLocation(editor.getPreference("flowgraph.debug.displayIds"))
    im.TextColored(valueTextColor, loc )
    im.PopFont()
    im.SameLine()
    im.SetCursorPosX(totalWidth-35*im.uiscale[0])
    self.targets = {{name = loc, target = self.mgr.graph.variables},{name="Project", target=self.mgr.variables}}
    if not self.mgr.allowEditing then im.BeginDisabled() end
    if editor.uiIconImageButton(editor.icons.add, im.ImVec2(35,35)) then
      im.OpenPopup("addVariablePopup")
      self.addVariableSettings = { target = 1 , addAnother = editor.getPreference("flowgraph.general.repeatVariableCreation")}
      --dump(self.addVariableSettings)
    end
    ui_flowgraph_editor.tooltip("Create a new variable.")
    if not self.mgr.allowEditing then im.EndDisabled() end

    self:drawTarget(self.mgr.graph.variables, 'Current Graph','-1')
    im.Separator()
    prePos = im.GetCursorPos()
    im.PushFont3("cairo_regular_medium")
    im.TextColored(globalColor,"Project Variables")
    im.PopFont()
    ui_flowgraph_editor.tooltip("These variables are available in the whole project.")
    im.SameLine()
    im.SetCursorPosX(totalWidth-35*im.uiscale[0])
    if not self.mgr.allowEditing then im.BeginDisabled() end
    if editor.uiIconImageButton(editor.icons.add, im.ImVec2(35,35)) then
      im.OpenPopup("addVariablePopup")
      self.addVariableSettings = { target = 2, addAnother = editor.getPreference("flowgraph.general.repeatVariableCreation") }
    end
    ui_flowgraph_editor.tooltip("Create a new variable.")
    if not self.mgr.allowEditing then im.EndDisabled() end
    self:drawTarget(self.mgr.variables,'Manager Variables',nil, true)
    im.Separator()
    im.PushFont3("cairo_regular_medium")
    im.Text("Other Graph Variables")
    im.PopFont()
    ui_flowgraph_editor.tooltip("These variables are not available here.")
    self:drawSortedGraphs(self.mgr.graphs)
    im.Separator()
    --self:drawSortedGraphs(self.mgr.macros)
    if im.BeginPopup("addVariablePopup") then
      self.addVariableSettings.name = self.addVariableSettings.name or im.ArrayChar(128)
      self.addVariableSettings.type = self.addVariableSettings.type or "auto"
      im.PushFont3("cairo_regular_medium")
      im.TextColored(globalColor,"Create a new Variable")
      im.PopFont()
      im.PushItemWidth(im.GetContentRegionAvailWidth())
      if im.BeginCombo("##variableTarget","Add to: "..self.targets[self.addVariableSettings.target].name) then
        for i, t in ipairs(self.targets) do
          if im.Selectable1("Add to: " ..t.name, i == self.addVariableSettings.target ) then
            self.addVariableSettings.target = i
          end
        end
        im.EndCombo()
      end
      im.PopItemWidth()
      im.Text("Name")
      im.SameLine()
      if not self.addVariableSettings.focussed or self.addVariableSettings.focussed<2  then
        im.SetKeyboardFocusHere()
        self.addVariableSettings.focussed = (self.addVariableSettings.focussed or 0) +1
      end
      local w = im.GetContentRegionAvailWidth()
      im.PushItemWidth(w-50)
      local acceptCreate = false
      if editor.uiInputText("##addVariableName", self.addVariableSettings.name,nil, im.InputTextFlags_EnterReturnsTrue) then
        acceptCreate = true
      end
      im.SameLine()
      local name = ffi.string(self.addVariableSettings.name)
      local nameAvailable = name ~= "" and not self.targets[self.addVariableSettings.target].target:variableExists(name)
      if nameAvailable then
        editor.uiIconImage(editor.icons.check, imVec24x24, imVec4Green)
        im.tooltip("This name is available.")
      else
        editor.uiIconImage(editor.icons.error_outline, imVec24x24, imVec4Red)
        im.tooltip("This name is used or invalid.")
      end
      im.PopItemWidth()
      local pushedItemWidth = false
      if self.addVariableSettings.type ~= 'auto' then
        im.PushItemWidth(120)
        pushedItemWidth = true
        self.mgr:DrawTypeIcon(self.addVariableSettings.type, false, 1, 20/scale)
        im.SameLine()
      else
        im.PushItemWidth(im.GetContentRegionAvailWidth())
      end
      local typeText = self.addVariableSettings.type=="auto" and ("Automatic Type: ("..self:getAutoTypeFromName(ffi.string(self.addVariableSettings.name))..")") or "self.addVariableSettings.type"
      if im.BeginCombo("##typeSelectorNewVariable", typeText, im.ComboFlags_HeightLarge) then
        if im.Selectable1("Automatic", self.addVariableSettings.type=="auto") then
          self.addVariableSettings.type = "auto"
          self.addVariableSettings.value = nil
        end
        im.Separator()
        for _,typename in ipairs(ui_flowgraph_editor.getSimpleTypes()) do
          self.mgr:DrawTypeIcon(typename, false, 1, 20/scale)
          im.SameLine()
          if im.Selectable1(typename, typename==self.addVariableSettings.type) then
            -- History
            self.addVariableSettings.type = typename
            self.addVariableSettings.value = nil
          end
        end
        im.EndCombo()
      end

      if self.addVariableSettings.type ~= 'auto' then
        local props = extensions.editor_flowgraphEditor.getPropertiesWindow()
        if not self.addVariableSettings.value then
          self.addVariableSettings.value = {
            cdata = {},
            path = "new",
            value = fg_utils.getDefaultValueForType(self.addVariableSettings.type)
          }
        end
        im.SameLine()
        props:_drawInputField(self.addVariableSettings.value.path, self.addVariableSettings.value.cdata, self.addVariableSettings.type, self.addVariableSettings.value.value, "", function(n, val) self.addVariableSettings.value.value = val end)
      end

      if im.Checkbox("Create Another", im.BoolPtr(self.addVariableSettings.addAnother or false)) then
        self.addVariableSettings.addAnother = not (self.addVariableSettings.addAnother or false)
      end
      im.SameLine()
      if im.Button("Create", im.ImVec2(im.GetContentRegionAvailWidth(), -1)) then
        acceptCreate = true
      end
      if acceptCreate then
        local name = ffi.string(self.addVariableSettings.name)
        if name ~= "" then
          local type = self.addVariableSettings.type
          if type == 'auto' then
            type = self:getAutoTypeFromName(name)
          end
          local value = self.addVariableSettings.value and self.addVariableSettings.value.value
          if value == nil then
            value = fg_utils.getDefaultValueForType(type)
          end
          self.targets[self.addVariableSettings.target].target:addVariable(name, value, type)
          if self.addVariableSettings.addAnother then
            self.addVariableSettings = {target = self.addVariableSettings.target, addAnother = true}
          else
            im.CloseCurrentPopup()
          end
          self.fgEditor.addHistory("Added new Variable: " .. name)
        end
      end

      im.EndPopup()
    else
      self.addVariableSettings = nil
    end
  end
  if not im.IsMouseDown(0) then self.dragPayload = nil end
  self:End()


end

function C:getAutoTypeFromName(name)
  return ui_flowgraph_editor.getAutoTypeFromName(name)
end


function C:drawVariableCard(target, varName, global)
  local variable = target:getFull(varName)
  if editor.getPreference("flowgraph.general.alwaysExpandVariables") then  variable.expanded = true end
  im.PushID1(target.id..varName..dumps(global).."pushed")
  local flags = bit.bor(im.WindowFlags_NoScrollbar, im.WindowFlags_NoScrollWithMouse)
  im.BeginChild1(target.id..varName..dumps(global), im.ImVec2(im.GetContentRegionAvailWidth(), scale*(variable.expanded and 58 or 24)+16), true, (not variable.expanded) and flags)

  local valueText = ui_flowgraph_editor.shortValueString(variable.value, variable.type)
  local width = im.GetContentRegionAvailWidth()
  local prePos = im.GetCursorPos()

  self.mgr:DrawTypeIcon(variable.type, false, 1, 16 / scale)

  im.SameLine()
  im.Text(varName)

  im.SameLine()
  im.TextColored(separatorColor, "|")
  im.SameLine()
  im.TextColored(valueTextColor, valueText)
  im.SameLine()

  if self.mgr.allowEditing then
    im.SetCursorPosX(width - 75*scale - 5)
    editor.uiIconImageButton(editor.icons.cloud_download, im.ImVec2(24,24))
    if im.IsItemHovered() and im.IsMouseReleased(0) and not self.dragPayload then
      local bounds = ui_flowgraph_editor.GetVisibleCanvasBounds()
      local pos = im.ImVec2((bounds.x + bounds.z) / 2, (bounds.y + bounds.w) / 2)
      local node = self.mgr.graph:createNode("types/getVariable")
      ui_flowgraph_editor.SetNodePosition(node.id, pos)
      node:alignToGrid()
      node:setGlobal(global)
      node:setVar(varName)
      self.mgr.fgEditor.addHistory("Added Variable node for " .. varName)
    end
    if im.IsItemHovered() and not self.dragPayload then
      self.mgr:dragDropSource("variableNodeDragDropPayload", {read = true, varName = varName, path = "Get " .. varName, global = global, text = "Getter for " .. varName})
    end
    ui_flowgraph_editor.tooltip("Creates a getter node for this variable. (Drag and Drop also works)")



    im.SameLine()
     editor.uiIconImageButton(editor.icons.cloud_upload, im.ImVec2(24,24))
     if im.IsItemHovered() and im.IsMouseReleased(0) and not self.dragPayload then
      local bounds = ui_flowgraph_editor.GetVisibleCanvasBounds()
      local pos = im.ImVec2((bounds.x + bounds.z) / 2, (bounds.y + bounds.w) / 2)
      local node = self.mgr.graph:createNode("types/setVariable")
      ui_flowgraph_editor.SetNodePosition(node.id, pos)
      node:setGlobal(global)
      node:setVar(varName)
      self.mgr.fgEditor.addHistory("Added Variable node for " .. varName)
    end
    if im.IsItemHovered() and not self.dragPayload then
      self.mgr:dragDropSource("variableNodeDragDropPayload", {read = false, varName = varName, path = "Set " .. varName, global = global, text = "Setter for ".. varName})
    end
    ui_flowgraph_editor.tooltip("Creates a setter node for this variable. (Drag and Drop also works)")
    im.SameLine()
  end


  im.SetCursorPosX(width - 22*scale)
  editor.uiIconImageButton(editor.icons.reorder, im.ImVec2(24,24), self.dragPayload and self.dragPayload.name == varName and self.dragPayload.target.id == target.id and highlightColor or nil)
  if im.IsItemHovered() and im.IsItemClicked() then
    self.dragPayload = {target = target, name = varName}
  end
  local endPos = im.GetCursorPos()
  if not editor.getPreference("flowgraph.general.alwaysExpandVariables") then
    if not self.dragPayload then
      im.SetCursorPos(im.ImVec2(prePos.x - 5, prePos.y -5))
      im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(0, 0))
      im.BeginChild1(target.id..varName..dumps(global).."clicker", im.ImVec2(im.GetContentRegionAvailWidth()-90*scale, endPos.y-prePos.y+3))
      im.EndChild()
      im.PopStyleVar()
      if im.IsItemHovered() and im.IsMouseReleased(0) then
        variable.expanded = not variable.expanded
      end
    end
  end
  if variable.expanded then
    im.Separator()
    im.Dummy(im.ImVec2(1,1))
    ui_flowgraph_editor.variableEditor(target, varName, {global = global, showNodes = true, allowDelete = true})
  end



  im.EndChild()
  im.PopID()

end

local lineColor = im.GetColorU322(highlightColor)
function C:drawTarget(target, name, id, global)
  local mouseXMin = im.GetCursorScreenPos().x + 10
  local mouseXMax = im.GetCursorScreenPos().x + im.GetContentRegionAvailWidth()-10
  local id = id or target.id


  local dragReleaseVerticalDistance = 20
  local insertPositions = {}
  for i, nm in ipairs(target.customVariableOrder) do
    if self.dragPayload then
      table.insert(insertPositions, im.GetCursorScreenPos().y)
    end


    --end
    --local variable = target:getFull(nm)
    --local vName = ui_flowgraph_editor.shortValueString(variable.value, variable.type)
    --if im.TreeNode2(nm..variable.index..'-'..id, nm .. ' = ' .. vName) then
      --ui_flowgraph_editor.variableEditor(target, nm, {global = global, showNodes = true, allowDelete = true})
      self:drawVariableCard(target, nm, global)
      --self:drawField(target, nm, target:getFull(nm), global or false)
    --  im.TreePop()
    --end
  end
  if self.dragPayload and self.dragPayload.target.id == target.id then

    table.insert(insertPositions, im.GetCursorScreenPos().y)
    local mousePos = im.GetMousePos()
    for i, y in ipairs(insertPositions) do
      if math.abs(mousePos.y - y) < dragReleaseVerticalDistance and mousePos.x > mouseXMin and mousePos.x < mouseXMax then
        im.ImDrawList_AddLine(im.GetWindowDrawList(), im.ImVec2(im.GetCursorScreenPos().x+10, y-1), im.ImVec2(im.GetCursorScreenPos().x+im.GetContentRegionAvailWidth()-20, y-1), lineColor, 3)
        if im.IsMouseReleased(0) then
          self.dragPayload.target:changeCustomVariableOrder(self.dragPayload.name, i)
          self.fgEditor.addHistory("Changed Variable Order")
        end
      end
    end

  end


end

function C:drawGraph(graph)
  self:drawTarget(graph.variables, graph.name .. (self.mgr.graph.id == graph.id and " (current)" or ""))
end

function C:drawRecursive(graph)
  if im.TreeNode2(graph.name..'##'..graph.id, graph.name) then
    self:drawGraph(graph)
    im.TreePop()
  end
  if next(graph:getChildren()) == nil then return end
  local ret = {}
  for id, gr in pairs(graph:getChildren()) do
      table.insert(ret,gr)
  end
  table.sort(ret, function(a,b) return a.id < b.id end)
  for _, gr in ipairs(ret) do
    self:drawRecursive(gr)
  end
end

function C:drawSortedGraphs(source)
  local ret = {}
  for id, gr in pairs(source) do
    if gr.parentId == nil then
      table.insert(ret,id)
    end
  end
  table.sort(ret)
  for _, id in ipairs(ret) do
    self:drawRecursive(source[id])
  end
end

function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

return _flowgraph_createMgrWindow(C)
