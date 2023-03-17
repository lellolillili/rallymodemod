-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local ffi = require("ffi")
local im = ui_imgui
local hColor = im.ImVec4(0.3,1,0.2,1)
local toolWindowName = "Playbook Unlocked Missions Viewer"


-- display window
local function onEditorGui()
  if not editor.isWindowVisible("Mission Playbook") then return end
  if editor.beginWindow(toolWindowName, toolWindowName,  im.WindowFlags_MenuBar) then
    local book = editor_missionPlaybook.book
    local data = book.results[book.page]
    if data then
      im.Columns(3)
      im.Text("Startable") im.NextColumn()
      im.Text("Visible")   im.NextColumn()
      im.Text("Invisible") im.Separator() im.NextColumn()

      for _, key in ipairs({"startable","visible","invisible"}) do
        for _, id in ipairs(data.unlockedMissions[key]) do
          local highlight = false
          if key == "startable" then
            if data.funRet and data.funRet.unlockChange and data.funRet.unlockChange.byId[id] then
              highlight = true
            end
          end
          if highlight then
            im.TextColored(hColor, id)
          else
            im.Text(id)
          end
          im.tooltip(id)
        end
        im.NextColumn()
      end

      im.Columns(1)
    end
    editor.endWindow()
  end
end


local function onWindowMenuItem()
  editor.showWindow("Mission Playbook")
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(500,500))
  editor.addWindowMenuItem(toolWindowName, onWindowMenuItem, {groupMenuName="Missions"})
end

local function onPlaybookLogAfterStep(resultData)
  local data = {
    startable = {},
    visible = {},
    invisible = {}

  }
  for _, id in ipairs(gameplay_missions_missions.getAllIds()) do
    local m = gameplay_missions_missions.getMissionById(id)
    if m.careerSetup.showInCareer then
      if m.unlocks.startable and m.unlocks.visible then
        table.insert(data.startable, id)
      elseif m.unlocks.visible then
        table.insert(data.visible, id)
      else
        table.insert(data.invisible, id)
      end
    end
  end
  resultData.unlockedMissions = data
end
M.onPlaybookLogAfterStep = onPlaybookLogAfterStep

M.onEditorInitialized = onEditorInitialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorGui = onEditorGui
M.show = onWindowMenuItem

return M
