-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.instances = {}

local helper = require('scenario/scenariohelper')
local logTag = 'finishRaceGoal'

local function failedGoal(instance, message)
  -- log("I", logTag, 'failedGoal called...')
  instance.status.result = "failed"
  statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})

  local errMsg = instance.value.failed or message
  local result = { failed = errMsg }
  scenario_scenarios.finish(result)
end

local function passedGoal(instance, message)
  -- log("I", logTag, 'passedGoal called...')
  instance.status.result = "passed"
  statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})

  local finalMsg = instance.value.passed or message
  local result = { msg = finalMsg }
  scenario_scenarios.finish(result)
end

local function processState(scenario, state, stateData)
  -- log("I", logTag, 'processState called...state:'..tostring(state))
  if state == 'onRaceWaypointReached' then
    for _,instance in ipairs(M.instances) do
      if stateData.next == nil then
        if instance.value.mustWin then
          if not instance.status.result then
            if instance.vId == stateData.vehicleId then
              instance.status.result = 'passed'
            else
              instance.status.result = 'failed'
            end
          end
        else
          if instance.vId == stateData.vehicleId then
            instance.status.result = 'passed'
          else
            instance.status.result = 'failed'
          end
        end
      end
    end
  else
    if state == 'onRaceResult' then
      for _,instance in ipairs(M.instances) do
        if not instance.status.result or instance.status.result == 'failed' then
          failedGoal(instance, 'You failed to finish the race.')
        else
          passedGoal(instance, 'You finished the race.')
        end
      end
    end
  end
end

local function init(scenario)
  M.instances = {}
  for _,instance in ipairs(scenario.goals.vehicles) do
    if instance.id == 'finishRace' then
      instance.status.result = nil
      table.insert(M.instances, instance)
    end
  end
end

local function updateFinalStatus(scenario)
  for _,instance in ipairs(M.instances) do
    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
  end
end

M.updateFinalStatus = updateFinalStatus
M.processState = processState
M.init = init

return M
