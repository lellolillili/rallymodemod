-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init()
  self.isGlobal = true
  self.runningOrder = 0.2
  self.isFilter = true
  self.hidden = true
  self.camLastPosRel = vec3(5,5,5)
  self.camLastPosAbs = vec3(0,0,0)
  self.camLastFOV = 90
  self.camLastQDir = quat(1,0,0,1)
  self.camLastNearClip = 0.1
  self.transitionTime = 0
  self:onSettingsChanged()
end

function C:onSettingsChanged()
  local transitionTimeMilliseconds = settings.getValue('cameraTransitionTime') or 300
  local transitionVehicleTimeMilliseconds = settings.getValue('cameraVehicleTransitionTime') or 500
  self.transitionVehicleDuration = transitionVehicleTimeMilliseconds / 1000
  self.transitionDuration = transitionTimeMilliseconds / 1000
end

function C:canTransition(origin, target)
  if self.transitionRequestedType == false then return true end
  local dir = target-origin
  local dist = dir:length()
  if dist > 100 then return false end
  local visibleOneWay = castRayStatic(origin, dir, dist) >= dist
  local visibleOtherWay = castRayStatic(target, -dir, dist) >= dist
  return visibleOneWay and visibleOtherWay
end

function C:update(data)
  local useOldCam = false
  if self.camPathTransitionData then
    self.transitionTime = 0
    self.transitionRequestedType = nil
    self.camPathTransitionData.callback(shallowcopy(data.res))
    self.camPathTransitionData = nil
    useOldCam = true
  end
  if self.transitionRequestedType ~= nil and self.firstTime then
    if self:canTransition(data.res.pos, self.camLastPosAbs) then
      self.camLastPosRel = self.camLastPosAbs - data.pos
      self.transitionTime = self.transitionRequestedType and self.transitionVehicleDuration or self.transitionDuration
    end
    self.transitionRequestedType = nil
  end

  data.res.pos:setSub(data.pos) -- make it relative

  if self.transitionTime > 0 then
    local oldTransitionTime = self.transitionTime
    self.transitionTime = math.max(0, self.transitionTime - data.dt)
    local perc = (self.transitionTime / oldTransitionTime)
    perc = perc * perc
    -- smooth
    data.res.pos = data.res.pos + (self.camLastPosRel - data.res.pos) * perc
    data.res.fov = data.res.fov + (self.camLastFOV - data.res.fov) * perc
    data.res.rot = data.res.rot:nlerp(self.camLastQDir, perc)
  end

  self.camLastPosRel:set(data.res.pos)

  data.res.pos:setAdd(data.pos) -- make it absolute again

  if useOldCam then
    data.res.pos = self.camLastPosAbs
    data.res.fov = self.camLastFOV
    data.res.rot = self.camLastQDir
    data.res.nearClip = self.camLastNearClip
  end
  self.camLastPosAbs:set(data.res.pos)
  self.firstTime = true

  self.camLastQDir:set(data.res.rot)
  self.camLastFOV = data.res.fov
  self.camLastNearClip = data.res.nearClip
  return true
end

function C:start(isVehicleSwitch, camPathTransitionData)
  self.transitionRequestedType = isVehicleSwitch and true or false
  self.camPathTransitionData = camPathTransitionData
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
