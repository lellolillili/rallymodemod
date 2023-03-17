local M = {}
local _, questType = path.splitWithoutExt(debug.getinfo(1).source)

local function updateProgress()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end

  for _, quest in ipairs(career_modules_questManager.getQuestsOfType(questType)) do
    local missionId = quest.type.conditions.missionId
    local missionData = jsonReadFile(savePath.."/career/missions/"..missionId..".json")
    if missionData then
      if quest.type.conditions.condition == "complete" then
        if missionData.progress.default.aggregate.completed then 
          career_modules_questManager.addCompleteQuest(quest)
        end
      elseif quest.type.conditions.condition == "pass" then
        if missionData.progress.default.aggregate.passed then 
          career_modules_questManager.addCompleteQuest(quest)
        end
      end

      quest.tempData.shortDescription = {txt = "quest.type."..quest.type.conditions.condition.."Mission.goal", mission = missionId}
      quest.tempData.goalReached = {txt = "quest.type."..quest.type.conditions.condition.."Mission.succeed", mission = missionId}

      quest.tempData.progress = { {
          type = "checkbox",
          done = quest.userData.status == "completed",
          label = "Dont know what to put in here",
        }
      }
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

M.onQuestsLoaded = onQuestsLoaded
M.onQuestActivated = onQuestActivated
M.onAnyMissionChanged = onAnyMissionChanged

return M