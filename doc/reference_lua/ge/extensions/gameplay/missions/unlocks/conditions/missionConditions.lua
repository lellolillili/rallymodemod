-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local F = {}
-- this function checks if any progress (by key) of a mission has a specific field set (passed, completed etc)
F.checkAggregateWithKey = function(id, progressKey, field)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then log("E","","Trying to get progress for nonexistent mission: " .. dumps(id)) return false end
  local pKeys = progressKey
  if pKeys == 'default' or pKeys == nil or progressKey == '' then
    pKeys = {mission.defaultProgressKey}
  elseif pKeys == 'any' then
    pKeys = tableKeysSorted(missions.saveData.progress)
  else
    pKeys = {pKeys}
  end
  local met = false
  for _, key in ipairs(pKeys) do
    if mission.saveData.progress[key] and mission.saveData.progress[key].aggregate then
      met = met or mission.saveData.progress[key].aggregate[field]
    end
  end
  return met
end

F.getTargetLabel = function(id, progressKey, verb)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then log("E","","Trying to getTargetString: for nonexistent mission: " .. dumps(id)) return "Missing Mission: " .. dumps(id) end
  if progressKey == 'default' or progressKey == nil or progressKey == '' then
    return {txt = "missions.missions.unlock."..verb..".default", context = {name = mission.name}}
  elseif progressKey == 'any' then
    return {txt = "missions.missions.unlock."..verb..".any", context = {name = mission.name}}
  else
    return {txt = "missions.missions.unlock."..verb..".custom", context = {name = mission.name, setting = progressKey}}
  end
end

M.missionPassed = {
  info = 'The user has to have passed another mission.',
  editorFunction = "displayMissionCondition",
  getLabel = function(self) return F.getTargetLabel(self.missionId, self.progressKey, 'pass') end,
  conditionMet = function(self) return F.checkAggregateWithKey(self.missionId, self.progressKey, 'passed') end
}

M.missionCompleted = {
  info = 'The user has to have completed another mission.',
  editorFunction = "displayMissionConditionWithProgressKey",
  getLabel = function(self) return F.getTargetLabel(self.missionId, self.progressKey, 'complete') end,
  conditionMet = function(self) return F.checkAggregateWithKey(self.missionId, self.progressKey, 'completed') end
}
--[[
M.missionFunction = {
  info = 'Calls a custom function from the mission class.',
  conditionString = function(c, mission)
    local ret = (mission[c.conditionString] and mission[condition.conditionString](mission))
    if ret == false then return nil end
    if ret == nil then return ("Function " .. c.functionName) end
    return ret
  end,
  conditionMet = function(c, mission) return mission[c.functionName] and mission[c.functionName](mission) end
}

]]
return M