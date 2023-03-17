-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_shortcut_legend'
local toolWindowName = "shortcutLegend"
local im = ui_imgui
local updateActionList
local compoundedActionInfos = {}

local prettyNames = {
  zaxis = "MouseWheel"
}

local modifierNames = {}

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Shortcut Legend", im.WindowFlags_NoTitleBar) then
    if updateActionList then
      local actionInfos = {}
      local currentActionNames = {}
      if editor.editMode and editor.editMode.getLegendCurrentActionNames then
        currentActionNames = editor.editMode.getLegendCurrentActionNames()
      end

      compoundedActionInfos = {}
      if editor.editMode and not tableIsEmpty(currentActionNames) then
        for controlFlag, title in pairs(currentActionNames) do
          local control
          for modifierFlag, modifierName in pairs(modifierNames) do
            if type(controlFlag) == "number" then
              if bit.band(controlFlag, modifierFlag) ~= 0 then
                if not control then
                  control = modifierName
                else
                  control = control .. " + " .. modifierName
                end
              end
            else
              control = controlFlag
            end
          end
          if control then
            table.insert(compoundedActionInfos, {control = control, title = title})
          end
        end
      else
        -- Find all actions of the top action map
        if editor.editMode and editor.editMode.actionMap then
          for _,device in ipairs(extensions.core_input_bindings.bindings) do
            if device.devname == "keyboard0" or device.devname == "mouse0" then
              for _, binding in ipairs(device.contents.bindings) do
                local actionmap = extensions.core_input_actions.getActiveActions()[binding.action].actionMap
                if actionmap and actionmap == editor.editMode.actionMap then
                  table.insert(actionInfos, {control = binding.control, title = extensions.core_input_actions.getActiveActions()[binding.action].title})
                end
              end
            end
          end
        end

        compoundedActionInfos = deepcopy(actionInfos)

        if editor.editMode and editor.editMode.auxShortcuts then
          for controlFlag, title in pairs(editor.editMode.auxShortcuts) do
            local control
            for modifierFlag, modifierName in pairs(modifierNames) do
              if type(controlFlag) == "number" then
                if bit.band(controlFlag, modifierFlag) ~= 0 then
                  if not control then
                    control = modifierName
                  else
                    control = control .. " + " .. modifierName
                  end
                end
              else
                control = controlFlag
              end
            end
            if control then
              table.insert(compoundedActionInfos, {control = control, title = title})
            end
          end
        end
      end

      table.sort(compoundedActionInfos, function(a,b) return a.control < b.control end)
      updateActionList = nil
    end

    -- Display the actions in the window
    if #compoundedActionInfos > 0 then
      local padding = im.GetStyle().FramePadding

      -- Center the shortcuts on the bar
      local wholeSpace = im.GetContentRegionAvailWidth()
      local completeNeededSpace = 0
      for _, action in ipairs(compoundedActionInfos) do
        local controlName = prettyNames[action.control] or action.control
        completeNeededSpace = completeNeededSpace + (im.CalcTextSize(controlName).x + 2 * padding.x) + im.CalcTextSize(action.title).x + 25
      end
      if completeNeededSpace < wholeSpace then
        im.SetCursorPosX(im.GetCursorPosX() + (wholeSpace - completeNeededSpace) / 2.0)
      end

      for _, action in ipairs(compoundedActionInfos) do
        local restOfSpace = im.GetContentRegionAvailWidth()
        local controlName = prettyNames[action.control] or action.control
        local spaceNeeded = (im.CalcTextSize(controlName).x + 2 * padding.x) + im.CalcTextSize(action.title).x
        if spaceNeeded > restOfSpace then
          -- Overwrite the last SameLine()
          im.Dummy(im.ImVec2(0, 0))
          im.Dummy(im.ImVec2(0, 2))
        end
        local topLeft = im.ImVec2(im.GetWindowPos().x + im.GetCursorPos().x - padding.x, im.GetWindowPos().y + im.GetCursorPos().y - im.GetScrollY())
        local bottomRight = im.ImVec2(topLeft.x + im.CalcTextSize(controlName).x + 2 * padding.x, topLeft.y + im.CalcTextSize(controlName).y + padding.y)

        im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), topLeft, bottomRight, im.GetColorU321(im.Col_FrameBg), 2, nil, 2)

        im.Text(controlName)
        im.SameLine()
        im.Text(" " .. action.title)
        im.SameLine()
        im.Dummy(im.ImVec2(20, 0))
        im.SameLine()
      end
    end
  end
  editor.endWindow()
end

local function onExtensionLoaded()
end

local function onEditorInitialized()
  modifierNames[editor.AuxControl_Ctrl] = "Ctrl"
  modifierNames[editor.AuxControl_Shift] = "Shift"
  modifierNames[editor.AuxControl_Alt] = "Alt"
  modifierNames[editor.AuxControl_LCtrl] = "LCtrl"
  modifierNames[editor.AuxControl_RCtrl] = "RCtrl"
  modifierNames[editor.AuxControl_LAlt] = "LAlt"
  modifierNames[editor.AuxControl_RAlt] = "RAlt"
  modifierNames[editor.AuxControl_LShift] = "LShift"
  modifierNames[editor.AuxControl_RShift] = "RShift"
  modifierNames[editor.AuxControl_MWheel] = "MouseWheel"
  modifierNames[editor.AuxControl_LMB] = "LMB"
  modifierNames[editor.AuxControl_MMB] = "MMB"
  modifierNames[editor.AuxControl_RMB] = "RMB"
  modifierNames[editor.AuxControl_Copy] = "Ctrl C"
  modifierNames[editor.AuxControl_Paste] = "Ctrl V"
  modifierNames[editor.AuxControl_Cut] = "Ctrl X"
  modifierNames[editor.AuxControl_Duplicate] = "Ctrl D"
  modifierNames[editor.AuxControl_Delete] = "Delete"

  editor.registerWindow(toolWindowName)
  editor.showWindow(toolWindowName)
end

local function onEditorEditModeChanged(oldEditMode, newEditMode)
  updateActionList = true
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onExtensionLoaded = onExtensionLoaded
M.onEditorEditModeChanged = onEditorEditModeChanged

return M
