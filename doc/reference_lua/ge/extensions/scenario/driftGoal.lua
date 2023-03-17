-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.instances = {}
local helper = require('scenario/scenariohelper')
local driftState = 0
local driftCooldown = 0
local driftPoints = 0
local driftCombo = 0
local messageTimer = 1
local displayMessage = ""
local driftSummary = ""
local driftDescription = {"Tiny Drift","Small Drift", "Nice Drift", "Great Drift!", "Awesome Drift!", "Spectacular Drift!", "Incredible Drift!", "Absurd Drift!"}     --insert adjectives here
local next =next

local function reset()
  driftState = 0
  driftCooldown = 0
  driftPoints = 0
  driftCombo = 0
  messageTimer = 1
  displayMessage = ""
  driftSummary = ""
end

local function sessionEnd(instance)
  local  result = {}

  if instance.driftScore >= instance.value.minDrift then
    if instance.value.msg then
      result = {msg={txt = instance.value.msg, context = {score = instance.driftScore}}}
    else
      result = {msg={txt = "extensions.scenario.drift.passGoal", context = {driftPoints = tostring(instance.value.driftPoints)}}}
    end
    instance.status.result = "passed"
  else
    if instance.value.failMsg then
      result = {failed={txt = instance.value.failMsg, context = {score = instance.driftScore}}}
    else
      result = {failed={txt = "extensions.scenario.drift.failedGoal", context = {minDrift = tostring(instance.value.minDrift)}}}
    end
    instance.status.result = "failed"
  end

  instance.driftScore = math.min(instance.driftScore, instance.value.maxDrift)
  instance.status.completed = true
  reset()
  scenario_scenarios.finish(result)
end

local function processState(scenario, state, stateData)
  for _,instance in ipairs(M.instances) do
    local fobjData = map.objects[map.objectNames[instance.vehicleName]]
    local vehicle = scenetree.findObjectById(instance.vId)
    if fobjData then
      local vecDifx = fobjData.dirVec.x - (fobjData.vel.x/fobjData.vel:length())  --find the difference between the x speed and rotation vectors
      local vecDify = fobjData.dirVec.y - (fobjData.vel.y/fobjData.vel:length())  --find the difference between the y speed and rotation vectors

      local angleBonus = math.floor(math.sqrt(vecDifx * vecDifx + vecDify * vecDify) * 10)    --distance between speed and rotation vectors
      local speedBonus = fobjData.vel:length() * 0.15
      local lastDriftPoints = 0
      angleBonus = angleBonus < 11 and angleBonus or 0    --don't consider spin-outs to be drifting
      angleBonus = angleBonus > 1 and angleBonus or 0     --don't consider overly shallow drifts
      speedBonus = speedBonus > 1 and speedBonus or 0     --don't consider very low-speed drifts

      local driftBonus = math.floor(angleBonus * speedBonus) --combine speed and angle to make a score
      if driftBonus > 0 then      --If a drift is happening
        if driftCooldown > 0 and driftState == 0 then   --allow combined drifts with a score multiplier
          driftCombo = driftCombo + 1
        end

        instance.driftScore = instance.driftScore + driftBonus * (driftCombo + 1)   --add the instantaneous drift score to the total scenario score
        driftPoints = driftPoints + driftBonus  * (driftCombo + 1)          --add the instantaneous drift score to the current drift score
        lastDriftPoints = 0

        if driftCombo == 0 then     --normal display message
          displayMessage = "Drift: "..driftPoints
        else
          displayMessage = "Combo x"..(driftCombo + 1)..": "..driftPoints --combo drift display message
        end
        driftState = 1
      else    --if not drifting
        if driftState == 1 then --if just finished a drift
          driftCooldown = 1   --allow chained drifts within a grace period
          driftState = 0      --end the drift
          messageTimer = 1
          lastDriftPoints = driftPoints   --remember what the score was
          displayMessage = driftDescription[math.min(math.floor(math.sqrt(lastDriftPoints/30))+1, 8)] --pick an adjective to describe the drift
          driftPoints = 0      --no more points from this drift
        end
        driftCooldown = driftCooldown > 0 and driftCooldown - 0.25 or 0 --short cooldown during which additional drifts can be chained
        driftCombo = driftCooldown > 0 and driftCombo or 0  --reset combos after cooldown period
        messageTimer = messageTimer > 0 and messageTimer - 0.1 or 0
        if messageTimer == 0 then
          displayMessage = ""
        end
      end

      if instance.driftScore > 0 then
        helper.realTimeUiDisplay(displayMessage) --display whatever message is relevant
      end
    end

    if not instance.status.completed then
      if state == 'onRaceResult' or (instance.value.timeAllowance and scenario.timer > instance.value.timeAllowance) then
        sessionEnd(instance)
      end
    end

    if not fobjData and vehicle then
      vehicle:queueLuaCommand('mapmgr.enableTracking("'..instance.vehicleName..'")')-- reset vehicle (tricky step to prevent executing setMode and initialition in the same time TODO
    end
  end
end

local function init(scenario)
  M.instances = {}
  for _,instance in ipairs(scenario.goals.vehicles) do
    if instance.id == 'drift' then
      if instance.value.minDrift and type(instance.value.minDrift)~="number" then
        log('E', 'In '..tostring(scenario.name), ' minDrift must contain number value  ')
        goto continue
      end
      if instance.value.maxDrift and type(instance.value.maxDrift)~= "number" then
        log('E', 'In '..tostring(scenario.name), ' maxDrift must contain number value  ')
        goto continue
      end

      instance.driftScore = 0
      instance.status.completed = false
      table.insert(M.instances, instance)
      ::continue::
    end
  end

  driftState = 0
  driftCooldown = 0
  driftPoints = 0
  driftCombo = 0
  messageTimer = 1
  displayMessage = ""
  driftSummary = ""
end

local function updateFinalStatus(scenario, instance)
  for _,instance in ipairs(M.instances) do
    if instance.driftScore < instance.value.minDrift then
      instance.status.result = "failed"
    else
      instance.status.result = "passed"
    end
    instance.status.completed = true

    statistics_statistics.setGoalProgress(instance.vId, instance.id, instance.vId, {status=instance.status.result,points=instance.driftScore,  maxPoints=instance.value.maxDrift})
  end
end

M.updateFinalStatus = updateFinalStatus
M.processState = processState
M.init = init

return M
