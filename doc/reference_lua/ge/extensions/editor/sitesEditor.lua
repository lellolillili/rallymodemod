  -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local u_32_max_int = 4294967295
local logTag = 'sites_editor_tool'
local toolWindowName = "sitesEditorTool"
local editModeName = "Edit Sites"
local im = ui_imgui
local ffi = require('ffi')
local currentMode = 'Locations'
local previousFilepath = "/gameplay/sites/"
local previousFilename = "newSite.sites.json"
local windows = {}
local currentWindow = {}
local testingWindow
local currentSites = require('/lua/ge/extensions/gameplay/sites/sites')("New Sites")
local allFiles = {}


local mouseInfo = {}
local nameText = im.ArrayChar(1024, "")

local function saveSites(sites, savePath)
  local dir, filename, ext = path.split(savePath)
  sites.dir = dir
  sites.name = filename
  local json = sites:onSerialize()
  jsonWriteFile(savePath, json, true)
  previousFilepath = dir
end

local function loadSites(loadPath)
  local sites = extensions.gameplay_sites_sitesManager.loadSites(loadPath)
  if sites then
    currentSites = sites
    local dir, filename, ext = path.split(loadPath)
    previousFilepath = dir
    for _, window in ipairs(windows) do
      currentWindow:setSites(currentSites)
      currentWindow:unselect()
    end
    currentWindow:selected()
  end
  return currentSites
end

local function updateMouseInfo()
  if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end
  mouseInfo.camPos = getCameraPosition()
  mouseInfo.ray = getCameraMouseRay()
  mouseInfo.rayDir = vec3(mouseInfo.ray.dir)
  mouseInfo.rayCast = cameraMouseRayCast()
  mouseInfo.valid = mouseInfo.rayCast and true or false

  if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end
  if not mouseInfo.valid then
    mouseInfo.down = false
    mouseInfo.hold = false
    mouseInfo.up   = false
    mouseInfo.closestNodeHovered = nil
  else
    mouseInfo.down =  im.IsMouseClicked(0) and not im.GetIO().WantCaptureMouse
    mouseInfo.hold = im.IsMouseDown(0) and not im.GetIO().WantCaptureMouse
    mouseInfo.up =  im.IsMouseReleased(0) and not im.GetIO().WantCaptureMouse
    if mouseInfo.down then
      mouseInfo.hold = false
      mouseInfo._downPos = vec3(mouseInfo.rayCast.pos)
    end
    if mouseInfo.hold then
      mouseInfo._holdPos = vec3(mouseInfo.rayCast.pos)
    end
    if mouseInfo.up then
      mouseInfo._upPos = vec3(mouseInfo.rayCast.pos)
    end
  end
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Sites: Locations and Zones Editor", im.WindowFlags_MenuBar) then
    if im.BeginMenuBar() then
      if im.BeginMenu("File") then
        if im.MenuItem1("New") then
          currentSites = require('/lua/ge/extensions/gameplay/sites/sites')("New Sites")
          for _, window in ipairs(windows) do
            currentWindow:setSites(currentSites)
            currentWindow:unselect()
          end
          currentWindow:selected()
          previousFilepath = "/gameplay/sites/"
        end
        if im.MenuItem1("Load...") then
          editor_fileDialog.openFile(function(data) currentSites = loadSites(data.filepath) end, {{"Sites Files",".sites.json"}}, false, previousFilepath)
        end
        if not currentSites.name or not currentSites.dir then
          im.BeginDisabled()
        end
        if im.MenuItem1("Save") then
        saveSites(currentSites, currentSites.dir..currentSites.name)
        end
        if not currentSites.name or not currentSites.dir then
          im.EndDisabled()
        end
        if im.MenuItem1("Save as...") then
          extensions.editor_fileDialog.saveFile(function(data) saveSites(currentSites, data.filepath) end,
                                        {{"Sites Files",".sites.json"}}, false, previousFilepath)
        end

        im.Separator()
        M.managerSites()
        im.EndMenu()
      end

      if im.BeginMenu("Tools") then

        if im.MenuItem1("Sort Locations by Name") then
          table.sort(currentSites.locations.sorted, function(a,b)
            if a.name == b.name then
              return a.sortOrder < b.sortOrder
            else
              return a.name < b.name
            end
          end)
          for i, e in ipairs(currentSites.locations.sorted) do
            e.sortOrder = i
          end
          currentSites.locations:sort()
        end
        if im.MenuItem1("Sort Zones by Name") then
          table.sort(currentSites.zones.sorted, function(a,b)
            if a.name == b.name then
              return a.sortOrder < b.sortOrder
            else
              return a.name < b.name
            end
          end)
          for i, e in ipairs(currentSites.zones.sorted) do
            e.sortOrder = i
          end
          currentSites.zones:sort()
        end
        im.EndMenu()
      end


      im.EndMenuBar()
    end

    if im.BeginTabBar("modes") then
      for _, window in ipairs(windows) do
        if im.BeginTabItem(window.windowDescription) then
          if currentWindow.windowDescription ~= window.windowDescription then
            currentWindow:unselect()
            currentWindow = window
            currentWindow:setSites(currentSites)
            currentWindow:selected()
          end
          im.EndTabItem()
        end
      end
      im.EndTabBar()
    end

    updateMouseInfo()

    currentSites:drawDebug()
    currentWindow:draw(mouseInfo)
  end
  editor.endWindow()
end

local function managerSites()
  if im.BeginMenu("Sites in Manager...") then
    local levelSites = extensions.gameplay_sites_sitesManager.getSitesByLevel()
    local lvlNamesSorted = {}
    local emptyLevelNamesSorted = {}
    for id, sites in pairs(levelSites) do
      if #sites > 0 then
        table.insert(lvlNamesSorted, id)
      else
        table.insert(emptyLevelNamesSorted, id)
      end
    end
    table.sort(lvlNamesSorted)
    table.sort(emptyLevelNamesSorted)

    if im.MenuItem1("Reload all level sites") then
      extensions.gameplay_sites_sitesManager.loadAllLevelSites()
    end
    if im.BeginMenu("Empty Levels") then
      for _, name in ipairs(emptyLevelNamesSorted) do
        im.MenuItem1(name)
      end
      im.EndMenu()
    end
    im.Separator()

    for _,lvl in ipairs(lvlNamesSorted) do
      if im.BeginMenu(lvl) then
        for _, site in ipairs(levelSites[lvl]) do
          if im.MenuItem1(site.filename) then
            currentSites = site
            for _, window in ipairs(windows) do
              currentWindow:setSites(currentSites)
              currentWindow:unselect()
            end
            currentWindow:selected()
            previousFilepath = site.dir
            previousFilename = site.filename
          end
          im.tooltip(site.dir..site.filename)
        end
        im.EndMenu()
      end
    end

    im.EndMenu()
  end
end

local function show()
  editor.clearObjectSelection()
  editor.showWindow(toolWindowName)
  editor.selectEditMode(editor.editModes.sitesEditMode)
end

local function onActivate()
  editor.clearObjectSelection()
  for _, win in ipairs(windows) do
    if win.onEditModeActivate then
      win:onEditModeActivate()
    end
  end
end
local function onDeactivate()
  for _, win in ipairs(windows) do
    if win.onEditModeDeactivate then
      win:onEditModeDeactivate()
    end
  end
  editor.clearObjectSelection()
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(400, 400))
  editor.editModes.sitesEditMode =
  {
    displayName = editModeName,
    onUpdate = nop,
    onActivate = onActivate,
    onDeactivate = onDeactivate,
    auxShortcuts = {},
    --icon = editor.icons.tb_close_track,
    --iconTooltip = "Race Editor"
  }
  editor.editModes.sitesEditMode.auxShortcuts[editor.AuxControl_LMB] = "Select"
  editor.addWindowMenuItem("Sites Editor", function() show() end, {groupMenuName="Gameplay"})

  local locations = require('/lua/ge/extensions/editor/sitesEditor/locations')(M,'locations')
  local locationsList = require('/lua/ge/extensions/editor/sitesEditor/sortedListDisplay')(M, 'locations',locations)
  locationsList.windowDescription = "Locations"
  table.insert(windows, locationsList)

  local zones = require('/lua/ge/extensions/editor/sitesEditor/zones')(M,'zones')
  local zonesList = require('/lua/ge/extensions/editor/sitesEditor/sortedListDisplay')(M, 'zones',zones)
  zonesList.windowDescription = "Zones"
  zonesList.createByShift = false
  zonesList.selectByClick = false
  table.insert(windows, zonesList)

  local parkingSpots = require('/lua/ge/extensions/editor/sitesEditor/parkingSpots')(M,'parkingSpots')
  local spotsList = require('/lua/ge/extensions/editor/sitesEditor/sortedListDisplay')(M, 'parkingSpots',parkingSpots)
  spotsList.windowDescription = "Parking Spots"
  table.insert(windows, spotsList)

  local locTags = require('/lua/ge/extensions/editor/sitesEditor/tags')(M,'locations')
  locTags.windowDescription = "Loc Tags"
  table.insert(windows, locTags)

  local zoneTags = require('/lua/ge/extensions/editor/sitesEditor/tags')(M,'zones')
  zoneTags.windowDescription = "Zone Tags"
  table.insert(windows, zoneTags)

--  table.insert(windows, require('/lua/ge/extensions/editor/sitesEditor/zones')(M))
  --table.insert(windows, require('/lua/ge/extensions/editor/sitesEditor/general')(M))
  currentWindow = windows[1]
  currentWindow:setSites(currentSites)
  currentWindow:selected()
end

local function onSerialize()
  local data = {
    path = currentSites:onSerialize()
  }
  return data
end

local function onDeserialized(data)
  if data then
    if data.path then
      currentSites:onDeserialized(data.path)
    end
  end
end

local function onEditorToolWindowHide(windowName)
  if windowName == toolWindowName then
    editor.selectEditMode(editor.editModes.objectSelect)
  end
end

local function onWindowGotFocus(windowName)
  if windowName == toolWindowName then
    editor.selectEditMode(editor.editModes.sitesEditMode)
  end
end

M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.allowGizmo = function() return editor.editMode and editor.editMode.displayName == editModeName or false end
M.getCurrentSites = function() return currentSites end
M.getCurrentZone = function() return windows[2]:getCurrentSelected() end
M.getCurrentLocation = function() return windows[1]:getCurrentSelected() end
M.show = show
M.loadSites = loadSites
M.saveSites = saveSites
M.onEditorGui = onEditorGui
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onEditorToolWindowGotFocus = onWindowGotFocus

M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded
M.managerSites = managerSites

return M