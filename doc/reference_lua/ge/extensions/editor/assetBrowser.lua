-- This Source Code Form is subject to the terms of the bCDDL, var. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- TODO: add favourites section

local M = {}

local ffi = require('ffi')
local im = ui_imgui
local imguiUtils = require('ui/imguiUtils')
local assetBrowserWindowName = "assetBrowser"
local assetBrowserImageInspectorWindowName = "assetBrowserImageInspector"
local icons = require("editor/iconOverview")

-- Reference to assetManager module.
local aM = nil

local logTag = 'editor_assetBrowser: '
local debug = false

-- TODO: Either cache the data we retrieve from the db or not.
local cacheResults = false
-- local db = true -- are we using the db implementation or not?!
local db = false

local draggedObjOffset

local var = {}

local sortLexicographically = function(a,b) return string.lower(a) < string.lower(b) end

local sortDirectoryAssetByFilename = function(dir)
  table.sort(dir.files, function(a,b) return string.lower(a.fileName) < string.lower(b.fileName) end)
end

local sortAssetsByFilename = function(a,b) return string.lower(a.fileName) < string.lower(b.fileName) end

var.windowFlags = im.flags(im.WindowFlags_MenuBar, im.WindowFlags_NoScrollbar)
var.windowWasOpen = false
var.settingsPath = "/settings/editor/assetBrowser_settings.json"
var.meshPreviewThumbnailPath = "/temp/assetBrowser/thumbnails/"
var.imageInspector_checkerboardBgPath = "/core/art/gui/images/checkerboard_bg.png"
var.imageInspector_whiteBgPath = "/core/art/gui/images/white_bg.png"
var.imageInspector_blackBgPath = "/core/art/gui/images/black_bg.png"
var.imageInspector_bg_state_enum = {
  checkerboard = 0,
  black = 1,
  white = 2,
}
var.imageInspector_bg_state = var.imageInspector_bg_state_enum.black

var.initialized = false
var.state_enum = {
  loading_assets = 0,
  loading_done = 1
}
var.state = var.state_enum.loading_assets -- 0: loading assets / 1: loading done

var.windowPos = nil
var.windowSize = nil

var.io = nil
var.style = nil

var.setTreeViewScroll = false
var.treeViewScrollPos = nil

var.scrollY = 0
var.assetViewScrollMax = 0
var.assetViewMainPanel_scrollPrev = 0

-- Count of all items we'd like to display in the asset view.
var.itemCount = 0
var.horizontalItems = 0
var.verticalItems = 0
var.maxAssetViewPanelHeight = 0
var.displayedItemsCount = 0

var.skipMainFolder = false
var.root = nil
var.otherFolders = nil

var.assetViewFilter = im.ImGuiTextFilter()
var.assetViewFilterDB = im.ArrayChar(32)
var.assetViewFilterWidth = 150
var.sortingGroupingDropdownWidth = 90

-- Whether we display assets of the current folder only or all folders.
var.assetViewFilterType_enum = {
  all_files = 1,
  current_folder_files = 2
}
var.saveFilterNameInputWidth = 100
var.saveFilterNameInput = im.ArrayChar(32)

var.fileTypes = nil
var.simpleFileTypes = nil

var.defaultFilter = {
  {label="All models", filterInput="", filterType=1, displayDirs=false, displayAssets=true, displayTextureSets=false, fileTypes={'dae'}},
  {label="All materials", filterInput="materials", displayDirs=false, displayAssets=true, displayTextureSets=false, filterType=1, fileTypes={'json'}}
}

var.levelPath = nil
var.levelName = nil

var.numberOfAllAssetsAndDirs = 0
var.assetsProcessed = 0

var.filteredDirs = {}
var.filteredDirsCount = nil
var.filteredAssets = {}
var.filteredAssetsCount = nil
var.filteredTextureSets = {}
var.filteredTextureSetsCount = nil
var.filteredAssetGroups = nil

var.fontSize = math.ceil(im.GetFontSize())
var.minThumbnailSize = math.ceil(im.GetFontSize())
var.tooltipThumbnailSize = im.ImVec2(64,64)
var.maxTooltipThumbnailSize = 256
var.thumbnailSliderGroupWidth = nil
var.thumbnailSliderWidth = 120

var.meshPreview = ShapePreview()
var.meshPreviewDimRdr = RectI(0,0,256,256)
var.meshPreviewRenderSize = {256,256}
var.meshPreviewDisplayCollisionMesh = false

var.meshPreviewCacheThumbnailSize = 128
var.meshPreviewCacheThumbnailRect = RectI(0,0,var.meshPreviewCacheThumbnailSize,var.meshPreviewCacheThumbnailSize)

var.imageButtonBorderSize = 1

var.iconSize = im.ImVec2(var.minThumbnailSize, var.minThumbnailSize)

var.assetViewMainPanelHeight = nil
var.assetViewMainPanelSize = im.ImVec2(0,0)

var.imageInspectorWindowSize = nil
var.imageInspectorWindowData = nil
var.imageInspectorWindowMaxSize = 512
var.imageInspectorWindowMinWidthSize = 300
var.imageInspectorAdditionalYSpace = 20

var.assetColorCodeHeight = 6

var.assetHovered = false

-- folder creation
var.newFolderModalOpen = false
var.newFolderName = im.ArrayChar(32)
var.newFolderMessages = {}
var.newFolderParentDir = nil

var.imageFileTypes = {'jpg', 'png', 'dds', 'tif', 'tiff', 'jpeg'}
var.fileSizeAbbreviations = {"B", "KB", "MB", "GB", "TB"}

var.inputFieldSize = nil

var.confirmationState_enum = {none = 0, deleteCache = 1, generateCache = 2}
var.confirmationState = var.confirmationState_enum.none

var.options = nil

var.savedSearchesOpen = false

var.assetSortingTypes = {
  {
    name="name",
    sortFunc = function(a,b)
      return string.lower(a.fileName) < string.lower(b.fileName)
    end
  },
  {
    name="filetype",
    sortFunc = function(a,b)
      local aType = string.lower(a.simpleFileType)
      local bType = string.lower(b.simpleFileType)
      if aType == bType then
        return string.lower(a.fileName) < string.lower(b.fileName)
      else
        return aType < bType
      end
    end
  },
  {
    name="asset type",
    sortFunc = function(a,b)
      local aType = string.lower(a.type)
      local bType = string.lower(b.type)
      if aType == bType then
        return string.lower(a.fileName) < string.lower(b.fileName)
      else
        return aType < bType
      end
    end
  }
}
var.assetSortingNamePtr = nil

var.assetGroupingTypes = {
  {
    name="none",
    assetGroupingFunc = nil,
    directoryGroupingFunc = nil
  },
  {
    name="filetype",
    assetGroupingFunc = function(asset)
      if not var.filteredAssetGroups[asset.simpleFileType] then
        var.filteredAssetGroups[asset.simpleFileType] = {}
      end
      table.insert(var.filteredAssetGroups[asset.simpleFileType], asset)
    end,
    directoryGroupingFunc = function(dir)
      if not var.filteredAssetGroups["folder"] then
        var.filteredAssetGroups["folder"] = {}
      end
      table.insert(var.filteredAssetGroups["folder"], dir)
    end
  },
  {
    name="type",
    assetGroupingFunc = function(asset)
      if not var.filteredAssetGroups[asset.type] then
        var.filteredAssetGroups[asset.type] = {}
      end
      table.insert(var.filteredAssetGroups[asset.type], asset)
    end,
    directoryGroupingFunc = function(dir)
      if not var.filteredAssetGroups["folder"] then
        var.filteredAssetGroups["folder"] = {}
      end
      table.insert(var.filteredAssetGroups["folder"], dir)
    end
  }
}
var.assetGroupingNamePtr = nil
var.assetGroupingTypes_enum = nil

-- initialized in setupVars()
var.directoryContextMenuEntries = nil
var.assetContextMenuEntries = nil
var.textureSetContextMenuEntries = nil
--

var.dragging_enum = {
  no_drag = 0,
  dragging = 2,
  drag_ended = 3
}
var.dragging = 0
var.dragDropMesh = nil

var.menuBarHeight = nil

var.history = {}
var.historyIndex = 1

var.currentListIndex = nil
var.arrowNavValueChanged = false
var.maxListIndexVal = 0

var.uniqueId = 0

var.currentLevelDirectories = {}

-- material preview
var.matPreview = ShapePreview()
var.dimRdr = RectI()
var.dimRdr:set(0, 0, 128, 128)

--  Tracks previous selection
var.viewSelectionHistory = nil

var.imageInspectorImage = nil
var.imageInspectorImageSize = nil
var.imageInspectorWindowData = nil

var.typeColors = {
  ['image'] = {0.81,0.52,0.65},
  ['json'] = {0.9,0.81,0.37},
  ['materials'] = {0.9,0.27,0.27},
  ['material'] = {0.93,0.41,0.71},
  ['terrain'] = {0.749,0.560,0.352},
  ['prefab'] = {0.52,0.81,0.81},
  ['datablock'] = {0.749,0.352,0.713},
  ['mesh'] = {0.27,0.18,0.83},
  ['lua'] = {0.31,0.31,0.6},
  ['html'] = {0.349,0.443,0.694},
  ['txt'] = {0.9,0.81,0.37},
  ['asset'] = {0.65,0.41,0.93},
  ['textureSet'] = {0.913,0.494,0.247},
  ['part configuration'] = {0.223,0.803,0.835},
  ['jbeam'] = {0.301, 0.576, 0.549},
}

-- ##### FUNCTIONS
local function getUniqueId()
  var.uniqueId = var.uniqueId + 1
  return var.uniqueId
end

local function isWindowHovered()
  if (var.io.MousePos.x >= var.windowPos.x) and (var.io.MousePos.x <= (var.windowPos.x + var.windowSize.x)) and (var.io.MousePos.y >= var.windowPos.y) and (var.io.MousePos.y <= (var.windowPos.y + var.windowSize.y)) then
    return true
  else
    return false
  end
end

local function directoryFilterCheck(dir)
  if im.ImGuiTextFilter_PassFilter(var.assetViewFilter, dir.name) then
    return true
  end
  return false
end

local function assetFileNameCheck(asset)
  if im.ImGuiTextFilter_PassFilter(var.assetViewFilter, asset.fileName) then
    return true
  else
    return false
  end
end

local function assetFileTypeNameCheck(asset)
  if im.ImGuiTextFilter_PassFilter(var.assetViewFilter, asset.fileType) then
    return true
  else
    return false
  end
end

local function assetSimpleFileTypeCheck(asset)
  for k, type in ipairs(var.simpleFileTypes) do
    if type.active[0] == true and asset.simpleFileType == type.label then
      return true
    end
  end
  return false
end

local function assetFilterCheck(asset)
  if (assetFileNameCheck(asset) or assetFileTypeNameCheck(asset)) and assetSimpleFileTypeCheck(asset) then
    return true
  end
  return false
end

local function getFileSizeString(filesize)
  local index = 1
  while filesize >= 1024 and index < #var.fileSizeAbbreviations do
    filesize = filesize/1024
    index = index + 1
  end
  return string.format((index > 1) and "%0.1f %s" or "%0.0f %s", filesize, var.fileSizeAbbreviations[index])
end

local function formatFileTime(file)
  file.filestats.accesstimeString = os.date("%x %I:%M%p", file.filestats.accesstime)
  file.filestats.createtimeString = os.date("%x %I:%M%p", file.filestats.createtime)
  file.filestats.modtimeString = os.date("%x %I:%M%p", file.filestats.modtime)
end

local function createFileStats(file, forced)
  if not file.filestats or forced == true then
    file.filestats = FS:stat(file.path)
    if file.filestats.filesize then
      file.filestats.filesizeString = getFileSizeString(file.filestats.filesize)
    end
    formatFileTime(file)
  end
end

local function createMeshPreviewJob(job)
  job.args[1].ready = false
  if not job.args[1].filestats then createFileStats(job.args[1], true) end

  job.args[1].inspectorData.cachePath = var.meshPreviewThumbnailPath .. job.args[1].path .. ".png"
  -- Check if a cached thumbnail exists already or if the asset of an existing thumbnail has been
  -- modified since the last cache creation.
  if FS:fileExists(job.args[1].inspectorData.cachePath) == false
  or (FS:fileExists(job.args[1].inspectorData.cachePath) == true and job.args[1].filestats.modtime > FS:stat(job.args[1].inspectorData.cachePath).createtime) then
    local shapePrev = ShapePreview()
    shapePrev:setRenderState(false,false,false,false,false)
    shapePrev:setCamRotation(0.3, 0)
    shapePrev:setObjectModel(job.args[1].path)

    local levelName = string.match(job.args[1].path, "/levels/([%w_]+)")
    local artFilepath = string.match(job.args[1].path, "/art/(.+)")
    if not levelName and not artFilepath then
      return
    end

    var.meshPreviewCacheThumbnailRect.point = Point2I(0, 0)
    var.meshPreviewCacheThumbnailRect.extent = Point2I(var.meshPreviewCacheThumbnailSize, var.meshPreviewCacheThumbnailSize)
    shapePrev:renderWorld(var.meshPreviewCacheThumbnailRect)
    shapePrev:fitToShape()
    coroutine.yield()
    coroutine.yield()
    coroutine.yield()
    shapePrev:renderWorld(var.meshPreviewCacheThumbnailRect)
    coroutine.yield()
    local bitmap = GBitmap()
    bitmap:init(var.meshPreviewCacheThumbnailSize,var.meshPreviewCacheThumbnailSize)
    shapePrev:copyToBmp(bitmap:getPtr())
    bitmap:saveFile(job.args[1].inspectorData.cachePath)
  end
  -- Indicates whether cache etc. has been created or not.
  job.args[1].ready = true
end

local function createMeshPreview(asset)
  asset.ready = false
  if not asset.filestats then createFileStats(asset, true) end

  asset.inspectorData.cachePath = var.meshPreviewThumbnailPath .. asset.path .. ".png"
  -- Check if a cached thumbnail exists already or if the asset of an existing thumbnail has been
  -- modified since the last cache creation.
  if FS:fileExists(asset.inspectorData.cachePath) == false
  or (FS:fileExists(asset.inspectorData.cachePath) == true and asset.filestats.modtime > FS:stat(asset.inspectorData.cachePath).createtime) then
    local shapePrev = ShapePreview()
    shapePrev:setRenderState(false,false,false,false,false)
    shapePrev:setCamRotation(0.3, 0)
    shapePrev:setObjectModel(asset.path)

    local levelName = string.match(asset.path, "/levels/([%w_]+)")
    local artFilepath = string.match(asset.path, "/art/(.+)")
    if not levelName and not artFilepath then
      return
    end

    var.meshPreviewCacheThumbnailRect.point = Point2I(0, 0)
    var.meshPreviewCacheThumbnailRect.extent = Point2I(var.meshPreviewCacheThumbnailSize, var.meshPreviewCacheThumbnailSize)
    shapePrev:renderWorld(var.meshPreviewCacheThumbnailRect)
    shapePrev:fitToShape()
    shapePrev:renderWorld(var.meshPreviewCacheThumbnailRect)
    local bitmap = GBitmap()
    bitmap:init(var.meshPreviewCacheThumbnailSize,var.meshPreviewCacheThumbnailSize)
    shapePrev:copyToBmp(bitmap:getPtr())
    bitmap:saveFile(asset.inspectorData.cachePath)
  end
  -- Indicates whether cache and stuff has been created or not.
  asset.ready = true
end

-- Create data for a single file we can display in the inspector based on its type.
local function createInspectorData(file, forced, noJob)
  if not file.inspectorData or forced == true then
    file.inspectorData = {}
    if file.type == "json" then
      if file.fileType == 'level.json' and file.fullFileName == "items.level.json" then
        file.inspectorData.data = {}
        for line in io.lines(file.path) do
          file.inspectorData.data[#file.inspectorData.data+1] = jsonDecode(line)
        end
      else
        local skipFile = false
        if file.fullFileName == "main.level.json" and getMissionFilename() ~= "" then
          local levelName = string.match(getMissionFilename(), "/levels/([%w_]+)")
          local newSceneTreeEntry = '/levels/' .. levelName .. '/main/'
          if FS:directoryExists(newSceneTreeEntry) then
            skipFile = true
          end
        end
        if skipFile then
          editor.logInfo(logTag .. "Skipping file: " .. file.fullFileName)
        else
          file.inspectorData.data = jsonReadFile(file.sourcefilename or file.path)
        end
      end
      file.inspectorData.rawdata = dumps(file.inspectorData.data)
    elseif file.type == "part configuration" or file.type == "jbeam" then
      file.inspectorData.data = jsonReadFile(file.sourcefilename or file.path)
      file.inspectorData.rawdata = dumps(file.inspectorData.data)
    elseif file.type == "materials" then
      file.inspectorData.data = jsonReadFile(file.sourcefilename or file.path)
      file.inspectorData.rawdata = dumps(file.inspectorData.data)
      file.inspectorData.materials = {}
      for matName, data in pairs(file.inspectorData.data) do
        if data.class == "Material" or data.class == "material" then
          local mat = {}
          mat.id = getUniqueId()
          mat.name = matName
          mat.type = 'material'
          mat.cobj = scenetree.findObject(matName)
          mat.selected = false
          file.inspectorData.materials[matName] = mat
        end
      end
    elseif file.type == "prefab" then
      file.inspectorData.rawdata = readFile(file.sourcefilename or file.path)
    elseif file.type == "datablock" then
      file.inspectorData.rawdata = readFile(file.sourcefilename or file.path)
    elseif file.type == "lua" then
      file.inspectorData.rawdata = readFile(file.sourcefilename or file.path)
    elseif file.type == "html" then
      file.inspectorData.rawdata = readFile(file.sourcefilename or file.path)
    elseif file.type == "txt" then
      file.inspectorData.rawdata = readFile(file.sourcefilename or file.path)
    elseif file.type == "image" then
      --
    elseif file.type == "mesh" then
      if noJob == true then
        createMeshPreview(file)
      else
        core_jobsystem.create(createMeshPreviewJob, 1, file)
      end
    end
  end
end

local function createAssetData(file, forced, noJob)
  createInspectorData(file, forced, noJob)
  createFileStats(file, forced)
end

local function createAssetDataJob(job)
  if job.args[1].type == "textureSet" then
    if job.args[1].d then
      coroutine.yield()
      createFileStats(job.args[1].d)
    end
    if job.args[1].n then
      coroutine.yield()
      createFileStats(job.args[1].n)
    end
    if job.args[1].s then
      coroutine.yield()
      createFileStats(job.args[1].s)
    end
  elseif job.args[1].type == "material" then

  else
    coroutine.yield()
    createInspectorData(job.args[1])
    coroutine.yield()
    createFileStats(job.args[1])
  end
end

local function createAssetDataForFilteredAssetsJob(job)
  for _,asset in ipairs(var.filteredAssets) do
    core_jobsystem.create(createAssetDataJob, 1, asset)
    coroutine.yield()
  end
end

-- used in coroutine/jobsystem
-- first argument = dir, 2nd argument = forced
local function createAssetDataOfWholeDirJob(job)
  if job.args[1].files then
    for _, file in ipairs(job.args[1].files) do
      createAssetData(file, job.args[2])
      coroutine.yield()
    end
  end
  job.args[1].processed = true
end

local function createAssetDataOfFilteredAssetsJob(job)
  for _, file in ipairs(job.args[1]) do
    createAssetData(file)
    coroutine.yield()
  end
end

local function openImageInspectorWindow(asset)
  var.imageInspectorImage = editor.getTempTextureObj(asset.path)
  if var.imageInspectorImage then
    var.imageInspectorImage.ratio = var.imageInspectorImage.size.y / var.imageInspectorImage.size.x
    var.imageInspectorImageSize = nil
    var.imageInspectorWindowData = asset.inspectorData
    if var.imageInspectorImage.size.x > var.imageInspectorWindowMaxSize or var.imageInspectorImage.size.y > var.imageInspectorWindowMaxSize then
      if var.imageInspectorImage.ratio < 1 then
        var.imageInspectorWindowSize = im.ImVec2(var.imageInspectorWindowMaxSize, var.imageInspectorWindowMaxSize * var.imageInspectorImage.ratio)
      else
        var.imageInspectorWindowSize = im.ImVec2(var.imageInspectorWindowMaxSize / var.imageInspectorImage.ratio, var.imageInspectorWindowMaxSize)
      end
    elseif var.imageInspectorImage.size.x < var.imageInspectorWindowMinWidthSize then
      if var.imageInspectorImage.ratio < 1 then
        var.imageInspectorWindowSize = im.ImVec2(var.imageInspectorWindowMinWidthSize, var.imageInspectorWindowMinWidthSize * var.imageInspectorImage.ratio)
      else
        var.imageInspectorWindowSize = im.ImVec2(var.imageInspectorWindowMinWidthSize, var.imageInspectorWindowMinWidthSize / var.imageInspectorImage.ratio)
      end
    else
      var.imageInspectorWindowSize = im.ImVec2(var.imageInspectorImage.size.x, var.imageInspectorImage.size.y)
    end
    editor.showWindow(assetBrowserImageInspectorWindowName)
  end
end

local function selectAsset(asset)
  if (not tableIsEmpty(editor.selection)) and editor.selection["asset"] == nil and var.viewSelectionHistory ~= nil then
    --  Resets tracked previous selection when selection changed outside of the asset browser
    -- otherwise we'll end up with multiple highlighted items.
    var.viewSelectionHistory.selectedInABView = false
    if var.viewSelectionHistory.type ~= nil then var.viewSelectionHistory.selected = false end

    if not tableIsEmpty(editor.selection.object) then
      var.editorLastSelection = editor.selection.object[#editor.selection.object]
    end

    editor.clearObjectSelection()
    editor.selection = {}
  end
  local currSelection = editor.selection["asset"]
  if currSelection ~= nil then
    -- The same asset has been selected.
    if currSelection == asset then
      return
    end
    --  Deselects current selection
    currSelection.selectedInABView = false
    if currSelection.type ~= nil then currSelection.selected = false end
  end

  -- Close image inspector when the selected asset is no image.
  if asset.type ~= "image" then
    editor.hideWindow(assetBrowserImageInspectorWindowName)
  else
    -- Update image inspector window's size based on resolution of the asset.
    if editor.isWindowVisible(assetBrowserImageInspectorWindowName) and asset ~= editor.selection["asset"] then
      openImageInspectorWindow(asset)
    end
  end

  if asset.type == "mesh" then
    var.meshPreview:setObjectModel(asset.path)
    var.meshPreview:fitToShape()
    -- setRenderState args: ghost, nodes, bounds, objbox, col, grid
    var.meshPreview:setRenderState(false,false,false,false,var.meshPreviewDisplayCollisionMesh,true)
  end

  if asset.type == "material" then
    var.matPreview:setMaterial(asset.cobj)
  end

  if not tableIsEmpty(editor.selection.object) then
    var.editorLastSelection = editor.selection.object[#editor.selection.object]
  end

  -- Clear editor selection.
  editor.clearObjectSelection()
  --  Selects new asset
  asset.selectedInABView = true
  if asset.type ~= nil then asset.selected = true end
  editor.selection["asset"] = asset
  var.viewSelectionHistory = asset
  --  Create inspector data
  if not asset.inspectorData then
    core_jobsystem.create(createAssetDataJob, 1, editor.selection["asset"])
  end
end

local function checkDirs(dir)
  if im.ImGuiTextFilter_PassFilter(var.assetViewFilter, dir.name) then
    table.insert(var.filteredDirs, dir)
    var.filteredDirsCount = var.filteredDirsCount + 1
  end
  if dir.dirs then
    for _,cDir in pairs(dir.dirs) do
      checkDirs(cDir)
    end
  end
end

local function addAssetToFilteredAssets(asset)
  table.insert(var.filteredAssets, asset)
  if var.assetGroupingTypes[var.options.assetGroupingType].assetGroupingFunc then
    var.assetGroupingTypes[var.options.assetGroupingType].assetGroupingFunc(asset)
  end
  var.filteredAssetsCount = var.filteredAssetsCount + 1
end

local function checkAssets(dir)
  if dir.files then
    for k,asset in pairs(dir.files) do
      if assetFilterCheck(asset) == true then
        addAssetToFilteredAssets(asset)
      end
    end
  end
  if dir.dirs then
    for _,cDir in pairs(dir.dirs) do
      checkAssets(cDir)
    end
  end
end

local function checkTextureSets(dir)
  if dir.textureSets then
    for k,set in pairs(dir.textureSets) do
      if im.ImGuiTextFilter_PassFilter(var.assetViewFilter, set.name) then
        table.insert(var.filteredTextureSets, set)
        var.filteredTextureSetsCount = var.filteredTextureSetsCount + 1
      end
    end
  end
  if dir.dirs then
    for _,cDir in pairs(dir.dirs) do
      checkTextureSets(cDir)
    end
  end
end

local function filterDirs()
  var.filteredDirs = {}
  var.filteredDirsCount = 0
  if var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files then
    for _, dir in ipairs(var.selectedDirectory.dirs) do
      if directoryFilterCheck(dir) == true then
        table.insert(var.filteredDirs, dir)
        var.filteredDirsCount = var.filteredDirsCount + 1
      end
    end
  elseif var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
    if var.root.dirs then
      for k,dir in pairs(var.root.dirs) do
        checkDirs(dir)
      end
    end
  end
  table.sort(var.filteredDirs, function(a,b) return string.lower(a.name) < string.lower(b.name) end)
end

local function filterAssets()
  -- Filter assets.
  var.filteredAssets = {}
  var.filteredAssetsCount = 0
  var.filteredAssetGroups = {}
  if var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files then
    if(var.selectedDirectory.files) then
      for _, asset in ipairs(var.selectedDirectory.files) do
        if assetFilterCheck(asset) == true then
          addAssetToFilteredAssets(asset)
        end
      end
    end
  elseif var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
    checkAssets(var.root)
  end

  for _, group in pairs(var.filteredAssetGroups) do
    table.sort(group, sortAssetsByFilename)
  end

  -- Sort assets based on selected sorting mode.
  if var.assetSortingTypes[var.options.assetSortingType].sortFunc then
    table.sort(var.filteredAssets, var.assetSortingTypes[var.options.assetSortingType].sortFunc)
  end

  -- Add directories to 'folders' asset group.
  var.filteredAssetGroups["folders"] = var.filteredDirs

  -- [Debug]
  -- dumpz(var.filteredAssetGroups, 2)

  -- Create a sorted array with all asset groups.
  var.filteredAssetGroupsSorted = {}
  for assetGroupIdentifier, _ in pairs(var.filteredAssetGroups) do
    table.insert(var.filteredAssetGroupsSorted, {identifier = assetGroupIdentifier, open = true})
  end
  table.sort(var.filteredAssetGroupsSorted, function(a,b) return string.lower(a.identifier) < string.lower(b.identifier) end)

  -- Filter texture sets.
  var.filteredTextureSets = {}
  var.filteredTextureSetsCount = 0
  if var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files then
    if(var.selectedDirectory.textureSets) then
      for _, set in pairs(var.selectedDirectory.textureSets) do
        table.insert(var.filteredTextureSets, set)
        var.filteredTextureSetsCount = var.filteredTextureSetsCount + 1
      end
    end
  elseif var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
    checkTextureSets(var.root)
  end
end

local function getAssetTypeColor(asset)
  if asset and asset.type and var.typeColors[asset.type] then
    local col = var.typeColors[asset.type]
    return im.GetColorU322(im.ImVec4(col[1],col[2],col[3],1))
  else
    editor.logWarn(logTag .. "No suitable color for type '" .. asset.type .. "'. Using default color.")
    return im.GetColorU322(im.ImVec4(1,1,1,1))
  end
end

local function createDBFilesTable(data)
  var.filteredAssets = {}
  if not data then return end
  dump(data)
  dump(#data)
  --[[
  for k, file in ipairs(data) do

    var.filteredAssets[k] = {
      id = file.file_id,
      filename = file.aliases_basename,
      extension = file.aliases_extension,
      sourcefilename = file.files_sourcefilename,
      path = file.aliases_directory, --<-- TODO: directory
      filesize = file.files_filesize,
      hash = file.files_hash,
      modtime = file.files_modtime,
      createtime = file.files_createtime,
      fullFileName = file.aliases_basename .. '.' .. file.aliases_extension,
      selected = false
    }
    local ext = file.aliases_extension
    if tableContains(var.imageFileTypes, ext) then
      var.filteredAssets[k].type = "image"
    elseif ext == "json" then
      var.filteredAssets[k].type = "json"
    elseif ext == "ter" then
      var.filteredAssets[k].type = "terrain"
    elseif ext == "prefab" then
      var.filteredAssets[k].type = "prefab"
    elseif ext == "cs" then
      var.filteredAssets[k].type = "datablock"
    elseif ext == "dae" then
      var.filteredAssets[k].type = "mesh"
    elseif ext == "html" then
      var.filteredAssets[k].type = "html"
    elseif ext == "lua" then
      var.filteredAssets[k].type = "lua"
    else
      var.filteredAssets[k].type = "asset"
    end
  end
  ]]
end

local function selectDirectory(dir, toggleOpen, open, addToHistory, createNoAssetData)
  -- editor.logInfo(logTag .. "Select directory: " .. dir.path)
  local keepScroll = (dir == var.selectedDirectory)

  if var.selectedDirectory ~= nil then
    var.selectedDirectory.selected = false
  end
  var.selectedDirectory = dir
  var.currentLevelDirectories[var.levelName] = dir.path
  editor.setPreference("assetBrowser.general.currentLevelDirectories", var.currentLevelDirectories)

  var.options.assetViewFilterType = var.assetViewFilterType_enum.current_folder_files
  filterDirs()
  filterAssets()

  dir.selected = true
  if keepScroll == false then
    var.scrollY = 0
  end

  -- directory in assetView has been double-clicked
  if open == true then
    dir.open = true
    -- open all parent directories
    local par = dir.parent
    if par ~= true then
      par.open = true
      while par.parent ~= true do
        par.parent.open = true
        par = par.parent
      end
    end
  -- directory in tree view
  elseif toggleOpen == true then
    dir.open = not dir.open
  end

  if editor.getPreference("assetBrowser.general.createAssetDataOfDirectory") == true and
    (dir.files and dir.processed == false) and (createNoAssetData == nil or createNoAssetData == false) then
    core_jobsystem.create(createAssetDataOfWholeDirJob, 1, dir)
  end

  if addToHistory == true then
    if var.historyIndex < #var.history then
      for i = #var.history, (var.historyIndex+1), -1 do
        table.remove(var.history,i)
      end
    end
    table.insert(var.history,dir)
    var.historyIndex = var.historyIndex + 1
  end
end

local function selectDirectoryDB(dir, toggleOpen, open, reloadData)
  -- editor.logInfo(logTag .. "Select directory: " .. dir.path)
  if var.selectedDirectory.path ~= dir.path or reloadData==true then
    if var.selectedDirectory ~= nil then
      var.selectedDirectory.selected = false
    end
    var.selectedDirectory = dir

    filterDirs()
    createDBFilesTable(aM.getFiles(var.selectedDirectory.path))

    dir.selected = true

    core_jobsystem.create(createAssetDataOfFilteredAssetsJob, 1, var.filteredAssets)
  end

  -- directory in assetView has been double-clicked
  if open == true then
    dir.open = true
    dir.parent.open = true -- open the parent folder
  -- directory in tree view
  elseif toggleOpen == true then
    dir.open = not dir.open
  end
end

local function pathToRoot(path, dir)
  if dir ~= true then
    table.insert(path, 1, dir)
    pathToRoot(path, dir.parent)
  end
end

local function newDirectory(path, name, parent, open, selected, addToParent)
  local dir = {
    id = getUniqueId(),
    path = path..'/',
    name = name,
    parent = parent,
    open = open or false,
    selected = selected or false,
    processed = false -- whether inspector gui data has been created for the files of the dir or not
  }
  -- TODO: create path to root
  dir.pathToRoot = {}
  pathToRoot(dir.pathToRoot, dir.parent)

  if addToParent and addToParent == true then
    dir.dirCount = 0
    dir.dirs = {}
    dir.fileCount = 0
    dir.files = {}
    dir.textureSets = {}
    table.insert(parent.dirs, dir)
    parent.dirCount = parent.dirCount + 1
    var.dirCount = var.dirCount + 1
    selectDirectory(parent)
  end

  return dir
end

local function newFile(dir, path, fileName, fileType, simpleFileType)
  local file = {
    id = getUniqueId(),
    dir = dir,
    path = path,
    selected = false,
    fileName = fileName,
    fileType = fileType,
    fullFileName = fileName .. '.' .. fileType,
    simpleFileType = simpleFileType,
    inspectorData = nil
  }
  if tableContains(var.imageFileTypes, file.simpleFileType) then
    file.type = "image"
  elseif file.fileType == "materials.json" then
    file.open = false
    file.type = "materials"
  elseif file.simpleFileType == "json" then
    file.type = "json"
  elseif file.simpleFileType == "ter" then
    file.type = "terrain"
  elseif file.simpleFileType == "prefab" then
    file.type = "prefab"
  elseif file.simpleFileType == "cs" then
    file.type = "datablock"
  elseif file.simpleFileType == "dae" then
    file.type = "mesh"
  elseif file.simpleFileType == "html" then
    file.type = "html"
  elseif file.simpleFileType == "lua" then
    file.type = "lua"
  elseif file.simpleFileType == "txt" then
    file.type = "txt"
  elseif file.simpleFileType == "pc" then
    file.type = "part configuration"
  elseif file.simpleFileType == "jbeam" then
    file.type = "jbeam"
  else
    file.type = "asset"
  end
  return file
end

local function icon(file, size, col)
  local colVal = editor.getPreference("assetBrowser.general.fileTypeIconColor")
  col = col and col or im.ImColorByRGB(colVal.r, colVal.g, colVal.b, colVal.a).Value
  if file.type == 'image' then
    editor.uiIconImage(editor.icons.ab_asset_image, size, col)
  elseif file.type == 'json' then
    editor.uiIconImage(editor.icons.ab_asset_json, size, col)
  elseif file.type == 'materials' then
    editor.uiIconImage(editor.icons.ab_asset_material_json, size, col)
  elseif file.type == 'material' then
    editor.uiIconImage(editor.icons.ab_asset_material, size, col)
  elseif file.type == 'terrain' then
    editor.uiIconImage(editor.icons.ab_asset_ter, size, col)
  elseif file.type == 'prefab' then
    editor.uiIconImage(editor.icons.ab_asset_prefab, size, col)
  elseif file.type == 'datablock' then
    editor.uiIconImage(editor.icons.ab_asset_cs, size, col)
  elseif file.type == 'mesh' then
    editor.uiIconImage(editor.icons.ab_asset_mesh, size, col)
  elseif file.type == 'lua' then
    editor.uiIconImage(editor.icons.ab_asset_lua, size, col)
  elseif file.type == 'html' then
    editor.uiIconImage(editor.icons.ab_asset_html, size, col)
  elseif file.type == 'txt' then
    editor.uiIconImage(editor.icons.favorite, size, col)
  elseif file.type == 'asset' then
    editor.uiIconImage(editor.icons.favorite, size, col)
  elseif file.type == 'textureSet' then
    editor.uiIconImage(editor.icons.photo_library, size, col)
  elseif file.type == 'part configuration' then
    editor.uiIconImage(editor.icons.directions_car, size, col)
  elseif file.type == 'jbeam' then
    editor.uiIconImage(editor.icons.directions_car, size, col)
  else
    editor.logWarn(logTag .. "No suitable icon for type '" .. file.type .. "'. Using default icon.")
    editor.uiIconImage(editor.icons.favorite, size, col)
  end
end

local function enableAllFilterTypes()
  local simpleFileTypes = {}
  for k,type in ipairs(var.simpleFileTypes) do
    type.active[0] = true
    simpleFileTypes[type.label] = true
  end
  editor.setPreference("assetBrowser.general.simpleFileTypes", simpleFileTypes)
end

local function disableAllFilterTypes()
  for k,type in ipairs(var.simpleFileTypes) do
    type.active[0] = false
  end
  editor.setPreference("assetBrowser.general.simpleFileTypes", {})
end

local function openSearchFilter(filter)
  im.TextFilter_SetInputBuf(var.assetViewFilter, filter.filterInput )
  ffi.copy(var.assetViewFilter.InputBuf, filter.filterInput) --because SetInputBuf doesn't work here
  -- im.ImGuiTextFilter_Build(var.assetViewFilter)
  var.options.assetViewFilterType = filter.filterType
  var.options.filter_displayDirs = filter.displayDirs
  var.options.filter_displayAssets = filter.displayAssets
  var.options.filter_displayTextureSets = filter.displayTextureSets

  editor.setPreference("assetBrowser.general.assetViewFilterType", var.options.assetViewFilterType)
  editor.setPreference("assetBrowser.general.filter_displayDirs", var.options.filter_displayDirs)
  editor.setPreference("assetBrowser.general.filter_displayAssets", var.options.filter_displayAssets)
  editor.setPreference("assetBrowser.general.filter_displayTextureSets", var.options.filter_displayTextureSets)

  if filter.fileTypes then
    disableAllFilterTypes()
    local simpleFileTypes = {}
    for _,type in ipairs(filter.fileTypes) do
      for __, fileType in ipairs(var.simpleFileTypes) do
        if fileType.label == type then
          simpleFileTypes[fileType.label] = true
          fileType.active[0] = true
        end
      end
    end
    editor.setPreference("assetBrowser.general.simpleFileTypes", simpleFileTypes)
  else
    enableAllFilterTypes()
  end

  filterDirs()
  filterAssets()
end

local function saveSearchFilter(label, filterInput)
  for k,v in ipairs(var.options.savedFilter) do
    if v.label == label then
      editor.logWarn(logTag .. "Filter with the given identifier '" .. label .. "' already exists.")
      return false
    end
  end
  for k,v in ipairs(var.defaultFilter) do
    if v.label == label then
      editor.logWarn(logTag .. "Filter with the given identifier '" .. label .. "' already exists.")
      return false
    end
  end
  -- TODO: overwrite the current filter?

  local fileTypes = {}
  for k,type in ipairs(var.simpleFileTypes) do
    if type.active[0] == true then
      table.insert(fileTypes, type.label)
    end
  end
  table.insert(var.options.savedFilter, {
    label = label,
    filterInput = filterInput,
    filterType = var.options.assetViewFilterType,
    displayDirs = var.options.filter_displayDirs,
    displayAssets = var.options.filter_displayAssets,
    displayTextureSets = var.options.filter_displayTextureSets,
    fileTypes = fileTypes
  })
  var.saveFilterNameInput = im.ArrayChar(32)
  editor.setPreference("assetBrowser.general.savedFilter", var.options.savedFilter)
  return true
end

local function instantiateMesh(asset)
  local objectPosition

  if var.options.instantiateMeshInFrontOfCamera == true then
    local camPos = getCameraPosition()
    local camRight = getCameraRight()
    local camUp = getCameraUp()
    local camFwd = vec3(camUp.y * camRight.z - camUp.z * camRight.y, camUp.z * camRight.x - camUp.x * camRight.z, camUp.x * camRight.y - camUp.y * camRight.x)
    objectPosition = vec3(camPos.x + camFwd.x * 10, camPos.y + camFwd.y * 10, camPos.z + camFwd.z * 10)
  else
    objectPosition = vec3(0, 0, 0)
  end

  local newObj = createObject('TSStatic')
  newObj:setPosition(objectPosition)
  newObj:setField('shapeName', 0, asset.path)
  newObj.scale = vec3(1, 1, 1)
  newObj.useInstanceRenderData = true
  newObj:setField('instanceColor', 0, string.format("%g %g %g %g", 1, 1, 1, 1))
  newObj:setField('collisionType', 0, "Collision Mesh")
  newObj:setField('decalType', 0, "Collision Mesh")
  newObj.canSave = true
  newObj:registerObject('')

  editor.setDirty()
  local grp = scenetree.MissionGroup
  if grp then
    grp:addObject(newObj)
    editor.setDirty()
  else
    editor.logDebug("MissionGroup does not exist. Not able to add instantiated object to MissionGroup. Deleting object.")
    newObj:delete()
  end
end

local function doubleClickAsset(asset)
  if asset.type == "mesh" then
    instantiateMesh(asset)
  end
end

-- ##### FUNCTIONS - END

-- ##### DRAG'N'DROP
local function onDragStarted()
  -- editor.logInfo(logTag .. 'Drag started')
end

-- Create Object
local function createObjectRedo(actionData)
  -- deserialize object
  if actionData.objectId then
    SimObject.setForcedId(actionData.objectId)
    Sim.deserializeObjectsFromText(actionData.serializedData, true, true)
  end
end

local function createObjectUndo(actionData)
  local obj = Sim.findObjectById(actionData.objectId)
  if obj then
    actionData.serializedData = "[" .. obj:serialize(true, -1) .. "]"
    editor.deleteObject(actionData.objectId)
  end
end

local function onDragEnded(aborted)
  if var.dragDropMesh then
    if aborted == nil or aborted == false then
      if isWindowHovered() == false then
        editor.setDirty()
        local grp = scenetree.MissionGroup
        if grp then
          grp:addObject(var.dragDropMesh)
        else
          editor.logDebug("MissionGroup does not exist")
        end
        -- deselect object
        editor.selection["asset"].selectedInABView = false
        editor.selection["asset"].selected = false
        -- enable 'object select' once user has instantiated an object via drag'n'drop feature
        editor.selectObjects({var.dragDropMesh:getID()})
        editor.selectEditMode(editor.editModes.objectSelect)
        editor.history:commitAction("CreateObject", {objectId = var.dragDropMesh:getID()},
                                  createObjectUndo, createObjectRedo, true)
      end
    elseif aborted == true then
      var.dragDropMesh:delete()
    end
  end

  var.dragDropMesh = nil
  editor.assetDragDrop.data = nil
  editor.assetDragDrop.dragImage = nil
  editor.assetDragDrop.payload = nil
  var.dragging = var.dragging_enum.drag_ended
end

local function onDrag()
  if var.dragging == var.dragging_enum.no_drag then
    onDragStarted()
    var.dragging = var.dragging_enum.dragging
  end

  -- local rayCastFlags = im.flags(SOTTerrain)
  local rayCastFlags = im.flags(SOTTerrain, SOTWater, SOTStaticShape, SOTPlayer, SOTItem, SOTVehicle, SOTForest)

  if var.dragDropMesh then var.dragDropMesh:disableCollision() end
  local hit = cameraMouseRayCast(false, rayCastFlags)
  if var.dragDropMesh then var.dragDropMesh:enableCollision() end

  if hit and hit.pos
    and (editor.assetDragDrop.data.type == 'mesh'
      or editor.assetDragDrop.data.type == 'prefab') then
    if not var.dragDropMesh then
      if editor.assetDragDrop.data.type == 'mesh' then
        var.dragDropMesh = createObject('TSStatic')
        var.dragDropMesh:setField('shapeName', 0, editor.assetDragDrop.data.path)
        var.dragDropMesh.useInstanceRenderData = true
        var.dragDropMesh:setField('instanceColor', 0, string.format("%g %g %g %g", 1, 1, 1, 1))
        var.dragDropMesh:setField('collisionType', 0, "Collision Mesh")
        var.dragDropMesh:setField('decalType', 0, "Collision Mesh")
        var.dragDropMesh.canSave = true
      else
        if editor.assetDragDrop.data.type == 'prefab' then
          var.dragDropMesh = spawnPrefab(Sim.getUniqueName(editor.assetDragDrop.data.fileName), editor.assetDragDrop.data.path, "0 0 0", "1 0 0 0", "1 1 1")
          if var.dragDropMesh then
            var.dragDropMesh.loadMode = 0
            scenetree.MissionGroup:addObject(var.dragDropMesh.obj)
            local camDir = (quat(getCameraQuat()) * vec3(0,1,0)) * 10
            var.dragDropMesh.obj:setPosition(getCameraPosition() + camDir)
          end
        end
      end
      var.dragDropMesh.scale = vec3(1, 1, 1)
      var.dragDropMesh:registerObject('')
      local x,y,z,w = string.match(var.dragDropMesh:getField('rotation', '0'), "(%d+) (%d+) (%d+) (.+)")
      var.dragDropRotation = w

      draggedObjOffset = 0
      if editor.getPreference("snapping.terrain.enabled") then
        if editor.getPreference("snapping.terrain.snapToCenter") then
          -- Offset from obj pos to bb center
          draggedObjOffset = var.dragDropMesh:getWorldBox():getCenter().z - var.dragDropMesh:getPosition().z
        elseif editor.getPreference("snapping.terrain.snapToBB") then
          -- Offset from obj pos to bb bottom
          draggedObjOffset = (var.dragDropMesh:getWorldBox():getCenter().z - var.dragDropMesh:getPosition().z) -
                              var.dragDropMesh:getWorldBox():getExtents().z/2
        end
      end
    else
      if isWindowHovered() == true then
        var.dragDropMesh.hidden = true
      else
        var.dragDropMesh.hidden = false
        -- Change object's orientation when the user uses the mouse wheel while dragging an object.
        if var.io.MouseWheel ~= 0 then
          var.dragDropRotation = var.dragDropRotation + (var.io.MouseWheel * var.options.dragDropRotationMultiplier)
          var.dragDropMesh:setField('rotation', '0', string.format( "%f %f %f %f", 0, 0, 1, var.dragDropRotation))
        end
      end
    end
    -- var.dragDropMesh:setPosRot(hit.pos.x, hit.pos.y, hit.pos.z, 0, 0, 1, var.dragDropRotation)

    if editor.getPreference("snapping.terrain.enabled") and editor.getPreference("snapping.terrain.relRotation") then
      local rot = vec3(0,0,1):getRotationTo(vec3(hit.normal))
      var.dragDropMesh:setPosRot(hit.pos.x, hit.pos.y, hit.pos.z - draggedObjOffset, rot.x, rot.y, rot.z, rot.w)
    else
      var.dragDropMesh:setPosition(vec3(hit.pos.x, hit.pos.y, hit.pos.z - draggedObjOffset))
    end

    if editor.getPreference("snapping.general.snapToGrid") and editor.getPreference("snapping.grid.useLastObjectSelected") then
      if var.editorLastSelection then
        local obj = scenetree.findObjectById(var.editorLastSelection)
        if obj then
          var.dragDropMesh:setPosition(obj:getPosition())
        end
      end
    end

  end

  -- Cancel drag and drop action.
  -- if im.IsMouseClicked(1) then
  --   onDragEnded(true)
  -- end
end

local function dragDropSource(asset, pos)
  if var.dragging == var.dragging_enum.dragging then im.SetWindowFocus1() end

  if var.dragging == var.dragging_enum.drag_ended then return end

  if im.BeginDragDropSource(im.DragDropFlags_SourceAllowNullID) then
    if asset.ready == false then createAssetData(asset, true, true) end
    if not editor.assetDragDrop.data then editor.assetDragDrop.data = asset end
    if not editor.assetDragDrop.dragImage then
      if asset.type == 'image' then
        editor.assetDragDrop.dragImage = editor.texObj(asset.sourcefilename or asset.path)
      elseif asset.type == 'mesh' then
        if asset.inspectorData and asset.inspectorData.cachePath then
          editor.assetDragDrop.dragImage = editor.texObj(asset.inspectorData.cachePath)
        end
      end
    end
    im.SetDragDropPayload("ASSETDRAGDROP", editor.assetDragDrop.data.path, ffi.sizeof'char[2048]', im.Cond_Once)
    if (asset.type == 'image' or asset.type == 'mesh') and editor.assetDragDrop.dragImage and editor.assetDragDrop.dragImage.tex then
      local sizex = var.tooltipThumbnailSize.x
      local sizey = var.tooltipThumbnailSize.y
      if asset.type == 'image' then
        local img = editor.getTempTextureObj(asset.path)
        if img then
          local ratio = img.size.y / img.size.x
          sizex = var.tooltipThumbnailSize.x / ratio
          sizey = var.tooltipThumbnailSize.y
          -- check if size exceeds the maximum size so we do not display 16k preview images
          if sizex > var.maxTooltipThumbnailSize then
            local resizeRatio = sizex / var.maxTooltipThumbnailSize
            sizex = sizex / resizeRatio
            sizey = sizey / resizeRatio
          end
        end
      end
      im.Image(
        editor.assetDragDrop.dragImage.tex:getID(),
        im.ImVec2(sizex, sizey),
        nil, nil, nil,
        editor.color.white.Value
      )
  else
      im.TextUnformatted(asset.path)
    end
    onDrag()
    im.EndDragDropSource()
  end
end
-- ##### DRAG'N'DROP - END

-- ##### GUI: MAIN

-- ##### GUI: CONTEXT MENUS
local function directoryContextMenu(dir)
  if dir then
    if im.BeginPopup("Popup_" .. dir.path) then
      for _, entry in ipairs(var.directoryContextMenuEntries) do
        if entry.filterFn then
          if entry.filterFn() then
            if im.Selectable1(entry.name .. "##" .. dir.path) then
              entry.fn(dir)
              im.CloseCurrentPopup()
            end
          end
        else
          if im.Selectable1(entry.name .. "##" .. dir.path) then
            entry.fn(dir)
            im.CloseCurrentPopup()
          end
        end
      end
      im.EndPopup()
    end
  end
end

local function assetContextMenu(asset)
  if im.BeginPopup("Popup_" .. asset.path .. "_" .. asset.fullFileName) then
    for _, entry in ipairs(var.assetContextMenuEntries) do
      if entry.filterFn then
        if entry.filterFn(asset) then
          if im.Selectable1(entry.name .. "##" .. asset.path) then
            entry.fn(asset)
            im.CloseCurrentPopup()
          end
        end
      else
        if im.Selectable1(entry.name .. "##" .. asset.path) then
          entry.fn(asset)
          im.CloseCurrentPopup()
        end
      end
    end
    im.EndPopup()
  end
end

local function materialContextMenu(material)
  if im.BeginPopup("ContextMenu_Material_" .. tostring(material.id)) then
    for _, entry in ipairs(var.assetContextMenuEntries) do
      if entry.filterFn then
        if entry.filterFn(material) then
          if im.Selectable1(entry.name) then
            entry.fn(material)
            im.CloseCurrentPopup()
          end
        end
      else
        if im.Selectable1(entry.name) then
          entry.fn(material)
          im.CloseCurrentPopup()
        end
      end
    end
    im.EndPopup()
  end
end

local function textureSetContextMenu(set)
  if im.BeginPopup("Popup_" .. set.dir.path .. "_" .. set.name) then
    for _, entry in ipairs(var.textureSetContextMenuEntries) do
      if entry.filterFn then
        if entry.filterFn() then
          if im.Selectable1(entry.name .. "##" .. set.dir.path) then
            entry.fn(set)
            im.CloseCurrentPopup()
          end
        end
      else
        if im.Selectable1(entry.name .. "##" .. set.dir.path) then
          entry.fn(set)
          im.CloseCurrentPopup()
        end
      end
    end
    im.EndPopup()
  end
end
-- ##### GUI: CONTEXT MENUS END

-- ##### GUI: DIRECTORY VIEW
local function removeSavedFilter(index)
  table.remove(var.options.savedFilter, index)
  editor.setPreference("assetBrowser.general.savedFilter", var.options.savedFilter)
end

local function savedFilterItem(index, item, contextMenu, defaultFilter)
  if im.BeginPopup("Popup_Filter_" .. item.label) then
    -- TODO: add button to rename item
    if im.SmallButton("Remove" .. "##Filter_" .. item.label) then
      removeSavedFilter(index)
      im.CloseCurrentPopup()
    end
    im.EndPopup()
  end
  editor.uiIconImage((defaultFilter) and editor.icons.blur_circular or editor.icons.radio_button_unchecked, var.iconSize, editor.color.gold.Value)
  im.SameLine()
  im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value) -- set SmallButton's background color to transparent
  if im.SmallButton(item.label) then
    openSearchFilter(item)
  end
  im.PopStyleColor()
  local tooltip = "filter: " .. ((item.filterInput == "") and '-' or item.filterInput) .. "\nsource: " .. ((item.filterType == 1) and "global" or "directory") .. "\nfiletypes: "
  if item.fileTypes then
    for _,type in ipairs(item.fileTypes) do
      tooltip = tooltip .. "\n* " .. type
    end
  else
    for _,type in ipairs(var.simpleFileTypes) do
      tooltip = tooltip .. "\n* " .. type.label
    end
  end
  -- TODO: Limit popup size since it can exceed the game's window bounds.
  --       Either draw a custom popup or make it selectable and show its properties in the inspector.
  -- im.SetNextWindowSize(im.ImVec2(0, im.GetContentRegionAvail().y))
  im.tooltip(tooltip)
  if contextMenu == true then
    if im.IsItemHovered() and im.IsItemClicked(1) then
      im.OpenPopup("Popup_Filter_" .. item.label)
    end
  end
end

local function showSavedSearches()
  local subFolderArrowIcon = var.savedSearchesOpen and editor.icons.keyboard_arrow_down or editor.icons.keyboard_arrow_right
  local cPosX = im.GetCursorPosX()
  im.PushStyleColor2(im.Col_Button, im.ImVec4(0, 0, 0, 0))
  if editor.uiIconImageButton(subFolderArrowIcon, var.iconSize, im.ImVec4(1, 1, 1, 1), nil) then
    var.savedSearchesOpen = not var.savedSearchesOpen
  end
  im.SameLine()
  im.SetCursorPosX(cPosX + var.iconSize.x)
  editor.uiIconImage(editor.icons.star_border, var.iconSize, editor.color.gold.Value)
  im.SameLine()
  if im.SmallButton("Saved Filter") then
    var.savedSearchesOpen = not var.savedSearchesOpen
  end
  im.PopStyleColor()
  im.ShowHelpMarker("Hit RMB on one of your saved filters in order to open a context menu", true)
  if var.savedSearchesOpen == true then
    im.Indent(var.iconSize.x + var.style.ItemSpacing.x)
    for index, item in pairs(var.defaultFilter) do
      savedFilterItem(index, item,nil, true)
    end
    for index, item in pairs(var.options.savedFilter) do
      savedFilterItem(index, item, true)
    end
    im.Unindent(var.iconSize.x + var.style.ItemSpacing.x)
  end
  im.Separator()
end

local function showDirectoryInTreeView(dir)
  if not dir then return end
  directoryContextMenu(dir)

  var.listIndexCounter = var.listIndexCounter + 1
  dir.listIndex = var.listIndexCounter
  local hasSubDirs = dir.dirs and #dir.dirs > 0 or false
  im.PushStyleColor2(im.Col_Button, im.ImVec4(0, 0, 0, 0))
  if not hasSubDirs then im.PushStyleColor2(im.Col_ButtonHovered, im.ImVec4(0, 0, 0, 0)) end
  local subFolderArrowIcon = dir.open and editor.icons.keyboard_arrow_down or editor.icons.keyboard_arrow_right
  local cPosX = im.GetCursorPosX()
  if editor.uiIconImageButton(subFolderArrowIcon, var.iconSize, hasSubDirs and im.ImVec4(1, 1, 1, 1) or im.ImVec4(0, 0, 0, 0), nil) then
    if hasSubDirs then
      selectDirectory(dir, true, nil, true)
    end
  end
  im.PopStyleColor(hasSubDirs and 1 or 2)
  im.SameLine()
  im.SetCursorPosX(cPosX + var.iconSize.x)
  if dir.open == true then
    if dir.selected == true then
      if var.setTreeViewScroll == true then
        var.setTreeViewScroll = false
        var.treeViewScrollPos = im.GetCursorPosY()
      end
      editor.uiIconImage(editor.icons.folder_open, var.iconSize, im.GetStyleColorVec4(im.Col_ButtonActive))
    else
      editor.uiIconImage(editor.icons.folder_open, var.iconSize)
    end
  else
    editor.uiIconImage(editor.icons.folder, var.iconSize, dir.selected == true and im.GetStyleColorVec4(im.Col_ButtonActive) or nil)
  end
  im.SameLine()
  im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value) -- set SmallButton's background color to transparent
  if dir.selected == true then
    if not var.currentListIndex then var.currentListIndex = var.listIndexCounter end
    im.PushStyleColor2(im.Col_Text, im.GetStyleColorVec4(im.Col_ButtonActive))
  else
    im.PushStyleColor2(im.Col_Text, editor.color.white.Value)
  end
  local itemDoubleClicked = false
  if im.SmallButton(dir.name .. "##" .. tostring(dir.id)) then
    var.currentListIndex = var.listIndexCounter
    var.arrowNavValueChanged = true
  end
  im.PopStyleColor(2)
  if im.IsItemClicked(1) then
    selectDirectory(dir, nil, nil, true)
    im.OpenPopup("Popup_" .. dir.path)
  end
  if im.IsItemHovered() and im.IsMouseDoubleClicked(0) then
    var.currentListIndex = var.listIndexCounter
    var.arrowNavValueChanged = true
    itemDoubleClicked = true;
  end

  if (var.listIndexCounter == var.currentListIndex and var.arrowNavValueChanged) then
    var.arrowNavValueChanged = false
    if db == true then
      selectDirectoryDB(dir, itemDoubleClicked)
    else
      selectDirectory(dir, itemDoubleClicked, nil, true)
    end
  end
  if dir.open then
    im.Indent(editor.getPreference("assetBrowser.general.treeViewIndentationWidth"))
    for _,dir in ipairs(dir.dirs) do
      showDirectoryInTreeView(dir)
    end
    im.Unindent(editor.getPreference("assetBrowser.general.treeViewIndentationWidth"))
  end
end

local function newFolderPopup()
  if im.BeginPopup("new_folder_popup") then
    local clearVars = function()
      ffi.copy(var.newFolderName, "")
      var.newFolderMessages = {}
      var.newFolderParentDir = nil
    end

    local createFolder = function()
      if var.selectedDirectory or var.newFolderParentDir then
        var.newFolderParentDir = var.newFolderParentDir or var.selectedDirectory
        local name = ffi.string(var.newFolderName)
        local path = var.newFolderParentDir.path .. name
        if not FS:directoryExists(path) then
          if FS:directoryCreate(path, true)  == 0 then
            newDirectory(path, name, var.newFolderParentDir, false, false, true)
            clearVars()
            im.CloseCurrentPopup()
          end
        else
          editor.logDebug(logTag .. "Cannot create folder, folder already exists.")
          var.newFolderMessages['folderExists'] = {
            color = im.ImVec4(1, 0.8, 0, 1),
            text = "Folder already exists!"
          }
        end
      end
    end

    im.PushItemWidth(200)
    im.TextUnformatted("Create new folder")
    if im.InputText("##NewFolderName", var.newFolderName, nil, im.flags(im.InputTextFlags_EnterReturnsTrue)) then
      createFolder()
    end
    for _, message in pairs(var.newFolderMessages) do
      im.TextColored(message.color, message.text)
    end
    im.PopItemWidth()
    if im.Button("Cancel") then
      ffi.copy(var.newFolderName, "")
      clearVars()
      im.CloseCurrentPopup()
    end
    im.SameLine()
    if im.Button("Create") then
      createFolder()
    end
    im.EndPopup()
  end
end

local function treeViewMainPanel()
  if im.BeginChild1("File Tree Child", nil, true) then
    if (aM and aM.isReady() == true) or db == false then
      if var.treeViewScrollPos then
        im.SetScrollY(var.treeViewScrollPos)
        var.treeViewScrollPos = nil
      end
      if var.state == var.state_enum.loading_done then
        var.listIndexCounter = 0
        showSavedSearches()
        showDirectoryInTreeView(var.root)
        showDirectoryInTreeView(var.commonArt)
        showDirectoryInTreeView(var.gameplay)
        showDirectoryInTreeView(var.vehicles)
        showDirectoryInTreeView(var.allData)
        var.maxListIndexVal = var.listIndexCounter

        newFolderPopup()

        if var.newFolderModalOpen == true then
          im.OpenPopup("new_folder_popup")
          var.newFolderModalOpen = false
        end
      end
    else
      im.TextUnformatted("Refreshing DB!")
      if aM then
        im.TextUnformatted(string.format( "%.2f", aM.getProgress().progress*100) .. " %" )
      end
    end
  end
  im.EndChild()
end
-- ##### GUI: DIRECTORY VIEW - END

local function setScrollBarValue()
  if var.io.MouseWheel > 0 then
    var.scrollY = var.scrollY - math.ceil(var.io.MouseWheel) * var.options.scrollSpeed
  elseif var.io.MouseWheel < 0 then
    var.scrollY = var.scrollY - math.floor(var.io.MouseWheel) * var.options.scrollSpeed
  end
  if var.scrollY < 0 then
    var.scrollY = 0
  elseif var.scrollY > var.assetViewScrollMax then
    var.scrollY = var.assetViewScrollMax
  end
end

-- ##### GUI: ASSET VIEW
local function displayDirectoryInAssetView(dir, childSize, parentDir, newLine)
  directoryContextMenu(dir)
  if childSize == -1 then
    editor.uiIconImage(editor.icons.folder, var.iconSize)
    im.SameLine()
    im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value) -- set SmallButton's background color to transparent
    -- [debug]
    -- im.SmallButton((parentDir == true) and ("[...]##parentDir" .. dir.path) or (tostring(im.GetCursorPosY()) .. " " .. dir.name .. "##" .. dir.path))
    if dir.selectedInABView == true then im.PushStyleColor2(im.Col_Text, im.GetStyleColorVec4(im.Col_ButtonActive)) end -- set SmallButton's font color to if the asset is selected
    im.SmallButton((parentDir == true) and ("[...]##parentDir" .. dir.id) or (dir.name .. "##" .. dir.id))
    im.PopStyleColor((dir.selectedInABView == true) and 2 or 1)
    if im.IsItemClicked(0) then
      selectAsset(dir)
    elseif im.IsItemClicked(1) then
      selectAsset(dir)
      var.newFolderParentDir = dir
      im.OpenPopup("Popup_" .. dir.path)
    end
    if im.IsItemHovered() == true then
      var.assetHovered = true
      if var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
        im.BeginTooltip()
          im.TextUnformatted(dir.path)
        im.EndTooltip()
      end
      if im.IsMouseDoubleClicked(0) then
        var.currentListIndex = dir.listIndex
        if db == true then
          selectDirectoryDB(dir, nil, true)
        else
          selectDirectory(dir, nil, true, true)
        end
      end
    end
  else
    if im.BeginChild1("Child_" .. dir.path .. "_" .. dir.name, childSize, true, im.flags(im.WindowFlags_NoScrollWithMouse)) then
      -- icon size should depend on child size and is the minimum between
      -- the unscaled unpadded horizontal size and the undpadded vertical size with the label removed.
      -- TODO: defaultUiScale could be made a default value for the preference
      local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale;
      local thumbSize = math.min(
        (childSize.x - 2 * var.style.WindowPadding.x) / uiScaling,
        (childSize.y - 2 * var.style.WindowPadding.y - var.style.ItemSpacing.x - var.fontSize - 5) / uiScaling
      )
      editor.uiIconImage(editor.icons.folder, im.ImVec2(thumbSize, thumbSize))
      local dirName = (parentDir == true) and "[...]" or dir.name
      if dir.selectedInABView then
        im.TextColored(im.GetStyleColorVec4(im.Col_ButtonActive), dirName)
      else
        im.TextUnformatted(dirName)
      end
    end
    im.EndChild()
    if im.IsItemHovered() then
      setScrollBarValue()
    end
    if im.IsItemClicked(0) then
      selectAsset(dir)
    elseif im.IsItemClicked(1) then
      im.OpenPopup("Popup_" .. dir.path)
    end
    if im.IsItemHovered() == true and im.IsMouseDoubleClicked(0) == true then
      var.currentListIndex = dir.listIndex
      if db == true then
        selectDirectoryDB(dir, nil, true)
      else
        selectDirectory(dir, nil, true, true)
      end
    end
    im.tooltip(dir.name)

    im.SameLine()
    if im.GetContentRegionAvailWidth() < childSize.x or (newLine and newLine == true) then
      im.NewLine()
    end
  end
  -- [debug]
  var.displayedItemsCount = var.displayedItemsCount + 1
end

local function textureSetTooltip(set)
  im.BeginTooltip()
  if var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files then
    im.TextUnformatted(set.name)
  elseif var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
    im.TextUnformatted(set.dir.path .. set.name)
  end
  local img = nil
  local ratio = nil

  local function textureSetTooltipImg(asset)
    img = editor.getTempTextureObj(asset.path)
    if img and img.size.x > 0 and img.size.y > 0 then
      ratio = img.size.y / img.size.x
      local sizex = var.tooltipThumbnailSize.x / ratio
      local sizey = var.tooltipThumbnailSize.y
      -- check if size exceeds the maximum size so we do not display 16k preview images
      if sizex > var.maxTooltipThumbnailSize then
        local resizeRatio = sizex / var.maxTooltipThumbnailSize
        sizex = sizex / resizeRatio
        sizey = sizey / resizeRatio
      end
      im.Image(
        img.tex:getID(),
        im.ImVec2(sizex, sizey),
        nil, nil, nil,
        editor.color.white.Value
      )
    end
  end
  -- diffuse
  if set.d then
    textureSetTooltipImg(set.d)
  end
  -- normal
  if set.n then
    textureSetTooltipImg(set.n)
  end
  -- specular
  if set.s then
    textureSetTooltipImg(set.s)
  end
  im.EndTooltip()
end

local function displayTextureSetInAssetView(set, childSize, newLine)
  textureSetContextMenu(set)

  if childSize == -1 then
    if set.selectedInABView then
      editor.uiIconImage(editor.icons.photo_library, var.iconSize, im.GetStyleColorVec4(im.Col_ButtonActive))
    else
      editor.uiIconImage(editor.icons.photo_library, var.iconSize)
    end
    im.SameLine()
    im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value) -- set SmallButton's background color to transparent
    if set.selectedInABView == true then im.PushStyleColor2(im.Col_Text, im.GetStyleColorVec4(im.Col_ButtonActive)) end -- set SmallButton's font color to if the asset is selected
    im.SmallButton(set.name .. "##_" .. set.path)
    im.PopStyleColor((set.selectedInABView == true) and 2 or 1)

    -- TODO: add drag'n'drop for texture sets
    -- e.g. automatically populate material editor's texture maps
    -- dragDropSource(file)
    if im.IsItemHovered() then
      if var.options.showThumbnailWhenHoveringAsset == true then
        textureSetTooltip(set)
      end
    end

    if im.IsItemClicked(0) then
      selectAsset(set)
    elseif im.IsItemClicked(1) then
      im.OpenPopup("Popup_" .. set.dir.path .. "_" .. set.name)
    end
  else
    if im.BeginChild1("AssetViewTextureSetChild_" .. set.name .. "_" .. set.path, childSize, true, im.flags(im.WindowFlags_NoScrollWithMouse, im.WindowFlags_NoScrollbar)) then
      -- dragDropSource(file, var.windowPos)
      local cursorPos = im.GetCursorPos()
      local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale;
      local imgSize = im.ImVec2(var.options.thumbnailSize * uiScaling - 5, var.options.thumbnailSize * uiScaling - 5)
      if set.d then
        im.Image(editor.getTempTextureObj(set.d.path).tex:getID(), imgSize, nil, nil, nil, editor.color.white.Value)
      elseif set.n then
        im.Image(editor.getTempTextureObj(set.n.path).tex:getID(), imgSize, nil, nil, nil, editor.color.white.Value)
      elseif set.s then
        im.Image(editor.getTempTextureObj(set.s.path).tex:getID(), imgSize, nil, nil, nil, editor.color.white.Value)
      else
        editor.uiIconImage(editor.icons.photo_library, im.ImVec2(var.options.thumbnailSize, var.options.thumbnailSize))
      end

      im.TextUnformatted(set.name)
      im.SetCursorPos(cursorPos)
      icon(set, im.ImVec2(var.options.thumbnailSize/4, var.options.thumbnailSize/4), im.GetStyleColorVec4(im.Col_Text))
      -- if file.selected then im.TextColored(im.GetStyleColorVec4(im.Col_ButtonActive), file.fullFileName) else im.TextUnformatted(file.fullFileName) end
    end
    im.EndChild()

    if im.IsItemHovered() then
      setScrollBarValue()
      var.assetHovered = true
      textureSetTooltip(set)
    end
    if im.IsItemClicked(0) then
      selectAsset(set)
    elseif im.IsItemClicked(1) then
      im.OpenPopup("Popup_" .. set.dir.path .. "_" .. set.name)
    end

    im.SameLine()
    if im.GetContentRegionAvailWidth() < childSize.x or (newLine and newLine == true) then
      im.NewLine()
    end
  end
  -- [debug]
  var.displayedItemsCount = var.displayedItemsCount + 1
end

local function displayMaterialInAssetView(material, childSize, newLine)
  materialContextMenu(material)

  if childSize == -1 then
    icon(material, var.iconSize, (material.selectedInABView == true and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Text)))
    im.SameLine()
    im.PushStyleColor2(im.Col_Text, (material.selectedInABView == true and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Text)))
    -- Set SmallButton's background color to transparent.
    im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value)
    -- [Debug]
    -- im.SmallButton(tostring(var.itemPos) .. " " .. tostring(im.GetCursorPosY()) .. " " .. material.fullFileName)
    if im.SmallButton(material.name) then
      selectAsset(material)
    end
    im.PopStyleColor(2)
  else
    im.SameLine()
    if im.GetContentRegionAvailWidth() < childSize.x then
      im.NewLine()
    end

    if im.BeginChild1("AssetViewChild_" .. material.name .. "_" .. material.id, childSize, true, im.flags(im.WindowFlags_NoScrollWithMouse, im.WindowFlags_NoScrollbar)) then
      icon(material, im.ImVec2(var.options.thumbnailSize, var.options.thumbnailSize), nil)
    end
    if material.selectedInABView then im.TextColored(im.GetStyleColorVec4(im.Col_ButtonActive), material.name) else im.TextUnformatted(material.name) end
    im.EndChild()

    if im.IsItemHovered() then
      setScrollBarValue()
      im.tooltip(material.name)
    end

    if im.IsItemClicked(0) then
      selectAsset(material)
    elseif im.IsItemClicked(1) then
      im.OpenPopup("ContextMenu_Material_" .. tostring(material.id))
    end

    im.SameLine()
    if im.GetContentRegionAvailWidth() < childSize.x or (newLine and newLine == true) then
      im.NewLine()
    end
  end
  -- [debug]
  var.displayedItemsCount = var.displayedItemsCount + 1
end

local function displayAssetInAssetView(file, childSize, newLine)
  assetContextMenu(file)

  -- Display assets in a list view.
  if childSize == -1 then
    if file.selectedInABView then
      icon(file, var.iconSize, im.GetStyleColorVec4(im.Col_ButtonActive))
    else
      icon(file, var.iconSize, im.GetStyleColorVec4(im.Col_Text))
    end
    im.SameLine()

    if file.type == "materials" then
      local startCursorPos = im.GetCursorPos()
      im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value)
      if editor.uiIconImageButton(file.open
          and editor.icons.keyboard_arrow_down
          or editor.icons.keyboard_arrow_right,
        im.ImVec2(var.minThumbnailSize, var.minThumbnailSize), nil, nil, nil, "##" .. file.id
      ) then
        file.open = not file.open
        if file.open == true then
          createInspectorData(file)
        end
      end
      im.SetCursorPos(im.ImVec2(startCursorPos.x + var.minThumbnailSize, startCursorPos.y))
      local buttonWidth = im.CalcTextSize(file.fullFileName).x + 2 * var.style.FramePadding.x
      if im.Button("##" .. tostring(file.id), im.ImVec2(buttonWidth,var.fontSize)) then
        selectAsset(file)
      end
      im.PopStyleColor()
      im.SetCursorPos(im.ImVec2(startCursorPos.x + var.minThumbnailSize + var.style.FramePadding.x, startCursorPos.y))
      if file.selectedInABView == true then im.PushStyleColor2(im.Col_Text, im.GetStyleColorVec4(im.Col_ButtonActive)) end
      im.TextUnformatted(file.fullFileName)
      if file.selectedInABView == true then im.PopStyleColor(1) end

      if file.open == true then
        if file.inspectorData then
          im.Indent()
          -- Set SmallButton's background color to transparent.
          im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value)
          for name, material in pairs(file.inspectorData.materials) do
            displayMaterialInAssetView(material, childSize)
          end
          im.PopStyleColor()
          im.Unindent()
        end
      end
    else
      -- Set SmallButton's font color if the asset is selected.
      if file.selectedInABView == true then im.PushStyleColor2(im.Col_Text, im.GetStyleColorVec4(im.Col_ButtonActive)) end
      -- Set SmallButton's background color to transparent.
      im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value)
      im.SmallButton(file.fullFileName)
      im.PopStyleColor((file.selectedInABView == true) and 2 or 1)
    end

    dragDropSource(file)
    if im.IsItemHovered() then
      var.assetHovered = true
      -- Double click on asset in the asset view.
      if im.IsMouseDoubleClicked(0) then
        doubleClickAsset(file)
      -- LMB
      elseif im.IsMouseClicked(0) then
        selectAsset(file)
      -- RMB
      elseif im.IsMouseClicked(1) then
        im.OpenPopup("Popup_" .. file.path .. "_" .. file.fullFileName)
      end

      local function imgTooltip(path)
        local img = editor.getTempTextureObj(path)
        if img and img.size.x > 0 and img.size.y > 0 then
          local ratio = img.size.y / img.size.x
          local sizex = var.tooltipThumbnailSize.x / ratio
          local sizey = var.tooltipThumbnailSize.y
          -- check if size exceeds the maximum size so we do not display 16k preview images
          if sizex > var.maxTooltipThumbnailSize then
            local resizeRatio = sizex / var.maxTooltipThumbnailSize
            sizex = sizex / resizeRatio
            sizey = sizey / resizeRatio
          end
          im.Image(
            editor.getTempTextureObj(path).tex:getID(),
            im.ImVec2(sizex, sizey),
            nil, nil, nil,
            editor.color.white.Value
          )
        end
      end

      if var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files then
        if (file.type == "image" or file.type == "mesh") and var.options.showThumbnailWhenHoveringAsset == true then
          if file.type == "image" then
            im.BeginTooltip()
              imgTooltip(file.path)
            im.EndTooltip()
          end
          if file.type == "mesh" and file.inspectorData and file.inspectorData.cachePath then
            im.BeginTooltip()
              imgTooltip(file.inspectorData.cachePath)
            im.EndTooltip()
          end
        end
      elseif var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
        im.BeginTooltip()
          im.TextUnformatted(file.path)
          if file.type == 'image' and var.options.showThumbnailWhenHoveringAsset == true then
            imgTooltip(file)
          end
        im.EndTooltip()
      end
    end

    if im.IsItemClicked(0) then
      selectAsset(file)
    elseif im.IsItemClicked(1) then
      im.OpenPopup("Popup_" .. file.path .. "_" .. file.fullFileName)
    end

  -- Display assets with thumbnails side by side.
  else
    if im.BeginChild1("AssetViewChild_" .. file.path .. "_" .. file.fullFileName, childSize, true, im.flags(im.WindowFlags_NoScrollWithMouse, im.WindowFlags_NoScrollbar)) then
      dragDropSource(file, var.windowPos)
      local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale
      local colorCodePos = im.GetCursorPos()
      if file.type == "image" then
        local topLeft = im.GetCursorPos()
        im.Image(
          editor.getTempTextureObj(file.path or "").tex:getID(),
          im.ImVec2(var.options.thumbnailSize * uiScaling - 5, var.options.thumbnailSize * uiScaling - 5),
          nil, nil, nil,
          editor.color.white.Value
        )
        local botRight = im.GetCursorPos()
        -- Draw an icon based on its type in the top left corner of the child.
        im.SetCursorPos(topLeft)
        icon(file, im.ImVec2(var.options.thumbnailSize/4, var.options.thumbnailSize/4))
        im.SetCursorPos(botRight)
      elseif file.type == "mesh" and file.inspectorData and file.inspectorData.cachePath then
        local topLeft = im.GetCursorPos()
        im.Image(
          editor.getTempTextureObj(file.inspectorData.cachePath).tex:getID(),
          im.ImVec2(var.options.thumbnailSize * uiScaling - 5, var.options.thumbnailSize * uiScaling - 5),
          nil, nil, nil,
          editor.color.white.Value
        )
        local botRight = im.GetCursorPos()
        -- Draw an icon based on its type in the top left corner of the child.
        im.SetCursorPos(topLeft)
        icon(file, im.ImVec2(var.options.thumbnailSize/4, var.options.thumbnailSize/4))
        im.SetCursorPos(botRight)
      elseif file.type == "materials" then
        icon(file, im.ImVec2(var.options.thumbnailSize, var.options.thumbnailSize), (file.selectedInABView == true and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Text)))
        local oldPos = im.GetCursorPos()
        im.SameLine()
        local cpos = im.GetCursorPos()
        im.SetCursorPos(im.ImVec2(cpos.x-var.style.WindowPadding.x-var.minThumbnailSize, cpos.y))
        im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0,0,0.1))
        if editor.uiIconImageButton(file.open == true
            and editor.icons.keyboard_arrow_left
            or editor.icons.keyboard_arrow_right, im.ImVec2(var.minThumbnailSize, var.minThumbnailSize), nil, nil, nil, "##" .. file.id) then
          file.open = not file.open
        end
        im.PopStyleColor()
        im.SetCursorPos(oldPos)
      else
        icon(file, im.ImVec2(var.options.thumbnailSize, var.options.thumbnailSize), (file.selectedInABView == true and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Text)))
      end

      -- color code bar that indicates the type of the asset
      if editor.getPreference("assetBrowser.general.displayAssetColorCode") then
        local winPos = im.GetWindowPos()
        local actualThumbnailSize = var.options.thumbnailSize * (editor.getPreference("ui.general.scale") or defaultUiScale)
        local colorCodePosA = im.ImVec2(winPos.x + colorCodePos.x, winPos.y + colorCodePos.y + actualThumbnailSize - var.assetColorCodeHeight)
        -- => -2 = minus border
        local colorCodePosB = im.ImVec2(winPos.x + colorCodePos.x + actualThumbnailSize - 3, winPos.y + colorCodePos.y + actualThumbnailSize - var.assetColorCodeHeight)

        im.ImDrawList_AddLine(im.GetWindowDrawList(), colorCodePosA, colorCodePosB, getAssetTypeColor(file), var.assetColorCodeHeight)
      end

      if file.selectedInABView then
        im.TextColored(im.GetStyleColorVec4(im.Col_ButtonActive),file.fullFileName)
      else
        im.TextUnformatted(file.fullFileName)
      end
    end
    im.EndChild()

    if im.IsItemHovered() then
      setScrollBarValue()
      var.assetHovered = true
      if var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files then
        im.tooltip(file.fullFileName)
      elseif var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
        im.tooltip(file.path)
      end

      -- Double click on asset in the asset view.
      if im.IsMouseDoubleClicked(0) then
        doubleClickAsset(file)
      -- LMB
      elseif im.IsMouseClicked(0) then
        selectAsset(file)
      -- RMB
      elseif im.IsMouseClicked(1) then
        im.OpenPopup("Popup_" .. file.path .. "_" .. file.fullFileName)
      end
    end

    if editor.IsItemDoubleClicked(0) and file.type == "materials" then
      file.open = not file.open
    end

    if file.type == "materials" then
      if file.inspectorData then
        if file.open == true and file.inspectorData.materials then
          for k, material in pairs(file.inspectorData.materials) do
            displayMaterialInAssetView(material, childSize)
          end
        end
      else
        createInspectorData(file, true)
      end
    end

    im.SameLine()
    if im.GetContentRegionAvailWidth() < childSize.x or (newLine and newLine == true) then
      im.NewLine()
    end
  end
  -- [debug]
  var.displayedItemsCount = var.displayedItemsCount + 1
end

local function isAssetVisible(childSize)
  -- Disable virtual scrolling for the time being if the thumbnail size ~= min thumbbnail size.
  if childSize ~= -1 then return true end

  if (im.GetCursorPosY() + (childSize == -1 and var.fontSize or childSize.y)) < im.GetScrollY() then
    -- Set cursor to next asset pos - skip rendering it.
    if childSize == -1 then
      im.SetCursorPosY(im.GetCursorPosY() + var.fontSize + var.style.ItemSpacing.y)
    elseif var.itemPos % var.horizontalItems == 0 then
      im.SetCursorPosY(im.GetCursorPosY() + childSize.y + var.style.ItemSpacing.y)
    end
    return false
  else
    -- Asset is within viewable area.
    if im.GetCursorPosY() < (im.GetScrollY() + im.GetWindowHeight()) and im.GetCursorPosY() then
      return true
    else
      return false
    end
  end
end

local function displayDirectories(directories, childSize)
  for k, dir in ipairs(directories) do
    -- Display assets in case it's in the visible area of the view panel.
    if isAssetVisible(childSize) == true then
      displayDirectoryInAssetView(dir, childSize, nil, (k == #directories and var.options.assetGroupingType ~= var.assetGroupingTypes_enum.none) and true or nil)
    end
    var.itemPos = var.itemPos + 1
  end
end

local function displayTextureSets(textureSets, childSize)
  for k, set in ipairs(textureSets) do
    -- Display assets in case it's in the visible area of the view panel.
    if isAssetVisible(childSize) == true then
      displayTextureSetInAssetView(set, childSize, (k == #textureSets and var.options.assetGroupingType ~= var.assetGroupingTypes_enum.none) and true or nil)
    end
    var.itemPos = var.itemPos + 1
  end
end

local function displayAssets(assets, childSize)
  for k, asset in ipairs(assets) do
    -- Display assets in case it's in the visible area of the view panel.
    if isAssetVisible(childSize) == true then
      displayAssetInAssetView(asset, childSize, (k == #assets and var.options.assetGroupingType ~= var.assetGroupingTypes_enum.none) and true or nil)
    end
    var.itemPos = var.itemPos + 1
  end
end

-- Draw a group header and return true if it's open so we can display the assets within it.
local function groupCollapsingHeader(group)
  local cPosStart = im.GetCursorPos()
  if im.Button("##" .. group.identifier .. "_CollapsingHeader", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
    group.open = not group.open
  end
  local cPosEnd = im.GetCursorPos()

  im.SetCursorPos(im.ImVec2(cPosStart.x + var.style.FramePadding.x, cPosStart.y + var.style.FramePadding.y))
  -- Draw arrow indicating whether the collapsing header is open or not and the group identifier within the button.
  editor.uiIconImage(group.open == true and editor.icons.keyboard_arrow_down or editor.icons.keyboard_arrow_right, im.ImVec2(var.fontSize, var.fontSize))
  im.SetCursorPos(im.ImVec2(cPosStart.x + var.fontSize + 3 * var.style.FramePadding.x, cPosStart.y + var.style.FramePadding.y))
  im.TextUnformatted(group.identifier .. " (" .. tostring(#var.filteredAssetGroups[group.identifier]) .. ")")
  im.SetCursorPos(cPosEnd)

  return group.open
end

local function getHorizontalItemsCount(childWidth, widthAvailable)
  local itemsCount = 0
  local width = childWidth
  while width < widthAvailable do
    width = width + childWidth + var.style.ItemSpacing.x
    itemsCount = itemsCount + 1
  end
  return itemsCount
end

local function getGroupHeight(group, childSize)
  local height = 0
  if childSize == -1 then
    if (group.identifier == "folders" and #var.filteredAssetGroups.folders > 0 and var.options.filter_displayDirs) or (group.identifier ~= "folders" and var.options.filter_displayAssets) then
      -- Add group's CollapsingHeader height
      height = height + var.fontSize + 2 * var.style.FramePadding.y + (var.style.ItemSpacing.y - 1)
      -- Add height of all asset in this group if open
      if group.open == true then
        height = height + (#var.filteredAssetGroups[group.identifier] * (var.fontSize + var.style.ItemSpacing.y))
      end
    end
  else
    if (group.identifier == "folders" and #var.filteredAssetGroups.folders > 0 and var.options.filter_displayDirs) or (group.identifier ~= "folders" and var.options.filter_displayAssets) then
      -- Add group's CollapsingHeader height
      height = height + var.fontSize + 2 * var.style.FramePadding.y
      if group.open == true then
        -- Add height of all asset in this group
        local vertItems = math.ceil(#var.filteredAssetGroups[group.identifier] / var.horizontalItems)
        height = height + (vertItems * (childSize.y + var.style.ItemSpacing.y))
      end
    end
  end
  return height
end

local function getAssetViewMainPanelHeight(childSize)
  local height = 0
  if childSize == -1 then
    -- No asset grouping.
    if var.options.assetGroupingType == var.assetGroupingTypes_enum.none then
      height = (var.verticalItems * var.fontSize + (var.verticalItems - 1) * var.style.ItemSpacing.y) + var.style.WindowPadding.y

    -- Asset grouping enabled.
    else
      height = var.style.WindowPadding.y

      for _, group in ipairs(var.filteredAssetGroupsSorted) do
        height = height + getGroupHeight(group, childSize)
      end
      height = height - var.style.ItemSpacing.y
    end
  else
    -- No asset grouping.
    if var.options.assetGroupingType == var.assetGroupingTypes_enum.none then
      height = var.verticalItems * childSize.y + (var.verticalItems - 1) * var.style.ItemSpacing.y + var.style.WindowPadding.y

    -- Asset grouping enabled.
    else
      height = var.style.WindowPadding.y

      for _, group in ipairs(var.filteredAssetGroupsSorted) do
        height = height + getGroupHeight(group, childSize)
      end

      height = height - var.style.ItemSpacing.y
    end
  end
  return height
end

--  Get a list of displayed of displayed filtered items in selected directory
--  @returns table
local function getDisplayedSelectedDirectoryFilteredList()
  local filteredList = {}
  if var.selectedDirectory ~= nil then
    --  Adds filtered directories first
    if var.options.filter_displayDirs == true and var.filteredDirs then
      for _, item in ipairs(var.filteredDirs) do table.insert(filteredList, item) end
    end
    --  Then fileterd texture sets
    if var.options.filter_displayTextureSets == true and var.filteredTextureSets then
      for _, item in ipairs(var.filteredTextureSets) do table.insert(filteredList, item) end
    end
    --  And finally filtered asset files
    if var.options.filter_displayAssets == true and var.filteredAssets then
      for _, item in ipairs(var.filteredAssets) do table.insert(filteredList, item) end
    end
  end
  return filteredList
end

local function assetViewMainPanel()
  if var.selectedDirectory then directoryContextMenu(var.selectedDirectory) end
  var.assetHovered = false
  var.assetViewMainPanelHeight = var.windowSize.y - (2*var.menuBarHeight - 6 + 3*var.style.WindowPadding.y + 1*var.style.FramePadding.y +2*var.style.ChildBorderSize + var.inputFieldSize)
  if im.BeginChild1("Assets##AssetMainPanel", im.ImVec2(0, var.assetViewMainPanelHeight), true, im.WindowFlags_NoScrollWithMouse) then
    var.assetViewScrollMax = im.GetScrollMaxY()
    local scrollY = im.GetScrollY()
    -- scrollbar has been dragged
    if var.assetViewMainPanel_scrollPrev ~= scrollY then
      var.assetViewMainPanel_scrollPrev = scrollY
      var.scrollY = var.assetViewMainPanel_scrollPrev
      im.SetScrollY(var.assetViewMainPanel_scrollPrev)
    -- Mouse wheel has been used
    else
      im.SetScrollY(var.scrollY)
    end

    -- Position of the asset/folder in a list/row. Used to do linebreaks if needed etc.
    var.itemPos = 1
    -- [Debug] Number of assets we're currently rendering in the asset view.
    var.displayedItemsCount = 0

    if (db == true and aM and aM.isReady()) or db == false then
      if var.state == var.state_enum.loading_done then
        var.assetViewMainPanelSize = im.GetItemRectSize()

        -- Sum of assets we have to display.
        var.itemCount = (
          0 +
          (var.options.filter_displayDirs and var.filteredDirsCount or 0) +
          (var.options.filter_displayAssets and var.filteredAssetsCount or 0) +
          (var.options.filter_displayTextureSets and var.filteredTextureSetsCount or 0) +
          ((var.selectedDirectory and var.selectedDirectory.parent ~= true and var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files) and 1 or 0)
        )

        -- Calculate the size of each asset in the asset view panel. Is set to -1 if the asset size
        -- is set to the minimal asset size possible, we're going to render a list view.
        local childSize = (var.options.thumbnailSize <= var.minThumbnailSize) and -1 or im.ImVec2(var.options.thumbnailSize + var.style.WindowPadding.x * 2, var.options.thumbnailSize + 2 * var.style.WindowPadding.y + var.style.ItemSpacing.x + var.fontSize - 5)
        -- [Debug]
        var.childSize = childSize

        -- adjusts child size to scaling
        if childSize ~= -1 then
          local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale;
          childSize.x = childSize.x * uiScaling;
          childSize.y = childSize.y * uiScaling;
        end
        -- Items per row
        var.horizontalItems = (childSize == -1) and 1 or getHorizontalItemsCount(childSize.x, im.GetContentRegionAvailWidth())
        -- Rows
        var.verticalItems = (childSize == -1) and var.itemCount or math.ceil(var.itemCount / var.horizontalItems)

        -- Calculate the max asset view panel height.
        -- We set the cursor at the end so imgui can draw a properly sized scrollbar.
        var.maxAssetViewPanelHeight = getAssetViewMainPanelHeight(childSize)

        if var.selectedDirectory ~= nil then
          if var.selectedDirectory.processing then
            im.TextUnformatted("Refreshing ...")
          else
            if db == false or (db==true and #ffi.string(var.assetViewFilterDB) == 0) then -- are we searching for files atm?

              -- No asset grouping option is selecetd.
              if var.options.assetGroupingType == var.assetGroupingTypes_enum.none then
                -- Directories
                if var.options.filter_displayDirs == true and var.filteredDirs then
                  -- Display the parent dir if there's one.
                  if var.selectedDirectory.parent ~= true and var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files then
                    -- TODO: Check if dir is in viewable area (for virtual scrolling)
                    displayDirectoryInAssetView(var.selectedDirectory.parent, childSize, true)
                  end

                  -- Disaplay all other directories within the current one.
                  displayDirectories(var.filteredDirs, childSize)
                end

                -- texture sets
                if var.filteredTextureSets and var.options.filter_displayTextureSets == true then
                  displayTextureSets(var.filteredTextureSets, childSize)
                end

                -- assets
                if var.filteredAssets and var.options.filter_displayAssets == true then
                  displayAssets(var.filteredAssets, childSize)
                end

              -- A asset grouping option is selected. We either group the asset by filetype or asset type.
              elseif var.options.assetGroupingType ~= var.assetGroupingTypes_enum.none then
                for _, group in ipairs(var.filteredAssetGroupsSorted) do
                  var.itemPos = 0
                  -- Display directories.
                  if group.identifier == "folders" then
                    if var.options.filter_displayDirs == true and #var.filteredAssetGroups.folders > 0 then
                      if groupCollapsingHeader(group) == true then
                        displayDirectories(var.filteredAssetGroups.folders, childSize)
                      end
                    end
                  -- Display assets.
                  else
                    if var.options.filter_displayAssets == true then
                      if groupCollapsingHeader(group) == true then
                        displayAssets(var.filteredAssetGroups[group.identifier], childSize)
                      end
                    end
                  end
                end
              end
            end
            --  Scrolls selection into view
            if var.scrollSelectionIntoView then
              local displayedItems = getDisplayedSelectedDirectoryFilteredList()
              for i, file in ipairs(displayedItems) do
                if file.selected then
                  local mScroll = 0
                  local halfPage = var.assetViewMainPanelHeight / 2
                  local bottomView = var.maxAssetViewPanelHeight - halfPage
                  if childSize == -1 then
                    -- List view
                    local lineHeight = var.maxAssetViewPanelHeight / (2 + #displayedItems)
                    local indexScroll = lineHeight * i  -- scroll height at top of selection
                    if indexScroll > halfPage then
                      mScroll = (indexScroll >= bottomView) and var.assetViewScrollMax or (indexScroll - halfPage)
                    end
                  else
                    -- Thumbnail view
                    local itemRow = math.ceil((i + 1) / var.horizontalItems)
                    local lineHeight = var.maxAssetViewPanelHeight / var.verticalItems
                    local rowScroll = (itemRow - 1) * lineHeight
                    halfPage = halfPage - lineHeight / 2
                    if rowScroll > halfPage then
                      mScroll = (rowScroll >= bottomView) and var.assetViewScrollMax or (rowScroll - halfPage)
                    end
                  end
                  im.SetScrollY(mScroll)
                end
              end
            end
            --  Only once
            var.scrollSelectionIntoView = false

          end

        end
        im.SetCursorPosY(var.maxAssetViewPanelHeight)
      else
        im.TextUnformatted("Loading assets (" .. tostring(var.assetsProcessed) .. "/" .. tostring(var.numberOfAllAssetsAndDirs) ..")")
        im.TextUnformatted(string.format("%0.2f",(var.assetsProcessed/var.numberOfAllAssetsAndDirs)*100) .. '%')
      end
    end
  end
  im.EndChild()

  if im.IsItemClicked(1) and var.assetHovered == false then
    im.OpenPopup("Popup_" .. var.selectedDirectory.path)
  end

  if im.IsItemHovered() then
    setScrollBarValue()
  end
end

local function pathBreadcrumb()

  local function chilrenDirectoryPopupButton(dir, pos)
    -- Setup popup window.
    local dirsCount = #dir.dirs
    if dirsCount > 0 then
      local sizeY = dirsCount * var.fontSize + (dirsCount - 1) * var.style.ItemSpacing.y
      im.SetNextWindowPos(im.ImVec2(pos.x, pos.y - sizeY))
      im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(2,2))
      if im.BeginPopup("childrenDirectoryPopup_" .. dir.path) then
        for _, dir in ipairs(dir.dirs) do
          im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(4,0))
          if im.Button(dir.name, im.ImVec2(im.GetContentRegionAvailWidth(),0)) then
            if db == true then
              selectDirectoryDB(dir)
            else
              selectDirectory(dir, nil, nil, true)
            end
            im.CloseCurrentPopup()
          end
          im.PopStyleVar()
        end
        im.EndPopup()
      end
      im.PopStyleVar()
    end

    local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale
    if editor.uiIconImageButton(
      editor.icons.keyboard_arrow_right,
      im.ImVec2(var.inputFieldSize / uiScaling, var.inputFieldSize / uiScaling),
      nil, nil, nil, ">##" .. dir.path
    ) then
      im.OpenPopup("childrenDirectoryPopup_" .. dir.path)
    end
  end

  -- Add buttons per directory.
  for k, dir in ipairs(var.selectedDirectory.pathToRoot) do
    if im.Button(dir.name .. "##breadcrump" .. tostring(dir.id)) then
      if db == true then
        selectDirectoryDB(dir)
      else
        selectDirectory(dir, nil, nil, true)
      end
    end
    im.SameLine()
    local cursorPos = im.GetCursorPos()
    chilrenDirectoryPopupButton(dir, im.ImVec2(var.windowPos.x + cursorPos.x, var.windowPos.y + cursorPos.y))
    im.SameLine()
  end

  -- Add button for the current selected directory.
  im.Button(var.selectedDirectory.name .. "##breadcrumb" .. tostring(var.selectedDirectory.id))

  im.SameLine()
  local cursorPos = im.GetCursorPos()
  if editor.selection["asset"] ~= nil and editor.selection["asset"].type ~= "textureSet" and editor.selection["asset"].dir == var.selectedDirectory then
    chilrenDirectoryPopupButton(var.selectedDirectory, im.ImVec2(var.windowPos.x + cursorPos.x, var.windowPos.y + cursorPos.y))
    im.SameLine()
    im.Button(editor.selection["asset"].fullFileName)
  elseif var.selectedDirectory.dirCount > 0 then
    chilrenDirectoryPopupButton(var.selectedDirectory, im.ImVec2(var.windowPos.x + cursorPos.x, var.windowPos.y + cursorPos.y))
  end
end

local function thumbnailSizeSliderWidget(sliderWidth, drawWithIcons)
  local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale;
  if drawWithIcons == true then
    editor.uiIconImage(editor.icons.ab_thumbnails_small, im.ImVec2(var.inputFieldSize / uiScaling, var.inputFieldSize / uiScaling))
    im.SameLine()
  end
  if sliderWidth then
    im.PushItemWidth(sliderWidth)
  end
  im.PushID1("ThumbnailSizeSlider")
  local editEnded = im.BoolPtr(false)
  local cpos = im.GetCursorPos()
  if editor.uiSliderInt("", editor.getTempInt_NumberNumber(var.options.thumbnailSize), var.minThumbnailSize, editor.getPreference("assetBrowser.general.maxThumbnailSize"), nil, editEnded) then
    var.options.thumbnailSize = editor.getTempInt_NumberNumber()
  end
  im.tooltip("Thumbnail size")
  im.PopID()
  if editEnded[0] == true then
    var.options.thumbnailSize = (var.minThumbnailSize > editor.getTempInt_NumberNumber()) and var.minThumbnailSize or editor.getTempInt_NumberNumber()
    editor.setPreference("assetBrowser.general.thumbnailSize", var.options.thumbnailSize)
  end
  if sliderWidth then
    im.PopItemWidth()
  end
  if drawWithIcons == true then
    im.SameLine()
    editor.uiIconImage(editor.icons.ab_thumbnails_big, im.ImVec2(var.inputFieldSize / uiScaling, var.inputFieldSize / uiScaling))
  end
end

local function assetThumbnailSizeSlider()
  var.thumbnailSliderGroupWidth = 2 * var.style.ItemSpacing.x + 2 * var.inputFieldSize + var.thumbnailSliderWidth
  local minimumWidgetSize = 2 * var.style.ItemSpacing.x + 3 * var.inputFieldSize
  local sliderWidth = var.thumbnailSliderWidth

  -- There's not enough space to draw the widget. We rather have no widget instead of having a weird UX
  if im.GetContentRegionAvailWidth() < minimumWidgetSize then
    return
  -- There's limited space, draw a widget that resizes based on the given available width.
  elseif im.GetContentRegionAvailWidth() < var.thumbnailSliderGroupWidth then
    sliderWidth = im.GetContentRegionAvailWidth() - (2 * var.inputFieldSize + 2 * var.style.ItemSpacing.x)
    var.thumbnailSliderGroupWidth = 2 * var.style.ItemSpacing.x + 2 * var.inputFieldSize + sliderWidth
  -- There's enough space, draw the full widget.
  end
  im.SetCursorPosX((im.GetCursorPosX() + im.GetContentRegionAvailWidth()) - (var.thumbnailSliderGroupWidth))
  thumbnailSizeSliderWidget(sliderWidth, true)
end

local function historyButtons()
  local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale;
  im.BeginDisabled(var.historyIndex == 1 and true or false)
  if editor.uiIconImageButton(editor.icons.arrow_back, im.ImVec2(var.inputFieldSize / uiScaling, var.inputFieldSize / uiScaling), nil, nil, nil, "historyBack") then
    if var.historyIndex > 1 then
      selectDirectory(var.history[(var.historyIndex -1)], false, false)
      if var.historyIndex == 1 then usedHistoryBack = true end
      var.historyIndex = var.historyIndex - 1
    end
  end
  if var.historyIndex > 1 then
    im.tooltip("back to " .. var.history[(var.historyIndex -1)].path)
  end
  im.EndDisabled()
  im.SameLine()
  im.BeginDisabled(var.historyIndex >= #var.history and true or false)
  if editor.uiIconImageButton(editor.icons.arrow_forward, im.ImVec2(var.inputFieldSize / uiScaling, var.inputFieldSize / uiScaling), nil, nil, nil, "historyForward") then
    if #var.history > var.historyIndex then
      selectDirectory(var.history[(var.historyIndex +1)], false, false)
      var.historyIndex = var.historyIndex + 1
    end
  end
  local tooltipDir = var.history[(var.historyIndex+1)]
  if tooltipDir then
    im.tooltip("forward to " .. tooltipDir.path)
  end
  im.EndDisabled()
end

local function assetViewBottomPanel()
  im.SetCursorPosY(im.GetCursorPosY() + var.style.FramePadding.y)
  historyButtons()
  editor.uiVertSeparator(var.inputFieldSize)
  if var.selectedDirectory ~= nil and var.state == var.state_enum.loading_done then
    pathBreadcrumb()
  end
  im.SameLine()
  -- asset thumbnail slider

  assetThumbnailSizeSlider()
end

local function assetView()
  assetViewMainPanel()
  assetViewBottomPanel()
end
-- ##### GUI: ASSET VIEW - END

-- ##### GUI: MENU BAR
local function saveFilterDropdown()
  local cursorX = im.GetCursorPosX()
  local cursorY = im.GetCursorPosY()

  local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale
  im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0,0,0))
  local open_popup = editor.uiIconImageButton(editor.icons.star, im.ImVec2(var.inputFieldSize / uiScaling, var.inputFieldSize / uiScaling), editor.color.gold.Value, nil, nil, "SaveFilterDropdownButton")
  im.PopStyleColor()
  im.tooltip("Save current filter")

  local popupPos = im.ImVec2(0,0)

  popupPos.x = cursorX + var.windowPos.x
  popupPos.y = cursorY + var.windowPos.y + var.inputFieldSize + var.style.ItemSpacing.y

  if open_popup == true then
    im.OpenPopup("SaveFilterDropdown")
  end

  im.SetNextWindowPos(popupPos)
  im.SetNextWindowSize(im.ImVec2(0, 0), im.Cond_Always)
  if im.BeginPopup("SaveFilterDropdown") then
    im.PushItemWidth(var.saveFilterNameInputWidth)
    im.InputText("##SaveFilterDropdownInputField", var.saveFilterNameInput)
    im.PopItemWidth()
    if im.Button("Save", im.ImVec2(var.saveFilterNameInputWidth, var.inputFieldSize)) then
      if #ffi.string(var.saveFilterNameInput) > 0 then
        local filterInput = ffi.string(im.TextFilter_GetInputBuf(var.assetViewFilter))
        local close = saveSearchFilter(ffi.string(var.saveFilterNameInput), filterInput)
        if close == true then im.CloseCurrentPopup() end
      end
    end
    im.EndPopup()
  end
end

local function filterDropdown()
  local cursorX = im.GetCursorPosX()
  local cursorY = im.GetCursorPosY()

  local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale
  im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0,0,0))
  local open_popup = editor.uiIconImageButton(editor.icons.ab_filter_by_type, im.ImVec2(var.inputFieldSize / uiScaling, var.inputFieldSize / uiScaling), nil, nil, nil, "FilterDropdownButton")
  im.PopStyleColor()
  local open_popup_rmb = false
  im.tooltip("Filter by type")

  if im.IsItemClicked(1) then
    open_popup_rmb = true
  end

  local popupPos = im.ImVec2(
    cursorX + var.windowPos.x + var.inputFieldSize - (var.fontSize + var.style.ItemSpacing.x + 2 * var.style.ItemSpacing.x + 2 * var.style.WindowPadding.x + im.CalcTextSize("prefab").x),
    cursorY + var.windowPos.y + var.inputFieldSize + var.style.ItemSpacing.y
  )
  local popupPosRmb = im.ImVec2(
    cursorX + var.windowPos.x + var.inputFieldSize - (im.CalcTextSize("Disable all").x + 2 * var.style.WindowPadding.x) ,
    cursorY + var.windowPos.y + var.inputFieldSize + var.style.ItemSpacing.y
  )

  if open_popup == true then
    im.OpenPopup("FilterByTypeDropdown")
  end

  im.SetNextWindowPos(popupPos)
  im.SetNextWindowSize(im.ImVec2(100, im.GetContentRegionAvail().y - var.menuBarHeight - var.style.WindowPadding.y - var.inputFieldSize))
  if im.BeginPopup("FilterByTypeDropdown") then
    local curX = im.GetCursorPosX()
    local indentedPos = curX + var.fontSize + var.style.ItemSpacing.x
    for k,type in ipairs(var.simpleFileTypes) do
      if type.active[0] == true then
        editor.uiIconImage(editor.icons.done, im.ImVec2(var.fontSize / uiScaling,var.fontSize / uiScaling))
        im.SameLine()
      end
      im.SetCursorPosX(indentedPos)

      im.Selectable1(type.label .. "##FileTypeDropdownItem", nil, im.SelectableFlags_DontClosePopups)
      if im.IsItemHovered() then
        if im.IsMouseDoubleClicked(0) then

          -- disabled all types except the double-clicked one
          for _,typeD in ipairs(var.simpleFileTypes) do
            typeD.active[0] = false
          end
          type.active[0] = true

          -- create dict to save preferences
          local simpleFileTypes = {}
          for k, typeE in ipairs(var.simpleFileTypes) do
            if typeE.active[0] == true then
              simpleFileTypes[typeE.label] = true
            else
              simpleFileTypes[typeE.label] = false
            end
          end
          editor.setPreference("assetBrowser.general.simpleFileTypes", simpleFileTypes)

          filterAssets()

        elseif im.IsMouseClicked(0) then
          if type.active[0] == true then type.active[0] = false else type.active[0] = true end

          -- check if all types are disabled
          if type.active[0] == false then
            local allDisabled = true
            for _, typeA in ipairs(var.simpleFileTypes) do
              if typeA.active[0] == true then allDisabled = false end
            end
            -- all are disabled, enable all
            if allDisabled == true then
              for _, typeB in ipairs(var.simpleFileTypes) do
                typeB.active[0] = true
              end
            end
          end

          -- create dict to save preferences
          local simpleFileTypes = {}
          for _, typeC in ipairs(var.simpleFileTypes) do
            if typeC.active[0] == true then
              simpleFileTypes[typeC.label] = true
            else
              simpleFileTypes[typeC.label] = false
            end
          end
          editor.setPreference("assetBrowser.general.simpleFileTypes", simpleFileTypes)

          filterAssets()
        end
      end
    end
    im.Separator()
    if im.Selectable1("Enable all##FileTypeDropdownItem", nil, im.SelectableFlags_DontClosePopups) then
      enableAllFilterTypes()
      filterAssets()
    end
    if im.Selectable1("Disable all##FileTypeDropdownItem", nil, im.SelectableFlags_DontClosePopups) then
      disableAllFilterTypes()
      filterAssets()
    end
    im.EndPopup()
  end

  if open_popup_rmb == true then
    im.OpenPopup("FilterByTypeDropdown_rmb")
  end

  im.SetNextWindowPos(popupPosRmb)
  im.SetNextWindowSize(im.ImVec2(0, 0), im.Cond_Always)
  if im.BeginPopup("FilterByTypeDropdown_rmb") then
    if im.Selectable1("Enable all##FileTypeDropdownItemRMB", nil, im.SelectableFlags_DontClosePopups) then
      enableAllFilterTypes()
      filterAssets()
      im.CloseCurrentPopup()
    end
    if im.Selectable1("Disable all##FileTypeDropdownItemRMB", nil, im.SelectableFlags_DontClosePopups) then
      disableAllFilterTypes()
      filterAssets()
      im.CloseCurrentPopup()
    end
    im.EndPopup()
  end
end

local function assetBrowserMenuBar()
  if im.BeginMenuBar() then

    local uiScaling = editor.getPreference("ui.general.scale") or defaultUiScale;
    local iconSize = im.ImVec2(var.inputFieldSize / uiScaling, var.inputFieldSize / uiScaling)

    -- Show/Hide tree view button
    im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0,0,0))
    if editor.uiIconImageButton((var.options.treeView == true) and editor.icons.ab_tree_view_open or editor.icons.ab_tree_view_closed, iconSize) then
      var.options.treeView = not var.options.treeView
      editor.setPreference("assetBrowser.general.treeView", var.options.treeView)
    end
    im.PopStyleColor()
    im.tooltip((var.options.treeView == true) and "Hide tree view" or "Show tree view")

    -- Display number of dirs and files.
    if var.filteredDirsCount and var.filteredAssetsCount then

      -- Width of filter buttons (restore, save, by type) incl. padding and item spacing.
      local filterButtonGroupWidth = (3 * var.inputFieldSize + 3 * var.style.ItemSpacing.x)
      -- Width of search input field incl. all buttons, spacing and additional spacing to the widget group in front of it.
      local assetFilterGroupWidth = (var.assetViewFilterWidth + 3 * var.style.ItemSpacing.x) + filterButtonGroupWidth

      -- Width of directory selection group
      local directorySelectionGroupWidth = (
        ((var.selectedDirectory) and (im.CalcTextSize("ALL").x + im.CalcTextSize(var.selectedDirectory.name).x) or 20) +
        4 * var.style.FramePadding.x +
        4 * var.style.ItemSpacing.x
      )
      local directorySelectionGroupWidthTruncated = (
        ((var.selectedDirectory) and (im.CalcTextSize("ALL").x + im.CalcTextSize("SEL").x) or 20) +
        4 * var.style.FramePadding.x +
        4 * var.style.ItemSpacing.x
      )

      -- Displayed text and their width
      local numberOfDirsText = string.format('Folders: %d', var.filteredDirsCount)
      local numberOfDirsTextWidth = im.CalcTextSize(string.format('Folders: %d', var.filteredDirsCount)).x
      local numberOfDirsTextTruncated = string.format('F: %d', var.filteredDirsCount)
      local numberOfDirsTextTruncatedWidth = im.CalcTextSize(string.format('F: %d', var.filteredDirsCount)).x

      local numberOfAssetsText = string.format('Assets: %d', var.filteredAssetsCount)
      local numberOfAssetsTextWidth = im.CalcTextSize(string.format('Assets: %d', var.filteredAssetsCount)).x
      local numberOfAssetsTextTruncated = string.format('A: %d', var.filteredAssetsCount)
      local numberOfAssetsTextTruncatedWidth = im.CalcTextSize(string.format('A: %d', var.filteredAssetsCount)).x

      local numberOfTextureSetsText = string.format('Sets: %d', var.filteredTextureSetsCount)
      local numberOfTextureSetsTextWidth = im.CalcTextSize(string.format('Sets: %d', var.filteredTextureSetsCount)).x
      local numberOfTextureSetsTextTruncated = string.format('S: %d', var.filteredTextureSetsCount)
      local numberOfTextureSetsTextTruncatedWidth = im.CalcTextSize(string.format('S: %d', var.filteredTextureSetsCount)).x

      local assetVisibilityGroupWidth = (
        numberOfDirsTextWidth + numberOfAssetsTextWidth + numberOfTextureSetsTextWidth +
        6 * var.style.FramePadding.x +
        5 * var.style.ItemSpacing.x
      )
      local assetVisibilityGroupWidthTruncated = (
        numberOfDirsTextTruncatedWidth + numberOfAssetsTextTruncatedWidth + numberOfTextureSetsTextTruncatedWidth +
        6 * var.style.FramePadding.x +
        5 * var.style.ItemSpacing.x
      )
      local assetVisibilityGroupWidthHidden = (
        3 * var.style.ItemSpacing.x
      )

      local sortingGroupingGroupWidth = (
        2 * var.sortingGroupingDropdownWidth +
        1 * var.style.ItemSpacing.x
      )
      local sortingGroupingGroupWidthTruncated = (
        2 * var.inputFieldSize +
        1 * var.style.ItemSpacing.x
      )
      local sortingGroupingGroupWidthHidden = (
        3 * var.style.ItemSpacing.x
      )

      local availWidth = im.GetContentRegionAvailWidth()
      -- Different stages where we want to truncate or hide some of the widgets/widget groups.
      local sortingGroupingTruncated = availWidth < (
        assetFilterGroupWidth +
        directorySelectionGroupWidth +
        assetVisibilityGroupWidth +
        sortingGroupingGroupWidth
      )
      local assetVisibilityTruncated = availWidth < (
        assetFilterGroupWidth +
        directorySelectionGroupWidth +
        assetVisibilityGroupWidth +
        sortingGroupingGroupWidthTruncated
      )
      local folderSelectionTruncated = availWidth < (
        assetFilterGroupWidth +
        directorySelectionGroupWidth +
        assetVisibilityGroupWidthTruncated +
        sortingGroupingGroupWidthTruncated
      )
      local groupingHidden = availWidth < (
        assetFilterGroupWidth +
        directorySelectionGroupWidthTruncated +
        assetVisibilityGroupWidthTruncated +
        sortingGroupingGroupWidthTruncated
      )
      local assetVisibilityHidden = availWidth < (
        assetFilterGroupWidth +
        directorySelectionGroupWidthTruncated +
        assetVisibilityGroupWidthTruncated
      )
      local directorySelectionHidden = availWidth < (
        assetFilterGroupWidth +
        directorySelectionGroupWidthTruncated
      )

      -- Set the position to where we'd like to start rendering the right-side menu entries.
      im.SetCursorPosX(im.GetCursorPosX() + availWidth - (
        1 * var.style.FramePadding.x + -- padding to the right side of the window frame
        assetFilterGroupWidth +
        (directorySelectionHidden and 0 or (folderSelectionTruncated and directorySelectionGroupWidthTruncated or directorySelectionGroupWidth)) +
        (assetVisibilityHidden and 0 or (assetVisibilityTruncated and assetVisibilityGroupWidthTruncated or assetVisibilityGroupWidth)) +
        (groupingHidden and -sortingGroupingGroupWidthHidden or (sortingGroupingTruncated and sortingGroupingGroupWidthTruncated or sortingGroupingGroupWidth))
      ))

      if not groupingHidden then
        -- Asset sorting combo.
        im.PushItemWidth(sortingGroupingTruncated and var.inputFieldSize or var.sortingGroupingDropdownWidth)
        if var.assetSortingNamePtr then
          if im.Combo1("##AssetSortingCombo", editor.getTempInt_NumberNumber(var.options.assetSortingType - 1), var.assetSortingNamePtr) then
            var.options.assetSortingType = editor.getTempInt_NumberNumber() + 1
            editor.setPreference("assetBrowser.general.assetSortingType", var.options.assetSortingType)
            filterAssets()
          end
        end
        im.PopItemWidth()
        im.tooltip("Sort by")

        -- Asset grouping combo.
        im.PushItemWidth(sortingGroupingTruncated and var.inputFieldSize or var.sortingGroupingDropdownWidth)
        if var.assetGroupingNamePtr then
          if im.Combo1("##AssetGroupingCombo", editor.getTempInt_NumberNumber(var.options.assetGroupingType - 1), var.assetGroupingNamePtr) then
            var.options.assetGroupingType = editor.getTempInt_NumberNumber() + 1
            editor.setPreference("assetBrowser.general.assetGroupingType", var.options.assetGroupingType)
            filterAssets()
          end
        end
        im.PopItemWidth()
        im.tooltip("Group by")

        -- Some spacing.
        im.SetCursorPosX(im.GetCursorPosX() + 2 * var.style.ItemSpacing.x)
      end

      if not assetVisibilityHidden then
        -- Button to show/hide directories.
        local dirText = assetVisibilityTruncated and numberOfDirsTextTruncated or numberOfDirsText
        local assetText = assetVisibilityTruncated and numberOfAssetsTextTruncated or numberOfAssetsText
        local setText = assetVisibilityTruncated and numberOfTextureSetsTextTruncated or numberOfTextureSetsText

        im.PushStyleColor2(
          im.Col_Button,
          (var.options.filter_displayDirs == true) and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Button)
        )
        if im.Button(dirText, im.ImVec2(0, var.inputFieldSize)) then
          var.options.filter_displayDirs = not var.options.filter_displayDirs
          editor.setPreference("assetBrowser.general.filter_displayDirs", var.options.filter_displayDirs)
        end
        im.PopStyleColor()
        im.tooltip((editor.getPreference("assetBrowser.general.filter_displayDirs") == true) and "Hide folders" or "Show folders")

        -- Button to show/hide assets
        im.PushStyleColor2(
          im.Col_Button,
          (var.options.filter_displayAssets == true) and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Button)
        )
        if im.Button(assetText, im.ImVec2(0 ,var.inputFieldSize)) then
          var.options.filter_displayAssets = not var.options.filter_displayAssets
          editor.setPreference("assetBrowser.general.filter_displayAssets", var.options.filter_displayAssets)
        end
        im.PopStyleColor()
        im.tooltip((editor.getPreference("assetBrowser.general.filter_displayAssets") == true) and "Hide assets" or "Show assets")

        -- Button to show/hide texture sets
        im.PushStyleColor2(
          im.Col_Button,
          (var.options.filter_displayTextureSets == true) and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Button)
        )
        if im.Button(setText, im.ImVec2(0 ,var.inputFieldSize)) then
          var.options.filter_displayTextureSets = not var.options.filter_displayTextureSets
          editor.setPreference("assetBrowser.general.filter_displayTextureSets", var.options.filter_displayTextureSets)
        end
        im.PopStyleColor()
        im.tooltip((var.options.filter_displayTextureSets == true) and "Hide texture sets" or "Show texture sets")

        -- Some spacing.
        im.SetCursorPosX(im.GetCursorPosX() + 2 * var.style.ItemSpacing.x)
      end

      if not directorySelectionHidden then
        -- Button to display assets of all directories.
        im.PushStyleColor2(
          im.Col_Button,
          (var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files) and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Button)
        )
        if im.Button("ALL##filterButton") then
          if var.options.assetViewFilterType ~= var.assetViewFilterType_enum.all_files then
            var.options.assetViewFilterType = var.assetViewFilterType_enum.all_files
            editor.setPreference("assetBrowser.general.assetViewFilterType", var.options.assetViewFilterType)
            filterDirs()
            filterAssets()
          end
        end
        im.PopStyleColor()
        im.tooltip("Search for files in all folders.")

        -- Button to display assets of selected directory.
        im.PushStyleColor2(
          im.Col_Button,
          (var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files) and im.GetStyleColorVec4(im.Col_ButtonActive) or im.GetStyleColorVec4(im.Col_Button)
        )
        if var.selectedDirectory then
          im.PushID1("SelectedDir_FilterButton")
          if im.Button(folderSelectionTruncated and "SEL" or var.selectedDirectory.name) then
            if var.options.assetViewFilterType ~= var.assetViewFilterType_enum.current_folder_files then
              var.options.assetViewFilterType = var.assetViewFilterType_enum.current_folder_files
              editor.setPreference("assetBrowser.general.assetViewFilterType", var.options.assetViewFilterType)
              filterDirs()
              filterAssets()
            end
          end
          im.PopID()
        end
        im.PopStyleColor(1)
        im.tooltip("Search for files and directories in the current selected directory.")

        -- Some moar spacing.
        im.SetCursorPosX(im.GetCursorPosX() + 2 * var.style.ItemSpacing.x)
      end

      -- Search text filter widget.
      if db == true then
        im.PushID1("assetViewFilterDB_inputText")
        im.PushItemWidth(var.assetViewFilterWidth)
        if im.InputText("", var.assetViewFilterDB) then
          if var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
            createDBFilesTable(aM.getFiles(nil, ffi.string(var.assetViewFilterDB)))
          elseif var.options.assetViewFilterType == var.assetViewFilterType_enum.current_folder_files then
            createDBFilesTable(aM.getFiles(var.selectedDirectory.path, ffi.string(var.assetViewFilterDB)))
          end
        end
        im.PopID()
        im.PopItemWidth()
      else
        imguiUtils.drawCursorPos(im.GetCursorPosX(), im.GetCursorPosY())
        if editor.uiInputSearchTextFilter(nil, var.assetViewFilter, var.assetViewFilterWidth) then
          filterDirs()
          filterAssets()
        end
      end

      -- Restore filter settings button.
      im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0,0,0))
      if editor.uiIconImageButton(editor.icons.settings_backup_restore, iconSize, nil, nil, nil, "RestoreFilter") then
        var.options.assetViewFilterType = var.assetViewFilterType_enum.current_folder_files
        var.options.filter_displayDirs = true
        var.options.filter_displayAssets = true
        var.options.filter_displayTextureSets = false

        editor.setPreference("assetBrowser.general.assetViewFilterType", var.options.assetViewFilterType)
        editor.setPreference("assetBrowser.general.filter_displayDirs", var.options.filter_displayDirs)
        editor.setPreference("assetBrowser.general.filter_displayAssets", var.options.filter_displayAssets)
        editor.setPreference("assetBrowser.general.filter_displayTextureSets", var.options.filter_displayTextureSets)

        im.TextFilter_SetInputBuf(var.assetViewFilter, "")
        ffi.copy(var.assetViewFilter.InputBuf,"") --because SetInputBuf doesn't work here
        im.ImGuiTextFilter_Clear(var.assetViewFilter)
        enableAllFilterTypes()
        filterDirs()
        filterAssets()
      end
      im.PopStyleColor()
      im.tooltip("Restore filter settings")

      -- Save filter button.
      saveFilterDropdown()

      -- Filetype filter dropdown widget.
      if var.simpleFileTypes then
        filterDropdown()
      end

    end
    im.EndMenuBar()
  end
end
-- ##### GUI: MENU BAR - END

-- ##### GUI: DEBUG WINDOW
local function displayFloat(name, value)
  im.TextUnformatted(name)
  im.NextColumn()
  im.TextUnformatted(tostring(value))
  im.NextColumn()
end

local function displayVec2(name, value)
  im.TextUnformatted(name)
  im.NextColumn()
  im.TextUnformatted("x: " .. tostring(value.x) .. "   y: " .. tostring(value.y))
  im.NextColumn()
end

local function displayBool(name, value)
  im.TextUnformatted(name)
  im.NextColumn()
  im.TextUnformatted(value==true and 'true' or 'false')
  im.NextColumn()
end
-- ##### GUI: DEBUG WINDOW - END

-- ##### GUI: IMAGE INSPECTOR WINDOW
local function imageInspectorWindow()
  -- Set size of the window according to the size of the image it's going to display.
  if editor.isWindowVisible(assetBrowserImageInspectorWindowName) and var.imageInspectorWindowSize then
    im.SetNextWindowSize(im.ImVec2(
      var.imageInspectorWindowSize.x + 2 * var.style.WindowPadding.x + 2 * var.style.WindowBorderSize,
      var.imageInspectorWindowSize.y + 2 * var.style.WindowPadding.y + var.menuBarHeight + 2 * var.style.WindowBorderSize + var.minThumbnailSize
    ))
    var.imageInspectorWindowSize = nil
  end

  var.imageInspectorAdditionalYSpace = var.style.ItemSpacing.y + var.fontSize

  -- Keep aspect ratio for the image inspector window.
  if var.imageInspectorImageSize then
    if var.imageInspectorImageSize.x ~= var.imageInspectorImageSize.y / var.imageInspectorImage.ratio then
      im.SetNextWindowSize(im.ImVec2(
        var.imageInspectorImageSize.x + 2 * var.style.WindowPadding.x + 2 * var.style.WindowBorderSize,
        var.imageInspectorImageSize.x * var.imageInspectorImage.ratio + 2 * var.style.WindowPadding.y + var.menuBarHeight + 2 * var.style.WindowBorderSize + var.imageInspectorAdditionalYSpace + var.minThumbnailSize
      ))
    end
  end

  if var.imageInspectorWindowData then
    if editor.beginWindow(assetBrowserImageInspectorWindowName, "Image Inspector", im.flags(im.WindowFlags_NoScrollbar, im.WindowFlags_NoDocking)) then
        local windowSize = im.GetWindowSize()
        if var.imageInspectorImageSize then
          var.imageInspectorImageSize.x = windowSize.x - 2 * var.style.WindowPadding.x - 2 * var.style.WindowBorderSize
          var.imageInspectorImageSize.y = windowSize.y - 2 * var.style.WindowPadding.y - var.menuBarHeight - 2 * var.style.WindowBorderSize - var.imageInspectorAdditionalYSpace - var.minThumbnailSize
        else
          var.imageInspectorImageSize = im.ImVec2(windowSize.x - 2 * var.style.WindowPadding.x - 2 * var.style.WindowBorderSize, windowSize.y - 2 * var.style.WindowPadding.y - var.menuBarHeight - 2 * var.style.WindowBorderSize - var.minThumbnailSize)
        end
        if var.imageInspectorImage and var.imageInspectorImage.tex then
          im.PushStyleColor2(im.Col_Button, editor.color.transparent.Value)
          local isCheckerBoardEnabled = var.imageInspector_bg_state == var.imageInspector_bg_state_enum.checkerboard
          local isWhiteBgEnabled = var.imageInspector_bg_state == var.imageInspector_bg_state_enum.white
          if editor.uiIconImageButton(isCheckerBoardEnabled
              and editor.icons.grid_off
              or editor.icons.grid_on,
            im.ImVec2(var.minThumbnailSize, var.minThumbnailSize), nil, nil, nil, "Checkerboard"
          ) then
            var.imageInspector_bg_state = isCheckerBoardEnabled and var.imageInspector_bg_state_enum.black or var.imageInspector_bg_state_enum.checkerboard
          end
          if im.IsItemHovered() then
            local tooltipText = isCheckerBoardEnabled and "Hide Checkerboard Pattern" or "Show Checkerboard Pattern"
            im.BeginTooltip()
            im.Text(tooltipText)
            im.EndTooltip()
          end
          im.SameLine()
          if editor.uiIconImageButton(isWhiteBgEnabled
            and editor.icons.radio_button_unchecked
            or editor.icons.lens,
            im.ImVec2(var.minThumbnailSize, var.minThumbnailSize), nil, nil, nil, "White Background"
          ) then
            var.imageInspector_bg_state = isWhiteBgEnabled and var.imageInspector_bg_state_enum.black or var.imageInspector_bg_state_enum.white
          end
          if im.IsItemHovered() then
            local tooltipText = isWhiteBgEnabled and "Black Background" or "White Background"
            im.BeginTooltip()
            im.Text(tooltipText)
            im.EndTooltip()
          end
          im.PopStyleColor()

          if not var.checkerboardTex then
            var.checkerboardTex = editor.texObj(var.imageInspector_checkerboardBgPath)
          end
          if not var.whiteBgTex then
            var.whiteBgTex = editor.texObj(var.imageInspector_whiteBgPath)
          end
          if not var.blackBgTex then
            var.blackBgTex = editor.texObj(var.imageInspector_blackBgPath)
          end

          local texToDraw = isCheckerBoardEnabled and var.checkerboardTex or (isWhiteBgEnabled and var.whiteBgTex or var.blackBgTex)

          local initialCursorPos = im.GetCursorPos()
          local cursorPos = initialCursorPos
          local uv1 = im.ImVec2(1, 1)
          local offsetInRow = var.imageInspectorImageSize.x % texToDraw.size.x
          local offsetInCol = var.imageInspectorImageSize.y % texToDraw.size.y
          local lastTileWidthInRow = offsetInRow ~= 0 and offsetInRow or texToDraw.size.x
          local lastTileHeightInCol = offsetInCol ~= 0 and offsetInCol or texToDraw.size.y - var.minThumbnailSize
          local isLastTileInRow, isLastTileInCol = false, false
          -- Draw Image Background Pattern
          for rowIndex = 1, var.imageInspectorImageSize.y/texToDraw.size.y + 1, 1 do
            if offsetInCol == 0 and rowIndex >= var.imageInspectorImageSize.y/texToDraw.size.y +1 then break end
            for colIndex = 1, var.imageInspectorImageSize.x/texToDraw.size.x + 1, 1 do
              cursorPos = im.GetCursorPos()
              isLastTileInRow = colIndex >= var.imageInspectorImageSize.x/texToDraw.size.x
              isLastTileInCol = rowIndex >= var.imageInspectorImageSize.y/texToDraw.size.y
              uv1.x = isLastTileInRow and (lastTileWidthInRow/texToDraw.size.x) or 1
              uv1.y = isLastTileInCol and (lastTileHeightInCol/texToDraw.size.y) or 1
              local texSize = im.ImVec2(texToDraw.size.x * uv1.x, texToDraw.size.y * uv1.y)
              im.Image(texToDraw.tex:getID(), texSize, nil, uv1, nil, nil)
              im.SetCursorPos(im.ImVec2(cursorPos.x + texSize.x, cursorPos.y))
            end
            im.SetCursorPos(im.ImVec2(initialCursorPos.x, initialCursorPos.y + rowIndex * texToDraw.size.y))
          end
          im.SetCursorPos(initialCursorPos)

          im.Image(
            var.imageInspectorImage.tex:getID(), var.imageInspectorImageSize, nil, nil, nil, editor.color.white.Value
          )
          if im.SmallButton("Actual image size") then
            openImageInspectorWindow(editor.selection["asset"])
          end
          im.SameLine()
          if var.imageInspectorImageSize then im.TextUnformatted("Image preview size x: " .. tostring(var.imageInspectorImageSize.x) .. " y: " .. tostring(var.imageInspectorImageSize.y)) end
        end
    end
    editor.endWindow()
  else
    editor.hideWindow("ab_imageInspector")
  end
end
-- ##### GUI: IMAGE INSPECTOR WINDOW - END

local function onEditorGui()
  var.windowFlags = (var.dragging == var.dragging_enum.dragging or var.dragging == var.dragging_enum.drag_ended) and
  im.flags(im.WindowFlags_MenuBar, im.WindowFlags_NoScrollbar, im.WindowFlags_NoMove) or
  im.flags(im.WindowFlags_MenuBar, im.WindowFlags_NoScrollbar)
  if editor.beginWindow(assetBrowserWindowName, "Asset Browser", var.windowFlags) then
    var.windowPos = im.GetWindowPos()
    var.windowSize = im.GetWindowSize()
    var.style = im.GetStyle()
    var.io = im.GetIO()

    var.fontSize = math.ceil(im.GetFontSize())
    var.menuBarHeight = 2*var.style.FramePadding.y + var.fontSize
    var.inputFieldSize = var.fontSize + 2 * var.style.FramePadding.y

    imageInspectorWindow()

    if var.dragging == var.dragging_enum.dragging and im.IsMouseReleased(0) then
      onDragEnded()
    end

    if (var.dragging == var.dragging_enum.drag_ended or var.dragging == var.dragging_enum.no_drag) and im.IsMouseReleased(0) then
      var.dragging = var.dragging_enum.no_drag
    end

    assetBrowserMenuBar()

    if var.options and var.options.treeView == true then

      im.Columns(2, "MainColumn")
      if not var.initialized then
        im.SetColumnWidth(0, var.windowSize.x * 0.25)
        var.initialized = true
      end

      local colId = im.GetColumnIndex()
      local colWidth = im.GetColumnWidth(colId)
      treeViewMainPanel()
      if colWidth < var.windowSize.x * 0.1 then
        im.SetColumnWidth(colId, var.windowSize.x * 0.1)
      end
      im.NextColumn()
      assetView()
      im.Columns(1)
    else
      assetView()
    end
  end
  editor.endWindow()
end
-- ##### GUI: MAIN - END

-- ##### GUI: INSPECTOR
local function assetInspectorGui_Json(asset)
  im.Separator()
  im.Columns(1)
  if im.TreeNodeEx1('data##' .. asset.path, im.TreeNodeFlags_DefaultOpen) then
    imguiUtils.displayKeyValues(asset.inspectorData.data)
    im.TreePop()
  end
  im.Dummy(im.ImVec2(0, 3*var.style.ItemSpacing.y))
  if im.TreeNode1('rawdata##' .. asset.path) then
    im.TextUnformatted(asset.inspectorData.rawdata)
    im.TreePop()
  end
end

local function assetInspectorGui_Materials(asset)
  im.Separator()
  im.Columns(1)
  im.TextUnformatted("Materials:")
  for matName, _ in pairs(asset.inspectorData.materials) do
    im.Bullet()
    if im.Selectable1(matName) then
      if editor_materialEditor then
        editor_materialEditor.showMaterialEditor()
        editor_materialEditor.selectMaterialByName(matName)
      end
    end
  end
  im.Separator()
  if im.TreeNodeEx1('data##' .. asset.path, im.TreeNodeFlags_DefaultOpen) then
    imguiUtils.displayKeyValues(asset.inspectorData.data)
    im.TreePop()
  end
  if im.TreeNode1('rawdata##' .. asset.path) then
    im.TextUnformatted(asset.inspectorData.rawdata)
    im.TreePop()
  end
end

local function assetInspectorGui_Material(asset)
  im.Columns(2)
  -- Asset Name
  im.TextUnformatted("Name")
  im.NextColumn()
  im.TextUnformatted(asset.name)
  im.NextColumn()
  im.TextUnformatted("Type")
  im.NextColumn()
  im.TextUnformatted(asset.type)
  im.NextColumn()

  im.Columns(1)
  im.TextUnformatted("Material Preview")
  local matPreviewSize = im.GetContentRegionAvailWidth()
  var.dimRdr:set(0, 0, matPreviewSize, matPreviewSize)
  -- TODO: renderWorld should not be called every frame only once the material or matPreviewSize changes.
  var.matPreview:renderWorld(var.dimRdr)
  var.matPreview:ImGui_Image(matPreviewSize, matPreviewSize)
  if im.SmallButton("Open in Material Editor") then
    if editor_materialEditor then
      editor_materialEditor.showMaterialEditor()
      editor_materialEditor.selectMaterialByName(asset.name)
    end
  end
end

local function assetInspectorGui_Prefab(asset)
  im.Separator()
  im.Columns(1)
  if im.TreeNode1('rawdata##' .. asset.path) then
    im.TextUnformatted(asset.inspectorData.rawdata)
    im.TreePop()
  end
end

local function assetInspectorGui_DataBlock(asset)
  im.Separator()
  im.Columns(1)
  if im.TreeNode1('rawdata##' .. asset.path) then
    im.TextUnformatted(asset.inspectorData.rawdata)
    im.TreePop()
  end
end

local function assetInspectorGui_Lua(asset)
  im.Separator()
  im.Columns(1)
  if im.TreeNode1('rawdata##' .. asset.path) then
    im.TextUnformatted(asset.inspectorData.rawdata)
    im.TreePop()
  end
end

local function assetInspectorGui_Html(asset)
  im.Separator()
  im.Columns(1)
  if im.TreeNode1('rawdata##' .. asset.path) then
    im.TextUnformatted(asset.inspectorData.rawdata)
    im.TreePop()
  end
end

local function assetInspectorGui_Txt(asset)
  im.Separator()
  im.Columns(1)
  if im.TreeNode1('rawdata##' .. asset.path) then
    im.TextUnformatted(asset.inspectorData.rawdata)
    im.TreePop()
  end
end

local function assetInspectorGui_Image(asset, mapName)
  local inspectorData = asset.inspectorData
  if inspectorData then
    local img = editor.getTempTextureObj(asset.path)
    if img then
      im.Columns(1)
      im.Separator()
      if mapName then
        im.TextUnformatted(mapName)
      end
      -- Image Resolution
      im.TextUnformatted("Dimensions")
      editor.uiTextUnformattedRightAlign(img.size.x .. ' x ' .. img.size.y, true)
      if img.format and img.format ~= "" then
        im.TextUnformatted("Format")
        editor.uiTextUnformattedRightAlign(img.format, true)
      end

      -- Image
      im.Columns(1)
      im.TextUnformatted("Preview:")
      local width = im.GetContentRegionAvailWidth()
      if width > var.options.maxInspectorImagePreviewSize then
        width = var.options.maxInspectorImagePreviewSize
      end
      local ratio = img.size.y / img.size.x
      local height = width * ratio
      if height > var.options.maxInspectorImagePreviewSize then
        local ratio = height / var.options.maxInspectorImagePreviewSize
        height = var.options.maxInspectorImagePreviewSize
        width = width / ratio
      end
      -- TODO: Use color from editor's colors table.
      if im.ImageButton(
        img.tex:getID(),
        im.ImVec2(width, height),
        im.ImVec2Zero,
        im.ImVec2One,
        var.imageButtonBorderSize,
        im.ImColorByRGB(0,0,0,255).Value
      ) then
        openImageInspectorWindow(asset)
      end
      dragDropSource(asset)
    end
  end
end

local function assetInspectorGui_Mesh(asset)
  if asset.ready == true then
    im.Separator()
    if var.meshPreview.mDetailPolys then
      im.TextUnformatted("Polygons")
      im.NextColumn()
      im.TextUnformatted(tostring(var.meshPreview.mDetailPolys))
      im.NextColumn()
    end
    if var.meshPreview.mColPolys then
      im.TextUnformatted("Collision Polygons")
      im.NextColumn()
      im.TextUnformatted(tostring(var.meshPreview.mColPolys))
      im.NextColumn()
    end
    im.Columns(1)
    im.NewLine()
    im.TextUnformatted("Mesh preview")
    im.ShowHelpMarker("Doubleclick = focus obj\nMMB = pan cam\nRMB = orbit cam \nScroll wheel = zoom\nCtrl + Scroll wheel = fast zoom", true)
    im.SameLine()
    local pressed = false
    if im.GetContentRegionAvailWidth() > (im.CalcTextSize("Show in ShapeEditor").x + 2 * var.style.FramePadding.x) then
      pressed = editor.uiButtonRightAlign("Show in ShapeEditor", nil, true)
    else
      im.NewLine()
      pressed = editor.uiButtonRightAlign("Show in ShapeEditor")
    end
    if pressed then editor_shapeEditor.showShapeEditorLoadFile(asset.path) end
    local size = im.GetContentRegionAvailWidth()
    var.meshPreviewDimRdr.point = Point2I(0, 0)
    var.meshPreviewDimRdr.extent = Point2I(size,size)
    var.meshPreviewRenderSize[1] = size
    var.meshPreviewRenderSize[2] = size
    var.meshPreview:renderWorld(var.meshPreviewDimRdr)
    im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(0,0))
    if im.BeginChild1("MeshPreviewChild", im.ImVec2(size,size), true, im.WindowFlags_NoScrollWithMouse) then
      var.meshPreview:ImGui_Image(var.meshPreviewRenderSize[1],var.meshPreviewRenderSize[2])
      im.EndChild()
    end
    im.PopStyleVar()
    if im.Checkbox("Show collision mesh", editor.getTempBool_BoolBool(var.meshPreviewDisplayCollisionMesh)) then
      var.meshPreviewDisplayCollisionMesh = editor.getTempBool_BoolBool()
      -- ghost, nodes, bounds, objbox, col, grid
      var.meshPreview:setRenderState(false,false,false,false,var.meshPreviewDisplayCollisionMesh,true)
    end
  end
end

local function assetInspectorGui(inspectorInfo)
  if editor.selection["asset"] ~= nil then
    local inspector_selectedAsset = editor.selection["asset"]
    local maxWidth = 0

    if inspector_selectedAsset.type == "material" then
      assetInspectorGui_Material(inspector_selectedAsset)
    elseif inspector_selectedAsset.type == "textureSet" then
      im.Columns(2)
      -- Asset Name
      im.TextUnformatted("Name")
      im.NextColumn()
      im.TextUnformatted(inspector_selectedAsset.name)
      im.NextColumn()
      -- Asset Path
      im.TextUnformatted("Path")
      im.NextColumn()
      im.TextUnformatted(inspector_selectedAsset.dir.path)
      im.NextColumn()
      -- Asset Type
      im.TextUnformatted("Type")
      im.NextColumn()
      im.TextUnformatted(inspector_selectedAsset.type)
      im.NextColumn()
      im.Separator()
      im.Columns(1)
      im.TextUnformatted("Texture Maps")
      if inspector_selectedAsset.d then
        assetInspectorGui_Image(inspector_selectedAsset.d, "Diffuse Map")
      end
      if inspector_selectedAsset.n then
        assetInspectorGui_Image(inspector_selectedAsset.n, "Normal Map")
      end
      if inspector_selectedAsset.s then
        assetInspectorGui_Image(inspector_selectedAsset.s, "Specular Map")
      end
    else --if inspector_selectedAsset.type ~= nil then
    -- if inspector_selectedAsset.type ~= "textureSet" then
      im.Columns(2)
      -- Asset Name
      im.TextUnformatted("Name")
      im.NextColumn()
      maxWidth = im.GetContentRegionAvailWidth()
      local assetName = inspector_selectedAsset.fullFileName or inspector_selectedAsset.name
      im.TextUnformatted(assetName)
      if maxWidth < im.CalcTextSize(assetName).x then
        im.tooltip(assetName)
      end
      im.NextColumn()
      -- Asset Path
      im.TextUnformatted("Path")
      im.NextColumn()
      maxWidth = im.GetContentRegionAvailWidth()
      im.TextUnformatted(inspector_selectedAsset.path)
      if maxWidth < im.CalcTextSize(inspector_selectedAsset.path).x then
        im.tooltip(inspector_selectedAsset.path)
      end
      im.NextColumn()
      -- Asset Type
      im.TextUnformatted("Type")
      im.NextColumn()
      im.TextUnformatted(inspector_selectedAsset.type or "directory")
      im.NextColumn()
      -- Asset Simple Filetype
      if inspector_selectedAsset.type ~= nil then
        im.TextUnformatted("File type")
        im.NextColumn()
        im.TextUnformatted(inspector_selectedAsset.simpleFileType)
        im.NextColumn()
        if inspector_selectedAsset.simpleFileType ~= inspector_selectedAsset.fileType then
          -- Asset Filetype
          im.TextUnformatted("")
          im.NextColumn()
          im.TextUnformatted(inspector_selectedAsset.fileType)
          im.NextColumn()
        end
      end
      -- Asset file stats
      if inspector_selectedAsset.filestats then
        -- Asset access time
        im.TextUnformatted("Access time")
        im.NextColumn()
        maxWidth = im.GetContentRegionAvailWidth()
        im.TextUnformatted(inspector_selectedAsset.filestats.accesstimeString)
        if maxWidth < im.CalcTextSize(inspector_selectedAsset.filestats.accesstimeString).x then
          im.tooltip(inspector_selectedAsset.filestats.accesstimeString)
        end
        im.NextColumn()
        -- Asset create time
        im.TextUnformatted("Creation time")
        im.NextColumn()
        maxWidth = im.GetContentRegionAvailWidth()
        im.TextUnformatted(inspector_selectedAsset.filestats.createtimeString)
        if maxWidth < im.CalcTextSize(inspector_selectedAsset.filestats.createtimeString).x then
          im.tooltip(inspector_selectedAsset.filestats.createtimeString)
        end
        im.NextColumn()
        -- Asset mod time
        im.TextUnformatted("Modification time")
        im.NextColumn()
        maxWidth = im.GetContentRegionAvailWidth()
        im.TextUnformatted(inspector_selectedAsset.filestats.modtimeString)
        if maxWidth < im.CalcTextSize(inspector_selectedAsset.filestats.modtimeString).x then
          im.tooltip(inspector_selectedAsset.filestats.modtimeString)
        end
        im.NextColumn()
        -- Asset file size
        im.TextUnformatted("File size")
        im.NextColumn()
        im.TextUnformatted(inspector_selectedAsset.filestats.filesizeString)
        im.NextColumn()
      end
      -- Asset Filesize
      if inspector_selectedAsset.filesize then
        im.TextUnformatted("File size")
        im.NextColumn()
        im.TextUnformatted(string.format("%0.0fkb", inspector_selectedAsset.filesize/1024))
        im.NextColumn()
      end

      if inspector_selectedAsset.inspectorData then
        if inspector_selectedAsset.type == "json" or inspector_selectedAsset.type == "part configuration" or inspector_selectedAsset.type == "jbeam" then
          assetInspectorGui_Json(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "materials" then
          assetInspectorGui_Materials(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "material" then
          assetInspectorGui_Material(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "prefab" then
          assetInspectorGui_Prefab(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "datablock" then
          assetInspectorGui_DataBlock(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "lua" then
          assetInspectorGui_Lua(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "html" then
          assetInspectorGui_Html(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "txt" then
          assetInspectorGui_Txt(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "image" then
          assetInspectorGui_Image(inspector_selectedAsset)
        elseif inspector_selectedAsset.type == "mesh" then
          assetInspectorGui_Mesh(inspector_selectedAsset)
        end
      end

      im.Columns(1)
    end
  end
end
-- ##### GUI: INSPECTOR - END

-- ##### SETUP FILES
-- Removes thumbnail cache files from cache as well as nulls the references in the lua objects.
local function removeThumbnailCache()
  if var.confirmationState == var.confirmationState_enum.none then
    var.confirmationState = var.confirmationState_enum.deleteCache
  elseif var.confirmationState == var.confirmationState_enum.deleteCache then
    if (FS:directoryExists("/temp/assetBrowser/")) then
      editor.logInfo(logTag .. "Removed thumbnail cache folder.")
      editor.showNotification("Removed thumbnail cache folder.")
      -- TODO:
      --  * Remove references to thumbnail objects.
      --  * Re-cache current folder.

      local function removeThumbnailCacheFiles(dir)

        local function removeFileIfExists(file)
          local path = "/temp/assetBrowser/thumbnails" .. file.path .. ".png"
          if file.type == "mesh" and FS:fileExists(path) then
            FS:removeFile(path)
          end
        end

        if dir.files then
          for _, file in ipairs(dir.files) do
            removeFileIfExists(file)
          end
        end

        if dir.dirs then
          for _, dir in ipairs(dir.dirs) do
            removeThumbnailCacheFiles(dir)
          end
        end
      end

      removeThumbnailCacheFiles(var.root)

      local res = FS:directoryRemove("/temp/assetBrowser/")
    end
    var.confirmationState = var.confirmationState_enum.none
  end
end

local function addFileTypes(fileType, simpleFileType)
  if not var.fileTypes[fileType] then
    var.fileTypes[fileType] = {label = fileType, active = im.BoolPtr(true), icon = editor.icons.ab_asset_jbeam}
  end
  if not var.simpleFileTypes[simpleFileType] then
    var.simpleFileTypes[simpleFileType] = {label = simpleFileType, active = im.BoolPtr(true), icon = editor.icons.ab_asset_jbeam}
  end
end

local function sortFileTypes()
  local fileTypes = {}
  for typename, type in pairs(var.fileTypes) do
    table.insert(fileTypes, type)
  end
  table.sort(fileTypes, function(a,b)
    return a.label < b.label
  end)
  var.fileTypes = fileTypes

  local simpleFileTypes = {}
  for typename, type in pairs(var.simpleFileTypes) do
    table.insert(simpleFileTypes, type)
  end
  table.sort(simpleFileTypes, function(a,b)
    return a.label < b.label
  end)
  var.simpleFileTypes = simpleFileTypes
end

local function getDirs(parent)
  parent.dirs = {}
  parent.dirCount = 0
  local tbl = FS:findFiles(parent.path, "*", 0, false, true)
  for _, path in ipairs(tbl) do
    local stat = FS:stat(path)
    if stat.filetype then
      if stat.filetype == "dir" then
        local name = string.match(path, "[^/]*$") -- name of the folder
        if var.options.skipMainFolder == true and name == 'main' then
          if debug then editor.logInfo(logTag .. "Skipped main dir.") end
        else
          table.insert(parent.dirs, newDirectory(path, name, parent))
          parent.dirCount = parent.dirCount + 1
          var.dirCount = var.dirCount + 1
        end
      end
    end
  end

  for _, dir in ipairs(parent.dirs) do
    coroutine.yield()
    getDirs(dir)
  end

  coroutine.yield()
end

local function addTextureToTextureSet(dir, asset, textureName , textureType)
  local success = false
  for _,set in ipairs(dir.textureSets) do
    if set.name == textureName then
      set[textureType] = asset
      set.count = set.count + 1
      success = true
    end
  end
  if success == false then
    local tbl = {name = textureName, count = 1, type="textureSet", selected=false, path=dir.path, dir=dir}
    tbl[textureType] = asset
    table.insert(dir.textureSets, tbl)
  end
end

local function getTextureSets(dir)
  dir.textureSets = {}
  if dir.fileCount > 1 then
    for _, file in ipairs(dir.files) do
      if file.type == "image" then
        local textureName = string.sub(file.fileName, 1, #file.fileName-2)
        local textureType = string.sub(file.fileName, -2)
        if string.sub(textureType,1,1) == "_" then
          textureType = string.sub(textureType,2,2)
          if textureType == "n" or textureType == "d" or textureType == "s" then
            addTextureToTextureSet(dir, file, textureName, textureType)
          end
        end
      end
    end
  end
  -- remove sets with only one single texture in it
  for i = #dir.textureSets, 1, -1 do
    if dir.textureSets[i].count == 1 then
      dir.textureSets[i] = nil
    end
  end
end

local function getDirsAndFiles(parent, notRecursive)
  parent.dirs = {}
  parent.files = {}
  parent.dirCount = 0
  parent.fileCount = 0
  parent.processing = true
  local tbl = FS:findFiles(parent.path, "*", 0, false, true)
  for _, path in ipairs(tbl) do
    local stat = FS:stat(path)
    if stat.filetype then
      if stat.filetype == "dir" then
        local name = string.match(path, "[^/]*$") -- name of the folder
        if var.options.skipMainFolder == true and name == 'main' then
          if debug then editor.logInfo(logTag .. "Skipped main dir.") end
        else
          table.insert(parent.dirs, newDirectory(path, name, parent))
          parent.dirCount = parent.dirCount + 1
          var.dirCount = var.dirCount + 1
        end
        var.assetsProcessed = var.assetsProcessed + 1
      elseif stat.filetype == "file" then
        local fileType = string.match(path, "[.].+") or ""
        local simpleFileType = string.lower(string.match(path, "[^.]*$"))
        local fileName = string.match(path, "[^/]*$")
        -- TODO: check if filetype is present
        fileName = string.sub(fileName, 1, #fileName - #fileType)
        -- Remove the `.` from the filetype
        fileType = #fileType > 0 and string.lower(string.sub(fileType, 2)) or fileType

        -- Skip imposter files when setting is enabled.
        if var.options.skipImposters == false or (var.options.skipImposters == true and (fileType ~= "dae.imposter.dds" and fileType ~= "dae.imposter_normals.dds")) then
          table.insert(parent.files, newFile(parent, path, fileName, fileType, simpleFileType))
          addFileTypes(fileType, simpleFileType)
          parent.fileCount = parent.fileCount + 1
          var.fileCount = var.fileCount + 1
          var.assetsProcessed = var.assetsProcessed + 1
        end
      end
    end
  end

  coroutine.yield()
  getTextureSets(parent)

  for _, dir in ipairs(parent.dirs) do
    coroutine.yield()
    getDirsAndFiles(dir)
  end

  parent.processing = nil

  coroutine.yield()
end

local function getLevelPathAndName()
  local path = '/levels/'
  local name = ""
  local i = 1
  for str in string.gmatch(getMissionFilename(),"([^/]+)") do
    if i == 2 then
      path = path .. str
      name = str
    end
    i = i + 1
  end
  return path, name
end

local function setupVars()
  -- Create char* array for asset sorting options combo widget.
  local tbl = {}
  for _, type in ipairs(var.assetSortingTypes) do
    table.insert(tbl, type.name)
  end
  var.assetSortingNamePtr = im.ArrayCharPtrByTbl(tbl)

  -- Create char* array for asset grouping options combo widget.
  tbl = {}
  var.assetGroupingTypes_enum = {}
  for id, type in ipairs(var.assetGroupingTypes) do
    var.assetGroupingTypes_enum[type.name] = id
    table.insert(tbl, type.name)
  end
  var.assetGroupingNamePtr = im.ArrayCharPtrByTbl(tbl)

  var.directoryContextMenuEntries = {
    {
      name = "Show in explorer",
      fn = function(dir) Engine.Platform.exploreFolder(dir.path) end
    },
    {
      name = "Go to",
      fn = function(dir) selectDirectory(dir, nil, true) end,
      filterFn = function()
        if var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
          return true
        else
          return false
        end
      end
    },
    -- TODO: Copy the absolute path instead of just the relative one.
    {
      name = "Copy path",
      fn = function(dir) im.SetClipboardText(dir.path)
      end
    },
    {
      name = "New Folder",
      fn = function(dir) var.newFolderModalOpen = true
      end
    },
    {
      name = "Regenerate asset data",
      fn = function(dir)
        core_jobsystem.create(createAssetDataOfWholeDirJob, 1, dir, true)
      end
    },
    {
      name = "Refresh directory",
      fn = function(dir)
        core_jobsystem.create(function()
          getDirsAndFiles(dir)
          selectDirectory(dir, nil, nil, false)
          -- todo recount files & dirs
        end, 1)
      end
    },
    {
      name = "Refresh assets",
      fn = function(dir)
        dir.files = {}
        var.fileCount = var.fileCount - dir.fileCount
        dir.fileCount = 0
        dir.processed = false

        local tbl = FS:findFiles(dir.path, "*", 0, false, true)
        for _, path in ipairs(tbl) do
          local stat = FS:stat(path)
          if stat.filetype then
            if stat.filetype == "file" then
              local fileType = string.match(path, "[.].+") or ""
              local simpleFileType = string.lower(string.match(path, "[^.]*$"))
              local fileName = string.match(path, "[^/]*$")
              -- TODO: check if filetype is present
              fileName = string.sub(fileName, 1, #fileName - #fileType)
              -- Remove the `.` from the filetype
              fileType = #fileType > 0 and string.lower(string.sub(fileType, 2)) or fileType

              -- Skip imposter files when setting is enabled.
              if var.options.skipImposters == false or (var.options.skipImposters == true and (fileType ~= "dae.imposter.dds" and fileType ~= "dae.imposter_normals.dds")) then
                table.insert(dir.files, newFile(dir, path, fileName, fileType, simpleFileType))
                dir.fileCount = dir.fileCount + 1
              end
            end
          end
        end

        var.fileCount = var.fileCount + dir.fileCount
        selectDirectory(dir, nil, nil, false)
      end
    },
    {
      name = "Dump directory",
      fn = function(dir)
        dumpz(dir, 2)
      end
    }
    -- TODO: Add copy, cut, paste, delete context menu entries.
    -- {name = "copy", fn = function(dir)  end},
    -- {name = "cut", fn = function(dir)  end},
    -- {name = "paste", fn = function(dir)  end},
    -- {name = "delete", fn = function(dir)  end}
  }

  var.assetContextMenuEntries = {
    {
      name = "Instantiate",
      fn = function(asset) instantiateMesh(asset) end,
      filterFn = function(asset)
        if asset.type == "mesh" then
          return true
        else
          return false
        end
      end
    },
    {
      name = "Open file",
      fn = function(asset) Engine.Platform.openFile(asset.path) end
    },
    {
      name = "Show in explorer",
      fn = function(asset) Engine.Platform.exploreFolder(asset.path) end
    },
    {
      name = "Go to",
      fn = function(asset) selectDirectory(asset.dir, nil, true) end,
      filterFn = function()
        if var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
          return true
        else
          return false
        end
      end
    },
    -- TODO: Copy the absolute path instead of just the relative one.
    {
      name = "Copy path",
      fn = function(asset) im.SetClipboardText(asset.path) end
    },
    {
      name = "Filter by type of this asset",
      fn = function(asset)
        local simpleFileTypes = {}
        for k, type in ipairs(var.simpleFileTypes) do
          if type.label == asset.simpleFileType then
            simpleFileTypes[type.label] = true
            type.active[0] = true
          else
            simpleFileTypes[type.label] = false
            type.active[0] = false
          end
        end
        editor.setPreference("assetBrowser.general.simpleFileTypes", simpleFileTypes)
        filterAssets()
      end
    },
    -- TODO: Add copy, cut, paste, delete context menu entries.
    -- {name = "copy", fn = function(asset) end},
    -- {name = "cut", fn = function(asset) end},
    -- {name = "paste", fn = function(asset) end},
    -- {name = "delete", fn = function(asset) end}
    {
      name = "Show in Shape Editor",
      fn = function(asset) editor_shapeEditor.showShapeEditorLoadFile(asset.path) end,
      filterFn = function(asset)
        if asset.type == 'mesh' then
          return true
        else
          return false
        end
      end
    },
    {
      name = "Show in Material Editor",
      fn = function(asset)
        if editor_materialEditor then
          editor_materialEditor.showMaterialEditor()
          editor_materialEditor.selectMaterialByName(asset.name)
        end
      end,
      filterFn = function(asset)
        if asset.type == 'material' and editor_materialEditor then
          return true
        else
          return false
        end
      end
    },
    {
      name = "Regenerate thumbnail",
      fn = function(asset)
        if asset.inspectorData then asset.inspectorData = nil end
        local cachePath = "/temp/assetBrowser/thumbnails" .. asset.path .. ".png"
        if(FS:fileExists(cachePath)) then
          FS:removeFile(cachePath)
        end
        createInspectorData(asset, true)
      end,
      filterFn = function(asset)
        if asset.type == 'mesh' then
          return true
        else
          return false
        end
      end
    },
    {
      name = "Spawn prefab at camera",
      fn = function(asset)
        local prefab = spawnPrefab(Sim.getUniqueName(asset.fileName),asset.path,"0 0 0","1 0 0 0","1 1 1")
        if prefab then
          prefab.loadMode = 0
          scenetree.MissionGroup:addObject(prefab.obj)
          local camDir = (quat(getCameraQuat()) * vec3(0,1,0)) * 10
          prefab.obj:setPosition(getCameraPosition() + camDir)
        end
      end,
      filterFn = function(asset)
        if asset.type == 'prefab' or asset.fileType == 'prefab.json' then
          return true
        else
          return false
        end
      end
    },
    {
      name = "Spawn prefab at origin",
      fn = function(asset)
        local prefab = spawnPrefab(Sim.getUniqueName(asset.fileName),asset.path,"0 0 0","1 0 0 0","1 1 1")
        if prefab then
          prefab.loadMode = 0
          scenetree.MissionGroup:addObject(prefab.obj)
          editor.selectObjectById(prefab.obj:getId())
        end
      end,
      filterFn = function(asset)
        if asset.type == 'prefab' or asset.fileType == 'prefab.json' then
          return true
        else
          return false
        end
      end
    },
    {
      name = "Dump asset",
      fn = function(asset)
        dumpz(asset, 3)
      end
    }
  }

  var.textureSetContextMenuEntries = {
    {
      name = "Show in explorer", fn = function(set) Engine.Platform.exploreFolder(set.dir.path) end},
    {
      name = "Go to",
      fn = function(set) selectDirectory(set.dir, nil, true) end,
      filterFn = function()
        if var.options.assetViewFilterType == var.assetViewFilterType_enum.all_files then
          return true
        else return false
        end
      end
    },
    -- TODO: Add copy, cut, paste, delete context menu entries.
    -- {name = "copy", fn = function(set) end},
    -- {name = "cut", fn = function(set) end},
    -- {name = "paste", fn = function(set) end},
    -- {name = "delete", fn = function(set) end}
  }
end

local function loadSavedFiletypeFilter()
  local simpleFileTypes = editor.getPreference("assetBrowser.general.simpleFileTypes")
  if not simpleFileTypes then return end
  for _, type in ipairs(var.simpleFileTypes) do
    if simpleFileTypes[type.label] ~= nil then
      if simpleFileTypes[type.label] == true then
        type.active[0] = true
      else
        type.active[0] = false
      end
    else
      -- default value
      type.active[0] = true
    end
  end
end

-- Opens a directory in the current selected directory based on a given name.
local function openDirByName(name, createNoAssetData)
  if var.selectedDirectory and var.selectedDirectory.dirs then
    for _,dir in ipairs(var.selectedDirectory.dirs) do
      if name == dir.name then
        selectDirectory(dir, nil, true, nil, createNoAssetData)
        var.setTreeViewScroll = true
        return
      end
    end
  end
end

local function getDirByName(name, dir)
  local selDir = dir or var.selectedDirectory
  if selDir and selDir.dirs then
    for _,dir in ipairs(selDir.dirs) do
      if string.lower(name) == string.lower(dir.name) then
        return dir
      end
    end
  end
end

local function selectFileByName(filename, dir)
  if dir and dir.files then
    for k, file in ipairs(dir.files) do
      if filename == file.fileName or filename == file.fullFileName then
        selectAsset(file)
        return
      end
    end
    editor.logWarn(logTag .. "No asset found with the given name '" .. filename .. "'")
  end
end

local function getDirByPath(path, dirToSearchIn, isLevelDir)
  local selDir = dirToSearchIn

  local dirNames = {}
  for dirName in string.gmatch(path, "[%w_]+") do
    if not isLevelDir or dirName ~= var.levelName then
      table.insert(dirNames, dirName)
    end
  end

  for _, dirName in ipairs(dirNames) do
    selDir = getDirByName(dirName, selDir)
  end

  return selDir
end

local function selectFileByPath(path)
  local rootFolder = string.match(path, "[%w_]+")
  local root = (rootFolder == "levels" and var.root or (rootFolder == "art" and var.commonArt or (rootFolder == "vehicles" and var.vehicles or nil)))

  if not root then
    return
  end

  local rootPath = string.gsub(root.path, "//", "/")
  local filepath = string.match(string.lower(path), string.lower(rootPath) .."(.+)")
  local filename = string.match(filepath, "[^/]*$")
  local fileDir = string.sub(filepath, 1, #filepath - #filename)
  local dir = getDirByPath(fileDir, root, true)
  selectDirectory(dir, nil, true, true)

  selectFileByName(filename, dir)
end

-- without filename e.g. "/gridmap/art/shapes/"
local function openDirByPath(path)
  local rootFolder = string.match(path, "[%w_]+")
  local root = (rootFolder == "levels" and var.root or (rootFolder == "art" and var.commonArt or (rootFolder == "vehicles" and var.vehicles or nil)))

  if not root then
    -- editor.logWarn(logTag .. path .. " cannot be found.")
    return
  end

  selectDirectory(root, nil, true, false, true)

  local dirNames = {}
  for dirName in string.gmatch(path, "[%w_]+") do
    if dirName ~= var.levelName then
      table.insert(dirNames, dirName)
    end
  end

  local dirNamesCount = table.getn(dirNames)
  for k, dirName in ipairs(dirNames) do
    local createNoCache = true
    if k == dirNamesCount then
      createNoCache = false
    end
    openDirByName(dirName, createNoCache)
  end
end
---

local function setupMaterialPreview()
  var.matPreview:setObjectModel("/art/shapes/material_preview/cube_1m.dae")
  var.matPreview:setRenderState(false,false,false,false,false,false)
  var.matPreview:setCamRotation(0.6, 3.9)
  var.matPreview:renderWorld(var.dimRdr)
  var.matPreview:fitToShape()
  var.matPreview.mBgColor = ColorI(178,178,178,255)
end

-- Function which will be used in a coroutine to get the directories and files of a folder and its
-- folders and files recursively.
local function setupJob()
  setupVars()

  -- Init material preview.
  setupMaterialPreview()

  var.levelPath, var.levelName = getLevelPathAndName()

  var.numberOfAllAssetsAndDirs = #FS:findFiles(var.levelPath, "*", -1, false, true)
  var.numberOfAllAssetsAndDirs = var.numberOfAllAssetsAndDirs + #FS:findFiles("/art/", "*", -1, false, true)

  if editor.getPreference("assetBrowser.general.loadVehicleAssets")== true then
    var.numberOfAllAssetsAndDirs = var.numberOfAllAssetsAndDirs + #FS:findFiles("/vehicles/", "*", -1, false, true)
  end

  if editor.getPreference("assetBrowser.general.loadGameplayAssets") == true then
    var.numberOfAllAssetsAndDirs = var.numberOfAllAssetsAndDirs + #FS:findFiles("/gameplay/", "*", -1, false, true)
  end

  if editor.getPreference("assetBrowser.general.showAllDataFolders") == true then
    var.numberOfAllAssetsAndDirs = var.numberOfAllAssetsAndDirs + #FS:findFiles("/", "*", -1, false, true)
  end

  var.root = newDirectory(var.levelPath, var.levelName, true, true, false)
  var.commonArt = newDirectory("/art/", "art", true, true, false)

  if editor.getPreference("assetBrowser.general.loadVehicleAssets")== true then
    var.vehicles = newDirectory("/vehicles/", "vehicles", true, true, false)
  end

  if editor.getPreference("assetBrowser.general.loadGameplayAssets") == true then
    var.gameplay = newDirectory("/gameplay/", "gameplay", true, true, false)
  end

  if editor.getPreference("assetBrowser.general.showAllDataFolders") == true then
    var.allData = newDirectory("/", "all", true, true, false)
  end

  var.fileCount = 0
  var.dirCount = 0

  var.fileTypes = {}
  var.simpleFileTypes = {}

  var.selectedDirectory = var.selectedDirectory or var.root

  var.selectedFile = nil

  -- get all directories and files of the current level and put them into a tree struct
  if db == true then
    extensions.load('core_assetManager')
    aM = core_assetManager
    -- only get directories recursively, we will retrieve the files from the db later on
    getDirs(var.root)
  else
    getDirsAndFiles(var.root)
    getDirsAndFiles(var.commonArt)

    -- Create/get thumbnails for the current selected directory.
    core_jobsystem.create(createAssetDataOfWholeDirJob, 1, var.selectedDirectory)

    if editor.getPreference("assetBrowser.general.loadVehicleAssets")== true then
      getDirsAndFiles(var.vehicles)
    end

    if editor.getPreference("assetBrowser.general.loadGameplayAssets") == true then
      getDirsAndFiles(var.gameplay)
    end

    if editor.getPreference("assetBrowser.general.showAllDataFolders") == true then
      getDirsAndFiles(var.allData)
    end

    if var.currentLevelDirectories[var.levelName] then
      openDirByPath(var.currentLevelDirectories[var.levelName])
    else
      selectDirectory(var.root, false, true)
    end
  end

  -- sort fileTypes alphabetically
  sortFileTypes()

  loadSavedFiletypeFilter()

  if db == true then
    editor.logInfo(logTag .. "Directory structure has been created.")
  else
    var.state = var.state_enum.loading_done
    editor.logInfo(logTag .. "Files have been received and processed.")
  end

  var.history = {var.root}

  filterDirs()
  filterAssets()
end
-- ##### SETUP FILES - END

-- ##### EDIT MODES
local function assetBrowserEditModeActivate()
  -- here you prepare your edit mode variables
end

local function assetBrowserEditModeDeactivate()
  -- here you cleanup your edit mode caches or other things
  if editor.selection["asset"] ~= nil then
    editor.selection["asset"].selectedInABView = false
  end
end

local function assetBrowserEditModeUpdate()
end
-- ##### EDIT MODES - END

local function onWindowMenuItem()
  editor.showWindow(assetBrowserWindowName)
end

local function extendedSceneTreeObjectMenuItems(node)
  -- Does nothing if still loading the assets
  if var.state == var.state_enum.loading_done then
    --  Gets asset file path
    local object = scenetree.findObjectById(node.id)
    local assetPath = object:getModelFile() --node.upcastedObject:getModelFile()

    --  Selects new path
    selectFileByPath(assetPath)
    --  Scroll into view
    var.scrollSelectionIntoView = true
  end
  --  Opens the window
  if not editor.isWindowVisible(assetBrowserWindowName) then
    editor.showWindow(assetBrowserWindowName)
  end
end

local function onEditorInitialized()
  editor.registerInspectorTypeHandler("asset", assetInspectorGui)
  editor.registerWindow(assetBrowserWindowName, im.ImVec2(800, 500))
  editor.registerWindow(assetBrowserImageInspectorWindowName)
  editor.editModes.assetBrowserEditMode = {
    onActivate = assetBrowserEditModeActivate,
    onDeactivate = assetBrowserEditModeDeactivate,
    onUpdate = assetBrowserEditModeUpdate,
    onToolbar = nil,
    actionMap = "assetBrowser", -- if available, not required
    icon = nil,
    iconTooltip = "assetBrowser"
  }

  var.options = {}
  var.options.scrollSpeedMin = 5
  var.options.scrollSpeedMax = 100

  editor.assetDragDrop = {}
  editor.assetDragDrop.data = nil
  editor.assetDragDrop.dragImage = nil
  editor.assetDragDrop.payload = nil

  -- subscribe our setup function to the jobsystem
  core_jobsystem.create(setupJob, 1)

  editor.addWindowMenuItem("Asset Browser", onWindowMenuItem, nil, true)
  editor.addExtendedSceneTreeObjectMenuItem({
    title = "Locate in Asset Browser",
    extendedSceneTreeObjectMenuItems = extendedSceneTreeObjectMenuItems,
    validator = function(node)
      local object = scenetree.findObjectById(node.id)
      -- Applicable for TSStatic objects
      if object then
        return object:getClassName() == "TSStatic"
      end
    end
  })
end

local function onEditorActivated()
  local asset = editor.selection["asset"]

  if asset and asset.type == "mesh" then
    var.meshPreview:setObjectModel(asset.path)
  elseif asset and asset.type == "material" then
    var.matPreview:setMaterial(asset.cobj)
  end
end

local function onFileModified(dir, filename, filetype)
  -- Not interested in adding imposters/cache files to asset browser.
  if string.match(filetype, "imposter") or string.match(filetype, "dae.png") or string.match(filetype, "cdae") then
    return
  end
  if dir then
    local filenameLowercase = string.lower(filename)
    for k, file in ipairs(dir.files) do
      if filenameLowercase == string.lower(file.fullFileName) then
        -- modify file
        createAssetData(file, true)
        if dir == var.selectedDirectory then
          selectDirectory(dir, nil, true)
        end
        return
      end
    end
    -- Create a new file.
    local simpleFileType = string.lower(string.match(filename, "[^.]*$"))
    local fileNameNoExt = string.sub(filename, 1, #filename - (#filetype+1))
    local file = newFile(dir, dir.path..filename, fileNameNoExt, filetype, simpleFileType)
    table.insert(dir.files, file)

    --File newly available. CreateAssetData regardless.
    if editor.getPreference("assetBrowser.general.createAssetDataOfDirectory") then
      createAssetData(file)
    end

    if dir == var.selectedDirectory then
      selectDirectory(dir, nil, true)
    end
  end
end

local function onFileDeleted(dir, filename, filetype)
  if dir and dir.files then
    for k, file in ipairs(dir.files) do
      if string.lower(filename) == string.lower(file.fullFileName) then
        table.remove(dir.files, k)
        if dir == var.selectedDirectory then
          selectDirectory(dir, nil, true)
        end
        return
      end
    end
  end
end

local function onFileChanged(path, type)
  if var.state == var.state_enum.loading_done then
    -- Get levelname or commonArt subfolder.
    local levelName, levelFilepath = string.match(path, "/levels/([%w_]+)(.+)")
    local artFilepath = string.match(path, "/art/(.+)")
    if levelName or artFilepath then
      local filename = string.match(path, "[^/]*$")
      local filetype = string.match(filename, "[.](.+)")
      local dir = nil

      if not var.levelName then return end

      if levelName and string.lower(levelName) == string.lower(var.levelName) then
        levelFilepath = string.sub(levelFilepath, 1, #levelFilepath - #filename)
        dir = getDirByPath(levelFilepath, var.root)
      elseif artFilepath then
        artFilepath = string.sub(artFilepath, 1, #artFilepath - #filename)
        dir = getDirByPath(artFilepath, var.commonArt)
      else
        return
      end

      -- Check if there's a filetype, if not it's probably a folder.
      if filetype then
        if type == 'modified' then
          onFileModified(dir, filename, filetype)
        elseif type == 'deleted' then
          -- clear editor selection if the deleted file was selected before
          if editor.selection["asset"] and editor.selection["asset"].dir == dir and string.lower(editor.selection["asset"].fullFileName) == filename then
            editor.selection["asset"].selectedInABView = false
          end
          onFileDeleted(dir, filename, filetype)
        end
      else
        -- TODO: Check if it's actually a folder or just a file without any filetype.
      end
    end
  end
end

local function reset()
  var.state = var.state_enum.loading_assets
  var.assetsProcessed = 0
  var.numberOfAllAssetsAndDirs = 0
  var.root = nil
  var.commonArt = nil
  var.allData = nil
  var.gameplay = nil
  var.vehicles = nil
  core_jobsystem.create(setupJob, 1)
end

local function onEditorPreferenceValueChanged(path, value)
  if path == "assetBrowser.general.thumbnailSize" then var.options.thumbnailSize = value end
  if path == "assetBrowser.general.filter_displayDirs" then var.options.filter_displayDirs = value end
  if path == "assetBrowser.general.filter_displayAssets" then var.options.filter_displayAssets = value end
  if path == "assetBrowser.general.filter_displayTextureSets" then var.options.filter_displayTextureSets = value end
  if path == "assetBrowser.general.assetViewFilterType" then var.options.assetViewFilterType = value end
  if path == "assetBrowser.general.savedFilter" then var.options.savedFilter = value end
  if path == "assetBrowser.general.assetSortingType" then var.options.assetSortingType = value end
  if path == "assetBrowser.general.assetGroupingType" then var.options.assetGroupingType = value end
  if path == "assetBrowser.general.currentLevelDirectories" then var.currentLevelDirectories = value end
  if path == "assetBrowser.general.treeView" then var.options.treeView = value end

  if path == "assetBrowser.general.loadGameplayAssets" then
    if value == true then
      if var.state == var.state_enum.loading_done then reset() end
    else
      var.gameplay = nil
    end
  end
  if path == "assetBrowser.general.loadVehicleAssets" then
    if value == true then
      if var.state == var.state_enum.loading_done then reset() end
      var.vehicles = newDirectory("/vehicles/", "vehicles", true, true, false)
      var.numberOfAllAssetsAndDirs = var.numberOfAllAssetsAndDirs + #FS:findFiles("/vehicles/", "*", -1, false, true)
    else
      var.vehicles = nil
      var.numberOfAllAssetsAndDirs = var.numberOfAllAssetsAndDirs - #FS:findFiles("/vehicles/", "*", -1, false, true)
    end
  end
  if path == "assetBrowser.general.showAllDataFolders" then
    if value == true then
      if var.state == var.state_enum.loading_done then reset() end
    else
      var.allData = nil
    end
  end

  if path == "assetBrowser.general.skipMainFolder" then var.options.skipMainFolder = value end
  if path == "assetBrowser.general.skipImposters" then var.options.skipImposters = value end
  if path == "assetBrowser.general.showThumbnailWhenHoveringAsset" then var.options.showThumbnailWhenHoveringAsset = value end
  if path == "assetBrowser.general.scrollSpeed" then var.options.scrollSpeed = value end
  if path == "assetBrowser.general.dragDropRotationMultiplier" then var.options.dragDropRotationMultiplier = value end
  if path == "assetBrowser.general.maxInspectorImagePreviewSize" then var.options.maxInspectorImagePreviewSize = value end
  if path == "assetBrowser.general.instantiateMeshInFrontOfCamera" then var.options.instantiateMeshInFrontOfCamera = value end
  if path == "assetBrowser.general.typeColors" then
    for type, color in pairs(var.typeColors) do
      if value[type] then
        var.typeColors[type] = value[type]
      end
    end
  end
end

local function onWindowGotFocus(windowName)
  if windowName == assetBrowserWindowName then
    pushActionMap("AssetBrowser")
  end
end

local function onWindowLostFocus(windowName)
  if windowName == assetBrowserWindowName then
    popActionMap("AssetBrowser")
  end
end

local prefTempBoolPtr = im.BoolPtr(true)
local tempFloatArr3 = ffi.new("float[3]", {0, 0, 0})

local function getTempFloatArray3(value)
  if value then
    tempFloatArr3[0] = value[1]
    tempFloatArr3[1] = value[2]
    tempFloatArr3[2] = value[3]

    return tempFloatArr3
  else
    return {tempFloatArr3[0],tempFloatArr3[1],tempFloatArr3[2]}
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("assetBrowser")
  prefsRegistry:registerSubCategory("assetBrowser", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {loadVehicleAssets = {"bool", false, "Load the vehicle assets in the asset browser, this will increase the time loading the asset browser.\nChanging the setting will reload all assets."}},
    {loadGameplayAssets = {"bool", false, "Load the gameplay folder assets.\nChanging the setting will reload all assets."}},
    {showAllDataFolders = {"bool", false, "Show all game data folders in the asset browser, this will increase the time loading the asset browser.\nChanging the setting will reload all assets."}},
    {skipMainFolder = {"bool", false, "Skip loading the main (level objects) folder"}},
    {skipImposters = {"bool", true, "Skip the imposter files when loading the file tree"}},
    {showThumbnailWhenHoveringAsset = {"bool", true, "Show a thumbnail on hovering the asset file"}},
    {instantiateMeshInFrontOfCamera = {"bool", true, "If true the mesh will be created in front of the camera, otherwise at origin (0,0,0), when double clicking on the asset"}},
    {scrollSpeed = {"float", 50, "Scroll speed in the thumbnail list"}},
    {dragDropRotationMultiplier = {"float", 10, "The rotation multiplier for when dropping a mesh object and rotating it with the mouse wheel"}},
    {thumbnailSize = {"int", 18, "The thumbnail image size"}},
    {maxThumbnailSize = {"int", 256, "The max thumbnail image size"}},
    {maxInspectorImagePreviewSize = {"int", 512, "The maximum preview image size within inspector"}},
    {treeViewIndentationWidth = {"float", 8, ""}},
    {createAssetDataOfDirectory = {"bool", true, "If true the asset browser will create thumbnails and other data when opening a directory."}},
    {fileTypeIconColor = { "ColorI", ColorI(255, 255, 255, 255), "Color of file type icon." }},

    {displayAssetColorCode = {"bool", true, "If true the asset browser will display a color coded bar at the bottom of the asset thumbnails."}},
    {typeColors = {"table", {}, "", nil, nil, nil, nil, nil, function()
      if var.typeColors and editor.getPreference("assetBrowser.general.displayAssetColorCode") then
        local sortedTbl = tableKeys(var.typeColors)
        table.sort(sortedTbl)
        im.BeginChild1("abTypeColorsTblChild", im.ImVec2(0, 300))
        im.Columns(2)
        if sortedTbl then
          for _, typeName in ipairs(sortedTbl) do
            im.TextUnformatted(typeName)
            im.NextColumn()
            prefTempBoolPtr[0] = false
            im.PushItemWidth(im.GetContentRegionAvailWidth())
            if editor.uiColorEdit3("##typeColor_" .. typeName, getTempFloatArray3(var.typeColors[typeName]), nil, prefTempBoolPtr) then
              var.typeColors[typeName] = getTempFloatArray3()
            end
            im.PopItemWidth()
            if prefTempBoolPtr[0] == true then
              editor.setPreference("assetBrowser.general.typeColors", var.typeColors)
              prefTempBoolPtr[0] = false
            end
            im.NextColumn()
          end
        end
        im.Columns(1)
        im.EndChild()
      end
    end}},

    -- hidden prefs
    {treeView = {"bool", true, "If the tree view is visible", nil, nil, nil, true}},
    {simpleFileTypes = {"table", {}, "", nil, nil, nil, true}},
    {currentLevelDirectories = {"table", {}, "", nil, nil, nil, true}},
    {assetViewFilterType = {"int", 2, "", nil, nil, nil, true}},
    {filter_displayDirs = {"bool", true, "", nil, nil, nil, true}},
    {filter_displayAssets = {"bool", true, "", nil, nil, nil, true}},
    {filter_displayTextureSets = {"bool", false, "", nil, nil, nil, true}},
    {savedFilter = {"table", {}, "", nil, nil, nil, true}},
    {assetSortingType = {"int", 1, "", nil, nil, nil, true}},
    {assetGroupingType = {"int", 1, "", nil, nil, nil, true}},
    {otherFolders = {"table", {}, "", nil, nil, nil, true}},
  })
end

local function moveSelectionIndex(up)
  if var.currentListIndex then
    var.currentListIndex = var.currentListIndex + (up and -1 or 1)
    if var.currentListIndex > var.maxListIndexVal then
      var.currentListIndex = var.maxListIndexVal
    end
    if var.currentListIndex < 1 then
      var.currentListIndex = 1
    end
    var.arrowNavValueChanged = true
  end
end

-- public interface
M.selectFileByPath = selectFileByPath

M.onEditorActivated = onEditorActivated
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onFileChanged = onFileChanged
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged
M.onEditorToolWindowGotFocus = onWindowGotFocus
M.onEditorToolWindowLostFocus = onWindowLostFocus

M.moveSelectionIndex = moveSelectionIndex

return M