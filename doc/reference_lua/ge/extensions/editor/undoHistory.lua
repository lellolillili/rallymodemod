-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_extension_undoHistory'
local imgui = ui_imgui
local toolWindowName = "undoHistory"
local selectedIndex = 0
local selectedIndex2 = 0
local toolTipMaxLength = 20
local toolTipMaxWidth = 100

local function getTooltipTextFromAction(action)
  local actionData = dumps(action)
  local lines = {}
  for s in actionData:gmatch("[^\n]+") do
    table.insert(lines, s:sub(1, toolTipMaxWidth)) -- limit width
  end
  local endString = lines[1]
  for i = 2, toolTipMaxLength do
    if lines[i] then
      endString = endString .. "\n" .. lines[i] -- limit height
    else
      break
    end
  end
  if lines[toolTipMaxLength+1] then
    endString = endString .. "\n ..."
  end
  return endString
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Undo History") then
    if imgui.Button("Delete All History") then editor.clearUndoHistory() end
    if imgui.IsItemHovered() then
      imgui.SetTooltip("This will leave changes as they are. Warning, this action cannot be undone.")
    end
    imgui.Separator()
    imgui.Columns(2)
    imgui.TextUnformatted("Undo Stack")
    if imgui.Button("Undo Selected") then editor.undo(tableSize(editor.history.undoStack) - selectedIndex + 1) end
    imgui.BeginChild1("undos", imgui.ImVec2(0, imgui.GetContentRegionAvail().y))
    for k = tableSize(editor.history.undoStack), 1, -1 do
      local isSel = (k >= selectedIndex)
      local action = editor.history.undoStack[k]
      imgui.PushID1(tostring(k))
      if imgui.Selectable1(tostring(k) .. ": " .. action.name, isSel) then selectedIndex = k end
      if imgui.IsItemHovered() then
        imgui.SetTooltip(getTooltipTextFromAction(action))
      end
      imgui.PopID()
    end
    imgui.EndChild()
    imgui.NextColumn()
    imgui.TextUnformatted("Redo Stack")
    if imgui.Button("Redo Selected") then editor.redo(tableSize(editor.history.redoStack) - selectedIndex2 + 1) end
    imgui.BeginChild1("redos", imgui.ImVec2(0, imgui.GetContentRegionAvail().y))
    for k = tableSize(editor.history.redoStack), 1, -1 do
      local isSel = (k >= selectedIndex2)
      local action = editor.history.redoStack[k]
      imgui.PushID1(tostring(k) .. "redo")
      if imgui.Selectable1(tostring(k) .. ": " .. action.name, isSel) then selectedIndex2 = k end
      if imgui.IsItemHovered() then
        imgui.SetTooltip(getTooltipTextFromAction(action))
      end
      imgui.PopID()
    end
    imgui.EndChild()
    imgui.Columns(1)
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onExtensionLoaded()
end

local function onEditorInitialized()
  editor.addWindowMenuItem("Undo History", onWindowMenuItem)
  editor.registerWindow(toolWindowName, imgui.ImVec2(300, 500))
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onExtensionLoaded = onExtensionLoaded

return M