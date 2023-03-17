-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- filters
local autozoom = require('core/cameraModes/autozoom')
local autopoint = require('core/cameraModes/autopoint')
local handheld = require('core/cameraModes/handheld')
local noise = require('core/cameraModes/noise')
local smooth = require('core/cameraModes/smooth')
local predictor = require('core/cameraModes/predictor')

local C = {}
C.__index = C

local p = hptimer()

function C:init()
  self.disabledByDefault = true
  self.resetCameraOnVehicleReset = false
  self.now = 0 -- timekeeping (cannot use a countdown since the countdown will randomly change over time)
  self.justStarted = true
  self.isFanMode = true
  self.offsetPeriod = 1 -- how often to focus the camera on a different node of the vehicle
  self.lastOffsetTime = self.now

  -- car state (used for teleporting detection)
  self.carPos = vec3()
  self.carVel = vec3()
  self.lastCarPos = vec3()
  self.lastCarVel = vec3()

  -- camera panning effect
  self.camVel = vec3(0,0,0)
  self.lastCamVel = vec3(self.camVel)

  -- camera switch triggers:
  -- * time
  self.camChangeTimeMin = 1.5 -- never switch cam faster than this, no matter what
  self.camChangeTimeBase = 4 -- randomization base for timeMax:
  self.camChangeTimeMax = self.camChangeTimeBase -- never keep the same camera for longer than this. will be a bit randomized after each cam change
  self.lastCamChangeTime = self.now -- used to decide when it's been too long in the same camera. will be a bit randomized after each cam change
  -- * vehicle not visible by camera
  self.invisibleTimeThreshold = 0.5 -- how long the vehicle can stay out of sightline before switch to another camera
  self.invisibleTime = 0 -- how long the vehicle has been out of sightline. intermitent visibility can count towards this too

  -- filters
  self.autozoom = autozoom()
  self.autopoint = autopoint()
  self.noise = noise()
  self.noise:init(0.14)
  self.smooth = smooth()
  self.smooth:init(20, 2.0)
  self.handheld = handheld()
  self.predictor = predictor()
  self:onSettingsChanged()
  self:onVehicleCameraConfigChanged()
  self:reset()
end

function C:onVehicleCameraConfigChanged()
  self.autopoint.refNodes = self.refNodes
end

function C:onSettingsChanged()
  self.tvModeOdds = settings.getValue('cameraFanVsTV') or 0.66
end

function C:setRefNodes(centerNodeID, leftNodeID, backNodeID)
  self.refNodes = self.refNodes or {}
  self.refNodes.ref = centerNodeID
  self.refNodes.left = leftNodeID
  self.refNodes.back = backNodeID
  self.autopoint:setRefNodes(centerNodeID, leftNodeID, backNodeID)
end

-- generate a random value between deadzone and max. if centered is true, values may have negative sign
local function dzRandom(deadzone, max, centered)
  local result = math.random() -- o .. 1
  if centered then
    -- [-max..-deadzone][+deadzone..+max]
    result = (max-deadzone) * (2*result-1)
    if result < 0 then result = result - deadzone
    else               result = result + deadzone end
  else
    -- [+deadzone..+max]
    result = (max-deadzone) * result + deadzone
  end
  return result
end

-- switch to a new camera
function C:reset()
  self.justStarted = true
  self.lastCamChangeTime = self.now
  self.invisibleTime = 0
end

local function findRandomAttachedNodePosition(veh)
  -- locate a good vehicle node position for the camera to track
  local spawnAABBRadius = veh:getSpawnAABBRadius()
  for tries=1,10 do
    local node = math.random(0, veh:getNodeCount()-1)
    local offset = veh:getNodePosition(node)
    local worldSpeed = veh:getNodeVelocity(node)
    if worldSpeed:length() > 5/3.6 or offset:length() < spawnAABBRadius then -- avoid fallen nodes
      return offset
    end
  end
  return nil -- give up after some tries
end

-- attempt to place the camera halfway to the predicted car destination
function C:findNewCamPosVel(carPos, futureCarPos, velLength, chancesMultiplier, carStopped)
  -- chancesMultiplier starts at 1, decreasing towards 0
  -- choose a new camera position near this future car position
  local forwardVector = (futureCarPos - carPos):normalized()
  local    sideVector = forwardVector:cross(vec3(0,0,1)):normalized()
  local      upVector = (carPos - futureCarPos):cross(sideVector):normalized()
  local minSideDist = 1.2 * chancesMultiplier*chancesMultiplier
  local    sideDist = dzRandom(minSideDist, minSideDist+math.min(20, velLength*chancesMultiplier), true) -- further away the faster you go, but never too far
  local   minUpDist = 0.2 * chancesMultiplier
  local      upDist = dzRandom(minUpDist, minUpDist+math.max(3,math.min(10,velLength*chancesMultiplier)), false) * math.random() -- random height distance, closer to the ground when going slow, never too far
  self.camPos = futureCarPos + sideVector*sideDist + upVector*upDist

  -- randomize camera panning effect. bias it towards X axis, so camera rolls together with vehicle (or opposed to it)
  if self.isFanMode then
    self.camVel = vec3(0,0,0)
  else
    local lonSpeed = 0.5 * velLength * (2*math.random() - (carStopped and 1 or 0.1))
    local minSideVel = minSideDist / 20
    local minUpVel = minUpDist / 8
    local panningLocal = vec3(
        dzRandom(minSideVel, minSideVel + math.min(2,velLength*chancesMultiplier/20), true), --side
        -math.min(5, lonSpeed),   -- longitudinal
        dzRandom(minUpVel, minUpVel + math.min(1,velLength*chancesMultiplier/40), true))  -- up
    panningLocal.z = math.max(panningLocal.z, (upDist - 0.1) / self.camChangeTimeMax) -- make sure camera won't trespass the road surface parallel to vehicle speed
    local panningSpeedFactor = carStopped and 1 or ((math.random() > 0.6) and dzRandom(0.8, 1) or dzRandom(0, 0.075)) -- choose either fast panning, or very slow panning
    panningLocal = panningSpeedFactor * panningLocal
    self.camVel:set(axisSystemApply(sideVector, -forwardVector, upVector, panningLocal)) -- speed coords to world coords
  end
end

-- returns 0 if no collision is found, or a distance otherwise
local function castRay(origin, target)
  local dir = target-origin
  local dist = dir:length()
  local ret = castRayStatic(origin, dir, dist, true)
  if ret >= dist then return 0 end
  return ret
end

-- returns the point from origin towards target where there's a hit with a physical object
-- 'earlierDist' will choose a point slightly earlier than the actual hit. For example, 0.1 will return 10cm before the hit
-- 'minHeight' will offset a point vertically so that the ground is at least this far away
local function getHitPos(origin, target, earlierDist, minHeight)
  earlierDist = earlierDist or 0 -- in meters
  local dir = target-origin
  local dist = dir:length()
  local hitDistDirect = castRayStatic(origin, dir, dist, true)
  local hitDistInverse = castRayStatic(target, -dir, dist, true)
  local hitDist = math.max(0, math.min(hitDistDirect, hitDistInverse)-earlierDist)
  local hitPos = origin + dir:normalized()*hitDist

  if minHeight then
    local up = vec3(0,0,1)
    local down = vec3(0,0,-1)
    local groundDist = castRayStatic(hitPos, down, minHeight, true)
    hitPos = hitPos + down*groundDist + up*minHeight
  end

  return hitPos
end
-- returns true if no collision is found, false otherwise
local function isVisible(origin, target)
  local dir = target-origin
  local dist = dir:length()
  local retDirect = castRayStatic(origin, dir, dist, true)
  local retInverse = castRayStatic(target, -dir, dist, true)
  return (retDirect >= dist) and (retInverse >= dist)
end

function C:applyOffset(nx, ny, nz, offset)
  if not offset then return end
  offset = vec3(offset:dot(nx), offset:dot(ny), offset:dot(nz)) -- from world axis system to vehicle axis system
  self.autopoint.localOffset = offset -- in local vehicle coordinates
end

function C:switchCamera(carVel, carPos, veh, nx, ny, nz, carStopped)
  self.invisibleTime = 0 -- reset car visibility check counter
  self.lastCamChangeTime = self.now -- update camera reference data

  -- try to find a new camera position that shows the car along its predicted future path (without occlusions)
  local maxAttempts = 40
  local attemptsLeft = maxAttempts
  local acc = 0
  while true do
    self.isFanMode = math.random() > self.tvModeOdds
    local z = dzRandom(0.5, 1.0)
    if self.isFanMode then
      self.autozoom:init(newTemporalSmoothing(15, 15))
      self.autozoom.steps = { {  0, z*70}, {1.5, z*60}, {  3, z*40}, {  6, z*30}, { 10, z*25}, { 40, z*15}, { 90, z*15}, {150, z*15} }
    else
      self.autozoom:init(newTemporalSpring(15, 10))
      self.autozoom.steps = { {  0, z*70}, {1.5, z*60}, {  3, z*60}, {  8, z*60}, { 20, z*40}, { 50, z*30}, {125, z* 20}, {200, z* 15} }
    end
    -- the more attempts, the less we restrict our search
    local chancesMultiplier = attemptsLeft/maxAttempts
    chancesMultiplier = chancesMultiplier * chancesMultiplier -- restrict spawn area faster, so we can find a solution faster
    attemptsLeft = attemptsLeft - 1

    -- randomize next camera spawn times, so the camera-change timing pattern isn't sooo obvious
    self.camChangeTimeMax = self.camChangeTimeBase * dzRandom(0.7, 0.7+0.6*chancesMultiplier) + (carStopped and 2 or 0)

    -- generate a random speed vector when car is parked, to avoid low speed jittering in random weird directions (including under ground)
    if carStopped then
      carVel = vec3(dzRandom(0.5, 2, true), dzRandom(0.5   , 2, true), 0) -- random speed
      carVel = axisSystemApply(nx, ny, nz, carVel) -- speed coords to world coords
      self.autozoom.steps = { {  0, 60}, {1.5, 50}, {  3,  30}, {  6,  25}, { 10,  20}, { 40,  15}, { 90,   10}, {150,   10} }
    end

    -- predict the vehicle position by the time the cam changes again
    local carPosMidway = carPos + carVel*chancesMultiplier * self.camChangeTimeMax*0.5
    -- check if the driving path is clear
    if not isVisible(carPos, carPosMidway) then
      -- car will go through the map. assume it's just an upcoming slope
      local distTravel = carPos:distance(carPosMidway)
      local slopeOffset = vec3(0,0,distTravel*0.35)
      local newCarPosLast = carPosMidway + slopeOffset
      -- see if our assumption is right and we can rise our head above the ground
      local distToGround = castRay(carPosMidway, newCarPosLast)
      if distToGround ~= 0 then
        -- yep, it's probably a slope, let's move the vehicle prediction right above the ground
        newCarPosLast = carPosMidway + vec3(0,0,distToGround + 0.1)
        -- check if the path is clear (to prevent spawning on roofs after an uphill)
        local visible = isVisible(carPos, newCarPosLast + vec3(0, 0, 1)) -- we add a meter in this check because right at the ground we'll probably not see the car immediately, it may take a second to appear if there's a crest
        if visible then
          -- the slope prediction looks good, let's run with it
          carPosMidway = newCarPosLast
        end
      end
    end
    local carPosEnd = carPosMidway + (carPosMidway - carPos)

    -- attempt to place the camera halfway to the predicted car destination
    self:findNewCamPosVel(carPos, carPosMidway, carVel:length(), chancesMultiplier, carStopped)
    -- handheld camera should be at human height above ground, try to correct that
    if self.isFanMode then
      local heightTest = 50
      local humanCameraHeight = dzRandom(1.3, 2.0)
      local distDown = castRay(self.camPos, self.camPos-vec3(0,0,heightTest))
      if distDown == 0 or distDown == heightTest then -- we may be underground
        local distUp = heightTest-castRay(self.camPos+vec3(0,0,heightTest), self.camPos)
        if distUp == 0 or distUp == heightTest then -- we are too far over the ground, default to current vehicle height
          self.camPos.z = self.camPos.z +          humanCameraHeight
        else
          self.camPos.z = self.camPos.z + distUp + humanCameraHeight
        end
      else
        self.camPos.z = self.camPos.z - distDown + humanCameraHeight
       end
    end

    -- guesstimate future cam positions several points along changeTime, 3 positions in total, according to panning speed
    local camPosEnd  = self.camPos + self.camVel * self.camChangeTimeMax*1.0

    -- verify if we can & will see, and if the camera path is clean
    p:stopAndReset()
    if carStopped then
      carPosMidway = carPos
      carPosEnd = carPos
    end
    carPosEnd = getHitPos(carPos, carPosEnd, 0.05, 1.0)
    if  isVisible(self.camPos, carPos)   -- is car visible now
    and isVisible(camPosEnd,carPosEnd)  -- is car visible at the end
    and isVisible(self.camPos, camPosEnd)  -- can camera travel
    then
      acc = acc + p:stopAndReset()
      break -- yay, found a good camera
    end
    acc = acc + p:stopAndReset()
    if attemptsLeft == 0 then break end -- tough luck, we'll just use whatever we have by now
  end
  if self.isFanMode then
    self.predictor.future = dzRandom(0.1,0.35)
    if carStopped then
      self.handheld:init(20, 5, 2)
      self.noise:init(0.02)
    else
      self.handheld:init(40, 9, dzRandom(0.25, 0.7))
      self.noise:init(0.04)
    end
  else
    self.handheld:init(80, 15, 0.05)
    self.predictor.future = dzRandom(0.05,0.35)
  end
  self.smooth:init(nil, nil, self.camPos)
  self:applyOffset(nx, ny, nz, findRandomAttachedNodePosition(veh)) -- distance to current vehicle center aaa
end

function C:shouldSwitchCamera(carPos, carVel, dt)
  local minTimeElapsed = (self.now - self.lastCamChangeTime) >= self.camChangeTimeMin -- prevent confusing fast cam switches
  local tooLong = (self.now - self.lastCamChangeTime) >= self.camChangeTimeMax -- don't keep any one camera for boringly long
  local distance = carPos:distance(self.camPos)
  local minDistance = carVel:length()*5 -- the faster it drives, the further it can stay on cam
  local tooFar = distance > minDistance
  local goingAway = tooLong and tooFar -- if car is going far away from camera and we've been on this angle for a while already
  -- compute visibility over a period of time: the 'invisibleTime' timer increases at 1x and decreases at 2x
  -- this is used to prevent switching camera when the car was momentarily occluded by trees/signals/columns/fences/small objects/etc
  local carVisibleNow = isVisible(self.camPos, carPos)
  self.invisibleTime = clamp(self.invisibleTime + dt*(carVisibleNow and -2 or 1), 0, self.invisibleTimeThreshold)
  local carVisible = self.invisibleTime < self.invisibleTimeThreshold
  local justStarted = self.justStarted
  self.justStarted = false
  return justStarted or (minTimeElapsed and (not carVisible or goingAway))
end

local function debugDrawings(carPos, carPosEnd, carVel, camPos, camPosEnd)
  -- car debug
  debugDrawer:drawSphere((carPos+vec3(0,0,2)), 0.5, ColorF(1,0,0,0.5)) -- car position
  debugDrawer:drawSphere(carPos, 0.3, ColorF(1,0,0,1.0))
  debugDrawer:drawCylinder(carPos, carPosEnd, 0.1, ColorF(1,0,0,0.1)) -- predicted car path
  debugDrawer:drawSphere(carPosEnd, 0.3, ColorF(1,0,0,0.3))
  debugDrawer:drawSphere((carPos+carVel), 0.5, ColorF(0,1,0,0.5)) -- speed
  -- camera debug
  debugDrawer:drawCylinder(camPos, camPos, 0.05, ColorF(1,1,1,0.8)) -- cam position
  debugDrawer:drawSphere(camPos, 0.1, ColorF(0,0,1,0.2))
  debugDrawer:drawCylinder(camPos, camPosEnd, 0.02, ColorF(0,0,1,0.3))
  debugDrawer:drawSphere(camPosEnd, 0.1, ColorF(0,0,1,0.2))
end

local function getNxyz(refNodes, veh)
  local ref  = veh:getNodePosition(refNodes.ref)
  local left = veh:getNodePosition(refNodes.left)
  local back = veh:getNodePosition(refNodes.back)
  local nx = (left-ref):normalized()
  local ny = (back-ref):normalized()
  local nz = nx:cross(ny):normalized()
  return nx, ny, nz
end

function C:randomizeOffsetSpeeds(paused, carStopped)
  if not paused then
    self.lastOffsetTime = self.now
  end
  if self.isFanMode then
    if carStopped then
      self.offsetPeriod = dzRandom(1, 5)
      self.autopoint:setSpring(1, 0.7)
    else
      self.offsetPeriod = dzRandom(0.2, 1.5)
      self.autopoint:setSpring(100, 5)
    end
  else
    if carStopped then
      self.offsetPeriod = dzRandom(2, 3)
      self.autopoint:setSpring(0.1, 0.5)
    else
      self.offsetPeriod = dzRandom(0.5, 1.5)
      self.autopoint:setSpring(2, 1.3)
    end
  end
end

function C:carTeleported()
  self:reset()
end
function C:camTeleported()
  self.autozoom.mustReset = true
  self.handheld.mustReset = true
  self.lastCamPos = self.lastCamPos or vec3()
  self.camPos = self.camPos or vec3()
end

function C:update(data)
  data.dt = data.dtSim -- switch to physics dt, to respect time scaling
  local paused = data.dt < 0.00001

  -- precompute car position/velocity
  local carPos, carVel = self.carPos, self.carVel -- just for convenience
  carPos:set(data.pos)
  carVel:set(data.vel)
  local nx, ny, nz = getNxyz(self.refNodes, data.veh)
  local carStopped = carVel:length() < 0.5

  -- check if we need to reset anything (e.g. user just activated this camera, or vehicle got teleported, etc)
  if core_camera.objectTeleported(self.camPos, self.lastCamPos, self.lastCamVel, data.dt) then self:camTeleported() end -- cam teleported
  if data.teleported then self:carTeleported() end -- car teleported
  if core_camera.objectTeleported(carPos, self.lastCarPos, self.lastCarVel, data.dt) then self:carTeleported() end -- car *appears* to have teleported since the last time this camera was used
  self.lastCarPos:set(carPos)
  self.lastCarVel:set(carVel)

  -- check if we should point at a different vehicle part (vehicle node)
  local mustFindNewOffset = (self.now - self.lastOffsetTime) > self.offsetPeriod
  if mustFindNewOffset then
    self:randomizeOffsetSpeeds(paused, carStopped)
    self:applyOffset(nx, ny, nz, findRandomAttachedNodePosition(data.veh)) -- distance to current vehicle center
  end

  -- check if we should switch to a new camera
  if self:shouldSwitchCamera(carPos, carVel, data.dt) then
    self:switchCamera(carVel, carPos, data.veh, nx, ny, nz, carStopped)
  end

  -- apply cam velocity (panning effect)
  self.camPos = self.camPos + self.camVel * data.dt
  self.lastCamPos:set(self.camPos)

  self.now = self.now + data.dt -- update clock
  --debugDrawings(carPos, carPosEnd, carVel, self.camPos, camPosEnd)

  -- fill output table, and pass it through all remaining filters
  data.res.pos:set(self.camPos)
  self.predictor:update(data)
  self.autozoom:update(data)
  self.autopoint:update(data)
  if self.isFanMode then
    self.noise:update(data)
    self.smooth:update(data)
  end
  self.handheld:update(data)
  return true
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
