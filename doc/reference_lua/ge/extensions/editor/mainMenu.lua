-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_main_menu'
M.dependencies = {"editor_layoutManager"}
local ffi = require('ffi')
local imgui = ui_imgui
local imgui_true = ffi.new("bool", true)
local imgui_false = ffi.new("bool", false)
local drawGizmoPlane = imgui.BoolPtr(true)
local smoothCameraMove = imgui.BoolPtr(false)
local smoothCameraRotate = imgui.BoolPtr(false)
local opened = imgui.BoolPtr(true)
local displaySceneMetric = imgui.BoolPtr(true)
local showCompleteSceneTree = imgui.BoolPtr(false)

local defaultWindowMenuItems = {}
local defaultWindowMenuGroups = {}
local windowMenuItems = {}
local windowMenuGroups = {}

local metrics = {}
local metricsTim = 0

local bor = bit.bor
local notificationShowTime = 4 -- seconds, total time to show a notification
local notificationFadeTime = 1 -- seconds, time amount from total time when notification is fading
local forceShowNewest = true -- if true this will hide the current showing notification and show the newest one (valid for one liner title text notification)
local aboutDlgName = "aboutDlg"
local safeModeDlgName = "safeModeDlg"
local openSafeModePopup = false
local saveLayoutWindowName = "saveLayoutWindow"
local saveLayoutWindowTitle = "Save Layout"
local deleteLayoutWindowName = "deleteLayoutWindow"
local deleteLayoutWindowTitle = "Delete Layout"
local resetLayoutsWindowName = "resetLayoutsWindow"
local resetLayoutsWindowTitle = "Reset Layouts"
local revertLevelToOriginalWindowName = "revertLevelWindow"
local revertLevelToOriginalWindowTitle = "Revert Level to Original"
local showRevertLevelToOriginalButton = false
local fpsSmoother = newExponentialSmoothing(50, 1)
local windowSearch = require('/lua/ge/extensions/editor/util/searchUtil')()
local windowSearchTxt = imgui.ArrayChar(256, "")
local windowSearchDisplayResult = false
local windowSearchResults = {}

local function rebuildCollision(force)
  if force or editor.needsCollisionRebuild then
    log("I", "", "Rebuilding Static Collision Data...")
    be:reloadCollision()
    editor.needsCollisionRebuild = false
    editor.showNotification("Rebuilt Static Collision Data")
  end
end

--- Add a new notification to the queue. It will override any notification in the same group (if present).
-- @param text the text of the notification
-- @param icon the icon (from editor.icons.*) to be shown next to the text (optional)
-- @param group the group name of this notification, it will override any current notification shown for this group (optional)
-- @param duration duration in seconds to show the notification, otherwise a default value will be used (optional)
local function showNotification(text, icon, group, duration)
  local notification = {
    time = 0,
    text = text,
    icon = icon or editor.icons.info,
    group = group or "",
    duration = duration or notificationShowTime
  }

  table.insert(editor.notificationQueue, notification)

  -- TODO: remove when notifications will be small floating windows
  if forceShowNewest then
    editor.currentNotificationIndex = tableSize(editor.notificationQueue)
  end

  --TODO: trim to maxNotificationCount
end

local function updateNotifications()
  -- if no index and no notifications, exit
  if editor.currentNotificationIndex == 0 and tableIsEmpty(editor.notificationQueue) then return end
  -- if all notifications were shown and the last one was also shown
  if editor.currentNotificationIndex == 0
    and (not tableIsEmpty(editor.notificationQueue))
    and editor.notificationQueue[tableSize(editor.notificationQueue)].time > editor.notificationQueue[tableSize(editor.notificationQueue)].duration then return end

  if editor.currentNotificationIndex == 0 then editor.currentNotificationIndex = tableSize(editor.notificationQueue) end

  local notification = editor.notificationQueue[editor.currentNotificationIndex]

  if notification.time > notification.duration then
    editor.currentNotificationIndex = editor.currentNotificationIndex + 1
    if editor.currentNotificationIndex > tableSize(editor.notificationQueue) then editor.currentNotificationIndex = 0 return end
  end

  notification.time = notification.time + editor.getDeltaTime()
end

local function renderLoginMenuItem()
  if not editor_auth then return end
  local loggedIn = editor_auth.isLoggedIn()

  if loggedIn then
    if imgui.MenuItem1("Logout", nil, imgui_false, imgui_true) then
      editor_auth.logOut()
    end
  elseif imgui.MenuItem1("Login...", nil, imgui_false, imgui_true) then
    editor_auth.openWindow()
  end
end

local function fileMenu()
  if imgui.BeginMenu("File", imgui_true) then
    if imgui.MenuItem1("New Level", "Ctrl+N", imgui_false, imgui_true) then
      editor.doNewLevel()
    end
    if imgui.MenuItem1("Open Level...", "Ctrl+O", imgui_false, imgui_true) then
      editor.doOpenLevel()
    end
    imgui.Separator()
    if imgui.MenuItem1("Save Level", "Ctrl+S", imgui_false, imgui_true) then
      editor.doSaveLevel()
    end
    --TODO: Save As disabled because issues with replacing old level paths to new copied level path/name
    -- in all of the assets json. Will be added after a proper asset system is in place
    -- if imgui.MenuItem1("Save Level As...", "Ctrl+Shift+S", imgui_false, imgui_true) then
    --   editor.doSaveLevelAs()
    -- end
    if editor.getLevelPath() ~= "" and showRevertLevelToOriginalButton then
      if imgui.MenuItem1("Revert Level to Original Content", "", imgui_false, imgui_true) then
        editor.showWindow(revertLevelToOriginalWindowName)
      end
    end
    imgui.Separator()
    if imgui.MenuItem1("Export Selected as Collada", "", imgui_false, imgui_true) then
      editor_fileDialog.saveFile(
        function(data)
          worldEditorCppApi.colladaExportSelection(data.filepath)
        end,
        {{"Collada file",".dae"}},
        false,
        "/",
        "File already exists.\nDo you want to overwrite the file?"
      )
    end
    imgui.Separator()
    renderLoginMenuItem()
    if imgui.MenuItem1("Exit Editor", "F11", imgui_false, imgui_true) then
      editor.toggleActive()
    end
    imgui.EndMenu()
  end

  if editor.beginWindow(revertLevelToOriginalWindowName, revertLevelToOriginalWindowTitle) then
    imgui.Text("Are you sure you want to revert current level to original content?")
    imgui.TextColored(imgui.ImVec4(1, 1, 0, 1), "Warning: You will lose all your changes to the level!")
    if imgui.Button("Yes") then
      editor.hideWindow(revertLevelToOriginalWindowName)
      FS:directoryRemove(editor.getLevelPath())
      editor.openLevel(editor.getLevelPath())
    end
    imgui.SameLine()
    if imgui.Button("No") then
      editor.hideWindow(revertLevelToOriginalWindowName)
    end
  end
  editor.endWindow()
end

local function editMenu()
  if imgui.BeginMenu("Edit", imgui_true) then
    if imgui.MenuItem1("Undo", "Ctrl+Z", imgui_false, imgui_true) then
      editor.undo()
    end
    if imgui.MenuItem1("Redo", "Ctrl+Y", imgui_false, imgui_true) then
      editor.redo()
    end
    imgui.Separator()
    if imgui.MenuItem1("Cut", "Ctrl+X", imgui_false, imgui_true) then
      editor.cut()
    end
    if imgui.MenuItem1("Copy", "Ctrl+C", imgui_false, imgui_true) then
      editor.copy()
    end
    if imgui.MenuItem1("Paste", "Ctrl+V", imgui_false, imgui_true) then
      editor.paste()
    end
    if imgui.MenuItem1("Duplicate", "Ctrl+D", imgui_false, imgui_true) then
      editor.duplicate()
    end
    imgui.Separator()
    if imgui.MenuItem1("Select All", "Ctrl+A", imgui_false, imgui_true) then
      editor.selectAll()
    end
    if imgui.MenuItem1("Deselect", "X", imgui_false, imgui_true) then
      editor.deselect()
    end
    if imgui.MenuItem1("Delete Selection", "Delete", imgui_false, imgui_true) then
      editor.deleteSelection()
    end
    imgui.Separator()
    if imgui.MenuItem1("Rebuild Collision", "Ctrl+F7") then
      -- we force the rebuild
      editor.rebuildCollision(true)
    end
    if imgui.MenuItem1("Reload Navgraph") then
      if map then
        log("I", "", "Reloading Navgraph Data...")
        map.reset()
      end
    end
    imgui.Separator()
    if imgui.MenuItem1("Editor Preferences...", nil, imgui_false, imgui_true) then
      editor.showPreferences()
    end
    imgui.EndMenu()
  end
end

local function cameraMenu()
  if imgui.BeginMenu("Camera", imgui_true) then
    if imgui.MenuItem1("Game Camera", "Ctrl+1", imgui_false, imgui_true) then
      editor.selectCamera(editor.CameraType_Game)
      if editor.getCamera() then editor.getCamera():setValidEditOrbitPoint(false) end
    end
    if imgui.MenuItem1("Free Camera", "Ctrl+2", imgui_false, imgui_true) then
      editor.selectCamera(editor.CameraType_Free)
      if editor.getCamera() then editor.getCamera():setValidEditOrbitPoint(false) end
    end
    if imgui.MenuItem1("Toggle Free Camera", "Shift+C", imgui_false, imgui_true) then
      editor.toggleFreeCamera()
    end
    if imgui.MenuItem1("Place Camera at Selection", "Ctrl+Q", imgui_false, imgui_true) then
      editor.placeCameraAtSelection()
    end
    if imgui.MenuItem1("Place Camera at Player", "Alt+Q", imgui_false, imgui_true) then
      editor.placeCameraAtPlayer()
    end
    if imgui.MenuItem1("Place Player at Camera", "Alt+W", imgui_false, imgui_true) then
      editor.placePlayerAtCamera()
    end
    if imgui.MenuItem1("Fit View to Selection", "F", imgui_false, imgui_true) then
      editor.fitViewToSelectionSmooth()
    end
    imgui.Separator()
    smoothCameraMove[0] = editor.getPreference("camera.general.smoothCameraMove")
    if imgui.Checkbox('Smooth Camera Movement', smoothCameraMove) then
      editor.setPreference("camera.general.smoothCameraMove", smoothCameraMove[0])
    end
    smoothCameraRotate[0] = editor.getPreference("camera.general.smoothCameraRotate")
    if imgui.Checkbox('Smooth Camera Rotation', smoothCameraRotate) then
      editor.setPreference("camera.general.smoothCameraRotate", smoothCameraRotate[0])
    end
    imgui.EndMenu()
  end
end

local function objectMenu()
  if imgui.BeginMenu("Object", imgui_true) then
    if imgui.MenuItem1("Lock Selection", "Ctrl+Alt+L", imgui_false, imgui_true) then
      editor.lockObjectSelection()
    end
    if imgui.MenuItem1("Unlock Selection", "Ctrl+Shift+L", imgui_false, imgui_true) then
      editor.unlockObjectSelection()
    end
    imgui.Separator()
    if imgui.MenuItem1("Hide Selection", "Ctrl+H", imgui_false, imgui_true) then
      editor.hideObjectSelection()
    end
    if imgui.MenuItem1("Show Selection", "Ctrl+Shift+H", imgui_false, imgui_true) then
      editor.showObjectSelection()
    end
    imgui.Separator()

    if imgui.BeginMenu("Align Bounds", imgui_true) then
      if imgui.MenuItem1("-X Axis") then
        editor.alignObjectSelectionByBounds(0)
      end
      if imgui.MenuItem1("+X Axis") then
        editor.alignObjectSelectionByBounds(1)
      end
      if imgui.MenuItem1("-Y Axis") then
        editor.alignObjectSelectionByBounds(2)
      end
      if imgui.MenuItem1("+Y Axis") then
        editor.alignObjectSelectionByBounds(3)
      end
      if imgui.MenuItem1("-Z Axis") then
        editor.alignObjectSelectionByBounds(4)
      end
      if imgui.MenuItem1("+Z Axis") then
        editor.alignObjectSelectionByBounds(5)
      end
      imgui.EndMenu()
    end

    if imgui.BeginMenu("Align Center", nil, imgui_false, imgui_true) then
      if imgui.MenuItem1("X Axis") then
        editor.alignObjectSelectionByCenter(0)
      end
      if imgui.MenuItem1("Y Axis") then
        editor.alignObjectSelectionByCenter(1)
      end
      if imgui.MenuItem1("Z Axis") then
        editor.alignObjectSelectionByCenter(2)
      end
      imgui.EndMenu()
    end

    if imgui.MenuItem1("Set Selection Transform from Camera", "", imgui_false, imgui_true) then
      editor.setObjectSelectionTransformFromCamera()
    end

    imgui.Separator()
    if imgui.MenuItem1("Reset Selected Transforms", "Ctrl+Alt+R", imgui_false, imgui_true) then
      editor.resetObjectSelectionTransform()
    end
    if imgui.MenuItem1("Reset Selected Rotations", "Ctrl+Shift+R", imgui_false, imgui_true) then
      editor.resetObjectSelectionRotation()
    end
    if imgui.MenuItem1("Reset Selected Scale", nil, imgui_false, imgui_true) then
      editor.resetObjectSelectionScale()
    end
    imgui.EndMenu()
  end
end

local function windowMenu()
  if imgui.BeginMenu("Window", imgui_true) then
    local menuGenerator = function(menuGroups, menuItems)
        for _, item in ipairs(menuItems) do
          if item.isGroup then
            if imgui.BeginMenu(item.itemText, imgui_true) then
              for _, subitem in ipairs(menuGroups[item.itemText]) do
                if imgui.MenuItem1(subitem.itemText, nil, imgui_false, imgui_true) then
                  if subitem.actionFunc then subitem.actionFunc() end
                end
              end
              imgui.EndMenu()
            end
          else
            if imgui.MenuItem1(item.itemText, nil, imgui_false, imgui_true) then
              if item.actionFunc then item.actionFunc() end
            end
          end
        end
      end
    if editor.uiInputSearch(nil, windowSearchTxt, 240 * editor.getPreference("ui.general.scale")) then
      local s = ffi.string(windowSearchTxt)
      windowSearchDisplayResult = s:len() > 0
      if windowSearchDisplayResult then
        local addToSearch = function(menuGroups, menuItems)
          for _, item in ipairs(menuItems) do
            if item.isGroup then
              for _, subitem in ipairs(menuGroups[item.itemText]) do
                local entry = shallowcopy(subitem)
                entry.name = item.itemText.." > "..subitem.itemText
                entry.score = 1
                windowSearch:queryElement(entry)
              end
            else
              local entry = shallowcopy(item)
              entry.name = entry.itemText
              entry.score = 1
              windowSearch:queryElement(entry)
            end
          end
        end
        windowSearch:startSearch(s)
        addToSearch(defaultWindowMenuGroups, defaultWindowMenuItems)
        addToSearch(windowMenuGroups, windowMenuItems)
        windowSearchResults = windowSearch:finishSearch()
      end

    end
    imgui.Separator()

    if windowSearchDisplayResult then
      for _, item in ipairs(windowSearchResults) do
        if imgui.MenuItem1(item.name, nil, imgui_false, imgui_true) then
          ffi.fill(windowSearchTxt, ffi.sizeof(windowSearchTxt))
          windowSearchDisplayResult = false
          if item.actionFunc then item.actionFunc() end
        end
      end
    else
      menuGenerator(defaultWindowMenuGroups, defaultWindowMenuItems)
      imgui.Separator()
      menuGenerator(windowMenuGroups, windowMenuItems)
    end

    imgui.EndMenu()
  end
end

local function helpMenu()
  if imgui.BeginMenu("Help", imgui_true) then
    if imgui.MenuItem1("Editor Documentation...", "F1", imgui_false, imgui_true) then
      editor.openHelp()
    end
    if imgui.MenuItem1("Editor Coding Documentation...", nil, imgui_false, imgui_true) then
      editor.openCodingHelp()
    end
    if imgui.MenuItem1("News/Release Notes", nil, imgui_false, imgui_true) then
      editor.setPreference("newsMessage.general.newsMessageShown", false)
    end
    if imgui.MenuItem1("About", nil, imgui_false, imgui_true) then
      editor.openModalWindow(aboutDlgName)
    end
    imgui.EndMenu()
  end
end

local saveLayoutWindow = imgui.BoolPtr(false)
local deleteLayoutWindow = imgui.BoolPtr(false)
local resetLayoutsWindow = imgui.BoolPtr(false)
local layoutName = imgui.ArrayChar(128)

local function viewMenu()
  if imgui.BeginMenu("View", imgui_true) then
    drawGizmoPlane[0] = editor.getPreference("gizmos.general.drawGizmoPlane")
    if imgui.Checkbox('Draw Gizmo Plane', drawGizmoPlane) then
      editor.setPreference("gizmos.general.drawGizmoPlane", drawGizmoPlane[0])
      if drawGizmoPlane[0] then
        worldEditorCppApi.setAxisGizmoRenderPlane(true)
        worldEditorCppApi.setAxisGizmoRenderPlaneHashes(true)
        worldEditorCppApi.setAxisGizmoRenderMoveGrid(true)
      else
        worldEditorCppApi.setAxisGizmoRenderPlane(false)
        worldEditorCppApi.setAxisGizmoRenderPlaneHashes(false)
        worldEditorCppApi.setAxisGizmoRenderMoveGrid(false)
      end
    end

    displaySceneMetric[0] = editor.getPreference("ui.general.sceneMetric")
    if imgui.Checkbox('Display Scene Metric', displaySceneMetric) then
      editor.setPreference("ui.general.sceneMetric", displaySceneMetric[0])
    end

    showCompleteSceneTree[0] = editor.getPreference("ui.general.showCompleteSceneTree")
    if imgui.Checkbox('Show Complete Scene Tree', showCompleteSceneTree) then
      editor.setPreference("ui.general.showCompleteSceneTree", showCompleteSceneTree[0])
    end

    if imgui.BeginMenu("Layouts", imgui_true) then
      for _, layoutPath in ipairs(editor_layoutManager.getWindowLayouts()) do
        if imgui.MenuItem1(string.match(layoutPath, ".+/(.+)"), nil, imgui_false, imgui_true) then
          editor_layoutManager.loadWindowLayout(layoutPath)
        end
      end

      imgui.Separator()
      if imgui.MenuItem1("Save Layout...", nil, imgui_false, imgui_true) then
        editor.showWindow(saveLayoutWindowName)
      end
      if imgui.MenuItem1("Delete Layout...", nil, imgui_false, imgui_true) then
        editor.showWindow(deleteLayoutWindowName)
      end
      if imgui.MenuItem1("Revert to Factory Settings...", nil, imgui_false, imgui_true) then
        editor.showWindow(resetLayoutsWindowName)
      end
      imgui.EndMenu()
    end

    if imgui.MenuItem1("Visualization Settings...") then
      editor.showWindow("visualization")
    end
    imgui.EndMenu()
  end

  if editor.beginWindow(saveLayoutWindowName, saveLayoutWindowTitle) then
    imgui.PushItemWidth(imgui.GetContentRegionAvailWidth())
      if imgui.InputText("##SaveLayout", layoutName, 128, imgui.InputTextFlags_EnterReturnsTrue) then
        editor.hideWindow(saveLayoutWindowName)
        editor_layoutManager.saveWindowLayout(ffi.string(layoutName))
      end
      if imgui.Button("Save") then
        editor.hideWindow(saveLayoutWindowName)
        editor_layoutManager.saveWindowLayout(ffi.string(layoutName))
      end
  end
  editor.endWindow()

  if editor.beginWindow(deleteLayoutWindowName, deleteLayoutWindowTitle) then
    for _, layoutPath in ipairs(editor_layoutManager.getWindowLayouts()) do
      if imgui.MenuItem1(string.match(layoutPath, ".+/(.+)"), nil, imgui_false, imgui_true) then
        editor_layoutManager.deleteWindowLayout(layoutPath)
      end
    end
  end
  editor.endWindow()

  if editor.beginWindow(resetLayoutsWindowName, resetLayoutsWindowTitle) then
    imgui.Text("This will delete all window layouts files and set the Default factory layout.")
    if imgui.Button("Continue") then
      editor.hideWindow(resetLayoutsWindowName)
      editor_layoutManager.resetLayouts()
    end
    imgui.SameLine()
    if imgui.Button("Cancel") then
      editor.hideWindow(resetLayoutsWindowName)
    end
  end
  editor.endWindow()
end

local function editorTitleGui()
  local windowSize = imgui.GetWindowContentRegionMax()
  extensions.hook("onEditorMainMenuBar", windowSize)
end

local function editorLevelTitleGui()
  imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.7, 1), "\tLevel: ")
  local str = "<none>"
  local modified = ""
  if editor.dirty then modified = "*" end
  imgui.TextColored(imgui.GetStyleColorVec4(imgui.Col_ButtonActive), "[" .. getMissionFilename() .. "]" .. modified)
end

local function notificationsGui()
  updateNotifications()
  if editor.currentNotificationIndex == 0 then return end
  local notification = editor.notificationQueue[editor.currentNotificationIndex]
  local textAlpha = 1

  if notification.time > notification.duration - notificationFadeTime then
    textAlpha = 1 - notification.time / notification.duration
  end

  imgui.TextColored(imgui.ImVec4(1, 1, 0, textAlpha), "\t"..notification.text)
end

local function currentEditModeGui()
  imgui.TextColored(imgui.ImVec4(0.7, 0.7, 0.7, 1.0), "\tEditMode: ")
  local str = "<none>"
  if editor.editMode then str = tostring(editor.editMode.displayName or editor.editMode.iconTooltip or "Unknown") end
  imgui.TextColored(imgui.GetStyleColorVec4(imgui.Col_ButtonActive), str)
end

--- Sets the current status bar text and optional UI. The status bar will be visible only when the text is non empty.
-- @param text the text shown in the status bar
-- @param uiCallback a function that will render additional imgui UI elements (progress bars, buttons etc), make sure to use imgui.SameLine() between them. (optional callback)
local function setStatusBar(text, uiCallback)
  editor.statusText = text
  editor.statusBarUiCallback = uiCallback
end

--- Hides the status bar. Please always use this function after your operation was completed.
local function hideStatusBar()
  editor.statusText = nil
  editor.statusBarUiCallback = nil
end

local function statusBarGui()
  if editor.statusText and editor.statusText ~= "" then
    local winbounds = imgui.GetMainViewport()
    --TODO: cannot properly position status bar window, needs precise values. It will break on UI scale other than 1
    imgui.SetNextWindowPos(imgui.ImVec2(winbounds.Pos.x + 15, winbounds.Pos.y + winbounds.Size.y - imgui.GetTextLineHeight()*3), imgui.Cond_Always)
    imgui.Begin("StatusBar", opened,
      bor(imgui.WindowFlags_NoTitleBar, imgui.WindowFlags_NoResize, imgui.WindowFlags_NoMove,
       imgui.WindowFlags_NoScrollbar, imgui.WindowFlags_AlwaysAutoResize, imgui.WindowFlags_NoBringToFrontOnFocus,
      imgui.WindowFlags_NoFocusOnAppearing, imgui.WindowFlags_NoNavFocus, imgui.WindowFlags_NoNavInputs,
      imgui.WindowFlags_NoNav))
    imgui.TextColored(imgui.ImVec4(1, 1, 0, 1), editor.statusText)
    imgui.SameLine()
    if editor.statusBarUiCallback then editor.statusBarUiCallback() end
    imgui.End()
  end
end

local function sceneMetric()
  local io = imgui.GetIO()
  local fps = fpsSmoother:get(io.Framerate)

  local txtSize = imgui.CalcTextSize("FPS: 999 ").y + imgui.CalcTextSize("GpuWait: 00.0f ").y + imgui.CalcTextSize("Poly: 123456789").y
  imgui.SetCursorPosX(imgui.GetCursorPosX() + imgui.GetContentRegionAvailWidth() - txtSize*4)

  if fps < 30 then
    imgui.TextColored(imgui.ImVec4(1, 0.3, 0.3, 1), "FPS: %.0f", fps)
  elseif fps < 60 then
    imgui.TextColored(imgui.ImVec4(1, 1, 0.2, 1), "FPS: %.0f", fps)
  else
    imgui.Text("FPS: %.0f", fps)
  end

  if metricsTim < Engine.Platform.getRuntime() -0.5 then
    metricsTim = Engine.Platform.getRuntime()
    Engine.Debug.getLastPerformanceMetrics(metrics)
  end
  if metrics["framePresentDelay"] < 0.3 then
    imgui.Text("GpuWait: %.1f", metrics["framePresentDelay"])
  elseif metrics["framePresentDelay"] < 1 or fps > 30 then
    imgui.TextColored(imgui.ImVec4(1, 1, 0.2, 1), "GpuWait: %3.1f", metrics["framePresentDelay"])
  else
    imgui.TextColored(imgui.ImVec4(1, 0.3, 0.3, 1), "GpuWait: %3.1f", metrics["framePresentDelay"])
  end
  imgui.Text("Poly: "..getConsoleVariable("$GFXDeviceStatistics::polyCount"))
end

local function onEditorGuiMainMenu()
  if editor.safeMode then
    imgui.PushStyleColor1(imgui.Col_MenuBarBg, imgui.GetColorU322(imgui.ImVec4(0.3,0,0,1)))
  end

  if editor.headless then
    extensions.hook("onEditorHeadlessMainMenuBar", windowSize)
    return
  else
  if imgui.BeginMainMenuBar() then
    fileMenu()
    editMenu()
    cameraMenu()
    objectMenu()
    viewMenu()
    windowMenu()
    helpMenu()
    editor.menuHeight = imgui.GetWindowHeight()
    if editor.safeMode == true then
      editor.uiTextColoredWithFont(imgui.ImVec4(1, 0, 0, 1), "[ S A F E   M O D E ]", "cairo_bold")
    end
    editorLevelTitleGui()
    currentEditModeGui()
    editorTitleGui()
    notificationsGui()
    statusBarGui()
    if displaySceneMetric[0] then
      sceneMetric()
    end
    imgui.EndMainMenuBar()
    if editor.safeMode then
      imgui.PopStyleColor()
    end
    if openSafeModePopup then editor.openModalWindow(safeModeDlgName) openSafeModePopup = false end
    if editor.beginModalWindow(safeModeDlgName, "Safe Mode", imgui.WindowFlags_AlwaysAutoResize + imgui.WindowFlags_NoScrollbar) then
      imgui.Text(
        [[

You have opened the World Editor in Safe Mode.

Safe Mode only loads the bare minimum and many apps/features will be missing.

        ]])

      if imgui.Button("OK", imgui.ImVec2(120, 0)) then editor.closeModalWindow(safeModeDlgName) end
    end
    editor.endModalWindow()

    if editor.beginModalWindow(aboutDlgName, "About Editor", imgui.WindowFlags_AlwaysAutoResize + imgui.WindowFlags_NoScrollbar) then
      imgui.Text(
        [[

BeamNG.drive ]] .. beamng_versionb .. [[ World Editor (level editor)

The editor is used to edit and create new content/levels for the game.
        ]])
      if imgui.Button("OK", imgui.ImVec2(120, 0)) then editor.closeModalWindow(aboutDlgName) end
    end
    editor.endModalWindow()
  end
  end
end

--- Add a new item in the main menu's `Window`.
-- if defaultToolWindow is true, then this is a window that opens by default in the editor, like Inspector and Scene Tree
-- and they will appear at the top of the Window menu, separated at the bottom with a menu separator, by other tool windows
-- @param itemText the text for the tools menu item
-- @param func the callback function called when the item is clicked
-- @param info [table] with info about this window menu item, with the following fields:
-- @param experimental [boolean] the extension tool is experimental if true, and it will be added to the Experimental submenu
-- @param gameplay [boolean] if true, then this extension tool will be shown on the gameplay Window menu (reduced editor, for gameplay only), but when full editor is on, it will also be visible in the Window menu
-- @param defaultToolWindow [boolean] if true, then this menu item will be shown at the top of the Window menu
local function addWindowMenuItem(itemText, actionFunc, info, defaultToolWindow)
  local item = {itemText = itemText, actionFunc = actionFunc, info = info}
  local menuGroups
  local menuItems

  -- if this item is a default window, we keep them on top
  if defaultToolWindow then
    menuGroups = defaultWindowMenuGroups
    menuItems = defaultWindowMenuItems
  else
    menuGroups = windowMenuGroups
    menuItems = windowMenuItems
  end

  if info then
    if info.groupMenuName then
      -- insert into custom group (create group if not existing)
      if nil == menuGroups[info.groupMenuName] then
        menuGroups[info.groupMenuName] = {}
        table.insert(menuItems, {isGroup = true, itemText = info.groupMenuName})
      end
      table.insert(menuGroups[info.groupMenuName], item)
      table.sort(menuGroups[info.groupMenuName], function(a, b) return a.itemText < b.itemText end)
    end
  else
    table.insert(menuItems, item)
  end

  table.sort(menuItems, function(a, b) return a.itemText < b.itemText end)
end

local function onExtensionLoaded()
  defaultWindowMenuItems = {}
  defaultWindowMenuGroups = {}
  windowMenuItems = {}
  windowMenuGroups = {}

  editor.notificationQueue = {}
  editor.maxNotificationCount = 100 -- how many notification messages to keep in the queue to be viewed
  editor.currentNotificationIndex = 0

  editor.addWindowMenuItem = addWindowMenuItem
  editor.showNotification = showNotification
  editor.setStatusBar = setStatusBar
  editor.hideStatusBar = hideStatusBar
  editor.rebuildCollision = rebuildCollision
end

local function onEditorActivated()
  worldEditorCppApi.setAxisGizmoRenderPlane(editor.getPreference("gizmos.general.drawGizmoPlane"))
  worldEditorCppApi.setAxisGizmoRenderPlaneHashes(editor.getPreference("gizmos.general.drawGizmoPlane"))
  worldEditorCppApi.setAxisGizmoRenderMoveGrid(editor.getPreference("gizmos.general.drawGizmoPlane"))
end

local function onEditorInitialized()
  editor.registerWindow(saveLayoutWindowName, imgui.ImVec2(200, 100))
  editor.registerWindow(deleteLayoutWindowName, imgui.ImVec2(200, 100))
  editor.registerWindow(resetLayoutsWindowName, imgui.ImVec2(200, 100))
  editor.registerWindow(revertLevelToOriginalWindowName, imgui.ImVec2(300, 100))
  editor.registerModalWindow(aboutDlgName, nil, nil, true)
  editor.registerModalWindow(safeModeDlgName, nil, nil, true)

  local openSafeModePopupJob = function(job)
    job.sleep(1)
    openSafeModePopup = true
  end
  if editor.safeMode then
    --core_jobsystem.create(openSafeModePopupJob)
    openSafeModePopup = true
  end

  local isModLevel = false
  local levelName = core_levels.getLevelName(getMissionFilename())
  if levelName then
    local unpackedModsList = FS:findFiles( "/mods/unpacked/", "*", 0, false, true )
    for _, modPath in ipairs(unpackedModsList) do
      if FS:directoryExists(modPath.."/levels/"..levelName) and not FS:fileExists(modPath.."/levels/"..levelName) then
        isModLevel = true
        break
      end
    end
  end

  if (editor.getLevelPath() ~= "" and isOfficialContentVPath(editor.getLevelPath()) or isModLevel) then
    showRevertLevelToOriginalButton = true
  end
end

local function onEditorPreferenceValueChanged(path, value)
  if path == "ui.general.sceneMetric" then displaySceneMetric[0] = value end
end

M.onEditorGuiMainMenu = onEditorGuiMainMenu
M.onExtensionLoaded = onExtensionLoaded
M.onEditorActivated = onEditorActivated
M.onEditorInitialized = onEditorInitialized
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged

return M