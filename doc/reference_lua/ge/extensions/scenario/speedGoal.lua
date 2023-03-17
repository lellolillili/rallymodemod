-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.instances = {}
local logTag = 'speedGoal'

local helper = require('scenario/scenariohelper')
local next = next
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
    local errMsg = instance.value.msg or "extensions.scenario.speedGoal.fail.msg"
    local result = { failed = errMsg }
    scenario_scenarios.finish(result)
  elseif instance.value.purpose == "win" then
    instance.status.result = "passed"
    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
    local winMsg = {txt = instance.value.msg, context = {time = timeStr}} or {txt = "extensions.scenario.speedGoal.win.msg", context = { time = timeStr }}
    local result = { msg = winMsg }
    scenario_scenarios.finish(result)
  end
end

local function playerSpeed(fobjData,instance,scenario)
  if instance.value.delay and scenario.timer <= instance.value.delay then
    return
  end
  --print(instance.value.minSpeed .. " " ..fobjData.vel:length())
  if (instance.value.minSpeed and fobjData.vel:length() < instance.value.minSpeed) or (instance.value.maxSpeed and fobjData.vel:length() > instance.value.maxSpeed) then
    instance.Timeout = instance.Timeout + instance.raceTickTime
    if instance.Timeout % 1 == 0 then
      local countdown = instance.value.maxTimeout - math.modf(instance.Timeout)
      if countdown > 0 then
        helper.flashUiMessage({txt = "extensions.scenario.speedGoal.countdown", context = {countdown = tostring(countdown)}}, 0.5, true)
      end
    end
  else
    instance.Timeout = 0
  end
  if instance.Timeout > instance.value.maxTimeout then
    showMsg(scenario, instance)
    instance.Timeout = 0
  end
end

local function processState(scenario, state, stateData)
  for _,instance in ipairs(M.instances) do
    instance.raceTickTime = 0.25
    if instance.value.maxSpeed == 0 then
      log('E', logTag, 'maxSpeed must be greater than zero')
      goto continue
    end

    local fobjData = map.objects[map.objectNames[instance.vehicleName]]
    local vehicle = scenetree.findObjectById(instance.vId)
    if not fobjData and vehicle then
      vehicle:queueLuaCommand('mapmgr.enableTracking("'..instance.vehicleName..'")')-- reset vehicle (tricky step to prevent executing setMode and initialition in the same time TODO
      goto continue
    end
        ---for scenarios that check speed at waypoint
    if state == 'onRaceTick' then
      local vehWpData = scenario_waypoints.getVehicleWaypointData(instance.vId)
      if vehWpData and instance.value.wayPointNum then
        if next(instance.value.wayPointNum) == nil then
          log('E', logTag, ' wayPointNum is empty ')
          goto continue
        end
        for _,i in ipairs(instance.value.wayPointNum) do
          if type(i) == "number" then
            if vehWpData.cur ==i  then
              playerSpeed(fobjData,instance,scenario)
            end
          else
            log('E', logTag, ' wayPointNum must be a number ')
            goto continue
          end
        end
      else
        playerSpeed(fobjData,instance,scenario)
      end
    end
    ::continue::
  end
end

local function init(scenario)
  M.instances = {}
  for _,instance in ipairs(scenario.goals.vehicles) do
    if instance.id ~= 'speed' then
      goto continue
    end

    if instance.value.minSpeed and type(instance.value.minSpeed)~="number" then
      log('E', logTag, ' minSpeed must contain number value  ')
      goto continue
    end
    if instance.value.maxSpeed and type(instance.value.maxSpeed)~= "number" then
      log('E', logTag, ' maxSpeed must contain number value  ')
      goto continue
    end
    if instance.value.wayPointNum and type(instance.value.wayPointNum) ~="table" then
      log('E', logTag, ' wayPointNum is not of type array ')
      goto continue
    end
    if not instance.value.maxTimeout  then
      instance.value.maxTimeout = 0
    end
    if instance.value.delay and type(instance.value.delay)~="number" then
      log('E', logTag,'delay must contain number value ')
      goto continue
    end
    if instance.value.purpose and type(instance.value.purpose)~="string" then
      log('E', logTag,'purpose is missing in json file or purpose has wrong type ')
      goto continue
    end
    if not instance.value.purpose then
      instance.value.purpose ="fail"
    end
    --[[if not instance.value.delay then
      instance.value.delay = 0.3
    end--]]
    instance.Timeout =0
    table.insert(M.instances, instance)
    ::continue::
  end
end

local function updateFinalStatus(scenario, instance)
  for _,instance in ipairs(M.instances) do
    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
  end
end

M.updateFinalStatus = updateFinalStatus
M.processState = processState
M.init = init

return M
