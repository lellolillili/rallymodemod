-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- A simple event (delegates) class

Event = {}
Event.__index = Event

local ERROR_FUN_NOT_FUNCTION = 'Wrong parameter type: must be a function'

local function is_function(fun)
  if fun and type(fun) == 'function' then
    return true
  else
    return false
  end
end

local function check_function(fun)
  if not is_function(fun) then error(ERROR_FUN_NOT_FUNCTION) end
end

function Event.add(self, fun)
  check_function(fun)
  self.__subscribers[fun] = true
end

function Event.remove(self, fun)
  check_function(fun)
  self.__subscribers[fun] = nil
end

function Event.clear(self)
  self.__subscribers = {}
end

function Event.call(self, ...)
  for f, _ in pairs(self.__subscribers) do f(...) end
end

Event.__call = Event.call

function Event.new()
  return setmetatable({__subscribers = {}}, Event)
end