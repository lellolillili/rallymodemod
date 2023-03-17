-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

-- called when this object is created. initialize variables here (but dont spawn objects)
function C:init(id)
end

-- called every frame to update the visuals.
function C:update()
    --local color = ColorF(0.91,0.05,0.48,0.5)
    --debugDrawer:drawLine(vec3(self.pos + vec3(0,0,3)), vec3(self.pos + vec3(0,0,20)), color)
end

function C:setToCheckpoint(wp, mode)
end

function C:setMode(mode)
end

-- visibility management
function C:setVisibility(v)
end

function C:hide() self:setVisibility(false) end
function C:show() self:setVisibility(true)  end

-- creates neccesary objects
function C:createMarkers()
end

-- destorys/cleans up all objects created by this
function C:clearMarkers()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end