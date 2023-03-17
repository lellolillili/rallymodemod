-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper for the level people, so they can mark things :)

local M = {}

local log_tag = "editor_file_dialog"

local toolWindowName = "fileDialog"
local recentDirsWindowName = "recentDirsWindow"
local im = ui_imgui
local imUtils = require('ui/imguiUtils')

local overwriteDialog = false
local overwriteDialogText = nil

local smartSearch = false

local maxFilePreviewSize = 512

local fNameInput
local fNameInputLength

local currentSortFunc

local columnCount = nil

local currentPath = nil
local fileCache = nil
local hasParentDir = nil
local currentFolderStat = nil
local action = "action"
local callbackFunction = nil
local withPreview = nil
local options = {file_exist = true, select_folder = false, suffix="*",pattern=nil}
local fileTypeSelected = 1
local textinput = im.ArrayChar(256, "")
local textinputNewFolder = im.ArrayChar(256, "")
local cbdata = nil
local selectedFile = nil
local fileViewColumnWidth = nil

local recentDirs = {}
local recentDirsWindowPos = nil
local recentDirsWindowWidth = nil

local fileTypeIcons = nil
local fileTypeTooltips = nil

local tempTextureObj = nil
local tempBoolPtr = im.BoolPtr(false)
local tempIntPtr = im.IntPtr(0)
local smartSearchItemsWindowName = "smartSearchItems"
local smartSearchWindowPos = nil
local smartSearchWindowSize = nil
local filenameTextInputFocused = false
local filetypeComboMinWidth = 20
local filetypeComboMaxWidth = 150
local filenameTextInputMinWidth = 10
local buttonsAreaMaxWidth = 120

local function getTempBool(value)
  if value ~= nil then
    if value == true then
      tempBoolPtr[0] = true
      return tempBoolPtr
    elseif value == false then
      tempBoolPtr[0] = false
      return tempBoolPtr
    end
  else
    return tempBoolPtr[0]
  end
end

local function getTempInt(value)
  if value then
    tempIntPtr[0] = value
    return tempIntPtr
  else
    return tempIntPtr[0]
  end
end

local function getTempTextureObj(value)
  if value then
    tempTextureObj = editor.texObj(value)
    return tempTextureObj
  else
    return tempTextureObj
  end
end

local function basicFilePreviewGui()
  im.Columns(2, "FilePreviewColumns")
  if selectedFile.name then
    im.TextUnformatted("Name")
    im.NextColumn()
    im.TextUnformatted(selectedFile.name)
    im.NextColumn()
  end
  if selectedFile.filesize then
    im.TextUnformatted("Filesize")
    im.NextColumn()
    im.TextUnformatted(bytes_to_string(selectedFile.filesize))
    im.NextColumn()
  end
  im.Columns(1, "FilePreviewColumns")
end

local function imagePreviewGui()
  im.NewLine()
  local imgSize = getTempTextureObj(selectedFile.path).size
  im.Columns(2, "FilePreviewColumns")
  im.TextUnformatted("Dimensions")
  im.NextColumn()
  im.TextUnformatted(string.format("%d x %d", imgSize.x, imgSize.y))
  im.Columns(1, "FilePreviewColumns")
  local maxImageSize = (im.GetContentRegionAvailWidth() - 2) > maxFilePreviewSize and maxFilePreviewSize or (im.GetContentRegionAvailWidth() - 2)
  local ratio = imgSize.x / imgSize.y
  local tooltipThumbnailSize = im.ImVec2(maxImageSize, maxImageSize)
  local maxTooltipThumbnailSize = 256
  local sizex = tooltipThumbnailSize.x / ratio
  local sizey = tooltipThumbnailSize.y
  -- check if size exceeds the maximum size so we do not display 16k preview images
  if sizex > maxTooltipThumbnailSize then
    local ratio = sizex / maxTooltipThumbnailSize
    sizex = sizex / ratio
    sizey = sizey / ratio
  end

  im.Image(getTempTextureObj().texId, im.ImVec2(sizex, sizex), nil, nil, nil, im.ImVec4(1,1,1,1))
end

local previewFunctions = {
  jpg = imagePreviewGui,
  jpeg = imagePreviewGui,
  png = imagePreviewGui,
  dds = imagePreviewGui
}

local function checkPattern(file, pattern)
  if type(pattern) == "string" then
    if file.name:match(".*("..pattern..")$") == nil then
      return false
    end
    return true
  elseif type(pattern) == "table" then
    local res = false
    for _, p in ipairs(pattern) do
      local file_name = options.case_sensitive_match and file.name or string.lower(file.name)
      local match_pattern = options.case_sensitive_match and p or string.lower(p)
      if file_name:match(".*(" .. match_pattern .. ")$") ~= nil then return true end
    end
    return res
  end
end

local function sortFileCache()
  table.sort(fileCache, function(a, b)
    if a.filetype ~= b.filetype then
      return a.filetype < b.filetype
    end
    return string.lower(a.name) > string.lower(b.name)
  end)
end

local function refreshCache(localcachepath)
  currentPath = localcachepath
  fileCache = {}
  if currentPath:sub(1,1) ~= "/" then currentPath = "/" .. currentPath end
  if currentPath:sub(-1) ~= "/" then currentPath = currentPath.."/" end
  currentPath = currentPath:gsub("/+", "/")   -- Reducing multiple slashes to avoid trimmed list names
  currentFolderStat = FS:stat(currentPath)
  local pathLen = string.len(currentPath) + 1
  -- get entries for current path
  local files = FS:findFiles(localcachepath, '*', 0, false, true) -- TODO : feature #4209
  local pattern = nil
  local suffixType = type(options.suffix[fileTypeSelected][2])
  if suffixType == 'string' then
    pattern = options.suffix[fileTypeSelected][2]:gsub("%.","%%.")
  elseif suffixType == 'table' then
    pattern = {}
    for k, ext in ipairs(options.suffix[fileTypeSelected][2]) do
      local p ,_ = ext:gsub("%.","%%.")
      table.insert(pattern, p)
    end
  end

  local validName
  for _, fn in ipairs(files) do
    local s = FS:stat(fn)
    s.name = string.sub(fn, pathLen)
    s.name = string.gsub(s.name, "/(.*)", "%1") -- strip leading /
    validName = true

    if not options.select_folder and (type(pattern) == "table" or (type(pattern) == 'string' and pattern ~= "*")) then
      if s.filetype == "file" then
        validName = checkPattern(s, pattern)
      end
    end

    if s.filetype == "file" then
      s.path = fn
      _, s.nameWithoutExt, s.extension = path.splitWithoutExt(fn)
      s.extension = string.lower(s.extension)
    end

    if validName then
      if s.filetype == 'dir' then s.filesize = nil end
      table.insert(fileCache, s)
    end
  end
  -- sort them
  table.sort(fileCache, function(a, b)
    if a.filetype ~= b.filetype then
      if a.filetype == nil then return false end
      if b.filetype == nil then return true end
      return a.filetype < b.filetype
    end
    return string.lower(a.name) < string.lower(b.name)
  end)
  hasParentDir = false
  if currentPath ~= '/' then
    hasParentDir = true
  end

  -- Add path to recent dirs
  local index = tableFindKey(recentDirs, currentPath)
  if index then
    table.remove(recentDirs, index)
  end
  table.insert(recentDirs, currentPath)
  if tableSize(recentDirs) > 10 then
    table.remove(recentDirs, 1)
  end
end

local function filterFile(file)
  if fNameInputLength == 0 or string.match(file.name, fNameInput) or smartSearch == false then
    return true
  else
    return false
  end
end

local function execCB(data)
  local isok, msg = pcall(callbackFunction, data)
  if not isok then
    log("E", "", "Callback failed : "..dumps(msg))
  end
  editor.hideWindow(toolWindowName)
end

local columns = {
  {
    name = "Filename",
    visible = true,
    lockedVisibility = true,
    guiFn = function(file)
      local doubleClicked = false
      -- Directory
      if file.filetype == "dir" then
        editor.uiIconImage(editor.icons.folder, im.ImVec2(im.GetFontSize(), im.GetFontSize()))
        im.SameLine()
        im.Selectable1(file.name, file.name == fNameInput)

        if editor.IsItemDoubleClicked(0) then
          refreshCache(currentPath..file.name.."/")
        end

      -- File
      elseif file.filetype == "file" then
        if fileTypeIcons[file.extension] then
          editor.uiIconImage(fileTypeIcons[file.extension], im.ImVec2(im.GetFontSize(), im.GetFontSize()))
        else
          editor.uiIconImage(editor.icons.ab_asset_json, im.ImVec2(im.GetFontSize(), im.GetFontSize()))
        end
        im.SameLine()

        if im.Selectable1(file.name, file == selectedFile) then
          -- copying the filename into the textinput field interferes with the smart search for files
          ffi.copy(textinput, file.name)
          smartSearch = false
          selectedFile = file
        end

        if editor.IsItemDoubleClicked(0) then
          if not options.select_folder then
            if action == "Save" then
              local fname = file.name
              if fname:reverse():find(options.suffix[fileTypeSelected][2]:reverse()) ~= 1 then
                fname = fname..options.suffix[fileTypeSelected][2]
              end
              cbdata = {path=currentPath, action=action, filename=fname, filepath=currentPath..fname, filestat = "overwrite"}
              --im.OpenPopup("overwriting_popup")
            else
              execCB({path=currentPath, stat=file, action=action, filename=file.name, filepath=currentPath..file.name})
            end
          end
        end

        -- Tooltip
        if fileTypeTooltips[file.extension] then
          fileTypeTooltips[file.extension](file)
        end
      end
    end
  },
  {
    name = "Filesize",
    visible = true,
    guiFn = function(file)
      if file.filetype == "file" then
        if file.filesize then
          im.TextUnformatted(bytes_to_string(file.filesize))
        end
      end
    end
  },
  {
    name = "Filetype",
    visible = false,
    guiFn = function(file)
      if file.filetype == "folder" then
        im.TextUnformatted("folder")
      elseif file.filetype == "file" then
        if file.extension then
          im.TextUnformatted(file.extension)
        end
      end
    end
  },
  {
    name = "Date created",
    visible = false,
    guiFn = function(file)
      if file.filetype == "file" and file.createtime then
        im.TextUnformatted(os.date("%Y/%m/%d %I:%M %p", file.createtime))
      end
    end
  },
  {
    name = "Date modified",
    visible = false,
    guiFn = function(file)
      if file.filetype == "file" and file.modtime then
        im.TextUnformatted(os.date("%Y/%m/%d %I:%M %p", file.createtime))
      end
    end
  }
}

local function saveColumnsVisibility()
  local cols = {}
  for _, column in ipairs(columns) do
    cols[column.name] = column.visible
  end
  editor.setPreference("files.fileDialog.columns", cols)
end

local function getFiletypeLabel(suffix)
  if type(suffix[2]) == "string" then
    return suffix[1].."(*"..suffix[2]..")"
  elseif type(suffix[2]) == "table" then
    local res = suffix[1] .."("
    for k, ext in ipairs(suffix[2]) do
      res = (k ~= #suffix[2]) and (res .. "*" .. ext .. ", ") or (res .. "*" .. ext)
    end
    res = res .. ")"
    return res
  end
end

local function smartSearchItemsWindow()
  if not smartSearchWindowPos then return end
  im.SetNextWindowPos(smartSearchWindowPos)
  im.SetNextWindowSize(smartSearchWindowSize)
  im.Begin(smartSearchItemsWindowName, editor.getWindowVisibleBoolPtr(smartSearchItemsWindowName), im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_NoFocusOnAppearing)
  for _, file in ipairs(fileCache) do
    if not (options.select_folder and file.filetype ~= 'dir') then
      if filterFile(file) then
        if im.Selectable1(file.name) then
          smartSearch = false
          ffi.copy(textinput, file.name)
          selectedFile = file
          editor.hideWindow(smartSearchItemsWindowName)
        end
      end
    end
  end
  if not im.IsWindowFocused() and not filenameTextInputFocused then
    editor.hideWindow(smartSearchItemsWindowName)
    smartSearch = false
  end
  im.End()
end

local function onEditorGui()
  --TODO: convert to beginWindow/endWindow
  if editor.isWindowVisible(toolWindowName) ~= true then return end
  editor.setupWindow(toolWindowName)

  --if not fileCache then refreshCache('/') end -- TODO: proper open API with initial path
  if not fileCache then
    editor.hideWindow(toolWindowName)
    return
  end

  if not overwriteDialog then
    --TODO: convert to modal popup
    if im.Begin("File dialog", editor.getWindowVisibleBoolPtr(toolWindowName), im.WindowFlags_MenuBar + im.WindowFlags_NoDocking + im.WindowFlags_NoCollapse + im.WindowFlags_UnsavedDocument) then
      -- Menu Bar
      if im.BeginMenuBar() then
        if im.BeginMenu("Favourites") then
          local favs = editor.getPreference("files.fileDialog.favourites")
          if not tableContains(favs, currentPath) then
            if im.MenuItem1("Add current path") then
              table.insert(favs, currentPath)
              table.sort(favs)
              editor.setPreference("files.fileDialog.favourites", favs)
            end
          else
            if im.MenuItem1("Remove current path") then
              table.remove(favs, arrayFindValueIndex(favs, currentPath))
              table.sort(favs)
              editor.setPreference("files.fileDialog.favourites", favs)
            end
          end
          im.Separator()
          for i, f in ipairs(favs or {}) do
            if im.MenuItem1(f..'##'..i) then
              refreshCache(f)
            end
          end
          im.EndMenu()
        end
        im.EndMenuBar()
      end

      local disabled = false
      if not hasParentDir then
        im.BeginDisabled()
        disabled = true
      end
      im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0,0,0))
      if editor.uiIconImageButton(editor.icons.arrow_upward, im.ImVec2(25 * im.uiscale[0], 25 * im.uiscale[0])) then
        local lastSep = currentPath:reverse():find("/", 2)
        local parentFolder = "/"
        if lastSep then
          parentFolder = currentPath:sub(1, currentPath:len()-lastSep+1 )
        end
        refreshCache(parentFolder)
      end
      im.PopStyleColor()
      if disabled then
        im.EndDisabled()
      end
      im.SameLine()

      local xpos = im.GetCursorPosX()
      local pathPointer = im.ArrayChar(512, currentPath)
      im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, im.GetStyle().ItemSpacing.y))
      if im.InputText("##filepath", pathPointer, nil, im.InputTextFlags_EnterReturnsTrue) then
        local newPath = ffi.string(pathPointer)
        if FS:directoryExists(newPath) then
          refreshCache(newPath)
        end
      end
      local width = im.CalcItemWidth()

      im.SameLine()
      if editor.uiIconImageButton(editor.icons.arrow_downward, im.ImVec2(25 * im.uiscale[0], 25 * im.uiscale[0])) then
        recentDirsWindowPos = im.ImVec2(im.GetWindowPos().x + xpos, im.GetWindowPos().y + im.GetCursorPosY() - im.GetStyle().ItemSpacing.y)
        recentDirsWindowWidth = width
        if editor.isWindowVisible(recentDirsWindowName) == true then
          editor.hideWindow(recentDirsWindowName)
        else
          editor.showWindow(recentDirsWindowName)
        end
      end
      im.PopStyleVar()

      if options.select_folder then
        im.Text("New folder:")
        im.SameLine()
        im.PushItemWidth(150)
        local createNow = false
        if im.InputText("##newfolder", textinputNewFolder, nil, im.InputTextFlags_EnterReturnsTrue) then
          createNow = true
        end
        im.PopItemWidth()
        im.SameLine()
        if im.Button("Create Folder") or createNow then
          local crtPath = ffi.string(pathPointer)
          local newPath = crtPath .. ffi.string(textinputNewFolder)
          FS:directoryCreate(newPath)
          if FS:directoryExists(newPath) then
            refreshCache(newPath)
          end
          ffi.copy(textinputNewFolder, "")
        end
      end

      im.BeginChild1("", im.ImVec2(0, - im.GetTextLineHeightWithSpacing() - im.GetStyle().ItemSpacing.y), true)
      if withPreview == true and selectedFile then
        im.Columns(2, "FileDialogMainColumn")
      end

      im.BeginChild1("FileDialogLeftColumn")


      if im.BeginPopup("ColumnContextMenu", nil, im.WindowFlags_AlwaysAutoResize) then
        for _, column in ipairs(columns) do
          if column.lockedVisibility and column.lockedVisibility == true then im.BeginDisabled() end
          if im.Checkbox(column.name, getTempBool(column.visible)) then
            local value = getTempBool()
            -- Enable a column's visibility.
            if value == true then
              column.visible = value
              columnCount = columnCount + 1
              saveColumnsVisibility()
              im.CloseCurrentPopup()
            else
              -- Disable a column's visiblity but check if it's the last visible one.
              if columnCount > 1 then
                column.visible = value
                columnCount = columnCount - 1
                saveColumnsVisibility()
                im.CloseCurrentPopup()
              end
            end
          end
          if column.lockedVisibility and column.lockedVisibility == true then im.EndDisabled() end
        end
        im.EndPopup()
      end

      -- Get the number of visible columns.
      if not columnCount then
        columnCount = 0
        for _, column in ipairs(columns) do
          if column.visible and column.visible == true then
            columnCount = columnCount + 1
          end
        end
      end

      im.Columns(columnCount, "FileViewColumns")

      -- Set column width.
      if fileViewColumnWidth and columnCount > 1 then
        for k, width in ipairs(fileViewColumnWidth) do
          if k <= im.GetColumnsCount() and im.GetColumnsCount() > 1 then
            im.SetColumnWidth(k-1, width)
          end
        end
      end

      for _, column in ipairs(columns) do
        if column.visible and column.visible == true then
          if im.Selectable1(column.name) then
            -- sortFileCache()
          end
          if im.IsItemClicked(1) then
            im.OpenPopup("ColumnContextMenu")
          end
          im.NextColumn()
        end
      end

      im.Separator()
      im.Columns(1, "FileViewColumns")

      im.BeginChild1("FileList")

      im.Columns(columnCount, "FileViewColumns")

      -- Get the column width so we can sync the width of the colum headers in the next frame.
      fileViewColumnWidth = {}
      if columnCount > 1 then
        for i = 1, im.GetColumnsCount(), 1 do
          fileViewColumnWidth[i] = im.GetColumnWidth(i-1)
        end
      end

      fNameInput = ffi.string(textinput)
      fNameInputLength = #fNameInput

      for _, file in pairs(fileCache) do
        if not (options.select_folder and file.filetype ~= 'dir') then
            for k, column in ipairs(columns) do
              if column.visible and column.visible == true then
                if editor.getPreference("files.fileDialog.gridLines") then
                  if k == 1 then im.Separator() end
                end
                column.guiFn(file)
                im.NextColumn()
              end
            end
        end
      end

      im.Columns(1, "FileViewColumns")
      im.EndChild()
      im.EndChild()

      -- Preview Column
      if withPreview == true and selectedFile then
        im.NextColumn()

        im.BeginChild1("RightColumn")
        basicFilePreviewGui()
        if previewFunctions[selectedFile.extension] then
          previewFunctions[selectedFile.extension]()
        end
        im.EndChild()
        im.Columns(1, "FileDialogMainColumn")
      end
      im.EndChild()

      -- TODO ?
      local pressedEnter = false
      if not options.select_folder then
        im.Text("File name:")
        im.SameLine()
        local itemWidth = im.GetContentRegionAvailWidth() - (buttonsAreaMaxWidth + buttonsAreaMaxWidth) * im.uiscale[0]
        itemWidth = itemWidth > filenameTextInputMinWidth and itemWidth or filenameTextInputMinWidth
        im.PushItemWidth(itemWidth)
        local posX = im.GetCursorPosX()
        if im.InputText('##filename', textinput, nil) then
          smartSearch = true
        end
        if im.IsItemActive() then
          local width = im.CalcItemWidth()
          smartSearchWindowPos =  im.ImVec2(im.GetWindowPos().x + posX, im.GetWindowPos().y + im.GetCursorPosY() + 2)
          smartSearchWindowSize = im.ImVec2(width, 100)
          if  ffi.string(textinput) ~= "" then
            filenameTextInputFocused = true
            smartSearch = true
          end
        else
          filenameTextInputFocused = false
        end
        im.PopItemWidth()
        im.SameLine()
      end
      -- im.PushItemWidth(70)
      -- im.InputText('', textinput) -- combo?
      if not options.select_folder then
        im.SameLine()
        local itemWidth = (im.GetContentRegionAvailWidth() - buttonsAreaMaxWidth * im.uiscale[0])
        itemWidth = itemWidth > filetypeComboMaxWidth and filetypeComboMaxWidth or
          (itemWidth < filetypeComboMinWidth and filetypeComboMinWidth or itemWidth)
        im.PushItemWidth(itemWidth)
        if im.BeginCombo("##file_type", getFiletypeLabel(options.suffix[fileTypeSelected])) then
          for i,v in ipairs(options.suffix) do
            if im.Selectable1(getFiletypeLabel(v), i == fileTypeSelected) then
              local oldval = fileTypeSelected
              fileTypeSelected = i
              if oldval ~= fileTypeSelected then
                refreshCache(currentPath)
              end
            end
          end
          im.EndCombo()
        end
        im.PopItemWidth()
        im.SameLine()
      end
      if im.Button(action) or pressedEnter then
        local fname = ffi.string(textinput)
        if options.select_folder and currentPath ~= "/" then
          execCB({path=currentPath, action=action, stat=currentFolderStat})
        elseif action == "Save" and fname:len() > 0 then
          if fname:reverse():find(options.suffix[fileTypeSelected][2]:reverse()) ~= 1 then
            fname = fname..options.suffix[fileTypeSelected][2]
          end
          if FS:fileExists(currentPath..fname) then
            cbdata = {path=currentPath, action=action, filename=fname, filepath=currentPath..fname, filestat = "overwrite"}
            --im.OpenPopup("overwriting_popup")
          else
            execCB({path=currentPath, action=action, filename=fname, filepath=currentPath..fname, filestat = "new"})
          end
        else -- action == "Open"
          -- check if file actually exists before calling cb func
          local fName = ffi.string(textinput)
          local found = false
          for _, file in ipairs(fileCache) do
            if file.name == fName or file.nameWithoutExt == fName then
              found = true
              execCB({path=currentPath, action=action, filename=file.name, filepath=file.path, filetype=options.suffix[fileTypeSelected]})
            end
          end
          if found == false then
            log("W", "", "File not found in fileCache.")
            editor.showNotification("File not found in current directory.")
          end
        end
      end

      im.SameLine()
      if im.Button('Cancel') then
        editor.hideWindow(toolWindowName)
      end
      -- im.EndPopup()
    end
    im.End()
  else
    -- TODO For now, put the overwrite dialog into the file dialog window, because we cant always force the popup window to be on top
    --if im.BeginPopupModal("overwriting_popup", nil, im.WindowFlags_AlwaysAutoResize) then
    if overwriteDialog then
      --TODO: convert to modal popup
      if im.Begin("File dialog", editor.getWindowVisibleBoolPtr(toolWindowName), im.WindowFlags_NoDocking + im.WindowFlags_NoCollapse + im.WindowFlags_UnsavedDocument) then
        im.TextUnformatted(overwriteDialogText or "Are you sure you want to overwrite this file")
        if im.Button("YES") then
          im.CloseCurrentPopup()
          execCB(cbdata)
          cbdata = nil
        end
        im.SameLine()
        if im.Button("NO") then
          im.CloseCurrentPopup()
          cbdata = nil
        end
      end
    end
    im.End()
  end

  if cbdata then
    overwriteDialog = true
  else
    overwriteDialog = false
  end


  if editor.isWindowVisible(smartSearchItemsWindowName) == true then
   smartSearchItemsWindow()
  elseif smartSearch then
    editor.showWindow(smartSearchItemsWindowName)
  end

  if editor.isWindowVisible(recentDirsWindowName) == true then
    if recentDirsWindowPos then
      im.SetNextWindowPos(recentDirsWindowPos)
    end
    im.SetNextWindowSize(im.ImVec2(recentDirsWindowWidth, 23 * im.uiscale[0] * tableSize(recentDirs) + 5))
    --TODO: convert to modal popup
    im.Begin("recentDirs", editor.getWindowVisibleBoolPtr(recentDirsWindowName), im.WindowFlags_NoTitleBar + im.WindowFlags_NoResize + im.WindowFlags_NoMove + im.WindowFlags_NoScrollbar)
    for _, dir in ipairs(recentDirs) do
      if im.Selectable1(dir) then
        refreshCache(dir)
        editor.hideWindow(recentDirsWindowName)
      end
    end
    if not im.IsWindowFocused() then
      editor.hideWindow(recentDirsWindowName)
    end
    im.End()
  end
end

-- Tooltip functions
local function tooltip_image(file)
  if im.IsItemHovered() then
    im.BeginTooltip()
    local imgSize = getTempTextureObj(file.path).size
    local ratio = imgSize.x / imgSize.y
    local sizex = 64 * ratio
    local sizey = 64
    -- check if size exceeds the maximum size so we do not display 16k preview images
    if sizex > 128 then
      local ratio = sizex / 128
      sizex = sizex / ratio
      sizey = sizey / ratio
    end
    im.Image(
      getTempTextureObj().texId,
      im.ImVec2(sizex, sizey),
      nil, nil, nil,
      editor.color.white.Value
    )
    im.EndTooltip()
  end
end

local function _fileDialog(act, callbackFn, filenameSuffix, selectFolder, defaultPath, preview, overwriteDlgText, caseSensitivePattern)
  smartSearch = false
  ffi.copy(textinput, "")
  if editor.isWindowVisible(toolWindowName) == true then
    log("E", "_fileDialog", "Dialog already open, won't queue or open again")
    return false
  end
  if not callbackFn or type(callbackFn) ~= "function" then
    log("E", "_fileDialog", "Callback function is invalid")
    return false
  end
  if not defaultPath or (type(defaultPath) == "string" and #defaultPath == 0) then
    log("W", "_fileDialog", "'defaultPath' should not be empty")
    defaultPath = "/"
  end
  overwriteDialogText = overwriteDlgText
  selectedFile = nil
  action = act
  fileTypeSelected = 1
  if selectFolder then
    options.suffix = {{"Any files", "*"}}
  else
    options.suffix = filenameSuffix or {{"Any files", "*"}}
    if #options.suffix >1 and options.suffix[1][2] == "*" then
      fileTypeSelected = 2
    end
  end
  callbackFunction = callbackFn-- or nop
  withPreview = preview
  options.select_folder = selectFolder or false
  options.case_sensitive_match = caseSensitivePattern or false
  refreshCache(defaultPath)
  editor.showWindow(toolWindowName)
  return true
end

local function openFile(callbackFn, filenameSuffix, selectFolder, defaultPath, preview, caseSensitivePattern)
  return _fileDialog("Open", callbackFn, filenameSuffix, selectFolder, defaultPath, preview, nil, caseSensitivePattern)
end

local function saveFile(callbackFn, filenameSuffix, selectFolder, defaultPath, overwriteDialogText)
  return _fileDialog("Save", callbackFn, filenameSuffix, selectFolder, defaultPath, false, overwriteDialogText)
end

local function onExtensionLoaded()
end

local function onEditorActivated()
end

local function onEditorDeactivated()
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(630, 430))
  editor.registerWindow(recentDirsWindowName)
  editor.registerWindow(smartSearchItemsWindowName)

  fileTypeIcons = {
    jpg = editor.icons.ab_asset_image,
    jpeg = editor.icons.ab_asset_image,
    png = editor.icons.ab_asset_image,
    dds = editor.icons.ab_asset_image
  }

  fileTypeTooltips = {
    jpg = tooltip_image,
    jpeg = tooltip_image,
    png = tooltip_image,
    dds = tooltip_image
  }

  -- Restore column visibility value.
  local cols = editor.getPreference("files.fileDialog.columns")
  for columnName, visible in pairs(cols) do
    for _, column in ipairs(columns) do
      if columnName == column.name then
        column.visible = visible
      end
    end
  end
  editor.setPreference("files.fileDialog.columns", cols)
  editor.hideWindow(toolWindowName)
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("files")
  prefsRegistry:registerSubCategory("files", "fileDialog", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {maxFilePreviewSize = {"int", 256, "The maximum file preview rectangle size", nil, 128, 1024}},
    {gridLines = {"bool", false, ""}},
    -- hidden
    {favourites = {"table", {}, "", nil, nil, nil, true}},
    {columns = {"table", {}, "", nil, nil, nil, true}},
  })
end

-- public interface
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorActivated = onEditorActivated
M.onEditorDeactivated = onEditorDeactivated
M.onExtensionLoaded = onExtensionLoaded
M.onEditorRegisterPreferences = onEditorRegisterPreferences

M.openFile = openFile
M.saveFile = saveFile

return M