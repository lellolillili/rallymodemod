--[[
 Fast Lua de/serializer for Lua 5.1

 Copyright (c) 2013-2022 BeamNG GmbH
 All Rights Reserved.

 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or
 sell copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following conditions:

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
 ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 --]]

local M = {}

if not pcall(require, "table.clear") then
  table.clear = function(tab) for k, _ in ipairs(tab) do tab[k] = nil end end
end

if not pcall(require, "table.new") then
  table.new = function() return {} end
end

local ffifound, ffi = pcall(require, 'ffi')
if not ffifound then
  ffi = {offsetof = function(v, atr) return v[atr] end}
end

local buffer = require('string.buffer')

local tonumber, byte, char, sub = tonumber, string.byte, string.char, string.sub
local abs, min, tableconcat, tablenew, tableclear = math.abs, math.min, table.concat, table.new, table.clear

local peekEncLua
local peekEnc
local peekDec = {}
local peekEncBin

local serTmp = {}
local bufTmp = buffer.new()
local bufDec = buffer.new()
local ludNull = bufTmp:set("\03"):decode()

local s

local function encodeDoubleArray(tbl)
  local startIdx = tbl[0] == nil and 1 or 0
  local tsize = #tbl + 1 - startIdx
  local da = ffi.new('double[?]', tsize)
  if startIdx == 1 then
    for i = 1, tsize do
      da[i - 1] = tbl[i]
    end
  else
    for i = 0, tsize - 1 do
      da[i] = tbl[i]
    end
  end

  return ffi.string(da, 8 * tsize)
end

local function decodeDoubleArray(sda, tbl)
  local sdabytes = #sda
  local sdasize = sdabytes / 8
  local da, tbl = ffi.new('double[?]', sdasize), tbl or {}
  ffi.copy(da, sda, sdabytes)
  for i = 0, sdasize - 1 do
    tbl[i+1] = da[i]
  end
  return tbl
end

local function encodeLua(v)
  bufTmp:reset()
  peekEncLua[type(v)](v)
  return bufTmp:get()
end

local function decodeLua(s)
  if s == nil then return nil end
  return loadstring("return " .. s)()
end

local function encode(v)
  if v == nil then return '' end
  serTmp[1] = 'a'
  serTmp[peekEnc[type(v)](v, 2)] = '~'
  local res = tableconcat(serTmp)
  tableclear(serTmp)
  return res
end

local function encodeBin(v)
  if v == nil then return '' end
  bufTmp:reset():put('b')
  peekEncBin[type(v)](bufTmp, v)
  return bufTmp:get()
end

local function encodeNumber(v, seridx)
  local seridx1 = seridx + 1
  if v * 0 ~= 0 then -- inf,nan
    serTmp[seridx] = v >= 0 and '-9e+999' or '=9e+999'
    return seridx1
  else
    if v < 0 then
      serTmp[seridx] = '='
      serTmp[seridx1] = abs(v)
      return seridx + 2
    else
      serTmp[seridx] = -abs(v)
      return seridx1
    end
  end
end

local function decodeNumber(seridx)
  local i, r = seridx + 1, 0
  local c = byte(s, i)
  while c >= 48 and c <= 57 do -- \d
    i = i + 1
    r = (c - 48) + r * 10
    c = byte(s, i)
  end
  if c == 46 then -- .
    i = i + 1
    c = byte(s, i)
    local f = 0
    local scale = 0.1
    while c >= 48 and c <= 57 do -- \d
      i = i + 1
      f = f + (c - 48) * scale
      c = byte(s, i)
      scale = scale * 0.1
    end
    r = r + f
  end
  if c == 101 then -- e
    i = i + 2 -- skip e+-
    c = byte(s, i)
    while c >= 48 and c <= 57 do -- \d
      i = i + 1
      c = byte(s, i)
    end
    r = tonumber(sub(s, seridx + 1, i - 1))
  end
  return r, c, i
end

local function decodeInt(i)
  i = i + 1
  local r, c = 0, byte(s, i)
  while c >= 48 and c <= 57 do -- \d
    i = i + 1; r = r * 10 + (c - 48); c = byte(s, i)
  end
  return r, c, i
end

local function decodeString(seridx)
  local i = seridx
  local i1 = i + 1
  local b1, b2 = byte(s, i, i1)
  local numlen = b1 - 65
  local strlen = b2 - 48
  i = i1
  for i1 = 1, numlen do
    strlen = (byte(s, i + i1) - 48) + strlen * 10
  end
  local strs = i + numlen + 1
  seridx = strs + strlen
  return sub(s, strs, seridx-1), byte(s, seridx), seridx
end

local function peekDecBin(buf)
  local c = byte(buf:get(1))
  if c <= 250 then -- table
    local arrayidx, res = 1, tablenew(c, 2)
    while true do
      local elem = buf:decode()
      if elem == ludNull then
        local key = buf:decode()
        if key == nil then return res end
        elem = buf:decode()
        if elem == nil then elem = peekDecBin(buf) end
        res[key] = elem
      else
        if elem == nil then elem = peekDecBin(buf) end
        res[arrayidx] = elem
        arrayidx = arrayidx + 1
      end
    end
  elseif c == 252 then -- vec3
    return vec3(buf:decode(), buf:decode(), buf:decode())
  elseif c == 251 then -- quat
    return quat(buf:decode(), buf:decode(), buf:decode(), buf:decode())
  end
end

local function decode(is)
  if is == '' or is == nil then return nil end
  local res
  local gcrunning = collectgarbage("isrunning")
  collectgarbage("stop")
  s = is
  if byte(is, 1) == 98 then -- b
    bufDec:set(is):get(1)
    res = bufDec:decode()
    if res == nil then res = peekDecBin(bufDec) end
  else
    res = peekDec[byte(is, 2)](2)
  end
  s = nil
  if gcrunning then collectgarbage("restart") end
  return res
end

local function bufTostring(v)
  bufTmp:put(tostring(v))
end

-- dispatch tables
do
  -- encodeLua
  peekEncLua = {
    boolean = bufTostring,
    userdata = bufTostring,
    string = function(v)
      bufTmp:putf('%q', v)
    end
    ,
    number = function(v)
      if v * 0 ~= 0 then -- inf,nan
        bufTmp:put(v > 0 and '9e999' or '-9e999')
      else
        bufTmp:put(v)
      end
    end
    ,
    table = function(v)
      local arrayidx, prefix = 1, "{"
      for kk, vv in pairs(v) do
        if kk == arrayidx then
          arrayidx = arrayidx + 1
          bufTmp:put(prefix)
        else
          bufTmp:putf(type(kk) == 'string' and "%s[%q]=" or "%s[%s]=", prefix, kk)
        end
        prefix = ","
        peekEncLua[type(vv)](vv)
      end
      if prefix ~= "," then
        bufTmp:put('{')
      end
      bufTmp:put('}')
    end
    ,
    cdata = function(v)
      if ffi.offsetof(v, 'z') ~= nil then  -- vec3
        if ffi.offsetof(v, 'w') ~= nil then -- quat
          bufTmp:put(tostring(v))
        else
          bufTmp:put("vec3(", v.x, ",", v.y, ",", v.z, ")")
        end
      else
        bufTmp:put(tostring(v))
      end
    end
  }

  -- binary encode
  peekEncBin = {
    string = bufTmp.encode,
    number = bufTmp.encode,
    boolean = bufTmp.encode,
    table = function(buf, v)
      local arrayidx, peek = 1, peekEncBin

      buf:put('\0'):put(char(min(#v, 250)))
      for kk, vv in pairs(v) do
        if kk == arrayidx then
          arrayidx = arrayidx + 1
          peek[type(vv)](buf, vv)
        else
          buf:put('\3'):encode(kk)
          peek[type(vv)](buf, vv)
        end
      end
      buf:put('\3\0')
    end
    ,
    cdata = function(buf, v)
      if ffi.offsetof(v, 'z') ~= nil then  -- vec3
        if ffi.offsetof(v, 'w') ~= nil then -- quat
          buf:put("\0\251"):encode(v.x):encode(v.y):encode(v.z):encode(v.w)
        else
          buf:put("\0\252"):encode(v.x):encode(v.y):encode(v.z)
        end
      else
        buf:put("\0\255")
      end
    end
    ,
    ["nil"] = function(buf, v)
      buf:put('\0\255')
    end
  }

  -- packed encode
  peekEnc = {
    number = encodeNumber,
    string = function(v, seridx)
      local vlen = #v
      serTmp[seridx] = vlen < 10 and 'A' or (vlen < 100 and 'B' or string.char(65 + math.floor(math.log10(vlen))))
      serTmp[seridx + 1] = vlen
      serTmp[seridx + 2] = v
      return seridx + 3
    end
    ,
    table = function(v, seridx)
      local dictlen = 0
      local dictlenidx
      local stmp = serTmp
      local peek = peekEnc

      if v[1] ~= nil then
        local arrayidx = 1

        stmp[seridx] = '['
        dictlenidx = seridx + 3
        seridx = seridx + 4

        for kk, vv in pairs(v) do
          if kk == arrayidx then
            arrayidx = arrayidx + 1
            seridx = peek[type(vv)](vv, seridx)
          else
            stmp[seridx] = ':'
            dictlen = dictlen + 1
            seridx = peek[type(vv)](vv, peek[type(kk)](kk, seridx + 1))
          end
        end

        stmp[dictlenidx - 2] = arrayidx - 1
        stmp[dictlenidx - 1] = dictlen > 0 and ',' or ''
      else
        stmp[seridx] = '{'
        dictlenidx = seridx + 1
        seridx = seridx + 2

        for kk, vv in pairs(v) do
          dictlen = dictlen + 1
          seridx = peek[type(vv)](vv, peek[type(kk)](kk, seridx))
        end
      end

      stmp[dictlenidx] = dictlen > 0 and dictlen or ''
      return seridx
    end
    ,
    boolean = function(v, seridx)
      serTmp[seridx] = v and '|' or '~'
      return seridx + 1
    end
    ,
    cdata = function(v, seridx)
      if ffi.offsetof(v, 'z') ~= nil then  -- vec3
        if ffi.offsetof(v, 'w') ~= nil then -- quat
          serTmp[seridx] = '&'
          return encodeNumber(v.w, encodeNumber(v.z, encodeNumber(v.y, encodeNumber(v.x, seridx + 1))))
        else
          serTmp[seridx] = '^'
          return encodeNumber(v.z, encodeNumber(v.y, encodeNumber(v.x, seridx + 1)))
        end
      else
        serTmp[seridx] = '?'
        return seridx + 1
      end
      return seridx
    end
  }

  -- packed decode
  peekDec = {
    [91] = function(seridx) -- [ (table)
      local arraylen, c, seridx = decodeInt(seridx)
      local peek = peekDec

      if c ~= 44 then
        local res = tablenew(arraylen, 0)

        for i = 1, arraylen do
          res[i], c, seridx = peek[c](seridx)
        end
        return res, c, seridx
      else
        local dictlen
        dictlen, c, seridx = decodeInt(seridx)
        local res = tablenew(arraylen, dictlen)
        local arrayidx = 1

        for _ = 1, arraylen + dictlen do
          if c == 58 then -- :
            local key
            seridx = seridx + 1
            key, c, seridx = peek[byte(s, seridx)](seridx)
            res[key], c, seridx = peek[c](seridx)
          else
            res[arrayidx], c, seridx = peek[c](seridx)
            arrayidx = arrayidx + 1
          end
        end
        return res, c, seridx
      end
    end
    ,
    [123] = function(seridx) -- { (dict)
      local dictlen, c, seridx = decodeInt(seridx)
      local res = tablenew(0, dictlen)
      local peek = peekDec
      local key
      for _ = 1, dictlen do
        key, c, seridx = peek[c](seridx)
        res[key], c, seridx = peek[c](seridx)
      end
      return res, c, seridx
    end
    ,
    [124] = function(seridx) -- | (true)
      seridx = seridx + 1
      return true, byte(s, seridx), seridx
    end
    ,
    [126] = function(seridx) -- ~ (false)
      seridx = seridx + 1
      return false, byte(s, seridx), seridx
    end
    ,
    [61] = function(seridx) -- =
      local num, c, seridx = decodeNumber(seridx)
      return -num, c, seridx
    end
    ,
    [45] = decodeNumber, -- -
    [65] = decodeString,
    [66] = decodeString,
    [67] = decodeString,
    [68] = decodeString,
    [69] = decodeString,
    [70] = decodeString,
    [71] = decodeString,
    [72] = decodeString,
    [73] = decodeString,
    [74] = decodeString
    ,
    [94] = function(seridx) -- ^ (vec3)
      seridx = seridx + 1
      local x, y, z, c
      x, c, seridx = peekDec[byte(s, seridx)](seridx)
      y, c, seridx = peekDec[c](seridx)
      z, c, seridx = peekDec[c](seridx)
      return vec3(x, y, z), c, seridx
    end
    ,
    [38] = function(seridx) -- & (quat)
      seridx = seridx + 1
      local x, y, z, w, c
      x, c, seridx = peekDec[byte(s, seridx)](seridx)
      y, c, seridx = peekDec[c](seridx)
      z, c, seridx = peekDec[c](seridx)
      w, c, seridx = peekDec[c](seridx)
      return quat(x, y, z, w), c, seridx
    end
    ,
    [63] = function(seridx) -- ? (ctype)
      seridx = seridx + 1
      return '?', byte(s, seridx), seridx
    end
    ,
  }
end

-- public interface
M.encode = encode
M.decode = decode
M.encodeLua = encodeLua
M.decodeLua = decodeLua
M.encodeBin = encodeBin
M.encodeDoubleArray = encodeDoubleArray
M.decodeDoubleArray = decodeDoubleArray
return M
