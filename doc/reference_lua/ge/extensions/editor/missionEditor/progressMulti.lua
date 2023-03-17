-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}
local missionTypesDir = "/gameplay/missionTypes"
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')
-- style helper
local colors = {}
colors.grey = { 0.6, 0.6, 0.6 }
colors.red = { 0.7, 0.2, 0.2 }
colors.green = { 0.1, 0.7, 0.0 }
local colorCache = {}
local function pushStyle(colorName)
  if not colorCache[colorName] then
    local color = colors[colorName]
    colorCache[colorName] = im.ImVec4(color[1], color[2], color[3], 1)
  end
  im.PushStyleColor2(im.Col_Text, colorCache[colorName])
end
local function popStyle(colorName)
  im.PopStyleColor(im.Int(1))
end

function C:init(missionEditor)
  self.missionEditor = missionEditor
  self.rawEditPerMission = {}
  self.tabName = "Progress Multi"
  self.rawCheckbox = im.BoolPtr(false)
end



function C:setMission(mission)
  self.mission = mission
  self.missionInstance = gameplay_missions_missions.getMissionById(mission.id)
  self.formattedSaveData = gameplay_missions_progress.formatSaveDataForUi(mission.id)
  self.currentProgressKey = self.missionInstance.currentProgressKey or self.missionInstance.defaultProgressKey or 'default'
  -- notify type editor
  self.rawCheckbox[0] = false
  if not self.rawEditPerMission[mission.id] then
    self.rawEditPerMission[mission.id] = false
  end
end

function C:draw()
  local progressKeys = self.formattedSaveData.allProgressKeys

  im.HeaderText("Multi Progress: "..self.mission.missionType)
  im.Separator()

  im.PushItemWidth(200)
  if im.BeginCombo("Progress Key", self.currentProgressKey) then
    for _, k in ipairs(progressKeys) do
      if im.Selectable1(k, k==self.currentProgressKey) then
        self.currentProgressKey = k
      end
    end
    im.EndCombo()
  end

  -- this is atm only the current mission, because the formatSaveDataForUi function in progress.lua was changed
  local currentAggregatesByKey = self.formattedSaveData.formattedProgressByKey[self.currentProgressKey].ownAggregate

  if not currentAggregatesByKey then
    return
  end
  if im.BeginTable('MultiProgression', #currentAggregatesByKey.labels) then

    for _,l in pairs(currentAggregatesByKey.labels) do
      im.TableSetupColumn(l)
    end

    im.TableHeadersRow()
    im.TableNextColumn()
    for _, missionData in pairs(currentAggregatesByKey.rows) do
      for _, c in pairs(missionData) do
        im.Text(c.text)
        im.TableNextColumn()
      end
    end
  end
  im.EndTable()

  im.Separator()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
