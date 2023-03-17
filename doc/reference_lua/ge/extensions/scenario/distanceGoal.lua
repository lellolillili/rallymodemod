-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.instances = {}
local helper = require('scenario/scenariohelper')
----------------------------------
local function showMsg(scenario, instance)
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

    local errMsg = instance.value.msg or "extensions.scenario_scenarios.distanceGoal.fail.msg"
    local result = { failed = errMsg }
    scenario_scenarios.finish(result)
    return
  elseif instance.value.purpose == "win" then
    instance.status.result = "passed"
    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
    local winMsg = {txt = instance.value.msg, context = {timeStr = timeStr}} or {txt = "extensions.scenario.distanceGoal.win.msg", context = {timeStr = timeStr}}
    local result = { msg = winMsg }
    scenario_scenarios.finish(result)
    return
  end
end

local function processState(scenario, state, stateData)
  for _,instance in ipairs(M.instances) do
    local targetobj= helper.getVehicleByName(instance.value.target)

    if not targetobj or not instance.vId then
      log('E', 'In '..tostring(scenario.name),"there is no object called " ..instance.value.target)
      goto continue
    end

    --distance instance: Distance between two vehicles must not be lower(minDistance) or higher(maxDistance) than X
    local vehicle = scenetree.findObjectById(instance.vId)
    if state == 'onRaceTick' and vehicle then
      local dis = (vehicle:getPosition() - targetobj:getPosition() ):len()
      --print("inside maxDistance check")
      if instance.value.distanceEnable then
        if dis < instance.value.distanceEnable then
          --Check if we are close enough to our target to actually start the distance check
          instance.status.checkForCarDistance = true
        end

        --print("CheckForCarDistance")
        if instance.status.checkForCarDistance then
          if (instance.value.maxDistance and  dis > instance.value.maxDistance) or (instance.value.minDistance and dis < instance.value.minDistance) then
            showMsg(scenario, instance)
          end
        end
      else
        if (instance.value.maxDistance and  dis > instance.value.maxDistance) or (instance.value.minDistance and dis < instance.value.minDistance) then
          showMsg(scenario, instance)
        end
      end

      if scenario.targetName then
          local distance = helper.getDistanceBetweenSceneObjects(instance.vehicleName, scenario.targetName)
          if distance >= 0 and distance <= 5 then
              --print("distance " ..distance)
              instance.status.result = "failed"
              statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})

              local result = { failed = "extensions.scenario_scenarios.DistanceBetweenSceneObjects.fail.msg" }
              scenario_scenarios.finish(result)
              return
          else
              instance.status.result = "passed"
          end
      end
    end
    ::continue::
  end
end

local function init(scenario)
  M.instances = {}
  for _,instance in ipairs(scenario.goals.vehicles) do
    if instance.id == 'distance' then
      if instance.value.maxDistance and type(instance.value.maxDistance) ~= "number" then
        log('E', 'In '..tostring(scenario.name), ' maxDistance must contain number value')
        goto continue
      end
      if instance.value.distanceEnable and type(instance.value.distanceEnable) ~= "number" then
        log('E', 'In '..tostring(scenario.name), ' distanceEnable must contain number value')
        goto continue
      end
      if instance.value.minDistance and type(instance.value.minDistance) ~= "number" then
        log('E', 'In '..tostring(scenario.name), ' minDistance must contain number value')
        goto continue
      end
      if instance.value.purpose and type(instance.value.purpose)~="string" then
        log('E', 'In '..tostring(scenario.name),'purpose is missing in json file or purpose has wrong type ')
        goto continue
      end
      if not instance.value.purpose then
        instance.value.purpose ="fail"
      end
      instance.status.checkForCarDistance = false
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
