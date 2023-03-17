-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- tracks loading times of things in vehicle lua

local M = {}

-- the current event stack of performance related timing events
local eventStack = {}
local eventStackSize = 0

-- the history for reporting
local eventHistory = {} -- format: 1 = label, 2 = starttime, 3 = stoptime, 4 = diff

local function pushEvent(label)
  -- record size separatly is faster
  table.insert(eventStack, {label, os.clock() * 1000})
  eventStackSize = eventStackSize + 1
  profilerPushEvent(label)
end

local function popEvent()
  -- record time taken and add it to the history table
  local evt = eventStack[eventStackSize]
  evt[3] = os.clock() * 1000
  evt[4] = evt[3] - evt[2] -- time diff
  table.insert(eventHistory, evt)

  -- remove from the stack
  table.remove(eventStack, eventStackSize)
  eventStackSize = eventStackSize -1

  profilerPopEvent()
end

local function onExtensionLoaded()
end

local function printReport()
  local logThreshold = 5 -- in ms, use 0 to display all timings
  log("I", "core_performance", "List of items that took more than " .. logThreshold .. " ms:")
  for _, t in pairs(eventHistory) do
    if t[4] > logThreshold then
      log("I", "core_performance", "  * " .. rpad(t[1], 34, " ") .. " = " .. lpad(string.format("%5.1f", t[4]), 8, " ") .. " ms")
    end
  end
end

local function saveReportToCSV(filename)
  local f = io.open(filename, "w")
  if f then
    table.sort(
      eventHistory,
      function(a, b)
        return a[4] > b[4]
      end
    )
    f:write(";name, time in ms\n")
    for _, vv in ipairs(eventHistory) do
      f:write(vv[1] .. ", " .. tostring(vv[4]) .. "\n")
    end
    f:close()
  end
end

M.onExtensionLoaded = onExtensionLoaded

M.pushEvent = pushEvent
M.popEvent = popEvent

M.printReport = printReport
M.saveReportToCSV = saveReportToCSV
return M
