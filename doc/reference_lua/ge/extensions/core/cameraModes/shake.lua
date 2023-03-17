-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init()
  self.isFilter = true
  self.hidden = true
  self.amp = vec3(0.08, 0.05, 0.03)
  self.freq = vec3(0.05, 0.04, 0.03)
  self.timeOffset = vec3(0, math.random(), math.random())
  self.time = 0
end

function C:update(data)
  self.time = self.time + data.dt
  local offset = vec3(
    self.amp.x * math.sin(math.pi * 2 * (self.timeOffset.x + self.time) * self.freq.x),
    self.amp.y * math.sin(math.pi * 2 * (self.timeOffset.y + self.time) * self.freq.y),
    self.amp.z * math.sin(math.pi * 2 * (self.timeOffset.z + self.time) * self.freq.z)
  )

  local rotEuler = vec3(
    offset.x * 10 * math.pi / 180,
    offset.y * 10 * math.pi / 180,
    offset.z * 10 * math.pi / 180
  )
  local q = quatFromEuler(rotEuler.x, rotEuler.y, rotEuler.z)

  data.res.rot = data.res.rot * q
  data.res.pos = data.res.pos + offset
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
