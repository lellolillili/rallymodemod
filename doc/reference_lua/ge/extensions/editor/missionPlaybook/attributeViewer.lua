-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local ffi = require("ffi")
local im = ui_imgui
local colorRed, colorGreen = im.ImVec4(1,0.6,0.6,1), im.ImVec4(0.6,1,0.6,1)
local toolWindowName = "Playbook Attribute Viewer"



local plotHelperUtil

local plotInvalid
-- display window
local function onEditorGui(dt)
  if not editor.isWindowVisible("Mission Playbook") then return end
  if editor.beginWindow(toolWindowName, toolWindowName,  im.WindowFlags_MenuBar) then
    local book = editor_missionPlaybook.book
    local data = book.results[book.page]
    if data and data.attributes then
      local sortedKeys = tableKeysSorted(data.attributes)
      im.Columns(4)
      im.Text("Key") im.NextColumn()
      im.Text("Value")   im.NextColumn()
      im.Text("Tier")   im.NextColumn()
      im.Text("Change") im.Separator() im.NextColumn()
      local prevData = book.results[book.page-1]
      if prevData then prevData = prevData.attributes end
      for _, key in ipairs(sortedKeys) do
        im.Text(key)
        im.NextColumn()
        im.Text(tostring(data.attributes[key].value))
        im.NextColumn()
        if data.attributes[key].level then
          local txt = string.format("%d (%d / %d)", data.attributes[key].level, data.attributes[key].curLvlProgress or 0, data.attributes[key].neededForNext or 0)

          local levelDiff = data.attributes[key].level - ((prevData and prevData[key] and prevData[key].level) or 0)
          if levelDiff > 0 then
            im.TextColored(colorGreen, txt)
          else
            im.Text(txt)
          end

        end
        im.NextColumn()
        local change = 0
        if prevData then
          change = data.attributes[key].value - (prevData[key].value or data.attributes[key].value)
        end

        if change > 0 then
          im.TextColored(colorGreen, "+"..tostring(change))
        elseif change < 0 then
          im.TextColored(colorRed, tostring(change))
        end
        im.NextColumn()
      end
      im.Columns(1)
      im.Separator()
      if plotInvalid then
        local plot = {}
        local names = {}
        for pg = 1, #book.results do
          local row = {pg}
          for keyIdx, key in ipairs(sortedKeys) do
            if key ~= "money" then
              table.insert(row, book.results[pg].attributes[key].value or 0)
              table.insert(names, key)
            end
          end
          table.insert(plot, row)
        end
        plotHelperUtil:setData(plot)
        plotHelperUtil:setSeriesNames(names)
        plotInvalid = false
      end
      local size = im.GetContentRegionAvail()
      plotHelperUtil:draw(size.x-10, size.y-10, dt)
    end
    editor.endWindow()
  end
end


local function onWindowMenuItem()
  editor.showWindow("Mission Playbook")
  editor.showWindow(toolWindowName)
end

local plotParams = {
  autoScale = true,
  showCatmullRomCurve = true
}
local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(500,500))
  editor.addWindowMenuItem(toolWindowName, onWindowMenuItem, {groupMenuName="Missions"})
  plotHelperUtil = require('/lua/ge/extensions/editor/util/plotHelperUtil')(plotParams)
end

local function onPlaybookLogAfterStep(resultData)
  local atts = career_modules_playerAttributes.getAllAttributes()
  local data = {}
  for key, val in pairs(atts) do
    local level, curLvlProgress, neededForNext = career_branches.getBranchLevel(key)

    data[key] = {
      value = val.value,
      level = level,
      curLvlProgress = curLvlProgress,
      neededForNext = neededForNext,
    }
  end
  resultData.attributes = data
  plotInvalid = true
end
M.onPlaybookLogAfterStep = onPlaybookLogAfterStep

M.onEditorInitialized = onEditorInitialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorGui = onEditorGui
M.show = onWindowMenuItem

return M
