-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init(dtFuture)
  self.isFilter = true
  self.hidden = true
  self.dtFuture = dtFuture or self.dtFuture or 0.1
end

function C:update(data)
  data.res.targetPos:setAdd(self.dtFuture * data.vel)
  data.res.rot = quatFromDir((data.res.targetPos - data.res.pos):normalized())
  return true
end

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
