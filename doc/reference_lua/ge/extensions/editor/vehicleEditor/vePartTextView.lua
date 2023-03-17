-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local imguiUtils = require('ui/imguiUtils')
local jbeamIO = require('jbeam/io')
local jsonAST = require('json-ast')
local im = ui_imgui

local wndName = 'Part Text View'

local tableFlags = bit.bor(im.TableFlags_ScrollX, im.TableFlags_ScrollY, im.TableFlags_RowBg, im.TableFlags_Borders)

local clipper = nil

local initTextView = true
local numOfLines = 1
local currLineLength = 0
local maxLineLength = 1
local lineCounter = 1
local firstLine = true
local lineToScrollTo = -1
local editNodeIdx

local textColorDefault = im.GetColorU322(im.ImVec4(1, 1, 1, 1))
local nodeColorDefault = im.GetColorU322(im.ImVec4(1, 1, 1, 0.1))
local nodeColorHighlight = im.GetColorU322(im.ImVec4(1, 1, 1, 0.5))
local nodeColorHighlightRed = im.GetColorU322(im.ImVec4(1, 1, 0.5, 0.2))

local scrollToSelection = im.BoolPtr(true)

local nodeEditTextInput = im.ArrayChar(256)
local nodeEditDoubleInput = im.DoublePtr(0)

local colorTable = {
  ['string'] = im.ImVec4(0.31, 0.73, 1, 1),
  string_single = im.ImVec4(0.31, 0.73, 1, 1),
  comment = im.ImVec4(0.42, 0.6, 0.29, 1),
  comment_multiline = im.ImVec4(0.42, 0.6, 0.29, 1),
  list_begin = im.ImVec4(0.95, 0.84, 0.06, 1),
  list_end = im.ImVec4(0.95, 0.84, 0.06, 1),
  object_begin = im.ImVec4(0.85, 0.39, 0.63, 1),
  object_end = im.ImVec4(0.85, 0.39, 0.63, 1),
}

--local p = LuaProfiler("Part_Text_View")

local function save()
  writeFile(vEditor.astFilename, jsonAST.stringify(vEditor.ast.ast))
  log('I', '', 'Wrote file: '.. tostring(vEditor.astFilename))
end

local function _editNode(nodeIdx, node)
  local nodeType = node[1]
  editNodeIdx = nodeIdx
  log('I', '', '_editNode: ' .. tostring(nodeIdx))
  nodeEditTextInput[0] = 0
  nodeEditDoubleInput[0] = 0
  if nodeType == 'string' or nodeType == 'string_single' then
    nodeEditTextInput = im.ArrayChar(256, node[2])
  elseif nodeType == 'number' then
    nodeEditDoubleInput[0] = node[2]
  elseif nodeType == 'bool' then
    node[2] = not node[2]
    return
  end
  editor.openModalWindow("editASTNode")
end

local tempTbl = {}

local function _renderNode(nodeIdx, node, scrollToSel)
  tempTbl[1] = node

  local text = jsonAST.stringifyNodes(tempTbl)
  local color = colorTable[node[1]]
  if color then
    im.PushStyleColor2(im.Col_Text, color)
  end
  im.PushID1(tostring(nodeIdx))
  im.TextUnformatted(text)
  if im.IsItemHovered() and im.IsMouseDoubleClicked(0) then
    _editNode(nodeIdx, node)
  end
  im.PopID()
  if color then
    im.PopStyleColor()
  end

  local nodeColor = nodeColorDefault
  if im.IsItemHovered() then
    nodeColor = nodeColorHighlight
    local rMin = im.GetItemRectMin()
    local rMax = im.GetItemRectMax()
    im.ImDrawList_AddRect(
      im.GetWindowDrawList(),
      rMin,
      rMax,
      nodeColor,
      0,
      nil,
      2
    )
    --if im.IsItemClicked(0) then
    --  node[1] = 'string'
    --  node[2] = 'Hello world :D'
    --end
  end

  local nodeSelected = vEditor.selectedASTNodeMap ~= nil and vEditor.selectedASTNodeMap[nodeIdx]

  if nodeSelected then
    if scrollToSel and vEditor.scrollToNode then
      vEditor.scrollToNode = false
      lineToScrollTo = lineCounter
    end
    local rMin = im.GetItemRectMin()
    local rMax = im.GetItemRectMax()
    im.ImDrawList_AddRectFilled(
      im.GetWindowDrawList(),
      rMin,
      rMax,
      nodeColorHighlightRed,
      0,
      nil,
      0
    )
  end

  if initTextView then
    currLineLength = currLineLength + im.GetItemRectSize().x
  end
end

local function _renderASTNodeTree(nodeIdx, clipperStart, clipperEnd, scrollToSel)
  local node = vEditor.ast.ast.nodes[nodeIdx]
  local nodeHierarchy = vEditor.ast.transient.hierarchy[nodeIdx]
  local nodeType = node[1]

  local doScrollToSelection = scrollToSel and vEditor.scrollToNode
  local visible = initTextView or doScrollToSelection or (lineCounter >= clipperStart and lineCounter <= clipperEnd)

  if visible then
    if firstLine then
      im.TableNextColumn()
      im.TextUnformatted(tostring(lineCounter))
      im.TableNextColumn()
      firstLine = false
    end
    _renderNode(nodeIdx, node, scrollToSel)
  end

  if nodeType == 'object_begin' or nodeType == 'list_begin' then
    im.SameLine()
    for _, childNodeIdx in ipairs(nodeHierarchy) do
      _renderASTNodeTree(childNodeIdx, clipperStart, clipperEnd, scrollToSel)
    end
  end
  if nodeType ~= 'newline' and nodeType ~= 'newline_windows' then
    im.SameLine()
  else
    maxLineLength = math.max(maxLineLength, currLineLength)
    currLineLength = 0

    lineCounter = lineCounter + 1

    if visible then
      im.TableNextColumn()
      im.TextUnformatted(tostring(lineCounter))
      im.TableNextColumn()
    end
  end
end

local oldPartName, oldResult, success

local function onEditorGui()
  if not vEditor.vehicle or not vEditor.vehData or not vEditor.selectedPart then return end

  local partName = vEditor.selectedPart
  local ioCtx = vEditor.vehData.ioCtx

  -- On part selected changed
  if oldPartName ~= partName then
    oldPartName = partName
    success, oldResult = pcall(function() return {jbeamIO.getPart(ioCtx, partName)} end)
    if not success then return end

    initTextView = true
  end

  if not oldResult then return end
  local part = oldResult[1]
  local jbeamFilename = oldResult[2]

  if editor.beginWindow(wndName, wndName, im.WindowFlags_MenuBar) then
    if im.BeginMenuBar() then
      if im.MenuItem1("Reload") then
        vEditor.ast = nil
      end
      if im.MenuItem1("Save") then
        save()
      end
      if im.MenuItem1("Close") then
        vEditor.selectedPart = nil
        return
      end
      if im.MenuItem1("Delete") then
        FS:removeFile(jbeamFilename)
        ast = nil
      end
      im.Checkbox("Scroll to selection", scrollToSelection)
      im.TextUnformatted(tostring(vEditor.selectedPart) .. ' - ')
      if jbeamFilename then
        im.TextUnformatted(tostring(jbeamFilename))
      end
      im.EndMenuBar()
    end

    if jbeamFilename then
      im.SameLine()
      if im.Button('explore') then
        Engine.Platform.exploreFolder(jbeamFilename)
      end
      local stat = FS:stat(jbeamFilename)
      if stat then
        im.SameLine()
        im.TextUnformatted('File times: ')
        im.SameLine()
        if stat.modtime ~= stat.createtime then
          im.TextUnformatted('created: ' .. os.date("%x %H:%M", stat.createtime) .. ' - modified: ' .. os.date("%x %H:%M", stat.modtime))
        else
          im.TextUnformatted('created: ' .. os.date("%x %H:%M", stat.createtime))
        end
      end
    end

    if vEditor.ast then
      im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 2))
      im.PushFont2(1) -- 1= monospace? PushFont3("cairo_semibold_large")

      local fontSize = im.GetFontSize()
      --local fontSize = im.GetTextLineHeight()

      --im.SetNextWindowContentSize(im.ImVec2(maxLineLength, 0))

      if initTextView then
        maxLineLength = 1
        currLineLength = 0
      end

      if im.BeginTable('astTable', 2, tableFlags) then
        clipper = ffi.new('ImGuiListClipper[1]')
        ffi.C.imgui_ImGuiListClipper_Begin(clipper, numOfLines, fontSize)
        ffi.C.imgui_ImGuiListClipper_Step(clipper)

        lineCounter = 1
        firstLine = true

        im.TableSetupColumn('', im.TableColumnFlags_NoHide, 0)
        im.TableSetupColumn('', im.TableColumnFlags_NoHide, maxLineLength)

        if vEditor.ast.transient.root then
          _renderASTNodeTree(vEditor.ast.transient.root, clipper[0].DisplayStart, clipper[0].DisplayEnd, scrollToSelection[0])
        end

        if lineToScrollTo ~= -1 then
          local itemPosY = clipper[0].StartPosY + clipper[0].ItemsHeight * lineToScrollTo
          im.SetScrollFromPosY(itemPosY - im.GetWindowPos().y)
          lineToScrollTo = -1
        end

        ffi.C.imgui_ImGuiListClipper_End(clipper)

        if initTextView then
          numOfLines = lineCounter

          initTextView = false
        end
      end
      im.EndTable()

      im.PopFont()
      im.PopStyleVar()
    end
  end
  editor.endWindow()

  if editor.beginModalWindow("editASTNode", "Edit Node") and editNodeIdx then
    local node = vEditor.ast.ast.nodes[editNodeIdx]
    local nodeHierarchy = vEditor.ast.transient.hierarchy[editNodeIdx]
    local nodeType = node[1]
    im.TextUnformatted(tostring(nodeType) .. ' - ' .. tostring(editNodeIdx))
    im.TextUnformatted('Raw node data: ' .. dumps(node))
    if nodeType == 'string' or nodeType == 'string_single' then
      im.InputText('##nodeEditTextInput', nodeEditTextInput)
    elseif nodeType == 'number' then
      im.InputScalar('##nodeEditScalarInput', im.DataType_Double, nodeEditDoubleInput)
    elseif nodeType == 'bool' then
      im.Checkbox('##nodeEditBoolInput', nodeEditBoolInput)
    end
    --im.SetKeyboardFocusHere(0)
    im.Separator()
    if im.Button("Apply") then
      if nodeType == 'string' or nodeType == 'string_single' then
        node[2] = ffi.string(nodeEditTextInput)
      elseif nodeType == 'number' then
        node[2] = nodeEditDoubleInput[0]
      end
      editor.closeModalWindow("editASTNode")
      editNodeIdx = nil
    end
    im.SameLine()
    if im.Button("Cancel") then
      editor.closeModalWindow("editASTNode")
      editNodeIdx = nil
    end
  end
  editor.endModalWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,400))
  editor.registerModalWindow("editASTNode")
end

M.onEditorGui = onEditorGui
M.open = open
M.onEditorInitialized = onEditorInitialized

return M