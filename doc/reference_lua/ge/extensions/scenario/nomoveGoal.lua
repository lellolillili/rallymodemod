-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.instances = {}
local logTag = 'noMoveGoal'
local count = 0
local function processState(scenario, state, stateData)
  for _,instance in ipairs(M.instances) do
    if not instance.vId and not instance.warnedVehicleMissing then
      log( 'E', logTag, "no fobj in nomove")
      instance.warnedVehicleMissing = true
      goto continue
    end
    if state == 'onCountdownEnded' then
      local vehicle = instance.vId and scenetree.findObjectById(instance.vId) or nil
      if vehicle then
        instance.startPos = vehicle:getPosition()
      end
      goto continue
    end

    if state == 'onRaceResult' or state=='onRaceTick' then
      local vehicle = scenetree.findObjectById(instance.vId)
      if vehicle and (instance.startPos - vehicle:getPosition()):len() > 0.1 then
        log('D', logTag, 'checkRaceGoals failed: '..instance.vehicleName..' moved '..tostring(instance.startPos)..' '..tostring( vehicle:getPosition() ) )
        if instance.value.triggerEndOnly then
          scenario_scenarios.endScenario(0.25)
        else
          instance.status.result = "failed"
          scenario_scenarios.finish({ failed = instance.value.msg })
        end
      else
        if not instance.value.triggerEndOnly then
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
    if instance.id == 'nomove' then
      local vehicle = instance.vId and scenetree.findObjectById(instance.vId) or nil
      if not vehicle then
        log('E', logTag, 'No vehicle present for '..instance.vehicleName)
        goto continue
      end
      instance.startPos = vehicle:getPosition()
      table.insert(M.instances, instance)
      ::continue::
    end
  end
end

local function updateFinalStatus(scenario, instance)
  for _,instance in ipairs(M.instances) do
    if not instance.value.triggerEndOnly then
      statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
      local playerVid = be:getPlayerVehicleID(0)
      statistics_statistics.setGoalProgress(playerVid, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})
    end
  end
end

M.updateFinalStatus = updateFinalStatus
M.init = init
M.processState = processState
return M