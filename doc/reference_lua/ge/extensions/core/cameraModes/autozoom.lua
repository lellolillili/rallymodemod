-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init(smoother)
  self.isFilter = true
  self.hidden = true
  self.fovSmoother = smoother or self.fovSmoother or newTemporalSpring(30, 10)
  if self.fovSmoother.getUncapped then
    self.smooth = self.fovSmoother.getUncapped
  else
    self.smooth = self.fovSmoother.get
  end
  self.mustReset = true
  self.fov = self.fov or 60 -- actual last fov sent to renderer
  self.baseFov = self.fov or 90 -- fov chosen by computer
  self.userFov = 0 -- fov delta chosen by the user (numpad 9/3), for greater/smaller zoom
  self.fovSmoother:set(self.baseFov)
  self.steps = { -- the format is {meters of distance, fov angle}
    {  0, 120},
    {1.5, 100},
    {  3,  70},
    {  8,  50},
    { 20,  20},
    { 50,  10},
    {125,   4},
    {200,   2}
  }
end

-- smoothly transistions between different steps of FOV angle, depending on distance and previous state
-- target FOV is computed in steps, much like a user would click the zoom button at certain times only, not continuously
-- the transistion from one FOV step to another FOV step happens gradually
function C:getFov(distance, dt)
  -- compute zoom steps (discrete zooming levels, rather than a smooth continuum of fov angles)
  for _,step in ipairs(self.steps) do
    if distance < step[1] then break end
    self.baseFov = step[2]
  end
  -- take user input into account, add/substract extra zoom
  local desiredDelta = 2.5 * dt * (MoveManager.zoomIn - MoveManager.zoomOut) * getCameraFovDeg()
  -- user input is sanitized to not exceed our healthy limits either (plus some margin)
  local maxFov = 100
  local minFov = 2
  local deltaMax = maxFov-self.baseFov-self.userFov + 20
  local deltaMin = minFov-self.baseFov-self.userFov - 1
  local userFovDelta = math.max(deltaMin, math.min(deltaMax, desiredDelta))
  -- userFov is the extra fov due to user input, baseFov is the regular zoom
  self.userFov = self.userFov + userFovDelta
  local newFov = self.baseFov + self.userFov
  if self.mustReset then
    -- instantaneously set the target fov, rather than smoothly transition to it
    self.mustReset = false
    self.fovSmoother:set(newFov)
    return newFov
  else
    return self.smooth(self.fovSmoother, newFov, dt)
  end
end

-- reset custom user FOV (numpad 9/3 keys)
function C:reset()
  self.userFov = 0
end
function C:update(data)
  local distance = data.res.targetPos:distance(data.res.pos)
  data.res.fov = self:getFov(distance, data.dt)
  return true
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
