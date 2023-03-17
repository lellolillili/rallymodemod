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
  self.oldMissionTypeData = {}
  self.missionTypeEditors = {}

  self.missionTypes = gameplay_missions_missions.getMissionTypes()
  table.sort(self.missionTypes)
  for _, missionType in ipairs(self.missionTypes) do
    self.missionTypeEditors[missionType] = gameplay_missions_missions.getMissionEditorForType(missionType)
  end

  self.rawCheckbox = im.BoolPtr(false)
end

-- see if the mission type has an editor.
function C:loadEditor(missionType)
  local reqPath = missionTypesDir.."/"..missionType .."/editor"
  local luaPath = reqPath..".lua"
  if not FS:fileExists(luaPath) then
    log("W", "", "found no editor for mission type " .. missionType ..": "..dumps(luaPath))
  else
    self.missionTypeEditors[missionType] = require(reqPath)(self.missionEditor)
    if not self.missionTypeEditors[missionType] then
      log("E", "", "could not load editor for mission type " .. missionType .. ": "..dumps(reqPath))
    end
  end
  -- make a default editor if none has been found.
  if not self.missionTypeEditors[missionType] then
    local E = {}
    E.__index = E
    self.missionTypeEditors[missionType] = gameplay_missions_missions.editorHelper(E, self.missionEditor)
  end
end

function C:setMission(mission)
  self.mission = mission
  -- notify type editor
  if self.missionTypeEditors[mission.missionType] then
    self.missionTypeEditors[mission.missionType]:setMission(mission)
  end
  if not self.rawEditPerMission[mission.id] then
    self.rawEditPerMission[mission.id] = false
  end
  self.missing = self.missionTypeEditors[mission.missionType]:checkMission(self.mission)
end

function C:fillGeneric(mission)
  self.missionTypeEditors[mission.missionType] = gameplay_missions_missions.getMissionEditorForType(mission.missionType)
  mission.missionTypeData = self.missionTypeEditors[mission.missionType] and self.missionTypeEditors[mission.missionType]:getNewData() or {}
end

function C:changeMissionType(newType, force)
  -- store previous data
  local oldType = self.mission.missionType
  if not self.oldMissionTypeData[self.mission.id] or force then self.oldMissionTypeData[self.mission.id] = {} end
  self.oldMissionTypeData[self.mission.id][oldType] = deepcopy(self.mission.missionTypeData)

  -- create new type data
  local newData =  {}
  if self.missionTypeEditors[newType] then
    newData = self.missionTypeEditors[newType]:getNewData()
  end
  -- check if we have stored data for the new type, use that instead
  if self.oldMissionTypeData[self.mission.id][newType] ~= nil then
    newData = deepcopy(self.oldMissionTypeData[self.mission.id][newType])
  end

  -- apply to mission
  self.mission.missionTypeData = newData
  self.mission.missionType = newType
  self:setMission(self.mission)
end

function C:openPopup()
  im.OpenPopup("missionFGVariables")
end

function C:variablesHelperPopup()
  if im.BeginPopup("missionFGVariables") then
    local scale = editor.getPreference("ui.general.scale")
    local mgr = editor_flowgraphEditor.getManager()
    if mgr and self.mission then
      im.BeginChild1("mfgvarContainter", im.ImVec2(350*scale,350*scale))
      im.Text("Project: " .. mgr.name)
      if not mgr.allowEditing then im.BeginDisabled() end
      if not self._sortedVars then
        self._vars = self.missionTypeEditors[self.mission.missionType]:getAllFieldNames()
        --dump(self._vars)
        self._sortedVars = {missing = {}, mismatch = {}, found = {}, other = {}}
        local fieldNameUsed = {}
        for idx, elem in ipairs(self._vars) do
          fieldNameUsed[elem.fieldName] = true
          local exists = mgr.variables:variableExists(elem.fieldName)
          if exists then
            local v = mgr.variables:getFull(elem.fieldName)
            if v.type == elem.type then
              table.insert(self._sortedVars.found, elem)
            else
              elem.typeInFG = v.type
              print(v.type .. " / " .. elem.type)
              table.insert(self._sortedVars.mismatch, elem)
            end
          else
            table.insert(self._sortedVars.missing, elem)
          end
        end
        for _, varName in ipairs(mgr.variables.sortedVariableNames) do
          if not fieldNameUsed[varName] then
            local v = mgr.variables:getFull(varName)
            table.insert(self._sortedVars.other, v)
          end
        end
      end
      if im.Button("Add all "..#self._sortedVars.missing.." missing Variables", im.ImVec2(-1,0)) then
        for _, elem in ipairs(self._sortedVars.missing) do
          mgr.variables:addVariable(elem.fieldName, fg_utils.getDefaultValueForType(elem.type), elem.type)
          self._clearVars = true
        end
      end
      if im.Button("Fix all "..#self._sortedVars.mismatch.." type-mismatched Variables", im.ImVec2(-1,0)) then
        for _, elem in ipairs(self._sortedVars.mismatch) do
          mgr.variables:updateType(elem.fieldName, elem.type)
          self._clearVars = true
        end
      end
      --im.pushtree
      if im.TreeNodeV1("missingVars","Missing Variables: " .. #self._sortedVars.missing ) then
      --if im.TreeNode1("missing00") then
        im.TextWrapped("These Variables are not present in the Flowgraph but in the Mission Editor.")
        im.Columns(3)
        im.SetColumnWidth(0,50)
        for i, elem in ipairs(self._sortedVars.missing) do
          if im.Button("Add##"..elem.fieldName.."--"..i) then
            mgr.variables:addVariable(elem.fieldName, fg_utils.getDefaultValueForType(elem.type), elem.type)
            self._clearVars = true
          end
          im.NextColumn()
          im.Text(elem.elemLabel)
          im.NextColumn()
          mgr:DrawTypeIcon(elem.type, false, 1, 20/scale)
          im.SameLine()
          im.Text(elem.fieldName)
          im.tooltip(elem.fieldName .." with type: " .. dumps(elem.type))
          im.NextColumn()
        end
        im.Columns(1)
        im.TreePop()
      end
      if im.TreeNodeV1("mismatchVars","Type Mismatch Variables: " .. #self._sortedVars.mismatch) then
        im.TextWrapped("These Variables are present in the Flowgraph, but have not the same type as in the Mission Editor.")
        im.Columns(3)
        im.SetColumnWidth(0,50)
        for i, elem in ipairs(self._sortedVars.mismatch) do
          if im.Button("Fix##"..elem.fieldName.."--"..i) then
            mgr.variables:updateType(elem.fieldName, elem.type)
            self._clearVars = true
          end
          im.NextColumn()
          im.Text(elem.elemLabel)
          im.NextColumn()
          mgr:DrawTypeIcon(elem.typeInFG, false, 1, 20/scale)
          im.SameLine()
          im.Text(">")
          im.SameLine()
          mgr:DrawTypeIcon(elem.type, false, 1, 20/scale)
          im.SameLine()
          im.Text(elem.fieldName)
          im.tooltip(elem.fieldName .." with type: " .. dumps(elem.typeInFG) .. " but should be: " .. dumps(elem.type))
          im.NextColumn()
        end
        im.Columns(1)
        im.TreePop()
      end
      if im.TreeNodeV1("correctVars","Correct Variables: " .. #self._sortedVars.found) then
        im.TextWrapped("These Variables are the same in the Flowgraph and in the Mission Editor.")
        im.Columns(2)
        --im.SetColumnWidth(0,50)
        for i, elem in ipairs(self._sortedVars.found) do
          im.Text(elem.elemLabel)
          im.NextColumn()
          mgr:DrawTypeIcon(elem.type, false, 1, 20/scale)
          im.SameLine()
          im.Text(elem.fieldName)
          im.tooltip(elem.fieldName .." with type: " .. dumps(elem.type))
          im.NextColumn()
        end
        im.Columns(1)
        im.TreePop()
      end
      if im.TreeNodeV1("othrVars","Other Variables: " .. #self._sortedVars.other) then
        im.TextWrapped("These Variables are only present in the Flowgraph, but not in the mission Editor.")
        --im.SetColumnWidth(0,50)
        for i, elem in ipairs(self._sortedVars.other) do
          mgr:DrawTypeIcon(elem.type, false, 1, 20/scale)
          im.SameLine()
          im.Text(elem.name)
          im.tooltip(elem.name .." with type: " .. dumps(elem.type))
        end
        im.TreePop()
      end
      im.EndChild()
      if not mgr.allowEditing then im.EndDisabled() end
    else
      im.Text("No FG Project or no Mission selected!")
    end
    im.EndPopup()
  else
    self._vars = nil
    self._sortedVars = nil
  end
  if self._clearVars then
    self._vars = nil
    self._sortedVars = nil
    self._clearVars = nil
  end

end

function C:draw()

  im.Columns(2)
  im.SetColumnWidth(0,150)
  im.Text("Mission Type")
  im.NextColumn()
  im.PushItemWidth(200)
  -- type dropdown menu
  if im.BeginCombo('Mission Type##MissionType',self.mission.missionType or "None!") then
    for _, mType in ipairs(self.missionTypes) do
      if im.Selectable1(mType, mType == self.mission.missionType) then
        self:changeMissionType(mType)
        self.mission._dirty = true
      end
      if im.IsItemHovered() then
        im.BeginTooltip()
        im.PushTextWrapPos(200 * editor.getPreference("ui.general.scale"))
        im.TextWrapped(gameplay_missions_missions.getMissionStaticData(mType)["description"] or "No Description")
        im.PopTextWrapPos()
        im.EndTooltip()
      end
    end
    im.EndCombo()
  end


  im.SameLine()
  self.rawCheckbox[0] = self.rawEditPerMission[self.mission.id] or false
  if im.Checkbox("Raw", self.rawCheckbox) then
    self.rawEditPerMission[self.mission.id] = self.rawCheckbox[0]
  end
  im.SameLine()
  im.Text(" | ")

  im.SameLine()
  if self.missing and #self.missing > 0 then
    if im.Button("Fix "..#self.missing .. " missing values!") then
      self.missionTypeEditors[self.mission.missionType]:checkMission(self.mission, true)
      self:setMission(self.mission)
    end
    im.tooltip(dumps(self.missing))
  else
    im.Text("All Values OK!")
  end


  im.Separator()
  im.Columns(1)
  -- draw type editor if exists
  if self.missionTypeEditors[self.mission.missionType] and not self.rawEditPerMission[self.mission.id] then
    self.missionTypeEditors[self.mission.missionType]:draw()
  else
    -- otherwise draw generic json editor
    if not self._editing then
      if im.Button("Edit") then
        self._editing = true
        local serializedProgress = jsonEncodePretty(self.mission.missionTypeData or "{}")
        local arraySize = 8*(2+math.max(128, 4*serializedProgress:len()))
        local arrayChar = im.ArrayChar(arraySize)
        ffi.copy(arrayChar, serializedProgress)
        self._text = {arrayChar, arraySize}
      end
      im.Text(dumps(self.mission.missionTypeData or {}))
    else
      if im.Button("Finish Editing") then
        local progressString = ffi.string(self._text[1])
        local state, newProgress = xpcall(function() return jsonDecode(progressString) end, debug.traceback)
        if newProgress == nil or state == false then
          self._text[3] = "Cannot save. Check log for details (probably a JSON syntax error)"
        else
          self.mission.missionTypeData = newProgress
          self._editing = false
          self._text = nil
          self.mission._dirty = true
        end
      end
      im.SameLine()
      if im.Button("Cancel") then
        self._editing = false
        self._text = nil
      end
      if self._text and self._text[3] then
        pushStyle("red")
        im.Text(self._text[3])
        popStyle()
      end
      if self._editing then
        im.InputTextMultiline("##facEditor", self._text[1], im.GetLengthArrayCharPtr(self._text[1]), im.ImVec2(-1,-1))
        -- display char limit
        im.Text("(char limit: "..dumps(self._text[2]/8-2)..")")
      end
    end
  end

end

function C:drawTools()

  for _, mType in ipairs(self.missionTypes) do
    if self.missionTypeEditors[mType] and self.missionTypeEditors[mType].toolsFunctions then
      if im.BeginMenu(mType..'##toolMenu') then
        self.missionTypeEditors[mType]:toolsFunctions()
        im.EndMenu()
      end
    end
  end
end

function C:drawViewsMenu()
  for _, mType in ipairs(self.missionTypes) do
    if self.missionTypeEditors[mType] and self.missionTypeEditors[mType].viewFunctions then
      if im.BeginMenu(mType..'##viewMenu') then
        self.missionTypeEditors[mType]:viewFunctions()
        im.EndMenu()
      end
    end
  end
end


function C:drawViews()
  for _, mType in ipairs(self.missionTypes) do
    if self.missionTypeEditors[mType] and self.missionTypeEditors[mType].drawViews then
      self.missionTypeEditors[mType]:drawViews(self.missionEditor.getMissionList())
    end
  end

end

function C:getCurrentEditorHelper()
  return self.missionTypeEditors[self.mission.missionType]
end
function C:getMissionIssues(m)
  return gameplay_missions_missions.getMissionEditorForType(m.missionType):checkMission(m)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
