-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- do not change the name of the functions as they are hardcoded in the c++ part
function __luaBindIndex(t, k)
  local mt = getmetatable(t)
  -- log('E', '', '  __index invoked on ' .. tostring(mt.___type))
  local res = rawget(mt, k)
  if res ~= nil then return res end

  local origgetters = rawget(mt, 1) -- 1 = getters
  local getFunc = rawget(origgetters, k)
  if getFunc ~= nil then
    -- log('E', '', '   getter hit: ' .. tostring(k) .. ' = ' .. tostring(res))
    return getFunc(t)
  end

  local origmt = mt
  while true do
    mt = rawget(mt, 3) -- 3 = super
    if not mt then
      --log('E', '', string.format("property '%s.%s' is not found", origmt.___type, k))
      return
    end
    res = rawget(mt, k)
    if res ~= nil then
      rawset(origmt, k, res)
      return res
    end
    local getters = rawget(mt, 1) -- 1 = getters
    if getters then
      local getFunc = rawget(getters, k)
      if type(getFunc) == 'function' then
        -- log('E', '', '   getter hit: ' .. tostring(k) .. ' = ' .. tostring(res))
        rawset(origgetters, k, getFunc)
        return getFunc(t)
      end
    end
  end
end

function __luaBindIndexStatic(t, k)
  local mt = getmetatable(t)
  -- log('E', '', '  __index invoked on ' .. tostring(mt.___type))
  local res = rawget(mt, k)
  if res ~= nil then return res end

  local origgetters = rawget(mt, 1) -- 1 = getters
  local getFunc = rawget(origgetters, k)
  if getFunc ~= nil then
    -- log('E', '', '   getter hit: ' .. tostring(k) .. ' = ' .. tostring(res))
    if type(getFunc) == 'function' then
      return getFunc()
    else
      return getFunc -- variables exposed through "addConstant()" return the value directly here (rather than a function)
    end
  end

  local origmt = mt
  while true do
    mt = rawget(mt, 3) -- 3 = super
    if not mt then
      --log('E', '', string.format("property '%s.%s' is not found", origmt.___type, k))
      return
    end
    res = rawget(mt, k)
    if res ~= nil then
      rawset(origmt, k, res)
      return res
    end
    local getters = rawget(mt, 1) -- 1 = getters
    if getters then
      local getFunc = rawget(getters, k)
      if type(getFunc) == 'function' then
        -- log('E', '', '   getter hit: ' .. tostring(k) .. ' = ' .. tostring(res))
        rawset(origgetters, k, getFunc)
        return getFunc()
      end
    end
  end
end

function __luaBindNewindex(t, k, v)
  local mt = getmetatable(t)
  --log('E', '', '__newindex invoked on ' .. tostring(mt.___type))
  local origsetters = rawget(mt, 2) -- 2 = setters
  local setFunc = rawget(origsetters, k)
  if setFunc ~= nil then
    setFunc(t, v)
    return
  end

  while true do
    mt = rawget(mt, 3) -- 3 = super
    if not mt then
      --log('E', '', string.format("property '%s.%s' is not found or not writable: %s", getmetatable(t).___type, k, debug.traceback()))
      return
    end
    local setters = rawget(mt, 2) -- 2 = setters
    if setters then
      local setFunc = rawget(setters, k)
      if type(setFunc) == 'function' then
        rawset(origsetters, k, setFunc)
        setFunc(t, v)
        return
      end
    end
  end
end

function __luaBindNewindexStatic(t, k, v)
  local mt = getmetatable(t)
  local origsetters = rawget(mt, 2) -- 2 = setters
  local setFunc = rawget(origsetters, k)
  if setFunc ~= nil then
    setFunc(v)
    return
  end

  while true do
    mt = rawget(mt, 3) -- 3 = super
    if not mt then
      --log('E', '', string.format("property '%s.%s' is not found or not writable: %s", getmetatable(t).___type, k, debug.traceback()))
      return
    end
    local setters = rawget(mt, 2) -- 2 = setters
    if setters then
      local setFunc = rawget(setters, k)
      if type(setFunc) == 'function' then
        rawset(origsetters, k, setFunc)
        setFunc(v)
        return
      end
    end
  end
end

local function __simObjectIndex(obj, k)
  local mt = getmetatable(obj)

  local res = rawget(mt, k)
  if res ~= nil then return res end

  local getFunc = rawget(rawget(mt, 1), k) -- 1 = getters
  if getFunc ~= nil then return getFunc(obj) end

  -- getStaticDataFieldbyName, getDynDataFieldbyName
  local dynField = rawget(mt, 4)(obj, k, 0) or rawget(mt, 5)(obj, k, 0)
  if dynField ~= nil then return dynField end

  if k == 'obj' then return obj end
end

local function __simObjectNewIndex(obj, k, v)
  local mt = getmetatable(obj)
  local setFunc = rawget(rawget(mt, 2), k) -- 2 = setters
  if setFunc ~= nil then
    setFunc(obj, v)
    return
  end

  if v == nil then return end

  if rawget(mt, 6)(obj, k, 0, v) then return end -- setStaticDataFieldbyName
  if rawget(mt, 7)(obj, k, 0, v) then return end -- setDynDataFieldbyName
end

local function flattenObjectMetatable(mt)
  local workmt = mt
  local workgetters = rawget(workmt, 1) or {}
  rawset(workmt, 1, workgetters)

  local worksetters = rawget(workmt, 2) or {}
  rawset(workmt, 2, worksetters)
  mt = rawget(mt, 3)
  while mt ~= nil do
    for k, v in pairs(rawget(mt, 1)) do
      workgetters[k] = workgetters[k] or v
    end

    for k, v in pairs(rawget(mt, 2)) do
      worksetters[k] = worksetters[k] or v
    end

    for k, v in pairs(mt) do
      if type(k) == "string" then
        rawset(workmt, k, rawget(workmt, k) or v)
      end
    end
    mt = rawget(mt, 3)
  end
end

function __finalizeLuaBindings(classes, luaVMname)
  if luaVMname ~= 'vlua' then
    for k, classtable in pairs(classes) do
      -- search for SimObject's metatables
      if k:byte(1) == 100 and classtable.isSubClassOf then -- d
        flattenObjectMetatable(classtable)
        -- create simobject metatable
        rawset(rawget(classtable, 1), "className", classtable.getClassName)
        if next(rawget(classtable, 2)) == nil and rawget(classtable, 3) == nil then
          rawset(rawget(classtable, 2), 1, 0)  -- disable newindex optimization when newindex table is empty
        end
        rawset(classtable, 4, classtable.getStaticDataFieldbyName)
        rawset(classtable, 5, classtable.getDynDataFieldbyName)
        rawset(classtable, 6, classtable.setStaticDataFieldbyName)
        rawset(classtable, 7, classtable.setDynDataFieldbyName)
        rawset(classtable, '__index', __simObjectIndex) -- new getter
        rawset(classtable, '__newindex', __simObjectNewIndex) -- new setter
      end
    end
  end

  for k, v in pairs(classes) do
    -- optimize metatables
    if rawget(v, 3) == nil then -- no super
      if next(rawget(v, 2)) == nil then -- no setters
        rawset(v, 2, nil)
        rawset(v, '__newindex', nil)
      end

      if next(rawget(v, 1)) == nil and rawget(v, '__index') ~= rawget(v, 1) then -- no getters
        local plainGetters = rawget(v, 1)
        if rawget(v, '__newindex') == nil then
          for f, getter in pairs(v) do
            if type(f) ~= 'number' then
              rawset(plainGetters, f, getter)
              if string.byte(f, 1) ~= 95 then
                rawset(v, f, nil)
              end
            end
          end
          plainGetters.__type = v.__type
        else
          for f, getter in pairs(v) do
            if type(f) ~= 'number' then
              rawset(plainGetters, f, getter)
            end
          end
        end
        rawset(v, '__index', plainGetters)
      end
    end
  end
end

function testBindings()
  print(' *** Unittest start ***')
  local a = TestNamespace.TestClassA()
  a.strC = 'this is C'
  a:callC()
  a.strB = 'abc'
  assert(a.strB == 'abc')
  assert(pcall(function() a:callC() end) == true)

  --assert(pcall(function() tc.strC = 'test' end) == false) -- this will fail as tc is declared as const
  --assert(pcall(function() tc:callA() end) == false) -- will not work as the function is not const
  --assert(pcall(function() tc:callC() end) == true) -- will work as the fucntion is declared as const: void callC() const;

  -- destruction tests
  local tmp = {}
  for i = 0, 5 do
    table.insert(tmp, TestNamespace.TestClassB())
  end
  tmp = nil -- free everything
  collectgarbage("collect")
  collectgarbage("collect")
  collectgarbage("collect")

  print(' *** DONE ***')
end


