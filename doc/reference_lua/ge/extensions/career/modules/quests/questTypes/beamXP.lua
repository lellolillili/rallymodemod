local M = {}
local _, questType = path.splitWithoutExt(debug.getinfo(1).source)

local function updateProgress()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end
  
  local currBeamXP = career_modules_playerAttributes.getAttribute(questType).value

  for _, quest in ipairs(career_modules_questManager.getQuestsOfType(questType)) do  
    local goal = quest.type.conditions.beamXPCount

    quest.tempData.progress = { {
        type = "progressBar",
        minValue = 0,
        currValue = currBeamXP,
        maxValue = goal,
        label = {txt = "quest.type."..questType..".progess", count = currBeamXP, goal = goal},
      }
    }
    quest.tempData.shortDescription = {txt = "quest.type."..questType..".goal", goal = goal}
    quest.tempData.goalReached = {txt = "quest.type."..questType..".succeed", goal = goal}
    if currBeamXP >= goal then
      career_modules_questManager.addCompleteQuest(quest)
    end
  end
end

local function onPlayerAttributesChanged()
  updateProgress()
end

-- This is here so when x quest becomes activated, every quest will check if they are completed, so x quest will perhaps become completed
local function onQuestActivated()
  updateProgress()
end

-- When every quests are loaded, we define their texts, progress etc...
local function onQuestsLoaded()
  updateProgress()
end

M.onQuestsLoaded = onQuestsLoaded
M.onQuestActivated = onQuestActivated
M.onBeamXPAdded = onBeamXPAdded
M.onPlayerAttributesChanged = onPlayerAttributesChanged
return M