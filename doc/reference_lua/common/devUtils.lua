-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- development utility things
-- generally things that are not used so commonly to justify them being in util

-- safe lua function execution with IO overrides
-- NOTE: this cannot be conceptually safe as you can always get hidden objects
function executeLuaSandboxed(cmd, source)
  source = source or 'executeLuaSandboxed'
  local stdOutCache = {}

  -- sandbox creation
  local fEnv = getfenv(1) -- we reuse the environment and override only some things ...
  -- sandboxed functions
  local print_saved = fEnv.print
  fEnv.print = function(msg)
    --io.write("sandboxed print: " .. tostring(msg) .. "\n")
    table.insert(stdOutCache, tostring(msg))
  end

  -- parse the lua, fEnd is the tiny sandbox that we have to redirect stdout
  local func, err = load(cmd, source, 't', fEnv)

  -- execute the lua
  if func then
    if type(debug.traceback) ~= "function" then
      fEnv.print = print_saved
      return "Error: Lua debug traceback broken"
    end

    local ok, result = xpcall(func, debug.traceback)
    if ok then
      fEnv.print = print_saved
      return result, stdOutCache
    end

    fEnv.print = print_saved
    return "Error: " .. tostring(result)
  end
  fEnv.print = print_saved
  return "Error: " .. tostring(err)
end


-- finds all upvalues for a given function and returns a table of them
-- ignores: global variables, module scope, module table, ___locals
local function _findUpValuesFromFunction(moduleTbl, func)
  local i = 1
  local res = {}
  while true do
    local name, upv = debug.getupvalue(func, i)
    if not name then break end
    if not _G[name] and not moduleTbl[name] and upv ~= moduleTbl and name ~= '___locals' then
      res[name] = upv
    end
    i = i + 1
  end
  return res
end

-- finds all upvalues recursively throughout a table
local function _recFindUpvalues(moduleTbl, tbl, visitedEntries)
  if type(tbl) ~= 'table' then return end
  if visitedEntries[tostring(tbl)] then return {} end
  visitedEntries[tostring(tbl)] = true -- prevent infinite recursion

  local res = {}
  for _, entry in pairs(tbl) do
    if type(entry) == 'function' and not visitedEntries[tostring(entry)]  then
      visitedEntries[tostring(entry)] = true -- prevent infinite recursion
      local upvalues = _findUpValuesFromFunction(moduleTbl, entry)
      tableMerge(res, upvalues)
      local resSub = _recFindUpvalues(moduleTbl, upvalues, visitedEntries)
      tableMerge(res, resSub)
    --elseif type(entry) == 'table' then
    --  tableMerge(res, _recFindUpvalues(moduleTbl, entry))
    end
  end
  local mt = getmetatable(tbl)
  if mt then
    tableMerge(res, _recFindUpvalues(moduleTbl, mt, visitedEntries))
  end
  return res
end

-- returns all known locals that are used by functions in that module
function getModuleLocals(moduleTbl)
  return _recFindUpvalues(moduleTbl, moduleTbl, {})
end

local function _cleanupCloneTbl(t, tablesVisited, path)
  if tablesVisited[tostring(t)] then return tablesVisited[tostring(t)] end
  local res = {}
  tablesVisited[tostring(t)] = res
  tablesVisited[tostring(res)] = res

  local keys = tableKeysSorted(t)

  for _, k in ipairs(keys) do
    local v = rawget(t, k)
    if type(v) == 'table' then
      local newPath = path .. '/' .. tostring(k)
      local r = _cleanupCloneTbl(v, tablesVisited, newPath)
      if r then
        res[k] = r
      end
    elseif type(v) ~= 'function' and type(v) ~= 'userdata' then
      res[k] = v
    end
  end
  return res
end

local function _createGraphviz(t, tablesVisited, path)
  if tablesVisited[tostring(t)] then return '' end
  tablesVisited[tostring(t)] = true

  local parent = tostring(t):gsub('[^a-zA-Z0-9]', '')
  local res = ''
  res = res .. parent .. ' [ label = "' .. tostring(k) .. '" ];\n'

  local keys = tableKeysSorted(t)
  for _, k in ipairs(keys) do
    local v = rawget(t, k)
    local newPath = path .. '_' .. tostring(v)
    newPath = newPath:gsub('[^a-zA-Z0-9]', '_')
    res = res .. path .. ' -> ' .. newPath .. ';\n'
    if type(v) == 'table' then
      res = res .. _createGraphviz(v, tablesVisited, newPath)
    end
  end
  return res
end

local function _createGraphvizFile(filename, t)
  local s = 'digraph {\n'
  s = s .. 'graph [splines=true overlap=false];\n'
  s = s .. _createGraphviz(t, {}, '_')
  s = s .. '}\n'
  writeFile(filename, s)
end

function createGlobalSnapshot(filename)
  -- general fixes
  if type(gui) == 'table' and type(gui.reset) == 'function' then gui.reset() end -- removes any temporary gui caches

  -- do the snapshot
  local snapshot = { tables = {}, tablesTmp = {}, vars = {}, extensions = {} }
  for k, v in pairs(_G) do
    if (type(v) == 'table' and (rawget(v, '___type') or rawget(v, '___getters'))) or type(v) == 'function' or k == '_G' or k == 'extensions' or k == 'package' then goto continue end
    if type(v) == 'table' and k ~= 'math' and k ~= 'ffi' and k ~= 'jit' and k ~= 'mime' and k ~= 'socket' then
      if rawget(v, '__extensionName__') and v.__extensionName__ == 'core_performance' then goto continue end
      local locals = getModuleLocals(v)
      local used = false
      local t = {}
      if not tableIsEmpty(locals) then t.locals = locals ; used = true end
      if not tableIsEmpty(v) then t.module = v ; used = true end
      if used then
        t.key = k
        snapshot.tablesTmp[tostring(v)] = t
      end
    else
      snapshot.vars[k] = deepcopy(v)
    end
    ::continue::
  end
  snapshot = _cleanupCloneTbl(snapshot, {}, '/')
  -- now cleanup the tables
  for k, v in pairs(snapshot.tablesTmp) do
    if v.module and v.module.__extensionName__ then
      v.key = nil
      snapshot.extensions[v.module.__extensionName__] = v
    else
      if v.module and not tableIsEmpty(v.module) then
        snapshot.tables[v.key] = v
        v.key = nil
      end
    end
  end
  snapshot.tablesTmp = nil
  --_createGraphvizFile(filename..'.dot', snapshot)
  flattenTable(snapshot)
  jsonWriteFile(filename, snapshot, true)
end

local function _tableFindRecursion(tbl, res, path)
  for k, v in pairs(tbl) do
    if type(v) == 'table' then
      local newPath = path .. '/' .. tostring(k)
      local tblPtr = tostring(v)
      if not res[tblPtr] then res[tblPtr] = {} end
      table.insert(res[tblPtr], newPath)
      _tableFindRecursion(v, res, newPath)
    end
  end
end

function tableFindRecursion(tbl)
  if type(tbl) ~= 'table' then return nil end
  local res = {}
  _tableFindRecursion(tbl, res, '')
  local duplicateTables = {}
  local dupeCount = 0
  for k, v in pairs(res) do
    if #v > 1 then
      duplicateTables[k] = v
      dupeCount = dupeCount + 1
    end
  end
  return dupeCount, duplicateTables
end