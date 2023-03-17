-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init(factor)
  self.hidden = true
  self.factor = factor or self.factor or 0.2
  self.offset = vec3()
  self.timeSinceRandom = 100000
end

function C:update(data)
  self.timeSinceRandom = self.timeSinceRandom + data.dt
  if self.timeSinceRandom > 0.1 then
    self.offset = vec3((math.random()-0.5) * self.factor, (math.random()-0.5) * self.factor, (math.random()-0.5) * self.factor)
    self.timeSinceRandom = 0
  end
  data.res.pos = data.res.pos + self.offset
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
