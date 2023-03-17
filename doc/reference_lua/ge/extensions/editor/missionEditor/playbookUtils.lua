-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}

local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

function C:init(missionEditor)
  self.missionEditor = missionEditor
  self.tabName = "Playbook Utils"
end



function C:setMission(mission)
  self.mission = mission
  self.missionInstance = gameplay_missions_missions.getMissionById(mission.id)
end




function C:draw()

  if im.Button("Add Empty") then
    local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = {}}
    table.insert(editor_missionPlaybook.book.instructions, instruction)
  end
  if im.Button("Add All Stars") then
    local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = {}}
    for _, key in ipairs(self.missionInstance.careerSetup._activeStarCache.sortedStars) do
      instruction.stars[key] = true
    end
    table.insert(editor_missionPlaybook.book.instructions, instruction)
  end

  if im.Button("Add All Default Stars") then
    local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = {}}
    for _, key in ipairs(self.missionInstance.careerSetup._activeStarCache.defaultStarKeysSorted) do
      instruction.stars[key] = true
    end
    table.insert(editor_missionPlaybook.book.instructions, instruction)
  end

  if im.Button("Add All Bonus Stars") then
    local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = {}}
    for _, key in ipairs(self.missionInstance.careerSetup._activeStarCache.bonusStarKeysSorted) do
      instruction.stars[key] = true
    end
    table.insert(editor_missionPlaybook.book.instructions, instruction)
  end

  if im.Button("Add Random Single Star") then
    local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = {}}
    local stars = deepcopy(self.missionInstance.careerSetup._activeStarCache.sortedStars)
    if #stars > 1 then
      arrayShuffle(stars)
      instruction.stars[stars[1]] = true
    end
    table.insert(editor_missionPlaybook.book.instructions, instruction)
  end
  im.tooltip("Only a single star enabled, no logic for default stars etc")

  if im.Button("Add Randomized All Stars") then
    local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = {}}
    for _, key in ipairs(self.missionInstance.careerSetup._activeStarCache.sortedStars) do
      instruction.stars[key] = math.random() > 0.5
    end
    table.insert(editor_missionPlaybook.book.instructions, instruction)
  end
  im.tooltip("Each star randomly enabled or not, no logic for default stars etc")

  im.Separator()

  if im.Button("Add All Stars Individually") then
    local stars = {}
    for _, key in ipairs(self.missionInstance.careerSetup._activeStarCache.sortedStars) do
      stars[key] = true
      local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = deepcopy(stars)}
      table.insert(editor_missionPlaybook.book.instructions, instruction)
    end
  end
  im.tooltip("Add one attempt per star, enabling more and more")


  if im.Button("Add All Default Stars Individually, Sequential") then
    local stars = {}
    for _, key in ipairs(self.missionInstance.careerSetup._activeStarCache.defaultStarKeysSorted) do
      stars[key] = true
      local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = deepcopy(stars)}
      table.insert(editor_missionPlaybook.book.instructions, instruction)
    end
  end
  im.tooltip("Add one attempt per star, enabling more and more")

  if im.Button("Add All Bonus Stars Randomly Individually") then
    local keys = deepcopy(self.missionInstance.careerSetup._activeStarCache.bonusStarKeysSorted)
    arrayShuffle(keys)
    for _, key in ipairs(keys) do
      local instruction = {type = "missionAttempt", missionId = self.mission.id, stars = {[''..key] = true}}
      table.insert(editor_missionPlaybook.book.instructions, instruction)
    end
  end
  im.tooltip("Adds one attempt per bonus star, randomly ordered")


end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
