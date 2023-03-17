-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--[[
    We will need to have logic files per instance i.e. 2 instances of the same prefabs will have seperate logic files

--]]
local logTag = 'prefabLogic'

local M = {}
M.state = {
  loadedModules = {},
  functionTable = {},
  functionTableSizes = {}
}

local levelFullyLoaded = false

local function nop()
end

local function execute(func, ...)
  local funcList = M.state.functionTable[func]
  for i = 1, (M.state.functionTableSizes[func] or 0) do
    funcList[i](...)
  end
end

local function updateFunctionTable()
  local functionTable = {}
  local functionTableSizes = {}
  local loadedModules = M.state.loadedModules
  for i = 1, (#loadedModules or 0) do
    local m = loadedModules[i]
    if type(m) == "table" then
      for functName,entry in pairs(m) do
        if type(entry) == 'function' then
          if functionTable[functName] == nil then functionTable[functName] = {} end
          table.insert(functionTable[functName], entry)
          functionTableSizes[functName] = #(functionTable[functName])
        end
      end
    end
  end
  M.state.functionTable = functionTable
  M.state.functionTableSizes = functionTableSizes
  --log('I', logTag, 'updateFunctionTable current state: ')
  --dump(M.state)
end

local function prefabLoaded(id, prefabName, prefabPath)
  log('I', logTag, 'Detected new prefab: ' .. dumps(id)..',' ..dumps(prefabName)..',' ..dumps(prefabPath))
  local logicPath = string.gsub(prefabPath, "%.", "_")
  if FS:fileExists("/"..logicPath..".lua") then
    log('I', logTag, 'Loading logic file: ' .. dumps(logicPath))
    -- local m = require(logicPath)
    local m = dofile(logicPath..".lua")
    if m then
      if type(m.onEventLoaded) == 'function' then
        m.onEventLoaded(id, prefabName, prefabPath)
      end
      -- dump(m)
      table.insert(M.state.loadedModules, m)
      if levelFullyLoaded then
        updateFunctionTable()
      end
    end
  end
end

local function prefabUnloaded(id, prefabName, prefabPath)
  log('I', logTag, 'Detected removal of prefab. Unloading logic file: ' .. dumps(id)..',' ..dumps(prefabName)..',' ..dumps(prefabPath))
    -- body
end

local paused = false
local function onPreRender(dt)
  -- log('I', logTag, 'onPreRender called....')
  if not paused then
    execute('onEventTick', dt)
  end
end

local function onPhysicsUnpaused()
  execute('onEventUnpaused')
  paused = false
end

local function onPhysicsPaused()
  execute('onEventPaused')
  paused = true
end

local function loadingCompleted()
  levelFullyLoaded = true
  updateFunctionTable()
end

local function onFreeroamLoaded(mission)
  --log('D', logTag, 'onFreeroamLoaded called....')
  loadingCompleted()
end

local function onScenarioLoaded(scenario)
  --log('D', logTag, 'onScenarioLoaded called....')
  loadingCompleted()
end

local function onInit()

end

M.prefabLoaded      = prefabLoaded
M.prefabUnloaded    = prefabUnloaded
M.onInit            = onInit
M.onPreRender       = onPreRender
M.onScenarioLoaded  = onScenarioLoaded
M.onFreeroamLoaded  = onFreeroamLoaded
M.onPhysicsPaused   = onPhysicsPaused
M.onPhysicsUnpaused = onPhysicsUnpaused

return M