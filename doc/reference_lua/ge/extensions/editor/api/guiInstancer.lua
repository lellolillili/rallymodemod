-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init()
  self.instances = {} -- the instances for this gui window
  self.nextInstanceIndex = 1 -- we start at 1, keeping the Lua standard for array indices
end

function C:addInstance()
  if tableIsEmpty(self.instances) then
    self.nextInstanceIndex = 1
  end
  self.instances[self.nextInstanceIndex] = { locked = false }
  self.nextInstanceIndex = self.nextInstanceIndex + 1
  return self.nextInstanceIndex - 1
end

function C:removeInstance(instanceIndex)
  self.instances[instanceIndex] = nil
end

function C:serialize(name, state)
  state[name] = { instances = self.instances, nextInstanceIndex = self.nextInstanceIndex }
end

function C:deserialize(name, state)
  if state[name] then
    self.instances = state[name].instances or {}
    self.nextInstanceIndex = state[name].nextInstanceIndex or 1
  end
end

return function()
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init()
  return o
end