-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'rewards'

M.pendingUserChoices = {}

local function iterateRewardsConst(player, callback)
  local inv = players[player] or {}
  for k, v in pairs(inv) do
      callback(k, v)
  end
end

local function getRewards(scenarioKey, scenarioData, scenarioResult, medal)
  --log('I', logTag, 'getRewards called... ')

  local data = (not scenarioResult.failed and scenarioData.onEvent.onSucceed) or scenarioData.onEvent.onFail
  if not data or not data.rewards then return end

  local reward = {}
  if medal then
    reward[medal] = data.rewards[medal] or {}
  end

  for k,v in pairs(data.rewards) do
    -- ignore all keys for medals
    if statistics_statistics.getMedalRanking(k) < 0 then
      reward[k] = v
    end
  end

  --dump(reward)
  return reward
end

local function processEntry(earned, k, data)
  if type(data) == 'table' then
    earned[k] = earned[k] or {}
    for _,value in pairs(data) do
      table.insert(earned[k], value)
      core_inventory.addItem('$$$_'..k, value)
    end
  else
    earned[k] = (earned[k] or 0) + data
    core_inventory.addItem('$$$_'..k, data)
  end
end

-- TODO(AK): Make rewards.lua have a validation step on the campaign json information
local function processRewards(scenarioKey, scenarioData, scenarioResult, medal)
  log('I', logTag, 'processRewards called... ')
  local pendingChoice = {}
  local earned = {}

  local rewards = getRewards(scenarioKey, scenarioData, scenarioResult, medal)
  if rewards then
    for k,data in pairs(rewards) do
      if statistics_statistics.getMedalRanking(k) >= 0 then
        for subKey,value in pairs(data) do
          if subKey == 'choices' then
            if type(value) == 'table' then
              pendingChoice['choices'] = value
              M.pendingUserChoices[scenarioKey] = value
            else
              log('E', logTag, 'Rewards entry choices has to be an array of objects : Bad entry here - '..scenarioKey)
            end
          else
            processEntry(earned, subKey, value)
          end
        end
      else
       processEntry(earned, k, data)
      end
    end
  end

  log('I', logTag, 'pendingChoice: ' .. dumps(pendingChoice))
  log('I', logTag, 'earned: ' .. dumps(earned))

  -- TODO(AK): This is a side-effect of communicating with UI. UI needs more fields to work with that are specific
  --           to what its function is. I.E. Things for user to choose from should be labeled with "_options"
  local finalResultInfo = {}
  for k,v in pairs(earned) do
    finalResultInfo[k] = v
  end

  for k,v in pairs(pendingChoice) do
    finalResultInfo[k] = v
  end

  return finalResultInfo
end

local function processUserSelection(scenarioKey, selectionIndex)
  log('I', logTag, 'processUserSelection called... '..selectionIndex .. ' / ' .. dumps(M.pendingUserChoices))
  local choices = M.pendingUserChoices[scenarioKey]
  if choices then
    for k,v in pairs(choices) do
      core_inventory.addItem("$$$_"..k, v[selectionIndex])

      -- TODO(AK): Send the other vehicles to the auto dealer
      for i=1,(selectionIndex - 1) do
        log('I', logTag, '@1 sending index '..i)
        campaign_dealer.addToStock("$$$_"..k, v[i])
      end
      local arraySize = #v
      for i=(selectionIndex + 1),arraySize do
        log('I', logTag, '@2 sending index '..i)
        campaign_dealer.addToStock("$$$_"..k, v[i])
      end
      return
    end
  end
end

local function getScenarioReward(scenarioData, eventName)
-- if scenarioData and scenarioData.onEvent and scenarioData.onEvent[eventName] then
--   local eventData = scenarioData.onEvent[eventName]
--   if eventData.rewards and type(eventData.rewards) == 'table' then
--     local result = {}
--    for _,v in ipairs(eventData.rewards) do
--      table.insert(result, v)
--    end
--    return result
--   end
-- end

-- return nil
end


M.iterateRewardsConst     = iterateRewardsConst
M.getRewards              = getRewards
M.processRewards          = processRewards
M.processUserSelection    = processUserSelection
M.getScenarioReward       = getScenarioReward

return M
