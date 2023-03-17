-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init()
  self.isFilter = true
  self.hidden = true
  self.localOffset = vec3(0,0,0) -- relative coords where the camera will point at
  self:setSpring(5,1)
end

function C:setSpring(rate, accel)
  self.smX = newTemporalSigmoidSmoothing(rate,accel, rate,accel, self.smX and self.smX:value() or nil)
  self.smY = newTemporalSigmoidSmoothing(rate,accel, rate,accel, self.smY and self.smY:value() or nil)
  self.smZ = newTemporalSigmoidSmoothing(rate,accel, rate,accel, self.smZ and self.smZ:value() or nil)
end

function C:setRefNodes(centerNodeID, leftNodeID, backNodeID)
  self.refNodes = self.refNodes or {}
  self.refNodes.ref = centerNodeID
  self.refNodes.left = leftNodeID
  self.refNodes.back = backNodeID
end

function C:update(data)
  local ref  = data.veh:getNodePosition(self.refNodes.ref)
  local left = data.veh:getNodePosition(self.refNodes.left)
  local back = data.veh:getNodePosition(self.refNodes.back)
  local nx = (left-ref):normalized()
  local ny = (back-ref):normalized()
  local nz = nx:cross(ny):normalized()
  local offset = vec3(self.localOffset)
  offset:set(
    self.smX:get(self.localOffset.x, data.dt),
    self.smY:get(self.localOffset.y, data.dt),
    self.smZ:get(self.localOffset.z, data.dt)
  )
  data.res.targetPos:setAdd(axisSystemApply(nx, ny, nz, offset))
  data.res.rot = data.res.rot or quat()
  data.res.rot:set(quatFromDir((data.res.targetPos - data.res.pos):normalized()))
  return true
end

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
