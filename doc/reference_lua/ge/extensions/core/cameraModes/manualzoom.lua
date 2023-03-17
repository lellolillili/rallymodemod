-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init(fovDefault, fovMin, fovMax, uiTxt)
  self.isFilter = true
  self.hidden = true
  self.fovDefault = fovDefault or 80
  self.fovMin = fovMin or 10
  self.fovMax = fovMax or 120
  self.uiTxt = uiTxt or "ui.camera.fov"
  self:reset()
end

function C:reset()
  self.fov = self.fovDefault
end

function C:update(data)
  local fovDelta = 4.5*data.dt*(MoveManager.zoomIn - MoveManager.zoomOut) * self.fov
  local fov = clamp(self.fov + fovDelta, self.fovMin, self.fovMax)
  local mustNotifyFov = round(fov*10) ~= round((self.lastNotifiedFov or self.fov) * 10)
  if mustNotifyFov then
    self.lastNotifiedFov = fov
    ui_message({txt=self.uiTxt, context={degrees=fov}}, 2, 'cameramode')
  end
  self.fov = fov
  data.res.fov = self.fov
  return mustNotifyFov
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
