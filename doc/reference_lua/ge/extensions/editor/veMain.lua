-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'core_vehicle_manager'}

local ffi = require("ffi")
local im = ui_imgui
M.menuItems = {items = {}}
local editorName = "vehicleEditor"

local veViewSettingsDefaultFilePath = "settings/vehicleEditor/veViewSettingsDefault.json"
local utils = {}
local _vEditor = M
local imgui_true = ffi.new("bool", true)
local imgui_false = ffi.new("bool", false)
local initialized = false
local fpsSmoother = newExponentialSmoothing(50, 1)

local metrics = {}
local metricsTim = 0

rawset(_G, 'vEditor', _vEditor)

vEditor.MODE_DEFAULT = 1
vEditor.MODE_PICKING_NODE = 2
vEditor.MODE_PICKING_BEAM = 3

vEditor.mode = vEditor.MODE_DEFAULT

vEditor.selectedNodes = {}
vEditor.selectedBeams = {}

vEditor.veluaData = {}

vEditor.vehicle = nil
vEditor.vehiclePos = nil
vEditor.vehicleNodesPos = nil
vEditor.vehdata = nil
vEditor.vdata = nil

local saveLayoutWindowName = "saveLayoutWindow"
local saveLayoutWindowTitle = "Save Layout"
local deleteLayoutWindowName = "deleteLayoutWindow"
local deleteLayoutWindowTitle = "Delete Layout"
local resetLayoutsWindowName = "resetLayoutsWindow"
local resetLayoutsWindowTitle = "Reset Layouts"


vEditor.changeMode = function (mode)
  table.clear(vEditor.selectedNodes)
  table.clear(vEditor.selectedBeams)
  vEditor.mode = mode
end

local function createMenu(subItems)
  for _, item in pairs(subItems) do
    if item.group then
      if im.BeginMenu(item.group) then
        createMenu(item.items)
        im.EndMenu()
      end
    else
      if im.MenuItem1(item.menuEntry) then
        item.menuOpen()
      end
    end
  end
end

local function generateTable(str, open)
  local temp = M.menuItems
  local list = {}
  -- Converts directory string into table of directories seperated
  -- e.g. "foo/bar/baz" -> {"foo", "bar", "baz"}
  for p in string.gmatch(str, "%s*%a+[%s%a+]*") do
    table.insert(list, p)
  end

  for k = 1, #list do
    local currGroup = list[k]

    if k < #list then
      local groupKey = nil

      for k,v in ipairs(temp.items) do
        if v.group == currGroup then
          groupKey = k
          break
        end
      end

      if not groupKey then
        groupKey = #temp.items + 1
        temp.items[groupKey] = {group = currGroup, items = {}}
      end

      local new = temp.items[groupKey]
      temp = new

    else
      temp.items[#temp.items + 1] = {menuEntry = currGroup, menuOpen = open}
    end
  end

  return M.menuItems
end

local function loadExtensions()
  local extNames = {}
  local luaFiles = FS:findFiles("/lua/ge/extensions/editor/vehicleEditor/", "ve*.lua", 0, false, false)

  for _, file in ipairs(luaFiles) do
    local _, fn, _ = path.split(file)
    local name = string.sub(fn, 1, -5)
    if name ~= "veMain" and not tableFindKey(utils, name) then
      table.insert(extNames, "editor_vehicleEditor_" .. name)
    end
  end

  editor.loadEditorExtensions(extNames)

  return extNames
end

local function createMenuItems(extNames)
  local entries = {}

  for _, name in ipairs(extNames) do
    local ext = extensions[name]

    if ext and ext.menuEntry and type(ext.open) == "function" and type(ext.menuEntry) == "string" then
      entries[ext.menuEntry] = ext.open
    end
  end

  local sortedEntries = tableKeysSorted(entries)

  for _, extMenuEntry in ipairs(sortedEntries) do
    local extOpen = entries[extMenuEntry]
    M.menuItems = generateTable(extMenuEntry, extOpen)
  end
end

local function setupEditor()
  if not initialized then
    local extNames = loadExtensions()
    createMenuItems(extNames)
    initialized = true
  end

  editor.selectEditMode(nil)
  editor.clearObjectSelection()
  editor.hideObjectIcons = true

  --popActionMap("EditorKeyMods")
  popActionMap("Editor")
end

local function initVehicleData(id)
  local vehData = core_vehicle_manager.getVehicleData(id)
  vEditor.vehData = vehData
  vEditor.vdata = vehData and vehData.vdata or nil

  vEditor.vehicle = be:getObjectByID(id)
  if vEditor.vehicle then
    vEditor.vehiclePos = vec3()
    vEditor.vehicleNodeCount = vEditor.vehicle:getNodeCount()
    vEditor.vehicleNodesPos = table.new(vEditor.vehicleNodeCount, 0)
    for i = 0, vEditor.vehicleNodeCount do
      vEditor.vehicleNodesPos[i] = vec3()
    end
  end
end

-- Update data for other vehicle editors to use
local function onPreRender(dtReal, dtSim, dtRaw)
  if not vEditor.vehicle then
    initVehicleData(be:getPlayerVehicleID(0))
    return
  end

  local vehData = core_vehicle_manager.getPlayerVehicleData()
  vEditor.vehData = vehData
  vEditor.vdata = vehData and vehData.vdata or nil

  if vEditor.vehicle then
    vEditor.vehiclePos:set(vEditor.vehicle:getPositionXYZ())

    -- Update vehicle node positions table
    for i = 0, vEditor.vehicleNodeCount do
      local nodePos = vEditor.vehicleNodesPos[i]

      nodePos:set(vEditor.vehicle:getNodePositionXYZ(i))
      nodePos:setAdd(vEditor.vehiclePos)
    end
  end

  extensions.hook("onVehicleEditorRenderJBeams", dtReal, dtSim, dtRaw)
end

local function onWindowMenuItem()
  -- enable the headless mode (hides menu, toolbars etc.)
  editor.enableHeadless(true, editorName)

  setupEditor()
end

local function onEditorInitialized()
  editor.addWindowMenuItem("Vehicle Editor", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

local function onVehicleSwitched(oldVehicle, newVehicle, player)
  initVehicleData(newVehicle)
end

local function onEditorHeadlessChange(enabled, toolName)
  log('I', 'veMain', "onEditorHeadlessChange(" .. tostring(enabled) .. ", " .. tostring(toolName) .. ")")

  if enabled and toolName == editorName then
    setupEditor()
  end
end

local function onVehicleDestroyed()
  vEditor.vehicle = nil
  vEditor.vehData = nil
  vEditor.vdata = nil
  vEditor.vehiclePos = nil
  vEditor.vehicleNodesPos = nil
end

local function onEditorInspectorFieldChanged(selectedIds, fieldName, fieldValue, arrayIndex)
  for i = 1, #selectedIds do
    local object = scenetree.findObjectById(selectedIds[i])
    if object and object:getClassName() == "BeamNGVehicle" then
      if fieldName == "color" or fieldName == "colorPalette0" or fieldName == "colorPalette1" then
        local color = core_vehicle_colors.colorStringToColorTable(fieldValue)
        color[4] = color[4]*2
        local paint = createVehiclePaint({x=color[1], y=color[2], z=color[3], w=color[4]}, {color[5], color[6], color[7], color[8]})
        core_vehicle_partmgmt.setConfigPaints(paint, false)
      end
    end
  end
end

local function sceneMetric()
  local io = im.GetIO()
  local fps = fpsSmoother:get(io.Framerate)

  local txtSize = im.CalcTextSize("FPS: 999 ").y + im.CalcTextSize("GpuWait: 00.0f ").y + im.CalcTextSize("Poly: 123456789").y
  im.SetCursorPosX(im.GetCursorPosX() + im.GetContentRegionAvailWidth() - txtSize*4)

  if fps < 30 then
    im.TextColored(im.ImVec4(1, 0.3, 0.3, 1), "FPS: %.0f", fps)
  elseif fps < 60 then
    im.TextColored(im.ImVec4(1, 1, 0.2, 1), "FPS: %.0f", fps)
  else
    im.Text("FPS: %.0f", fps)
  end

  if metricsTim < Engine.Platform.getRuntime() -0.5 then
    metricsTim = Engine.Platform.getRuntime()
    Engine.Debug.getLastPerformanceMetrics(metrics)
  end
  if metrics["framePresentDelay"] < 0.3 then
    im.Text("GpuWait: %.1f", metrics["framePresentDelay"])
  elseif metrics["framePresentDelay"] < 1 or fps > 30 then
    im.TextColored(im.ImVec4(1, 1, 0.2, 1), "GpuWait: %3.1f", metrics["framePresentDelay"])
  else
    im.TextColored(im.ImVec4(1, 0.3, 0.3, 1), "GpuWait: %3.1f", metrics["framePresentDelay"])
  end
  im.Text("Poly: "..getConsoleVariable("$GFXDeviceStatistics::polyCount"))
end

local function fileMenu()
  if im.BeginMenu("File", imgui_true) then
    if im.MenuItem1("Exit Vehicle Editor...", nil, imgui_false, imgui_true) then
      -- disable headless mode
      editor.enableHeadless(false, editorName)
      editor.hideObjectIcons = false

      pushActionMapHighestPriority("Editor")
      --pushActionMapHighestPriority("EditorKeyMods")
    end
    im.EndMenu()
  end
end

local function appsMenu()
  if im.BeginMenu("Apps") then
    for _, item in ipairs(M.menuItems.items) do
      if item.group then
        if im.BeginMenu(item.group) then
          createMenu(item.items)
          im.EndMenu()
        end
      else
        if im.MenuItem1(item.menuEntry) then
          item.menuOpen()
        end
      end
    end
    im.EndMenu()
  end
end

local layoutName = im.ArrayChar(128)

local function viewMenu()
  if im.BeginMenu("View", imgui_true) then
    if im.MenuItem1("Add Scene View") then
      extensions.editor_vehicleEditor_veView.addSceneView()
    end
    if im.BeginMenu("Layouts", imgui_true) then
      for _, layoutPath in ipairs(editor_layoutManager.getWindowLayouts(editorName)) do
        if im.MenuItem1(string.match(layoutPath, ".+/(.+)"), nil, imgui_false, imgui_true) then
          editor_layoutManager.loadWindowLayout(layoutPath)
        end
      end

      im.Separator()
      if im.MenuItem1("Save Layout...", nil, imgui_false, imgui_true) then
        editor.showWindow(saveLayoutWindowName)
      end
      if im.MenuItem1("Delete Layout...", nil, imgui_false, imgui_true) then
        editor.showWindow(deleteLayoutWindowName)
      end
      if im.MenuItem1("Revert to Factory Settings...", nil, imgui_false, imgui_true) then
        editor.showWindow(resetLayoutsWindowName)
      end
      im.EndMenu()
    end
    im.EndMenu()
  end

  if editor.beginWindow(saveLayoutWindowName, saveLayoutWindowTitle) then
    im.PushItemWidth(im.GetContentRegionAvailWidth())
      if im.InputText("##SaveLayout", layoutName, 128, im.InputTextFlags_EnterReturnsTrue) then
        editor.hideWindow(saveLayoutWindowName)
        editor_layoutManager.saveWindowLayout(ffi.string(layoutName), editorName)
      end
      if im.Button("Save") then
        editor.hideWindow(saveLayoutWindowName)
        editor_layoutManager.saveWindowLayout(ffi.string(layoutName), editorName)
      end
  end
  editor.endWindow()

  if editor.beginWindow(deleteLayoutWindowName, deleteLayoutWindowTitle) then
    for _, layoutPath in ipairs(editor_layoutManager.getWindowLayouts(editorName)) do
      if im.MenuItem1(string.match(layoutPath, ".+/(.+)"), nil, imgui_false, imgui_true) then
        editor_layoutManager.deleteWindowLayout(layoutPath)
      end
    end
  end
  editor.endWindow()

  if editor.beginWindow(resetLayoutsWindowName, resetLayoutsWindowTitle) then
    im.Text("This will delete all window layouts files and set the Default factory layout.")
    if im.Button("Continue") then
      editor.hideWindow(resetLayoutsWindowName)
      editor_layoutManager.resetLayouts(editorName)
    end
    im.SameLine()
    if im.Button("Cancel") then
      editor.hideWindow(resetLayoutsWindowName)
    end
  end
  editor.endWindow()
end

-- this hook function is called by the editor when in headless mode to draw your own menubar
local function onEditorHeadlessMainMenuBar()
  if not editor.isHeadlessToolActive(editorName) then return end
  -- show our custom menu for the editor
  if im.BeginMainMenuBar() then
    fileMenu()
    appsMenu()
    viewMenu()

    sceneMetric()
    im.EndMainMenuBar()
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  local veViewSceneViewsDefaultVal = readJsonFile(veViewSettingsDefaultFilePath)

  prefsRegistry:registerCategory("vehicleEditor")

  prefsRegistry:registerSubCategory("vehicleEditor", "veView", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    -- hidden prefs
    {sceneViews = {"table", veViewSceneViewsDefaultVal, "", nil, nil, nil, true, nil}},
  })
end

M.onPreRender = onPreRender
M.onEditorHeadlessChange = onEditorHeadlessChange
M.onEditorInitialized = onEditorInitialized
M.onVehicleSwitched = onVehicleSwitched
M.onVehicleDestroyed = onVehicleDestroyed
M.onEditorInspectorFieldChanged = onEditorInspectorFieldChanged
M.onEditorHeadlessMainMenuBar = onEditorHeadlessMainMenuBar
M.onEditorRegisterPreferences = onEditorRegisterPreferences

return M
