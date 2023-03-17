-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M ={}
M.instances = {}
local helper = require('scenario/scenariohelper')

local function showMsg(scenario,instance)
  local finalTime = scenario.timer
  local minutes = math.floor(finalTime / 60);
  local seconds = finalTime - (minutes * 60);
  local timeStr = ''
  if minutes > 0 then
    timeStr = string.format("%02.0f:%05.2f", minutes, seconds)
  else
    timeStr = string.format("%0.2f", seconds) .. 's'
  end
  if instance.value.purpose == "fail" then
    instance.status.result = "failed"
    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
    local errMsg = instance.value.msg or "extensions.scenario.damageGoal.fail.msg"
    local result = { failed = errMsg }
    scenario_scenarios.finish(result)
    return
  elseif instance.value.purpose == "win" then
    instance.status.result = "passed"
    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
    local winMsg = {txt = instance.value.msg, context = {timeStr = timeStr}} or {txt = "extensions.scenario.damageGoal.win.msg", context = {timeStr = timeStr}}
    local result = { msg = winMsg }
    scenario_scenarios.finish(result)
    return
  end
end

local function processState(scenario, state, stateData)
  for _,instance in ipairs(M.instances) do
    local fobjData = map.objects[map.objectNames[instance.vehicleName]]
    if not fobjData  then
      helper.trackVehicle(instance.vehicleName, instance.vehicleName) -- reset vehicle (tricky step to prevent executing setMode and initialition in the same time TODO
      goto continue
    end

    if state == 'onRaceTick' then
      if instance.value.damageLimit and instance.value.damageThreshold and fobjData.damage > 0 and fobjData.damage < instance.value.damageLimit then
        local progress = math.floor((fobjData.damage / instance.value.damageLimit) * 100)
        local thresholdPercentage = ((instance.value.damageThreshold / instance.value.damageLimit) * 100)
        if (progress - instance.lastProgress) >= thresholdPercentage then
          local progressStr = tostring(progress)
          if instance.value.purpose == "win" then
            helper.flashUiMessage({txt = "extensions.scenario.damageGoal.checkDamage.win.msg", context = {damage = progressStr} }, 1)
          elseif instance.value.purpose == "fail" then
            helper.flashUiMessage({txt = "extensions.scenario.damageGoal.checkDamage.fail.msg", context = {damage = progressStr}}, 1)
          end
        end
        instance.lastProgress = progress
      end
      if (instance.value.damageLimit and fobjData.damage > instance.value.damageLimit and fobjData.damage ~= 0) then
        showMsg(scenario,instance)
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
    if instance.id == 'damage' then
      if instance.value.damageLimit and type(instance.value.damageLimit) ~= "number" then
        log('E', 'In '..tostring(scenario.name), ' damageLimit must contain number value  ')
        goto continue
      end
      if instance.value.damageThreshold and type(instance.value.damageThreshold) ~= "number" then
        log('E', 'In '..tostring(scenario.name), ' damageThreshold must contain number value  ')
        goto continue
      end
      if instance.value.purpose and type(instance.value.purpose)~="string" then
        log('E', 'In '..tostring(scenario.name),'purpose is missing in json file or purpose has wrong type ')
        goto continue
      end
      if not instance.value.purpose then
        instance.value.purpose ="fail"
      end

      instance.lastProgress = 0
      table.insert(M.instances, instance)
      ::continue::
    end
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
