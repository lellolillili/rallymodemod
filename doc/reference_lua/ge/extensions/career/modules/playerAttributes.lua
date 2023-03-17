-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local dlog = function(m) log("D","",m) end -- set to nop to disable loggin

M.dependencies = {'career_career'}

local attributes

local function init()
  attributes = {}
  attributes["beamXP"] = {value = 0, min = 0}
  attributes["money"] = {value = 10000, min = 0}
  for _, branch in ipairs(career_branches.getSortedBranches()) do
    attributes[branch.attributeKey] = {value = branch.defaultValue or 0}
  end
  dlog("Initialized Attributes to: " ..dumps(attributes))
end

local function clampAttributeValue(attribute)
  if attribute.max then
    attribute.value = math.min(attribute.value, attribute.max)
  end
  if attribute.min then
    attribute.value = math.max(attribute.value, attribute.min)
  end
end

local function setAttribute(attributeName, value)
  local attribute = attributes[attributeName]
  attribute.value = value
  clampAttributeValue(attribute)
  extensions.hook("onPlayerAttributesChanged")
end

local function addAttribute(attributeName, value)
  local attribute = attributes[attributeName] or {value = 0}
  local before = attribute.value
  local after = attribute.value + value
  setAttribute(attributeName, after)
  dlog("Added " .. dumps(value) .. " to attribute " .. dumps(attributeName) ..". ("..dumps(before).." -> " .. dumps(attribute.value))
end

local function getAttribute(attribute)
  return attributes[attribute]
end

local function getAllAttributes()
  return attributes
end

local function onExtensionLoaded()
  if not career_career.isCareerActive() then return false end
  if not attributes then
    init()
  end

  -- load from saveslot
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end
  local jsonData = jsonReadFile(savePath .. "/career/playerAttributes.json") or {}

  for name, data in pairs(jsonData) do
    if attributes[name] and attributes[name].value then
      attributes[name].value = data.value
    end
  end
end

-- this should only be loaded when the career is active
local function onSaveCurrentSaveSlot(currentSavePath)
  jsonWriteFile(currentSavePath .. "/career/playerAttributes.json", attributes, true)
end

M.addAttribute = addAttribute
M.setAttribute = setAttribute
M.getAttribute = getAttribute
M.getAllAttributes = getAllAttributes

M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onExtensionLoaded = onExtensionLoaded
return M