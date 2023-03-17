-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local modes = {"manual","navgraph"}

function C:init(path, name, forceId)
  self.path = path
  self.id = forceId or path:getNextUniqueIdentifier()
  self.name = name or "Pacenote " .. self.id
  self.pos = vec3()
  self.normal = vec3(0,1,0)
  self.radius = 0

  self.note = ""
  self.segment = -1


  self._drawMode = 'none'
  self.sortOrder = 999999

end

function C:setNormal(normal)
  if not normal then
    self.normal = vec3(0,1,0)
  end
  if normal:length() > 0.9 then
    self.normal = normal:normalized()
  end
end

function C:setManual(pos, radius, normal)
  self.mode = "manual"
  self.pos = vec3(pos)
  self.radius = radius
  self:setNormal(normal)
  self.navgraphName = nil
end

function C:setNavgraph(navgraphName, fallback)
  self.mode = "navgraph"
  self.navgraphName = navgraphName
  local n = map.getMap().nodes[navgraphName]
  if n then
    self.pos = n.pos
    self.radius = n.radius * self.navRadiusScale
  else
    if fallback then
      self.pos = fallback.pos
      self.radius = fallback.radius * self.navRadiusScale
    end
  end
  self:setNormal(nil)
end


function C:inside(pos)
  local inside = (pos-self.pos):length() <= self.radius
  if self.hasNormal then
    return inside and ((pos-self.pos):normalized():dot(self.normal) >= 0)
  else
    return inside
  end
end


function C:intersectCorners(fromCorners, toCorners)
  local minT = math.huge
  for i = 1, #fromCorners do
    local rPos, rDir = fromCorners[i], toCorners[i]-fromCorners[i]
    local len = rDir:length()
    if len > 0 then
      len = 1/len
      rDir:normalize()
      local sMin, sMax = intersectsRay_Sphere(rPos, rDir, self.pos, self.radius)
      --adjust for normlized rDir
      sMin = sMin * len
      sMax = sMax * len
      -- inside sphere?
      if sMin <= 0 and sMax >= 1 then
        local t = intersectsRay_Plane(rPos, rDir, self.pos, self.normal)
        t = t*len
        if t<=1 and t>=0 then
          minT = math.min(t, minT)
        end
      end
    end
  end

  return minT <= 1, minT
end

function C:onSerialize()
  local ret = {
    name = self.name,
    pos = {self.pos.x,self.pos.y,self.pos.z},
    radius = self.radius,
    normal = {self.normal.x,self.normal.y,self.normal.z},
    oldId = self.id,
    note = self.note,
    segment = self.segment
  }
  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  self:setManual(vec3(data.pos),data.radius,vec3(data.normal))
  self.note = data.note
  self.segment = oldIdMap and oldIdMap[data.segment] or data.segment or -1
end


function C:drawDebug(drawMode, clr, extraText)
  drawMode = drawMode or self._drawMode
  if drawMode == 'none' then return end

  clr = clr or rainbowColor(#self.path.pacenotes.sorted, (self.sortOrder-1), 1)
  if drawMode == 'highlight' then clr = {1,1,1,1} end
  --clr = {1,1,1,1}
  local shapeAlpha = (drawMode == 'highlight') and 0.5 or 0.25

  debugDrawer:drawSphere((self.pos), self.radius, ColorF(clr[1],clr[2],clr[3],shapeAlpha))

  local alpha = (drawMode == 'normal') and 0.5 or 1
  if self.note == '' then alpha = alpha * 0.4 end
  if drawMode ~= 'faded' then
    local str = self.note or ''
    if str == '' then
      str = self.name or 'Note'
      str = '('..str..')'
    end
    if extraText then
      str = str .. ' ' .. extraText
    end
    debugDrawer:drawTextAdvanced((self.pos),
      String(str),
      ColorF(1,1,1,alpha),true, false,
      ColorI(0,0,0,alpha*255))
 end


  local midWidth = self.radius*2
  local side = self.normal:cross(vec3(0,0,1)) *(self.radius - midWidth/2)
  debugDrawer:drawSquarePrism(
    self.pos,
    (self.pos + self.radius * self.normal),
    Point2F(1,self.radius/2),
    Point2F(0,0),
    ColorF(clr[1],clr[2],clr[3],shapeAlpha*1.25))
  debugDrawer:drawSquarePrism(
    (self.pos+side),
    (self.pos + 0.25 * self.normal + side ),
    Point2F(5,midWidth),
    Point2F(0,0),
    ColorF(clr[1],clr[2],clr[3],shapeAlpha*0.66))
end


return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end