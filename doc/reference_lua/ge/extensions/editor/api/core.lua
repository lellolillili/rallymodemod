-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- global constants
local editor
local imgui = ui_imgui
local tobit = bit.tobit
local band = bit.band
local bor = bit.bor
local bxor = bit.bxor
local bnot = bit.bnot
local blshift = bit.lshift
local preferencesRegistry = {}
-- visualization
local varTypes = {ConVar = 1, LuaVar = 2, Custom = 3, Setting = 4}
local visualizationTypes = {}
local visualizationTypesSortNeeded = false

local function copyDirectory(srcPath, dstPath)
  local filesAndFolders = FS:findFiles(srcPath, "*.*", -1, true, true)

  editor.log("Copying directory '" .. srcPath .. "' to '" .. dstPath .. "'...")

  for _, v in pairs(filesAndFolders) do
    local newFilename = v
    newFilename = newFilename:gsub(srcPath, dstPath)
    FS:copyFile(v, newFilename)
  end
end

local function copyLevelFolder(srcPath, dstPath)
  if srcPath == "" or not srcPath then srcPath = "levels/template/" end
  local filesAndFolders = FS:findFiles(srcPath, "*.*", -1, true, true)
  local srcLevelName = srcPath:gsub("levels/", "")
  local levelName = dstPath:gsub("levels/", "")

  srcLevelName = srcLevelName:gsub("/", "")
  levelName = levelName:gsub("/", "")

  editor.log("Copying source level '" .. srcPath .. "' to destination level '" .. dstPath .. "'...")
  editor.log("This could take a while, replacing ".. srcLevelName .." paths inside data (json) files...")

  for _, v in pairs(filesAndFolders) do
    local newFilename = v

    newFilename = newFilename:gsub(srcPath, dstPath)
    FS:copyFile(v, newFilename)

    if newFilename:find(".json") or newFilename:find(".cs") then
      local content = readFile(newFilename)
      content = content:gsub(srcLevelName, levelName)
      writeFile(newFilename, content)
    end

    if newFilename:find(srcLevelName) then
      local finalFilename = newFilename:gsub(srcLevelName, levelName)
      FS:renameFile(newFilename, finalFilename)
    end
  end
end

--- Reset everything and create a new level from a default template
local function newLevel()
  extensions.hook("onEditorExitLevel")
  extensions.hook("onEditorBeforeNewLevel")
  editor.history:clear()
  editor.levelPath = ""
  editor.setPreference("files.autoSave.counter", 1)
  editor.newLevelCreated = true
  extensions.hook("onEditorAfterNewLevel")
  editor.resetDirty()
  -- NOTE: no deletion of the scenetree happens because the template new level is loaded instead
end

--- Open an existing level from disk. Will remove any unsaved changes made to the current level.
-- @param path the level folder, relative to game root
local function openLevel(path)
  editor.newLevel()
  extensions.hook("onEditorBeforeOpenLevel")

  if path ~= "" then
    editor.shutdown()
    core_levels.startLevel(path)
  end

  extensions.hook("onEditorAfterOpenLevel")
end

local function saveLevelBackup()
  extensions.hook("onEditorBeforeSaveLevelBackup")
  -- delete existent /main folder because some objects do not exist anymore and will remain rogue
  --TODO: must delete all files one by one, FS:directoryRemove will not delete non emtpy folders
  -- it should be done selectively, since deleting all might affect repository commits
  local path = editor.levelPath .. "main"
  local backupPath = "/settings/editor/backups/" .. editor.getLevelName() .. "/main"
  copyDirectory(path, backupPath)
  editor.log("Saving level backup: " .. path)
  extensions.hook("onEditorAfterSaveLevelBackup")
  editor.showNotification("Level backup saved also")
end

--- Save the current level data. There must be a level opened. This function will call the Save As if the level is unnamed.
local function saveLevel()
  extensions.hook("onEditorBeforeSaveLevel")
  -- delete existent /main folder because some objects do not exist anymore and will remain rogue
  --TODO: must delete all files one by one, FS:directoryRemove will not delete non emtpy folders
  -- it should be done selectively, since deleting all might affect repository commits
  FS:directoryRemove(editor.levelPath .. "/main")
  editor.log("Saving level: " .. editor.levelPath .. "/main")
  -- only the mission group is saved to drive
  Sim.serializeObjectToDirectories("MissionGroup", editor.levelPath .. "/main", editor.orderTable)
  extensions.hook("onEditorAfterSaveLevel")
  editor.newLevelCreated = false
  editor.resetDirty()
  editor.setPreference("general.internal.levelWasSaved", true)
  editor.showNotification("Level saved")
  if not editor.autosavingNow and editor.getPreference("files.autoSave.saveBackupCopy") then
    saveLevelBackup()
  end
end

-- Save the level's scene tree to the specified path.
local function saveLevelAs(levelPath)
  editor.levelPath = levelPath
  setMissionFilename(levelPath .. "info.json")
  editor.saveLevel()
end

--- Save a copy of the level's scene tree to an autosave folder
local function autoSaveLevel()
  if editor.getLevelName() == "" or not editor.getLevelName() then return end
  local oldLevelPath = editor.levelPath
  local folderName
  local oldDirty = editor.dirty
  editor.dirty = true

  if editor.getPreference("files.autoSave.counter") > editor.getPreference("files.autoSave.maxAutoSaveCountPerSession") then
    editor.setPreference("files.autoSave.counter", 1)
  end

  local counter = editor.getPreference("files.autoSave.counter")

  folderName = string.format("%04d", counter)
  local path = "/settings/editor/autosaves/" .. editor.getLevelName() .. "/" .. folderName
  editor.autosavingNow = true
  saveLevelAs(path)
  editor.autosavingNow = false
  editor.levelPath = oldLevelPath
  setMissionFilename(editor.levelPath .. "/info.json")
  counter = counter + 1
  editor.setPreference("files.autoSave.counter", counter)
  editor.dirty = oldDirty
end

--- Set the editor state to dirty, level needs to be saved.
local function setDirty()
  editor.dirty = true
  editor.needsCollisionRebuild = true
  if editor.getPreference("general.internal.cleanExit") then
    editor.setPreference("general.internal.cleanExit", false)
  end
  local levelPath = editor.getLevelPath()
  if editor.getPreference("general.internal.lastLevel") ~= levelPath then
    editor.setPreference("general.internal.lastLevel", levelPath)
  end
end

--- Set the editor state to clean, no need to save it.
local function resetDirty()
  editor.dirty = false
  worldEditorCppApi.clearSceneDirtyFlag()
  editor.setPreference("general.internal.cleanExit", true)
end

--- Hides and deactivates the editor.
local function quitEditor()
  editor.setEditorActive(false)
end

--- Quit the actual game.
local function quitGame()
  quit()
end

--- Delete an object by its id.
local function deleteObject(objectId)
  local obj = Sim.findObjectById(objectId)
  if obj and not obj:isLocked() then
    obj:deleteObject()
    editor.setDirty()
    return true
  end
  return false
end

--- Undo the last operation(s).
-- @param steps the number of undo steps to be performed, if omitted, then this is 1
local function undo(steps)
  editor.history:undo(steps)
end

--- Redo (revert the last undo steps) the last operation(s).
-- @param steps the number of redo steps to be performed, if omitted, then this is 1
local function redo(steps)
  editor.history:redo(steps)
end

--- Allows the user to change the current history table instance.
-- This is useful for context aware undo, for example if the editor uses multiple windows/panes and when switching editing actions back and forth, each window/pane should keep its own undo context to allow proper undo/redo operation.
-- @param history the history table instance to be used from now on. If this is nil then the default history will be used.
local function setUndoHistory(history)
  if not history then
    editor.history = editor.defaultHistory
  else
    editor.history = history
  end
end

--- Clears the current undo history (along with redo information), basically acting like a collapse of operations. From this moment all the past operations are irreversible.
local function clearUndoHistory()
  editor.history:clear()
end

--- Set a visualization type's status on or off.
-- @param name the name of the type, allowed values can be found using [editor.getVisualizationTypes()][{{editor.getVisualizationTypes()}}]
-- @param on true to activate the vizualization
local function setVisualizationType(name, on)
  for _, type in ipairs(visualizationTypes) do
    if type.name == name then
      if type.type == varTypes.ConVar then
        setConsoleVariable(name, on and "1" or "0")
      elseif type.type == varTypes.LuaVar then
        local f = loadstring(type.name .. " = " .. tostring(on))
        f()
      elseif type.type == varTypes.Custom then
        type.setter(on)
      elseif type.type == varTypes.Setting then
        settings.setValue(type.name, on)
      end
      if type.callback then type.callback() end
      return
    end
  end
end

--- Return a visualization type current value.
-- @param name the vizualization's name
-- @return true if the vizualization is active
local function getVisualizationType(name)
  for _, type in ipairs(visualizationTypes) do
    if type.name == name then
      if type.type == varTypes.ConVar then
        return getConsoleVariable(name) == "1"
      elseif type.type == varTypes.LuaVar then
        local f = loadstring("return " .. type.name)
        return f()
      elseif type.type == varTypes.Custom then
        return type.getter()
      elseif type.type == varTypes.Setting then
        return settings.getValue(type.name)
      end
    end
  end
end

--- Returns the available visualization types. You can add custom ones adding an item to ``editor.registerVisualizationType(...)``
local function getVisualizationTypes()
  if visualizationTypesSortNeeded then
    visualizationTypesSortNeeded = false
    table.sort(visualizationTypes, function(a, b) return a.displayName < b.displayName end)
  end
  return visualizationTypes
end

--- Add a new user visualization type.
-- @param typeData the visualization type info
local function registerVisualizationType(typeData)
  table.insert(visualizationTypes, typeData)
  visualizationTypesSortNeeded = true
end

local function clearVisualizationTypes()
  visualizationTypes = {}
end

--- Set the object type visibility.
-- @param typeName the name of the C++ object class/type to be visible
-- @param visible true/false for class visibility
local function setObjectTypeVisible(typeName, visible)
  worldEditorCppApi.setClassIsRenderable(typeName, visible)
end

---Returns true/false for class visibility
-- Get the object type visibility.
-- @param typeName the name of the C++ object class/type
local function getObjectTypeVisible(typeName)
  return worldEditorCppApi.getClassIsRenderable(typeName)
end

--- Set a certain object type from being editable/selectable.
-- @param typeName the name of the C++ object class/type
-- @param selectable true/false for class selectability
local function setObjectTypeSelectable(typeName, selectable)
  worldEditorCppApi.setClassIsSelectable(typeName, selectable)
end

--- Return true if object type is editable/selectable.
-- @param typeName the name of the C++ object class/type
local function getObjectTypeSelectable(typeName)
  return worldEditorCppApi.getClassIsSelectable(typeName)
end

--- Select the current edit mode
-- @param mode the edit mode table, with the fields:
--  **displayName** - the display name shown in the title bar for the current edit mode, example: "Edit Terrain"
--  **onActivate** - a function called when the edit mode gets selected, optional
--  **onDeactivate** - a function called when the edit mode gets deselected, optional
--  **onUpdate** - a function called when the edit mode needs to update/check internal state
--  **onCut** - a function called when the edit mode is required to cut the selection, optional
--  **onCopy** - a function called when the edit mode is required to copy the selection, optional
--  **onPaste** - a function called when the edit mode is required to paste the selection, optional
--  **onDuplicate** - a function called when the edit mode is required to duplicate(clone) the selection, optional
--  **onSelectAll** - a function called when the edit mode is required to select all items, optional
--  **onDeselect** - a function called when the edit mode is required to deselect the selection, optional
--  **onDeleteSelection** - a function called when the edit mode is required to delete the selected items, optional
--  **onToolbar** - a function called when the edit mode is selected and it needs to render icon buttons in the vertical edit mode toolbar, optional
--  **actionMap** - an action map for the input, which will be pushed to the action map stack when the edit mode is selected, optional
--  **icon** - an icon for the edit mode, you can find the icons in the editor.icons table, if nil, no toolbar button will be shown in the edit modes toolbar
--  **iconTooltip** - a tooltip for the button in the edit modes toolbar, optional
local function selectEditMode(newEditMode)
  local oldEditMode = editor.editMode
  -- we should check if there was an edit mode selected before, default is nil
  if oldEditMode then
    if oldEditMode.onDeactivate then
      oldEditMode.onDeactivate()
    end
  end

  -- show object icons again (maybe they were hidden)
  editor.hideObjectIcons = false
  editor.editMode = newEditMode

  if newEditMode then
    if newEditMode.onActivate then
      newEditMode.onActivate()
    end
    if newEditMode.hideObjectIcons then
      -- hide object icons
      editor.hideObjectIcons = true
    end
  end

  if oldEditMode and oldEditMode.actionMap then
    popActionMap(oldEditMode.actionMap)
  end

  if newEditMode and newEditMode.actionMap then
    pushActionMapHighestPriority(newEditMode.actionMap)
  end

  extensions.hook("onEditorEditModeChanged", oldEditMode, newEditMode)
end

--- Returns the current edit mode name, from the key name of the editMode table
local function getCurrentEditModeName()
  for key, val in pairs(editor.editModes) do
    if val == editor.editMode then return key end
  end
  return ""
end

--- Cut the current selection. The cut action is routed to the current edit mode, calling its ``onCut()`` callback, see `Edit Modes`.
-- The global extension hook ``onEditorCut`` will also be invoked, which can be used by other tools if they're in focus and don't have edit modes registered.
local function cut()
  if editor.editMode and editor.editMode.onCut then
    editor.editMode.onCut()
  end
  extensions.hook("onEditorCut")
end

--- Copy the current selection. The copy action is routed to the current edit mode, calling its ``onCopy()`` callback, see `Edit Modes`.
-- The global extension hook ``onEditorCopy`` will also be invoked, which can be used by other tools if they're in focus and don't have edit modes registered.
local function copy()
  if editor.editMode and editor.editMode.onCopy then
    editor.editMode.onCopy()
  end
  extensions.hook("onEditorCopy")
end

--- Paste the current selection. The paste action is routed to the current edit mode, calling its ``onPaste()`` callback, see `Edit Modes`.
-- The global extension hook ``onEditorPaste`` will also be invoked, which can be used by other tools if they're in focus and don't have edit modes registered.
local function paste()
  if editor.editMode and editor.editMode.onPaste then
    editor.editMode.onPaste()
  end
  extensions.hook("onEditorPaste")
end

--- Duplicate the current selection. The duplicate action is routed to the current edit mode, calling its ``onDuplicate()`` callback, see `Edit Modes`.
-- The global extension hook ``onEditorDuplicate`` will also be invoked, which can be used by other tools if they're in focus and don't have edit modes registered.
local function duplicate()
  if editor.editMode and editor.editMode.onDuplicate then
    editor.editMode.onDuplicate()
  end
  extensions.hook("onEditorDuplicate")
end

--- Select all items. The select all action is routed to the current edit mode, calling its ``onSelectAll()`` callback, see `Edit Modes`.
-- The global extension hook ``onEditorSelectAll`` will also be invoked, which can be used by other tools if they're in focus and don't have edit modes registered.
local function selectAll()
  if editor.editMode and editor.editMode.onSelectAll then
    editor.editMode.onSelectAll()
  end
  extensions.hook("onEditorSelectAll")
end

--- Deselect the current selection. The deselect action is routed to the current edit mode, calling its ``onDeselect()`` callback, see `Edit Modes`.
-- The global extension hook ``onEditorDeselect`` will also be invoked, which can be used by other tools if they're in focus and don't have edit modes registered.
local function deselect()
  if editor.editMode and editor.editMode.onDeselect then
    editor.editMode.onDeselect()
  end
  extensions.hook("onEditorDeselect")
end

--- Delete the items in the current selection. The delete selection action is routed to the current edit mode, calling its ``onDeleteSelection()`` callback, see `Edit Modes`.
-- The global extension hook ``onEditorDeleteSelection`` will also be invoked, which can be used by other tools if they're in focus and don't have edit modes registered.
local function deleteSelection()
  if editor.editMode and editor.editMode.onDeleteSelection then
    editor.editMode.onDeleteSelection()
  end
  extensions.hook("onEditorDeleteSelection")
  editor.selection = {}
end

--- Return the current level name.
local function getLevelName()
  local levelPath, levelName, _ = path.split(getMissionFilename())
  if levelPath then
    return string.match(levelPath,'.*/(.+)/')
  end
  return ""
end

--- Return the current level path.
local function getLevelPath()
  local levelPath, _, _ = path.split(getMissionFilename())
  return levelPath or ""
end

--- Used by editor UI to do new level, complete with all the open dialog
local function doNewLevel()
  editor_fileDialog.openFile(function(data)
    if data.path ~= "" then
      local path = data.path
      if path == nil or path == "" then return end
      -- copy the template level to the new level folder
      copyLevelFolder("levels/template/", path)
      editor.newLevel()
      editor.openLevel(path)
    end
  end, {{"All Folders","*"}}, true, "/levels")
end

--- Used by editor UI to open a level, complete with open file dialog
local function doOpenLevel()
  editor_fileDialog.openFile(function(data)
    if data.path ~= "" then
      local path = data.path
      if path == nil or path == "" then return end
      editor.openLevel(path .. "/")
    end
  end, {{"All Folders","*"}}, true, "/levels")
end

--- Used by editor UI to save level, will ask for folder is no level path was set
local function doSaveLevel()
  -- if this is a new level
  if editor.levelPath == "" then
    editor.doSaveLevelAs()
  else
    editor.saveLevel()
  end
end

--- Used by editor UI to save a level into another folder, as a new level, complete with open folder dialog
local function doSaveLevelAs()
  editor_fileDialog.openFile(function(data)
    if data.path ~= "" then
      local newPath = data.path
      if newPath == nil or newPath == "" then return end
      -- first copy all the files from current level folder to new one
      newPath = sanitizePath(newPath)
      if newPath == "/levels" or newPath == "/levels/" then
        editor.logError("Cannot save as directly into /levels folder, you need to specify a subfolder")
        messageBox("World Editor - Save As", "Cannot save as directly into /levels folder, you need to specify a subfolder", 0, 0)
      else
        editor.copyLevelFolder(editor.levelPath, newPath)
        editor.saveLevelAs(newPath)
        messageBox("World Editor - Save As", "The new level folder data was copied, you need to manually fix issues with remaining paths inside various files, where needed", 0, 0)
      end
    end
  end, {{"All Folders","*"}}, true, "/levels")
end

local function enableHeadless(enabled, toolName)
  if enabled then
    -- first, we save the current window layout so we dont lose it
    editor_layoutManager.saveCurrentWindowLayout()
  else
    -- save the tool's window layout
    editor_layoutManager.saveCurrentWindowLayout(toolName)

    -- restore back the current main editor layout
    editor_layoutManager.loadCurrentWindowLayout()
  end

  editor.headless = enabled
  editor.headlessToolName = toolName
  extensions.hook("onEditorHeadlessChange", enabled, toolName)
  if enabled then
    -- then, we load our custom layout (if it exists), else nothing loaded
    editor_layoutManager.loadCurrentWindowLayout(toolName)
    --editor_layoutManager.loadWindowLayout("settings/editor/layouts/" .. toolName)
  end
end

local function isHeadlessToolActive(toolName)
  return editor.headlessToolName == toolName and editor.headless == true
end

local function initialize(editorInstance)
  editor = editorInstance
  -- constants
  editor.FloatMin = -1000000000
  editor.FloatMax = 1000000000
  editor.IntMin = -2147483648
  editor.IntMax = 2147483647
  -- control flags for edit mode auxShortcuts field
  editor.AuxControl_Ctrl = blshift(1, 0)
  editor.AuxControl_Shift = blshift(1, 1)
  editor.AuxControl_Alt = blshift(1, 2)
  editor.AuxControl_LCtrl = blshift(1, 3)
  editor.AuxControl_RCtrl = blshift(1, 4)
  editor.AuxControl_LAlt = blshift(1, 5)
  editor.AuxControl_RAlt = blshift(1, 6)
  editor.AuxControl_LShift = blshift(1, 7)
  editor.AuxControl_RShift = blshift(1, 8)
  editor.AuxControl_MWheel = blshift(1, 9)
  editor.AuxControl_LMB = blshift(1, 10)
  editor.AuxControl_MMB = blshift(1, 11)
  editor.AuxControl_RMB = blshift(1, 12)
  editor.AuxControl_Copy = blshift(1, 13)
  editor.AuxControl_Paste = blshift(1, 14)
  editor.AuxControl_Duplicate = blshift(1, 15)
  editor.AuxControl_Delete = blshift(1, 16)
  editor.AuxControl_Cut = blshift(1, 17)

  -- variables
  editor.defaultHistory = require("editor/api/history")()
  editor.history = editor.defaultHistory
  editor.history.onUndo = function(action) if editor.showNotification then editor.showNotification("Undo: " .. action.name) end end
  editor.levelPath = ""
  editor.dirty = false
  editor.editModes = {}
  editor.editMode = nil
  editor.selection = {}
  editor.username = "anonymous" --TODO: when editing, user can set a username in the editor settings, used for logs and visual bug reporting
  editor.userId = 0

  -- functions
  editor.newLevel = newLevel
  editor.openLevel = openLevel
  editor.saveLevel = saveLevel
  editor.saveLevelAs = saveLevelAs
  editor.setDirty = setDirty
  editor.resetDirty = resetDirty
  editor.autoSaveLevel = autoSaveLevel
  editor.quitEditor = quitEditor
  editor.quitGame = quitGame
  editor.getDeltaTime = function() return imgui.GetIO().DeltaTime end
  editor.deleteObject = deleteObject
  editor.undo = undo
  editor.redo = redo
  editor.setUndoHistory = setUndoHistory
  editor.clearUndoHistory = clearUndoHistory
  editor.registerVisualizationType = registerVisualizationType
  editor.setVisualizationType = setVisualizationType
  editor.getVisualizationType = getVisualizationType
  editor.getVisualizationTypes = getVisualizationTypes
  editor.clearVisualizationTypes = clearVisualizationTypes
  editor.setObjectTypeVisible = setObjectTypeVisible
  editor.getObjectTypeVisible = getObjectTypeVisible
  editor.setObjectTypeSelectable = setObjectTypeSelectable
  editor.getObjectTypeSelectable = getObjectTypeSelectable
  editor.selectEditMode = selectEditMode
  editor.getCurrentEditModeName = getCurrentEditModeName
  editor.cut = cut
  editor.copy = copy
  editor.paste = paste
  editor.duplicate = duplicate
  editor.selectAll = selectAll
  editor.deselect = deselect
  editor.deleteSelection = deleteSelection
  editor.getLevelName = getLevelName
  editor.getLevelPath = getLevelPath
  editor.doNewLevel = doNewLevel
  editor.doOpenLevel = doOpenLevel
  editor.doSaveLevel = doSaveLevel
  editor.doSaveLevelAs = doSaveLevelAs
  editor.varTypes = varTypes
  editor.copyDirectory = copyDirectory
  editor.copyLevelFolder = copyLevelFolder
  editor.enableHeadless = enableHeadless
  editor.isHeadlessToolActive = isHeadlessToolActive
end

local M = {}
M.initialize = initialize

return M