-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}
local imVec24x24 = im.ImVec2(24,24)
local imVec16x16 = im.ImVec2(16,16)
local imVec4Red = im.ImVec4(1,0,0,1)
local imVec4Green = im.ImVec4(0,1,0,1)
local noTranslation = "No Translation found!"
function C:init(missionEditor)
  self.missionEditor = missionEditor


  self.reccomendedAttributes = gameplay_missions_missions.getRecommendedAttributesList()
  self.reccBooleans = {}
  for _, recc in ipairs(self.reccomendedAttributes) do
    self.reccBooleans[recc] = im.BoolPtr(false)
  end
end

function C:getMissionIssues(m)
  self:setMission(m)
  local issues = {}
  if self.mission.name == "" then
    table.insert(issues, {type = 'Name is missing!'})
  end
  if self.mission.description == "" then
    table.insert(issues, {type = 'Description is missing!'})
  end
  if translateLanguage(self.mission.name, self.mission.name, true) == self.mission.name then
    table.insert(issues, {type = 'Name has no translation!'})
  end
  if translateLanguage(self.mission.description, self.mission.description, true) == self.mission.description then
    table.insert(issues, {type = 'Description has no translation!'})
  end
  return issues
end

function C:setMission(mission)
  self.mission = mission
  self.nameText = im.ArrayChar(1024, self.mission.name)
  self.descText = im.ArrayChar(2048, self.mission.description)
  self._titleTranslated = nil
  self._descTranslated = nil
  self._groupLabelTranslated = nil
  for _, recc in ipairs(self.reccomendedAttributes) do
    self.reccBooleans[recc][0] = (self.mission.recommendedAttributesKeyBasedCache and self.mission.recommendedAttributesKeyBasedCache[recc]) or false
  end
  self.inputTrafficAllowed = im.BoolPtr(mission.trafficAllowed or false)
end

function C:draw()

  im.Columns(2)
  im.SetColumnWidth(0,150)

  im.Text("Name")
  im.NextColumn()
  local editEnded = im.BoolPtr(false)
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 35)
  editor.uiInputText("##GeneralName", self.nameText, 1024, nil, nil, nil, editEnded)
  im.PopItemWidth()
  if editEnded[0] then
    self.mission.name = ffi.string(self.nameText)
    self._titleTranslated = nil
    self.mission._dirty = true
  end
  im.SameLine()
  if not self._titleTranslated then
    self._titleTranslated = translateLanguage(self.mission.name, noTranslation, true)
  end
  editor.uiIconImage(editor.icons.translate, imVec24x24 , (self._titleTranslated or noTranslation) == noTranslation and imVec4Red or imVec4Green)
  if im.IsItemHovered() then
    im.tooltip(self._titleTranslated)
  end


  im.NextColumn()

  im.Text("Description")
  im.NextColumn()
  editEnded = im.BoolPtr(false)
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 35)
  editor.uiInputTextMultiline("##Description", self.descText, 2048, im.ImVec2(0,100), nil, nil, nil, editEnded)
  im.PopItemWidth()
  if editEnded[0] then
    self.mission.description = ffi.string(self.descText)
    self._descTranslated = nil
    self.mission._dirty = true
  end
    im.SameLine()
  if not self._descTranslated then
    self._descTranslated = translateLanguage(self.mission.description, noTranslation, true)
  end
  editor.uiIconImage(editor.icons.translate, imVec24x24 , (self._descTranslated or noTranslation) == noTranslation and imVec4Red or imVec4Green)
  if im.IsItemHovered() then
    im.tooltip(self._descTranslated)
  end

  im.NextColumn()
  im.Columns(1)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
