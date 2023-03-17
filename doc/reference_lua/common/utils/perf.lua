 -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- simple performance tracking library that hooks into calls
-- created by BeamNG

local M = {}

--[[

how to use:
1) use luadebug UI module
2) use for small scale, target oriented perforamance debugging:

perf.enable(1)
-- your code should execute here
perf.disable()
perf.saveDataToCSV('vehicleloading.csv')

--]]

local timers = {} -- the timer objects
local timings_tmp = {} -- time sums
local calls_tmp = {} -- time count

M.data = {} -- the statistics

local windowSize = 2 -- stats every X seconds
local sec = 0 -- timer that counts the frame timings to get stats for 1 sec
local frames = 0 -- counts the frames for the timeframe

local guiHook = nil
local srcData = {}

local globalTimer = (HighPerfTimer or hptimer)()

local function nop()
end

local function start(name)
  if timers[name] == nil then
    timers[name] = (HighPerfTimer or hptimer)()
  else
    timers[name]:reset()
  end
end

local function stop(name)
  if not timers[name] then return end
  if not timings_tmp[name] then
    timings_tmp[name] = 0
    calls_tmp[name] = 0
  end
  timings_tmp[name] = timings_tmp[name] + timers[name]:stop()
  calls_tmp[name] = calls_tmp[name] + 1
end

local function _update()
  local used_mem, _ = gcinfo()
  M.data = {frameCount = frames, size = windowSize, memory = used_mem}
  tableMerge(M.data, srcData)
  frames = 0
  local fcts = {}
  for k,v in pairs(timings_tmp) do
    if calls_tmp[k] > 0 then
      local _s = (timings_tmp[k] * calls_tmp[k]) / (windowSize*1000)
      table.insert(fcts, { f=k, t=timings_tmp[k], c=calls_tmp[k], s=_s })
      timings_tmp[k] = 0
      calls_tmp[k] = 0
    end
  end
  M.data.fcts = fcts
  if guiHook then
    guihooks.trigger(guiHook, M.data)
  end
end

local function update()
  local dt = globalTimer:stopAndReset() / 1000
  sec = sec + dt
  frames = frames + 1
  if sec > windowSize then
    sec = sec - windowSize
    _update()
  end
end

local function getData()
  _update()
  return M.data
end

local function saveDataToCSV(filename)
  local d = getData()
  local f = io.open(filename, "w")
  if not f then return false end
  table.sort(d.fcts, function(a, b) return a.s > b.s end)
  f:write(";function, time\n")
  for _,vv in ipairs(d.fcts) do
    f:write(vv.f .. ', ' .. tostring(vv.s) .. "\n")
  end
  f:close()
end

local function trace(event, line)
  local s = debug.getinfo(2)
  --log('D', 'luaperf', event .. ' = ' .. s.what..'_'..s.source..':'..s.linedefined)
  if event == 'call' then
    start(s.what..'_'..s.source..':'..s.linedefined)
  elseif event == 'return' then
    stop(s.what..'_'..s.source..':'..s.linedefined)
  end
end

local function enable(_windowSize, _guiHook, _srcData)
  M.update = update
  windowSize = _windowSize or 10
  guiHook = _guiHook
  srcData = _srcData or {}
  debug.sethook(trace, "cr")
end

local function disable()
  M.update = nop
  --M.data = {}
  --M.frames = 0
  debug.sethook()
end

-- public interface
M.update = nop
M.enable  = enable
M.disable = disable
M.getData = getData
M.saveDataToCSV = saveDataToCSV

return M