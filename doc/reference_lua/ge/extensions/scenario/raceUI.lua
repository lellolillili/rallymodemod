-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local lastWaypointTimes = {}
local currentLap = 1

local function initialise(scenario)
  lastWaypointTimes = {}

  guihooks.trigger('WayPoint', nil)
  guihooks.trigger('RaceLapChange', nil)
end

local function onRaceStart()
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end

  if scenario.initialLapConfig and #scenario.initialLapConfig > 1 then
    guihooks.trigger('WayPoint', 'Checkpoint 0 / '..tostring(#scenario.initialLapConfig) )
  end

  if scenario.lapCount > 1 then
    guihooks.trigger('RaceLapChange', {current = 1, count = scenario.lapCount} )
  end
end

local function onScenarioChange(scenario)
  --log( 'D', 'raceUI', 'onScenarioChange' )
  if not scenario or scenario.state == 'pre-start' then
    guihooks.trigger('WayPoint', nil)
    return
  end
end

local function onRaceWaypointReached( data )
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end

  local playerVehicleId = be:getPlayerVehicleID(0)
  if data.vehicleId ~= playerVehicleId or scenario.disableWaypointTimes then return end

  local curtimeId = #lastWaypointTimes + 1
  local lastTimeId = curtimeId - #scenario.lapConfig
  lastWaypointTimes[curtimeId] = data.time

  if lastTimeId > 1 then
    local lastcheckDiff = ( lastWaypointTimes[curtimeId] - lastWaypointTimes[curtimeId-1]) - (lastWaypointTimes[lastTimeId] - lastWaypointTimes[lastTimeId-1])
    guihooks.trigger('RaceCheckpointComparison', {timeOut = 5000, time = lastcheckDiff} )

    local A = lastWaypointTimes[(currentLap - 1) * #scenario.lapConfig + 1]
    local B = lastWaypointTimes[curtimeId - #scenario.lapConfig]
    local C = lastWaypointTimes[(currentLap - 2)* #scenario.lapConfig + 1]

    local lasttimeDiff = 0
    if A and B and C then
      lasttimeDiff = (lastWaypointTimes[curtimeId] - A) - (B - C)
    end

    guihooks.trigger('RaceTimeComparison', {timeOut = 5000, time = lasttimeDiff} )
  end
  local numberWaypoints = #data.currentLapConfig
  if numberWaypoints >= 1 then
    guihooks.trigger('WayPoint', 'Checkpoint ' .. tostring(data.cur)..' / '..tostring(numberWaypoints) )
  end
end

local function onRaceLap( data )
  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end

  local playerVehicleId = be:getPlayerVehicleID(0)
  if data.vehicleId ~= playerVehicleId then return end

  if scenario.lapCount > 1 then
    currentLap = ( math.min(data.lap + 1, scenario.lapCount ) )
    guihooks.trigger('RaceLapChange', {current = currentLap, count = scenario.lapCount } )
  elseif scenario.lapCount == 0 then
    currentLap = data.lap + 1
    guihooks.trigger('RaceLapChange', nil )
  end
  if #scenario.lapConfig > 1 then
    guihooks.trigger('WayPoint', 'Checkpoint ' .. tostring(#scenario.lapConfig)..' / '..tostring(#scenario.lapConfig) )
  end

  local curTime = string.format("%.3f", data.time) .. 's'
  --guihooks.trigger('ScenarioFlashMessage', {{'Lap ' ..tostring(data.lap) .. ' time: ' .. curTime, 3}} )
  ui_message('lap ' ..tostring(data.lap) .. ' time: '..curTime, 2)
end

M.onScenarioChange = onScenarioChange
M.onRaceWaypointReached = onRaceWaypointReached
M.onRaceLap = onRaceLap
M.onRaceStart = onRaceStart
M.initialise = initialise

return M
