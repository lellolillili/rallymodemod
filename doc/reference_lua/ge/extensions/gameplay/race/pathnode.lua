-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local modes = {"manual","navgraph"}

function C:init(path, name, forceId)
  self.path = path
  self.id = forceId or path:getNextUniqueIdentifier()
  self.name = name or "Pathnode " .. self.id
  self.mode = "manual"
  self.pos = vec3()
  self.normal = nil
  self.radius = 0
  self.navRadiusScale = 1
  self.hasNormal = false
  self._drawMode = 'faded'
  self.sortOrder = 999999

  self.sidePadding = vec3(1,3)

  self.visible = true
  self.recovery = -1
  self.reverseRecovery = -1

  self.customFields = require('/lua/ge/extensions/gameplay/sites/customFields')()
end

function C:setNormal(normal)
  if not normal then
    self.normal = nil
    self.hasNormal = false
  else
    if normal:length() > 0.9 then
      self.normal = normal:normalized()
      self.hasNormal = true
    else
      self:setNormal(nil)
    end
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

function C:setNavRadiusScale(scl)
  self.navRadiusScale = scl or 1
  if self.mode == 'navgraph' then
    self.radius = map.getMap().nodes[self.navgraphName].radius * self.navRadiusScale
  end
end

function C:inside(pos)
  local inside = (pos-self.pos):length() <= self.radius
  if self.hasNormal then
    return inside and ((pos-self.pos):normalized():dot(self.normal) >= 0)
  else
    return inside
  end
end

function C:getRecovery()
  return self.path.startPositions.objects[self.recovery]
end
function C:getReverseRecovery()
  return self.path.startPositions.objects[self.reverseRecovery]
end

function C:intersectCorners(fromCorners, toCorners)
  local minT = math.huge
  for i = 1, #fromCorners do
    local rPos, rDir = fromCorners[i], toCorners[i]-fromCorners[i]
    local len = rDir:length()
    if len > 0 then
      len = 1/len
      rDir:normalize()
      if self.hasNormal then
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
      else
        local t, _ = intersectsRay_Sphere(rPos, rDir, self.pos, self.radius)
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
    mode = self.mode,
    navRadiusScale = self.navRadiusScale,
    pos = {self.pos.x,self.pos.y,self.pos.z},
    radius = self.radius,
    normal = self.hasNormal and {self.normal.x,self.normal.y,self.normal.z} or nil,
    navgraphName = self.navgraphName,
    oldId = self.id,
    recovery = self.recovery,
    reverseRecovery = self.reverseRecovery,
    visible = self.visible,
    sidePadding = {self.sidePadding.x, self.sidePadding.y},
    customFields = self.customFields:onSerialize()
  }
  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  self.navRadiusScale = data.navRadiusScale
  if data.mode == 'navgraph' then
    self:setNavgraph(data.navgraphName, {pos = vec3(data.pos), radius = data.radius})
    if data.normal then
      self:setNormal(vec3(data.normal))
    end
  elseif data.mode == 'manual' then
    self:setManual(vec3(data.pos),data.radius,vec3(data.normal))
  end
  self.recovery = oldIdMap and oldIdMap[data.recovery] or data.recovery or -1
  self.reverseRecovery = oldIdMap and oldIdMap[data.reverseRecovery] or data.reverseRecovery or -1
  self.visible = data.visible or (data.visible == nil)
  self.sidePadding = data.sidePadding and vec3(data.sidePadding[1], data.sidePadding[2],0) or vec3()

  self.customFields:onDeserialized(data.customFields or {})
end

function C:getPaddedCenter()
  local midWidth = self.radius*2 - self.sidePadding.x - self.sidePadding.y
  local side = self.normal:cross(vec3(0,0,1)) *(self.radius-self.sidePadding.y - midWidth/2)
  return self.pos+side, midWidth
end

function C:drawDebug(drawMode, clr, extraText)
  drawMode = drawMode or self._drawMode
  if drawMode == 'none' then return end

  clr = clr or rainbowColor(#self.path.pathnodes.sorted, (self.sortOrder-1), 1)
  if drawMode == 'highlight' then clr = {1,1,1,1} end
  if drawMode == 'faded' then clr = {1,1,1,0.25} end
  local shapeAlpha = (drawMode == 'highlight') and 0.5 or 0.25
  if not self.visible  then
    clr[1] = clr[1] * 0.3 + 0.25
    clr[2] = clr[2] * 0.3 + 0.25
    clr[3] = clr[3] * 0.3 + 0.25
  end

  debugDrawer:drawSphere((self.pos), self.radius, ColorF(clr[1],clr[2],clr[3],shapeAlpha))

  local alpha = (drawMode == 'normal') and 0.5 or 1
  if drawMode ~= 'faded' then
    local str = self.name
    if not self.visible then
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

  if self.hasNormal then
    local midWidth = self.radius*2 --- self.sidePadding.x - self.sidePadding.y
    local side = self.normal:cross(vec3(0,0,1)) *(self.radius-self.sidePadding.y - midWidth/2)
    debugDrawer:drawSquarePrism(
      self.pos,
      (self.pos + self.radius * self.normal),
      Point2F(1,self.radius/2),
      Point2F(0,0),
      ColorF(clr[1],clr[2],clr[3],shapeAlpha*1.0))
    debugDrawer:drawSquarePrism(
      (self.pos),
      (self.pos + 0.25 * self.normal ),
      Point2F(5,midWidth),
      Point2F(0,0),
      ColorF(clr[1],clr[2],clr[3],shapeAlpha*0.4))
  end
end


-- side detail procedural generator
local qOff = quatFromEuler(0,0,math.pi/2)*quatFromEuler(0,math.pi/2,math.pi/2)
function C:convertRayHitToTransform(hit, pRot, zOff, scl, side, alignMode)
  if not hit then return nil end

  local rot = quat()
  if alignMode == 'terrain' then
    rot = qOff * pRot * quatFromDir(vec3(hit.norm), self.normal)
  elseif alignMode == 'pathnode' then
    rot = qOff * pRot * quatFromDir(vec3(0,0,1), self.normal)
  elseif alignMode == 'absolute' then
    rot = pRot
  end
  local ret = {
    pos = vec3(hit.pt) + zOff * vec3(hit.norm),
    scl = vec3(scl),
    rot = rot,
    side = side
  }
  return ret
end

local rayLength = 10
function C:getSideTransforms(posOffset, rotOffset, sclOffset, alignMode)
  if not self.hasNormal then return {} end
  alignMode = alignMode or "terrain"
  local rot = quatFromDir(self.normal:z0())
  local up = vec3(0,0,1)

  -- find positions on side
  local pLeft, pRight = self.pos + rot*(vec3(-self.radius,0,0)-posOffset:z0()) + up*rayLength/2,
                        self.pos + rot*(vec3( self.radius,0,0)+posOffset:z0()) + up*rayLength/2


  -- disable forest for raycasts
  if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end

  local hitLeft = Engine.castRay((pLeft), (pLeft-up*rayLength), true, false)
  local hitRight = Engine.castRay((pRight), (pRight-up*rayLength), true, false)

  if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end

  return {
    self:convertRayHitToTransform(hitLeft,  quatFromEuler(rotOffset.x, -rotOffset.y, -rotOffset.z), posOffset.z, sclOffset,'l', alignMode),
    self:convertRayHitToTransform(hitRight, quatFromEuler(rotOffset.x,  rotOffset.y,  rotOffset.z), posOffset.z, sclOffset,'r', alignMode)
  }
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end