-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.__index = C

function C:init(qualitiyLevelsFilename, groupName)
  self.currentQualityLevel = ""
  self.qualityLevels = {}

  local group = qualitiyLevelsFilename and require(qualitiyLevelsFilename) or {}
  for k, v in pairs(group.qualityLevels or {}) do
    self.qualityLevels[k] = v
  end

  self.name = groupName or 'unnamed_quality_group'
  self.onApply = group.onApply or nop
end

function C:applyLevel(levelString)
  if levelString and self.qualityLevels then
    local qualityLevel = self.qualityLevels[levelString] or {}
    self:apply(qualityLevel)
    self.currentQualityLevel = levelString
  end
end

function C:getCurrentLevel(levelString)
  return self.qualityLevels[self.currentQualityLevel]
end

function C:getCurrentLevelId()
  return self.currentQualityLevel
end

function C:apply(qualityLevel)
  if type(qualityLevel) == 'table' then
    local changeDetected = false
    for key,value in pairs(qualityLevel) do
      local currentValue = TorqueScriptLua.getVar(key)
      changeDetected = changeDetected or tostring(currentValue) ~= tostring(value)
      TorqueScriptLua.setVar(key, value)
    end
    if changeDetected then
      self:onApply()
    end
  end
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW
return function(qualitiyLevelsFilename, groupName, ...)
  local o = ... or {}
  setmetatable(o, C)
  o:init(qualitiyLevelsFilename, groupName)
  return o
end

