-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local conditionTypes = {}

-- This function recursively processes a condition, generating label, if the condition is met etc.
local function conditionMet(condition)
  local conditionType = conditionTypes[condition.type]
  if not conditionType then
    conditionType = conditionTypes['missing']
  end

  local met, nested = conditionType.conditionMet(condition)
  local label = conditionType.getLabel(condition)
  return {met = met, condition = condition, nested = nested, label = label, hidden = conditionType.hidden}
end

-- the "main" mission unlock caluclation. Sets the Startable and Visible flags and infos for missions.
local function updateUnlockStatus(missions)
  missions = missions or gameplay_missions_missions.get()
  local counts = {startable = 0, visible = 0}
  local referencedMissions = {}
  local careerActive = career_career and career_career.isCareerActive()
  local missionIdsById = {}
  for _, mission in ipairs(missions) do
    local startableInfo = conditionMet(mission.startCondition or deepcopy(conditionTypes['always']))
    mission.unlocks = mission.unlocks or {}
    mission.unlocks.startable = startableInfo.met
    mission.unlocks.startableDetails = startableInfo
    mission.unlocks.hideStartableDetails = startableInfo.hidden
    if mission.careerSetup.showInCareer and mission.careerSetup.showInFreeroam and not careerActive then
      mission.unlocks.startable = true
      mission.unlocks.startableDetails = nil
    end
    counts.startable = counts.startable + (mission.unlocks.startable and 1 or 0)
  end
  for _, mission in ipairs(missions) do
    local isVisible = true
    mission.unlocks.visible = false
    if careerActive then
      isVisible = mission.careerSetup.showInCareer
    else
      isVisible = mission.careerSetup.showInFreeroam
    end
    --isVisible = true
    if isVisible then
      if mission.visibleCondition.type == 'automatic' then

        if not mission.unlocks.backward or #mission.unlocks.backward == 0 then
          mission.unlocks.visible = true
        else
          for _, bId in ipairs(mission.unlocks.backward or {}) do
            local back = gameplay_missions_missions.getMissionById(bId)
            if back then
              mission.unlocks.visible = back.unlocks.startable or mission.unlocks.visible
            end
          end
        end
        if mission.careerSetup.showInCareer and mission.careerSetup.showInFreeroam and not careerActive then
          mission.unlocks.visible = true
        end
      else
        local visibleInfo = conditionMet(mission.visibleCondition or deepcopy(conditionTypes['always']))
        mission.unlocks.visible = visibleInfo.met
      end
    end
    counts.visible = counts.visible + (mission.unlocks.visible and 1 or 0)
  end

  log("I", "", "Processed unlock status of missions: ".. counts.startable.."/"..#missions .. " startable missions, " .. counts.visible.."/"..#missions.." visible missions.")
end


-----------------------------------------------------------------
----------------------- Comparing Unlocks -----------------------
-----------------------------------------------------------------

--  this function generates a flat/simple list of all unlock data for all missions, used for comparisons.
local function getSimpleUnlockedStatus()
  local cache = {}
  for _, mission in ipairs(gameplay_missions_missions.get()) do
    cache[mission.id] = deepcopy(mission.unlocks)
  end
  return cache
end

-- compares two unlock data, to see what changed beween them
local keysToCheck = {'startable','visible'}
local function compareUnlock(a,b)
  local ret = {}
  for _, key in ipairs(keysToCheck) do
    if a[key] ~= b[key] then
      table.insert(ret, {
        key = key,
        old = a[key],
        new = b[key]
      })
    end
  end
  return ret
end

-- compares two simpleUnlockedStatus lists to see what changed between them
local function getUnlockDiff(before, after)
  local diff = {list = {}, byId = {}, missionsList={}}
  for _, mission in ipairs(gameplay_missions_missions.get()) do
    local id = mission.id
    local comp = compareUnlock(before[id], after[id])
    if next(comp) then
      table.insert(diff.list,{
        missionId = id,
        change = comp
      })
      diff.byId[id] = comp
      -- check if a mission is now startable
      if after[id].startable and (not before[id].startable) then
        table.insert(diff.missionsList, {
          name = mission.name,
          id = id
        })
      end
    end
  end
  return diff
end

-- for a specific mission, gets all misisons that are directly unlocked by it.
local function getMissionBasedUnlockDiff(mission, diff)
  local fwd = {list = {}}
  for _, id in ipairs(mission.unlocks.forward) do
    local otherMission = gameplay_missions_missions.getMissionById(id)
    table.insert(fwd.list, {missionId = id, changed = diff.byId[id] ~= nil, startable = otherMission.unlocks.startable})
  end
  return fwd
end

--------------------------------------------------------------------
----------------------- Ordering and Tagging -----------------------
--------------------------------------------------------------------

-- recursively collects all missions referenced in conditions (missionPassed, missionCompleted)
local function getMissionsForCondition(cond, list)
  if cond.nested then
    for _, n in ipairs(cond.nested) do
      getMissionsForCondition(n, list)
    end
  else
    if cond.type == 'missionPassed' or cond.type == 'missionCompleted' then
      table.insert(list, cond.missionId)
    end
  end
end
M.getMissionsForCondition = getMissionsForCondition

-- recursively gets all branch level requirements in conditions (branchLevel)
local function getBranchLevelForCondition(cond, list)
  if cond.nested then
    for _, n in ipairs(cond.nested) do
      M.getBranchLevelForCondition(n, list)
    end
  else
    if cond.type == "branchLevel" then
      list[cond.branchId] = cond.level
    end
  end
end
M.getBranchLevelForCondition = getBranchLevelForCondition

-- for one specific mission, sets the branchTags and level data for all missions following it (missionPassed etc).
local function propagateBranchLevel(startId, missionById)
  local front, nxt, open = {}, {}, {}
  local startLevel = missionById[startId].unlocks.maxBranchlevel
  local startTypes = missionById[startId].unlocks.branchTags
  table.insert(front, startId)
  local c = 0
  while c < 10000 and next(front) do
    nxt = {}
    for _, mId in ipairs(front) do
      missionById[mId].unlocks.maxBranchlevel = math.max(missionById[mId].unlocks.maxBranchlevel, startLevel)
      for _, nId in ipairs(missionById[mId].unlocks.forward) do
        nxt[nId] = true
      end
      for key, _ in pairs(startTypes) do
        missionById[mId].unlocks.branchTags[key] = true
      end
    end
    front = tableKeysSorted(nxt)
    c = c+1
  end
end

-- the "main" unlocking additional data caluculation method.
local function setUnlockForwardBackward(missions)
  local backward, forward = {}, {}
  local highestLevelForMission = {}
  local branchTagForMission = {}
  local missionById = {}

  -- first, get the base data for all missions: associated missions, branch levels.
  for _, m in ipairs(missions) do
    missionById[m.id] = m
    backward[m.id] = {}
    forward[m.id] = {}
    getMissionsForCondition(m.startCondition, backward[m.id])

    local levelForBranch = {}
    getBranchLevelForCondition(m.startCondition, levelForBranch)
    highestLevelForMission[m.id] = nil
    branchTagForMission[m.id] = nil
    for bId, lvl in pairs(levelForBranch) do
      branchTagForMission[m.id] = branchTagForMission[m.id] or {}
      branchTagForMission[m.id][bId] = true
      if not highestLevelForMission[m.id] then
        highestLevelForMission[m.id] = lvl
      else
        highestLevelForMission[m.id] = math.max(highestLevelForMission[m.id], lvl)
      end
    end
    m.unlocks.maxBranchlevel = highestLevelForMission[m.id] or 0
    m.unlocks.branchTags = branchTagForMission[m.id] or {}
  end

  -- double-link the missions, so that missions know which ones come after that (conditions are looking "backward")
  for bId, list in pairs(backward) do
    for _, fId in ipairs(list or {}) do
      if not forward[fId] then forward[fId] = {} end
      table.insert(forward[fId], bId)
    end
  end

  -- set the data to the unlocks field of the mission.
  for _, m in ipairs(missions) do
    if #backward[m.id] > 0 then
      --log(m.id .. " Backwards: " .. dumps(backward[m.id]))
    end
    if #forward[m.id] > 0 then
      --log(m.id .. " Forwards: " .. dumps(forward[m.id]))
    end
    m.unlocks.forward = forward[m.id]
    m.unlocks.backward = backward[m.id]
  end

  -- propagate the max lvl of a mission forward, so each mission knows the minimum branch level needed through predecessors
  local missionIdsWithBranchCondition = tableKeysSorted(highestLevelForMission)
  for _, mId in ipairs(missionIdsWithBranchCondition) do
    propagateBranchLevel(mId, missionById)
  end

  --propagate missions go get initial "depth"
  local front, nxt, open = {}, {}, {}
  local depth = 0
  for _, m in ipairs(missions) do
    m.unlocks.depth = -1
    if #m.unlocks.backward == 0 then
      table.insert(front, m.id)
    end
  end
  while depth < 1000 and next(front) do
    nxt = {}
    for _, mId in ipairs(front) do
      missionById[mId].unlocks.depth = math.max(missionById[mId].unlocks.depth, depth)
      for _, nId in ipairs(missionById[mId].unlocks.forward) do
        nxt[nId] = true
      end
    end
    front = tableKeysSorted(nxt)
    depth = depth+1
  end

  -- get max depth for each level. then sum up to get depth offset
  local maxDepthPerBranchlevel = {}
  local maxLevel = 0
  for _, m in ipairs(missions) do
    maxDepthPerBranchlevel[m.unlocks.maxBranchlevel] = math.max(m.unlocks.depth, maxDepthPerBranchlevel[m.unlocks.maxBranchlevel] or 0)
    maxLevel = math.max(maxLevel, m.unlocks.maxBranchlevel)
  end
  local prev = 0
  for i = 0, maxLevel do
    maxDepthPerBranchlevel[i] = prev + maxDepthPerBranchlevel[i]
    prev = maxDepthPerBranchlevel[i]
  end

  -- shift the depth of a mission based on the amount of branches, branch depth, branch level
  for _, m in ipairs(missions) do
    m.unlocks.depth = m.unlocks.depth + maxDepthPerBranchlevel[m.unlocks.maxBranchlevel] + (m.unlocks.maxBranchlevel)*1
  end
end

M.setUnlockForwardBackward = setUnlockForwardBackward
M.startConditionMet = startConditionMet
M.updateUnlockStatus = updateUnlockStatus

M.conditionMet = conditionMet
M.getSimpleUnlockedStatus = getSimpleUnlockedStatus
M.getUnlockDiff = getUnlockDiff
M.getMissionBasedUnlockDiff = getMissionBasedUnlockDiff

-- load all condition types.
local function onExtensionLoaded()
  local files = FS:findFiles('/lua/ge/extensions/gameplay/missions/unlocks/conditions','*.lua',-1)
  local count = 0
  for _, file in ipairs(files) do
    local aConds = require(file:sub(0,-5))

    for key, value in pairs(aConds) do
      count = count+1
      conditionTypes[key] = value
    end
  end
  log("D","","Loaded " .. count .. " condition types from " .. #files .. " files.")
end
M.onExtensionLoaded = onExtensionLoaded

return M
