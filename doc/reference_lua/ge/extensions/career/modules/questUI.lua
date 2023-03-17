local M = {}

local imgui = ui_imgui
local openPtr = imgui.BoolPtr(true)


local quests = {}


--when booting up the career, show completed but not viewed quest
local function onQuestsLoaded()
  local questList = career_modules_questManager.getNotViewedButCompleteQuests()
end

local function onPopupClosed()
end

local function refreshQuests()
  quests = career_modules_questManager.getUIFormattedQuests()
end

local function onQuestCompleted(quests)
  dump(quests)
end

local function onQuestActivated(quests)
  
end

local function questsList()
  for _, quest in pairs(quests)do
    imgui.Text("Quest ID: " .. quest.id .. " (" .. quest.status .. ")")

    imgui.Text("Title: " .. quest.title)
    imgui.Text("Description: ".. quest.description)

    imgui.Text("Short description: ".. dumps(quest.shortDescription))
    imgui.Text("Goal Reached text: ".. dumps(quest.goalReached))
    imgui.Text("Progress: ".. dumps(quest.progress))

    imgui.Text("Unlocks: " .. dumps(quest.unlocks))
    imgui.Text("Unlocked by: ".. dumps(quest.unlockedBy))
    imgui.Text("Image: (i dunno what to print)")

    if quest.status == "active" then
      if imgui.Button("Complete##"..quest.id) then 
        career_modules_questManager.completeQuest(quest.id)
        refreshQuests()
      end 
    end
    if quest.claimable then
      if imgui.Button("Claim rewards##"..quest.id) then 
        career_modules_questManager.UIClaimRewards(quest.id)
        refreshQuests()
      end 
    end

    imgui.Separator()

  end
  if imgui.Button("Claim every rewards") then 
    career_modules_questManager.claimEveryRewards()
    refreshQuests()
  end 
end

local function onUpdate()
  if imgui.Begin("Quest Debug", openPtr) then
    questsList()
    imgui.End()
  end
end

local function openQuests()
  openPtr = imgui.BoolPtr(true)
  refreshQuests()
end

M.openQuests = openQuests

M.onUpdate = onUpdate
M.onQuestsLoaded = onQuestsLoaded
M.onQuestActivated = onQuestActivated
M.onQuestCompleted = onQuestCompleted
return M