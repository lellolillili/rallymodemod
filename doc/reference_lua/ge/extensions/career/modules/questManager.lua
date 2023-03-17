local M = {}
M.dependencies = {'career_career'}

local fileName = "quests.json"

local quests = {}
--[[quests = {
  tempData = {},
  userData = {},
  anything in the root is from the core quest data
}--]]

--those two are temporarily used when initialization. they are populated then put in the quests table
local userData = {} -- The user quest data that will be saved 
local diskData = {} -- Quest data that comes from the actual quest. Dont edit

local function formatQuest(quest)
  local formattedQuest = {}
  formattedQuest.id = quest.id
  formattedQuest.title = quest.name
  formattedQuest.shortDescription = quest.tempData.shortDescription
  formattedQuest.goalReached = quest.tempData.goalReached
  formattedQuest.description = quest.description
  formattedQuest.image = quest.image
  formattedQuest.progress = quest.tempData.progress
  formattedQuest.unlocks = quest.tempData.nextQuests
  formattedQuest.unlockedBy = quest.unlock.unlockedBy

  formattedQuest.status = quest.userData.status
  formattedQuest.claimable = quest.userData.status == "completed" and not quest.userData.claimed
  return formattedQuest
end

------------------- DO NOT DISTURB STUFF -------------------

local inAMission = false

local function canBeDisturbed()
  return not inAMission
end

local function tryPushNotifications()
  local activatedQuests = {}
  local completedQuests = {}
  if canBeDisturbed() then
    for _, quest in pairs(quests)do
      if quest.userData.status == "completed" and not quest.userData.completedViewed then
        completedQuests[quest.id] = formatQuest(quest)
      end
      if quest.userData.status == "activated" and not quest.userData.activatedViewed then
        activatedQuests[quest.id] = formatQuest(quest)
      end
    end
    if next(completedQuests) then extensions.hook("onQuestCompleted", completedQuests) end
    if next(activatedQuests) then extensions.hook("onQuestActivated", activatedQuests) end
  end
end

local function onAnyMissionChanged(state, mission)
  inAMission = state == "started"
  tryPushNotifications()
end

---------------------------------------------------------

local function getUIFormattedQuests()
  local list = {}
  for _, quest in pairs(quests)do
    list[quest.id] = formatQuest(quest)
  end
  return list
end

local function setQuestToViewed(questId)
  quests[questId].userData.completedViewed = true
end

-- When booting the game, the UI will show a list of completed quests that the user didnt see
local function getNotViewedButCompleteQuests()
  local list = {}
  for _, quest in pairs(quests)do
    if quest.userData.status == "completed" and not quest.userData.completedViewed then
      list[quest.id] = formatQuest(quest)
    end
  end
  return list
end


local function loadQuestTypesExtensions()
  local extensionFiles = {}
  local files = FS:findFiles("/lua/ge/extensions/career/modules/quests/questTypes", '*.lua', 0, false, false)
  for i = 1, tableSize(files) do
    extensions.luaPathToExtName(modulePath)
    local extensionFile = string.gsub(files[i], "/lua/ge/extensions/", "")
    extensionFile = string.gsub(extensionFile, ".lua", "")
    table.insert(extensionFiles, extensions.luaPathToExtName(extensionFile))
  end
  extensions.load(extensionFiles)
end

local function getQuestsWithStatus(status)
  local questss = {}
  for _, quest in pairs(quests)do
    if quest.userData.status == status then
      table.insert(questss, quest)
    end
  end
  return questss
end

local function isQuestRewardsClaimable(quest)
  return (not quest.userData.claimed and quest.userData.status == "completed" and quest.rewards ~= nil) and true or false
end

local function getCompleteQuests()
  local questss = {}
  for _, quest in pairs(quests) do
    if quest.userData.status == "completed" then
      table.insert(questss, quest)
    end
  end
  return questss
end

local function getUnClaimedQuests()
  local questss = {}
  for _, quest in pairs(getQuestsWithStatus("completed"))do
    if isQuestRewardsClaimable(quest) then
      table.insert(questss, quest)
    end
  end
  return questss
end

--A quest is considered a root quest if it cant be unlocked AND is not complete AND isnt a sub Quest, which means it needs to be a current quest
local function checkIsRootQuest(quest)
  if #quest.unlock.unlockedBy == 0 then
    return (quest.userData.status ~= "completed" and not quest.tempData.isSubQuest) and true or false
  end
  return false
end

local function displayProgress(quest)
  for _, p in ipairs(quest.tempData.progress) do
    imgui.Text("Progress : " .. p.label)
  end
end

local function displayUnlockCondition(quest)
  local str = "Unlockable from : "
  local i = 1
  for _, id in pairs(quest.unlock.unlockedBy)do
    str = str .. id .. ((i == #quest.unlock.unlockedBy and "") or " " .. quest.unlock.unlockType .. " ")
    i = i + 1
  end
  imgui.Text(str)
end

local function displayBaseTask(quest)
  local questType = checkIsRootQuest(quest) and " (Root quest)" or ""
  questType = quest.tempData.isSubQuest and " (Sub quest of ".. table.concat(quest.tempData.nextQuests, ", ", 1, 1) ..")" or questType
  questType = quest.isMilestone and " (Milestone)" or questType

  imgui.Text(string.format("Task id %s %s", quest.id, questType))
  imgui.Text("Task name: "..quest.name)
  if quest.unlock then
    displayUnlockCondition(quest)
  end
  if quest.tempData.progress then
    displayProgress(quest)
  end
  imgui.Spacing()
end


local function activateQuest(quest)
  quest.userData.status = "active"
  if canBeDisturbed() then
    extensions.hook("onQuestActivated", {formatQuest(quest)})
  end
end

-- will find if quest is locked, active or done
local function updateQuestStatus(quest)
  --basically if this quest cant be unlocked from any other quest, then it is a "root" quest, thus needs to be active
  if checkIsRootQuest(quest) then
    M.activateQuest(quest)
    return
  end

  if quest.userData.status  ~= "completed" then
    --this bit only checks if the current quest is "locked" or "active" according to its previous (not sub) quests
    if quest.unlock.unlockedBy then -- if unlocked by other quests
      local flag = true
      for _, id in pairs(quest.unlock.unlockedBy)do
        if quests[id].userData.status == "completed" then
          if quest.unlock.unlockType == "or" then
            M.activateQuest(quest)
            flag = false
          end
        else
          if quest.unlock.unlockType == "and" then
            flag = false
          end
        end
      end
      if quest.unlock.unlockType == "and" then
        if not flag then
          quest.userData.status = "locked"
        else
          M.activateQuest(quest)
        end
      else
        if flag then
          quest.userData.status = "locked"
        end
      end
    end
  end

  M.saveUserData()
end

-- when a quest is done, we need to update its following quests status
local function updateFollowingQuestsStatus(quest)
  if quest.tempData.nextQuests then
    for _, id in pairs(quest.tempData.nextQuests) do
      updateQuestStatus(quests[id])
    end
  end
end


local function initQuestsStatus()
  for _, quest in pairs(quests) do
    updateQuestStatus(quest)
  end
end

local function initFollowingQuests()
  for _, quest in pairs(quests) do
    if quest.unlock then
      if quest.type and quest.type.type == "questOfQuests" then
        if quest.unlock.subTasks then -- if unlock other quests
          for _, questId in pairs(quest.unlock.subTasks)do
            table.insert(quests[questId].tempData.nextQuests, quest.id)
          end
        end
      end
      if quest.unlock.unlockedBy then -- if unlock other quests
        for _, questId in pairs(quest.unlock.unlockedBy)do
          table.insert(quests[questId].tempData.nextQuests, quest.id)
        end
      end
    end
  end
end

local function initSubQuests()
  for _, quest in pairs(quests) do
    if quest.type and quest.type.type == "questOfQuests" then
      if quest.unlock then
        if quest.type.subTasks then -- if unlock other quests
          for _, questId in pairs(quest.type.subTasks)do
            quests[questId].tempData.isSubQuest = true
          end
        end
      end
    end
  end
end

--[[
_status:  -none     --default one (shouldn't remain in this state)
          -locked   --quest not unlocked
          -active   --quest unlocked
          -completed     --quest finished
]]--
local function formatQuestsData()
  for _, quest in pairs(diskData) do
    if not quest.unlock then quest.unlock = {unlockedBy = {}} end
    if not quest.description then quest.description = "No description" end

    quests[quest.id] = quest
    quest.tempData = {
      isSubQuest = false,
      nextQuests = {}
    }
  end
  for id, data in pairs(userData) do
    quests[id].userData = data
  end
  --pass to check if there is some user data, if not, we create the default
  for _, quest in pairs(quests) do 
    if not quest.userData then
      quest.userData = {
        status = "none",
        claimed = false,
        completedViewed = false,
        activatedViewed = false,
        tracked = false,
        date = ""
      }
    end
  end
  initQuestsStatus()
end

--Load the quests data from all files inside gameplay/quests folder.
local function loadDataFromDisk()
  local questsFiles = FS:findFiles('/gameplay/quests/', '*.quest.json', -1, true, false)
  local qD = {}
  local hasData = false
  local count = 0
  for _, file in pairs(questsFiles) do
    local f = jsonReadFile(file)
    for _, quest in pairs(f.quests) do
      diskData[quest.id] = quest
      count = count + 1
      hasData = true
    end
  end
  if hasData then
    log("I", "career", "Loaded " .. count .. " quests from  gameplay/quests/")
  else
    log("E", "career", "It was not possible to load any quest from the main files at gameplay/quests/")
  end
end

--This is only called in the loadExtension function
local function init() 
  initFollowingQuests() -- for ease of use, we calculate and set the following tasks for each task
  initSubQuests() -- for ease of use, we calculate and set if a task is a sub task
  --initQuestsStatus() --check the status of every quest
  log("I","Initialized Quest manager.")
end

--Saves only the necessary data into the user folder.
local function saveUserData()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end
  local saveUserData = {}
  for _, quest in pairs(quests) do
    saveUserData[quest.id] = quest.userData
  end

  jsonWriteFile(savePath .. "/career/" .. fileName, saveUserData, true)
  log("I", "career", "All data from the quest has been saved succesfully.")
end

--Load the saved data in the career user folder.
local function loadUserData()
  userData = {}
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then
    log("E", "career", "There is no slot aviable.")
    return
  end
  log("I", "career", "Loading the user quest data form the saved file.")
  userData = jsonReadFile(savePath .. "/career/"..fileName) or {}
  formatQuestsData()
  init()
  extensions.hook('onQuestsLoaded')
end

local function claimRewards(quest)
  quest.userData.claimed = true
  if quest.rewards then
    for _, reward in pairs(quest.rewards) do
      career_modules_playerAttributes.addAttribute(reward.attributeKey, reward.rewardAmount)
    end
  end
  saveUserData()
end

local function claimEveryRewards()
  for _, quest in pairs(getUnClaimedQuests()) do
    claimRewards(quest)
  end
end


--ONLY FOR DEBUG -> Resets all the current data and erase the user folder data
local function eraseUserData()
  quests = {}
  saveUserData()
end

local function addCompleteQuest(quest)
  if quest.userData.status == "active" then
    quest.userData.status = "completed"
    quest.userData.date = os.date()
    updateQuestStatus(quest)
    updateFollowingQuestsStatus(quest) --update following quests and sub quests if there are any
    saveUserData()
    if canBeDisturbed() then
      extensions.hook("onQuestCompleted", {formatQuest(quest)})
    end
  end
end

local function getQuestsOfType(type)
  local list = {}
  for _, quest in pairs(quests) do
    if quest.type and quest.type.type == type then
      table.insert(list, quest)
    end
  end
  return list
end

local function getQuestById(id)
  return quests[id]
end

local function onExtensionLoaded()
  
  --loadQuestTypesExtensions()
end

local function onCareerActivatedWhileLevelLoaded()
  --loadDataFromDisk()
  --loadUserData()
end

local function completeQuest(questId)
  addCompleteQuest(quests[questId])
end

M.activateQuest = activateQuest
M.updateQuestStatus = updateQuestStatus
M.saveUserData = saveUserData

M.onExtensionLoaded = onExtensionLoaded
M.onCareerActivatedWhileLevelLoaded = onCareerActivatedWhileLevelLoaded

M.getQuestById = getQuestById
M.addCompleteQuest = addCompleteQuest
M.getQuestsOfType = getQuestsOfType

M.onAnyMissionChanged = onAnyMissionChanged

--UI API
M.UIClaimRewards = function(questId) claimRewards(quests[questId]) end
M.claimEveryRewards = claimEveryRewards
M.getUIFormattedQuests = getUIFormattedQuests
M.setQuestToViewed = setQuestToViewed
M.getNotViewedButCompleteQuests = getNotViewedButCompleteQuests

M.completeQuest = completeQuest
return M