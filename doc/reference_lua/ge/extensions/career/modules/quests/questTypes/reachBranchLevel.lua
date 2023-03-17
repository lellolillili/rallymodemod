local M = {}
local _, questType = path.splitWithoutExt(debug.getinfo(1).source)

-- Pass or Complete n number of missions
local function updateProgress(state, activity)
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end

  local quests = career_modules_questManager.getQuestsOfType(questType)
  for _, quest in ipairs(quests) do
    local currBranchId = quest.type.conditions.branchId
    local currLevel  = career_branches.getBranchLevel(currBranchId)
    local goal = quest.type.conditions.level

    if currLevel >= goal then
      career_modules_questManager.addCompleteQuest(quest)
    end
    quest.tempData.shortDescription = {txt = "quest.type."..questType..".goal", goal = goal, branch = currBranchId}
    quest.tempData.goalReached = {txt = "quest.type."..questType..".succeed", level = currLevel, branch = currBranchId}
    quest.tempData.progress = { {
      type = "progressBar",
      minValue = 0,
      currValue = currLevel,
      maxValue = goal,
      label = {txt = "quest.type."..questType..".progress", goal = goal, level = currLevel, branch = currBranchId},
      }
    }
  end
end


local function onAnyMissionChanged(state, activity)
  if state == "stopped" then
    updateProgress()
  end
end

-- When every quests are loaded, we define their texts, progress etc...
local function onQuestsLoaded()
  updateProgress()
end

-- This is here so when x quest becomes activated, every quest will check if they are completed, so x quest will perhaps become completed
local function onQuestActivated()
  updateProgress()
end

M.onQuestActivated = onQuestActivated
M.onQuestsLoaded = onQuestsLoaded
M.onAnyMissionChanged = onAnyMissionChanged

return M