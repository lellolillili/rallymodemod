-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'headless_editor_test'
local imgui = ui_imgui
local toolWindowName = "headless_editor_test"
local toolbarWindowName = "myCustomToolbar"
local toolName = "myHeadlessTool" -- this should be an unique name

local function onEditorGui()
  if not editor.isHeadlessToolActive(toolName) then return end
  if editor.beginWindow(toolWindowName, "Headless Test Tool Window") then
    if imgui.Button("Test") then
      print("This is a test for headless editor")
    end
  end
  editor.endWindow()

  local toolbarFlags = imgui.WindowFlags_HorizontalScrollbar + imgui.WindowFlags_NoScrollWithMouse

  if editor.beginWindow(toolbarWindowName, "My Toolbar", toolbarFlags, true) then
    if editor.uiIconImageButton(editor.icons.insert_drive_file, nil, nil, nil, nil) then
      print("toolbar btn1")
    end
    if imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text("Button1") imgui.EndTooltip() end
    imgui.SameLine()

    if editor.uiIconImageButton(editor.icons.insert_drive_file, nil, nil, nil, nil) then
      print("toolbar btn2")
    end
    if imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text("Button2") imgui.EndTooltip() end
    imgui.SameLine()

    if editor.uiIconImageButton(editor.icons.save, nil, nil, nil, nil) then
      print("toolbar btn3")
    end
    if imgui.IsItemHovered() then imgui.BeginTooltip() imgui.Text("Button3") imgui.EndTooltip() end
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  -- enable the headless mode (hides menu, toolbars etc.)
  editor.enableHeadless(true, toolName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, imgui.ImVec2(200, 200))
  editor.registerWindow(toolbarWindowName, imgui.ImVec2(500, 200))
  editor.addWindowMenuItem("Headless Editor Test", onWindowMenuItem, {groupMenuName="Experimental"})
end

local function onEditorActivated()
end

-- this hook function is called by the editor when in headless mode to draw your own menubar
local function onEditorHeadlessMainMenuBar()
  if not editor.isHeadlessToolActive(toolName) then return end
  -- show our custom menu for the editor
  if imgui.BeginMainMenuBar() then
    if imgui.BeginMenu("Operations", imgui_true) then
        if imgui.MenuItem1("Exit Headless Mode...", nil, imgui_false, imgui_true) then
          -- disable headless mode
          editor.enableHeadless(false, toolName)
        end
        if imgui.Button("Open Test Window") then
          editor.showWindow(toolWindowName)
        end
        if imgui.Button("Open Toolbar Window") then
          editor.showWindow(toolbarWindowName)
        end
        imgui.EndMenu()
    end
    imgui.EndMainMenuBar()
  end
end

local function onEditorHeadlessChange(enabled, toolName)
  --print(enabled, toolName)
end

if not shipping_build then
  M.onEditorInitialized = onEditorInitialized
  M.onEditorActivated = onEditorActivated
  M.onEditorGui = onEditorGui
  M.onEditorHeadlessMainMenuBar = onEditorHeadlessMainMenuBar
  M.onEditorHeadlessChange = onEditorHeadlessChange
end

return M