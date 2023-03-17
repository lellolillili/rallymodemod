-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- utility things, see documentation

require('filters')
require('inputFilters')
lpack = require('lpack')
local buffer = require('string.buffer')

local ffifound, ffi = pcall(require, 'ffi')
if not ffifound then
  ffi = {offsetof = function(v, atr) return v[atr] end}
end

--== type definitions ==--
-- used in conversions and serializations
local __typeQuatF = (QuatF ~= nil) and QuatF(0,0,0,1).___type or nil
local __typeColor = (color ~= nil) and color(0,0,0,0).___type or nil

-- useful local shortcuts
local min = math.min
local max = math.max
local abs = math.abs
local fmod = math.fmod
local floor = math.floor
local random = math.random
local huge = math.huge
local stringformat, tableconcat = string.format, table.concat
local str_find, str_len, str_sub, byte = string.find, string.len, string.sub, string.byte

local bufTmp = buffer.new()

--== color things ==--

function RGBtoHSV(rgb)
  local r, g, b = rgb.x, rgb.y, rgb.z
  local cMax, cMin = max(r,g,b), min(r,g,b)
  local cDelta = cMax - cMin

  local h = 0
  if cDelta == 0 then
    h = 0
  elseif r == cMax then
    h = (((g-b)/cDelta) % 6) / 6
  elseif g == cMax then
    h = (((b-r)/cDelta) + 2) / 6
  elseif b == cMax then
    h = (((r-g)/cDelta) + 4) / 6
  end

  return vec3(h, cMax == 0 and 0 or cDelta/cMax, cMax)
end

function HSVtoRGB(hsv)
  local h, s, v = hsv.x, hsv.y, hsv.z
  h = h - floor(h)

  h = max(0, min(1, h))
  s = max(0, min(1, s))
  v = max(0, min(1, v))

  local hi = floor(h * 6.0)
  local f = (h * 6.0) - hi

  local p, q, t = v * (1.0 - s), v * (1.0 - s * f), v * (1.0 - s * (1.0 - f))
  local rgb = vec3(v, t, p)

  if hi == 1 then
    rgb.x = q; rgb.y = v; rgb.z = p
  elseif hi == 2 then
    rgb.x = p; rgb.y = v; rgb.z = t
  elseif hi == 3 then
    rgb.x = p; rgb.y = q; rgb.z = v
  elseif hi == 4 then
    rgb.x = t; rgb.y = p; rgb.z = v
  elseif hi == 5 then
    rgb.x = v; rgb.y = p; rgb.z = q
  end

  return rgb
end

-- splits the RGB color range into numOfSteps slices equally. Creates good contrast colors
function rainbowColor(numOfSteps, step, format)
  -- Adam Cole, 2011-Sept-14
  -- HSV to RBG adapted from: http://mjijackson.com/2008/02/rgb-to-hsl-and-rgb-to-hsv-color-model-conversion-algorithms-in-javascript
  local r,g,b
  local h = step / numOfSteps
  local i = floor(h * 6)
  local f = h * 6 - i
  local q = 1 - f
  local iMod = i % 6
  if     iMod == 0 then r = 1; g = f; b = 0
  elseif iMod == 1 then r = q; g = 1; b = 0
  elseif iMod == 2 then r = 0; g = 1; b = f
  elseif iMod == 3 then r = 0; g = q; b = 1
  elseif iMod == 4 then r = f; g = 0; b = 1
  elseif iMod == 5 then r = 1; g = 0; b = q
  end
  if (format or 255) == 255 then
    return {floor(r*255), floor(g*255), floor(b*255), 255}
  else
    return {r, g, b, 1}
  end
end

function getContrastColorF(i)
  local c = rainbowColor(16, i % 17, 1)
  return ColorF(c[1], c[2], c[3], 1)
end

function getContrastColorStringRGB(i)
  local c = rainbowColor(16, i % 17, 255)
  return stringformat("#%02x%02x%02x", c[1], c[2], c[3])
end

function getContrastColorStringRGBA(i)
  local c = rainbowColor(16, i % 17, 255)
  return stringformat("#%02x%02x%02x%02x", c[1], c[2], c[3], 255)
end

--== String utilities ==--

local inspect = require("libs/inspect/inspect")

function dumps(...)
  local arg = {...}
  local narg = table.maxn(arg)
  if narg > 1 then
    local res = {}
    for k=1, narg do
      table.insert(res, inspect(arg[k]))
    end
    return table.concat(res, ', ')
  else
    if narg == 0 then return '' end
    if type(...) == "userdata" then
      local metatable = getmetatable(...)
      if metatable then
        return inspect(metatable)
      end
    end
    return inspect(...)
  end
end

function dump(...)
  -- to find out who is calling this, you can use this snippet:
  --log('A', "lua.utils.dump-calledby", debug.traceback())

  log('A', "lua.utils", dumps(...))
end

function dumpsz(o, depth)
  return inspect(o, {depth = depth or huge})
end

function dumpz(o, depth)
  log('A', "lua.utils", dumpsz(o, depth))
end

function addLevelLog(object, logLevel, origin, uniqueErrorCode, message)
  local debugInfo = debug.getinfo(2)
  if not object then
    Engine.Debug.addLevelLogLuaNoObject(logLevel, origin, uniqueErrorCode, debugInfo.source, debugInfo.currentline, message)
  else
    Engine.Debug.addLevelLogLua(object, logLevel, origin, uniqueErrorCode, debugInfo.source, debugInfo.currentline, message)
  end
end

function getLevelLogs()
  return Engine.Debug.getLevelLogsLua()
end

function clearLevelLogs()
  Engine.Debug.clearLevelLogs()
end

function lpad(s, l, c)
  s = tostring(s)
  return string.rep(c, l - #s)..s
end

function rpad(s, l, c)
  s = tostring(s)
  return s .. string.rep(c, l - #s)
end

function trim(s)
  return s:match("^%s*(.-)%s*$")
end

function join(list, delimiter)
  return table.concat(list, delimiter)
end

-- Compatibility: Lua-5.0
function split(str, delim, nMax)
  local aRecord = {}

  if str_len(str) > 0 then
     nMax = nMax or -1
     local nField, nStart = 1, 1
     local nFirst,nLast = str_find(str, delim, nStart, true)
     while nFirst and nMax ~= 0 do
        aRecord[nField] = str_sub(str, nStart, nFirst-1)
        nField = nField+1
        nStart = nLast+1
        nFirst,nLast = str_find(str, delim, nStart, true)
        nMax = nMax-1
     end
     aRecord[nField] = str_sub(str, nStart)
  end

  return aRecord
end

function string.startswith(String,Start)
  return string.sub(String,1,string.len(Start))==Start
end

function string.endswith(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

function string.rstripchars(String, chrs)
  return String:gsub("["..chrs.."]$", '')
end

function string.stripchars(String, chrs)
  return String:gsub("["..chrs.."]", '')
end

function string.stripcharsFrontBack(str, chrs)
  str = str:match( "^["..chrs.."]*(.+)" )
  str = str:match( "(.-)["..chrs.."]*$" )
  return str
end

function string.split(str, delimregex)
  delimregex = delimregex or "%S+"
  local i, t = 1, {}
  for v in string.gmatch(str, delimregex) do
    t[i] = v
    i = i + 1
  end
  return t
end

function string.sentenceCase(str)
  local result = str:gsub("([A-Z])", " %1")
  return string.upper(result:sub(1, 1)) .. result:sub(2)
end

function stringHash(text)
  -- From: http://wowwiki.wikia.com/wiki/StringHash/Analysis
  -- available under CC-BY-SA
  local counter = 1
  local len = string.len(text)
  for i = 1, len, 3 do
    counter = fmod(counter * 8161, 4294967279) +
    (string.byte(text, i) * 16776193) +
    ((string.byte(text, i + 1) or (len - i + 256)) * 8372226) +
    ((string.byte(text, i + 2) or (len - i + 256)) * 3932164)
  end
  return fmod(counter, 4294967291)
end

-- converts a byte count to a human readable string
function bytes_to_string(bytes)
    if bytes >= 1000 * 1000 * 1000 then
      return ("%.2f GB"):format(bytes / (1000 * 1000 * 1000))
    elseif bytes >= 1000 * 1000 then
      return ("%.2f MB"):format(bytes / (1000 * 1000))
    elseif bytes >= 1000 then
      return ("%.2f KB"):format(bytes / 1000)
    end
    return ("%.2f B"):format(bytes)
  end

-- time string format
function formatTimeStringNow(res)
  local d = os.date('*t')
  res = res:gsub("{YYYY}", string.format('%04d', d.year))
  res = res:gsub("{YY}", string.format('%02d', d.year - 2000))
  res = res:gsub("{Y}", d.year)
  res = res:gsub("{MM}", string.format('%02d', d.month))
  res = res:gsub("{M}", d.month)
  res = res:gsub("{DD}", string.format('%02d', d.day))
  res = res:gsub("{D}", d.day)
  res = res:gsub("{HH}", string.format('%02d', d.hour))
  res = res:gsub("{H}", d.hour)
  res = res:gsub("{mm}", string.format('%02d', d.min))
  res = res:gsub("{m}", d.min)
  res = res:gsub("{ss}", string.format('%02d', d.sec))
  res = res:gsub("{s}", d.sec)
  return res
end

-- ASCII graph
function graphs(v, len)
  local size = min(len, floor(abs(v)))
  return '['..string.rep(v>0 and "+" or "-", size) .. string.rep(' ', len - size)..']'
end

--== Json ==--
local function escapeString(s)
  for i = 1, #s do
    local c = byte(s, i)
    if c < 32 or c == 34 or c == 92 then
      return ( s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\t", "\\t"):gsub('"','\\"'):gsub("\r", "\\r") ) -- gsub returns 2 values, parens are needed
    end
  end
  return s
end

local function jsonEncode_rec(v)
  local vtype = type(v)
  if vtype == 'string' then
    bufTmp:put('"', escapeString(v), '"')
  elseif vtype == 'number' then
    if v * 0 ~= 0 then -- inf,nan
      bufTmp:put(v > 0 and '-9e999' or '-9e999')
    else
      bufTmp:put(v)
    end
  elseif vtype == 'table' then  --tables
    local kk1, vv1 = next(v)
    if kk1 == 1 and next(v, #v) == nil then
      local vcount = #v
      bufTmp:put('[')
      if vcount >= 1 then
        jsonEncode_rec(vv1)
        for i = 2, vcount do
          bufTmp:put(',')
          jsonEncode_rec(v[i])
        end
      end
      bufTmp:put(']')
    else
      if kk1 ~= nil then
        local prefix = '{"'
        for kk, vv in pairs(v) do
          bufTmp:put(prefix, type(kk) == 'string' and (kk) or kk, '":')
          jsonEncode_rec(vv)
          prefix = ',"'
        end
        bufTmp:put('}')
      else
        bufTmp:put('{}')
      end
    end
  elseif vtype == 'boolean' then
    bufTmp:put(tostring(v))
  elseif vtype == 'cdata' and ffi.offsetof(v, 'z') ~= nil then  -- vec3
    if ffi.offsetof(v, 'w') ~= nil then
      bufTmp:putf('{"x":%.9g,"y":%.9g,"z":%.9g,"w":%.9g}', v.x, v.y, v.z, v.w)
    else
      bufTmp:putf('{"x":%.9g,"y":%.9g,"z":%.9g}', v.x, v.y, v.z)
    end
  else
    bufTmp:put("null")
  end
end

function jsonEncode(v)
  bufTmp:reset()
  jsonEncode_rec(v)
  return tostring(bufTmp)
end

function jsonEncodePrefix(prefix, v, postfix)
  bufTmp:reset()
  bufTmp:put(prefix)
  jsonEncode_rec(v)
  if postfix then
    bufTmp:put(postfix)
  end
  return tostring(bufTmp)
end

function jsonEncodePretty(v, lvl, numberPrecision)
  if v == nil then return "null" end
  local vtype = type(v)
  if vtype == 'string' then return stringformat('"%s"', escapeString(v)) end
  if vtype == 'number' then
    if v * 0 ~= 0 then -- inf,nan
      return v > 0 and '9e999' or '-9e999'
    else
      if numberPrecision == nil then
        return stringformat('%.10g', v)  -- .10g is needed for time
      else
        if v ~= floor(v) then
          return stringformat('%' .. numberPrecision .. '.' .. numberPrecision .. 'f', v)
        else
          return stringformat('%d', v)
        end
      end
    end
  end
  if vtype == 'boolean' then return tostring(v) end

  -- Handle tables
  if vtype == 'table' then
    lvl = lvl or 1
    local indent = string.rep('  ', lvl)
    local indentPrev = string.rep('  ', max(0, lvl - 1))
    local tmp = {}
    if next(v) == 1 and next(v, #v) == nil then
      for i = 1, #v do
        table.insert(tmp, jsonEncodePretty(v[i], lvl + 1, numberPrecision))
      end
      return stringformat('[\n' .. indent .. '%s\n' .. indentPrev .. ']', table.concat(tmp, ',\n' .. indent))
    else
      if next(v) == nil then
        return '{}'
      else
        -- sort keys first
        local tableKeys = tableKeysSorted(v)
        for _, kk in pairs(tableKeys) do
          local vv = v[kk]
          local cv = jsonEncodePretty(vv, lvl + 1, numberPrecision)
          if cv ~= nil then table.insert(tmp, stringformat('"%s":%s', escapeString(tostring(kk)), cv)) end
        end
        return stringformat('{\n'..indent .. '%s\n'.. indentPrev ..'}', table.concat(tmp, ',\n' .. indent))
      end
    end
  end

  if vtype == 'cdata' and ffi.offsetof(v, 'z') ~= nil then  -- vec3
    if ffi.offsetof(v, 'w') ~= nil then
      return stringformat('{"x":%.9g,"y":%.9g,"z":%.9g,"w":%.9g}', v.x, v.y, v.z, v.w)
    else
      return stringformat('{"x":%.9g,"y":%.9g,"z":%.9g}', v.x, v.y, v.z)
    end
  end

  return "null"
end

function jsonDecode(content, context)
  if not json then json = require("json") end
  local state, data = xpcall(function() return json.decode(content) end, debug.traceback)
  if state == false then
    log('E', "jsonDecode", "unable to decode JSON: "..tostring(context))
    log('E', "jsonDecode", "JSON decoding error: "..tostring(data))
    return nil
  end
  return data
end

function jsonWriteFile(filename, obj, pretty, numberPrecision)
  local objType = type(obj)
  if objType ~= "table" then
    log("E", "jsonWriteFile", "Provided objType is not a table but "..dumps(objType)..", unable to write to: "..dumps(filename))
    print(debug.tracesimple())
    return false
  end
  local f = io.open(filename, "w")
  if f then
    local content
    if pretty then
      content = jsonEncodePretty(obj, 1, numberPrecision)
    else
      content = jsonEncode(obj)
    end
    f:write(content)
    f:close()
    return true
  else
    log("E", "jsonWriteFile", "Unable to open file for writing: "..dumps(filename))
    print(debug.tracesimple())
  end
  return false
end

function jsonReadFile(filename)
  local content = readFile(filename)
  if content == nil then
    -- parent needs to deal with error reporting
    return nil
  end
  return jsonDecode(content, filename)
end

function readDictJSONTable(filename)
  local data = jsonReadFile(filename)
  if not data then return nil end
  for k,v in pairs(data) do
    for k2,v2 in pairs(v) do
      if k2 > 1 then
        -- re-add headers
        for i=1,#v[1],1 do

          v[k2][v[1][i]] = v[k2][i]
          v[k2][i] = nil
        end
      end
    end
    v[1] = nil
  end
  --dump(data)
  return data
end

--== Table utilities ==--

-- checks if the table is a dictionary by checking if key 1 exists
function tableIsDict(tbl)
  if type(tbl) ~= "table" then
    return false
  end
  return next(tbl) ~= 1
end

function tableIsArraySlow(tbl)
  local tblSize = #tbl
  for k, _ in pairs(tbl) do
    if type(k) ~= 'number' or k < 1 or k > tblSize then return false end
  end
  return true
end

function tableIsEmpty(tbl)
  return type(tbl) ~= 'table' or next(tbl) == nil
end

-- returns a new array containing all table keys
function tableKeys(tbl, target)
  local keys = target or table.new(#tbl, 4)
  local keysidx = 1
  for k, _ in pairs(tbl) do
    keys[keysidx] = k
    keysidx = keysidx + 1
  end
  return keys
end

local function tableSortCompareMultiType(a, b)
  local typeA, typeB = type(a), type(b)
  if typeA ~= typeB then
    return typeA < typeB
  elseif typeA == "string" or typeA == "number" then
    return a < b
  elseif typeA == "boolean" then
    return a == true
  else
    return tostring(a) < tostring(b)
  end
end

function tableKeysSorted(tbl, target)
  local res = tableKeys(tbl, target)
  table.sort(res, tableSortCompareMultiType)
  return res
end

-- returns the values of a table for key lookup
function tableValuesAsLookupDict(tbl, target)
  local res = target or table.new(#tbl, 4)
  for _, tb in pairs(tbl) do
    res[tb] = 1
  end
  return res
end

-- appends src array to dst array
function arrayConcat(dst, src)
  local dstidx = #dst
  for i = src[0] == nil and 1 or 0, #src do
    dstidx = dstidx + 1
    dst[dstidx] = src[i]
  end
  return dst
end

function tableMerge(dst, src)
  for k, v in pairs(src) do
    if type(v) ~= "function" then
      dst[k] = v
    end
  end
  return dst
end

function setEqual(set1, set2)
  if #set1 ~= #set2 then return false end
  local lut = tableValuesAsLookupDict(set1)
  for _, val in ipairs(set2) do
    if not lut[val] then return false end
  end
  return true
end

-- appends to dst array, all the values from src array that didn't exist in dst array
function setUnion(dst, src)
  local lut = tableValuesAsLookupDict(dst)
  for _,v in ipairs(src) do
    if not lut[v] then
      table.insert(dst, v)
      lut[v] = 1
    end
  end
  return dst
end

-- removes from dst array, all values in src array. It changes the order of dst
function setDifference(dst, src)
  local srcByValue = table.new(0, #src)
  for _,v in ipairs(src) do
    srcByValue[v] = true
  end
  local dstBack = #dst
  for i = dstBack, 1, -1 do
    if srcByValue[dst[i]] then
      dst[i] = dst[dstBack]
      dst[dstBack] = nil
      dstBack = dstBack - 1
    end
  end
  return dst
end

-- http://stackoverflow.com/questions/1283388/lua-merge-tables
function tableMergeRecursive(t1, t2)
  for k, v in pairs(t2) do
    if type(v) == "table" and type(t1[k]) == "table" then
      tableMergeRecursive(t1[k], t2[k])
    else
      t1[k] = v
    end
  end
  return t1
end

-- returns the size of the table. Works with arrays and dictionaries. SLOW, as it iterates all ekements
function tableSize(tbl)
  if type(tbl) ~= "table" then
    return 0
  end
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

local function readOnlyCatcher(table, key, value)
  error(stringformat("Attempt to modify read-only table entry: %s = %s", key, value))
end

-- returns a readonly table (only primary level unless all sub-tables are also created as readonly)
function tableReadOnly(table)
  return setmetatable({}, {
      __index = table,
      __newindex = readOnlyCatcher,
      __metatable = false
    })
end

-- counts the 0 elemnet as well if existing (Lua tables start with 1)
function tableSizeC(tbl)
  return #tbl + (tbl[0] == nil and 0 or 1)
end

-- finds the key of a certain value. Non-recursive
function tableFindKey(t, element)
  for k, v in pairs(t) do
    if v == element then
      return k
    end
  end
end

-- checks if the table contains a certain value. Non-recursive
function tableContains(t, element)
  return tableFindKey(t, element) ~= nil
end

-- checks if the table contains a certain value, compared lower-case. Non-recursive
function tableContainsCaseInsensitive(table, element)
  element = string.lower(element)
  for _, value in pairs(table) do
    if string.lower(value) == element then
      return true
    end
  end
  return false
end

function arrayFindValueIndex(t, val)
  for i = 1, #t do
    if t[i] == val then
        return i
    end
  end
  return false
end

--Fisher-Yates shuffle for pure arrays
function arrayShuffle(array)
  for i = #array, 2, -1 do
    local j = random(i)
    array[i], array[j] = array[j], array[i]
  end
  return array
end

-- reverses a pure array
function arrayReverse(array)
  local n = #array
  for i = 1, n * 0.5 do
    array[i], array[n] = array[n], array[i]
    n = n - 1
  end
  return array
end

-- counts the depth of a table. Recursive, super slow
function tableDepth(tbl, lookup)
  if type(tbl) ~= 'table' then return 0 end
  lookup = lookup or {}
  local depth = 1
  for k, v in pairs(tbl) do
    if type(k) == "table" then
      lookup[k] = lookup[k] or tableDepth(k, lookup)
      depth = max(depth, lookup[k] + 1)
    end
    if type(v) == "table" then
      lookup[v] = lookup[v] or tableDepth(v, lookup)
      depth = max(depth, lookup[v] + 1)
    end
  end
  return depth
end

function tableRoundRobinKey(tbl, lastKey)
  local rr = next(tbl, (lastKey ~= nil and tbl[lastKey]) and lastKey or nil)
  return rr ~= nil and rr or (next(tbl, rr))
end

-- creates a copy of the value or table. Non-recursive
function shallowcopy(orig)
  if type(orig) == 'table' then
    local copy = table.new(#orig, 0)
    for k, v in pairs(orig) do
      copy[k] = v
    end
    return copy
  else -- number, string, boolean, etc
    return orig
  end
end

-- local, used in deepcopy()
local function _deepcopyTable(lookup_table, object)
  local new_table = table.new(#object, 0)
  lookup_table[object] = new_table
  for index, value in pairs(object) do
    if type(index) == 'table' then
      index = lookup_table[index] or _deepcopyTable(lookup_table, index)
    end
    if type(value) == 'table' then
      value = lookup_table[value] or _deepcopyTable(lookup_table, value)
    end
    new_table[index] = value
  end
  return setmetatable(new_table, getmetatable(object))
end

-- copies the object, recreates an exact  copy. Recursive. Slow
function deepcopy(object)
  if type(object) == 'table' then
    local lookup_table = {}
    return _deepcopyTable(lookup_table, object)
  else
    return object
  end
end

--usage: checkTableDataTypes(myTable, {"string", "number"}), returns true/false as first return and a text in case of failure as second
--only usable for array-typed tables
function checkTableDataTypes(data, expectedTypes)
  --check for number mismatch
  if #data ~= #expectedTypes then
    return false, string.format("Actual and expected parameter counts are mismatched, actual: %d, expected: %q", #data, #expectedTypes)
  end
  --check actual datatypes for expected types and report potential issues
  for k, v in ipairs(expectedTypes) do
    if type(data[k]) ~= v then
      return false, string.format("Wrong data type on param %d, expected: %q, actual: %q", k, v, type(data[k]))
    end
  end
  return true
end

--== Time ==--

-- ToDo: add proper getTime function to the lua api, use hacky solution for the time being so there's at least an implementation for a global getTime function
--returns the time that has passed since game start
function getTime()
  return ui_imgui.GetTime()
end

--== Input/Output helpers ==--

-- inspects the arguments and writes the output to the file
function dumpToFile(filename, ...)
  local f = io.open(filename, "w")
  if f then
    f:write(inspect(...))
    f:close()
    return true
  end
  return false
end

-- reads the content of a file
function readFile(filename)
  local f = io.open(filename, "r")
  if f == nil then
    return nil
  end
  local content = f:read("*all")
  f:close()
  return content
end

-- writes text to a file
function writeFile(filename, data)
  local file, err = io.open(filename, 'w')
  if file == nil then
    log('W', "writeFile", "Error opening file for writing: "..filename..": "..err)
    return nil
  end
  file:write(data)
  file:close()
  return true
end

--== User interface ==--

function ui_message(msg, ttl, category, icon)
  guihooks.message(msg, (ttl or 5), (category or ''), icon)
end

--== Extension/Packages ==--

local function isPackage(name, entry)
  if name == 'extensions' then
    return false
  end

  if type(entry) == 'function' then
    return false
  elseif type(entry) == 'table' and entry.__extensionName__ then
    return false
  end

  return true
end

function serializePackages(reason)
  --log("I", 'lua.extensions', "serializePackages called.....")
  if reason == nil then reason = 'reload' end
  local tmp = {}
  for k,v in pairs(package.loaded) do
    if isPackage(k, v) and type(v) == 'table' and (v['onDeserialized'] ~= nil or v['onSerialize'] ~= nil) then
      -- log("I", "serialize", "Package: "..k)
      if type(v['onSerialize']) == 'function' then
        tmp[k] = v['onSerialize'](reason)
      elseif v['state']  then
        tmp[k] = v.state
      else
        tmp[k] = v
      end
    end
  end

  tableMerge(tmp, extensions.getSerializationData(reason))
  return tmp
end

function deserializePackages(data, filter)
  if data == nil then return end
  -- log("I", 'lua.extensions', "deserializePackages called.....")
  -- Process extensions first so that calls to extensions.belongsToExtensions work with newly loaded modules
  extensions.deserialize(data)

  for k,v in pairs(package.loaded) do
    --print("k="..tostring(k) .. " = " .. tostring(v))
    if isPackage(k, v) and (filter == nil or k == filter) and type(v) == 'table' and (v['onDeserialized'] ~= nil or v['onDeserialize'] ~= nil) and data[k] ~= nil then
      --log("I", "deserialize", "Package: "..k)
      if type(v['onDeserialize']) == 'function' then
        v['onDeserialize'](data[k])
      elseif type(v['state']) == 'table' then
        tableMerge(v['state'], data[k])
      else
        tableMerge(v, data[k])
      end
      if type(v['onDeserialized']) == 'function' then
        v['onDeserialized'](data[k])
      end
    end
  end
end

--== path/directory utils ==--

path = {}
path.dirname = function (filename)
  while true do
    if filename == "" or string.sub(filename, -1) == "/" then
      break
    end
    filename = string.sub(filename, 1, -2)
  end
  if filename == "" then
    filename = "."
  end

  return filename
end

path.is_file = function (filename)
  local f = io.open(filename, "r")
  if f ~= nil then
    io.close(f)
    return true
  end
  return false
end

-- filename DOES contain the extension
path.split = function(path, compositeExtension)
  local dir, filename, ext = string.match(path, "^(.*/)([^/]-([^/%.]*))$")
  if dir == nil then -- a single filename only
    filename, ext = string.match(path, "^([^/]-([^/%.]*))$")
  end
  if filename == ext then
    ext = ''
  elseif compositeExtension then
    ext = string.match(filename, "%.(.*)$")
  end
  return dir, filename, ext
end

-- filename DOES NOT contain the extension
path.splitWithoutExt = function(filepath, compositeExtension)
  local dir, filename, ext = path.split(filepath, compositeExtension)
  filename = filename:gsub('.'..ext, "")
  return dir, filename, ext
end

path.getCurrentPath = function()
  local dirname, filename = path.split(debug.getinfo(2).short_src)
  return dirname
end

path.getPathLevelMain = function(levelName)
  return sanitizePath('/levels/'..levelName..'/main.level.json')
end

path.getPathLevelInfo = function(levelName)
  return sanitizePath('/levels/'..levelName..'/info.json')
end

-- returns level name and rest of path
path.levelFromPath = function(filepath)
  return string.match(filepath, "levels/([%w_]+)(.+)")
end

function getCurrentLevelIdentifier(raw)
  local dir, filename, ext = path.split(getMissionFilename())
  if dir ~= nil then
    if raw then string.gsub(dir, "/levels/(.*)/", "%1") end
    return string.lower(string.gsub(dir, "/levels/(.*)/", "%1"))
  end
end

function getAllLevelIdentifiers()
  local ret = {}
  for _, lvlPath in ipairs(FS:findFiles('/levels/', '*', 0, false, true)) do
    table.insert(ret, string.lower(lvlPath:sub(9)))
  end
  return ret
end

--== Ini settings file ==--
-- plain, no section, no nested INI support
function loadIni(filename)
  local d = {}
  local f = io.open(filename, "r")
  if not f then return nil end
  for line in f:lines() do
    if string.len(line) > 0 then
      local firstChar = string.sub(line, 1, 1)
      if firstChar ~= '#' and firstChar ~= ';' and firstChar ~= '/' then
        local key, value = line:match("^([^%s=]+)%s-=%s-(.+)$")
        if key and value then
          value = trim(value)
          if tonumber(value) then
            value = tonumber(value)
          elseif value == "true" then
            value = true
          elseif value == "false" then
            value = false
          end
          d[key] = value
        else
          log("E", "", "Unable to parse INI line: "..line)
        end
      end
    end
  end
  f:close()
  return d
end

function saveIni(filename, d)
  local c = {}

  -- sort the keys
  local dkeys = {}
  for k in pairs(d) do table.insert(dkeys, k) end
  table.sort(dkeys)

  -- save a header
  table.insert(c, '# ' .. beamng_windowtitle .. '\r\n')
  table.insert(c, '# ' .. beamng_buildinfo .. '\r\n')
  table.insert(c, '# saved on ' .. formatTimeStringNow('{YYYY}/{MM}/{DD} {HH}:{mm}:{ss}') .. '\r\n')

  -- save the text
  for _, k in pairs(dkeys) do
    local v = d[k]
    table.insert(c, ("%s = %s\r\n"):format(tostring(k), tostring(v)))
  end

  -- create the file
  local f = io.open(filename, "w")
  if not f then return end
  f:write(tableconcat(c, ""))
  f:close()
end

--== Serialization ==--

-- serialization functions, see testSerialization
local function serialize_rec(v)
  local vtype = type(v)

  if vtype == "string" then
    bufTmp:putf('%q', v)
  elseif vtype == "number" then
    if v * 0 ~= 0 then -- inf,nan
      bufTmp:put(v > 0 and '9e999' or '-9e999')
    else
      bufTmp:putf('%.9g', v)
    end
  elseif vtype == "table" then
    if v._noSerialize then
      bufTmp:put('nil')
      return
    end
    if v._serialize ~= nil then
      bufTmp:put('_kv{')
      local incl = v._serialize
      if type(incl) == "table" then
        for kk, vv in pairs(v) do
          if incl[kk] then
            bufTmp:putf(type(kk) == 'string' and "%q;" or "%s;", kk)
            serialize_rec(vv)
            bufTmp:put(',')
          end
        end
      else
        for kk, vv in pairs(v) do
          bufTmp:putf(type(kk) == 'string' and "%q;" or "%s;", kk)
          serialize_rec(vv)
          bufTmp:put(',')
        end
      end
      bufTmp:put('}')
    else
      local arrayidx = 1
      local prefix = "{"
      for kk, vv in pairs(v) do
        if kk == arrayidx then
          arrayidx = arrayidx + 1
          bufTmp:put(prefix)
        else
          bufTmp:putf(type(kk) == 'string' and "%s[%q]=" or "%s[%s]=", prefix, kk)
        end
        prefix = ","
        serialize_rec(vv)
      end
      if prefix ~= "," then
        bufTmp:put('{')
      end
      bufTmp:put('}')
    end
  elseif vtype == "boolean" then
    bufTmp:put(tostring(v))
  elseif vtype == 'nil' then
    bufTmp:put('nil')
  elseif vtype == "userdata" then
    -- %.9g produces the shortest numbers
    if v.___type == __typeColor then
      bufTmp:putf("color(%.9g,%.9g,%.9g,%.9g)", v.r, v.g, v.b, v.a)
    elseif v.___type == __typeQuatF then
      bufTmp:putf("QuatF(%.9g,%.9g,%.9g,%.9g)", v.x, v.y, v.z, v.w)
    else
      log("E", "serialize", "Unrecognized data ___type: "..dumps(v.___type))
    end
  elseif vtype == 'cdata' then
    bufTmp:put(tostring(v))
  elseif vtype == 'function' then
    bufTmp:put('nil')
  else
    log("E", "serialize", "Unrecognized data type: "..type(v))
  end
end

function serialize(v)
  bufTmp:reset()
  serialize_rec(v)
  return tostring(bufTmp)
end

function _kv(kv)
  local kvlen = #kv
  local t = table.new(0, kvlen * 0.5)
  for i = 1, kvlen, 2 do
    t[kv[i]] = kv[i+1]
  end
  return t
end

function deserialize(s)
  if s == nil then return nil end
  return loadstring("return " .. s)()
end

-- function testSerialization()
--   d = {a = "foo", b = {c = 123, d = "foo", p = vec3(1,2,3)}}
--   print("original data: " .. tostring(d))
--   dump(d)

--   s = serialize(d)
--   print("serialized data: " .. tostring(s))

--   da = deserialize(s)
--   print("restored data: " .. tostring(da))
--   dump(da)

--   sa = serialize(da)
--   if sa == s then
--     print "serialization seems to work"
--   else
--     print "serialization got problems, look above"
--   end

--   if deserialize(serialize(nil)) ~= nil then print "serialize with nil fails to work corectly" end
-- end
--testSerialization()

--== Other ==--

function detectGlobalWrites()
  setmetatable(_G, {
    __newindex = function (t, key, val)
      rawset(_G, key, val)
      log('W', 'globals', debug.traceback('set new global variable: "' .. tostring(key) .. '"  to "'  .. tostring(val) .. '"', 2, 1, false))
    end,
  })
end

-- prints bytes of garbage created since previous call
function gcprobe(printZero, omitPrint)
  local newgccount = collectgarbage("count") * 1024
  if __prevgccount__ then
    local dif = newgccount - __prevgccount__
    collectgarbage('restart')
    if (dif > 0 or printZero) and not omitPrint then print(dif) end
    __prevgccount__ = false
    return dif
  else
    collectgarbage('stop')
    rawset(_G, '__prevgccount__', newgccount)
  end
end

-- prints duration in ms
function timeprobe(omitPrint)
  if not __hp__ then
    rawset(_G, '__hp__', be and hptimer() or HighPerfTimer())
  end
  if not __prevtime__ then
    rawset(_G, '__prevtime__', __hp__:stopAndReset())
  else
    local t = __hp__:stopAndReset()
    if not omitPrint then
      print(t)
      t = be and t*0.001 or t
    end
    __prevtime__ = false
    return t
  end
end

function jitprobe()
  if not __jitprobeactive__ then
    if not __jitv__ then
      rawset(_G, '__jitv__', require("jit.v"))
    end
    rawset(_G, '__jitprobeactive__', true)
    __jitv__.on("-")
  else
    __jitv__.off("-")
    __jitprobeactive__ = false
  end
end

local function _flattenTable_rec(tbl, tableRegister, path)
  local keys = tableKeysSorted(tbl)

  for _, k in pairs(keys) do
    local v = tbl[k]
    if type(v) == 'table' then
      local tblPtr = tostring(v)
      if not tableRegister[tblPtr] then
        local newPath = path .. '/' .. tostring(k)
        tableRegister[tblPtr] = '>#>' .. newPath
        _flattenTable_rec(v, tableRegister, newPath)
      else
        tbl[k] = tableRegister[tblPtr]
      end
    end
  end
end

-- replace multiple references to a table with a special token
function flattenTable(tbl)
  if type(tbl) ~= 'table' then return nil end
  _flattenTable_rec(tbl, {}, '')
  return tbl
end

local function _unflattenTable_rec(tbl, tableRegister, path)
  for k, v in pairs(tbl) do
    if type(v) == 'table' then
      local newPath = path .. '/' .. tostring(k)
      tableRegister['>#>' .. newPath] = v
      _unflattenTable_rec(v, tableRegister, newPath)
    elseif type(v) == 'string' and v:match("%>%#%>(.*)") then
      if not tableRegister[v] then
        log('E', 'tableFlattener', 'unable to unflatten table, link not in tree')
      else
        tbl[k] = tableRegister[v]
      end
    end
  end
end

-- replace the special tokens via flattenTable with the proper table links
function unflattenTable(tbl)
  if type(tbl) ~= 'table' then return nil end
  _unflattenTable_rec(tbl, {}, '')
  return tbl
end

-- https://www.lua.org/pil/19.3.html
function pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end


function hex_dump(str)
  local len = string.len(str)
  local hex = ''
  local asc = ''
  for i = 1, len do
    if 1 == i % 8 then
      print(hex .. asc)
      hex = string.format( "%04x: ", i - 1 )
      asc = ""
    end

    local ord = string.byte( str, i )
    hex = hex .. string.format( "%02x ", ord )
    if ord >= 32 and ord <= 126 then
      asc = asc .. string.char( ord )
    else
      asc = asc .. "."
    end
  end
  print(hex .. string.rep( "   ", 8 - len % 8 ) .. asc)
end
