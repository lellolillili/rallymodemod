-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}
local level = {'check','warning','error'}
local icons  = {'check','warning','error'}
local infoColors = {
  warning = im.ImVec4(1, 1, 0, 1.0),
  error = im.ImVec4(1, 0, 0, 1.0)
}

function C:init(missionEditor)
  self.missionEditor = missionEditor

end

function C:setMission(mission)
  self.mission = mission
end

function C:draw()
  if not self.mission._issueList then return end
  im.Columns(2)
  im.SetColumnWidth(0,150)

  im.Text("Issues")
  im.NextColumn()
  if self.mission._issueList.count == 0 then
    im.Text("No Issues!")
  end

  for _, issue in ipairs(self.mission._issueList) do
    im.BulletText(issue.type)
  end



  im.Columns(1)
end

function C:calculateMissionIssues(missionList, windows)
  local issues = {list = {}}
  for _, mission in ipairs(missionList) do
    mission._issueList = {list = {}, count = 0, type = 'warning'}
    for _, w in ipairs(windows) do
      if w.getMissionIssues then
        for _, issue in ipairs(w:getMissionIssues(mission) or {}) do
          issue.missionId = mission.id
          table.insert(issues.list, issue)
          table.insert(mission._issueList, issue)
          mission._issueList.count = mission._issueList.count + 1
        end
      end
      if mission._issueList.count == 0 then
        mission._issueList.type = 'check'
        mission._issueList.color = im.ImVec4(0, 1, 0, 1.0)
      else
        local c = math.min(mission._issueList.count, 10)
        mission._issueList.color = im.ImVec4(0.8+c*0.02, 0.8-0.08*c, 0, 1.0)
        mission._issueList.type = 'warning'
      end
    end
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
