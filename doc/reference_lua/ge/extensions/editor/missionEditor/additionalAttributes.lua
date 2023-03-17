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
  self.name = "AdditionalInfo"
  self.attributes, self.sortedAttKeys = gameplay_missions_missions.getAdditionalAttributes()
end

local noneVal = {
  label = "(None)"
}

function C:setMission(mission)
  self.mission = mission
  self.groupIdInput = im.ArrayChar(1024, self.mission.grouping.id or "")
  self.groupLabelInput = im.ArrayChar(2048, self.mission.grouping.label or "")
  self.authorInput = im.ArrayChar(1024, self.mission.author or "")
  self.dateInput = im.IntPtr(self.mission.date or 0)
  self.dateHumanReadable = nil

  self.todInput = im.FloatPtr(self.mission.setupModules.timeOfDay.time or 0)

  self.trafficAmountInput = im.IntPtr(self.mission.setupModules.traffic.amount or 3)
  self.trafficActiveAmountInput = im.IntPtr(self.mission.setupModules.traffic.activeAmount or 3)
  self.trafficParkedAmountInput = im.IntPtr(self.mission.setupModules.traffic.parkedAmount or 0)
  self.trafficRespawnRateInput = im.FloatPtr(self.mission.setupModules.traffic.respawnRate or 1)
  self.trafficActiveDefaultInput = im.BoolPtr(self.mission.setupModules.traffic.activeDefault and true or false)
  self.trafficPrevTrafficInput = im.BoolPtr(self.mission.setupModules.traffic.usePrevTraffic and true or false)
  self.trafficUserOptionsInput = im.BoolPtr(self.mission.setupModules.traffic.useGameOptions and true or false)
  self.trafficSimpleVehsInput = im.BoolPtr(self.mission.setupModules.traffic.useSimpleVehs and true or false)
end

function C:updateDateHumanReadable()
  self.dateHumanReadable = self.dateHumanReadable or os.date('%Y-%m-%d %H:%M:%S', self.mission.date or 0)
end

function C:getMissionIssues(m)
  self:setMission(m)
  local issues = {}
  if not m.additionalAttributes.difficulty then
    table.insert(issues, {type = 'No difficulty set!'})
  end
  if self.mission.grouping.label ~= "" and translateLanguage(self.mission.grouping.label, self.mission.grouping.label, true) == self.mission.grouping.label then
    table.insert(issues, {type = 'Grouping Label has no translation!'})
  end
  if self.mission.author == nil or self.mission.author == "" then
    table.insert(issues, {type = 'No Author set!'})
  end
  if self.mission.date == nil or self.mission.date == 0 then
    table.insert(issues, {type = 'No Date set!'})
  end
  return issues
end

local function todToTime(val)
  local seconds = ((val + 0.50001) % 1) * 86400
  local hours = math.floor(seconds / 3600)
  local mins = math.floor(seconds / 60 - (hours * 60))
  local secs = math.floor(seconds - hours * 3600 - mins * 60)
  return string.format("%02d:%02d:%02d", hours, mins, secs)
end

function C:draw()
  im.PushID1(self.name)
  im.Columns(2)
  im.SetColumnWidth(0,150)
  local editEnded = im.BoolPtr(false)

  editEnded = im.BoolPtr(false)
  im.Text("Author")
  im.tooltip("The Author of this Mission.")
  im.NextColumn()
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 35)
  editor.uiInputText("##author", self.authorInput, 1024, nil, nil, nil, editEnded)
  if editEnded[0] then
    self.mission.author = ffi.string(self.authorInput)
    self.mission._dirty = true
  end
  im.NextColumn()

  editEnded = im.BoolPtr(false)
  im.Text("Date")
  im.tooltip("When this mission was created or last updated.")
  im.NextColumn()
  im.PushItemWidth(300)
  editor.uiInputInt("##date", self.dateInput, 60*60*24, 60*60*24*7, nil, editEnded)
  im.SameLine()
  if im.Button("Now") then
    self.dateInput[0] = os.time()
    editEnded[0] = true
  end
  im.SameLine()
  if editEnded[0] then
    self.mission.date = self.dateInput[0]
    self.mission._dirty = true
    self.dateHumanReadable = nil
  end
  self:updateDateHumanReadable()
  im.SameLine()
  im.Text(self.dateHumanReadable)
  im.NextColumn()

  im.Text("As Scenario")
  im.tooltip("If set, the mission is available as a scenario from the main menu.")
  im.NextColumn()
  if im.Checkbox("Is Available as Scenario", im.BoolPtr(self.mission.isAvailableAsScenario or false)) then
    self.mission.isAvailableAsScenario = not self.mission.isAvailableAsScenario
    self.mission._dirty = true
  end
  im.NextColumn()


  local eh = self.missionEditor.getCurrentEditorHelperWhenActive()
  for _, attKey in ipairs(self.sortedAttKeys) do
    local attribute = self.attributes[attKey]
    local val = attribute.valuesByKey[self.mission.additionalAttributes[attKey]] or noneVal
    im.Text(attribute.label)
    im.NextColumn()
    local isAuto = eh and eh.autoAdditionalAttributes[attKey]
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if isAuto then im.BeginDisabled() end
    if im.BeginCombo('##'..attKey.."AdditionalData", isAuto and "(Automatic)" or val.label) then

      if im.Selectable1(noneVal.label, val.key == nil) then
        self.mission.additionalAttributes[attKey] = nil
        self.mission._dirty = true
      end
      im.Separator()
      for _, v in ipairs(attribute.valuesSorted) do
        if im.Selectable1(v.label, val.key == v.key) then
          self.mission.additionalAttributes[attKey] = v.key
          self.mission._dirty = true
        end
      end
      im.EndCombo()
    end
    if isAuto then im.EndDisabled() im.tooltip("This Value will be automatically set by the mission constructor.") end
    im.PopItemWidth()
    im.NextColumn()
  end

  editEnded = im.BoolPtr(false)
  im.Text("Group Id")
  im.tooltip("Missions with the same ID will be grouped together in the bigmap. Leave empty for no group.")
  im.NextColumn()
  editEnded = im.BoolPtr(false)
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 35)
  editor.uiInputText("##groupId", self.groupIdInput, 1024, nil, nil, nil, editEnded)
  im.PopItemWidth()
  if editEnded[0] then
    self.mission.grouping.id = ffi.string(self.groupIdInput)
    self.mission._dirty = true
  end
  im.NextColumn()

  im.Text("Group Label")
  im.NextColumn()
  editEnded = im.BoolPtr(false)
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 35)
  editor.uiInputText("##GeneralName", self.groupLabelInput, 2048, nil, nil, nil, editEnded)
  im.PopItemWidth()
  if editEnded[0] then
    self.mission.grouping.label = ffi.string(self.groupLabelInput)
    self._groupLabelTranslated = nil
    self.mission._dirty = true
  end
  im.SameLine()
  if not self._groupLabelTranslated then
    self._groupLabelTranslated = translateLanguage(self.mission.grouping.label, noTranslation, true)
  end
  editor.uiIconImage(editor.icons.translate, imVec24x24 , (self._groupLabelTranslated or noTranslation) == noTranslation and imVec4Red or imVec4Green)
  if im.IsItemHovered() then
    im.tooltip(self._groupLabelTranslated)
  end

  im.Separator()
  im.NextColumn()
  im.Text("Time Of Day")
  im.NextColumn()
  if im.Checkbox("##todEnabled", im.BoolPtr(self.mission.setupModules.timeOfDay.enabled)) then
    self.mission.setupModules.timeOfDay.enabled = not self.mission.setupModules.timeOfDay.enabled
    if self.mission.setupModules.timeOfDay.enabled then
      self.mission.setupModules.timeOfDay.time = self.mission.setupModules.timeOfDay.time or (core_environment and core_environment.getTimeOfDay() and core_environment.getTimeOfDay().time) or 0
    else
      self.mission.setupModules.timeOfDay.time = nil
    end
    self.todInput[0] = self.mission.setupModules.timeOfDay.time or 0
    self.mission._dirty = true
  end
  im.SameLine()
  if self.mission.setupModules.timeOfDay.enabled then
    im.PushItemWidth(100)
    if im.InputFloat("##tod", self.todInput) then
      self.todInput[0] = math.max(self.todInput[0],0)
      self.todInput[0] = math.min(self.todInput[0],1)
      self.mission.setupModules.timeOfDay.time = self.todInput[0]
      self.mission._dirty = true
    end
    im.SameLine()
    im.Text(todToTime(self.todInput[0]))
    im.SameLine()
    if im.BeginCombo("##todSelector","...") then
      if im.Selectable1("Now") then
        self.mission.setupModules.timeOfDay.time = (core_environment and core_environment.getTimeOfDay() and core_environment.getTimeOfDay().time) or 0
        self.mission._dirty = true
      end
      for i =0, 48 do
        if im.Selectable1(todToTime((i/48+0.5)%1)) then
          self.mission.setupModules.timeOfDay.time = (i/48+0.5)%1
          self.todInput[0] = (i/48+0.5)%1
          self.mission._dirty = true
        end
      end
      im.EndCombo()
    end
  else
    self.mission.setupModules.timeOfDay.time = nil
    im.BeginDisabled()
    im.Text("Time of Day setup disabled.")
    im.EndDisabled()
  end

  im.Separator()
  im.NextColumn()
  im.Text("Traffic")
  im.NextColumn()
  if im.Checkbox("##trafficEnabled", im.BoolPtr(self.mission.setupModules.traffic.enabled)) then
    self.mission.setupModules.traffic.enabled = not self.mission.setupModules.traffic.enabled
    if not self.mission.setupModules.traffic.amount then -- init values
      self.mission.setupModules.traffic.activeDefault = true
      self.trafficActiveDefaultInput[0] = self.mission.setupModules.traffic.activeDefault
      self.mission.setupModules.traffic.amount = self.trafficAmountInput[0]
      self.mission.setupModules.traffic.activeAmount = self.trafficActiveAmountInput[0]
      self.mission.setupModules.traffic.parkedAmount = self.trafficParkedAmountInput[0]
      self.mission.setupModules.traffic.respawnRate = self.trafficRespawnRateInput[0]
      self.mission.setupModules.traffic.usePrevTraffic = self.trafficPrevTrafficInput[0]
      self.mission.setupModules.traffic.useGameOptions = self.trafficUserOptionsInput[0]
      self.mission.setupModules.traffic.useSimpleVehs = self.trafficSimpleVehsInput[0]
    end
    self.mission._dirty = true
  end
  im.SameLine()
  if self.mission.setupModules.traffic.enabled then
    im.Text("Traffic Setup")
    im.PushItemWidth(100)
    if im.InputInt("Amount##traffic", self.trafficAmountInput, 1) then
      self.mission.setupModules.traffic.amount = self.trafficAmountInput[0]
      self.mission._dirty = true
    end
    im.tooltip("Amount of traffic vehicles to spawn; -1 = auto amount")
    im.PopItemWidth()
    im.PushItemWidth(100)
    if im.InputInt("Active Amount##traffic", self.trafficActiveAmountInput, 1) then
      self.mission.setupModules.traffic.activeAmount = self.trafficActiveAmountInput[0]
      self.mission._dirty = true
    end
    im.tooltip("Amount of active traffic vehicles running at the same time; other vehicles stay hidden until they get cycled.")
    im.PopItemWidth()
    if self.mission.setupModules.traffic.amount ~= 0 and self.mission.setupModules.traffic.activeAmount <= 0 then
      im.SameLine()
      im.TextColored(im.ImVec4(1, 1, 0, 1), " Warning: All traffic vehicles will start out as hidden.")
    end

    im.PushItemWidth(100)
    if im.InputInt("Parked Amount##traffic", self.trafficParkedAmountInput, 1) then
      self.mission.setupModules.traffic.parkedAmount = self.trafficParkedAmountInput[0]
      self.mission._dirty = true
    end
    im.tooltip("Amount of parked vehicles to spawn.")
    im.PopItemWidth()
    im.PushItemWidth(100)
    if im.InputFloat("Respawn Rate##traffic", self.trafficRespawnRateInput, 0.1, nil, "%.2f") then
      self.mission.setupModules.traffic.respawnRate = self.trafficRespawnRateInput[0]
      self.mission._dirty = true
    end
    im.tooltip("Traffic respawn rate; values can range from 0 to 3.")
    im.PopItemWidth()
    if self.mission.setupModules.traffic.respawnRate <= 0 then
      im.SameLine()
      im.TextColored(im.ImVec4(1, 1, 0, 1), " Warning: All traffic vehicles will not respawn.")
    end

    if im.Checkbox("Enable Traffic as Default Setting##traffic", self.trafficActiveDefaultInput) then
      self.mission.setupModules.traffic.activeDefault = self.trafficActiveDefaultInput[0]
      self.mission._dirty = true
    end
    im.tooltip("If true, this mission will start with traffic enabled unless the user changes the setting.")
    if im.Checkbox("Keep Previous Traffic##traffic", self.trafficPrevTrafficInput) then
      self.mission.setupModules.traffic.usePrevTraffic = self.trafficPrevTrafficInput[0]
      self.mission._dirty = true
    end
    im.tooltip("If true, this mission will try to use traffic that already existed in freeroam.")
    if im.Checkbox("Use Settings From Traffic Options##traffic", self.trafficUserOptionsInput) then
      self.mission.setupModules.traffic.useGameOptions = self.trafficUserOptionsInput[0]
      self.mission._dirty = true
    end
    if self.trafficUserOptionsInput[0] then im.BeginDisabled() end
    if im.Checkbox("Use Simple Vehicles##traffic", self.trafficSimpleVehsInput) then
      self.mission.setupModules.traffic.useSimpleVehs = self.trafficSimpleVehsInput[0]
      self.mission._dirty = true
    end
    if self.trafficUserOptionsInput[0] then im.EndDisabled() end
  else
    table.clear(self.mission.setupModules.traffic)
    self.mission.setupModules.traffic.enabled = false
    im.BeginDisabled()
    im.Text("Traffic Setup disabled.")
    im.EndDisabled()
  end

  im.Columns(1)
  im.PopID()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
