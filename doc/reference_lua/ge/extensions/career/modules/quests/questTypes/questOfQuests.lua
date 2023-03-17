local M = {}
local _, questType = path.splitWithoutExt(debug.getinfo(1).source)


local function updateProgress()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end

  for _, quest in ipairs(career_modules_questManager.getQuestsOfType(questType)) do
    local andFlag = true
    local succeededSubQuestCount = 0
    local goal = #quest.type.conditions.subTasks

    for _, id in ipairs(quest.type.conditions.subTasks) do 
      local questStatus = career_modules_questManager.getQuestById(id).userData.status
      if questStatus ~= "completed" then
        andFlag = false
        break
      else
        succeededSubQuestCount = succeededSubQuestCount + 1
      end
    end
    if andFlag then
      career_modules_questManager.addCompleteQuest(quest)
    end
    quest.tempData.shortDescription = {txt = "quest.type."..questType..".goal"}
    quest.tempData.goalReached = {txt = "quest.type."..questType..".succeed"}

    quest.tempData.progress = { {
        type = "progressBar",
        minValue = 0,
        currValue = succeededSubQuestCount,
        maxValue = goal,
        label = {txt = "quest.type."..questType..".progress", count = succeededSubQuestCount, goal = goal},
      }
    }
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

M.onQuestsLoaded = onQuestsLoaded
M.onQuestActivated = onQuestActivated

return M