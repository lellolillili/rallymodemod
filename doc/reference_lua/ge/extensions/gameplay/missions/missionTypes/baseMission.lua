-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

-- This is called when a mission of this type is being created. Load files, initialize variables etc
function C:init()
  self.missionTypeLabel = "bigMap.missionLabels."..self.missionType
  self.progressKeyTranslations = {default = "missions.progressKeyLabels.default", custom = 'missions.progressKeyLabels.custom'}
end

function C:getProgressKeyTranslation(progressKey)
  if self.progressKeyTranslations then
    return self.progressKeyTranslations[progressKey] or progressKey
  end
  return progressKey
end

-- when the mission starts
function C:onStart() end
-- called each frame
function C:onUpdate(dtReal, dtSim, dtRaw) end
-- called when the activity stops. attempt might be nil
function C:onStop(data) end

return function(derivedClass, ...)
  local o = ... or {}
  setmetatable(o, C)
  C.__index = C
  o:init()
  for k, v in pairs(derivedClass) do
    o[k] = v
  end
  local init = o:init()
  return o, init
end
