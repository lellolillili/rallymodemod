-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}


function C:init(sites, name, forceId)
  self.sites = sites
  self.id = forceId or sites:getNextUniqueIdentifier()
  self.name = name or "Location " .. self.id
  self.color  = vec3(1,1,1)
  self.pos = vec3()
  self.radius = 5
  self._drawMode = 'faded'
  self.sortOrder = 999999
  self.customFields = require('/lua/ge/extensions/gameplay/sites/customFields')()
end

function C:onSerialize()
  local ret = {
    name = self.name,
    pos = {self.pos.x,self.pos.y,self.pos.z},
    radius = self.radius,
    color = self.color:toTable(),
    oldId = self.id,
    customFields = self.customFields:onSerialize()
  }
  return ret
end

function C:onDeserialized(data)
  self.name = data.name
  self.color = vec3(data.color)
  self:set(vec3(data.pos),data.radius)
  self.customFields:onDeserialized(data.customFields)
  self.radius = data.radius or 5
end

function C:set(pos, radius)
  self.pos = vec3(pos)
  self.radius = radius
end

function C:drawDebug(drawMode, clr)
  drawMode = drawMode or self._drawMode
  if drawMode == 'none' then return end
  clr = clr or self.color:toTable()
  --if drawMode == 'highlight' then clr = {1,1,1,1} end
  local shapeAlpha = (drawMode == 'highlight') and 0.5 or 0.25
  debugDrawer:drawSphere((self.pos), self.radius, ColorF(clr[1],clr[2],clr[3],shapeAlpha))

  local alpha = (drawMode == 'normal') and 0.4 or 1
  if drawMode ~= 'faded' then
    debugDrawer:drawTextAdvanced((self.pos),
      String(self.name),
      ColorF(1,1,1,alpha),true, false,
      ColorI(0,0,0,alpha*255))
  end
  if drawMode == 'highlight' then
    local info = self:findClosestRoadInfo()
    if info then
      debugDrawer:drawSphere((info.pos), info.radius, ColorF(1,1,0.6,shapeAlpha/1.5))
      debugDrawer:drawSphere((info.a.pos), info.a.radius, ColorF(0.7,1,0.7,shapeAlpha/2))
      debugDrawer:drawSphere((info.b.pos), info.b.radius, ColorF(1,0.7,0.7,shapeAlpha/2))
      debugDrawer:drawCylinder((info.a.pos), (info.b.pos), info.radius, ColorF(1,1,1,shapeAlpha/2))
      debugDrawer:drawCylinder((info.pos), (self.pos), info.radius/3, ColorF(1,1,1,shapeAlpha/2))
      debugDrawer:drawTextAdvanced((info.pos),
        "Closest Road",
        ColorF(1,1,1,alpha),true, false,
        ColorI(0,0,0,alpha*200))
    end
  end
end

function C:findClosestRoadInfo()
  if not map then return nil end
  local name_a,name_b,distance = map.findClosestRoad(vec3(self.pos))
  if not name_a or not name_b or not distance then return end
  local a = map.getMap().nodes[name_a]
  local b = map.getMap().nodes[name_b]
  local xnorm = self.pos:xnormOnLine(a.pos,b.pos)
  if xnorm > 1 then xnorm = 1 end
  if xnorm < 0 then xnorm = 0 end
  -- if we are closer to point p, swap it around
  if xnorm > 0.5 then
    local swp = name_a
    name_a = name_b
    name_b = swp
    a = map.getMap().nodes[name_a]
    b = map.getMap().nodes[name_b]
    xnorm = 1-xnorm
  end
  return {
    name_a = name_a,
    name_b = name_b,
    a = a,
    b = b,
    distance = distance,
    pos = lerp(a.pos,b.pos, xnorm),
    radius = lerp(a.radius,b.radius,xnorm)
  }
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end