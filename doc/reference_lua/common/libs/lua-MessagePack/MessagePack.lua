-- lua-MessagePack is licensed under the terms of the MIT/X11 license reproduced below.
-- Copyright (C) 2012-2014 Francois Perrad, 2022 BeamNG
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.
--
-- BASE VERSION = '0.5.1'

local char, format = string.char, string.format
local abs, floor, frexp, ldexp, huge = math.abs, math.floor, math.frexp, math.ldexp, math.huge
local tconcat = table.concat

local _ENV = nil
local m = {}

--[[ debug only
local function hexadump(s)
  return (s:gsub('.', function (c) return format('%02X ', c:byte()) end))
end
m.hexadump = hexadump
--]]

local function argerror(caller, narg, extramsg)
  error("bad argument #" .. tostring(narg) .. " to "
      .. caller .. " (" .. extramsg .. ")")
end

local function typeerror(caller, narg, arg, tname)
  argerror(caller, narg, tname .. " expected, got " .. type(arg))
end

local function checktype(caller, narg, arg, tname)
  if type(arg) ~= tname then
    typeerror(caller, narg, arg, tname)
  end
end

local packers = setmetatable({}, {
  __index = function(t, k)
    if k == 1 then return end   -- allows ipairs
    error("pack '" .. k .. "' is unimplemented")
  end
})
m.packers = packers

packers['nil'] = function(buffer, bi)
  buffer[bi] = char(0xC0) -- nil
  return bi + 1
end

packers['boolean'] = function(buffer, bi, bool)
  buffer[bi] = bool and char(0xC3) or char(0xC2) -- true false
  return bi + 1
end

packers['tstring'] = function(buffer, bi, str) -- text string
  local n = #str
  if n <= 0x1F then
    buffer[bi] = char(0xA0 + n) -- fixstr
  elseif n <= 0xFF then
    buffer[bi] = char(0xD9, n) -- str8
  elseif n <= 0xFFFF then
    buffer[bi] = char(0xDA, floor(n / 0x100), n % 0x100) -- str16
  else
    buffer[bi] = char(0xDB, floor(n / 0x1000000), floor(n / 0x10000) % 0x100, floor(n / 0x100) % 0x100, n % 0x100) -- str32
  end
  buffer[bi + 1] = str
  return bi + 2
end

packers['string'] = function(buffer, bi, str) -- bin string
  local n = #str
  if n <= 0xFF then
    buffer[bi] = char(0xC4, n) -- bin8
  elseif n <= 0xFFFF then
    buffer[bi] = char(0xC5, floor(n / 0x100), n % 0x100) -- bin16
  else
    buffer[bi] = char(0xC6, floor(n / 0x1000000), floor(n / 0x10000) % 0x100, floor(n / 0x100) % 0x100, n % 0x100) -- bin32
  end
  buffer[bi + 1] = str
  return bi + 2
end

packers['map'] = function(buffer, bi, tbl, n)
  if n <= 0x0F then
    buffer[bi] = char(0x80 + n) -- fixmap
  elseif n <= 0xFFFF then
    buffer[bi] = char(0xDE, floor(n / 0x100), n % 0x100) -- map16
  else
    buffer[bi] = char(0xDF, floor(n / 0x1000000), floor(n / 0x10000) % 0x100, floor(n / 0x100) % 0x100, n % 0x100) -- map32
  end
  bi = bi + 1
  for k, v in pairs(tbl) do
    local typek = type(k)
    bi = packers[typek == 'string' and 'tstring' or typek](buffer, bi, k)
    bi = packers[type(v)](buffer, bi, v)
  end
  return bi
end

packers['array'] = function(buffer, bi, tbl, n)
  if n <= 0x0F then
    buffer[bi] = char(0x90 + n) -- fixarray
  elseif n <= 0xFFFF then
    buffer[bi] = char(0xDC, floor(n / 0x100), n % 0x100) -- array16
  else
    buffer[bi] = char(0xDD, floor(n / 0x1000000), floor(n / 0x10000) % 0x100, floor(n / 0x100) % 0x100, n % 0x100) -- array32
  end
  bi = bi + 1
  for i = 1, n do
    local v = tbl[i]
    bi = packers[type(v)](buffer, bi, v)
  end
  return bi
end

local set_array = function(array)
  if array == 'without_hole' then
    packers['_table'] = function(buffer, bi, tbl)
      local is_map, n, max = false, 0, 0
      for k in pairs(tbl) do
        if type(k) == 'number' and k > 0 then
          if k > max then
            max = k
          end
        else
          is_map = true
        end
        n = n + 1
      end
      if max ~= n then -- there are holes
        is_map = true
      end
      if is_map then
        bi = packers['map'](buffer, bi, tbl, n)
      else
        bi = packers['array'](buffer, bi, tbl, n)
      end
      return bi
    end
  elseif array == 'with_hole' then
    packers['_table'] = function(buffer, bi, tbl)
      local is_map, n, max = false, 0, 0
      for k in pairs(tbl) do
        if type(k) == 'number' and k > 0 then
          if k > max then
            max = k
          end
        else
          is_map = true
        end
        n = n + 1
      end
      if is_map then
        bi = packers['map'](buffer, bi, tbl, n)
      else
        bi = packers['array'](buffer, bi, tbl, max)
      end
      return bi
    end
  elseif array == 'always_as_map' then
    packers['_table'] = function(buffer, bi, tbl)
      local n = 0
      for k in pairs(tbl) do
        n = n + 1
      end
      return packers['map'](buffer, bi, tbl, n)
    end
  else
    argerror('set_array', 1, "invalid option '" .. array .."'")
  end
end
m.set_array = set_array

packers['table'] = function(buffer, bi, tbl)
  return packers['_table'](buffer, bi, tbl)
end

packers['number'] = function(buffer, bi, n)
  local mant, expo = frexp(abs(n))
  if mant ~= mant then
    buffer[bi] = char(0xCB, 0xFF, 0xF8, 0, 0, 0, 0, 0, 0)  -- nan
  elseif mant == huge or expo > 0x400 then
    buffer[bi] = char(0xCB, n >= 0 and 0x7F or 0xFF, 0xF0, 0, 0, 0, 0, 0, 0) -- inf
  elseif (mant == 0 and expo == 0) or expo < -0x3FE then
    buffer[bi] = char(0xCB, n >= 0 and 0 or 0x80, 0, 0, 0, 0, 0, 0, 0)  -- zero
  else
    expo = expo + 0x3FE
    mant = floor((mant * 2.0 - 1.0) * ldexp(0.5, 53))
    buffer[bi] = char(0xCB, (n >= 0 and 0 or 0x80) + floor(expo / 0x10), (expo % 0x10) * 0x10 + floor(mant / 0x1000000000000),
      floor(mant / 0x10000000000) % 0x100, floor(mant / 0x100000000) % 0x100, floor(mant / 0x1000000) % 0x100, floor(mant / 0x10000) % 0x100,
      floor(mant / 0x100) % 0x100, mant % 0x100)
  end
  return bi + 1
end

for k = 0, 4 do
  local n = floor(2^k)
  local fixext = 0xD4 + k
  packers['fixext' .. tostring(n)] = function(buffer, bi, tag, data)
    buffer[bi] = char(fixext, tag < 0 and tag + 0x100 or tag)
    buffer[bi + 1] = data
    return bi + 2
  end
end

packers['ext'] = function(buffer, bi, tag, data)
  local n = #data
  if n <= 0xFF then
    buffer[bi] = char(0xC7, n, tag < 0 and tag + 0x100 or tag) -- ext8
  elseif n <= 0xFFFF then
    buffer[bi] = char(0xC8, floor(n / 0x100), n % 0x100, tag < 0 and tag + 0x100 or tag) -- ext16
  elseif n <= 4294967295.0 then
    buffer[bi] = char(0xC9, floor(n/0x1000000), floor(n/0x10000) % 0x100, floor(n/0x100) % 0x100, n % 0x100, tag<0 and tag+0x100 or tag) -- ext&32
  else
    error"overflow in pack 'ext'"
  end
  buffer[bi + 1] = data
  return bi + 2
end

function m.pack(data)
  local buffer = {}
  packers[type(data)](buffer, 1, data)
  return tconcat(buffer)
end

function m.packPrefix(prefix, data)
  local buffer = {prefix}
  packers[type(data)](buffer, 2, data)
  return tconcat(buffer)
end

local unpackers         -- forward declaration

local function unpack_cursor(c)
  local s, i, j = c.s, c.i, c.j
  if i > j then
    c:underflow(i)
    s, i, j = c.s, c.i, c.j
  end
  local val = s:byte(i)
  c.i = i+1
  return unpackers[val](c, val)
end
m.unpack_cursor = unpack_cursor

local function unpack_str(c, n)
  local s, i, j = c.s, c.i, c.j
  local e = i+n-1
  if e > j or n < 0 then
    c:underflow(e)
    s, i, j = c.s, c.i, c.j
    e = i+n-1
  end
  c.i = i+n
  return s:sub(i, e)
end

local function unpack_array(c, n)
  local t = {}
  for i = 1, n do
    t[i] = unpack_cursor(c)
  end
  return t
end

local function unpack_map(c, n)
  local t = {}
  for i = 1, n do
    local k = unpack_cursor(c)
    local val = unpack_cursor(c)
    if k == nil or k ~= k then
      k = m.sentinel
    end
    if k ~= nil then
      t[k] = val
    end
  end
  return t
end

local function unpack_float(c)
  local s, i, j = c.s, c.i, c.j
  if i+3 > j then
    c:underflow(i+3)
    s, i, j = c.s, c.i, c.j
  end
  local b1, b2, b3, b4 = s:byte(i, i+3)
  local sign = b1 > 0x7F and -1 or 1
  local expo = (b1 % 0x80) * 0x2 + floor(b2 / 0x80)
  local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4
  c.i = i+4
  if mant == 0 and expo == 0 then
    return sign * 0
  elseif expo == 0xFF then
    return mant == 0 and sign * huge or 0/0
  else
    return sign * ldexp(1 + mant / 0x800000, expo - 0x7F)
  end
end

local function unpack_double(c)
  local s, i, j = c.s, c.i, c.j
  if i+7 > j then
    c:underflow(i+7)
    s, i, j = c.s, c.i, c.j
  end
  local b1, b2, b3, b4, b5, b6, b7, b8 = s:byte(i, i+7)
  local sign = b1 > 0x7F and -1 or 1
  local expo = (b1 % 0x80) * 0x10 + floor(b2 / 0x10)
  local mant = ((((((b2 % 0x10) * 0x100 + b3) * 0x100 + b4) * 0x100 + b5) * 0x100 + b6) * 0x100 + b7) * 0x100 + b8
  c.i = i+8
  if mant == 0 and expo == 0 then
    return sign * 0
  elseif expo == 0x7FF then
    return mant == 0 and sign * huge or 0/0
  else
    return sign * ldexp(1 + mant / 4503599627370496.0, expo - 0x3FF)
  end
end

local function unpack_uint8(c)
  local s, i, j = c.s, c.i, c.j
  if i > j then
    c:underflow(i)
    s, i, j = c.s, c.i, c.j
  end
  c.i = i+1
  return s:byte(i)
end

local function unpack_uint16(c)
  local s, i, j = c.s, c.i, c.j
  if i+1 > j then
    c:underflow(i+1)
    s, i, j = c.s, c.i, c.j
  end
  local b1, b2 = s:byte(i, i+1)
  c.i = i+2
  return b1 * 0x100 + b2
end

local function unpack_uint32(c)
  local s, i, j = c.s, c.i, c.j
  if i+3 > j then
    c:underflow(i+3)
    s, i, j = c.s, c.i, c.j
  end
  c.i = i+4
  local b1, b2, b3, b4 = s:byte(i, i+3)
  return ((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4
end

local function unpack_uint64(c)
  local s, i, j = c.s, c.i, c.j
  if i+7 > j then
    c:underflow(i+7)
    s, i, j = c.s, c.i, c.j
  end
  local b1, b2, b3, b4, b5, b6, b7, b8 = s:byte(i, i+7)
  c.i = i+8
  return ((((((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4) * 0x100 + b5) * 0x100 + b6) * 0x100 + b7) * 0x100 + b8
end

local function unpack_int8(c)
  local s, i, j = c.s, c.i, c.j
  if i > j then
    c:underflow(i)
    s, i, j = c.s, c.i, c.j
  end
  local b1 = s:byte(i)
  c.i = i+1
  return b1 < 0x80 and b1 or b1 - 0x100
end

local function unpack_int16(c)
  local s, i, j = c.s, c.i, c.j
  if i+1 > j then
    c:underflow(i+1)
    s, i, j = c.s, c.i, c.j
  end
  local b1, b2 = s:byte(i, i+1)
  c.i = i+2
  if b1 < 0x80 then
    return b1 * 0x100 + b2
  else
    return (b1 - 0xFF) * 0x100 + (b2 - 0xFF) - 1
  end
end

local function unpack_int32(c)
  local s, i, j = c.s, c.i, c.j
  if i+3 > j then
    c:underflow(i+3)
    s, i, j = c.s, c.i, c.j
  end
  local b1, b2, b3, b4 = s:byte(i, i+3)
  c.i = i+4
  if b1 < 0x80 then
    return ((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4
  else
    return (((b1 - 0xFF) * 0x100 + (b2 - 0xFF)) * 0x100 + (b3 - 0xFF)) * 0x100 + (b4 - 0xFF) - 1
  end
end

local function unpack_int64(c)
  local s, i, j = c.s, c.i, c.j
  if i+7 > j then
    c:underflow(i+7)
    s, i, j = c.s, c.i, c.j
  end
  local b1, b2, b3, b4, b5, b6, b7, b8 = s:byte(i, i+7)
  c.i = i+8
  if b1 < 0x80 then
    return ((((((b1 * 0x100 + b2) * 0x100 + b3) * 0x100 + b4) * 0x100 + b5) * 0x100 + b6) * 0x100 + b7) * 0x100 + b8
  else
    return (((((((b1 - 0xFF) * 0x100 + (b2 - 0xFF)) * 0x100 + (b3 - 0xFF)) * 0x100 + (b4 - 0xFF)) * 0x100 + (b5 - 0xFF)) * 0x100 + (b6 - 0xFF)) * 0x100 + (b7 - 0xFF)) * 0x100 + (b8 - 0xFF) - 1
  end
end

function m.build_ext(tag, data)
  return nil
end

local function unpack_ext(c, n, tag)
  local s, i, j = c.s, c.i, c.j
  local e = i+n-1
  if e > j or n < 0 then
    c:underflow(e)
    s, i, j = c.s, c.i, c.j
    e = i+n-1
  end
  c.i = i+n
  return m.build_ext(tag, s:sub(i, e))
end

unpackers = setmetatable({
  [0xC0] = function() return nil end,
  [0xC2] = function() return false end,
  [0xC3] = function() return true end,
  [0xC4] = function(c) return unpack_str(c, unpack_uint8(c)) end,    -- bin8
  [0xC5] = function(c) return unpack_str(c, unpack_uint16(c)) end,   -- bin16
  [0xC6] = function(c) return unpack_str(c, unpack_uint32(c)) end,   -- bin32
  [0xC7] = function(c) return unpack_ext(c, unpack_uint8(c), unpack_int8(c)) end,
  [0xC8] = function(c) return unpack_ext(c, unpack_uint16(c), unpack_int8(c)) end,
  [0xC9] = function(c) return unpack_ext(c, unpack_uint32(c), unpack_int8(c)) end,
  [0xCA] = unpack_float,
  [0xCB] = unpack_double,
  [0xCC] = unpack_uint8,
  [0xCD] = unpack_uint16,
  [0xCE] = unpack_uint32,
  [0xCF] = unpack_uint64,
  [0xD0] = unpack_int8,
  [0xD1] = unpack_int16,
  [0xD2] = unpack_int32,
  [0xD3] = unpack_int64,
  [0xD4] = function(c) return unpack_ext(c, 1, unpack_int8(c)) end,
  [0xD5] = function(c) return unpack_ext(c, 2, unpack_int8(c)) end,
  [0xD6] = function(c) return unpack_ext(c, 4, unpack_int8(c)) end,
  [0xD7] = function(c) return unpack_ext(c, 8, unpack_int8(c)) end,
  [0xD8] = function(c) return unpack_ext(c, 16, unpack_int8(c)) end,
  [0xD9] = function(c) return unpack_str(c, unpack_uint8(c)) end,
  [0xDA] = function(c) return unpack_str(c, unpack_uint16(c)) end,
  [0xDB] = function(c) return unpack_str(c, unpack_uint32(c)) end,
  [0xDC] = function(c) return unpack_array(c, unpack_uint16(c)) end,
  [0xDD] = function(c) return unpack_array(c, unpack_uint32(c)) end,
  [0xDE] = function(c) return unpack_map(c, unpack_uint16(c)) end,
  [0xDF] = function(c) return unpack_map(c, unpack_uint32(c)) end,
}, {
  __index = function(t, k)
    if k < 0xC0 then
      if k < 0x80 then
        return function(c, val) return val end
      elseif k < 0x90 then
        return function(c, val) return unpack_map(c, val % 0x10) end
      elseif k < 0xA0 then
        return function(c, val) return unpack_array(c, val % 0x10) end
      else
        return function(c, val) return unpack_str(c, val % 0x20) end
      end
    elseif k > 0xDF then
      return function(c, val) return val - 0x100 end
    else
      return function() error("unpack '" .. format('%#x', k) .. "' is unimplemented") end
    end
  end
})

local function cursor_string(str)
  return {
    s = str,
    i = 1,
    j = #str,
    underflow = function()
            error "missing bytes"
          end,
  }
end

local function cursor_loader(ld)
  return {
    s = '',
    i = 1,
    j = 0,
    underflow = function(self, e)
            self.s = self.s:sub(self.i)
            e = e - self.i + 1
            self.i = 1
            self.j = 0
            while e > self.j do
              local chunk = ld()
              if not chunk then
                error "missing bytes"
              end
              self.s = self.s .. chunk
              self.j = #self.s
            end
          end,
  }
end

function m.unpack(s)
  checktype('unpack', 1, s, 'string')
  local cursor = cursor_string(s)
  local data = unpack_cursor(cursor)
  if cursor.i <= cursor.j then
    error "extra bytes"
  end
  return data
end

function m.unpacker(src)
  if type(src) == 'string' then
    local cursor = cursor_string(src)
    return function()
      if cursor.i <= cursor.j then
        return cursor.i, unpack_cursor(cursor)
      end
    end
  elseif type(src) == 'function' then
    local cursor = cursor_loader(src)
    return function()
      if cursor.i > cursor.j then
        pcall(cursor.underflow, cursor, cursor.i)
      end
      if cursor.i <= cursor.j then
        return true, unpack_cursor(cursor)
      end
    end
  else
    argerror('unpacker', 1, "string or function expected, got " .. type(src))
  end
end

set_array'without_hole'
return m