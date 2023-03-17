-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M ={}
M.instances = {}
local helper = require('scenario/scenariohelper')
local next = next
local function processState(scenario, state, stateData)
  if state == 'onRaceWaypointReached' and scenario.state == 'running' and scenario.raceState == 'racing' then
    for _,instance in ipairs(M.instances) do
      if next(instance.value.wayPointNum) == nil then
        log('E', 'In '..tostring(scenario.name), ' wayPointNum is empty ')
        goto continue
      end
      if next(scenario.lapConfig) == nil then
        log('E', 'In '..tostring(scenario.name), ' lapConfig is empty ')
        goto continue
      end
      ---for scenarios that check speed at waypoint
      local vehWpData = scenario_waypoints.getVehicleWaypointData(instance.vId)
      --print(vehWpData.cur)
      for i = 1, #instance.value.wayPointNum do
        if type(instance.value.wayPointNum[i]) == "number" then
          if vehWpData.cur == instance.value.wayPointNum[i] then
            helper.flashUiMessage(instance.value.wayPointMsg[i],2)
          end
        else
          log('E', 'In '..tostring(scenario.name), ' wayPointNum must be a number ')
          goto continue
        end
      end
      ::continue::
    end
  end
end

local function init(scenario)
  M.instances = {}
  for _,instance in ipairs(scenario.goals.vehicles) do
    if instance.id == 'wayPointAction' then
      if instance.value.wayPointNum and type(instance.value.wayPointNum) ~="table" then
        log('E', 'In '..tostring(scenario.name), ' wayPointNum is not of type array ')
        goto continue
      end
      if not instance.value.wayPointMsg then
        instance.value.wayPointMsg = " "
      end
      table.insert(M.instances, instance)
      ::continue::
    end
  end
end

local function updateFinalStatus(scenario, instance)
end

M.updateFinalStatus = updateFinalStatus
M.init =init
M.processState = processState
return M
