-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init()
  self.isGlobal = true
  self.runningOrder = 1
  self.isFilter = true
  self.hidden = true
end

local gameNotified
function C:update(data)
  if not levelLoaded then
    if not gameNotified then
      log("W", "", "No camera available, no level loaded either")
      gameNotified = true
    end
    return
  end
  gameNotified = nil

  setCameraFovDeg(data.res.fov)
  setCameraPosRot(data.res.pos.x, data.res.pos.y, data.res.pos.z, data.res.rot.x, data.res.rot.y, data.res.rot.z, data.res.rot.w)
  SceneManager.setNearClip(data.res.nearClip)
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
