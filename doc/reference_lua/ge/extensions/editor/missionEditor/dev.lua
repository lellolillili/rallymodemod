-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}
local modes = {'silent','info','warning','error'}
local icons  = {'visibility_off','info','warning','error'}

function C:init(missionEditor)
  self.missionEditor = missionEditor

end

function C:setMission(mission)
  self.mission = mission
  self.devText = im.ArrayChar(2048, self.mission.devNotes.text or "")
  self.devMission = im.BoolPtr(self.mission.devNotes.devMission or false)
end

function C:draw()
  im.Columns(2)
  im.SetColumnWidth(0,150)

  im.Text("Dev Notes")
  im.NextColumn()
  local editEnded = im.BoolPtr(false)

  editor.uiInputTextMultiline("##Description", self.devText, 2048, im.ImVec2(0,40), nil, nil, nil, editEnded)
  if editEnded[0] then
    self.mission.devNotes.text = ffi.string(self.devText)
    self.mission._dirty = true
  end

  if im.BeginCombo('##mode',self.mission.devNotes.mode) then
    for _, mode in ipairs(modes) do
      if im.Selectable1(mode,mode == self.mission.devNotes.mode) then
        self.mission.devNotes.mode = mode
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end

  im.SameLine()
  if im.Checkbox("Dev Mission##devMission", self.devMission) then
    self.mission.devNotes.devMission = self.devMission[0]
    self.mission._dirty = true
  end im.tooltip("This Mission will only show if the user has devmode enabled.")

  im.Columns(1)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
