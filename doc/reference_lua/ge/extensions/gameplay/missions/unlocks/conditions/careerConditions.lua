-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.branchLevel = {
  info = 'The user has to have a certain level in a career branch.',
  editorFunction = "displayBranchLevel",
  getLabel = function(self) return {txt = "missions.missions.unlock.attributeLevel.atLeast", context = {branchName = career_career and career_branches.getBranchById(self.branchId).name or self.branchId, level = self.level}} end,
  conditionMet = function(self) return ((not career_career) or (not career_career.isCareerActive()) or (not career_branches)) or career_branches.getBranchLevel(self.branchId) >= self.level end
}


return M