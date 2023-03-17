-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init(spring, damp, pos)
  self.isFilter = true
  self.hidden = true
  self.spring = spring or self.spring or 30
  self.damp = damp or self.damp or 10
  self.posX = newTemporalSpring(self.spring, self.damp)
  self.posY = newTemporalSpring(self.spring, self.damp)
  self.posZ = newTemporalSpring(self.spring, self.damp)
  if pos then
    self.posX:set(pos.x)
    self.posY:set(pos.y)
    self.posZ:set(pos.z)
  end
end

function C:update(data)
  data.res.pos.x = self.posX:get(data.res.pos.x, data.dt)
  data.res.pos.y = self.posY:get(data.res.pos.y, data.dt)
  data.res.pos.z = self.posZ:get(data.res.pos.z, data.dt)
  return true
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
