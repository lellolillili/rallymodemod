  -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local imgui = ui_imgui
local newsDlgName = "newsModalDlg"

local EditorNewsMessageVersion = 5
local newsText = [[
]]

local function onEditorGui()
  if newsText == "" or not newsText then return end
  if (not editor.getPreference("newsMessage.general.newsMessageShown")
    or editor.getPreference("newsMessage.general.newsMessageVersion") ~= EditorNewsMessageVersion) then
    editor.setPreference("newsMessage.general.newsMessageShown", true)
    editor.setPreference("newsMessage.general.newsMessageVersion", EditorNewsMessageVersion)
    editor.openModalWindow(newsDlgName)
  end
  if editor.beginModalWindow(newsDlgName, "World Editor News", imgui.WindowFlags_AlwaysAutoResize + imgui.WindowFlags_NoScrollbar) then
    editor.uiTextColoredWithFont(imgui.GetStyleColorVec4(imgui.Col_NavHighlight), "Important Editor Release Notes for " .. beamng_versionb, "cairo_regular_medium")
    imgui.Text(newsText)
    imgui.Spacing()
    imgui.Spacing()
    imgui.Spacing()
    imgui.Spacing()
    imgui.Separator()
    editor.uiTextColoredWithFont(nil, "For any issues/feedback please use the support tickets at", "cairo_bold")
    imgui.SameLine()
    if imgui.SmallButton("https://support.beamng.com/") then openWebBrowser("https://support.beamng.com/") end
    imgui.SameLine()
    editor.uiTextColoredWithFont(nil, "or the forum at ", "cairo_bold")
    imgui.SameLine()
    if imgui.SmallButton("https://www.beamng.com/forums/world-editor/") then openWebBrowser("https://www.beamng.com/forums/world-editor/") end
    imgui.Separator()
    imgui.Spacing()
    if imgui.Button("Close##newsCloseBtn", imgui.ImVec2(120, 0)) then editor.closeModalWindow(newsDlgName) end
  end
  editor.endModalWindow()
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("newsMessage")
  prefsRegistry:registerSubCategory("newsMessage", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    -- hidden
    {newsMessageShown = {"bool", false, "", nil, nil, nil, true}},
    {newsMessageVersion = {"int", 0, "", nil, nil, nil, true}},
  })
end

local function onEditorInitialized()
  editor.registerModalWindow(newsDlgName, nil, nil, true)
end

M.onEditorGui = onEditorGui
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorInitialized = onEditorInitialized

return M