-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--[[
Usage:

a = vec3(1,2,3)
b = vec3({1,2,3})
c = vec3({x = 1, y = 2, z = 3})
print(a == b)
print( (a-b) == vec3(0, 0, 0) )
print( (c*1) )
print( vec3(10,0,0):dot(vec3(10,0,0)) )
]]

local min, max, sqrt, abs, random = math.min, math.max, math.sqrt, math.abs, math.random

local newLuaVec3xyz
local LuaVec3 = {}
LuaVec3.__index = LuaVec3

local ffifound, ffi = pcall(require, 'ffi')
if ffifound then
  -- FFI available, so use it
  ffi.cdef [[
    struct __luaVec3_t {double x, y, z;};
    struct __luaQuat_t {double x, y, z, w;};
  ]]
  newLuaVec3xyz = ffi.typeof("struct __luaVec3_t")
  ffi.metatype("struct __luaVec3_t", LuaVec3)
else
  -- no FFI available, compatibility mode
  ffi = nil
  newLuaVec3xyz = function (x, y, z)
    return (setmetatable({x = x, y = y, z = z}, LuaVec3)) -- parenthesis to workaround slowdown from: NYI return to lower frame
  end
end

-- Vector 3d --

function vec3(x, y, z)
  if y == nil then
    if x ~= nil then
      if x.xyz ~= nil then
        return newLuaVec3xyz(x:xyz())
      else
        return newLuaVec3xyz(x.x or x[1], x.y or x[2], x.z or x[3])
      end
    else
      return newLuaVec3xyz(0, 0, 0)
    end
  else
    return newLuaVec3xyz(x, y, z or 0)
  end
end

function LuaVec3:set(x, y, z)
  if y == nil then
    self.x, self.y, self.z = x:xyz()
  else
    self.x, self.y, self.z = x, y, z
  end
end

function LuaVec3:xyz()
  return self.x, self.y, self.z
end

function LuaVec3:fromString(s)
  local x, y, z = s:match('([%d.+eE-]+)[,%s]+([%d.+eE-]+)[,%s]+([%d.+eE-]+)')
  self.x, self.y, self.z = tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
  return self
end

function LuaVec3:__tostring()
  return string.format('vec3(%.9g,%.9g,%.9g)', self.x, self.y, self.z)
end

function LuaVec3:toTable()
  return {self.x, self.y, self.z}
end

function LuaVec3:setFromTable(t)
  self.x, self.y, self.z = t[1], t[2], t[3]
end

function LuaVec3:toDict()
  return {x = self.x, y = self.y, z = self.z}
end

function LuaVec3:length()
  local ax, ay, az = self.x, self.y, self.z
  return sqrt(ax*ax + ay*ay + az*az)
end

function LuaVec3:lengthGuarded()
  local ax, ay, az = self.x, self.y, self.z
  return sqrt(ax*ax + ay*ay + az*az) + 1e-30
end

function LuaVec3:squaredLength()
  local ax, ay, az = self.x, self.y, self.z
  return ax*ax + ay*ay + az*az
end

function LuaVec3.__add(a, b)
  return newLuaVec3xyz(a.x + b.x, a.y + b.y, a.z + b.z)
end

function LuaVec3.__sub(a, b)
  return newLuaVec3xyz(a.x - b.x, a.y - b.y, a.z - b.z)
end

function LuaVec3.__unm(a)
  return newLuaVec3xyz(-a.x, -a.y, -a.z)
end

function LuaVec3.__mul(a, b)
  if type(b) == 'number' then
    return newLuaVec3xyz(b * a.x, b * a.y, b * a.z)
  else
    return newLuaVec3xyz(a * b.x, a * b.y, a * b.z)
  end
end

function LuaVec3.__div(a,b)
  if type(b) == 'number' then
    b = 1 / b
    return newLuaVec3xyz(b * a.x, b * a.y, b * a.z)
  else
    a = 1 / a
    return newLuaVec3xyz(a * b.x, a * b.y, a * b.z)
  end
end

function LuaVec3.__eq(a, b)
  return b ~= nil and a.x == b.x and a.y == b.y and a.z == b.z
end

function LuaVec3:dot(a)
  return self.x * a.x + self.y * a.y + self.z * a.z
end

function LuaVec3:cross(a)
  return newLuaVec3xyz(self.y * a.z - self.z * a.y, self.z * a.x - self.x * a.z, self.x * a.y - self.y * a.x)
end

function LuaVec3:z0()
  return newLuaVec3xyz(self.x, self.y, 0)
end

function LuaVec3:perpendicular()
  local k = abs(self.x) + 0.5
  k = k - math.floor(k)
  return newLuaVec3xyz(-self.y, self.x - k * self.z, k * self.y)
end

function LuaVec3:perpendicularN()
  local p = self:perpendicular()
  local r = 1 / (p:length() + 1e-30)
  p.x, p.y, p.z = p.x * r, p.y * r, p.z * r
  return p
end

function LuaVec3:cosAngle(a)
  return max(min(self:dot(a) / (sqrt(self:squaredLength() * a:squaredLength()) + 1e-30), 1), -1)
end

function LuaVec3:normalize()
  local r = 1 / (self:length() + 1e-30)
  self.x, self.y, self.z = self.x * r, self.y * r, self.z * r
end

function LuaVec3:resize(a)
  local r = a / (self:length() + 1e-30)
  self.x, self.y, self.z = self.x * r, self.y * r, self.z * r
end

function LuaVec3:normalized()
  local r = 1 / (self:length() + 1e-30)
  return newLuaVec3xyz(self.x * r, self.y * r, self.z * r)
end

function LuaVec3:resized(m)
  local r = m / (self:length() + 1e-30)
  return newLuaVec3xyz(self.x * r, self.y * r, self.z * r)
end

function LuaVec3:distance(a)
  local tmp = self.x - a.x
  local d = tmp * tmp
  tmp = self.y - a.y
  d = d + tmp * tmp
  tmp = self.z - a.z
  return sqrt(d + tmp * tmp)
end

function LuaVec3:squaredDistance(a)
  local tmp = self.x - a.x
  local d = tmp * tmp
  tmp = self.y - a.y
  d = d + tmp * tmp
  tmp = self.z - a.z
  return d + tmp * tmp
end

-- a, b are two line points, self is the point
function LuaVec3:distanceToLine(a, b)
  local ab, an = a - b, a - self
  return an:distance(ab * (ab:dot(an) / (ab:squaredLength() + 1e-30)))
end

function LuaVec3:squaredDistanceToLine(a, b)
  local ab, an = a - b, a - self
  return an:squaredDistance(ab * (ab:dot(an) / (ab:squaredLength() + 1e-30)))
end

function LuaVec3:distanceToLineSegment(a, b)
  local ab, an = a - b, a - self
  return an:distance(ab * min(max(ab:dot(an) / (ab:squaredLength() + 1e-30), 0), 1))
end

function LuaVec3:xnormDistanceToLineSegment(a, b)
  local ab, an = a - b, a - self
  local xnorm = ab:dot(an) / (ab:squaredLength() + 1e-30)
  return xnorm, an:distance(ab * min(max(xnorm, 0), 1))
end

function LuaVec3:squaredDistanceToLineSegment(a, b)
  local ab, an = a - b, a - self
  return an:squaredDistance(ab * min(max(ab:dot(an) / (ab:squaredLength() + 1e-30), 0), 1))
end

function LuaVec3:xnormSquaredDistanceToLineSegment(a, b)
  local ab, an = a - b, a - self
  local xnorm = ab:dot(an) / (ab:squaredLength() + 1e-30)
  return xnorm, an:squaredDistance(ab * min(max(xnorm, 0), 1))
end

function LuaVec3:xnormOnLine(a, b)
  local bax, bay, baz = b.x-a.x, b.y-a.y, b.z-a.z
  return (bax*(self.x-a.x) + bay*(self.y-a.y) + baz*(self.z-a.z)) / (bax*bax + bay*bay + baz*baz + 1e-30) -- (b-a):dot(self-a) / (b-a):squaredLength()
end

-- u*a + v*b + (1-u-v)*c
function LuaVec3:triangleBarycentricNorm(a, b, c)
  local ca, bc = c - a, b - c
  local norm = ca:cross(bc)
  local normsqlen = norm:squaredLength() + 1e-30
  local pacnorm = (self - c):cross(norm)
  return bc:dot(pacnorm) / normsqlen, ca:dot(pacnorm) / normsqlen, norm / sqrt(normsqlen)
end

-- backwards compatibility
function LuaVec3:toPoint3F()
  return self
end

-- backwards compatibility
function LuaVec3:toFloat3()
  return self
end

function LuaVec3:projectToOriginPlane(pnorm)
  local t = self.x * pnorm.x + self.y * pnorm.y + self.z * pnorm.z
  return newLuaVec3xyz(self.x - t * pnorm.x, self.y - t * pnorm.y, self.z - t * pnorm.z)
end

-- self is a plane' point
function LuaVec3:xnormPlaneWithLine(pnorm, a, b)
  return (pnorm.x*(self.x-a.x) + pnorm.y*(self.y-a.y) + pnorm.z*(self.z-a.z)) *
          max(min(1 / (pnorm.x*(b.x-a.x) + pnorm.y*(b.y-a.y) + pnorm.z*(b.z-a.z)), 1e300), -1e300) -- pnorm:dot(self-a)/pnorm:dot(b-a)
end

-- self is center of sphere, returns (low, high) xnorms. Returns pair 1,0 if no hit found
function LuaVec3:xnormsSphereWithLine(radius, a, b)
  local lDif, ac = b - a, a - self
  local invDif2len = 1 / max(lDif:squaredLength(), 1e-30)
  local dotab = -ac:dot(lDif) * invDif2len
  local D = dotab * dotab + (radius * radius - ac:squaredLength()) * invDif2len
  if D >= 0 then
    D = sqrt(D)
    return dotab - D, dotab + D
  else
    return 1, 0
  end
end

function LuaVec3:basisCoordinates(c1, c2, c3)
  local c2xc3 = c2:cross(c3)
  local invDet = 1 / c1:dot(c2xc3)
  return newLuaVec3xyz(c2xc3:dot(self)*invDet, c3:cross(c1):dot(self)*invDet, c1:cross(c2):dot(self)*invDet)
end

function LuaVec3:componentMul(b)
  return newLuaVec3xyz(self.x * b.x, self.y * b.y, self.z * b.z)
end

function LuaVec3:setMin(b)
  self.x, self.y, self.z = min(self.x, b.x), min(self.y, b.y), min(self.z, b.z)
end

function LuaVec3:setMax(b)
  self.x, self.y, self.z = max(self.x, b.x), max(self.y, b.y), max(self.z, b.z)
end

function LuaVec3:setAdd(b)
  self.x, self.y, self.z = self.x + b.x, self.y + b.y, self.z + b.z
end

function LuaVec3:setAdd2(a, b)
  self.x, self.y, self.z = a.x + b.x, a.y + b.y, a.z + b.z
end

function LuaVec3:setSub(b)
  self.x, self.y, self.z = self.x - b.x, self.y - b.y, self.z - b.z
end

function LuaVec3:setSub2(a, b)
  self.x, self.y, self.z = a.x - b.x, a.y - b.y, a.z - b.z
end

function LuaVec3:setScaled(b)
  self.x, self.y, self.z = self.x * b, self.y * b, self.z * b
end

function LuaVec3:setScaled2(a, b)
  self.x, self.y, self.z = a.x * b, a.y * b, a.z * b
end

function LuaVec3:setComponentMul(b)
  self.x, self.y, self.z = self.x * b.x, self.y * b.y, self.z * b.z
end

function LuaVec3:setLerp(from, to, t)
  self.x, self.y, self.z = from.x + (to.x - from.x) * t, from.y + (to.y - from.y) * t, from.z + (to.z - from.z) * t  -- monotonic
end

function LuaVec3:setCross(a, b)
  local ax, ay, az = a:xyz()
  local bx, by, bz = b:xyz()
  self.x, self.y, self.z = ay * bz - az * by, az * bx - ax * bz, ax * b.y - ay * bx
end

local function fractPos(x)
  return x - math.floor(x)
end

function LuaVec3:getBlueNoise2d()
  self.x, self.y, self.z = fractPos(self.x + 0.75487766624669276), fractPos(self.y + 0.56984029099805327), 0
  return self
end

function LuaVec3:getBlueNoise3d()
  self.x, self.y, self.z = fractPos(self.x + 0.81917251339616443), fractPos(self.y + 0.6710436067037892084), fractPos(self.z + 0.54970047790197026)
  return self
end

function LuaVec3:getRandomPointInSphere(radius)
  radius = radius or 1
  local sx, sy, sz = 0, 0, 0;
  for i = 1, 4 do
    local x, y, z = random(), random(), random()
    sx, sy, sz = sx + x, sy + y, sz + z
    local xc, yc, zc = x - 0.5, y - 0.5, z - 0.5
    if xc * xc + yc * yc + zc * zc <= 0.25 then
      local r2 = radius * 2
      self.x, self.y, self.z = xc * r2, yc * r2, zc * r2
      return self
    end
  end

  sx, sy, sz = sx - 2, sy - 2, sz - 2
  local u = random()
  local norm = sqrt(0.5 * (sqrt(u) + u)/(sx*sx + sy*sy + sz*sz + 1e-25)) * radius
  self.x, self.y, self.z = sx*norm, sy*norm, sz*norm
  return self
end

function LuaVec3:getRandomPointInCircle(radius)
  radius = radius or 1
  local sx, sy = 0, 0
  for i = 1, 4 do
    local x, y = random(), random()
    sx, sy = sx + x, sy + y
    local xc, yc = x - 0.5, y - 0.5
    if xc * xc + yc * yc <= 0.25 then
      local r2 = radius * 2
      self.x, self.y, self.z = xc * r2, yc * r2, 0
      return self
    end
  end

  sx, sy = sx - 2, sy - 2
  local norm = sqrt(random()/(sx*sx+sy*sy + 1e-25)) * radius
  self.x, self.y, self.z = sx*norm, sy*norm, 0
  return self
end

function LuaVec3:getBluePointInSphere(radius)
  radius = radius or 1
  local bx, by, bz = self.x, self.y, self.z
  for i = 1, 8 do -- seen up to 6
    local x, y, z = fractPos(bx + 0.81917251339616443 * i), fractPos(by + 0.6710436067037892084 * i), fractPos(bz + 0.54970047790197026 * i)
    local xc, yc, zc = x - 0.5, y - 0.5, z - 0.5
    if xc * xc + yc * yc + zc * zc <= 0.25 then
      self.x, self.y, self.z = x, y, z
      local r2 = radius * 2
      return newLuaVec3xyz(xc * r2, yc * r2, zc * r2)
    end
  end
  return newLuaVec3xyz(0, 0, 0)
end

function LuaVec3:getBluePointInCircle(radius)
  radius = radius or 1
  local bx, by = self.x, self.y
  for i = 1, 5 do -- seen up to 3
    local x, y = fractPos(bx + 0.75487766624669276 * i), fractPos(by + 0.56984029099805327 * i)
    local xc, yc = x - 0.5, y - 0.5
    if xc * xc + yc * yc <= 0.25 then
      self.x, self.y = x, y
      local r2 = radius * 2
      return newLuaVec3xyz(xc * r2, yc * r2, 0)
    end
  end
  return newLuaVec3xyz(0, 0, 0)
end

-- backward compatibility
function LuaVec3:getAxis(i)
  return self[string.char(120 + i)]
end

function LuaVec3:setAxis(i, v)
  self[string.char(120 + i)] = v
end

LuaVec3.len = LuaVec3.length
LuaVec3.lenSquared = LuaVec3.squaredLength
LuaVec3.normalizeSafe = LuaVec3.normalize

-- returns random gauss number in [0..3]
function randomGauss3()
  return random() + random() + random()
end

-- returns xnormals for the two lines: http://geomalgorithms.com/a07-_distance.html
function closestLinePoints(l1p0, l1p1, l2p0, l2p1)
  local u, v = l1p1 - l1p0, l2p1 - l2p0
  local a, b, c = u:squaredLength(), u:dot(v), v:squaredLength()
  local D = a * c - b * b
  local w = l1p0 - l2p0
  local d, e = u:dot(w), v:dot(w)

  if D < 1e-8 then
    return 0, b > c and d / b or e / (c + 1e-30)
  else
    return (b*e - c*d) / D, (a*e - b*d) / D
  end
end

function linePointFromXnorm(p0, p1, xnorm)
  return newLuaVec3xyz(p0.x + (p1.x-p0.x) * xnorm, p0.y + (p1.y-p0.y) * xnorm, p0.z + (p1.z-p0.z) * xnorm)
end

-- Stack vec3 --

local StackVec3 = {}
StackVec3.__index = StackVec3
local stackv3 = setmetatable({}, StackVec3)
local stacki = 1

function push3(x, y, z)
  if y == nil then
    stackv3[stacki], stackv3[stacki+1], stackv3[stacki+2] = x.x, x.y, x.z
  else
    stackv3[stacki], stackv3[stacki+1], stackv3[stacki+2] = x, y, z
  end
  stacki = stacki + 3
  return stackv3
end

function StackVec3:xyz()
  stacki = stacki - 3
  return stackv3[stacki], stackv3[stacki+1], stackv3[stacki+2]
end

function StackVec3:__tostring()
  stacki = stacki - 3
  return string.format('stack3(%.9g,%.9g,%.9g)', stackv3[stacki], stackv3[stacki+1], stackv3[stacki+2])
end

function StackVec3.__add(a, b)
  local bx, by, bz = b:xyz()
  stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1] = stackv3[stacki-3] + bx, stackv3[stacki-2] + by, stackv3[stacki-1] + bz
  return stackv3
end

function StackVec3.__sub(a, b)
  local bx, by, bz = b:xyz()
  stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1] = stackv3[stacki-3] - bx, stackv3[stacki-2] - by, stackv3[stacki-1] - bz
  return stackv3
end

function StackVec3.__unm(a)
  stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1] = -stackv3[stacki-3], -stackv3[stacki-2], -stackv3[stacki-1]
  return stackv3
end

function StackVec3.__mul(a, b)
  b = type(a) == 'number' and a or b
  stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1] = stackv3[stacki-3]*b, stackv3[stacki-2]*b, stackv3[stacki - 1]*b
  return stackv3
end

function StackVec3.__div(a, b)
  b = type(a) == 'number' and 1 / a or 1 / b
  stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1] = stackv3[stacki-3]*b, -stackv3[stacki-2]*b, -stackv3[stacki - 1]*b
  return stackv3
end

function StackVec3:dot(a)
  local ax, ay, az = a:xyz()
  stacki = stacki - 3
  return stackv3[stacki] * ax + stackv3[stacki+1] * ay + stackv3[stacki+2] * az
end

function StackVec3:cross(b)
  local bx, by, bz = b:xyz()
  local ax, ay, az = stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1]
  stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1] = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
  return stackv3
end

function StackVec3:z0()
  stackv3[stacki-1] = 0
  return stackv3
end

function StackVec3:length()
  stacki = stacki - 3
  local ax, ay, az = stackv3[stacki], stackv3[stacki+1], stackv3[stacki+2]
  return sqrt(ax*ax + ay*ay + az*az)
end

function StackVec3:squaredLength()
  stacki = stacki - 3
  local ax, ay, az = stackv3[stacki], stackv3[stacki+1], stackv3[stacki+2]
  return ax*ax + ay*ay + az*az
end

function StackVec3:normalized()
  local ax, ay, az = stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1]
  local r = 1 / (sqrt(ax*ax + ay*ay + az*az) + 1e-30)
  stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1] = stackv3[stacki-3] * r, stackv3[stacki-2] * r, stackv3[stacki-1] * r
  return stackv3
end

function StackVec3:resized(m)
  local ax, ay, az = stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1]
  local r = m / (sqrt(ax*ax + ay*ay + az*az) + 1e-30)
  stackv3[stacki-3], stackv3[stacki-2], stackv3[stacki-1] = stackv3[stacki-3] * r, stackv3[stacki-2] * r, stackv3[stacki-1] * r
  return stackv3
end

function StackVec3:distance(a)
  local ax, ay, az = a:xyz()
  stacki = stacki - 3
  local tmp = stackv3[stacki] - ax
  local d = tmp * tmp
  tmp = stackv3[stacki+1] - ay
  d = d + tmp * tmp
  tmp = stackv3[stacki+2] - az
  return sqrt(d + tmp * tmp)
end

function StackVec3:squaredDistance(a)
  local ax, ay, az = a:xyz()
  stacki = stacki - 3
  local tmp = stackv3[stacki] - ax
  local d = tmp * tmp
  tmp = stackv3[stacki+1] - ay
  d = d + tmp * tmp
  tmp = stackv3[stacki+2] - az
  return d + tmp * tmp
end

-- Quaternion --

local LuaQuat = {}
LuaQuat.__index = LuaQuat
local newLuaQuatxyzw

if ffi then
  newLuaQuatxyzw = ffi.typeof("struct __luaQuat_t")
  ffi.metatype("struct __luaQuat_t", LuaQuat)
else
  newLuaQuatxyzw = function (_x, _y, _z, _w)
    return (setmetatable({ x = _x, y = _y, z = _z, w = _w }, LuaQuat)) -- parenthesis needed to workaround extreme slowdown from: NYI return to lower frame
  end
end

-- Returns quat. Both inputs should be normalized
function LuaVec3:getRotationTo(v)
  local w = 1 + self:dot(v)
  local qv

  if (w < 1e-6) then
    w = 0
    qv = v:perpendicular()
  else
    qv = self:cross(v)
  end
  local q = newLuaQuatxyzw(qv.x, qv.y, qv.z, -w)
  q:normalize()
  return q
end

-- Rotates by quaternion q (-w)
function LuaVec3:rotated(q)
  local qv = newLuaVec3xyz(q.x, q.y, q.z)
  local t = 2 * qv:cross(self)
  return self - q.w * t + qv:cross(t)
end

-- T3d's quats use -w
function quat(x, y, z, w)
  if y == nil then
    if type(x) == 'table' and x[4] ~= nil then
      return newLuaQuatxyzw(x[1], x[2], x[3], x[4])
    elseif x == nil then
      return newLuaQuatxyzw(1, 0, 0, 0)
    else
      return newLuaQuatxyzw(x.x, x.y, x.z, x.w)
    end
  else
    return newLuaQuatxyzw(x, y, z, w)
  end
end

function LuaQuat:__tostring()
  return string.format('quat(%.9g,%.9g,%.9g,%.9g)', self.x, self.y, self.z, self.w)
end

function LuaQuat:toTable()
  return {self.x, self.y, self.z, self.w}
end

function LuaQuat:toDict()
  return {x = self.x, y = self.y, z = self.z, w = self.w}
end

function LuaQuat:set(x, y, z, w)
  if y == nil then
    self.x, self.y, self.z, self.w = x.x, x.y, x.z, x.w
  else
    self.x, self.y, self.z, self.w = x, y, z, w
  end
end

function LuaQuat:norm()
  return sqrt(self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w)
end

function LuaQuat:squaredNorm()
  return self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w
end

function LuaQuat:normalize()
  local r = 1/(self:norm() + 1e-30)
  self.x, self.y, self.z, self.w = self.x * r, self.y * r, self.z * r, self.w * r
end

function LuaQuat:normalized()
  local r = 1/(self:norm() + 1e-30)
  return newLuaQuatxyzw(self.x * r, self.y * r, self.z * r, self.w * r)
end

function LuaQuat:inversed()
  local InvSqNorm = -1 / (self:squaredNorm() + 1e-30)
  return newLuaQuatxyzw(self.x * InvSqNorm, self.y * InvSqNorm, self.z * InvSqNorm, -self.w * InvSqNorm)
end

function LuaQuat.__unm(a)
  return newLuaQuatxyzw(-a.x, -a.y, -a.z, -a.w)
end

function LuaQuat.__mul(a, b)
  if type(a) == 'number' then
    return newLuaQuatxyzw(b.x * a, b.y * a, b.z * a, b.w * a)
  elseif type(b) == 'number' then
    return newLuaQuatxyzw(a.x * b, a.y * b, a.z * b, a.w * b)
  elseif (ffi and ffi.istype('struct __luaVec3_t', b)) or b.w == nil then
    local qv = newLuaVec3xyz(a.x, a.y, a.z)
    local t = qv:cross(b)
    t:setScaled(2)
    local res = qv:cross(t)
    res:setAdd(b)
    t:setScaled(a.w)
    res:setSub(t)
    return res -- b - a.w * t + qv:cross(t)
  else
    return newLuaQuatxyzw(a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                a.w * b.y + a.y * b.w + a.z * b.x - a.x * b.z,
                a.w * b.z + a.z * b.w + a.x * b.y - a.y * b.x,
                a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)
  end
end

function LuaQuat.__sub(a, b)
  return newLuaQuatxyzw(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w)
end

function LuaQuat.__div(a, b)
  if type(a) == 'number' then
    return newLuaQuatxyzw(b.x / a, b.y / a, b.z / a, b.w / a)
  elseif type(b) == 'number' then
    return newLuaQuatxyzw(a.x / b, a.y / b, a.z / b, a.w / b)
  end
  return a * b:inversed()
end

function LuaQuat.__add(a, b)
  return newLuaQuatxyzw(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w)
end

function LuaQuat:dot(a)
  return self.x * a.x + self.y * a.y + self.z * a.z + self.w * a.w
end

function LuaQuat:distance(a)
  return 0.5 * (self - a):squaredNorm()
end

function LuaQuat:nlerp(a, t)
  local tmp = (1 - t) * self + (self:dot(a) < 0 and -t or t) * a
  tmp:normalize()
  return tmp
end

function LuaQuat:slerp(a, t)
  local dot = clamp(self:dot(a), -1, 1)

  if dot > 0.9995 then
    return self:nlerp(a, t)
  end

  local theta = math.acos(dot)*t
  return (self*math.cos(theta) + (a - self*dot):normalized()*math.sin(theta)):normalized();
end

-- returns reverse rotation
function LuaQuat:conjugated()
  return newLuaQuatxyzw(-self.x, -self.y, -self.z, self.w)
end

function LuaQuat:scale(a)
  self.x, self.y, self.z, self.w = self.x * a, self.y * a, self.z * a, self.w * a
  return self
end

--http://bediyap.com/programming/convert-quaternion-to-euler-rotations/
function LuaQuat.toEulerYXZ(q)
  local wxsq = q.w*q.w-q.x*q.x
  local yzsq = q.z*q.z-q.y*q.y
  return newLuaVec3xyz(
    math.atan2(2*(q.x*q.y + q.w*q.z), wxsq-yzsq),
    math.asin(max(min(-2*(q.y*q.z - q.w*q.x), 1), -1)),
    math.atan2(2*(q.x*q.z + q.w*q.y), wxsq+yzsq))
end

function LuaQuat:toTorqueQuat()
  local sinhalf = math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
  local tw = math.acos(self.w) * 360 / math.pi
  if sinhalf ~= 0 then
    return {x = self.x / sinhalf, y = self.y / sinhalf, z = self.z / sinhalf, w = tw}
  else
    return {x = 1, y = 0, z = 0, w = tw}
  end
end

function LuaQuat:toDirUp()
  return self * vec3(0,1,0), self * vec3(0,0,1)
end

-- function LuaQuat:pow(a)
--   self:scale(a)
--   local vlen = sqrt( self.x*self.x + self.y*self.y + self.z*self.z )
--   local ret = math.exp(self.w)
--   local coef = ret * math.sin(vlen) / (vlen + 1e-60)

--   return newLuaQuatxyzw( coef*self.x, coef*self.y, coef*self.z, -ret* math.cos(vlen) )
-- end

local q = {}
local function quatFromAxesMatrix(m)
  q[0], q[1], q[2], q[3] = 0, 0, 0, 0
  local trace = m[0][0] + m[1][1] + m[2][2]
  if trace > 0 then
    local s = sqrt(trace + 1)
    q[3] = s * 0.5
    s = 0.5 / s
    q[0] = (m[1][2] - m[2][1]) * s
    q[1] = (m[2][0] - m[0][2]) * s
    q[2] = (m[0][1] - m[1][0]) * s
  else
    local i = 0
    if m[1][1] > m[0][0] then i = 1 end
    if m[2][2] > m[i][i] then i = 2 end
    local j = (i + 1) % 3
    local k = (j + 1) % 3

    local s = sqrt((m[i][i] - (m[j][j] + m[k][k])) + 1)
    q[i] = s * 0.5
    s = 0.5 / s
    q[j] = (m[i][j] + m[j][i]) * s
    q[k] = (m[i][k] + m[k][i]) * s
    q[3] = (m[j][k] - m[k][j]) * s
  end

  local tmp = newLuaQuatxyzw(q[0], q[1], q[2], q[3])
  tmp:normalize()
  return tmp
end

local globalUp = vec3(0, 0, 1)
local dirNorm, i, k = vec3(), vec3(), vec3()
local matTable = {[0]={}, {}, {}}
function quatFromDir(dir, up)
  k:set(up or globalUp)
  dirNorm:set(dir)
  dirNorm:normalize()
  if abs(dirNorm:dot(k)) > 0.9999 then
    dirNorm:set((push3(dirNorm) + dirNorm:perpendicularN() * 1e-5):normalized())
  end

  i:setCross(dirNorm, k)
  i:normalize()
  k:setCross(i, dirNorm)
  k:normalize()
  matTable[0][0], matTable[0][1], matTable[0][2] = i.x, dirNorm.x, k.x
  matTable[1][0], matTable[1][1], matTable[1][2] = i.y, dirNorm.y, k.y
  matTable[2][0], matTable[2][1], matTable[2][2] = i.z, dirNorm.z, k.z
  return quatFromAxesMatrix(matTable)
end

function lookAt(lookAt, up)
  up = up or vec3(0, 0, 1)
  local forward = lookAt:normalized()
  local right = forward:cross(up)
  right:normalize()
  up = right:cross(forward)
  up:normalize()

  local w = sqrt(1 + right.x + up.y + forward.z) * 0.5
  local w4_recip = 1 / (4 * w)
  local x = (forward.y - up.z) * w4_recip
  local y = (right.z - forward.x) * w4_recip
  local z = (up.x - right.y) * w4_recip
  return newLuaQuatxyzw(x,y,z,w)
end

function quatFromAxisAngle(axle, angleRad)
  angleRad = angleRad * 0.5
  local fsin = math.sin(angleRad)
  return newLuaQuatxyzw(fsin * axle.x, fsin * axle.y, fsin * axle.z, math.cos(angleRad))
end

function quatFromEuler(x, y, z)
  x, y, z = x * 0.5, y * 0.5, z * 0.5
  local sx, cx, sy, cy, sz, cz  = math.sin(x), math.cos(x), math.sin(y), math.cos(y), math.sin(z), math.cos(z)
  local cycz, sysz, sycz, cysz = cy*cz, sy*sz, sy*cz, cy*sz
  return newLuaQuatxyzw(cycz*sx + sysz*cx, sycz*cx + cysz*sx, cysz*cx - sycz*sx, cycz*cx - sysz*sx)
end

-- returns -1, 1
function sign2(x)
  return max(min(x * math.huge, 1), -1)
end

-- returns -1, 0, 1
function sign(x)
  return max(min((x * 1e200) * 1e200, 1), -1)
end

fsign = sign

-- returns sign(s) * abs(v)
function signApply(s, v)
  local absv = abs(v)
  return max(min((s * 1e200) * 1e200, absv), -absv)
end

function guardZero(x) --branchless
  return 1 / max(min(1/x, 1e300), -1e300)
end

function clamp(x, minValue, maxValue )
  return min(max(x, minValue), maxValue)
end

function square(a)
  return a * a
end

function round(a)
  return math.floor(a+.5)
end

function isnan(a)
  return not(a == a)
end

function isinf(a)
  return abs(a) == math.huge
end

function isnaninf(a)
  return a * 0 ~= 0
end

function linearScale(v, minValue, maxValue, minOutput, maxOutput)
  return minOutput + min(max((v - minValue) / (maxValue - minValue), 0), 1) * (maxOutput - minOutput)
end

function lerp(from, to, t)
  return from + (to - from) * t  -- monotonic
end

function inverseLerp(from, to, value)
  local dif = to - from
  return abs(dif) > 1e-60 and (value - from) / dif or 0
 end

function smoothstep(x)
  x = min(max(x, 0), 1) -- monotonic guard
  return x*x*(3 - 2*x)
end

function smootherstep(x)
  return min(max(x*x*x*(x*(x*6 - 15) + 10), 0), 1)
end

function smootheststep(x)
  x = min(max(x, 0), 1)
  return square(x*x)*(35-x*(x*(x*20-70)+84))
end

function smoothmin(a, b, k)
    k = k or 0.1
    local h = min(max(0.5 + 0.5*(b-a)/k, 0), 1)
    return a*h - (b - k*h)*(1-h)
end

function biasFun(x, k)
  local xk = x * k
  return (x + xk)/(1 + xk)
end

-- https://arxiv.org/pdf/2010.09714.pdf
function biasGainFun(x, t, s)
  t, s = t or 0.5, s or 0.25
  if x < t then
    return t * x/(x + s*(t - x) + 1e-20)
  else
    local x1 = 1-x
    return 1 - (1-t)*x1/(x1 - s*(t - x) + 1e-20)
  end
end

-- symmetric around 0
function sigmoid1(x, a)
  return x/((a or 1) + abs(x))
end

function bumpFun(x, peakLeftX, peakRightX, leftSlope, rightSlope, leftY, peakY, rightY, roundness)
  leftY, peakY, roundness = leftY or 0, peakY or 1, roundness or 10
  return leftY+0.5*((peakY-leftY)*(1 + sigmoid1(roundness*(x-peakLeftX), (leftSlope or 1))) +
    ((rightY or 0)-peakY)*(1+sigmoid1(roundness*(x-peakRightX), (rightSlope or 1))))
end

function nanError(x)
  if x ~= x then
    error('NaN found')
  end
  return x
end

function axisSystemCreate(nx, ny, nz)
  local rx, ry, rz = vec3(), vec3(), vec3()

  local row = ny:cross(nz)
  local invdet = 1 / nx:dot(row)
  row = row * invdet
  rx.x, ry.x, rz.x = row.x, row.y, row.z

  row = nz:cross(nx) * invdet
  rx.y, ry.y, rz.y = row.x, row.y, row.z

  row = nx:cross(ny) * invdet
  rx.z, ry.z, rz.z = row.x, row.y, row.z
  return rx, ry, rz
end

function axisSystemApply(nx, ny, nz, v)
  return nx * v.x + ny * v.y + nz * v.z
end

function cardinalSpline(p0, p1, p2, p3, t, s, d1, d2, d3)
  d1, d2, d3 = max(d1 or 1, 1e-30), d2 or 1, max(d3 or 1, 1e-30)
  s = (s or 0.5) * 2
  local sd2 = s  * d2
  local tt, t_1 = t * t, t-1
  local t_1sq = t_1 * t_1

  local m1 =  (p1 - p0) / d1 + (p0 - p2) / (d1 + d2)
  local m2 =  (p1 - p3) / (d2 + d3) + (p3 - p2) / d3

  return t*t_1sq*sd2*m1 + tt*t_1*sd2*m2 + t_1sq * (2 * t + 1) * p1 - tt * (2*t-3) * p2 + s*t_1*(t*t_1 + tt) * (p2 - p1)
end

function catmullRom(p0, p1, p2, p3, t, s)
  return cardinalSpline(p0, p1, p2, p3, t, s or 0.5, 1, 1, 1)
end

function catmullRomChordal(p0, p1, p2, p3, t, s)
  return cardinalSpline(p0, p1, p2, p3, t, s or 0.5, p0:distance(p1), p1:distance(p2), p2:distance(p3))
end

function catmullRomCentripetal(p0, p1, p2, p3, t, s)
  return cardinalSpline(p0, p1, p2, p3, t, s or 0.5, sqrt(p0:distance(p1)), sqrt(p1:distance(p2)), sqrt(p2:distance(p3)))
end

function monotonicSteffen(y0, y1, y2, y3, x0, x1, x2, x3, x)
  local x1x0, x2x1, x3x2 = x1-x0, x2-x1, x3-x2
  local delta0, delta1, delta2 = (y1-y0) / (x1x0 + 1e-30), (y2-y1) / (x2x1 + 1e-30), (y3-y2) / (x3x2 + 1e-30)
  local m1 = (sign(delta0)+sign(delta1)) * min(abs(delta0),abs(delta1), 0.5*abs((x2x1*delta0 + x1x0*delta1) / (x2-x0 + 1e-30)))
  local m2 = (sign(delta1)+sign(delta2)) * min(abs(delta1),abs(delta2), 0.5*abs((x3x2*delta1 + x2x1*delta2) / (x3-x1 + 1e-30)))
  local xx1 = x - x1
  local xrel = xx1 / max(x2x1, 1e-30)
  return y1 + xx1*(m1 + xrel*(delta1 - m1 + (xrel - 1)*(m1 + m2 - 2*delta1)))
end

function biQuadratic(p0, p1, p2, p3, t)
  local p12 =  p1 + (p2 - p1) * (t * 0.5 + 0.25)
  if t <= 0.5 then
    local p01 = p0 + (p1 - p0) * (t * 0.5 + 0.75)
    return p01 + (p12 - p01) * (t + 0.5)
  else
    return p12 + (p2 + (p3 - p2) * (t * 0.5 - 0.25) - p12) * (t - 0.5)
  end
end

function overlapsOBB_OBB(c1, x1, y1, z1, c2, x2, y2, z2)
  local cc = c1 - c2
  local d11, d12, d13 = abs(x1:dot(x2)), abs(x1:dot(y2)), abs(x1:dot(z2))
  local d21, d22, d23 = abs(y1:dot(x2)), abs(y1:dot(y2)), abs(y1:dot(z2))
  local d31, d32, d33 = abs(z1:dot(x2)), abs(z1:dot(y2)), abs(z1:dot(z2))

  return abs(cc:dot(x1))-d11-d12-d13<=x1:squaredLength() and abs(cc:dot(y1))-d21-d22-d23<=y1:squaredLength()
     and abs(cc:dot(z1))-d31-d32-d33<=z1:squaredLength() and abs(cc:dot(x2))-d11-d21-d31<=x2:squaredLength()
     and abs(cc:dot(y2))-d12-d22-d32<=y2:squaredLength() and abs(cc:dot(z2))-d13-d23-d33<=z2:squaredLength()
end

-- untested
function containsOBB_OBB(c1, x1, y1, z1, c2, x2, y2, z2)
  local cc = c1 - c2
  return abs(cc:dot(x1))+abs(x1:dot(x2))+abs(x1:dot(y2))+abs(x1:dot(z2))<=x1:squaredLength()
     and abs(cc:dot(y1))+abs(y1:dot(x2))+abs(y1:dot(y2))+abs(y1:dot(z2))<=y1:squaredLength()
     and abs(cc:dot(z1))+abs(z1:dot(x2))+abs(z1:dot(y2))+abs(z1:dot(z2))<=z1:squaredLength()
end

function overlapsOBB_Sphere(c1, x1, y1, z1, c2, r2)
  local cc = c1 - c2
  local x1len, y1len, z1len = x1:length(), y1:length(), z1:length()
  local ccx, ccy, ccz = abs(cc:dot(x1)), abs(cc:dot(y1)), abs(cc:dot(z1))

  return ccx<=x1len*(x1len+r2) and ccy<=y1len*(y1len+r2) and ccz<=z1len*(z1len+r2)
    and (ccx<=x1len*x1len or ccy<=y1len*y1len or ccz<=z1len*z1len or
      square(ccx/(x1len+1e-30)-x1len)+square(ccy/(y1len+1e-30)-y1len)+square(ccz/(z1len+1e-30)-z1len)<=r2*r2)
end

function overlapsOBB_Plane(c1, x1, y1, z1, plpos, pln)
  return abs((c1 - plpos):dot(pln))<=abs(x1:dot(pln))+abs(y1:dot(pln))+abs(z1:dot(pln))
end

function containsOBB_Sphere(c1, x1, y1, z1, c2, r2)
  local cc = c1 - c2
  local x1len, y1len, z1len = x1:length(), y1:length(), z1:length()
  return abs(cc:dot(x1))<=x1len*(x1len-r2) and abs(cc:dot(y1))<=y1len*(y1len-r2) and abs(cc:dot(z1))<=z1len*(z1len-r2)
end

function containsSphere_OBB(c1, r1, c2, x2, y2, z2)
  local cc = c1 - c2
  local ccx1, cc_x2, y2z2, y2_z2 = cc+x2, cc-x2, y2+z2, y2-z2
  return max((ccx1+y2z2):squaredLength(), (ccx1+y2_z2):squaredLength(), (ccx1-y2_z2):squaredLength(), (ccx1-y2z2):squaredLength(),
      (cc_x2+y2z2):squaredLength(), (cc_x2+y2_z2):squaredLength(), (cc_x2-y2_z2):squaredLength(), (cc_x2-y2z2):squaredLength())<=r1*r1
end

function containsOBB_point(c1, x1, y1, z1, p)
  local cc = c1 - p
  return abs(cc:dot(x1))<=x1:squaredLength() and abs(cc:dot(y1))<=y1:squaredLength() and abs(cc:dot(z1))<=z1:squaredLength()
end

function containsEllipsoid_Point(c1, x1, y1, z1, p)
  local cc = p - c1
  local x, y, z = cc:dot(x1), cc:dot(y1), cc:dot(z1)
  local a2, b2, c2 = x1:squaredLength(), y1:squaredLength(), z1:squaredLength()
  a2, b2, c2 = a2*a2, b2*b2, c2*c2
  local b2c2 = b2*c2
  return x*x*b2c2 + a2*(y*y*c2 + z*z*b2) <= a2*b2c2
end

function constainsCylinder_Point(cposa, cposb, cR, p)
  local xnorm, r2 = p:xnormSquaredDistanceToLineSegment(cposa, cposb)
  return xnorm >=0 and xnorm <= 1 and r2 <= cR*cR
end

function altitudeOBB_Plane(c1, x1, y1, z1, plpos, pln)
  return (c1 - plpos):dot(pln)+abs(x1:dot(pln))+abs(y1:dot(pln))+abs(z1:dot(pln))
end

-- returns signed distance of plane on the ray
function intersectsRay_Plane(rpos, rdir, plpos, pln)
  return min((plpos - rpos):dot(pln) / rdir:dot(pln), math.huge)
end

-- hit: minhit < maxhit, inside: minhit < 0
function intersectsRay_OBB(rpos, rdir, c1, x1, y1, z1)
  local rposc1 = c1 - rpos
  local rposc1x1, x1sq, invrdirx1 = rposc1:dot(x1), x1:squaredLength(), 1 / rdir:dot(x1)
  local dx1, dx2 = (rposc1x1 - x1sq) * invrdirx1, min((rposc1x1 + x1sq) * invrdirx1, math.huge)
  local rposc1y1, y1sq, invrdiry1 = rposc1:dot(y1), y1:squaredLength(), 1 / rdir:dot(y1)
  local dy1, dy2 = (rposc1y1 - y1sq) * invrdiry1, min((rposc1y1 + y1sq) * invrdiry1, math.huge)
  local rposc1z1, z1sq, invrdirz1 = rposc1:dot(z1), z1:squaredLength(), 1 / rdir:dot(z1)
  local dz1, dz2 = (rposc1z1 - z1sq) * invrdirz1, min((rposc1z1 + z1sq) * invrdirz1, math.huge)

  local minhit, maxhit = max(min(dx1, dx2), min(dy1, dy2), min(dz1, dz2)), min(max(dx1, dx2), max(dy1, dy2), max(dz1, dz2))
  return (minhit <= maxhit and minhit or math.huge), maxhit
end

function intersectsRay_Sphere(rpos, rdir, cpos, cr)
  local rcpos = cpos - rpos
  local dcr = rdir:dot(rcpos)
  local s = dcr*dcr - rcpos:squaredLength() + cr*cr
  if s < 0 then return math.huge, math.huge end
  s = sqrt(s)
  return dcr - s, dcr + s
end

function intersectsRay_Ellipsoid(rpos, rdir, c1, x1, y1, z1)
  local invx1, invy1, invz1 = 1 / (x1:squaredLength() + 1e-30), 1 / (y1:squaredLength() + 1e-30), 1 / (z1:squaredLength() + 1e-30)
  local cc = rpos - c1
  local pM = vec3(cc:dot(x1)*invx1, cc:dot(y1)*invy1, cc:dot(z1)*invz1)
  local dirM = vec3(rdir:dot(x1)*invx1, rdir:dot(y1)*invy1, rdir:dot(z1)*invz1)

  local a, b, c = dirM:squaredLength(), 2*pM:dot(dirM), pM:squaredLength() - 1
  local d = b*b - 4*a*c
  if d < 0 then return math.huge, math.huge end
  d = -b -sign(b)*sqrt(d)
  local r1, r2 = 0.5*d / a, 2*c / d
  return min(r1, r2), max(r1,r2)
end

function intersectsRay_Cylinder(rpos, rdir, cposa, cposb, cR)
  local rca, cba = cposa - rpos, cposb - cposa
  local cpnorm = cba:normalized()
  local cp = rca:projectToOriginPlane(cpnorm)
  local rdp = rdir:projectToOriginPlane(cpnorm)
  local minhit, maxhit = intersectsRay_Sphere(vec3(0,0,0), rdp:normalized(), cp, cR)
  local invrdplen = 1 / (rdp:length() + 1e-30)
  minhit, maxhit = minhit * invrdplen, maxhit * invrdplen
  local plhita, plhitb = intersectsRay_Plane(rpos, rdir, cposa, cpnorm), intersectsRay_Plane(rpos, rdir, cposb, cpnorm)
  minhit, maxhit = max(minhit, min(plhita, plhitb)), min(maxhit, max(plhita, plhitb))
  return (minhit <= maxhit and minhit or math.huge), maxhit
end

-- returns hit distance, barycentric x, y
function intersectsRay_Triangle(rpos, rdir, a, b, c)
  local ca, bc = c - a, b - c
  local norm = ca:cross(bc)
  local rposc = rpos - c
  local pOnTri = rposc:dot(norm) / rdir:dot(norm)
  if pOnTri <= 0 then
    local pacnorm = (rposc - rdir * pOnTri):cross(norm)
    local bx, by = bc:dot(pacnorm), ca:dot(pacnorm)
    if min(bx, by) >= 0 then
      local normSq = norm:squaredLength() + 1e-30
      if bx + by <= normSq then
        return -pOnTri, bx / normSq, by / normSq
      end
    end
  end
  return math.huge, -1, -1
end