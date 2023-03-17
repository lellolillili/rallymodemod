-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper for the level people, so they can mark things :)

local M = {}
local imgui = ui_imgui
local toolWindowName = "AutoSave Restore"
local autoSaveTimer = 0
local autoSaveFirstFrame = false
local showWindowNow = false
local autosaves = nil
local selectedAutosaveIndex = 0
local wasNotCleanExit = false

local function gatherAvailableAutoSaves()
  if editor.getLevelName() == "" then return end
  local folders = FS:directoryList("/settings/editor/autosaves/" .. editor.getLevelName(), false, true)
  autosaves = {}
  for i = 1, tableSize(folders) do
    table.insert(autosaves, {
       path = folders[i],
       displayPath = string.gsub(folders[i], "/settings/editor/autosaves/", ""),
       datetime = os.date("%x %X", FS:stat(folders[i]).modtime)
       })
  end
end

local function restoreLevelFromAutosave(index)
  local oldPath = editor.levelPath
  local newPath = autosaves[index].path .. "/"
  editor.logInfo("Restoring autosaved scene tree...")
  editor.copyDirectory(newPath, oldPath)
  editor.openLevel(oldPath)
end

local function showAutoSaveDialog()
  if (not editor.getPreference("general.internal.cleanExit")
      and not autoSaveFirstFrame
      and editor.getPreference("general.internal.lastLevel") == editor.getLevelPath())
    or showWindowNow then
      gatherAvailableAutoSaves()
      wasNotCleanExit = not editor.getPreference("general.internal.cleanExit")
      if (not tableIsEmpty(autosaves)) or showWindowNow then
        imgui.OpenPopup("AutoSave Restore")
      end
      showWindowNow = false
  end

  if imgui.BeginPopupModal("AutoSave Restore", nil, imgui.WindowFlags_AlwaysAutoResize) then
    editor.setPreference("general.internal.cleanExit", true)

    if wasNotCleanExit then
      imgui.Text("It seems the game was not closed properly and the edited level was not saved.")
    end

    imgui.Text("You can choose one of the autosaved levels (scene tree) to revert your level scene:")
    imgui.Separator()
    imgui.BeginChild1("autosaves", imgui.ImVec2(0, 200))
    for k = tableSize(autosaves), 1, -1 do
      imgui.PushID1(tostring(k))
      if imgui.Selectable1(autosaves[k].displayPath .. " @ " ..  autosaves[k].datetime, k == selectedAutosaveIndex) then
        selectedAutosaveIndex  = k
      end
      imgui.PopID()
    end
    imgui.EndChild()

    if imgui.Button("Restore") then
      imgui.OpenPopup("AutoSave Restore Confirm")
    end
    imgui.SameLine()
    if imgui.Button("Close") then
      imgui.CloseCurrentPopup()
    end
    imgui.SameLine()
    --TODO: all folder must be empty before FS:directoryRemove
    -- if imgui.Button("Delete all autosaves for this level") then
    --   FS:directoryRemove("/settings/editor/autosaves/" .. editor.getLevelName())
    --   imgui.CloseCurrentPopup()
    -- end
    local closeWindow = false
    if imgui.BeginPopupModal("AutoSave Restore Confirm", nil, imgui.WindowFlags_AlwaysAutoResize) then
      imgui.Text("This operation will overwrite the level's scene tree: " .. editor.getLevelPath() .. "main/" ..
        "\nWith autosaved scene tree from: " .. autosaves[selectedAutosaveIndex].path .. "/main/" ..
        "\n\nWARNING! This operation is not undoable.")
      imgui.Spacing()
      imgui.Separator()
      imgui.Spacing()
      if imgui.Button("Load AutoSave") then
        imgui.CloseCurrentPopup()
        restoreLevelFromAutosave(selectedAutosaveIndex)
        closeWindow = true
      end
      imgui.SameLine()
      if imgui.Button("Cancel") then
        imgui.CloseCurrentPopup()
      end
      imgui.EndPopup()
    end
    if closeWindow then imgui.CloseCurrentPopup() end
    imgui.EndPopup()
  end

  autoSaveFirstFrame = true
end

local function onEditorGui(dtReal, dtSim, dtRaw)
  showAutoSaveDialog()
  if not editor.getPreference("files.autoSave.active") then return end

  autoSaveTimer = autoSaveTimer - dtReal

  if autoSaveTimer <= editor.getPreference("files.autoSave.noticeInterval") then
    editor.setStatusBar("AutoSaving in " .. math.floor(autoSaveTimer) .. " seconds...")
  end

  if autoSaveTimer <= 0 then
    editor.hideStatusBar()
    editor.autoSaveLevel()
    autoSaveTimer = editor.getPreference("files.autoSave.interval")
    gatherAvailableAutoSaves()
  end
end

local function onToolMenuItem()
  showWindowNow = true
  wasNotCleanExit = false
end

local function onEditorInitialized()
  autoSaveTimer = editor.getPreference("files.autoSave.interval")
  editor.addWindowMenuItem(toolWindowName, onToolMenuItem)
end

local function onEditorPreferenceValueChanged(path, value)
  if path == "files.autoSave.interval" then
    autoSaveTimer = value
    if value < editor.getPreference("files.autoSave.noticeInterval") then
      editor.setPreference("files.autoSave.noticeInterval", value)
    end
    editor.hideStatusBar()
  end
  if path == "files.autoSave.noticeInterval" then
    if value > editor.getPreference("files.autoSave.interval") then
      editor.setPreference("files.autoSave.noticeInterval", editor.getPreference("files.autoSave.interval"))
    end
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("files")
  prefsRegistry:registerSubCategory("files", "autoSave", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {active = {"bool", false, "If checked, the level scene tree will be saved at a specific interval to /settings/editor/autosaves folder in the user folder"}},
    {saveBackupCopy = {"bool", false, "If checked, a backup copy of the level scene tree will be saved in the /settings/editor/backups folder in the user folder,\n when Save Level is executed manually, regardless if AutoSave is active or not"}},
    {interval = {"int", 120, "The interval in seconds at which the current level scene tree is saved", "Auto Save Interval (Seconds)"}},
    {noticeInterval = {"int", 10, "The countdown interval in seconds to warn user that an autosave will occur"}},
    {maxAutoSaveCountPerSession = {"int", 3, "The maximum autosaves per game session, before the counter will be reset and overwriting will occur for the autosaved files"}},
    -- hidden prefs
    {counter = {"int", 1, "Keeps current autosave counter between sessions", nil, nil, nil, true}},
  })
end

-- public interface
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged

return M