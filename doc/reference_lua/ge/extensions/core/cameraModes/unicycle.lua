-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

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
  self.hidden = true
  self.manualzoom = manualzoom()
  self.manualzoom:init(55)
  self:reset()
end

function C:onCameraChanged(focused)
  local isUnicycle = not activeGlobalCameraName and core_vehicle_manager and core_vehicle_manager.getPlayerVehicleData() and core_vehicle_manager.getPlayerVehicleData().mainPartName == "unicycle"
  if isUnicycle then return end

  if focused then
    if not self.pos or not self.rotVec then
      log("E", "", "No original pos,rotVec was provided (e.g. via setCustomData)")
    end
    guihooks.trigger('appContainer:loadLayoutByType', "unicycle")
  else
    core_gamestate.requestGameState() -- this is the best way i know of to go back to the intended ui layout, but i don't know if it's really right.
  end
end

function C:reset()
  --TODO what should reset do?
  self.manualzoom:reset()
  --self.pos = nil
  --self.rotVec = nil
end

-- return the point where we hit something on the way from origin to target
-- if nothing is hit, return nil
local function castRayLocation(origin, target)
  local result = vec3()
  local dir = target-origin
  local dist = dir:length()
  local ret = castRayStatic(origin, dir, dist)
  if ret >= dist then return end -- default to zero distance from origin
  result = origin + (dir:normalized()*ret)
  return result
end

local humanHeight = 1.6
local function getHumanHeight(crouching)
  return humanHeight * (crouching and 0.7 or 1)
end
local function getHipHeight(crouching)
  return getHumanHeight(crouching) * 0.45
end
local function getEyePosition(pos)
  local result
  local resultUp = pos+vec3(0, 0, getHipHeight(crouching))
  local resultDown = pos+vec3(0, 0,-5)
  local resultGround = castRayLocation(resultUp, resultDown)
  if resultGround then
    result = resultGround + vec3(0,0,getHumanHeight())
  else
    result = pos
  end
  return result
end

local prevCamPos
local maxFallHeight = 10
local gravity = -2
local teleportingSpeed = 1000/3.6 -- in m/s, threshold to detect teleport with F7 / recovery / reset / replay seeking
local function attemptToWalk(camPos, dt, crouching)
  if not levelLoaded then return camPos end -- don't attempt to walk if no level is loaded, as we can't raycast or do anything useful
  -- keep player walking on the ground
  local cameraTeleported = prevCamPos and (prevCamPos:distance(camPos)/dt > teleportingSpeed)
  if cameraTeleported then prevCamPos = nil end
  if prevCamPos then camPos.z = prevCamPos.z end
  local oldGround = camPos+vec3(0, 0, -getHumanHeight(crouching))
  local hip = oldGround+vec3(0, 0, getHipHeight(crouching))
  local target = oldGround+vec3(0, 0, -maxFallHeight)
  local newGround = castRayLocation(hip, target)
  local newCamPos
  -- calculate potential future location
  if newGround then
    -- found ground within the fall height
    if newGround.z < oldGround.z then
      --dump("ground known, falling towards it")
      newGround.z = math.max(oldGround.z + gravity*dt, newGround.z)
      newCamPos = newGround + vec3(0,0,getHumanHeight(crouching))
    else
      --dump("ground known, immediately climbing it")
      newCamPos = newGround + vec3(0,0,getHumanHeight(crouching))
    end
  else
    -- didn't find any ground within the fall height
    if prevCamPos then
      --dump("ground unknown, reverting")
      --newCamPos = prevCamPos
      newCamPos = camPos + vec3(0,0, gravity*dt)
    else
      --dump("ground unknown, falling into the abyss?")
      newCamPos = camPos + vec3(0,0, gravity*dt)
    end
  end
  -- check if we can get to the new potential location without hitting something
  if prevCamPos then
    local newKnee = newCamPos+vec3(0,0, -getHumanHeight(crouching)+getHipHeight(crouching))
    local prevKnee = prevCamPos+vec3(0,0, -getHumanHeight(crouching)+getHipHeight(crouching))
    local hipCollisionPoint = castRayLocation(prevKnee, newKnee)
    if hipCollisionPoint then
      -- our head hit something, stay away from the collision
      local diff = prevKnee - hipCollisionPoint
      local dist = math.max(diff:length(), 0.3) -- stay some distance away from collision point
      hipCollisionPoint = hipCollisionPoint + diff:normalized()*dist -- stay 20cm away from collision point
      newKnee = vec3(hipCollisionPoint.x, hipCollisionPoint.y, newKnee.z)
      newCamPos = newKnee+vec3(0,0,-getHipHeight(crouching)+getHumanHeight(crouching))
      --newCamPos = prevCamPos
    else
      -- no collision, all good
    end
  end
  prevCamPos = newCamPos
  return newCamPos
end

local function getRotVecFromFrontUp(front, up)
  local initialLookDir = quatFromDir(front, up)
  local rotEuler = initialLookDir:toEulerYXZ()
  local rotVec = vec3(math.deg(rotEuler.x), 180, 0) -- look horizontally, cause the math below is broken :(
  --local rotVec = vec3(math.deg(rotEuler.x), 180+math.deg(rotEuler.y), math.deg(rotEuler.z))
  --dump(string.format("%5.3f, %5.3f, %5.3f", rotVec.x, rotVec.y, rotVec.z))
  return rotVec
end

function C:setCustomData(customData)
  --TODO teleport vehicle to new position
  self.pos = getEyePosition(customData.pos)
  self.rotVec = getRotVecFromFrontUp(customData.front, customData.up)
end
function C:getPosRot()
  if not self.pos or not self.rotVec then
    log("W", "", "Unicycle camera cannot provide a position or a rotation: "..dumps(self.pos).." / "..dumps(self.rotVec))
    return vec3(), quat()
  end
  local rot = rotateEuler(-math.rad(self.rotVec.x), -math.rad(self.rotVec.y), math.rad(self.rotVec.z))
  return self.pos, rot
end

function C:update(data)
  local dt = data.dtSim
  if not self.rotVec then
    local veh = be:getPlayerVehicle(0)
    self:setCustomData({pos=data.pos, front=veh:getDirectionVector(), up=veh:getDirectionVectorUp()})
  end
  --if self.pos == nil then
    --log("E", "", "Walk camera has no usable pos data")
    --return
  --end

  -- rotation
  local rdx = MoveManager.yawRelative   + 20*dt*(MoveManager.yawRight - MoveManager.yawLeft  )
  local rdy = MoveManager.pitchRelative + 20*dt*(MoveManager.pitchUp  - MoveManager.pitchDown)
  self.rotVec = self.rotVec + (dt>0 and 7 or 0)*vec3(rdx, rdy, 0)
  self.rotVec.y = clamp(self.rotVec.y, 180-89.9, 180+89.9) -- limit head pitch, look at floor or roof, but not further than that (adding a 0.1 safety margin to account for float precission issues in later conversions)

  local rot = rotateEuler(-math.rad(self.rotVec.x), -math.rad(self.rotVec.y), math.rad(self.rotVec.z))
  local rotHorizontal = rotateEuler(-math.rad(self.rotVec.x), -math.rad(180), math.rad(self.rotVec.z))

  local camNodeID = core_camera.getDriverData(data.veh)
  local nodePos = vec3(data.veh:getNodePosition(camNodeID or 0))
  local carPos = data.pos
  self.pos = carPos + nodePos

  --self.manualzoom:update(data) -- disable for now, freeing up buttons on gamepad

  -- application
  data.res.pos = self.pos
  data.res.rot = rot

  -- unicycle guiding
  data.veh:queueLuaCommand("controller.getControllerSafe('playerController').setCameraControlData("..serialize({cameraRotation = rotHorizontal})..")")
  return true
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
