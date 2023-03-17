-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init(race, name)
  self.race = race
  self.id = race:getNextUniqueIdentifier()
  self.name = name or "Start Position " .. self.id

  self.pos = vec3()
  self.rot = quat()

  self._drawMode = 'faded'
  self.sortOrder = 999999
end


function C:onSerialize()
  local ret = {
    name = self.name,
    pos = {self.pos.x,self.pos.y,self.pos.z},
    rot = {self.rot.x,self.rot.y,self.rot.z,self.rot.w},
    oldId = self.id
  }
  return ret
end

function C:onDeserialized(data)
  self.name = data.name
  self.pos = vec3(data.pos)
  self.rot = quat(data.rot)
end

function C:set(pos, rot)
  self.pos = vec3(pos)
  self.rot = quat(rot)
end

function C:getFrontCorners(width, length)
  width = width or 1
  length = length or 1
  local rot = self.rot
  local x,y = rot * vec3(1,0,0), rot * vec3(0,-1,0)
  return {
    {self.pos + x*width + y*length  ,self.pos + x*width, self.pos - x*width, self.pos - x*width + y*length},
    {self.pos + x*width+y*0.4, self.pos - x*width+y*0.4}
  }
end

function C:drawDebug(drawMode, clr)
  drawMode = drawMode or self._drawMode
  if drawMode == 'none' then return end
  clr = clr or rainbowColor(#self.race.startPositions.sorted, (self.sortOrder-1), 1)
  if drawMode == 'highlight' then clr = {1,1,1,1} end
  local shapeAlpha = (drawMode == 'highlight') and 0.5 or 0.25
  --debugDrawer:drawSphere((self.pos), 2, ColorF(clr[1],clr[2],clr[3],shapeAlpha))
  local rot = self.rot
  local x, y, z = rot * vec3(1,0,0), rot * vec3(0,1,0), rot * vec3(0,0,1)

  -- one side
  debugDrawer:drawTriSolid(
    vec3(self.pos + x + z),
    vec3(self.pos + x    ),
    vec3(self.pos - x    ),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  debugDrawer:drawTriSolid(
    vec3(self.pos - x    ),
    vec3(self.pos - x + z),
    vec3(self.pos + x + z),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))

  debugDrawer:drawTriSolid(
    vec3(self.pos - x + z),
    vec3(self.pos - x - y*4),
    vec3(self.pos - x    ),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  debugDrawer:drawTriSolid(
    vec3(self.pos + x + z),
    vec3(self.pos + x - y*4),
    vec3(self.pos + x    ),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))

  -- other side
  debugDrawer:drawTriSolid(
    vec3(self.pos + x + z),
    vec3(self.pos - x    ),
    vec3(self.pos + x    ),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  debugDrawer:drawTriSolid(
    vec3(self.pos - x    ),
    vec3(self.pos + x + z),
    vec3(self.pos - x + z),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))

  debugDrawer:drawTriSolid(
    vec3(self.pos - x + z),
    vec3(self.pos - x    ),
    vec3(self.pos - x - y*4),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))
  debugDrawer:drawTriSolid(
    vec3(self.pos + x + z),
    vec3(self.pos + x    ),
    vec3(self.pos + x - y*4),
    ColorI(clr[1]*255,clr[2]*255,clr[3]*255,shapeAlpha*255))


  if drawMode == 'highlight' then
    debugDrawer:drawSquarePrism(
      vec3(self.pos -y*0.1 + z*0.91),
      vec3(self.pos -y*4.6 + z*0.91),
      Point2F(1.5,1.8),
      Point2F(1.5,1.8),
      ColorF(0.9,0.0,0.3,0.5))
  end

  local alpha = (drawMode == 'normal') and 0.5 or 1
  if drawMode ~= 'faded' then
    debugDrawer:drawTextAdvanced(self.pos,
      String(self.name),
      ColorF(1,1,1,alpha),true, false,
      ColorI(0,0,0,alpha*255))
  end
end

function C:moveResetVehicleTo(vehId, lowPrecision)
  local veh = scenetree.findObjectById(vehId)
  if not veh then return end

  local fl  = vec3(veh:getSpawnWorldOOBB():getPoint(0))
  local fr  = vec3(veh:getSpawnWorldOOBB():getPoint(3))
  local bl  = vec3(veh:getSpawnWorldOOBB():getPoint(4))
  local flU = vec3(veh:getSpawnWorldOOBB():getPoint(1))

  local xVeh = (fr -fl):normalized()
  local yVeh = (fl -bl):normalized()
  local zVeh = (flU-fl):normalized()

  local pos = veh:getPosition()
  local posOffset = (pos - fl)
  local localOffset = vec3(xVeh:dot(posOffset), yVeh:dot(posOffset), zVeh:dot(posOffset))

  local xLine, yLine, zLine = self.rot * vec3(1,0,0), self.rot * vec3(0,1,0), self.rot * vec3(0,0,1)
  local newFLPos = self.pos - xLine * (fl-fr):length() * 0.5

  local newOffset = xLine * localOffset.x + yLine * localOffset.y + zLine * localOffset.z
  local newPos = newFLPos + newOffset
  local vehRot = quatFromEuler(0,0,math.pi) * self.rot

  if lowPrecision then -- this must be used if the vehicle is loaded in the first frame, because the OOBB does not work correctly then.
    newPos = self.pos + yLine*2 + zLine * 0.5 -- spawn the vehicle 2m behin and 0.5m above self.
  end
  veh:setPositionRotation(newPos.x, newPos.y, newPos.z, vehRot.x, vehRot.y, vehRot.z, vehRot.w)
  return newPos, vehRot
end

function C:setToVehicle(vehId)
  local veh = scenetree.findObjectById(vehId)
  if not veh then return end
  local fl  = vec3(veh:getSpawnWorldOOBB():getPoint(0))
  local fr  = vec3(veh:getSpawnWorldOOBB():getPoint(3))
  local bl  = vec3(veh:getSpawnWorldOOBB():getPoint(4))
  local flU = vec3(veh:getSpawnWorldOOBB():getPoint(1))

  local center = fl/2 + fr/2
  if scenetree.findClassObjects("TerrainBlock") then
    center.z = core_terrain.getTerrainHeight(center)
    local normalTip = center + (bl-fl)
    normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
    self.rot = quatFromDir((center - normalTip):normalized(), (flU-bl):normalized())
  else
    self.rot = quatFromDir((fl - bl):normalized(), (flU-bl):normalized())
  end
  self.pos = center

end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end