-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init(sites, name, forceId)
  self.sites = sites
  self.id = forceId or (sites and sites:getNextUniqueIdentifier()) or -1
  self.name = name or "Zone " .. self.id
  self.color = vec3(1,1,1)
  self.vertices = {}
  self.center = vec3(0,0,0)
  self.labelPos = vec3(0,0,-math.huge)
  self._drawMode = 'faded'
  self.sortOrder = 999999
  self.customFields = require('/lua/ge/extensions/gameplay/sites/customFields')()
  self.aabb = {xMin = -math.huge, xMax = math.huge, yMin = -math.huge, yMax = math.huge, zMin = -math.huge, zMax = math.huge, invalid = true}
  self.top = {pos = vec3(0,0,10), normal = vec3(0,0,1), active = false}
  self.bot = {pos = vec3(0,0,-10), normal = vec3(0,0,-1), active = false}
end

function C:onSerialize()
  local verts = {}
  for i, v in ipairs(self.vertices) do
    table.insert(verts,v.pos:toTable())
  end
  local ret = {
    name = self.name,
    vertices = verts,
    color = self.color:toTable(),
    oldId = self.id,
    customFields = self.customFields:onSerialize(),
    top = {
      active = self.top.active,
      pos = self.top.pos:toTable(),
      normal = self.top.normal:toTable()
    },
    bot = {
      active = self.bot.active,
      pos = self.bot.pos:toTable(),
      normal = self.bot.normal:toTable()
    }

  }
  return ret
end

function C:onDeserialized(data)
  self.name = data.name
  self.color = vec3(data.color)
  self.vertices = {}
  for i, v in ipairs(data.vertices) do
    table.insert(self.vertices,{pos = vec3(v)})
  end
  self.customFields:onDeserialized(data.customFields)
  if data.top then
    self.top.pos = vec3(data.top.pos)
    self.top.normal = vec3(data.top.normal)
    self.top.active = data.top.active or false
  end
  if data.bot then
    self.bot.pos = vec3(data.bot.pos)
    self.bot.normal = vec3(data.bot.normal)
    self.bot.active = data.bot.active or false
  end
  self:processVertices()
end

function C:addVertex(pos, index)
  table.insert(self.vertices,index or (#self.vertices+1),{pos = vec3(pos), radius = 5})
  self:processVertices()
end

function C:removeVertex(index)
  table.remove(self.vertices,index)
  self:processVertices()
end

-- this does some precomputations.
function C:processVertices()
  self.center = vec3(0,0,-100000)
  self.labelPos = vec3(0,0,-math.huge)
  self.aabb = {
    xMin = math.huge, xMax = -math.huge,
    yMin = math.huge, yMax = -math.huge,
    zMin = math.huge, zMax = -math.huge,
    invalid = false}
  self.vertexCount = #self.vertices
  if #self.vertices == 0 then
    self.aabb.invalid = true
    return
  end
  for i, v in ipairs(self.vertices) do
    v.index = i
    v.radius = 5
    self.aabb.xMin = math.min(self.aabb.xMin, v.pos.x)
    self.aabb.xMax = math.max(self.aabb.xMax, v.pos.x)
    self.aabb.yMin = math.min(self.aabb.yMin, v.pos.y)
    self.aabb.yMax = math.max(self.aabb.yMax, v.pos.y)
    self.aabb.zMin = math.min(self.aabb.zMin, v.pos.z)
    self.aabb.zMax = math.max(self.aabb.zMax, v.pos.z)
  end
  self.center.x = (self.aabb.xMin + self.aabb.xMax) / 2
  self.center.y = (self.aabb.yMin + self.aabb.yMax) / 2
  self.center.z = (self.aabb.zMin + self.aabb.zMax) / 2

  self.labelPos = vec3(self.center)
  self.labelPos.z = self.aabb.zMax + 5


  for i = 1, #self.vertices-1 do
    self.vertices[i].next = i+1
    self.vertices[i+1].prev = i
  end
  if self.top.active or self.bot.active then
    for i, v in ipairs(self.vertices) do
      -- expand AABB by planes.
      self.aabb.zMax = math.max(self.aabb.zMax, self:vertexPlaneIntersection(v.pos,self.top).z)
      self.aabb.zMin = math.min(self.aabb.zMin, self:vertexPlaneIntersection(v.pos,self.bot).z)
    end
  end
  if not self.top.active then self.aabb.zMax = math.huge end
  if not self.bot.active then self.aabb.zMin = -math.huge end
  self.vertices[1].prev = #self.vertices
  self.vertices[#self.vertices].next = 1
end

function C:changedPlanes()
  self:processVertices()
end

-- test if both planes are valid. normals of the planes have to point up/down respectively.
function C:validPlanes()
  return self.top.active and self.top.normal:dot(vec3(0,0, 1)) > 0
     and self.bot.active and self.bot.normal:dot(vec3(0,0,-1)) > 0
end

-- creates some automatically gnrated planes 5m above/below the highest/lowest vertex, aligned to the x/y plane.
function C:autoPlanes(ignoreTop, ignoreBot)
  local zMin, zMax = math.huge, -math.huge
  for i, v in ipairs(self.vertices) do
    zMin = math.min(zMin, v.pos.z)
    zMax = math.max(zMax, v.pos.z)
  end
  if not ignoreTop then
    self.top = {
      pos = vec3(self.center.x, self.center.y, zMax + 5),
      normal = vec3(0,0,1),
      active = true
    }
  end
  if not ignoreBot then
    self.bot = {
      pos = vec3(self.center.x, self.center.y, zMin - 5),
      normal = vec3(0,0,-1),
      active = true
    }
  end
  self:processVertices()
end

-- returns if a point is located between the planes.
function C:pointBetweenPlanes(point)
  if self.top.active then
    if (point - self.top.pos):dot(self.top.normal) > 0 then
      return false
    end
  end
  if self.bot.active then
    if (point - self.bot.pos):dot(self.bot.normal) > 0 then
      return false
    end
  end
  return true
end

function C:vertexPlaneIntersection(vertex, plane)
  --direction vector of the vertex
  if not plane.active then
    return vertex
  end
  local l = vec3(0,0,1)
  local ln = l:dot(plane.normal)
  if math.abs(ln) <= 1e-30 then
    -- this should not happen, planes are not allowed to be aligned with the z-axis
    log("E","","vertex plane intersection, plane is aligned with z-axis, not allowed!")
    return vertex
  end
  local d = (plane.pos - vertex):dot(plane.normal) / ln
  return vertex + vec3(0,0,d)
end

function C:aabbCheck(point)
  if self.aabb.invalid
  or point.x < self.aabb.xMin
  or point.x > self.aabb.xMax
  or point.y < self.aabb.yMin
  or point.y > self.aabb.yMax
  or point.z < self.aabb.zMin
  or point.z > self.aabb.zMax
  then
    return false
  end
  return true
end

function C:containsPoint2D(point)
  if self:aabbCheck(point) and self:pointBetweenPlanes(point) then
    local inside = false
    local verts = self.vertices
    for _, cur in ipairs(self.vertices) do
      local nexpos = verts[cur.next].pos

      local curposy = cur.pos.y
      local y3y4 = curposy - nexpos.y
      local y3y1 = curposy - point.y

      if math.abs(y3y1) < math.abs(y3y4)
        and y3y1*y3y4 >= 0
        and y3y4 * ((cur.pos.x - point.x) * y3y4 + (nexpos.x - cur.pos.x) * y3y1) >= 0 then
        inside = not inside
      end
    end
    return inside
  else
    return false
  end
end

local clrITemp = ColorI(0,0,0,0)
local clrTable = {}
local camPos
function C:drawDebug(drawMode, clr, customHeight, customDown, nearCam, drawDistance)
  drawMode = drawMode or self._drawMode
  if drawMode == 'none' then return end

  if not clr then
    clr = clrTable
    clrTable[1] = self.color.x
    clrTable[2] = self.color.y
    clrTable[3] = self.color.z
  end
  --if drawMode == 'highlight' then clr = {1,1,1,1} end
  local shapeAlpha = (drawMode == 'highlight') and 0.75 or 0.5
  --debugDrawer:drawSphere((self.pos), self.radius, ColorF(clr[1],clr[2],clr[3],shapeAlpha))
  if #clr == 4 then shapeAlpha = clr[4] end
  local alpha = (drawMode == 'normal') and 0.4 or 1
  if drawMode ~= 'faded' then
    debugDrawer:drawTextAdvanced((self.labelPos),
      String(self.name),
      ColorF(1,1,1,alpha),true, false,
      ColorI(0,0,0,alpha*255))
    for i, v in ipairs(self.vertices) do
      debugDrawer:drawLine((self.labelPos), (v.pos+vec3(0,0,5)), ColorF(clr[1],clr[2],clr[3],shapeAlpha))
    end
  end
  if drawMode == 'highlight' then
    for i, v in ipairs(self.vertices) do
      debugDrawer:drawCylinder((v.pos), (v.pos+vec3(0,0,5)), 0.5, ColorF(clr[1],clr[2],clr[3],shapeAlpha))
    end
  end
  if #self.vertices > 1 then
    clrITemp.r = clr[1]*255
    clrITemp.g = clr[2]*255
    clrITemp.b = clr[3]*255
    camPos = getCameraPosition()
    for i, v in ipairs(self.vertices) do
      local usePlanes = true
      if customHeight then
        usePlanes = false
      end

      self:drawFence(v.pos, self.vertices[v.next].pos, clrITemp, customDown or -50,customHeight or 5, usePlanes, nearCam, drawDistance, shapeAlpha)
      if v.t then
        debugDrawer:drawTextAdvanced(((v.pos + self.vertices[v.next])/2),
          String(string.format("t=%0.1f  |  u=%s",v.t,tostring(v.u))),
          ColorF(1,1,1,1),true, false,
          ColorI(0,0,0,255))
      end
    end
  end
  if drawMode ~= "faded" then
    if self.top.active then
      self:drawPlane(self.top, ColorF(clr[1],clr[2],clr[3],shapeAlpha))
    end
    if self.bot.active then
      self:drawPlane(self.bot, ColorF(clr[1],clr[2],clr[3],shapeAlpha))
    end
  end
end

function C:drawPlane(plane, clrF)
  if #self.vertices > 1 then
    for i, v in ipairs(self.vertices) do
      debugDrawer:drawLine((plane.pos), (self:vertexPlaneIntersection(v.pos,plane)), clrF)
      debugDrawer:drawLine(self:vertexPlaneIntersection(self.vertices[v.next].pos,plane), (self:vertexPlaneIntersection(v.pos,plane)), clrF)
    end
    debugDrawer:drawLine((plane.pos), (plane.pos + plane.normal*5), clrF)
  end

end


local defaultDrawDistance = 30
local fullAlphaDistance = defaultDrawDistance * 0.75

local a, b, c, d = vec3(), vec3(), vec3(), vec3()

function C:drawFence(from, to, clrI, down, up, usePlanes, nearCam, drawDistance, shapeAlpha)
  down = down or 0
  up = up or 5
  drawDistance = drawDistance or defaultDrawDistance
  fullAlphaDistance = drawDistance * 0.75
  if not nearCam or
    (   camPos.x > from.x-drawDistance and camPos.x < from.x+drawDistance
    and camPos.y > from.y-drawDistance and camPos.y < from.y+drawDistance
    and camPos.z > from.z-drawDistance and camPos.z < from.z+drawDistance )
    then

    local dist = camPos:distance(from)
    if dist > fullAlphaDistance and nearCam then
      clrI.a = shapeAlpha * 255 * clamp(linearScale(dist, fullAlphaDistance, drawDistance, 1, 0), 0,1)
    else
      clrI.a = shapeAlpha * 255
    end

    a:set(from) a.z = a.z+down
    b:set(from) b.z = b.z+up
    c:set(to) c.z = c.z+up
    d:set(to) d.z = d.z+down
    if usePlanes then
      if self.top.active then
        b = self:vertexPlaneIntersection(from,self.top)
        c = self:vertexPlaneIntersection(to,self.top)
      end
      if self.bot.active then
        a = self:vertexPlaneIntersection(from,self.bot)
        d = self:vertexPlaneIntersection(to,self.bot)
      end
    end

    -- one side
    debugDrawer:drawTriSolid(a, b, c, clrI)
    debugDrawer:drawTriSolid(c, d, a, clrI)
    -- other side
    debugDrawer:drawTriSolid(b, a, c, clrI)
    debugDrawer:drawTriSolid(d, c, a, clrI)
    if nearCam then
      --[[
      debugDrawer:drawLineInstance(from, c, ColorF(0.8, 0.8, 0.8, 0.8), 2)
      debugDrawer:drawLineInstance(to, b, ColorF(0.8, 0.8, 0.8, 0.8), 2)
      debugDrawer:drawLineInstance(c, b, ColorF(0.8, 0.8, 0.8, 0.8), 2)
      debugDrawer:drawLineInstance(from, a, ColorF(0.8, 0.8, 0.8, 0.8), 4)
      ]]
    end
  end
end

function C:makeHighResolutionFence()
  --if self.name ~= "servicestationGarage1" then return end
  local newVerts = {}
  local maxStep = 3--m
  local vCount = #self.vertices

  if vCount > 1 then
    for i, v in ipairs(self.vertices) do
      local cur, nex = v.pos, self.vertices[v.next].pos
      local dist = (vec3(cur):z0() - vec3(nex):z0()):length()
      local steps = math.max(math.floor((dist-0.1) / (maxStep)), 1)
      --print("from: " .. dumps(cur) .. " to " .. dumps(nex))
      --print(string.format("Distance: %0.2f, steps: %d", dist, steps))
      for i = 0, steps-1 do
        local t = i/steps
        local p = lerp(cur, nex, t)
        if core_terrain then
          p.z = (core_terrain.getTerrainHeight(p) or p.z)
        end
        table.insert(newVerts, {pos = p})
        --print("Adding: "..dumps(p))
      end
    end
  end
  if #self.vertices ~= #newVerts then
    log("D","Zones","Increased resolution of fence from " .. vCount.." Vertices to " .. #newVerts.." Vertices.")
  end
  self.vertices = newVerts
  self:processVertices()

end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end