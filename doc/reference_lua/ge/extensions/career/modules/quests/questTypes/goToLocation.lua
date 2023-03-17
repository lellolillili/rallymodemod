local M = {}
local _, questType = path.splitWithoutExt(debug.getinfo(1).source)

local function updateProgressOfQuest(quest, done)
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end

  local goal = quest.type.locationName or "no location name"

  quest.tempData.progress = { {
      type = "checkBox",
      done = done,
      label = "nothing yet",
    }
  }
  quest.tempData.shortDescription = {txt = "quest.type."..questType..".goal", goal = goal}
  quest.tempData.goalReached = {txt = "quest.type."..questType..".succeed", goal = goal}

  if done then
    career_modules_questManager.addCompleteQuest(quest)
  end
end

local function updateProgress()
  for _, quest in ipairs(career_modules_questManager.getQuestsOfType(questType)) do  
    updateProgressOfQuest(quest, false)
  end
end

local defaultDist = 20
local function check()
  local pos
  local playerPos = be:getPlayerVehicle(0):getPosition()
  if not playerPos then return end
  for _, quest in ipairs(career_modules_questManager.getQuestsOfType(questType)) do  
    pos = quest.type.conditions.pos
    defaultDist = quest.type.conditions.distance or defaultDist
    if vec3(pos[1], pos[2], pos[3]):distance(playerPos) < defaultDist then
      updateProgressOfQuest(quest, true)
    end
  end
end

-- This is here so when x quest becomes activated, every quest will check if they are completed, so x quest will perhaps become completed
local function onQuestActivated()
  updateProgress()
end

-- When every quests are loaded, we define their texts, progress etc...
local function onQuestsLoaded()
  updateProgress()
end

local function onUpdate()
  check()
end

M.onQuestsLoaded = onQuestsLoaded
M.onQuestActivated = onQuestActivated
M.onBeamXPAdded = onBeamXPAdded

M.onUpdate = onUpdate
return M