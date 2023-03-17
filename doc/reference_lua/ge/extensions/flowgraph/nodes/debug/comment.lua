-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

local moveModesPrettyNames = {
  withNodes = "With Nodes",
  withoutNodes = "Without Nodes"
}

C.name = 'Comment'
C.description = "Places a comment into your graph, which can group together nodes."
C.category = 'logic'
C.todo = "Size of the node is not kept through reloading and randomly breaks. Use 'Simple' mode to avoid this"
C.tags = { 'group' }

C.pinSchema = {}

function C:init()

  self.commentSize = im.ImVec2(200, 200)
  self.storedCommentSize = im.ImVec2(200,200)
  self.commentTitle = 'Comment'
  self.commentText = ''
  self.forceSize = true
  self.backgroundColor = im.ArrayFloat(4)
  self.backgroundColor[0] = im.Float(0.5)
  self.backgroundColor[1] = im.Float(0.5)
  self.backgroundColor[2] = im.Float(0.5)
  self.backgroundColor[3] = im.Float(0.5)
  self.bgColorVec4 = im.ImVec4(0,0,0,0)
  self.borderColor = im.ArrayFloat(4)
  self.borderColor[0] = im.Float(0.8)
  self.borderColor[1] = im.Float(0.8)
  self.borderColor[2] = im.Float(0.8)
  self.borderColor[3] = im.Float(1)
  self.borderColorVec4 = im.ImVec4(0,0,0,0)
  self.textColor = im.ArrayFloat(4)
  self.textColor[0] = im.Float(1)
  self.textColor[1] = im.Float(1)
  self.textColor[2] = im.Float(1)
  self.textColor[3] = im.Float(1)
  self.textColorVec4 = im.ImVec4(0,0,0,0)
  self:refreshColors()
  self.alpha = im.FloatPtr(0.75)

  self.moveModes = {
    "withNodes",
    "withoutNodes"
  }
  self.moveMode = "withoutNodes"
  self.simple = im.BoolPtr(false)
end



function C:showProperties()
  --self.te = im.createTextEditor()
  --im.TextEditor_SetText(self.te, self.commentText)
end

function C:hideProperties()
  --im.destroyTextEditor(self.te)
  --self.te = nil
end

function C:drawCustomProperties()
  local reason = nil
  local imText = im.ArrayChar(64, self.commentTitle)
  local descText = im.ArrayChar(2048, self.commentText)
  im.Columns(2)
  im.Text("Title")
  im.NextColumn()
  if im.InputText("##title" .. self.id, imText, nil, im.InputTextFlags_EnterReturnsTrue) then
    self.commentTitle = ffi.string(imText)
    reason = "Changed title to self.commentTitle"
  end
  im.NextColumn()

  im.Text("Alpha")
  im.NextColumn()
  im.SliderFloat('##Alpha',self.alpha,0,1)
  if im.IsItemDeactivatedAfterEdit() then
    reason = "Changed alpha of comment."
  end
  im.NextColumn()

  im.Text("Background")
  im.NextColumn()
  if im.ColorEdit4("##BgClr",self.backgroundColor) then self:refreshColors() end
  if im.IsItemDeactivatedAfterEdit() then
      reason = "Changed background color of comment."
  end
  im.NextColumn()
  im.Text("Border")
  im.NextColumn()

  if im.ColorEdit4("##BorderClr",self.borderColor) then self:refreshColors() end
  if im.IsItemDeactivatedAfterEdit() then
      reason = "Changed border color of comment."
  end
  im.NextColumn()
  im.Text("Text")
  im.NextColumn()
  if im.ColorEdit4("##TextClr",self.textColor) then self:refreshColors() end
  if im.IsItemDeactivatedAfterEdit() then
      reason = "Changed text color of comment."
  end
  im.NextColumn()
  im.Text("Simple")
  im.NextColumn()
  if im.Checkbox("##Simple", self.simple) then   reason = "Changed Simple" end
  im.NextColumn()

  if not self.simple[0] then
    im.Text("Move Mode")
    im.NextColumn()
    if im.BeginCombo("##moveMode" .. self.id, moveModesPrettyNames[self.moveMode]) then
      for _, mode in ipairs(self.moveModes) do
        if im.Selectable1(moveModesPrettyNames[mode], mode == self.moveMode) then
          self.moveMode = mode
          reason = "Changed Move mode to " .. mode
        end
      end
      im.EndCombo()
    end
    ui_flowgraph_editor.tooltip("Whether or not nodes inside will be attached to this node.")
  end

  im.Columns(1)
  im.Separator()

  if im.InputTextMultiline("##" .. self.id, descText, 2048,im.ImVec2(im.GetContentRegionAvailWidth(),300), im.InputTextFlags_Multiline) then
    self.commentText = ffi.string(descText)
  end
  if self.te then
    local avail = im.GetContentRegionAvail()

    if im.TextEditor_Render(self.te, "Comment Text",avail) then
    end
    dump(self.te)
  end
  return reason
end

function C:refreshColors()
  self.bgColorVec4 = im.ImVec4(self.backgroundColor[0],self.backgroundColor[1],self.backgroundColor[2],self.backgroundColor[3])
  self.borderColorVec4 = im.ImVec4(self.borderColor[0],self.borderColor[1],self.borderColor[2],self.borderColor[3])
  self.textColorVec4 = im.ImVec4(self.textColor[0],self.textColor[1],self.textColor[2],self.textColor[3])
end

function C:_onSerialize(res)
  res.commentSize = {self.commentSize.x, self.commentSize.y}
  res.backgroundColor = {self.backgroundColor[0],self.backgroundColor[1],self.backgroundColor[2],self.backgroundColor[3]}
  res.borderColor = {self.borderColor[0],self.borderColor[1],self.borderColor[2],self.borderColor[3]}
  res.textColor = {self.textColor[0],self.textColor[1],self.textColor[2],self.textColor[3]}
  res.alpha = self.alpha[0]
  res.commentTitle = self.commentTitle
  res.commentText = string.gsub(self.commentText, "\n", "\\n")
  res.simple = self.simple[0]
  res.moveMode = self.moveMode
end

function C:_onDeserialized(nodeData)
  self.commentSize = im.ImVec2(nodeData.commentSize[1], nodeData.commentSize[2])
  if nodeData.backgroundColor then
    self.backgroundColor[0] = nodeData.backgroundColor[1]
    self.backgroundColor[1] = nodeData.backgroundColor[2]
    self.backgroundColor[2] = nodeData.backgroundColor[3]
    self.backgroundColor[3] = nodeData.backgroundColor[4]
  end
  if nodeData.backgroundColor then
    self.borderColor[0] = nodeData.borderColor[1]
    self.borderColor[1] = nodeData.borderColor[2]
    self.borderColor[2] = nodeData.borderColor[3]
    self.borderColor[3] = nodeData.borderColor[4]
  end
  if nodeData.textColor then
    self.textColor[0] = nodeData.textColor[1]
    self.textColor[1] = nodeData.textColor[2]
    self.textColor[2] = nodeData.textColor[3]
    self.textColor[3] = nodeData.textColor[4]
  end
  self:refreshColors()
  self.alpha[0] = nodeData.alpha
  self.commentTitle = nodeData.commentTitle or "Comment"
  self.commentText = string.gsub(nodeData.commentText or "", "\\n", "\n") or ""
  self.simple = im.BoolPtr(nodeData.simple or false)
  self.moveMode = nodeData.moveMode or "withoutNodes"
  self.forceSize = true
end


-- updating the node position should only happen when you open the manager in the editor.
function C:updateEditorPosition()
  if self.nodePosition and (ui_flowgraph_editor.GetCurrentEditor() ~= nil) then
    if    self.nodePosition[1] > -2e8 and self.nodePosition[2] > -2e8
      and self.nodePosition[1] <  2e8 and self.nodePosition[2] <  2e8 then
      ui_flowgraph_editor.SetNodePosition(self.id, im.ImVec2(self.nodePosition[1], self.nodePosition[2]))
    end
  end
  self.forceSize = true
end

function C:draw()
  im.PushStyleVar1(im.StyleVar_Alpha, self.alpha[0])
  ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_NodeBg, self.bgColorVec4)
  ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_NodeBorder, self.borderColorVec4)

  ui_flowgraph_editor.BeginNode(self.id)
    ui_flowgraph_editor.SetGroupingDisabled(self.id, self.moveMode == "withoutNodes")
    im.BeginGroup("content")
      im.BeginGroup("horizontal")
        --editor.uiIconImage("lock")
        im.TextColored(self.textColorVec4,ffi.string(self.commentTitle))
      im.EndGroup()
      local cp = im.GetCursorPos()
      cp.x = cp.x + 5
      cp.y = cp.y + 5
      if not self.simple[0] then
        ui_flowgraph_editor.Group(self.commentSize, self.forceSize)
        self.forceSize = false
        local commentSize = im.GetItemRectSize()
        if commentSize.x < 5 then self.commentSize.x = self.storedCommentSize.x self.forceSize = true end
        if commentSize.y < 5 then self.commentSize.y = self.storedCommentSize.y self.forceSize = true end

        if not self.forceSize then
          self.commentSize = commentSize
          self.storedCommentSize.x = self.commentSize.x
          self.storedCommentSize.y = self.commentSize.y
        end

      end
      im.SetCursorPos(cp)
      im.TextColored(self.textColorVec4,self.commentText)
    im.EndGroup()
  ui_flowgraph_editor.EndNode()
  ui_flowgraph_editor.PopStyleColor(2)
  im.PopStyleVar()

  if ui_flowgraph_editor.BeginGroupHint(self.id) then
    local alpha = self.alpha[0] * im.GetStyle().Alpha

    im.PushStyleVar1(im.StyleVar_Alpha, self.alpha[0] * im.GetStyle().Alpha)

    local min = ui_flowgraph_editor.GetGroupMin()
    --auto max = ui_flowgraph_editor.GetGroupMax()
    min.x = min.x+4
    min.y = min.y - im.GetTextLineHeightWithSpacing() + 2
    local itemSize = im.CalcTextSize(self.commentTitle)

    local col1 = im.GetColorU322(self.bgColorVec4)
    local col2 = im.GetColorU322(self.borderColorVec4)

    local rMin = im.ImVec2(min.x - 4, min.y - 1)
    local rMax = im.ImVec2(min.x + itemSize.x + 4, min.y + itemSize.y + 1)
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), rMin, rMax, col1, 4)
    im.ImDrawList_AddRect(im.GetWindowDrawList(), rMin, rMax, col2, 4)
    im.SetCursorScreenPos(min)
    im.BeginGroup()
    im.TextColored(self.textColorVec4,self.commentTitle)
    im.EndGroup()

    rMin.x = rMin.x - 4
    rMin.y = rMin.y - 1
    rMax.x = rMax.x + 4
    rMax.y = rMax.y + 1
    --local hintBounds = im.GetItemRectSize() --ImGui_GetItemRect()
    --local hintFrameBounds = hintBounds.expanded(8, 4)



    im.PopStyleVar()
  end
  ui_flowgraph_editor.EndGroupHint()
end



return _flowgraph_createNode(C)
