local M = {}
local _, questType = path.splitWithoutExt(debug.getinfo(1).source)

local function updateProgress()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end
  --Count stars
  local totalStarCount = 0
  for _, mission in ipairs(gameplay_missions_missions.get()) do
    local saveData = mission.saveData
    local starCount = tableSize(saveData.unlockedStars)
    if starCount then
      totalStarCount = totalStarCount + starCount
    end
  end

  for _, quest in ipairs(career_modules_questManager.getQuestsOfType(questType)) do    
    local goal = quest.type.conditions.starsCount
    quest.tempData.progress = { {
        type = "progressBar",
        minValue = 0,
        currValue = totalStarCount,
        maxValue = goal,
        label = {txt = "quest.type."..questType..".progess", count = totalStarCount, goal = goal},
      }
    }
    quest.tempData.shortDescription = {txt = "quest.type."..questType..".goal", count = totalStarCount}
    quest.tempData.goalReached = {txt = "quest.type."..questType..".succeed", count = totalStarCount}

    if totalStarCount >= goal then
      career_modules_questManager.addCompleteQuest(quest)
    end
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