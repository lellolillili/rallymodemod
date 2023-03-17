-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

local ffi = require('ffi')

local _uid = 0 -- do not use ever
local function getNextUniqueIdentifier()
  _uid = _uid + 1
  return _uid
end

local managers = {}
local uniqueManagers = {}
local nodeLookup = nil
local nodePath = '/lua/ge/extensions/flowgraph/nodes/'
local simpleNodeConstructorPath = '/lua/ge/extensions/flowgraph/simpleNode/'

M.runningProxies = {}
M.refreshDependencies = function()
  local deps = tableKeys(M.runningProxies)
  M.dependencies = deps
end

M.enableUsageTracking = false

local function onExtensionLoaded()
  --extensions.load('ui_flowgraph_editor')
  -- node creation helper
  rawset(_G, '_flowgraph_createNode', function(C)
    return {
      node = C,
      create = function(mgr, graph, forceId) return require('/lua/ge/extensions/flowgraph/basenode').use(mgr, graph, forceId, C) end
    }
  end)
  rawset(_G, '_flowgraph_createStateNode', function(C)
    return {
      node = C,
      create = function(mgr, graph, forceId) return require('/lua/ge/extensions/flowgraph/baseStateNode').use(mgr, graph, forceId, C) end
    }
  end)
  rawset(_G, '_flowgraph_createModule', function(C)
    return {
      module = C,
      create = function(mgr) return require('/lua/ge/extensions/flowgraph/baseModule').use(mgr, C) end
    }
  end)
  --for _, simpleNodeConstructor in ipairs(FS:findFiles(simpleNodeConstructorPath,"*.json")) do
  --  require(simpleNodeConstructor)
  --end

  --M.addManager()
  --M.loadManager("flowEditor/demo/helloWorld.flow.json")
  --M.loadManager("flowEditor/demo/helloVariables.flow.json")
end

local function clearAllManagers()
  for _, mgr in ipairs(managers) do
    mgr:destroy()
  end
  table.clear(managers)
end

local function getAllManagers()
  return managers
end

local function getManagerByID(id)
  for _,mgr in ipairs(managers) do
    if mgr.id == id then
      return mgr
    end
  end
  return nil
end

local function loadManager(filepath, hidden, keepSavedDirs)
  local data = jsonReadFile(filepath)
  local mgr = require('/lua/ge/extensions/flowgraph/manager')(M)
  table.insert(managers, mgr)
  if data then
    local dir, filename, ext = path.split(filepath)
    data.savedDir = keepSavedDirs and data.savedDir or dir
    data.savedFilename = keepSavedDirs and data.savedFilename or filename
    mgr:_onDeserialized(data)
    mgr.hidden = hidden
    mgr:historySnapshot("Loaded File " .. filepath)
    return mgr, true
  else
    log("E", "Load Manager", "Could not find file " .. filepath)
    return mgr, false
  end
end

local function addManager(data)
  local mgr = require('/lua/ge/extensions/flowgraph/manager')(M)
  table.insert(managers, mgr)
  if data then
    mgr:_onDeserialized(data)
  end
  return mgr
end

local function removeManager(mgr)
  -- find index and uniqe name if available.
  local index = -1
  for i, m in ipairs(managers) do
    if mgr.id == m.id then index = i end
  end
  if index == -1 then return end
  local uniqueName = ""
  for nm, m in pairs(uniqueManagers) do
    if mgr.id == m.id then uniqueName = nm end
  end

  mgr:destroy()
  table.remove(managers, index)
  if uniqueName ~= "" then
    uniqueManagers[uniqueName] = nil
  end

end
local nextFrameRemove = {}
local nextFrameStart = {}
local function startNextFrame(mgr)
  table.insert(nextFrameStart, mgr)
end
local function removeNextFrame(mgr)
  table.insert(nextFrameRemove, mgr)
end

local startOnLoadingScreenFadeoutList = {}
local function onLoadingScreenFadeout()
  for _, fg in ipairs(startOnLoadingScreenFadeoutList) do
    fg:setRunning(true)
    fg.stopRunningOnClientEndMission = true -- used by auto-start for levels
  end
  table.clear(startOnLoadingScreenFadeoutList)
end

local function startOnLoadingScreenFadeout(fg)
  table.insert(startOnLoadingScreenFadeoutList, fg)
end

local function onUpdate()
  for _, mgr in ipairs(managers) do
    mgr:resolveHooksAndReset()
  end
  for _,mgr in ipairs(nextFrameStart) do
    mgr:setRunning(true)
  end
  for _,mgr in ipairs(nextFrameRemove) do
    M.removeManager(mgr)
  end
  table.clear(nextFrameRemove)
  table.clear(nextFrameStart)
  for _, mgr in ipairs(managers) do
    mgr:broadcastCall("onFlowgraphManagerPreUpdate")
  end
end

local function mgrRunningChanged()
end

local function reInitOnFileChange(filename)
  local requireFilename = string.sub(filename, 1, string.len(filename) - 4)
  log("I","flowgraphManager","Reloading Node: " .. tostring(requireFilename))
  nodeLookup = nil
  -- TODO: reinit everything
  local eSer, fgEditor
  if editor_flowgraphEditor then
    fgEditor = editor_flowgraphEditor
    eSer = fgEditor.onSerialize()
  end

  local ser = M.onSerialize()
  M.onDeserialized(ser)
  if fgEditor and eSer then
    fgEditor.onDeserialized(eSer)
  end
end

local function onFileChanged(filename, type)
  local dirname, fn, e = path.split(filename)

  -- check basic nodes
  if filename:sub(1, string.len(nodePath)) == nodePath then
    reInitOnFileChange(filename)
  end

  -- check custom nodes
  if filename:sub(string.len(filename)-7,string.len(filename)) == 'Node.lua' then
    for _,manager in ipairs(managers) do
      if manager.savedDir and (manager.savedDir.."customNodes/") == dirname then
        reInitOnFileChange(filename)
      end
    end
  end
end


local function onSerialize()
  local mgrs = {}
  local uniques = {}
  for i,mgr in ipairs(managers) do
    if not mgr.transient then
      local mS = mgr:_onSerialize()
      table.insert(mgrs,mS)
    end
  end
  for name,u in pairs(uniqueManagers) do
    local index = -1
    for j, mgr in ipairs(managers) do
      if mgr == u then index = j end
    end
    table.insert(uniques,{name = name, index = index})
  end

  return {mgrs = mgrs, uniques = uniques}
end

local function onDeserialized(data)
  M.clearAllManagers()
  --dumpz(data, 1)
  if next(data) then
    if data.mgrs then
      for i, mgr in ipairs(data.mgrs) do
        local m = M.addManager(mgr)
      end
    end
    if data.uniques then
      for _, un in ipairs(data.uniques) do
        uniqueManagers[un.name] = managers[un.index]
        uniqueManagers[un.name]:setRunning(true)
      end
    end
  end
end

local function getAvailableNodeTemplates()
  if not nodeLookup then
    local res = {}
    local lookup = {}
    for i, filename in ipairs(FS:findFiles(nodePath, '*.lua', -1, true, false)) do
      local dirname, fn, e = path.split(filename)
      local path = dirname:sub(string.len(nodePath) + 1)
      local pathArgs = split(path, '/')

      local treeNode = res
      for i = 1, #pathArgs do
        if pathArgs[i] ~= '' then
          if not treeNode[pathArgs[i]] then
            treeNode[pathArgs[i]] = { nodes = {} }
          end
          treeNode = treeNode[pathArgs[i]]
        end
      end
      local moduleName = string.sub(fn, 1, string.len(fn) - 4)
      local requireFilename = string.sub(filename, 1, string.len(filename) - 4)

      local status, node = pcall(rerequire, requireFilename)
      if not status then
        log('E', '', 'error while loading node ' .. tostring(requireFilename) .. ' : ' .. tostring(node) .. '. ' .. debug.tracesimple())
      else
        node.path = path .. moduleName
        node.sourcePath = nodePath .. path .. moduleName..'.lua'
        node.splitPath = pathArgs
        node.splitPath[#node.splitPath] = moduleName
        node.splitPath[#node.splitPath+1] = node.node.name
        node.availablePinTypes = M.getAvailablePinTypes(node.node)
        treeNode.nodes[moduleName] = node
        lookup[path .. moduleName] = node
      end
    end
    nodeLookup = {lookup = lookup, res = res}
  end
  return nodeLookup.res, nodeLookup.lookup
end

local function getAvailablePinTypes(node)
  local availablePinTypes = { _in = {}, _out = {}}
  if node.pinSchema then
    for _, pin in ipairs(node.pinSchema) do
      if type(pin.type) == 'table' then -- because multiple types per pin are possible
        for i = 1, #pin.type do
          availablePinTypes['_'..pin.dir][pin.type[i]] = true
        end
      else
        availablePinTypes['_'..pin.dir][pin.type] = true
      end
    end
  end

  -- add automatic pins from category system
  if node.category and ui_flowgraph_editor.isFunctionalNode(node.category) and not ui_flowgraph_editor.isSimpleNode(node.category) then
    availablePinTypes['_in']['flow'] = true
    availablePinTypes['_out']['flow'] = true
  end

  return availablePinTypes
end

local stateLookup = nil
local function getAvailableStateTemplates()
  local stateTemplatePath = '/flowEditor/states/'
  if not stateLookup then
    local res = {}
    local lookup = {}
    for i, filename in ipairs(FS:findFiles(stateTemplatePath, '*state.flow.json', -1, true, false)) do
      local dirname, fn, e = path.splitWithoutExt(filename, true)
      local path = dirname:sub(string.len(stateTemplatePath) + 1)
      if path ~= "" then
        local pathArgs = split(path, '/')

        local treeNode = res
        for i = 1, #pathArgs do
          if pathArgs[i] ~= '' then
            if not treeNode[pathArgs[i]] then
              treeNode[pathArgs[i]] = { states = {} }
            end
            treeNode = treeNode[pathArgs[i]]
          end
        end
        local moduleName = fn
        --local requireFilename = string.sub(filename, 1, string.len(filename) - 4)
        local stateData = {}

        stateData.data = readJsonFile(filename)
        stateData.path = path .. moduleName
        stateData.sourcePath = stateTemplatePath .. path .. moduleName..'.lua'
        stateData.splitPath = pathArgs
        stateData.splitPath[#stateData.splitPath] = moduleName
        stateData.splitPath[#stateData.splitPath+1] = stateData.name
        treeNode.states[moduleName] = stateData
        lookup[path .. moduleName] = stateData
      end
    end
    stateLookup = {lookup = lookup, res = res}
  end
  return stateLookup.res, stateLookup.lookup
end
M.getAvailableStateTemplates = getAvailableStateTemplates


local function getSingleton(name)
  if not uniqueManagers[name] then
    local json = jsonReadFile("flowEditor/"..name..".flow.json")
    if json then
      local mgr = M.addManager(json)
      mgr:historySnapshot("Loaded Singleton " .. name)
      mgr:setRunning(true)
      uniqueManagers[name] = mgr
      log('I', "flowgraphManager", "Successfully loaded Project file "..name.." and set it running.")
      return mgr
    else
      log('E', "flowgraphManager", "Could not find Project file " .. "flowEditor/"..name..".flow.json" .. "!")
      return nil
    end
  end
  return uniqueManagers[name]
end



M.controls = function(name)
  if name == 'reset' then
    for i, mgr in ipairs(managers) do
      mgr:broadcastCall('onControlsReset')
    end
  elseif name == 'action' then
    for i, mgr in ipairs(managers) do
      mgr:broadcastCall('onControlsAction')
    end
  end
end

M.onFlowgraphSceneObjectAdd = function(id, name, fgPath)
  dump(string.format("Added FGSO: %s, ID: %d, fgPath: %s ", name or '', id or 0, fgPath or ''))
end

M.onFlowgraphSceneObjectRemove = function(id, name, fgPath)
  dump(string.format("Removed FGSO: %s, ID: %d, fgPath: %s ", name or '', id or 0, fgPath or ''))
end

M.onFlowgraphSceneObjectChanged = function(id, name, fgPath)
  dump(string.format("Changed FGSO: %s, ID: %d, fgPath: %s ", name or '', id or 0, fgPath or ''))
end

M.nodePath = nodePath
M.startNextFrame = startNextFrame
M.removeNextFrame = removeNextFrame
M.lightExample = lightExample
M.getManagerByID = getManagerByID
M.onExtensionLoaded = onExtensionLoaded
M.getNextUniqueIdentifier = getNextUniqueIdentifier
M.updateHookLists = updateHookLists
M.removeManager = removeManager
M.loadManager = loadManager
M.addManager = addManager
M.getAllManagers = getAllManagers
M.clearAllManagers = clearAllManagers
M.onUpdate = onUpdate
M.onDeserialized = onDeserialized
M.onSerialize = onSerialize
M.getSingleton = getSingleton
M.getAvailableNodeTemplates = getAvailableNodeTemplates
M.getAvailablePinTypes = getAvailablePinTypes
M.onFileChanged = onFileChanged

M.onLoadingScreenFadeout = onLoadingScreenFadeout
M.startOnLoadingScreenFadeout = startOnLoadingScreenFadeout

return M
