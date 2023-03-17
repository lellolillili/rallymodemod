-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.instances = {}
  --"position":{"endPoint":"object in scenetree", "msg":"You are not in the brake area..."}
      --Do move: car needs to be at a specific position (potentially with a threshold)
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

    local errMsg = instance.value.msg or "Not in brake area"
    local result = { failed = errMsg }
    scenario_scenarios.finish(result)
    return
  elseif instance.value.purpose == "win" then
    instance.status.result = "passed"
    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result, maxPoints=nil})

    local winMsg = instance.value.msg .. timeStr or "IN brake area "..timeStr
    local result = { msg = winMsg }
    scenario_scenarios.finish(result)
    return
  end
end

local function processState(scenario, state, stateData)
  for _,instance in ipairs(M.instances) do
    local endobj = scenetree.findObject(instance.value.endPoint)
    if not endobj then
      log('E', 'In '..tostring(scenario.name), ' this value ' ..tostring(instance.value.endPoint) .. ' is not an object in scenetree')
      goto continue
    end
    local vehicle = scenetree.findObjectById(instance.vId)
    if endobj and vehicle then
      local distance = (endobj:getPosition() - vehicle:getPosition()):len()
      if state == 'onRaceResult'  then
        if distance > endobj.scale.x then
          showMsg(scenario,instance)
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
    if instance.id ~= 'position' then
      goto continue
    end
    if instance.value.purpose and type(instance.value.purpose)~="string" then
      log('E', 'In '..tostring(scenario.name),'purpose is missing in json file or purpose has wrong type ')
      goto continue
    end
    if not instance.value.purpose then
      instance.value.purpose ="fail"
    end
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
M.init = init
M.processState = processState
return M
