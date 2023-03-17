-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local branchesDir = "/gameplay/branches/"
local missingBranch = {id = "missing", name = "Missing branch!", description = "A missing branch.", levels = {}}

local branchesById
local sortedBranches

local attributeOrder = {money = 0,beamXP = 1}
local function sortAttributes(a,b) return (attributeOrder[a] or math.huge) < (attributeOrder[b] or math.huge) end
local branchNameOrder = {}
local function sortBranchNames(a,b) return (attributeOrder[a] or math.huge) < (attributeOrder[b] or math.huge) end

local function sanitizeBranch(branch, filePath)
  local infoDir, _, _ = path.split(filePath)
  branch.dir = string.sub(infoDir,1,-1)
  branch.id = string.sub(infoDir, #branchesDir+1, -2)
  branch.file = filePath

  branch.name = branch.name or ("Unnamed Branch: " .. branch.id)
  branch.description = branch.description or "No Description for this branch."
  branch.attributeKey = branch.attributeKey or branch.id
  branch.attributeOrder = branch.attributeOrder or (1000 + #sortedBranches)
end

-- gets all branches in a dict by ID
local function getBranches()
  if not branchesById then
    branchesById = {}
    for _, filePath in ipairs(FS:findFiles(branchesDir, 'info.json', -1, false, true)) do
      local fileInfo = jsonReadFile(filePath)
      sanitizeBranch(fileInfo, filePath)
      branchesById[fileInfo.id] = fileInfo
      attributeOrder[fileInfo.attributeKey] = fileInfo.attributeOrder
      branchNameOrder[fileInfo.id] = fileInfo.attributeOrder
    end
  end
  return branchesById
end

local function getBranchById(id)
  return getBranches()[id] or missingBranch
end

local function getSortedBranches()
  if not sortedBranches then
    sortedBranches = {}
    local keysSorted = tableKeys(getBranches())
    table.sort(keysSorted, sortBranchNames)
    for _, key in ipairs(keysSorted) do
      table.insert(sortedBranches, getBranchById(key))
    end
  end
  return sortedBranches
end

local function calcBranchLevelFromValue(val, id)
  local branch = getBranchById(id)
  local level = -1
  local curLvlProgress, neededForNext = -1

  local levels = branch.levels or {}
  for i, lvl in ipairs(levels) do
    if val >= lvl.requiredValue then
      level = i
    end
  end
  if levels[level+1] then
    neededForNext = levels[level+1].requiredValue - levels[level].requiredValue
    curLvlProgress = val - levels[level].requiredValue
  end
  return level, curLvlProgress, neededForNext

end

local function getBranchLevel(id)
  local branch = getBranchById(id)
  if branch.id == 'missing' then return nil end
  local attValue = career_modules_playerAttributes and career_modules_playerAttributes.getAttribute(branch.attributeKey).value or -1
  return calcBranchLevelFromValue(attValue, id)
end


local function orderAttributeKeysByBranchOrder(list)
  table.sort(list, sortAttributes)
  return list
end


local function orderBranchNamesKeysByBranchOrder(list)
  list = list or tableKeys(branchesById)
  table.sort(list, sortBranchNames)
  return list
end

M.getBranches = getBranches
M.getBranchById = getBranchById
M.getSortedBranches = getSortedBranches
M.getBranchLevel = getBranchLevel
M.calcBranchLevelFromValue = calcBranchLevelFromValue

M.orderAttributeKeysByBranchOrder = orderAttributeKeysByBranchOrder
M.orderBranchNamesKeysByBranchOrder = orderBranchNamesKeysByBranchOrder

return M