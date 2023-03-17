-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = ui_imgui

local wndName = "Node Visualization Modes"

M.menuEntry = "JBeam Debug/Node Visualization"
M.dependencies = {"editor_veMain"}

local state = nil

local nodeTextModes = nil
local nodeVisModes = nil

local nodeTextMode = im.IntPtr(0)
local nodeVisMode = im.IntPtr(0)

local tempArr = {}

local function onBDebugUpdate(newState)
  state = newState

  for _,v in pairs(state.vehicle.nodeTextModes) do
    table.insert(tempArr, v.name)
  end

  nodeTextModes = im.ArrayCharPtrByTbl(tempArr)
  table.clear(tempArr)

  for _,v in pairs(state.vehicle.nodeVisModes) do
    table.insert(tempArr, v.name)
  end

  nodeVisModes = im.ArrayCharPtrByTbl(tempArr)
  table.clear(tempArr)

  return true
end

local function requestBDebugState()
  vEditor.vehicle:queueLuaCommand("bdebug.requestState()")
end

local function setBDebugState()
  vEditor.vehicle:queueLuaCommand("bdebug.setState(" .. serialize(state) .. ")")
end

-- Get latest state from bdebug.lua, get user input, and post them to bdebug.lua
-- Do not use past local results or result of user input for further processing right away (only use latest state from bdebug.lua to do so)
local function onEditorGui()
  if not vEditor.vehicle then return end

  if editor.beginWindow(wndName, wndName) then
    local dirty = false -- flag to indicate if any user input has been made

    if state then
      local currentTextModeID = state.vehicle.nodeTextMode
      local currentVisModeID = state.vehicle.nodeVisMode

      nodeTextMode[0] = currentTextModeID - 1
      nodeVisMode[0] = currentVisModeID - 1

      im.TextColored(im.ImVec4(0.3, 0.9, 0.2, 1.0), "Node Text        ")
      im.SameLine()
      if im.Combo1("##", nodeTextMode, nodeTextModes) then
        -- Change node text
        state.vehicle.nodeTextMode = nodeTextMode[0] + 1
        dirty = true
      end

      im.TextColored(im.ImVec4(0.3, 0.9, 0.2, 1.0), "Visualization mode")
      im.SameLine()
      if im.Combo1("",nodeVisMode, nodeVisModes) then
        -- Change node mode
        state.vehicle.nodeVisMode = nodeVisMode[0] + 1
        dirty = true
      end
    else
      requestBDebugState()
    end

    if dirty then
      setBDebugState()
    end
  end
  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorToolWindowShow(window)
  if window == wndName and vEditor.vehicle then
    requestBDebugState()
  end
end

local function onEditorToolWindowHide(closedWindow)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,200))
end


M.onBDebugUpdate = onBDebugUpdate
M.onEditorGui = onEditorGui
M.open = open
M.onEditorToolWindowShow = onEditorToolWindowShow
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onEditorInitialized = onEditorInitialized

return M
