-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init(spring, damping, rotspring)
  self.isFilter = true
  self.hidden = true
  self.k = spring or self.k or 20
  self.damping = damping or self.damping or 5
  self.rotk = rotspring or self.rotk or 3
  self.vel = vec3()
  self.mustReset = true
end

function C:update(data)
  if self.mustReset then
    self.mustReset = false
    self.dir = (data.res.targetPos - data.res.pos):normalized()
  end

  local curDir = (data.res.targetPos - data.res.pos):normalized()
  local force = curDir - self.dir
  force = self.k * force - self.damping * self.vel
  self.vel = self.vel + force * data.dt
  self.dir = (self.dir + self.vel * data.dt):normalized()

  local up = (-self.rotk * data.dt * force:projectToOriginPlane(self.dir) + vec3(0,0,1)):normalized()
  data.res.rot = quatFromDir(self.dir, up)
  return true
end

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
