-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_layout'
local imgui = ui_imgui
local imguiUtils = require('ui/imguiUtils')
local imguiIO = imgui.GetIO()
local defaultDirectory = "settings/editor/layouts/Default"
local defaultImguiIniFile = "settings/default_imgui.ini"
local imguiIniFile = "settings/imgui.ini"

local function getWindowLayouts(toolName)
  return FS:directoryList("settings/" .. (toolName or "editor") .. "/layouts/", false, true)
end

local function loadWindowLayout(layout, toolName)
  local layoutDirectory = layout or defaultDirectory

  editor.loadWindowsState(layoutDirectory .. "/windowsState.json", toolName)

  if FS:getFileRealPath(layoutDirectory) == FS:getFileRealPath(defaultDirectory) then
    imgui.loadIniSettingsFromDisk(defaultImguiIniFile)
  else
    imgui.loadIniSettingsFromDisk(imguiIniFile)
  end
end

local function saveWindowLayout(layoutName, toolName)
  local layoutDirectory = "settings/" .. (toolName or "editor") .. "/layouts/" .. layoutName

  editor.saveWindowsState(layoutDirectory .. "/windowsState.json")
  imgui.saveIniSettingsToDisk(imguiIniFile)
end

local function loadCurrentWindowLayout(toolName)
  editor.loadWindowsState("settings/" .. (toolName or "editor") .. "/windowsState.json", toolName)
  imgui.loadIniSettingsFromDisk(imguiIniFile)
end

local function saveCurrentWindowLayout(toolName)
  editor.saveWindowsState("settings/" .. (toolName or "editor") .. "/windowsState.json")
  imgui.saveIniSettingsToDisk(imguiIniFile)
end

local function deleteWindowLayout(layoutPath)
  for _, path in ipairs(FS:findFiles(layoutPath, "*", -1, true, false)) do
    FS:removeFile(path)
  end

  FS:directoryRemove(layoutPath)
end

local function resetLayouts(toolName)
  local layoutDirectory = "settings/" .. (toolName or "editor") .. "/layouts"

  for _, path in ipairs(FS:findFiles(layoutDirectory, "*", 0, true, true)) do
    deleteWindowLayout(path)
  end

  FS:directoryRemove(layoutDirectory)
  loadWindowLayout(layoutDirectory .. "/Default")
end

M.getWindowLayouts = getWindowLayouts
M.loadWindowLayout = loadWindowLayout
M.saveWindowLayout = saveWindowLayout
M.loadCurrentWindowLayout = loadCurrentWindowLayout
M.saveCurrentWindowLayout = saveCurrentWindowLayout
M.deleteWindowLayout = deleteWindowLayout
M.resetLayouts = resetLayouts

return M