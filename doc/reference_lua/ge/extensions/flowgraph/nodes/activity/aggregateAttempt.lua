-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Aggregate Attempt'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
C.description = "Aggregates attempt and gives results."
C.category = 'once_p_duration'

C.pinSchema = {

  { dir = 'in', type = 'table', name = "attempt", tableType = "attemptData",  description = "Attempt Data for other nodes to process", fixed=true },
  { dir = 'in', type = 'string', name = "progressKey", description = "Progress Key to use", fixed=true },
  { dir = 'out', type = 'table', name = "change", description = "Change Object", fixed=true },
  { dir = 'out', type = 'string', name = "outroText", description = "Text associated with the highest default star in the attempt.", fixed=true },
  { dir = 'out', type = 'table', name = "outroTranslation", description = "Text associated with the highest default star in the attempt, as a translation object with the attempt data as context.", tableType = 'translationObject', fixed=true },

  { dir = 'out', type = 'bool', name = "newBestType", description = "if a new best type was achieved", fixed=true, hidden=true },
}

C.tags = {'activity'}
C.allowCustomOutPins = true
function C:init()

end

function C:workOnce()
  if self.pinIn.flow.value then
    if not self.mgr.activity then return end
    local attempt = self.pinIn.attempt.value
    -- todo: get progress key
    local progressKey = self.pinIn.progressKey.value or self.mgr.activity.currentProgressKey or self.mgr.activity.defaultProgressKey
    local totalChange = gameplay_missions_progress.aggregateAttempt(self.mgr.activity.id, attempt, progressKey)
    local aggregateChange = totalChange.aggregateChange
    local unlockChange = totalChange.unlockChange
    local nextMissionsUnlock = totalChange.nextMissionsUnlock
    if not (career_career and career_career.isCareerActive()) then
      gameplay_missions_progress.saveMissionSaveData(self.mgr.activity.id)
    end

    local highestDefaultStarOutroText = self.mgr.activity.careerSetup.starOutroTexts['noStarUnlocked'] or ""
    if highestDefaultStarOutroText == "" then
      highestDefaultStarOutroText = self.mgr.activity.defaultStarOutroTexts['noStarUnlocked'] or ""
    end
    for _, starKey in ipairs(self.mgr.activity.careerSetup._activeStarCache.defaultStarKeysSorted) do
      if attempt.unlockedStars[starKey] then
        local txt = self.mgr.activity.careerSetup.starOutroTexts[starKey] or ""
        if txt == "" then
          txt = self.mgr.activity.defaultStarOutroTexts[starKey] or ""
        end
        highestDefaultStarOutroText = txt
      end
    end

    if highestDefaultStarOutroText == "" then
     highestDefaultStarOutroText =  "(No Text!)"
    end
    self.pinOut.outroText.value = highestDefaultStarOutroText
    self.pinOut.outroTranslation.value =  { txt = highestDefaultStarOutroText, context = deepcopy(attempt.data) }

    self.pinOut.change.value = totalChange or {}
    for key, val in pairs(aggregateChange) do
      if self.pinOut[key] then
        self.pinOut[key].value = val
      end
    end
  end
end


return _flowgraph_createNode(C)
