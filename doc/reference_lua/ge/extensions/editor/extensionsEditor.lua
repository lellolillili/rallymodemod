-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper for the level people, so they can mark things :)

local M = {}
local imgui = ui_imgui
local toolWindowName = "extensionsEditor"
local toolWindowTitle = "Extensions Editor"
local iconSize = imgui.ImVec2(20, 20)
local iconColor = imgui.ImVec4(1,1,1,1)
local iconDisabledColor = imgui.ImVec4(1,0,0,1)

local function onEditorGui()
  if editor.beginWindow(toolWindowName, toolWindowTitle) then
    imgui.Spacing()
    imgui.TextUnformatted("Control the loading of the editor extensions.")
    imgui.TextUnformatted("NOTE: You will need to reload Lua (Ctrl+L) for the changes to take effect.")
    imgui.TextUnformatted("If an extension is not working properly, you can start editor in safe mode (Ctrl+F11) and disable it here.")
    imgui.Spacing()
    imgui.Separator()
    imgui.Spacing()
    local tableFlags = bit.bor(imgui.TableFlags_ScrollY, imgui.TableFlags_BordersV, imgui.TableFlags_BordersOuterH, imgui.TableFlags_Resizable, imgui.TableFlags_RowBg, imgui.TableFlags_NoBordersInBody)
    local colCount = 1
    if imgui.BeginTable('##extensionstable', colCount, tableFlags) then
      local textBaseWidth = imgui.CalcTextSize('W').x
      imgui.TableSetupScrollFreeze(0, 1) -- Make top row always visible
      imgui.TableSetupColumn("Extensions", imgui.TableColumnFlags_NoHide)
      imgui.TableHeadersRow()
      for k = 1, tableSize(editor.allExtensionNames) do
        local extName = editor.allExtensionNames[k]
        imgui.TableNextRow()
        imgui.TableNextColumn()
        local isDisabled = false
        if editor.extensionsSettings[extName] then
          isDisabled = editor.extensionsSettings[extName].disabled
        end
        local icon = editor.icons.done
        local extIconColor = iconColor
        if isDisabled then icon = editor.icons.do_not_disturb_alt extIconColor = iconDisabledColor end

        if editor.uiIconImageButton(icon, iconSize, extIconColor, extName, nil, nil, extIconColor, nil, false) then
          if not editor.extensionsSettings[extName] then editor.extensionsSettings[extName] = {} end
          editor.extensionsSettings[extName].disabled = not editor.extensionsSettings[extName].disabled
          editor.saveExtensionsSettings()
        end
      end
      imgui.EndTable()
    end
  end
  editor.endWindow()
end

local function onToolMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, imgui.ImVec2(915, 600))
  editor.addWindowMenuItem(toolWindowTitle, onToolMenuItem)
end

local function onEditorPreferenceValueChanged(path, value)
end

local function onEditorRegisterPreferences(prefsRegistry)
end

-- public interface
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged

return M