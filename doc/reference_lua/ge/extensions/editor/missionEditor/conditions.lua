-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui

local C = {}
local missionConditions
local comparisonOps = getComparisonOps()
local index = 0
local depth = 0
local padPerDepth = 40
local conditionFunctions = {}
local search = require('/lua/ge/extensions/editor/util/searchUtil')()

-- this will come from mission manager once refactored
local conditionsSortedCache
local function getConditionsSorted()
  if not conditionsSortedCache then
    conditionsSortedCache = tableKeys(missionConditions)
    table.sort(conditionsSortedCache)
  end
  return conditionsSortedCache
end



function C:init(missionEditor, field, name)
  self.missionEditor = missionEditor
  self.field = field
  self.name = name
  missionConditions = {}
  local files = FS:findFiles('/lua/ge/extensions/gameplay/missions/unlocks/conditions/','*.lua', -1)
  for _, file in ipairs(files) do
    local aConds = require(file:sub(0,-5))
    for key, value in pairs(aConds) do
      missionConditions[key] = value
    end
  end
end

function C:setMission(mission)
  self.mission = mission
  self.fields = {}
end


local function displayMissionCondition(self, condition)
  index = index + 1
  im.PushItemWidth(200)

  local ret = search:beginSearchableSimpleCombo(im, '##'..condition.type..'selectMission'..index, condition.missionId, gameplay_missions_missions.getAllIds())
  if ret then
    condition.missionId = ret
    self.mission._dirty = true
  end
  im.PopItemWidth()
end

local function displayMissionConditionWithProgressKey(self, condition)
  index = index + 1
  im.PushItemWidth(200)
  local ret = search:beginSearchableSimpleCombo(im, '##'..condition.type..'selectMission'..index, condition.missionId, gameplay_missions_missions.getAllIds())
  if ret then
    condition.missionId = ret
    self.mission._dirty = true
  end
  local editEnded = im.BoolPtr(false)
  im.SameLine()
  im.PushItemWidth(120)
  local  val, name =  'vName'..index, 'vnName'..index
  if not self.fields[val] then self.fields[val] = im.ArrayChar(1024, condition.progressKey or '') end
  if im.InputText("##"..'valueInput'..index, self.fields[val], 1024) then
    self.mission._dirty = true
    condition.progressKey = ffi.string(self.fields[val])
  end
  im.tooltip("use 'any' for any progress key, 'default' for using the default key.")
  im.PopItemWidth()
end

local function displayNestedCondition(self, condition)
  index = index + 1
  im.NewLine()
  condition.nested = condition.nested or {}
  local count = #(condition.nested)
  depth = depth +1
  local rem = nil
  for i, con in ipairs(condition.nested) do
    if conditionFunctions.displayCondition(self, con) then
      rem = i
    end
  end
  if rem then
    table.remove(condition.nested, i)
    self.mission._dirty = true
  end
  im.Dummy(im.ImVec2(depth * padPerDepth, 1)) im.SameLine()
  if im.Button("Add##"..index) then
    table.insert(condition.nested,{type = 'always'})
    self.mission._dirty = true
  end
  depth = depth -1

end

local function displaySimpleCondition(self, condition)
  index = index + 1
  im.Dummy(im.ImVec2(1,1))
end

local function displayCondition(self, condition)
  index = index +1
  local rem = nil

  im.Dummy(im.ImVec2(depth * padPerDepth, 1)) im.SameLine()
  if condition.transient then
    editor.uiIconImageButton(editor.icons.visibility_off, im.ImVec2(24, 24), nil, nil, nil,'##rem'..condition.type..index)
    im.tooltip("This Condition is transient (generated at runtime) and can't be edited.")
    im.BeginDisabled()
  else
    if editor.uiIconImageButton(editor.icons.delete_forever, im.ImVec2(24, 24), nil, nil, nil,'##rem'..condition.type..index) then
      rem = true
    end
  end
  im.SameLine()
  im.PushItemWidth(200)
  if im.BeginCombo('##'..condition.type..index, condition.type) then
    --if self.field == 'visible' then
      if im.Selectable1("automatic", "automatic" == condition.type) then
        condition.type = "automatic"
        self.fields = {}
        self.mission._dirty = true
      end
      im.Separator()
    --end
    for _, cType in ipairs(getConditionsSorted()) do
      if im.Selectable1(cType, cType == condition.type) then
        condition.type = cType
        self.fields = {}
        self.mission._dirty = true
      end
      im.tooltip(missionConditions[cType].info or "Missing info for this condition.")
    end
    im.EndCombo()
  end
  im.PopItemWidth()
  im.SameLine()
  if missionConditions[condition.type] and conditionFunctions[missionConditions[condition.type].editorFunction] then
    conditionFunctions[missionConditions[condition.type].editorFunction](self,condition)
  else
    displaySimpleCondition(self, condition)
  end
  if condition.transient then
    im.EndDisabled()
  end
  return rem
end

local function displayBranchLevel(self, condition)
  index = index + 1
  im.Text("Attribute ")
  im.SameLine()
  im.PushItemWidth(150)
  if im.BeginCombo("##branchSelector"..index, condition.branchId or "(None!)") then
    for _, branch in ipairs(career_branches.getSortedBranches()) do
      if im.Selectable1(branch.id, branch.id == condition.branchId) then
        self.mission._dirty = true
        condition.branchId = branch.id
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()
  im.SameLine()
  im.Text("Level")
  im.SameLine()
  local fieldName = "levelPtr"..index
  condition.level = condition.level or 1
  if not self.fields[fieldName] then self.fields[fieldName] = im.IntPtr(condition.level or 1) end
  im.PushItemWidth(120)
  if im.InputInt("##levleSelector"..index, self.fields[fieldName]) then
    self.mission._dirty = true
    condition.level = self.fields[fieldName][0]
  end
  im.PopItemWidth()
end

conditionFunctions.displayCondition = displayCondition
conditionFunctions.displayMissionCondition = displayMissionCondition
conditionFunctions.displayNestedCondition = displayNestedCondition
conditionFunctions.displaySimpleCondition = displaySimpleCondition
conditionFunctions.displayMissionConditionWithProgressKey = displayMissionConditionWithProgressKey
conditionFunctions.displayBranchLevel = displayBranchLevel


function C:draw()
  im.PushID1(self.name)
  im.Columns(2)
  im.SetColumnWidth(0,150)
  im.Text(self.name)
  im.NextColumn()
  index = 0
  local condition = self.mission[self.field] or {type='always'}
  depth = 0

  local rem = conditionFunctions.displayCondition(self, condition)

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


--[[

local function displayValueCondition(self, condition, index)
  im.PushItemWidth(120)
  if not condition.value then condition.value = 0 end
  if not condition.valueName then condition.valueName = "money" end
  local  val, name =  'vName'..index, 'vnName'..index
  if not self.fields[val] then self.fields[val] = im.FloatPtr(condition.value) end
  local editEnded = im.BoolPtr(false)
  im.SameLine()
  im.PushItemWidth(120)
  if im.InputFloat("##"..'valueInput'..index, self.fields[val]) then
    self.mission._dirty = true
    condition.value = self.fields[val][0]
  end
end

local function displayDrivetrainLayoutCondition(self, condition, index)
  im.PushItemWidth(200)
  if im.BeginCombo('##'..condition.type..'drivetrainLayout'..index, condition.value or "") then
    for _,i in ipairs({ "4WD", "AWD", "FWD", "Other", "RWD" }) do
      if im.Selectable1(i..'##'..index, i == condition.value) then
        condition.value = i
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()
end
local function displayPropulsion(self, condition, index)
  im.PushItemWidth(200)
  if im.BeginCombo('##'..condition.type..'drivetrainLayout'..index, condition.value or "") then
    for _,i in ipairs({ "Electric", "ICE" }) do
      if im.Selectable1(i..'##'..index, i == condition.value) then
        condition.value = i
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()
end

local function displayNumericCondition(self, condition, index)
  im.PushItemWidth(120)
  if not condition.comparator then condition.comparator = ">" end
  if not condition.value then condition.value = 0 end
  if not condition.valueName then condition.valueName = "money" end
  local  val, name =  'vName'..index, 'vnName'..index
  if not self.fields[name] then self.fields[name] = im.ArrayChar(1024, condition.valueName) end
  if not self.fields[val] then self.fields[val] = im.FloatPtr(condition.value) end
  local editEnded = im.BoolPtr(false)
  editor.uiInputText("##"..'numericName'..index..self.name, self.fields[name], 1024, nil, nil, nil, editEnded)
  if editEnded[0] then
    condition.valueName = ffi.string(self.fields[name])
    self.mission._dirty = true
  end
  im.SameLine()
  im.PushItemWidth(60)
  if im.BeginCombo('##'..condition.type..index..'numeric'..self.name, condition.comparator) then
    for _, c in ipairs(comparisonOps) do
      if im.Selectable1(c.opSymbol..'##'..index..self.name, c.opSymbol == condition.comparator) then
        condition.comparator = c.opSymbol
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
  im.SameLine()
  im.PushItemWidth(120)
  if im.InputFloat("##"..'numericInput'..index..self.name, self.fields[val]) then
    self.mission._dirty = true
    condition.value = self.fields[val][0]
  end
end

local function displayCareerLevelCondition(self, condition, index)
  im.PushItemWidth(120)
  if not condition.level then condition.level = 1 end
  local  val =  'cval'..index
  if not self.fields[val] then self.fields[val] = im.FloatPtr(condition.level) end
  if im.InputFloat("Min Career Level##"..'displayCareerLevelCondition'..index..self.name, self.fields[val]) then
    self.mission._dirty = true
    condition.level = self.fields[val][0]
  end
end

local function displayWPCategoryCondition(self, condition, index)
  if not condition.value then condition.value = 'A' end
  im.Text("Player Vehicle WPCategory is ")
  im.SameLine()
  im.PushItemWidth(60)
  if im.BeginCombo('##'..condition.type..index..'wpCat'..self.name, condition.value) then
    for _, c in ipairs({"A","B","C","D","E"}) do
      if im.Selectable1(c..'##'..index..self.name, c == condition.value) then
        condition.value = c
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
end

local function displayManufacturerCondition(self, condition, index)
  if not condition.value then condition.value = "BeamNG" end
  im.Text(" is ")
  im.SameLine()
  im.PushItemWidth(250)
  local name =  'manufacName'..index
  if not self.fields[name] then self.fields[name] = im.ArrayChar(1024, condition.value) end
  local editEnded = im.BoolPtr(false)
  editor.uiInputText("##"..'ManuFacName'..index..self.name, self.fields[name], 1024, nil, nil, nil, editEnded)
  if editEnded[0] then
    condition.value = ffi.string(self.fields[name])
    self.mission._dirty = true
  end
  if not self.manufacturerList then
    self.manufacturerList = {}
    local mans = {}
    for model, info in pairs(core_vehicles.getModelList().models) do
      if info.Brand then
        mans[info.Brand] = true
      end
    end
    for k, _ in pairs(mans) do table.insert(self.manufacturerList, k) end
    table.sort(self.manufacturerList)
  end
  im.PopItemWidth()
  im.SameLine()
  im.PushItemWidth(60)
  if im.BeginCombo('##manuFacCombo'..index..self.name, "...") then
    for idx, man in ipairs(self.manufacturerList) do
      if im.Selectable1(man..'##ManSelect'..idx..self.name, man == condition.value) then
        self.fields[name] = im.ArrayChar(1024, man)
        condition.value = man
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
end
]]