-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.instances = {}
local logTag = 'timeLimit'
local helper = require('scenario/scenariohelper')
---{"timeLimit":{"maxTime":8,"msg":"used more than 8 sec"}
--Scenario must be completed in less than X time

local function failedGoal(instance)
  instance.status.result = "failed"
  statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})

  local errMsg = instance.value.msg or {txt = "extensions.scenario.timeLimit.failedGoal", context = {maxTime = tostring(instance.value.maxTime)}}
  local result = { failed = errMsg }
  scenario_scenarios.finish(result)
end

local function processState(scenario, state, stateData)
  for _,instance in ipairs(M.instances) do
    --instance.wait = 5
    if state == 'onRaceTick' and instance.value.maxTime~=0 and instance.value.waitTime  then
      if instance.value.countdown and instance.value.countdown~=nil then
        --Count down the time left when below 10 seconds
        local timeleft = instance.value.maxTime - scenario.timer
        if timeleft < instance.wait then
          instance.finish = true
          local countdown = math.floor(timeleft) + 1
          if countdown > 0 and instance.wait > countdown then
            helper.flashUiMessage({txt = "extensions.scenario.timeLimit.checkTime.countdown", context = {countdown = tostring(countdown)}}, 0.5, true)
            instance.wait = countdown
          end
        end
      end
      if scenario.timer > instance.value.maxTime + instance.value.waitTime then
        failedGoal(instance)
        goto continue
      end
    end
    if state == 'onRaceResult' then
      if scenario.finalStatus.finalTime > instance.value.maxTime then
        -- print("inside on raceresult")
        failedGoal(instance)
        goto continue
      else
        instance.status.result = "passed"
      end
    end
    ::continue::
  end
end

local function init(scenario)
  M.instances = {}
  for _,instance in ipairs(scenario.goals.vehicles) do
    if instance.id == 'timeLimit' then
      instance.wait= instance.value.countdown

      if type(instance.value.maxTime) ~="number" and type(instance.value.waitTime) ~="number" then
        log('E', 'In '..tostring(scenario.name), ' maxTime or waitTime have a wrong type it should be a number')
        goto continue
      end

      if instance.value.countdown and type(instance.value.countdown)~="number" then
        log('E', 'In '..tostring(scenario.name), ' countdown has a wrong type it should be a number')
        goto continue
      end
      table.insert(M.instances, instance)
    end
    ::continue::
  end
end

local function updateFinalStatus(scenario, instance)
  for _,instance in ipairs(M.instances) do
    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
  end
end

M.updateFinalStatus = updateFinalStatus
M.init = init
M.processState = processState
return M
