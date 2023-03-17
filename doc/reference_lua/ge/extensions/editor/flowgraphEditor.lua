-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local ffi = require('ffi')

local M = {}
local im = ui_imgui
local fge = ui_flowgraph_editor

local executionView
local windows
local pushedActionMap = false

M.pushedNodeLibActionMap = false
local nodelib
local main
local nodePreviewPopup
local properties
local search
local eventView
local welcome
local mgrChanged = false
local newManager = nil
local mgr = nil
local fgMgr = nil
local currentFile = nil
local dirtyChildren = {}

local showMain = true
M.lastOpenedFolder = 'flowEditor/'
local autoSaveDir = "flowEditor/autoSaves/"
local autoSaveTimer = 120
local lastMousePos = im.ImVec2(0,0)
local lastMouseTimer = 0
M.allowTooltip = false
M.settings = {
  viewModes = {'default', 'simple', 'flowLevel', 'debug'},
}
M.requestedEditor = false

M.showSmallFgWindow = im.BoolPtr(false)
M.switchToSmallWindow = false

local function attach(newMgr)
  mgr = newMgr
  if mgr then
    mgr:attach(M)
  end
  M.nodelib:attach(mgr)
  M.nodePreviewPopup:attach(mgr)
  main:attach(mgr)
  for _,win in ipairs(windows) do
    win:attach(mgr)
  end
  if mgr.graph then
    mgr.graph.restoreView = true
  end
  autoSaveTimer = editor.getPreference("flowgraph.general.autosaveInterval")
end

local function detach()
  mgr = nil
end

local function updateRecentFiles(filepath)
  local recentFiles = editor.getPreference("flowgraph.general.recentFiles") or {}
  local idx = arrayFindValueIndex(recentFiles, filepath)
  if idx then
    table.remove(recentFiles, idx)
  end
  table.insert(recentFiles, 1, filepath)
  while #recentFiles > editor.getPreference("flowgraph.general.recentFileCount") do
    table.remove(recentFiles, editor.getPreference("flowgraph.general.recentFileCount")+1)
  end
  editor.setPreference("flowgraph.general.recentFiles", recentFiles)
end

local function openFile(fCbData, openAsNewManager, keepSavedDirs)
  --currentFile = fCbData.filepath
  local dir, filename, ext = path.split(fCbData.filepath)
  M.lastOpenedFolder = dir
  if openAsNewManager then
    --local targetMgr = fgMgr.addManager(data)
    local targetMgr = fgMgr.loadManager(fCbData.filepath, nil, keepSavedDirs)
    M.setManager(targetMgr)
    targetMgr:updateEditorPosition()
  else
    local data = jsonReadFile(fCbData.filepath)
    if data then
      mgr:_onDeserialized(data)
      mgr:updateEditorPosition()
      mgr.historySnapshot("Loaded File " .. fCbData.filepath)
    end
  end
  updateRecentFiles(fCbData.filepath)
end

local function closeCurrent()
  fgMgr.removeManager(mgr)
  M.setManager(fgMgr.getAllManagers()[1] or nil)
end

local function saveMacroAs(graph)
  dirtyChildren = graph:getDirtyChildren()
  if not tableIsEmpty(dirtyChildren) then
    im.OpenPopup("Unsaved macros")
  else
    extensions.editor_fileDialog.saveFile(function(data)mgr:saveMacro(graph, data)end, {{"Node graph Files",".macro.flow.json"}}, false, "/flowEditor/macros/")
  end
end

local function saveMacro(graph)
  dirtyChildren = graph:getDirtyChildren()
  if not tableIsEmpty(dirtyChildren) then
    im.OpenPopup("Unsaved macros")
  else
    if graph.macroPath then
      mgr:saveMacro(graph, {filepath = graph.macroPath})
    else
      local tag = ffi.string(properties.macroTagField)
      if tag~='' then
        table.insert(mgr.macroTags,tag)
      end
      extensions.editor_fileDialog.saveFile(function(data)mgr:saveMacro(graph, data)end, {{"Node graph Files",".macro.flow.json"}}, false, "/flowEditor/macros/")
    end
  end
end

local function saveCurrent()
  if mgr.graph.type == "macro" and mgr.graph.macroPath ~= nil then
    M.saveMacro(mgr.graph)
  else
    M.save()
  end
end

local function save()
  if (not editor.getPreference("flowgraph.general.editorDebug")) and mgr.transient then return end
  if mgr.savedDir and mgr.savedFilename then
    M.saveFile()
  else
    extensions.editor_fileDialog.saveFile(function(data) M.saveAsFile(data)end, {{"Node graph Files",".flow.json"}}, false, M.lastOpenedFolder)
  end
  autoSaveTimer = editor.getPreference("flowgraph.general.autosaveInterval")
end

local function autoSave()
  if autoSaveTimer > 0 then return end
  if not mgr.allowEditing then return end
  if mgr.transient then return end
  local data = mgr:_onSerialize()
  local time = os.time(os.date("!*t"))
  jsonWriteFile(autoSaveDir .. time.."_"..mgr.name:gsub('%W','_')..".flow.json", data, true, 20)
  log("I","autosave","Autosaved flowgraph under " .. autoSaveDir .. time.."_"..mgr.name..".flow.json")
  autoSaveTimer = editor.getPreference("flowgraph.general.autosaveInterval")
end

local function saveFile()
  if (not editor.getPreference("flowgraph.general.editorDebug")) and mgr.transient then
    log("E","saveFile","Transient Projects cannot be saved.")
  end
  if not mgr.savedDir or not mgr.savedFilename then
    log("E","saveFile","saving file without name/path?")
    return
  end

  if mgr.runningState ~= 'stopped' then
    log("E","saveFile","Cannot save a non-stopped project.")
    return
  end

  for id,graph in pairs(mgr.graphs) do
    if graph.type == "graph" or not graph.macroPath then
      graph:setDirty(false, false)
    end
  end
  for id,macro in pairs(mgr.macros) do
    if not macro.macroPath then
      macro:setDirty(false, false)
    end
  end
  if mgr.name == "New Project" then
    --TODO(AK) 20/06/2019: Is there a better way of extracting this filename without messing with LUA string parsing
    mgr.name = string.gsub(mgr.savedFilename, "(.*)%.flow.json", "%1")
  end

  local data = mgr:_onSerialize()
  jsonWriteFile(mgr.savedDir .. mgr.savedFilename, data, true, 20)

  updateRecentFiles(mgr.savedDir..mgr.savedFilename)
end

local function saveAsFile(fCbData)
  local dir, filename, ext = path.split(fCbData.filepath)
  mgr.savedDir = dir
  mgr.savedFilename = filename
  M.lastOpenedFolder = dir
  M.saveFile()
end

local function initWindows()
  --if next(windows) then return end
  -- window creation
  rawset(_G, '_flowgraph_createMgrWindow', function(C)
    return {
      window = C,
      create = function(emgr) return require('/lua/ge/extensions/editor/flowgraph/basewindow').use(emgr, C) end
    }
  end)

  -- init other windows
  windows = {}

  main = require('/lua/ge/extensions/editor/flowgraph/main').create(M)
  table.insert(windows, require('/lua/ge/extensions/editor/flowgraph/overview').create(M))
  table.insert(windows, require('/lua/ge/extensions/editor/flowgraph/stateView').create(M))
  eventView = require('/lua/ge/extensions/editor/flowgraph/events').create(M)
  table.insert(windows, eventView)
  local examples = require('/lua/ge/extensions/editor/flowgraph/examples').create(M)
  table.insert(windows, examples)
  properties = require('/lua/ge/extensions/editor/flowgraph/properties').create(M)

  table.insert(windows, properties)
  table.insert(windows, require('/lua/ge/extensions/editor/flowgraph/variables').create(M))
  table.insert(windows, require('/lua/ge/extensions/editor/flowgraph/projectSettings').create(M))
  table.insert(windows, require('/lua/ge/extensions/editor/flowgraph/history').create(M))
  welcome = require('/lua/ge/extensions/editor/flowgraph/welcome').create(M)
  welcome.examples = examples
  table.insert(windows, welcome)

  table.insert(windows, require('/lua/ge/extensions/editor/flowgraph/nodelibrary').create(M))
  executionView = require('/lua/ge/extensions/editor/flowgraph/execution').create(M)
  table.insert(windows, executionView )
  search = require('/lua/ge/extensions/editor/flowgraph/search').create(M)
  table.insert(windows, search)
  table.insert(windows, require('/lua/ge/extensions/editor/flowgraph/references').create(M))
  table.sort( windows, function (a,b) return a.windowDescription < b.windowDescription end)

  M.nodelib = require('/lua/ge/extensions/editor/flowgraph/nodelibrary').create(M)
  M.nodelib:setStatic()
  M.nodePreviewPopup = require('/lua/ge/extensions/editor/flowgraph/nodePreview').create(M)

  table.insert(windows, require('/lua/ge/extensions/editor/flowgraph/garbageDebug').create(M))

  M.arrowControllableWindow = nil
  --[[
  local noneOpen = true
  for _,w in ipairs(windows) do noneOpen = noneOpen and not editor.isWindowVisible(w.windowName) end
  if noneOpen then
    editor.showWindow('fg_properties')
    editor.showWindow('fg_nodelib')
    editor.showWindow('fg_execution')
    editor.showWindow('fg_welcome')
  end
  ]]
end

local function onEditorGui(dtReal, dtSim, dtRaw)
  M.arrowControllableWindow = nil
  local closed = ( not editor.isWindowVisible(main.windowName)) --and (not editor.isWindowVisible(executionView.windowName))
  --dump(closed)
  if closed then
    properties:unselect()
    if pushedActionMap then
      popActionMap("FlowgraphMain")
      popActionMap("Flowgraph")
      popActionMap("NodeLibrary")
      pushedActionMap = false
      M.pushedNodeLibActionMap = false
    end
    return
  end
  local mousePos = im.GetMousePos()
  if mousePos.x == lastMousePos.x and mousePos.y == lastMousePos.y then
    lastMouseTimer = lastMouseTimer + dtReal
  else
    lastMouseTimer = 0
  end
  M.allowTooltip = lastMouseTimer > 0.5 and not im.IsAnyMouseDown()

  if M.previousMgrName then
    --print("previous mgr is " .. M.previousMgrName)
    for _, m in ipairs(fgMgr.getAllManagers())  do
      if not done and m.name == M.previousMgrName then
        M.setManager(m)
      end
    end
    M.previousMgrName = nil
  end


  if mgrChanged then
    mgr = newManager
    newManager = nil
    mgrChanged = false
    if mgr then
      attach(mgr)
    end
  end

  if mgr then
    if showMain then
      M.drawEditor(dtReal,dtSim,dtRaw)
    else
      M.drawExecution()
    end
  else
    --TODO: convert to beginWindow/endWindow
    local opn = im.BoolPtr(true)
    if im.Begin("Flowgraph Editor##NoProject", opn, im.flags(im.WindowFlags_MenuBar)) then
      if im.BeginMenuBar() then
        if im.MenuItem1("New Project") then
          local m = core_flowgraphManager.addManager()
          M.setManager(m)
        end
        if im.MenuItem1("Load Project...") then
          extensions.editor_fileDialog.openFile(function(data)M.openFile(data, true)end, {{"Any files", "*"},{"Node graph Files",".flow.json"}}, false, M.lastOpenedFolder)
        end
        if im.BeginMenu("Recent Files...") then
          local recentFiles = editor.getPreference("flowgraph.general.recentFiles") or {}
          if #recentFiles == 0 then
            im.BeginDisabled()
            im.Text("No Recent Files!")
            im.EndDisabled()
          else
            for idx, file in ipairs(recentFiles) do
              if FS:fileExists(file) then
                if im.MenuItem1(idx.." - " .. file) then
                  M.openFile({filepath = file}, true)
                end
              else
                im.BeginDisabled()
                im.Text(idx.." - " .. file)
                im.EndDisabled()
                ui_flowgraph_editor.tooltip("No File Found under " .. dumps(file) .. " !")
              end
            end
          end
          im.EndMenu()
        end
        M.drawRestoreMenu()
        im.EndMenuBar()
      end
      welcome:drawContent()
      im.End()
    end
    if not opn[0] then
      editor.hideWindow(main.windowName)
    end
  end
  if not M.arrowControllableWindow and M.pushedNodeLibActionMap then
    popActionMap("NodeLibrary")
    M.pushedNodeLibActionMap = false
  end
  lastMousePos = im.GetMousePos()

  if im.BeginPopupModal("Unsaved macros") then
    im.Text('There are unsaved macros inside this macro. Please save those first before saving this one.')
    im.Text('The unsaved macros are the following: ')
    for id,_ in pairs(dirtyChildren) do
      im.Text(mgr.macros[id].name)
    end

    if im.Button('Ok') then
      dirtyChildren = nil
      im.CloseCurrentPopup()
    end
    im.EndPopup()
  end
end

local function drawContextMenus()
  im.SetNextWindowSize(im.ImVec2(0,350 * im.uiscale[0]), im.Cond_Always)
  if im.BeginPopup("CreateNodeContentMenu") then
    M.nodelib:drawContent(mgr.newNodePos)
    im.EndPopup()
  end
end

local function drawExecution()
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(8, 8))
  executionView:drawAlone()
  im.PopStyleVar()
end

local function addHistory(title, graph)
  print(title)
  local snap = { title = title}
  if graph == nil then
    snap.graph = mgr.graph
  elseif type(graph) == "table" then
    snap.graph = graph
  else
    snap.graph = nil
  end
  M.delayedHistorySnapshot = snap
end

local restoreFiles = {}
local function drawRestoreMenu()
  if im.BeginMenu("Restore...") then
    if restoreFiles == nil then
      local allFiles = FS:findFiles(autoSaveDir, '*flow.json', -1, true, false)
      local filesByOriginal = {}
      for _, fileName in ipairs(allFiles) do
        local file = jsonReadFile(fileName)
        if file then
          local name = file.savedFilename or "Unnamed File"
          if name then
            filesByOriginal[name] = filesByOriginal[name] or {list = {}, date = 0}
            local date = string.match(fileName,"%d+") or 0
            filesByOriginal[name].date = math.max(filesByOriginal[name].date, date)
            table.insert(filesByOriginal[name].list,{shortName = name, fileName = fileName, date = date, dateFormatted = os.date('%Y-%m-%d %H:%M UTC', date)})
          end
        end
      end
      local sorter = function(a,b) return a.date > b.date end
      local originalFileNames = {}
      for fo, elem in pairs(filesByOriginal) do
        table.insert(originalFileNames, fo)
        table.sort(elem.list, sorter)
      end
      table.sort(originalFileNames, function(a,b) return filesByOriginal[a].date > filesByOriginal[b].date end)
      restoreFiles = {names = originalFileNames, filesByName = filesByOriginal, newest = {}}
      for idx, name in ipairs(restoreFiles.names) do
        for idx, elem in ipairs(restoreFiles.filesByName[name].list) do
          if #restoreFiles.newest < 5 then
            table.insert(restoreFiles.newest, elem)
          else
            break
          end
        end
        if #restoreFiles.newest >= 5 then
          break
        end
      end
    end

    if #restoreFiles.names == 0 then
      im.BeginDisabled()
      im.Text("No Files to Restore!")
      im.EndDisabled()
    else
      for idx, elem in ipairs(restoreFiles.newest) do
        if im.MenuItem1(idx.." - " ..elem.shortName.." - " .. elem.dateFormatted) then
          M.openFile({filepath = elem.fileName}, true, true)
        end
      end
      im.Separator()
      for i, name in ipairs(restoreFiles.names) do
        if im.BeginMenu(name..'##restore'..i) then
          for idx, elem in ipairs(restoreFiles.filesByName[name].list) do
            if im.MenuItem1(idx.." - " .. elem.dateFormatted) then
              M.openFile({filepath = elem.fileName}, true, true)
            end
          end
          im.EndMenu()
        end
      end
    end
    im.EndMenu()
  else
    restoreFiles = nil
  end
end

local function drawEditor(dtReal,dtSim,dtRaw)
  autoSaveTimer = autoSaveTimer - dtReal
  --dump(mgr.name)
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(8, 8))
  ui_flowgraph_editor.SetCurrentEditor(M.ectx)
  mgr:updateEditorSelections()
  M.showSmallFgWindow[0] = false
  --M.switchToSmallWindow = false

  local focus = false
  mgr:draw(dtReal,dtSim,dtRaw)
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(2, 2))

  main:Begin('Flowgraph Editor', im.flags(im.WindowFlags_MenuBar, im.WindowFlags_NoScrollbar, im.WindowFlags_NoCollapse))
  main:draw()
  im.PopStyleVar()
  for _, win in pairs(windows) do
    win:draw(dtReal,dtSim,dtRaw)
    focus = focus or win.hasFocus
  end
  main:End()
  mgr:updateEditorSelections()
  focus = focus or main.hasFocus

  local nodeId = tonumber(ui_flowgraph_editor.GetDoubleClickedNode())
  if nodeId ~= 0 then
    mgr.graph.nodes[nodeId]:_doubleClicked()
  end
  --print(tonumber(ui_flowgraph_editor.GetDirtyReason()))


  M.drawContextMenus()
  ui_flowgraph_editor.SetCurrentEditor(nil)
  M.nodePreviewPopup:draw()
  focus = focus or M.nodePreviewPopup.hasFocus

  if M.delayedHistorySnapshot ~= nil then
    mgr:historySnapshot(M.delayedHistorySnapshot.title)
    if M.delayedHistorySnapshot.graph ~= nil then
      M.delayedHistorySnapshot.graph:setDirty(true)
      if M.delayedHistorySnapshot.graph.type == 'macro' then
        mgr:updateInstances(M.delayedHistorySnapshot.graph)
      end
      if M.delayedHistorySnapshot.graph.type == 'graph' and M.delayedHistorySnapshot.graph:getParent() ~= nil then
        local iNode = mgr:findIntegratedNode(M.delayedHistorySnapshot.graph)
        if iNode then
          mgr:refreshIntegratedPins(iNode)
        end
      end
    end
    M.autoSave()
    M.delayedHistorySnapshot = nil
  end

  mgr.graphsToUpdate = {}
  im.PopStyleVar()

  if focus then
    --print("Focus: " .. tostring(focus))
    if not pushedActionMap then
      pushActionMapHighestPriority("FlowgraphMain")
      table.insert(editor.additionalActionMaps, "FlowgraphMain")
      pushedActionMap = true
    end
  else
    pushedActionMap = false
    if pushedActionMap then
      popActionMap("FlowgraphMain")
      popActionMap("Flowgraph")
    end
  end
  if M.switchToSmallWindow then
    editor.setEditorActive(false)
    M.showSmallFgWindow[0] = true
  end
  M.switchToSmallWindow = false
end
M.forceOpen = {states = true, log = true}
-- Small Testing Window
local function smallFgWindow(dtReal, dtSim, dtRaw)
  if not M.showSmallFgWindow[0] then return end
  im.Begin("FG Monitor", M.showSmallFgWindow)
    if editor.uiIconImageButton(editor.icons.fullscreen, im.ImVec2(20, 20)) then
      editor.setEditorActive(true)
    end
    ui_flowgraph_editor.tooltip("Maximize Editor.")
    im.SameLine()
    if mgr and mgr.runningState ~= 'stopped' then
      if editor.uiIconImageButton(editor.icons.stop, im.ImVec2(20, 20)) then
        mgr:setRunning(false)
        editor.setEditorActive(true)
      end
      ui_flowgraph_editor.tooltip("Stop Execution")
      im.SameLine()
      im.Text("Project Running")
      if M.forceOpen.states ~= nil then
        im.SetNextItemOpen(M.forceOpen.states)
      end
      if im.TreeNode1("Active States") then
        local stateIds = {}
        for id, state in pairs(mgr.states.states) do
          if state.active then
            table.insert(stateIds, id)
          end
        end
        table.sort(stateIds)
        for _, id in ipairs(stateIds) do
          im.BulletText(mgr.states.states[id].name)
          im.SameLine()
          im.BeginDisabled()
          local loc = mgr.states.states[id].graph:getLocation(true)
          im.Text(loc)
          im.EndDisabled()
        end
        im.TreePop()
      end
      if M.forceOpen.log ~= nil then
        im.SetNextItemOpen(M.forceOpen.log)
      end
      if im.TreeNode1("Event Log") then
        eventView:drawContent()
        im.TreePop()
      end

    else
      if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(20, 20)) then
        mgr:setRunning(true)
      end
      im.SameLine()
      im.Text("Project Stopped")
    end
  im.End()
  M.forceOpen.states = nil
  M.forceOpen.log = nil
end

M.onUpdate = smallFgWindow

local function onWindowMenuItem()
  open()
end

local function open()
  editor.showWindow(main.windowName)
  showMain = true
end

local function onEditorDeactivated()
  pushedActionMap = false
  popActionMap("FlowgraphMain")
  popActionMap("Flowgraph")
end

local function customFieldEditor(objectIds, fieldValue, fieldName, fieldLabel, fieldDesc, fieldType, fieldTypeName, customData, pasteCallback, contextMenuUI)
  -- return only when the field value changed, otherwise the undo system will overflow
  --return {fieldValue = fieldValue, editEnded = true }
  print(">>> customFieldEditor")
end

local function onEditorInitialized()
  initWindows()
  editor.addWindowMenuItem("Flowgraph Editor", function() M.open() end,{groupMenuName="Gameplay"})
  if not M.ectx then
    M.ectx = ui_flowgraph_editor.CreateEditor(ui_imgui.ctx)
    ui_flowgraph_editor.SetCurrentEditor(M.ectx)
    ui_flowgraph_editor.EnableShortcuts(true)

  end
  fgMgr = extensions['core_flowgraphManager']

    M.setManager(mgr or fgMgr.getAllManagers()[1])

  --M.executionOpenOnly = im.BoolPtr(M.res and M.res.executionOpenOnly or false)


  editor.registerCustomFieldInspectorEditor("FlowgraphSceneObject", "filename", customFieldEditor)


  if M.windowOpenInfo then
    for _, win in ipairs( windows) do
      if M.windowOpenInfo[win.windowName] then
        win:open()
      else
        win:close()
      end
    end
    if  M.windowOpenInfo[main.windowName] then
      main:open()
    end
    M.windowOpenInfo = nil
  end

  -- add custom edit mode for transform nodes
  editor.editModes.flowgraphTransform =
    {
      displayName = "Transform Node Mode",
      onActivate = nop,
      onDeactivate = nop,
      onUpdate = nop,
      onToolbar = nil
    }
end

local function setManager(newMgr, instant)
  mgrChanged = true
  newManager = newMgr
  if instant then
    mgr = newMgr
  end
end

local function onSerialize()
  if not windows then return {} end
  if not mgr then return end
  local index = 0
  for i, m in ipairs(fgMgr.getAllManagers()) do
    if m == mgr then
      index = i
    end
  end
  local res = {currentMgrName = mgr.name}
  --dumpz(mgr,2)
  ui_flowgraph_editor.SetCurrentEditor(M.ectx)
  for _, m in ipairs(fgMgr.getAllManagers()) do
    m:updateNodePositions()
  end
  --jsonWriteFile("flowEditor/data_temp.json", res, true)
  res.windows = {}
  for _, win in ipairs(windows) do
    res.windows[win.windowName] = editor.isWindowVisible(win.windowName)
  end
  res.windows[main.windowName] = editor.isWindowVisible(main.windowName)
  return res
end


local function resetFrecencyDataUi()
  if im.Button("Reset Node Library Usage Data", im.ImVec2(im.GetContentRegionAvailWidth(), 0)) then
    editor.setPreference("flowgraph.general.nodeFrecency", {})
  end
  im.tooltip("Resets the recently used node data. This data is used to improve the accuracy of search in the node library, by putting nodes you use more often at the top of the results.")
end

local function customLuaNodesManagerUi()
  local sortedNames = tableKeys(editor.getPreference('flowgraph.general.customLuaNodes'))
  table.sort(sortedNames)
  local del = nil
  im.Text(tostring(tableSize(sortedNames)) .. " Custom Lua Nodes:")
  for _, name in ipairs(sortedNames) do
    if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(20, 20)) then
      del = name
    end
    im.SameLine()
    im.Text(name)
  end
  im.Separator()
  if del then
    local newNodes = editor.getPreference('flowgraph.general.customLuaNodes')
    newNodes[del] = nil
    editor.setPreference('flowgraph.general.customLuaNodes', newNodes)
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("flowgraph")
  prefsRegistry:registerSubCategory("flowgraph", "general", "General",
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {hideSimpleNames = {"bool", false, "Hides pins that are named 'flow' or 'value'."}},
    {displayConstPinValues = {"bool", false, "Displays the constant pin values for hardcoded pins."}},
    {showHiddenPinCount = {"bool", true, "Shows the number of hidden pins for nodes."}},
    {hideUnusedPinsWhenRunning = {"bool", false, "Hides all unused pins when the project is running."}},
    {hideDuplicateEvents = {"bool",true,"Hides duplicates of events in the event log."}},
    {showNodeBehaviours = {"bool",true,"", nil,nil,nil}},
    {minimizeFlowgraphWhenRunning = {"bool",false,"", nil,nil,nil, true}},
    {alwaysExpandVariables = {"bool",false,"Always have all variables expanded in the variables view."}},
    {repeatVariableCreation = {"bool",true,"Sets the default value for 'Create Another' in the variables creation dialogue."}},
    {showAdvancedReferenceData = {"bool", false, "Shows more advanced data in the reference window."}},
    {showObsoleteNodes = {"bool", false, "Shows obsolete nodes in the node library."}},
    {autoConnectResetPins = {"bool", false, "Automatically connects reset pins of once nodes to the enterState pin of the onUpdate node."}},

    {recentFileCount = {"int",10,"How many files are kept in the 'Recently opened files' list.",nil, 1,50}},

    {eventTimeFormat = {'string','Project Time',"",nil, nil, nil, true}},
    {eventAutoScroll = {'bool',true,"",nil, nil, nil, true}},
    {recentFiles = {"table", {}, "", nil, nil, nil, true}},
    {nodeFrecency = {"table", {}, "", nil, nil, nil, false, nil, resetFrecencyDataUi}},
    {customLuaNodes = {"table", {}, "", nil, nil, nil, false, nil, customLuaNodesManagerUi}},
    {autosaveInterval = {"int",120,"Time in seconds between autosaves.",nil, 30,600}},
  })

  prefsRegistry:registerSubCategory("flowgraph", "debug", "Debug",
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {editorDebug = {"bool", false, "Enables various advanced developer functions."}},
    {displayIds = {"bool", false, "Displays the Ids of nodes and other elements."}},
    {duplicateIdCheck = {"bool", false, "Continous duplicate Id checking. Slow."}},
    {displayFlowLinks = {"bool", false, "Displays the whole project flattened.","Flat Project"}},
    {transientEditable = {"bool", false, "Makes Transient graphs editable","Editable Transient Graphs"}},
    -- hidden
    {displayNodesInOverview = {"bool", false, "", nil, nil, nil, true}},
    {viewMode = {"string", "default", "", nil, nil, nil, true}}, --TODO: make it an enum ? or is it changed in the fg UI only
    {minEditorHeight = {"int",150,"Minimum height before hiding editor due to too small space"}},

    {debugGarbage = {'bool',false,"",nil, nil, nil, true}},
    {garbageSort = {"string", "q90", "", nil, nil, nil, true}}, --TODO: make it an enum ? or is it changed in the fg UI only

  })
end

local function onDeserialized(data)
  M.windowOpenInfo = data.windows
  M.previousMgrName = data.currentMgrName
end

local function getManager()
  return mgr
end

local function windowsMenu()
  for _, win in ipairs(windows) do
    if win.windowName and win.windowDescription then
      if im.MenuItem1(win.windowDescription, nil, editor.isWindowVisible(win.windowName)) then
        win:toggle()
      end
    end
  end
  im.Separator()
  if im.MenuItem1("Open All") then
    for _, win in ipairs(windows) do
      win:open()
    end
  end
    if im.MenuItem1("Close All") then
    for _, win in ipairs(windows) do
      win:close()
    end
  end
end

local function onClientStartMission()
  if M.requestedEditor then
    if not editor.active then
      editor.toggleActive()
    end
    M.open()
    --for _, win in ipairs( windows) do
    --  win:open()
    --end
    M.requesteEditor = false
  end
end

local function showNodeReferences(node)
  local winReferences = nil
  for _, win in ipairs( windows) do
    if win.windowName == 'fg_references' then
      winReferences = win
      break;
    end
  end
  if not winReferences then return end
  winReferences:open()
  winReferences:searchFor(node)
end

local function arrowControllableWindowCall(fun, ...)
  if M.arrowControllableWindow then
    M.arrowControllableWindow[fun](M.arrowControllableWindow, ...)
  end
end

local function uiFocusNodesShortcut()
  if not mgr then return end
  if mgr.selectedNodeCount > 0 then
    mgr.graph.focusSelection = true
  else
    mgr.graph.focusContent = true
  end
  mgr.graph.focusDelay = 1
end

local function uiHideShortcut(hide)
  if not mgr then return end
  if mgr.selectedLinkCount == 1 then
    for lId, _ in pairs(mgr.selectedLinks) do
      local link = mgr.graph.links[lId]
      if link then
        link.hidden = not link.hidden
      end
    end
  end
  if mgr.selectedLinkCount > 1 then
    local onCount, offCount = 0,0
    for lId, _ in pairs(mgr.selectedLinks) do
      local link = mgr.graph.links[lId]
      if link then
        if link.hidden then
          onCount = onCount +1
        else
          offCount = offCount +1
        end
      end
    end
    for lId, _ in pairs(mgr.selectedLinks) do
      local link = mgr.graph.links[lId]
      if link then
        link.hidden = onCount < offCount
      end
    end
  end
  if mgr.selectedLinkCount == 0 then
    for _, link in pairs(mgr.graph.links) do
      if  mgr.selectedNodes[link.targetNode.id] or mgr.selectedNodes[link.sourceNode.id] then
        link.hidden = hide
      end
    end
  end
  mgr:historySnapshot("Hidden or Unhidden Elements.")
end

local function uiShowSourceShortcut()
  if mgr.selectedNodeCount == 1 then
    local id, sel = next(mgr.selectedNodes)
    local node = mgr.graph.nodes[id]
    if node then
      Engine.Platform.openFile(node.sourcePath)
    end
  end
end

local function uiAutoConnectShortcut()
  local nodeA, nodeB = nil, nil
  local success = false
  if mgr.selectedNodeCount == 0 and mgr.selectedLinkCount == 1 then
    for lId, _ in pairs(mgr.selectedLinks) do
      local link = mgr.graph.links[lId]
      if link then
        nodeA, nodeB = link.sourceNode, link.targetNode
      end
    end
  end
  if mgr.selectedNodeCount == 1 then
    local connectedNodes = {}
    local connectedIds = {}
    for nId, _ in pairs(mgr.selectedNodes) do
      local node = mgr.graph.nodes[nId]
      nodeA = node
      for _, pin in ipairs(node.pinList) do
        local link = pin:getFirstConnectedLink()
        if link then
          local other = link.sourceNode == node and link.targetNode or link.sourceNode
          if not connectedIds[other.id] then
            table.insert(connectedNodes, other)
            connectedIds[other.id] = true
          end
        end
      end
      break
    end
    if #connectedNodes == 1 then
      nodeB = connectedNodes[1]
    end
  end
  if mgr.selectedNodeCount == 2 then
    for nId, _ in pairs(mgr.selectedNodes) do
      local node = mgr.graph.nodes[nId]
      if not nodeA then
        nodeA = node
      else
        nodeB = node
        break
      end
    end
  end
  if nodeA and nodeB then
    if nodeA.nodePosition[1] > nodeB.nodePosition[1] then
      nodeA, nodeB = nodeB, nodeA
    end
    if nodeA.nodePosition[1] == nodeB.nodePosition[1] then
      if nodeA.nodePosition[2] > nodeB.nodePosition[2] then
        nodeA, nodeB = nodeB, nodeA
      end
    end
    local availableA, availableB = {},{}
    for _, pin in pairs(nodeA.pinOut) do
      if not pin.hidden then
        table.insert(availableA, pin)
      end
    end
    for _, pin in pairs(nodeB.pinInLocal) do
      if not pin.hidden and not pin:getFirstConnectedLink() and pin.pinMode ~= "hardcoded" then
        table.insert(availableB, pin)
      end
    end

    for _, pinB in ipairs(availableB) do
      local matches = {}
      for _, pinA in ipairs(availableA) do
        if mgr.graph:canCreateLink(pinA, pinB) then
          M.nodelib:ratePinSimilarity(pinA, pinB)
          if pinA.__matchScore > 0 then
            table.insert(matches, pinA)
          end
        end
      end
      table.sort(matches, function(a,b) return a.__matchScore > b.__matchScore end)
      if matches[1] then
        success = true
        mgr.graph:createLink(matches[1], pinB)
      end
    end
  end
  if success then
    mgr:historySnapshot("Auto-Connected Nodes.")
  end
end

local function uiDisconnectShortcut()
  local linksToRemove = {}
  if mgr.selectedNodeCount == 0 then
    for lId, _ in pairs(mgr.selectedLinks) do
      local link = mgr.graph.links[lId]
      if link then
        table.insert(linksToRemove, link)
      end
    end
  else
    for _, link in pairs(mgr.graph.links) do
      if    mgr.selectedNodes[link.targetNode.id] and not mgr.selectedNodes[link.sourceNode.id]
         or mgr.selectedNodes[link.sourceNode.id] and not mgr.selectedNodes[link.targetNode.id] then
        table.insert(linksToRemove, link)
      end
    end
    if #linksToRemove == 0 then
      for _, link in pairs(mgr.graph.links) do
        if mgr.selectedNodes[link.targetNode.id] and mgr.selectedNodes[link.sourceNode.id] then
          table.insert(linksToRemove, link)
        end
      end
    end
  end
  for _, link in ipairs(linksToRemove) do
    mgr.graph:deleteLink(link)
  end
  if next(linksToRemove) then
    mgr:historySnapshot("Auto-Disconnected Nodes.")
  end
end


local function uiFindShortcut()
  search:open()
  search.focusSearch = 2
end

local function uiToggleCategoryShortcut()
  if mgr.selectedNodeCount == 1 then
    local id, sel = next(mgr.selectedNodes)
    local node = mgr.graph.nodes[id]
    if node then
      node:toggleDynamicMode()
    end
  end
end

local function isActionMapEnabled(map)
  local list = ActionMap:getList()
  if list and list.active then
    for _, e in ipairs(list.active) do
      if e.name == map.."ActionMap" and e.enabled then
        return true
      end
    end
  end
  return false
end
M.getPropertiesWindow = function() return properties end
M.uiFocusNodesShortcut = uiFocusNodesShortcut
M.uiHideShortcut = uiHideShortcut
M.uiShowSourceShortcut = uiShowSourceShortcut
M.uiAutoConnectShortcut = uiAutoConnectShortcut
M.uiFindShortcut = uiFindShortcut
M.uiDisconnectShortcut = uiDisconnectShortcut
M.uiToggleCategoryShortcut = uiToggleCategoryShortcut
M.isActionMapEnabled = isActionMapEnabled

M.arrowControllableWindowCall = arrowControllableWindowCall

M.open = open
M.closeCurrent = closeCurrent
M.autoSave = autoSave
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorDeactivated = onEditorDeactivated

M.drawRestoreMenu = drawRestoreMenu
M.drawExecution = drawExecution
M.drawEditor = drawEditor
M.drawContextMenus = drawContextMenus
M.setManager = setManager
M.getManager = getManager

M.showNodeReferences = showNodeReferences
M.saveCurrent = saveCurrent
M.saveMacro = saveMacro
M.save = save
M.saveFile = saveFile
M.saveAsFile = saveAsFile
M.openFile = openFile
M.windowsMenu = windowsMenu
M.addHistory = addHistory
M.onClientStartMission = onClientStartMission
M.onEditorRegisterPreferences = onEditorRegisterPreferences
return M