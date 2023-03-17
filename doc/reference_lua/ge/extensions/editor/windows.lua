-- This Source Code Form is subject to the terms of the bCDDL, var. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- TODO: add favourites section

local M = {}

local ffi = require('ffi')
local im = ui_imgui
local imguiUtils = require('ui/imguiUtils')
local windowName = "windows"
local filter = im.ImGuiTextFilter()

local windowPos
local windowSize

local function windowPosCheck()
  local mainViewport = im.GetMainViewport()
  local mVPos = mainViewport.Pos
  local mVSize = mainViewport.Size
  local moveWindow = false

  if windowPos.x + windowSize.x -40 < mVPos.x then
    moveWindow = true
  end
  if windowPos.y < mVPos.y then
    moveWindow = true
  end
  if windowPos.x > mVPos.x + mVSize.x then
    moveWindow = true
  end
  if windowPos.y > mVPos.y + mVSize.y then
    moveWindow = true
  end

  if moveWindow then
    im.SetWindowPos2("Windows", im.ImVec2(mainViewport.Pos.x + 40, mainViewport.Pos.y + 40))
  end
end

local function onEditorGui()
  if editor.beginWindow(windowName, "Windows") then

    windowPos = im.GetWindowPos()
    windowSize = im.GetWindowSize()
    windowPosCheck()

    local windowsData = editor.getWindowsState()
    local windows = {}
    for name, data in pairs(windowsData) do
      table.insert(windows, data.title or name)
    end
    table.sort(windows)

    editor.uiInputSearchTextFilter("##windowsFilter", filter, im.GetContentRegionAvailWidth())
    if im.BeginChild1("Windows##Child", nil, true) then
      im.Columns(2, "windowsColumns")
      for _, name in pairs(windows) do
        if im.ImGuiTextFilter_PassFilter(filter, name) then
          im.TextUnformatted(name)
          im.NextColumn()
          if im.Button("Set position to 0,0##" .. name) then
            im.SetWindowPos2(name, im.ImVec2(0, 0))
          end
          im.NextColumn()
        end
      end
    end
    im.EndChild()
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(windowName)
end

local function onEditorInitialized()
  editor.registerWindow(windowName, im.ImVec2(800, 500))
  editor.editModes.assetBrowserEditMode = {
    onToolbar = nil,
    icon = nil,
  }

  editor.addWindowMenuItem("Windows", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M