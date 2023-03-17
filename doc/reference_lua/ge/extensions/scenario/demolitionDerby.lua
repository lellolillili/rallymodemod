-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local lastPosition = {}
local vehiclesStopTicks = {}
local scenarioVehicles = {}
local activePlayers = 0
local maxStopTicks = 15
local tickCounter = 0

local function reset()
    scenarioVehicles = {}
    activePlayers= 0
    lastPosition = {}
    vehiclesStopTicks = {}
end

local function onScenarioChange(sc)
    local scenario = scenario_scenarios.getScenario()
    if not scenario then reset() return end

    if scenario.state == 'running' and scenario.vehicles then
      reset()
      for vName, vData in pairs(scenario.vehicles) do
        local vObj = scenetree.findObject(vName)
        if vObj then
          scenarioVehicles[vName] = vObj
          activePlayers = activePlayers + 1
          lastPosition[vName] = vObj:getPosition()
          vehiclesStopTicks[vName] = 0
        end
      end
    end
end

-- called before rendering a graphics frame
local function onPreRender(dt)
    local scenario = scenario_scenarios.getScenario()
    if not scenario or scenario.state ~= 'running' then return end

    tickCounter = tickCounter + dt
    if tickCounter < 1 then return end
    tickCounter = 0

    local playersMoving = {}
    local playersStoped = {}
    for vName, vObj in pairs(scenarioVehicles) do
        if not lastPosition[vName] then lastPosition[vName] = vObj:getPosition() end
        local distance = (vObj:getPosition() - lastPosition[vName]):len()
        if distance > 1 then
            lastPosition[vName] = vObj:getPosition()
            vehiclesStopTicks[vName] = 0
            table.insert( playersMoving, vName )
        else
            vehiclesStopTicks[vName] = vehiclesStopTicks[vName] + 1
            if vehiclesStopTicks[vName] > maxStopTicks then
                table.insert( playersStoped, vName )
            end
        end
    end

    if #playersMoving == 1 and #playersStoped == activePlayers - 1 then
        local result = {msg = playersMoving[1]..' WINS!!!'}
        scenario_scenarios.finish(result)
    end
end

M.onScenarioChange = onScenarioChange
M.onPreRender = onPreRender

return M
