-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- small pixel drawing library that can draw primitives and text
-- Usage: see M.test()
-- require('utils/pixellib').test()

-- created by BeamNG

local M = {}

local ffi = require('ffi')
ffi.cdef [[
typedef struct rgba_pixel_t { uint8_t r, g, b, a; } rgba_pixel_t;
bool saveRGBABufferToFile(int width, int height, rgba_pixel_t *data, const char* filename);
]]

local LuaRGBAPixel = {}
LuaRGBAPixel.__index = LuaRGBAPixel
ffi.metatype("rgba_pixel_t", LuaRGBAPixel)
local newLuaRGBAPixel = function(r, g, b, a)
  return ffi.new("rgba_pixel_t", r, g, b, a)
end

local mini_font = {}
local fontHeight = 5

--------------------------------------------------------------------------------

local LuaPixelBuffer = {}
LuaPixelBuffer.__index = LuaPixelBuffer

local function create()
  local newInstance = {}
  setmetatable(newInstance, LuaPixelBuffer)
  return newInstance
end

function LuaPixelBuffer:init(width, height)
  self.width = math.floor(width)
  self.height = math.floor(height)
  self:_allocate_buffer(width * height)
end

function LuaPixelBuffer:saveFile(filename)
  return ffi.C.saveRGBABufferToFile(self.width, self.height, self.buf, filename)
end

function LuaPixelBuffer:_allocate_buffer(n)
  self.bufSize = n
  self.buf = ffi.new("rgba_pixel_t[?]", n)
  --if self.buf then ffi.C.freeARGBBuffer(self.buf) end
  --self.buf = ffi.C.allocateARGBBuffer(n)
end

function LuaPixelBuffer:__tostring()
    return 'LuaPixelBuffer - ' .. tostring(self.buf) .. ' [resolution: ' .. self.width .. ' x ' .. self.height .. ' (RGBA)]'
end

function LuaPixelBuffer:drawPixel(x, y, color)
  if x < 0 or y < 0 or x >= self.width or y >= self.height then return end
  local p = self.buf[math.floor(x) + math.floor(y) * self.width]
  p.r = color.r
  p.g = color.g
  p.b = color.b
  p.a = color.a
end

function LuaPixelBuffer:getPixel(x, y)
  if x < 0 or y < 0 or x >= self.width or y >= self.height then return nil end
  return self.buf[x + y * self.width]
end

function LuaPixelBuffer:drawPoint(x, y, color, size)
  if size == nil or size == 0 then size = 1 end
  if size == 1 then
    self:drawPixel(x, y, color)
  else
    local s1 = math.floor(size * 0.5)
    self:drawFilledCircle(vec3(x, y, 0), s1, color)
  end
end

function LuaPixelBuffer:fill(color)
  self:drawFilledRect(vec3(0,0,0), self.width, self.height, color)
end

function LuaPixelBuffer:drawCircle(pos, radius, color, lineWidth)
  if lineWidth == nil then lineWidth = 1 end
  -- midpoint circle algorithm
  local f = 1 - radius
  local dx = 0
  local dy = -2 * radius
  local x = 0
  local y = radius
  self:drawPoint(pos.x, pos.y + radius, color, lineWidth)
  self:drawPoint(pos.x, pos.y - radius, color, lineWidth)
  self:drawPoint(pos.x + radius, pos.y, color, lineWidth)
  self:drawPoint(pos.x - radius, pos.y, color, lineWidth)

  while x < y do
    if f >= 0 then
      y = y - 1
      dy = dy + 2
      f = f + dy
    end
    x = x + 1
    dx = dx + 2
    f = f + dx + 1
    self:drawPoint(pos.x + x, pos.y + y, color, lineWidth)
    self:drawPoint(pos.x - x, pos.y + y, color, lineWidth)
    self:drawPoint(pos.x + x, pos.y - y, color, lineWidth)
    self:drawPoint(pos.x - x, pos.y - y, color, lineWidth)
    self:drawPoint(pos.x + y, pos.y + x, color, lineWidth)
    self:drawPoint(pos.x - y, pos.y + x, color, lineWidth)
    self:drawPoint(pos.x + y, pos.y - x, color, lineWidth)
    self:drawPoint(pos.x - y, pos.y - x, color, lineWidth)
  end
end

function LuaPixelBuffer:drawFilledCircle(pos, radius, color)
  local r = radius
  for y = -r, r, 1 do
    for x = -r, r, 1 do
      if x * x + y * y <= r * r then
        self:drawPixel(pos.x + x, pos.y + y, color)
      end
    end
  end
end

function LuaPixelBuffer:drawRect(p1, width, height, color, lineWidth)
  if lineWidth == nil then lineWidth = 1 end
  --   p1 -- p2
  --   |     |
  --  p4 -- p3
  local p2 = vec3(p1.x + width, p1.y, 0)
  local p3 = vec3(p1.x + width, p1.y + height, 0)
  local p4 = vec3(p1.x, p1.y + height, 0)
  self:drawLine(p1, p2, color, lineWidth)
  self:drawLine(p2, p3, color, lineWidth)
  self:drawLine(p3, p4, color, lineWidth)
  self:drawLine(p4, p1, color, lineWidth)
end

function LuaPixelBuffer:drawFilledRect(p1, width, height, color)
  for x = p1.x, p1.x + width do
    for y = p1.y, p1.y + height do
      self:drawPixel(x, y, color)
    end
  end
end

-- redneck text drawing function :D
function LuaPixelBuffer:drawText(pos, text, color)
  text = string.upper(text)
  local x = pos.x
  local consumedWidth = 0
  for i = 1, string.len(text) do
    local c = string.sub(text, i, i)
    if c == ' ' then
      -- space char
      x = x + 4
    end
    if mini_font[c] then
      local cl = split(mini_font[c], "\n")
      local maxX = 0
      local charHeight = #cl
      for dy = 1, charHeight do
        for dx = 1, string.len(cl[dy]) do
          local cf = string.sub(cl[dy], dx, dx)
          if cf ~= ' ' then
            maxX = math.max(maxX, dx)
            self:drawPixel(x + dx, pos.y - charHeight + dy - 1, color)
          end
        end
      end
      x = x + maxX + 1 -- 1 space
      consumedWidth = consumedWidth + 1
    end
  end
  return consumedWidth
end

function LuaPixelBuffer:drawIcon(pos, type, color)
  if type == 'x' then
--[[
x   x
 x x
  X
 x x
x   x
--]]
    self:drawPixel(pos.x-2, pos.y-2, color)
    self:drawPixel(pos.x+2, pos.y-2, color)
    self:drawPixel(pos.x-1, pos.y-1, color)
    self:drawPixel(pos.x+1, pos.y-1, color)
    self:drawPixel(pos.x, pos.y, color)
    self:drawPixel(pos.x-1, pos.y+1, color)
    self:drawPixel(pos.x+1, pos.y+1, color)
    self:drawPixel(pos.x-2, pos.y+2, color)
    self:drawPixel(pos.x+2, pos.y+2, color)
  elseif type == 'o' then
    self:drawCircle(pos, 2, color)
  end
end

function LuaPixelBuffer:drawLine(pos1, pos2, color, lineWidth)
  if lineWidth == nil then lineWidth = 1 end
  lineWidth = math.floor(lineWidth)
  local diffx = pos2.x - pos1.x
  local diffy = pos2.y - pos1.y
  if math.abs(diffx) > math.abs(diffy) then
    local slope = diffy/math.abs(diffx)
    local y = pos1.y
    for x = math.floor(pos1.x), math.floor(pos2.x), pos2.x > pos1.x and 1 or -1 do
      self:drawPoint(x, math.floor(y), color, lineWidth)
      y = y + slope
    end
  else
    local slope = diffx/math.abs(diffy)
    local x = pos1.x
    for y = math.floor(pos1.y), math.floor(pos2.y), pos2.y > pos1.y and 1 or -1 do
      self:drawPoint(math.floor(x), y, color, lineWidth)
      x = x + slope
    end
  end
end

-- require('utils/pixellib').test()
M.test = function()
  local pb = create()
  pb:init(250, 250)
  print(tostring(pb))

  pb:fill(ColorI(255, 255, 255, 255))

  -- test the drawing
  pb:drawIcon(vec3(50, 50, 0), 'x', ColorI(0, 0, 255, 255))
  pb:drawIcon(vec3(60, 50, 0), 'o', ColorI(255, 0, 255, 255))

  pb:drawLine(vec3(-500,-500,0), vec3(500,500,0), ColorI(100, 100, 100, 100), 20)

  pb:getPixel(10, 10)
  pb:drawPoint(10, 10, ColorI(255, 0, 0, 255), 1)
  pb:drawPoint(20, 10, ColorI(255, 0, 0, 255), 2)
  pb:drawPoint(30, 10, ColorI(255, 0, 0, 255), 3)
  pb:drawPoint(40, 10, ColorI(255, 0, 0, 255), 4)
  pb:drawPoint(50, 10, ColorI(255, 0, 0, 255), 5)
  pb:drawPoint(60, 10, ColorI(255, 0, 0, 255), 6)
  pb:drawPoint(70, 10, ColorI(255, 0, 0, 255), 7)
  pb:drawPoint(80, 10, ColorI(255, 0, 0, 255), 8)

  pb:drawFilledRect(vec3(170,50,0), 50, 100, ColorI(255, 255, 0, 255))
  pb:drawRect(vec3(170,50,0), 50, 100, ColorI(150, 150, 0, 255), 5)

  pb:drawLine(vec3(15,15,0), vec3(30,45,0), ColorI(0, 255, 0, 255), 1)
  pb:drawLine(vec3(40,55,0), vec3(25,25,0), ColorI(0, 255, 0, 255), 1)

  pb:drawLine(vec3(30,45,0), vec3(60,18,0), ColorI(255, 0, 0, 255), 2)
  pb:drawLine(vec3(70,28,0), vec3(40,55,0), ColorI(255, 0, 0, 255), 2)

  pb:drawLine(vec3(15,15,0), vec3(60,18,0), ColorI(0, 255, 255, 255), 3)
  pb:drawLine(vec3(70,28,0), vec3(25,25,0), ColorI(0, 255, 255, 255), 3)

  pb:drawFilledCircle(vec3(100,100,0), 50, ColorI(255,0,0,255))
  pb:drawCircle(vec3(100,100,0), 50, ColorI(150,0,0,255), 1)

  pb:drawFilledCircle(vec3(100,100,0), 30, ColorI(0,255,0,255))
  pb:drawCircle(vec3(100,100,0), 30, ColorI(0,150,0,255), 2)

  pb:drawFilledCircle(vec3(100,100,0), 10, ColorI(0,0,255,255))
  pb:drawCircle(vec3(100,100,0), 10, ColorI(0,0,150,255), 3)

  pb:drawText(vec3(0, 200, 0), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', ColorI(0,0,0,255))
  pb:drawText(vec3(0, 210, 0), '1234567890!?\'":,.-_', ColorI(0,0,0,255))
  pb:drawText(vec3(0, 220, 0), "Hello world!", ColorI(0,0,0,255))

  pb:saveFile("helloworld.png")
end



mini_font['A'] = [[
 XX
X  X
XXXX
X  X
X  X]]
mini_font['B'] = [[
XXX
X  X
XXX
X  X
XXX]]
mini_font['C'] = [[
 XX
X  X
X
X  X
 XX]]
mini_font['D'] = [[
XXX
X  X
X  X
X  X
XXX]]
mini_font['E'] = [[
XXX
X
XX
X
XXX]]
mini_font['F'] = [[
XXX
X
XX
X
X]]
mini_font['G'] = [[
 XX
X
X XX
X  X
 XX]]
mini_font['H'] = [[
X  X
X  X
XXXX
X  X
X  X]]
mini_font['I'] = [[
XXX
 X
 X
 X
XXX]]
mini_font['J'] = [[
XXX
 X
 X
 X
X]]
mini_font['K'] = [[
X  X
X X
XX
X X
X  X]]
mini_font['L'] = [[
X
X
X
X
XXX]]
mini_font['M'] = [[
 X X
X X X
X X X
X X X
X X X]]
mini_font['N'] = [[
X  X
XX X
X XX
X  X
X  X]]
mini_font['O'] = [[
 XX
X  X
X  X
X  X
 XX]]
mini_font['P'] = [[
XXX
X  X
XXX
X
X]]
mini_font['Q'] = [[
 XX
X  X
X  X
X X
 XXX]]
mini_font['R'] = [[
XXX
X  X
XXX
X  X
X  X]]
mini_font['S'] = [[
XXX
X
XXX
  X
XXX]]
mini_font['T'] = [[
XXX
 X
 X
 X
 X]]
mini_font['U'] = [[
X X
X X
X X
X X
XXX]]
mini_font['V'] = [[
X X
X X
X X
X X
 X ]]
mini_font['W'] = [[
X X X
X X X
X X X
X X X
 X X]]
mini_font['X'] = [[
X X
X X
 X
X X
X X]]
mini_font['Y'] = [[
X X
X X
 X
 X
 X]]
mini_font['Z'] = [[
XXXX
   X
  X
 X
XXXX]]
mini_font['1'] = [[
 X
XX
 X
 X
XXX]]
mini_font['2'] = [[
XX
  X
 X
X
XXX]]
mini_font['3'] = [[
XXX
  X
XXX
  X
XXX]]
mini_font['4'] = [[
  X
 XX
X X
XXXX
  X]]
mini_font['5'] = [[
XXXX
X
XXX
   X
XXX]]
mini_font['6'] = [[
X
X
XXXX
X  X
XXXX]]
mini_font['7'] = [[
XXXX
   X
   X
   X
   X]]
mini_font['8'] = [[
XXXX
X  X
XXXX
X  X
XXXX]]
mini_font['9'] = [[
XXXX
X  X
XXXX
   X
XXXX]]
mini_font['0'] = [[
XXXX
X  X
X  X
X  X
XXXX]]
mini_font['!'] = [[
X
X
X

X]]
mini_font['?'] = [[
XXX
   X
 XX

 X]]
mini_font['\''] = [[
X
X


]]
mini_font['"'] = [[
X X
X X


]]
mini_font['.'] = [[




X]]
mini_font[','] = [[



X
X]]
mini_font[':'] = [[


X

X]]
mini_font['-'] = [[


XX

]]
mini_font['_'] = [[




XXX]]

M.create = create

return M