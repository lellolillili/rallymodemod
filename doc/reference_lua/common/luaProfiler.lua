-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--[[
Usage example:

local p = LuaProfiler("my profiler")

function onUpdatePhysics()
  p:start()

  stuff()
  p:add("physics stuff")
end

function onUpdateGfx(dtSim, dtReal)
  p:start()

  foo()
  p:add("foo")

  for i=1,10 do
    bar()
    baz()
    p.add("bar&baz")
  done

  qux()
  p:add("qux")

  p:finish(true)          -- show stats each frame
  --p:finish(dtSim>0)     -- show stats each frame (except during pause)
  --p:finish(dtSim>0, dtReal) -- show stats when a peak is detected (except during pause)
end
]]

local C = {}
C.__index = C

-- constructor; title is only displayed in logs, can be used to differentiate between different profilers running at the same time
function C:init(title)
  self.title = title
end

-- call once after each section of code whose running time you want to profile
function C:add(section)
  if not self.timer then
    log("E", "", "luaProfiler: Missing start")
    print(debug.tracesimple())
    return
  end
  -- store previous section time
  if section ~= nil then
    local garbage = self.garbagePrev and (collectgarbage("count")*1024 - self.garbagePrev) or nil
    local time = self.timer:stopAndReset()
    local foundSection = nil
    self.sections = self.sections or {}
    for _,v in ipairs(self.sections) do
      if v.section == section then
        foundSection = v
        break
      end
    end
    if foundSection then
      foundSection.time = foundSection.time + time
      foundSection.garbage = foundSection.garbage + garbage
      foundSection.runs = foundSection.runs + 1
    else
      table.insert(self.sections, {
         section = section
        ,time = time
        ,garbage = garbage
        ,runs = 1
      })
    end
  end

  -- reset or create timer
  self.timer = self.timer or (HighPerfTimer or hptimer)()
  self.timer:stopAndReset()
  self.garbagePrev = collectgarbage("count") * 1024
end

local function format(value, decimals, pad, decimalSeparator)
  local factor = 10^decimals
  local result = math.floor(value*factor + 0.5) / factor
  local k
  while decimalSeparator do
    result, k = string.gsub(result, "^(-?%d+)(%d%d%d)", '%1,%2')
    if k == 0 then break end
  end
  return lpad(result, pad or 0, ' ')
end

local function computeStats(result, slow, fast, value, dt)
  result.smSlow = result.smSlow or newTemporalSmoothing(slow)
  result.smFast = result.smFast or newTemporalSmoothing(fast)
  local smTotalSlow = result.smSlow:getUncapped(value, dt)
  local smTotalFast = result.smFast:getUncapped(value, dt)
  result.unstableRel = math.abs(smTotalFast - smTotalSlow) / smTotalSlow
  result.deltaRel = (value-smTotalSlow) / smTotalSlow
  result.average = smTotalSlow
end

-- needs to be used once per independent-function* that you want to profile
-- (*) which doesn't share any common caller ancestor with a function that already used start()
function C:start()
  self.timer = self.timer or (HighPerfTimer or hptimer)()
  self.timer:stopAndReset()
  self.garbagePrev = collectgarbage("count") * 1024
end

-- compute: will silence all logs if 'false'. use as a quick way to disable profiling without having to remove all 'add(...)' calls
-- dt: is used to compute averages and find out peaks (enables peak detection)
function C:finish(compute, dt)
  local detectPeaks = type(dt) == "number"
  dt = detectPeaks and dt or 0
  if compute ~= false then
    local currTotalTime = 0.0
    local currTotalGarbage = 0
    self.stats = self.stats or {}
    self.sections = self.sections or {}
    for _, t in ipairs(self.sections) do
      currTotalTime = currTotalTime + t.time
      currTotalGarbage = currTotalGarbage + math.max(0, t.garbage)
      self.stats[t.section] = self.stats[t.section] or {}
      computeStats(self.stats[t.section], 0.5, 5, t.time, dt)
    end
    self.stats.total = self.stats.total or {}
    computeStats(self.stats.total, 0.5, 5, currTotalTime, dt)
    local peakDetected = (self.stats.total.deltaRel > 0.5) and (self.stats.total.unstableRel < 0.1)
    peakDetected = true
    if (not detectPeaks) or (detectPeaks and peakDetected) then
      local title = self.title
      local time = currTotalTime
      local garbage = currTotalGarbage
      local width = 50
      local msg = format(garbage, 3, 8) .. " bytes"
      msg = msg .." " .. format(time, 2, 8)
      if detectPeaks then msg = msg.." ms vs "..format(self.stats.total.average, 2, 8).." ms (+"..format(self.stats.total.deltaRel*100, 0, 5).."%)"
      else msg = msg.." ms" end
      msg = msg.." TOTAL "..title
      log("I", "", msg)
      for _, t in ipairs(self.sections) do
        local localPeakDetected = self.stats[t.section].deltaRel > 0.3
        local title = t.section..(t.runs > 1 and (" (x"..t.runs..")") or "")
        local time = t.time
        local garbage = t.garbage
        if (not detectPeaks) or (detectPeaks and localPeakDetected) then
          --local msg = rpad(title, width, " ").." = "..format(time, 3, 8)
          local msg = format(garbage, 3, 8) .. " bytes"
          msg = msg .." " .. format(time, 2, 8)
          if detectPeaks then msg = msg.." ms vs "..format(self.stats[t.section].average, 2, 8).." ms (+"..format(self.stats[t.section].deltaRel*100, 0, 5).."%)"
          else msg = msg.." ms" end
          msg = msg .. "   " .. title
          log("I", "", msg)
        end
      end
    end
  end
  self.timer = nil
  self.sections = nil
end

function LuaProfiler(...)
  local o = {}
  setmetatable(o, C)
  o:init(...)
  return o
end
