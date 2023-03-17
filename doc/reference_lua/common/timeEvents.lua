-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper that lets you schedule things into the future
-- works like `schedule()`

-- created by BeamNG

--[[ example usage:

local events = require('timeEvents').create()

-- print sth in 5 seconds
events:addEvent( 5, function() print ("hello world!") end)

-- update the module in the main update loop:
events:process(dtSim)

--]]

local M = {}

local mt = {}
mt.__index = mt

function mt:addEvent(time, fn)
  table.insert(self, {fn = fn, time = time})
end

function mt:clear()
  table.clear(self)
end

function mt:process(dt)
  local size = #self
  for i = size, 1, -1 do
  self[i].time = self[i].time - dt
  if self[i].time < 0 then
    self[i].fn()
    table.remove(self, i)
  end
  end
end

function M.create()
  local data = {}

  setmetatable(data, mt)
  return data
end

return M