-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local vecY = vec3(0,1,0)
local vecZ = vec3(0,0,1)

local manualzoom = require('core/cameraModes/manualzoom')

local C = {}
C.__index = C


local function rotateEuler(x, y, z, q)
  q = q or quat()
  q = quatFromEuler(0, z, 0) * q
  q = quatFromEuler(0, 0, x) * q
  q = quatFromEuler(y, 0, 0) * q
  return q
end

function C:init()
  self.manualzoom = manualzoom()
  self.manualzoom:init(self.fov)
  self:onVehicleCameraConfigChanged()
  self:reset()
  self.canRotate = self.canRotate ~= nil and self.canRotate or true --load canRotate from jbeam and default to true is nothing is specified
end

function C:onVehicleCameraConfigChanged()
  self.hidden = self.hidden or self.name == "driver" -- 'driver' camera data is kept, for driver.lua and other cams to use it. but the cam is hidden from the end-user, also accept jbeam config

end

function C:reset()
  self.camRot = vec3()
  self.manualzoom:reset()
end

local setLookBack = false
function C:lookback(value)
  if value >= 0.5 then
    setLookBack = true
  else
    setLookBack = false
  end
end

function C:update(data)
  -- update input
  if self.canRotate then --only rotate if the camera is allowed to
    self.camRot.x = self.camRot.x + 10 * MoveManager.yawRelative   + 100 * data.dt * (MoveManager.yawRight - MoveManager.yawLeft)
    self.camRot.y = self.camRot.y - 10 * MoveManager.pitchRelative + 100 * data.dt * (MoveManager.pitchDown  - MoveManager.pitchUp)
    --self.camRot.z = self.camRot.z - 10*MoveManager.rollRelative  + 100*data.dt*(MoveManager.rollRight- MoveManager.rollLeft)
  end
  if self.rotation and (self.rotation.z == nil or self.rotation.z == 0) then
    self.camRot.x = self.camRot.x + (self.rotation.x or 0)
    self.camRot.y = self.camRot.y + (self.rotation.y or 0)
  else
    self.camRot.y = clamp(self.camRot.y, -85, 85)
  end

  self.manualzoom:update(data)

  -- position
  local carPos = data.pos
  self.camNodeID = self.camNodeID or self.refNodes.ref or 0
  local nodePos = data.veh:getNodePosition(self.camNodeID)
  local qdir

  local camUp
  local camLeft
  local dir

  if self.idUp and self.idBack then
    local ref = data.veh:getNodePosition(self.idRef or self.camNodeID)
    local up =  data.veh:getNodePosition(self.idUp)
    local back =  data.veh:getNodePosition(self.idBack)
    dir = (ref - back); dir:normalize()
    camUp = (up - ref)
    camLeft = dir:cross(camUp); camLeft:normalize()
    camUp = camLeft:cross(dir); camUp:normalize()
  else
    local ref  = data.veh:getNodePosition(self.refNodes.ref)
    local left = data.veh:getNodePosition(self.refNodes.left)
    local back = data.veh:getNodePosition(self.refNodes.back)
    dir = (ref - back); dir:normalize()
    camLeft = (ref - left); camLeft:normalize()
    camUp = -(dir:cross(camLeft)); camUp:normalize()
  end

  if type(self.offset) == 'table' then
    nodePos = nodePos + dir * (self.offset.x or 0) - camLeft * (self.offset.y or 0) + camUp * (self.offset.z or 0)
  end

  if dir:squaredLength() == 0 or camLeft:squaredLength() == 0 then
    data.res.pos = carPos + nodePos
    data.res.rot = quatFromDir(vecY, vecZ)
    return false
  end

  qdir = quatFromDir(dir)
  local rotatedUp = qdir * vecZ
  local camPos = carPos + nodePos
  if setLookBack then
    qdir = rotateEuler(math.rad(180),0,math.atan2(rotatedUp:dot(camLeft), rotatedUp:dot(camUp)),qdir)
    camPos = vec3(data.veh:getSpawnWorldOOBBRearPoint())
  else
    qdir = rotateEuler(math.rad(self.camRot.x), math.rad(self.camRot.y), math.atan2(rotatedUp:dot(camLeft), rotatedUp:dot(camUp)), qdir)
  end

  -- application
  data.res.pos = camPos
  data.res.rot = qdir
  return true
end

function C:setRefNodes(centerNodeID, leftNodeID, backNodeID)
  self.refNodes = self.refNodes or {}
  self.refNodes.ref = centerNodeID
  self.refNodes.left = leftNodeID
  self.refNodes.back = backNodeID
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
