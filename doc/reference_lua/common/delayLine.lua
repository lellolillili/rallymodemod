-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--A delayLine can be used to delay given data over time.
--It was created with the intention of simulating how it takes time for left-over fuel from the engine to travel down
--the exhaust pipes and reach the end where it can combust. However, the implementation is generic enough to be useful
--in other scenarios where data needs to be delayed over time.
--Each "data packet" that is pushed down the line is delayed the same amount of time (set at init). The line needs to polled for data
--at regular intervals to fetch whatever reached the end.

local push = function(self, payload)
  table.insert(self.data, payload)
  table.insert(self.times, self.currentTime + self.delay)
  self.length = self.length + 1
end

local pop = function(self, dt)
  self.currentTime = self.currentTime + dt
  if self.length == 0 then return nil end

  local delayedData = {}
  local finishedKeysCount = 0
  for i = 1, self.length, 1 do
    if self.times[i] <= self.currentTime then
      table.insert(delayedData, self.data[i])
      finishedKeysCount = finishedKeysCount + 1
    end
  end

  for _ = 1, finishedKeysCount, 1 do
    table.remove(self.data, 1)
    table.remove(self.times, 1)
    self.length = self.length - 1
  end

  return delayedData
end

local popSum = function(self, dt)
  self.currentTime = self.currentTime + dt
  if self.length == 0 then return 0 end

  local dataSum = 0
  local finishedKeysCount = 0
  for i = 1, self.length, 1 do
    if self.times[i] <= self.currentTime then
      dataSum = dataSum + self.data[i]
      finishedKeysCount = finishedKeysCount + 1
    else
      break
    end
  end

  for _ = 1, finishedKeysCount, 1 do
    table.remove(self.data, 1)
    table.remove(self.times, 1)
    self.length = self.length - 1
  end

  return dataSum
end

local peek = function(self, dt)
  if self.length == 0 then return nil end

  local delayedData = {}
  for i = 1, self.length, 1 do
    if self.times[i] <= self.currentTime + dt then
      table.insert(delayedData, self.data[i])
    end
  end

  return delayedData
end

local function reset(self)
  self.length = 0
  self.currentTime = 0
  self.data = {}
  self.times = {}
end

local methods = {
  push = push,
  peek = peek,
  pop = pop,
  popSum = popSum,
  reset = reset,
}

local new = function(delay)
  local r = {delay = delay, length = 0, currentTime = 0, data = {}, times = {}}

  return setmetatable(r, {__index = methods})
end

return {
  new = new,
}
