-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init()
  self.isGlobal = true
  self.hidden = true
  self.cameraName = nil
  self.camLastBulletSpeed = nil
  self.camT = 0.0
  self.targetOverride = nil
end

function C:update(data)
  if not self.cameraName then
    log("D", "", "cameraName is null, leaving observer cam")
    return
  end

  local cam = scenetree.findObject(self.cameraName)
  if not cam then
    log("E", "", "Associated observer camera does not exist: "..dumps(self.cameraName))
    return
  end

  local camPos = vec3(cam:getPosition())

  if cam.Speed and tonumber(cam.Speed) then
    if self.camLastBulletSpeed ~= cam.Speed then
      bullettime.set(1/cam.Speed)
      self.camLastBulletSpeed = cam.Speed
      if cam.showApps ~= '1' and cam.Speed ~= '1' then
        guihooks.trigger('ShowApps', false)
      end
    end
  elseif self.camLastBulletSpeed then
      bullettime.set(1)
      self.camLastBulletSpeed = nil
      guihooks.trigger('ShowApps', true)
  end

  local blendSpeed = cam.blendSpeed or 50

  if self.camT < 1.0 then
    self.camT = clamp(data.dt*blendSpeed + self.camT, 0, 1)

    if cam.PositionMove then
      local targetPos = vec3():fromString(cam.PositionMove)
      camPos = camPos + (targetPos - camPos) * self.camT
    end
  end


  if self.targetOverride then
    local targetObject = scenetree.findObject(self.targetOverride)
    if targetObject then
      --log('A','observer','self.targetOverride: ' ..dumps(self.targetOverride))
      data.pos = vec3(targetObject:getPosition())
    end
  end

  local camPosDelta = data.pos:distance(camPos)
  local dir = (data.pos - camPos):normalized()
  local qdir = quatFromDir(dir)

  local targetFOV = cam.targetFOV and tonumber(cam.targetFOV) or (90 - camPosDelta * 3)

  -- application
  data.res.pos = camPos
  data.res.rot = qdir
  data.res.fov = math.max(10, targetFOV)

  return true
end

-- Called when setGlobalCameraByName is called (basically when switching)
function C:setCustomData(customData)
  self:setCamera(customData.cam, customData.targetOverride)
end

function C:setCamera(cam, targetOverride)
  self.cameraName = cam and cam:getField('name', '') or nil

  if self.camLastBulletSpeed then
    bullettime.set(1)
    self.camLastBulletSpeed = nil
    guihooks.trigger('ShowApps', true)
  end

  self.camT = 0.0

  self.targetOverride = targetOverride
end

function C:onCameraChanged(focused)
  if focused then
    guihooks.trigger('onCameraNameChanged', {name = 'observer'})
    extensions.hook('onCameraModeChanged', 'observer')
  else
    if scenario then guihooks.trigger('appContainer:loadLayoutByType', "scenario") end
    self:setCamera(nil)
  end
end

function C:onScenarioRestarted()
  self:setCamera(nil)
end
function C:onScenarioChange(scenario)
  if not scenario then
    self:setCamera(nil)
  end
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
