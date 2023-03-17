-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local oldPosition = vec3(0,0,0)
local oldQuat = quatFromEuler(0,0,0)

local targetPosition = vec3(0,0,0)
local targetQuat = quatFromEuler(0,0,0)

local transitionTime = 1
local remainingTime = 0

local function lerpFunction(t)
  return 1-((1-t)*(1-t))
end

local currentPosition = vec3(0,0,0)
local currentQuat = vec3(0,0,0)
local perc = 0
local function onPreRender(dt)
  if remainingTime <= 0 then return end
  remainingTime = remainingTime - dt
  if remainingTime <= 0 then remainingTime = 0 end
  perc = lerpFunction(1 - (remainingTime/transitionTime))
  currentPosition = oldPosition * (1-perc) + targetPosition * perc
  currentQuat = oldQuat:nlerp(targetQuat, perc)

  if not commands.isFreeCamera() then return end

  setCameraPosRot(
    currentPosition.x, currentPosition.y, currentPosition.z,
    currentQuat.x, currentQuat.y, currentQuat.z, currentQuat.w
    )

end

local function lerpTo(pos, rot, time)
  if time <= 0 then
    setCameraPosRot(
      pos.x, pos.y, pos.z,
      rot.x, rot.y, rot.z, quat.w
      )
    return
  end

  oldPosition:set(getCameraPosition())
  local cQ = getCameraQuat()
  oldQuat = quat(cQ.x,cQ.y,cQ.z,cQ.w)

  targetPosition = pos
  targetQuat = rot

  transitionTime = time
  remainingTime = time
end

M.lerpTo = lerpTo
M.onPreRender = onPreRender
return M