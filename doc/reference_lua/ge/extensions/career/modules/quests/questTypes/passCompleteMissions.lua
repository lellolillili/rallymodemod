local M = {}
local _, questType = path.splitWithoutExt(debug.getinfo(1).source)

-- Pass or Complete n number of missions
local function updateProgress()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end

  --Count stars
  local passedCount = 0
  local completedCount = 0
  for _, mission in ipairs(gameplay_missions_missions.get()) do
    local saveData = mission.saveData
    if saveData.progress.default then
      if saveData.progress.default.aggregate.completed then completedCount = completedCount + 1 end
      if saveData.progress.default.aggregate.passed then passedCount = passedCount + 1 end
    end
  end

  for _, quest in ipairs(career_modules_questManager.getQuestsOfType(questType)) do
    local currValue
    local goal = quest.type.conditions.missionsCount
    
    if quest.type.conditions.condition == "complete" then
      currValue = completedCount
      if completedCount >= goal then
        career_modules_questManager.addCompleteQuest(quest)
      end
    elseif quest.type.conditions.condition == "pass" then
      currValue = passedCount
      if passedCount >= goal then
        career_modules_questManager.addCompleteQuest(quest)
      end
    end
    quest.tempData.shortDescription = {txt = "quest.type."..quest.type.conditions.condition.."Missions.goal", goal = goal}
    quest.tempData.goalReached = {txt = "quest.type."..quest.type.conditions.condition.."Missions.succeed", count = currValue, goal = goal}

    quest.tempData.progress = { {
        type = "progressBar",
        minValue = 0,
        currValue = currValue,
        maxValue = goal,
        label = {txt = "quest.type."..quest.type.conditions.condition.."Missions.progress", count = currValue, goal = goal},
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