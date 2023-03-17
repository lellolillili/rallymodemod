-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--- you can use this to turn of Just In Time compilation for debugging purposes:
--jit.off()

local M = {}

-- make the editor a global accessible reference
-- global already defined in ge/main.lua
editor = M
local ffi = require('ffi')
local imgui = ui_imgui
local imguiUtils = require('ui/imguiUtils')

M.dependencies = {"core_camera"}

local timeExtensionsInit = false
local editorPreferencesPath = "settings/editor/preferences.json"
local editorCurrentStatePath = "settings/editor/currentState.json"
local editorExtensionsSettingsPath = "settings/editor/extensions.json"
local editorLuaReloaded = false
local editorWasActive = false
local editorWasHeadless = false
local editorHeadlessToolName = ""
local cefWasVisible = true
local editorWasDirty = false
local editorHistoryData = {}
local lastEditModeName = ""
local CurrentStateFileFormatVersion = 1

M.initialized = false
M.active = false
M.safeMode = false
M.extensionNames = {}
M.allExtensionNames = {}
M.additionalActionMaps = {}
M.preferencesRegistry = require("editor/api/preferencesRegistry")()

-- if this is nil, then any editor extension is allowed to load
-- we do not load editor_main, since its in the same folder with all editor extensions
local disallowedExtensions = {"editor_main"} -- we dont want editor main, already loaded and is treated differently
local safeModeExtensionNames = {"editor_extensionsEditor", "editor_fileDialog", "editor_newsMessage", "editor_worldEditorHelper", "editor_createObjectTool", "editor_extensionsDebug", "editor_autoSave", "editor_gizmoHelper", "editor_logHelper", "editor_mainMenu", "editor_mainToolbar", "editor_mainUpdate", "editor_preferences", "editor_objectTool", "editor_sceneTree", "editor_inspector", "editor_layoutManager"}
local vehicleActionMaps = {"VehicleCommonActionMap", "VehicleSpecificActionMap"}
local auxExtensionsSubfolders = {"vehicleEditor"}

local function editorLog(msg)
  log("I", "editor", msg)
end

local function editorLogDebug(msg)
  log("D", "editor", msg)
end

local function editorLogError(msg)
  log("E", "editor", msg)
end

local function editorLogWarn(msg)
  log("W", "editor", msg)
end

local function setPreference(path, value)
  return M.preferencesRegistry:set(path, value)
end

local function getPreference(path)
  return M.preferencesRegistry:get(path)
end

local function loadPreferences()
  M.preferencesRegistry:loadPreferences(editorPreferencesPath)
  M.setPreference = setPreference
  M.getPreference = getPreference
  M.preferencesRegistry:migratePreferences()
end

local function savePreferences()
  M.preferencesRegistry:savePreferences(editorPreferencesPath)
end

local function loadExtensionsSettings()
  M.extensionsSettings = jsonReadFile(editorExtensionsSettingsPath) or {}
end

local function saveExtensionsSettings()
  jsonWriteFile(editorExtensionsSettingsPath, M.extensionsSettings, true)
end

local function isFileAnEditorExtension(path)
  local f = io.open(path, "r")
  local content = f:read("*all")
  f:close()

  -- any M function with onEditor or onExtension prefix is an editor extension
  if content:find("M.onEditor") or content:find("M.onExtension") then return true end

  return false
end

local function loadAllEditorExtensions()
  loadExtensionsSettings()
  local extensionFiles = FS:findFiles('/lua/ge/extensions/editor/', '*.lua', 0, false, false)

  M.extensionNames = {}
  M.allExtensionNames = {}
  for _, filename in ipairs(extensionFiles) do
    if isFileAnEditorExtension(filename) then
      local name = string.gsub(filename, "(.*/)(.*)/(.*)%.lua", "%3")
      local extName = "editor_" .. name
      local allowLoad = true

      table.insert(M.allExtensionNames, name)

      if M.safeMode and not tableContains(safeModeExtensionNames, extName) then
        allowLoad = false
      else
        if tableContains(disallowedExtensions, extName) then
          allowLoad = false
        end
        if M.extensionsSettings then
          if M.extensionsSettings[name] ~= nil and M.extensionsSettings[name].disabled then
            allowLoad = false
            editor.logWarn("Skipping disabled extension: " .. extName)
          end
        end
      end

      if allowLoad then table.insert(M.extensionNames, extName) end
    end
  end
  M.log("Loading editor extensions...")
  extensions.load(M.extensionNames)
  M.log("Done.")
end

local function loadEditorExtension(name)
  extensions.load(name)
  if extensions.isExtensionLoaded(name) then
    table.insert(M.extensionNames, name)
    if extensions[name].onEditorRegisterPreferences then
      extensions[name].onEditorRegisterPreferences(editor.preferencesRegistry)
      -- save the current prefs
      editor.savePreferences()
      -- reload them again to have the new loaded extension access them too
      editor.loadPreferences()
      editor.updatePreferencePages()
    end
    if extensions[name].onEditorRegisterApi then
      extensions[name].onEditorRegisterApi()
    end
    if extensions[name].onEditorInitialized then
      extensions[name].onEditorInitialized()
    end
    if extensions[name].onEditorActivated then
      extensions[name].onEditorActivated()
    end
    if not editor.preferencesRegistry.dontCallHookForSetValue then
      -- set value to trigger new extension to update its pref related data
      editor.preferencesRegistry:callHookForSetValue()
    end
    return rawget(extensions, name)
  end

  return nil
end

local function loadEditorExtensions(names)
  for _, name in ipairs(names) do
    extensions.load(name)
    if extensions.isExtensionLoaded(name) then
      table.insert(M.extensionNames, name)
      if extensions[name].onEditorRegisterPreferences then
        extensions[name].onEditorRegisterPreferences(editor.preferencesRegistry)
      end
    end
  end

  -- save the current prefs
  editor.savePreferences()
  -- reload them again to have the new loaded extension access them too
  editor.loadPreferences()
  editor.updatePreferencePages()

  for _, name in ipairs(names) do
    if extensions[name].onEditorRegisterApi then
      extensions[name].onEditorRegisterApi()
    end
    if extensions[name].onEditorInitialized then
      extensions[name].onEditorInitialized()
    end
    if extensions[name].onEditorActivated then
      extensions[name].onEditorActivated()
    end
  end
  if not editor.preferencesRegistry.dontCallHookForSetValue then
    -- set value to trigger new extension to update its pref related data
    editor.preferencesRegistry:callHookForSetValue()
  end
end

local function unloadEditorExtensions()
  M.log("Unloading " .. tableSize(M.extensionNames) .. " editor extensions...")
  for _, name in ipairs(M.extensionNames) do
    extensions.unload(name)
  end
  M.extensionNames = {}
end

local function unloadEditorExtension(extName)
  for i, name in ipairs(M.extensionNames) do
    if extName == name then
      table.remove(M.extensionNames, i)
      if extensions[name].onEditorDeactivated then
        extensions[name].onEditorDeactivated()
      end
      if extensions[name].onEditorShutdown then
        extensions[name].onEditorShutdown()
      end
      extensions.unload(name)
      break
    end
  end
end

local mapsEnabledStateBefore = {}
local function pushVehicleActionMapsEnabled()
  for _, mapName in ipairs(vehicleActionMaps) do
    local map = scenetree.findObject(mapName)
    if map then
      mapsEnabledStateBefore[mapName] = map.enabled
      map:setEnabled(editor.getPreference("ui.general.enableVehicleControls"))
    end
  end
end

local function popVehicleActionMapsEnabled()
  for _, mapName in ipairs(vehicleActionMaps) do
    if mapsEnabledStateBefore[mapName] ~= nil then
      local map = scenetree.findObject(mapName)
      if map then
        map:setEnabled(mapsEnabledStateBefore[mapName])
      end
    end
  end
  mapsEnabledStateBefore = {}
end

local function initializeEditorExtensions()
  local timer = hptimer()

  -- clear the prefs registry, extensions will add new fresh ones
  M.preferencesRegistry:clear()

  -- first allow extensions to register their preferences
  for _, val in ipairs(M.extensionNames) do
    if extensions.isExtensionLoaded(val) and extensions[val].onEditorRegisterPreferences then
      extensions[val].onEditorRegisterPreferences(editor.preferencesRegistry)
    end
  end

  -- load preference values so they will be available in the onEditorInitialized for extensions
  M.loadPreferences()

  -- init extensions
  editor.logDebug("Initializing editor extensions...")
  extensions.hook("onEditorRegisterApi")

  if timeExtensionsInit then
    timer:stopAndReset()
    for _, val in ipairs(M.extensionNames) do
      if extensions.isExtensionLoaded(val) and extensions[val].onEditorInitialized then
        extensions[val].onEditorInitialized()
        local dt = timer:stopAndReset()
        editor.logInfo("Initialized " .. val .. " in " .. dt .. "ms")
      end
    end

  else
    extensions.hook("onEditorInitialized")
  end

  -- call this before the action maps are enabled/disabled by onEditorPreferenceValueChanged
  pushVehicleActionMapsEnabled()

  -- this will call the onEditorPreferenceValueChanged for all preferences
  -- client code might setup various things in the engine using those values
  M.preferencesRegistry:callHookForSetValue()
end

local function initializeModules()
  if M.modulesInitialized then return end
  log('I', "editor", "Initializing editor modules...")
  M.guiModule = require("editor/api/gui")
  M.coreModule = require("editor/api/core")
  M.assetsModule = require("editor/api/assets")
  M.cameraModule = require("editor/api/camera")
  M.dataBlockModule = require("editor/api/dataBlock")
  M.decalModule = require("editor/api/decal")
  M.gizmoModule = require("editor/api/gizmo")
  M.materialModule = require("editor/api/material")
  M.navigationModule = require("editor/api/navigation")
  M.objectModule = require("editor/api/object")
  M.roadRiverModule = require("editor/api/roadRiver")
  M.sketchModule = require("editor/api/sketch")
  M.terrainModule = require("editor/api/terrain")
  M.forestModule = require("editor/api/forest")

  M.guiModule.initialize(M)
  M.coreModule.initialize(M)
  M.assetsModule.initialize(M)
  M.cameraModule.initialize(M)
  M.dataBlockModule.initialize(M)
  M.decalModule.initialize(M)
  M.gizmoModule.initialize(M)
  M.materialModule.initialize(M)
  M.navigationModule.initialize(M)
  M.objectModule.initialize(M)
  M.roadRiverModule.initialize(M)
  M.sketchModule.initialize(M)
  M.terrainModule.initialize(M)
  M.forestModule.initialize(M)

  M.modulesInitialized = true
  extensions.hook("onEditorModulesInitialized")
end

local function loadAndInitializeExtensions()
  unloadEditorExtensions()
  loadAllEditorExtensions()
  initializeEditorExtensions()
end

local function setSelectedObjectFlags(enable)
  if not editor.selection or not editor.selection.object then
    return
  end
  -- clear selected objects flags
  for _, objId in ipairs(editor.selection.object) do
    local obj = scenetree.findObjectById(objId)
    if obj then obj:setSelected(enable) end
  end
end

local function enableEditingMode(enable)
  worldEditorCppApi.enableEditor(enable)
  M.enableEditorOnObjects(enable)
end

local function saveState(filePath)
  -- do not save state if we did not used the editor in this session
  if not editor.initialized then return end
  editor.logDebug("Saving editor state...")
  local state = {}
  state.version = CurrentStateFileFormatVersion
  editorWasActive = M.active
  lastEditModeName = editor.getCurrentEditModeName()
  extensions.hook("onEditorSaveState", state)
  jsonWriteFile(filePath or editorCurrentStatePath, state, true)
end

local function loadState(filePath)
  editor.logDebug("Loading editor state...")
  local state = readJsonFile(filePath or editorCurrentStatePath) or {}

  if state.version ~= CurrentStateFileFormatVersion and not tableIsEmpty(state) then
    editor.logWarn("Editor state file format version mismatch. Expected: " .. CurrentStateFileFormatVersion .. " File: " .. tostring(state.version) .. ", will upgrade.")
    --TODO: upgrade code for older versions of the file
  end
  return state
end

local function getSmoothCameraParams()
  local cam = commands.getFreeCamera()
  if cam then
    return {
      newtonMode = cam.newtonMode,
      newtonRotation = cam.newtonRotation,
      mass = cam.mass,
      drag = cam.drag,
      force = cam.force,
      angularDrag = cam.angularDrag,
      angularForce = cam.angularForce
    }
  end
end

local function setEditorActiveInternal(activate, safeMode)
  local wasInitedNow = false

  if activate and safeMode == true then
    log("I", "editor", "Editor starting in SAFE MODE...")
  end

  if (safeMode or (not safeMode and M.safeMode == true)) then
    extensions.hook("onEditorShutdown")
    unloadEditorExtensions()
    M.active = false
    M.initialized = false
  end

  M.safeMode = safeMode

  -- we clear any editing mode, because previous extenstion handling it might not be loaded in safe mode
  if safeMode then
    lastEditModeName = nil
  end

  -- if we activate, init the editor modules if not yet first time inited
  if activate and not M.initialized then
    initializeModules()
  end

  -- save the smooth camera params, before our preferences are loaded and extensions inited
  local smoothCameraParams = getSmoothCameraParams()

  -- if activate, and not editor inited
  if activate and not M.initialized then
    local state = loadState()
    loadAndInitializeExtensions()
    editor.loadWindowsState()
    extensions.hook("onEditorLoadState", state)
    wasInitedNow = true
    M.initialized = true
  end

  if #M.extensionNames == 0 then return end

  local activated = M.active

  M.active = activate

  --
  -- ACTIVATE
  --
  if activate and not activated then
    editor.logInfo("Activating editor...")
    editor.savedSmoothCameraParams = smoothCameraParams
    cefWasVisible = extensions.ui_visibility.getCef()
    extensions.ui_visibility.setCef(false)
    extensions.ui_visibility.setImgui(true)
    if not wasInitedNow then
      pushVehicleActionMapsEnabled()
    end

    enableEditingMode(true)
    setSelectedObjectFlags(true)
    editor.isGameFreeCamera = commands.isFreeCamera()

    M.selectCamera(editor.CameraType_Free)

    if not wasInitedNow then
      local state = loadState()
      editor.loadWindowsState()
      extensions.hook("onEditorLoadState", state)
    end

    extensions.hook("onEditorActivated")
    pushActionMapHighestPriority("Editor")
    pushActionMapHighestPriority("EditorKeyMods")

    -- let the key modifiers pass through, for mouse and other keys
    local amap = scenetree.findObject("EditorKeyModsActionMap")
    if amap then amap.trapHandledEvents = false end

    editor.callShowWindowHookForVisibleWindows()
    editor.levelPath = editor.getLevelPath()

    -- select default edit mode if none set
    if lastEditModeName ~= "" and lastEditModeName ~= nil then
      editor.selectEditMode(editor.editModes[lastEditModeName])
    end

    if editor.editMode == nil then
      editor.selectEditMode(editor.editModes.objectSelect)
    end

    if editorLuaReloaded then
      editor.dirty = editorWasDirty
      editorLuaReloaded = false
    end

    editor.setSmoothCameraMove(editor.getPreference("camera.general.smoothCameraMove"))
    editor.setSmoothCameraRotate(editor.getPreference("camera.general.smoothCameraRotate"))
    editor.setSmoothCameraDragNormalized(editor.getPreference("camera.general.freeCameraMoveSmoothness"))
    editor.setSmoothCameraAngularDragNormalized(editor.getPreference("camera.general.freeCameraRotateSmoothness"))
    local freeCam = scenetree.findObject("freeCamera")
    if freeCam then
      worldEditorCppApi.hideIconForObject(freeCam)
    end

    if editorWasHeadless then
      editor.enableHeadless(true, editorHeadlessToolName)
      editorWasHeadless = false
    end
  else
    if activated and not activate then
    --
    -- DEACTIVATE
    --
      editor.logInfo("Deactivating editor...")
      editor.defocusFocusedWindow()
      enableEditingMode(false)
      editor.rebuildCollision()
      M.savePreferences()
      -- save windows state only when not in headless mode
      if not editor.headless then
        editor.saveWindowsState()
      end
      saveState()
      if not editor.headless then
        editor.hideAllWindows()
      end
      lastEditModeName = editor.getCurrentEditModeName()
      editor.selectEditMode(nil)
      setSelectedObjectFlags(false)
      extensions.hook("onEditorDeactivated")
      popActionMap("EditorKeyMods")
      popActionMap("Editor")
      --TODO: remove this, if we'll use the disable action maps on editor open strategy
      for _, actionMap in ipairs(M.additionalActionMaps) do
        popActionMap(actionMap)
      end
      extensions.ui_visibility.setCef(cefWasVisible)
      popVehicleActionMapsEnabled()
      -- restore smooth camera params, for example if photomode was opened
      editor.setSmoothCameraParams(editor.savedSmoothCameraParams)

      editorWasHeadless = editor.headless
      editorHeadlessToolName = editor.headlessToolName

      if editorWasHeadless then
        editor.enableHeadless(false, editorHeadlessToolName)
      end
    end
  end
end

local frameCount = 0
local doActivate = false
local toggleEditorActive = false
local wantSafeMode = false

local function setEditorActive(activate, safeMode)
  toggleEditorActive = true
  frameCount = 0
  doActivate = activate
  wantSafeMode = safeMode
end

local function isEditorActive()
  return M.active
end

local function shutdown()
  if not M.initialized then return end
  setEditorActive(false)
  extensions.hook("onEditorShutdown")
  unloadEditorExtensions()
  M.active = false
  M.initialized = false
end

local function onClientStartMission()
  editor.initialized = false
  editor.modulesInitialized = false
  setEditorActive(M.active)
end

local function onPreWindowClose()
  if editor.dirty and editor.initialized then
    local result = messageBox("World Editor - Exiting BeamNG.drive", "You have edited this level.\nDo you want to save your changes made to this level ?", 4, 2)
    if result == 1 then
      editor.saveLevel()
    elseif result == 2 then
      Engine.cancelShutdown()
    end
  end
end

local function onClientEndMission()
  saveState()
  guihooks.trigger('ShowApps', true)
  shutdown()
end

local function onUpdate()
  -- if there is a toggle editor request
  if toggleEditorActive then
    -- on first request frame, show the loading popup
    if frameCount < 1 then
      -- show it only we want to activate editor
      if doActivate then
        local pos = imgui.ImVec2(imgui.GetMainViewport().Pos.x + imgui.GetMainViewport().Size.x / 2, imgui.GetMainViewport().Pos.y + imgui.GetMainViewport().Size.y / 2)
        imgui.SetNextWindowPos(pos, imgui.Cond_Appearing, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(300, 55))
        imgui.Begin("loadingEditorWnd", nil, imgui.WindowFlags_NoTitleBar + imgui.WindowFlags_NoResize + imgui.WindowFlags_NoMove)
        imgui.PushFont3("cairo_semibold_large")
        imgui.Separator()
        imgui.Text("\t\t\tLoading World Editor...")
        imgui.Separator()
        imgui.PopFont()
        imgui.End()
      end
      frameCount = frameCount + 1
    else
      -- actual editor toggling after first frame of the toggling request
      toggleEditorActive = false
      frameCount = 0
      setEditorActiveInternal(doActivate, wantSafeMode)
    end
  end
end

local function toggleActive(safeMode)
  setEditorActive(not M.active, safeMode)
end

local function onExit()
  editor.active = false
  editor.saveState()
end

local function onExtensionLoaded()
end

local function onExtensionUnloaded()
  editor.shutdown()
end

local function onSerialize()
  local data = {}

  if editor.matrixToTable then
    data.cameraTransform = editor.matrixToTable(getCameraTransform())
  end

  data.active = editor.active
  data.dirty = editor.dirty
  data.headless = editor.headless
  data.headlessToolName = editor.headlessToolName

  if editor.history then
    --TODO: objects need serializable formats not C++ object refs
    --editor.history:serialize(data)
  end

  if editor.active then
    data.editModeName = editor.getCurrentEditModeName()
    saveState()
    if editor.saveWindowsState then
      if editor.headless then
        data.headlessToolName = editor.headlessToolName
      else
        editor.saveWindowsState()
      end
    end
  else
    data.editModeName = lastEditModeName
  end

  setSelectedObjectFlags(false)

  if editor.setPreference then
    editor.setPreference("general.internal.cleanExit", true)
    editor.savePreferences()
  end

  editor.setEditorActive(false)

  return data
end

local function onDeserialized(data)
  editor_main.serializedData = data
  editorHistoryData.history = {}
  if data.history then
    editorHistoryData.history = data.history
  end
  editorWasActive = data.active
  editorWasDirty = data.dirty
  editorWasHeadless = data.headless
  editorHeadlessToolName = data.headlessToolName
  lastEditModeName = data.editModeName or ""
  editorLuaReloaded = true
end

local function onFirstUpdate()
  if editorWasActive then
    editor.logInfo("Reactivating editor...")
    editor.active = false
    setEditorActive(true)
    --TODO: objects need serializable formats not C++ object refs
    --editor.history:deserialize(editorHistoryData)
  end
end

M.log = editorLog
M.logDebug = editorLogDebug
M.logError = editorLogError
M.logWarn = editorLogWarn
M.logInfo = editorLog
M.initializeModules = initializeModules
M.toggleActive = toggleActive
M.setEditorActive = setEditorActive
M.isEditorActive = isEditorActive
M.saveState = saveState
M.loadState = loadState
M.savePreferences = savePreferences
M.loadPreferences = loadPreferences
M.loadExtensionsSettings = loadExtensionsSettings
M.saveExtensionsSettings = saveExtensionsSettings
M.loadEditorExtension = loadEditorExtension
M.loadEditorExtensions = loadEditorExtensions
M.unloadEditorExtension = unloadEditorExtension
M.shutdown = shutdown
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onExit = onExit
M.onPreWindowClose = onPreWindowClose
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onFirstUpdate = onFirstUpdate
M.onUpdate = onUpdate

return M