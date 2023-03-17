-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 000 -- low first, high later

C.idCounter = 0
function C:getFreeId()
  self.idCounter = self.idCounter +1
  return self.idCounter
end

function C:init()
  self.variables = require('/lua/ge/extensions/flowgraph/variableStorage')(self.mgr)
  self:clear()
end

function C:clear()
  self.variables:clear()
  self.timers = {}
  self.globalTime = {
    real = 0,
    sim = 0,
    raw = 0,
  }
  C.idCounter = 0
end

-- gets the global time depending on the mode.
function C:getGlobalTime(mode)
  if mode == 'dtSim' then return self.globalTime.sim end
  if mode == 'dtReal' then return self.globalTime.real end
  if mode == 'dtRaw' then return self.globalTime.raw end
  return 0
end

-- adds a new timer.
function C:addTimer(data)
  local timer = {
    id = self:getFreeId()
  }
  local id = timer.id
  local mode = data.mode or "dtSim"
  local start = self:getGlobalTime(mode) - (data.time or 0)

  self.variables:addVariable(id.."start",start, "number")
  self.variables:addVariable(id.."mode",mode or 'dtSim', "string")
  self.variables:addVariable(id.."duration",data.duration or 5, "number")
  timer.start = self.variables:getFull(id.."start")
  timer.mode = self.variables:getFull(id.."mode")
  timer.duration = self.variables:getFull(id.."duration")
  timer.isPaused = false
  self.timers[id] = timer
  return id
end

-- gets the full timer object.
function C:getTimer(id) return self.timers[id] end

-- sets some field for the timer, using the variables.
function C:set(id, field, val) self.variables:change(id..field, val) end

-- pauses or unpauses a timer.
function C:setPause(id, val)
  local timer = self.timers[id]
  if timer.pauseFlag ~= nil then
    log("W","","Timerflag has already been set for timer " .. id.."!")
  end
  if timer.isPaused == (val or false) then return end
  timer.pauseFlag = val
end

-- sets the elapsed time on a timer.
function C:setElapsedTime(id, time)
  if self.timers[id].isPaused then
    self.timers[id].elapsedTime = time
  else
    self.variables:change(id.."start", self:getGlobalTime(self.timers[id].mode.value) - time)
  end
end

-- sets the desired mode of the timer
function C:setMode(id, mode)
  self.variables:set(id.."mode", mode)
  if not self.timers[id].isPaused then
    local elapsedTime = self:getElapsedTime(id)
    self.variables:set(id.."start", self:getGlobalTime(mode) - elapsedTime)
  end
end

-- gets the elapsed time on a timer.
function C:getElapsedTime(id)
  if self.timers[id].isPaused then
    return self.timers[id].elapsedTime
  else
    return self:getGlobalTime(self.timers[id].mode.value) - self.timers[id].start.value
  end
end

-- checks if the timer is complete.
function C:isComplete(id)
  return self:getElapsedTime(id) >= self.timers[id].duration.value
end

function C:onUpdate(dtReal, dtSim, dtRaw)
  self.globalTime.real = self.globalTime.real + dtReal
  self.globalTime.sim = self.globalTime.sim + dtSim
  self.globalTime.raw = self.globalTime.raw + dtRaw
end

-- called at the end, finalizing all the merge strats.
function C:afterTrigger()
  for id, timer in pairs(self.timers) do
    -- finalize the pauseFlag
    if timer.pauseFlag ~= nil then
      self.variables:finalizeChanges() -- update in case the startTime has changed.
      local now = self:getGlobalTime(timer.mode.value)
      -- if pauseFlag, then convert to elapsed time. otherwise, adjust start time.
      if timer.pauseFlag then
        timer.elapsedTime = now - timer.start.value
        timer.isPaused = true
      else
        self.variables:change(id.."start",  now - timer.elapsedTime)
        timer.elapsedTime = nil
        timer.isPaused = false
      end
      timer.pauseFlag = nil
    end
  end

  self.variables:finalizeChanges()
end

function C:executionStopped()
  self:clear()
end

return _flowgraph_createModule(C)