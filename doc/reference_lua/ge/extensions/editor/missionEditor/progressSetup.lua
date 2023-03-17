-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}
local missionTypesDir = "/gameplay/missionTypes"
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
  self.progressSetup = {}
  self.rawCheckbox = im.BoolPtr(false)
end



function C:setMission(mission)
  self.mission = mission
  self.progressSetup = gameplay_missions_missions.getMissionProgressSetupData(mission.missionType)
  -- notify type editor
  self.rawCheckbox[0] = false
  if not self.rawEditPerMission[mission.id] then
    self.rawEditPerMission[mission.id] = false
  end
end



function C:draw()
  im.HeaderText("Progress - "..translateLanguage(self.mission.name, self.mission.name, true))
  im.SameLine()
  self.rawCheckbox[0] = self.rawEditPerMission[self.mission.id] or false
  if im.Checkbox("Raw", self.rawCheckbox) then
    self.rawEditPerMission[self.mission.id] = self.rawCheckbox[0]
  end
  im.Separator()

  -- draw type editor if exists
  if not self.rawEditPerMission[self.mission.id] then
    self:drawProgress()
  else
    -- otherwise draw generic json editor
    if not self._editing then
      if im.Button("Edit") then
        self._editing = true
        local serializedSaveData = jsonEncodePretty(self.missionInstance.saveData or "{}")
        local arraySize = 8*(2+math.max(128, 4*serializedSaveData:len()))
        local arrayChar = im.ArrayChar(arraySize)
        ffi.copy(arrayChar, serializedSaveData)
        self._text = {arrayChar, arraySize}
      end
      im.Text(dumps(self.missionInstance.saveData or {}))
    else
      if im.Button("Finish Editing") then
        local progressString = ffi.string(self._text[1])
        local state, newSaveData = xpcall(function() return jsonDecode(progressString) end, debug.traceback)
        if newSaveData == nil or state == false then
          self._text[3] = "Cannot save. Check log for details (probably a JSON syntax error)"
        else
          self.mission.saveData = newSaveData
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

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
