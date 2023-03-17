-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local vecY = vec3(0,1,0)
local vecZ = vec3(0,0,1)

local collision = require('core/cameraModes/collision')

local C = {}
C.__index = C

function C:init()
  self.disabledByDefault = true
  self.camLastRot = vec3()
  self.fwdVeloSmoother = newTemporalSmoothing(100)
  local chaseDirSmoothCoef = 0.0008
  self.dirSmoothX = newTemporalSmoothing(chaseDirSmoothCoef)
  self.dirSmoothY = newTemporalSmoothing(chaseDirSmoothCoef)
  self.dirSmoothZ = newTemporalSmoothing(chaseDirSmoothCoef)
  self.lastDataPos = vec3()
  self.forwardLooking = true
  self.lastRefPos = vec3()
  self.camLastUp = vec3()
  self.camResetted = 0

  self.collision = collision()
  self.collision:init()

  self:onVehicleCameraConfigChanged()
  self:onSettingsChanged()
  self:reset()
end

function C:onVehicleCameraConfigChanged()
  if self.defaultRotation == nil then
    self.defaultRotation = vec3(0, -17, 0)
  else
    self.defaultRotation = vec3(self.defaultRotation)
    self.defaultRotation.y = -self.defaultRotation.y
  end
  self.camRot = vec3(self.defaultRotation)
  self.camMinDist = self.distanceMin or 3
  self.distance = self.distance or 5
  self.defaultDistance = self.distance
  self.camDist = self.defaultDistance
  self.camLastDist = self.defaultDistance
  self.mode = self.mode or 'ref'
  self.fov = self.fov or 65
  self.offset = vec3(self.offset)
  self.camBase = vec3()
end

function C:onSettingsChanged()
  self.relaxation = settings.getValue('cameraOrbitRelaxation') or 3
  self.rollSmoothing = math.max(settings.getValue('cameraChaseRollSmoothing') or 1, 0.000001)
  self:reset() --TODO is this really necessary?
end

function C:reset()
  self.camRot = vec3(self.defaultRotation)
  self.camRot.x = 0
  self.forwardLooking = true
  self.camResetted = 2
  self.relYaw = 0
  self.relPitch = 0
end

local rot = vec3()
function C:update(data)
  data.res.collisionCompatible = true
  -- update input
  local deadzone = 0.5
  self.relYaw =   clamp(self.relYaw   + 0.15*MoveManager.yawRelative  , -1, 1)
  self.relPitch = clamp(self.relPitch + 0.15*MoveManager.pitchRelative, -1, 1)
  local relYawUsed   = self.relYaw
  local relPitchUsed = self.relPitch
  if math.abs(relYawUsed)   < deadzone then relYawUsed   = 0 end
  if math.abs(relPitchUsed) < deadzone then relPitchUsed = 0 end

  local dx = 200*relYawUsed + 100*data.dt*(MoveManager.yawRight - MoveManager.yawLeft)
  self.camRot.x = 0
  if not self.forwardLooking then
    self.camRot.x = -180
  end

  local triggerValue = 0.05

  if dx > triggerValue then
    self.camRot.x = 90
  elseif dx < -triggerValue then
    self.camRot.x = -90
  end
  if not self.forwardLooking then
    self.camRot.x = -self.camRot.x
  end

  local dy = 200*relPitchUsed + 100*data.dt*(MoveManager.pitchUp - MoveManager.pitchDown)
  self.camRot.y = self.defaultRotation.y
  if dy > triggerValue then
    self.camRot.y = self.defaultRotation.y + 30
  elseif dy < -triggerValue then
    if self.forwardLooking then
      self.camRot.x = -180
    else
      self.camRot.x = 0
    end
  end

  self.camRot.y = clamp(self.camRot.y, -85, 85)

  -- make sure the rotation is never bigger than 2 PI
  if self.camRot.x > 180 then
    self.camRot.x = self.camRot.x - 360
    self.camLastRot.x = self.camLastRot.x - math.pi * 2
  elseif self.camRot.x < -180 then
    self.camRot.x = self.camRot.x + 360
    self.camLastRot.x = self.camLastRot.x + math.pi * 2
  end

  local ddist = 0.1 * data.dt * (MoveManager.zoomIn - MoveManager.zoomOut) * self.fov
  self.camDist = self.defaultDistance
  if ddist > triggerValue then
    self.camDist = self.defaultDistance * 2
  elseif ddist < -triggerValue then
    self.camDist = self.camMinDist
  end

  --
  local ref  = data.veh:getNodePosition(self.refNodes.ref)
  local left = data.veh:getNodePosition(self.refNodes.left)
  local back = data.veh:getNodePosition(self.refNodes.back)

  -- calculate the camera offset: rotate with the vehicle
  local nx = left - ref
  local ny = back - ref

  if nx:squaredLength() == 0 or ny:squaredLength() == 0 then
    data.res.pos = data.pos
    data.res.rot = quatFromDir(vecY, vecZ)
    return false
  end

  local nz = nx:cross(ny):normalized()

  if self.offset and self.offset.x then
    self.camBase:set(self.offset.x / (nx:length() + 1e-30), self.offset.y / (ny:length() + 1e-30), self.offset.z / (nz:length() + 1e-30))
  else
    self.camBase:set(0,0,0)
  end


  local targetPos
  if self.mode == 'center' then
    targetPos = data.veh:getBBCenter()
  else
    local camOffset2 = nx * self.camBase.x + ny * self.camBase.y + nz * self.camBase.z
    targetPos = data.pos + ref + camOffset2
  end

  local dir = (ref - back); dir:normalize()

  if self.camResetted ~= 0 then
    self.lastDataPos = vec3(data.pos)
  end

  local up = dir:cross(left); up:normalize()

  if self.camResetted ~= 1 then
    if self.rollSmoothing > 0.0001 then
      local upSmoothratio = 1 / (data.dt * self.rollSmoothing)
      up = (1 / (upSmoothratio + 1) * up + (upSmoothratio / (upSmoothratio + 1)) * self.camLastUp); up:normalize()
    else
      -- if rolling is disabled, we are always up no matter what ...
      up:set(vecZ)
    end
    dir:set(self.dirSmoothX:getUncapped(dir.x, data.dt*1000), self.dirSmoothY:getUncapped(dir.y, data.dt*1000), self.dirSmoothZ:getUncapped(dir.z, data.dt*1000)); dir:normalize()
  end
  self.camLastUp:set(up)

  -- decide on a looking direction
  -- the reason for this: on reload, the vehicle jumps and the velocity is not correct anymore
  local vel = (data.pos - self.lastDataPos) / data.dt
  local velF = vel:dot(dir)
  local velNF = vel:distance(velF * dir)
  local forwardVelo = self.fwdVeloSmoother:getUncapped(velF, data.dt)
  if self.camResetted == 0 then
    if self.forwardLooking and forwardVelo < -1.5 and math.abs(forwardVelo) > velNF then
      if self.camRot.x >= 0 then
        self.camRot:set(self.defaultRotation)
        self.camRot.x = 180
      else
        self.camRot:set(self.defaultRotation)
        self.camRot.x = -180
      end
      self.forwardLooking = false
    elseif not self.forwardLooking and forwardVelo > 1.5 then
      self.camRot:set(self.defaultRotation)
      self.camRot.x = 0
      self.forwardLooking = true
    end
  end
  self.lastDataPos:set(data.pos)

  rot:set(math.rad(self.camRot.x), math.rad(self.camRot.y), math.rad(self.camRot.z))

  -- smoothing
  local ratio = 1 / (data.dt * 8)
  rot.x = 1 / (ratio + 1) * rot.x + (ratio / (ratio + 1)) * self.camLastRot.x
  rot.y = 1 / (ratio + 1) * rot.y + (ratio / (ratio + 1)) * self.camLastRot.y

  local dist = 1 / (ratio + 1) * self.camDist + (ratio / (ratio + 1)) * self.camLastDist

  local calculatedCamPos = dist * vec3(
     math.sin(rot.x) * math.cos(rot.y)
    , math.cos(rot.x) * math.cos(rot.y)
    , math.sin(rot.y)
  )

  local qdir_heading = quatFromDir(-dir, up)
  calculatedCamPos = qdir_heading * calculatedCamPos

  local camPos = calculatedCamPos + targetPos

  local dir_target = (targetPos - camPos); dir_target:normalize()
  local qdir_target = quatFromDir(dir_target, up)

  self.camLastRot:set(rot)
  self.camLastDist = dist
  self.camResetted = math.max(self.camResetted - 1, 0)

  -- application
  data.res.pos = camPos
  data.res.rot = qdir_target
  data.res.fov = self.fov
  data.res.targetPos = targetPos

  self.collision:update(data)
  return true
end

function C:setRefNodes(centerNodeID, leftNodeID, backNodeID)
  self.refNodes = self.refNodes or {}
  self.refNodes.ref = centerNodeID
  self.refNodes.left = leftNodeID
  self.refNodes.back = backNodeID
end

function C:mouseLocked(locked)
  if locked then return end
  self.relYaw = 0
  self.relPitch = 0
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
