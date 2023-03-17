-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local transformHelper = require('/lua/ge/extensions/editor/util/transformUtil')("Start Trigger Location","Location")
--transformHelper.allowRotate = true
transformHelper:setOneDimensionalScale(true)
local C = {}
-- this will come from activity manager once refactored

local function automaticTrigger(self)
  im.Text("Automatic Trigger Set by Mission.")
end

local function worldTrigger(self)
  im.Text("Always available.")
end

local function levelTrigger(self)
  if not self.fields.levelName then self.fields.levelName = im.ArrayChar(1024, self.mission.startTrigger.level) end
  local editEnded = im.BoolPtr(false)
  if editor.uiInputText("##Level", self.fields.levelName, 1024, nil, nil, nil, editEnded) then
  end
  if editEnded[0] then
    self.mission.startTrigger.level = ffi.string(self.fields.levelName)
    self.mission._dirty = true
  end
  if im.BeginCombo("##levelCombo", self.fields.levelName) then
    for _, lvl in ipairs(self.sortedLevels) do
      if im.Selectable1(lvl.value, lvl.value == self.mission.startTrigger.level) then
        self.fields.levelName = nil
        self.mission.startTrigger.level = lvl.value
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
end

local function coordinatesTrigger(self)
  if not self.fields.levelName then self.fields.levelName = im.ArrayChar(1024, self.mission.startTrigger.level) end
  local editEnded = im.BoolPtr(false)
  editor.uiInputText("##Level", self.fields.levelName, 1024, nil, nil, nil, editEnded)
  if editEnded[0] then
    self.mission.startTrigger.level = ffi.string(self.fields.levelName)
    self.mission._dirty = true
  end
  im.SameLine()
  im.PushItemWidth(20)
  if im.BeginCombo("##levelCombo", "...") then
    for _, lvl in ipairs(self.sortedLevels) do
      if im.Selectable1(lvl.value, lvl.value == self.mission.startTrigger.level) then
        self.fields.levelName = nil
        self.mission.startTrigger.level = lvl.value
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()

  if getCurrentLevelIdentifier() == self.mission.startTrigger.level then
    local radius = self.mission.startTrigger.radius
    debugDrawer:drawSphere(transformHelper.pos, radius, ColorF(1,0,0,0.5))
    local normal = transformHelper.rot * vec3(0,1,0)
    debugDrawer:drawSquarePrism(
        transformHelper.pos,
        (transformHelper.pos + radius * normal),
        Point2F(1,radius/2),
        Point2F(0,0),
        ColorF(1,0,0,0.66))
      debugDrawer:drawSquarePrism(
        transformHelper.pos,
        (transformHelper.pos + 0.25 * normal),
        Point2F(5,radius*2),
        Point2F(0,0),
        ColorF(1,0,0,0.25))
    transformHelper.showGizmo = true
  else
    transformHelper.showGizmo = false
  end
  if transformHelper:update(extensions.editor_missionEditor.getMissionTypeWindow():getCurrentEditorHelper().mouseInfo) then
    self.mission.startTrigger.pos = transformHelper.pos:toTable()
    self.mission.startTrigger.rot = transformHelper.rot:toTable()
    self.mission.startTrigger.radius = transformHelper.scl
    self.mission._dirty = true
  end
end


local startTriggerTypes = {
  automatic = automaticTrigger,
  world = worldTrigger,
  level = levelTrigger,
  coordinates = coordinatesTrigger
}
local oldValues = {}
local startTriggersSorted = {}
for k, _ in pairs(startTriggerTypes) do table.insert(startTriggersSorted, k) end
table.sort(startTriggersSorted)

local newStartTrigger = {
  automatic = {},
  world = {},
  level = {level = 'gridmap'},
  coordinates = {level = 'gridmap', pos = {0,0,0}, radius = 3, rot={0,0,0,1}},
}

function C:init(missionEditor)
  self.missionEditor = missionEditor
  self.name = "StartTrigger"
  local levels = getAllLevelIdentifiers()
  table.sort(levels)
  self.sortedLevels = {}
  for _, lvl in ipairs(levels) do
    table.insert(self.sortedLevels, {value = lvl, name = "displayed name"})
  end
end

function C:setMission(mission)
  self.mission = mission
  self.fields = {}
  oldValues = {}
  transformHelper:stop()
  if self.mission.startTrigger.type == 'coordinates' then
    transformHelper:set(vec3(self.mission.startTrigger.pos), quat(self.mission.startTrigger.rot or {0,0,0,1}), self.mission.startTrigger.radius)
  end
end


function C:draw()
  im.PushID1(self.name)
  im.Columns(2)
  im.SetColumnWidth(0,150)
  im.Text(self.name)
  im.NextColumn()
  if self.mission._clearStartTriggerFields then
    self:setMission(self.mission)
    self.mission._clearStartTriggerFields = false
  end
  --[[
  im.PushItemWidth(200)
  if im.BeginCombo('##startTrigger', self.mission.startTrigger.type) then
    for _, stType in ipairs(startTriggersSorted) do
      if im.Selectable1(stType, stType == self.mission.startTrigger.type) then
        local hasOld = oldValues[stType] ~= nil
        oldValues[self.mission.startTrigger.type] = deepcopy(self.mission.startTrigger)
        if hasOld then
          self.mission.startTrigger = deepcopy(oldValues[stType])
        else
          self.mission.startTrigger = deepcopy(newStartTrigger[stType])
          if stType == 'coordinates' then
            transformHelper:set(vec3(self.mission.startTrigger.pos), nil, self.mission.startTrigger.radius)
          end
        end
        self.mission.startTrigger.type = stType
        self.fields = {}
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()
  ]]
  if startTriggerTypes[self.mission.startTrigger.type] then
    startTriggerTypes[self.mission.startTrigger.type](self)
  end

  im.Columns(1)
  im.PopID()
end

function C:getStartTriggerTransform()
  if getCurrentLevelIdentifier() == self.mission.startTrigger.level then
    return transformHelper
  end
  return nil
end


return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
