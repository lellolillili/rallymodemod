-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}
local inputBuffers = {}
local missionTypesDir = "/gameplay/missionTypes"
local imVec24x24 = im.ImVec2(24,24)
local imVec16x16 = im.ImVec2(16,16)
local imVec4Red = im.ImVec4(1,0,0,1)
local imVec4Green = im.ImVec4(0,1,0,1)
-- style helper
local noTranslation = "No Translation found!"
local grayColor = im.ImVec4(0.6,0.6,0.6,1)
local redColor = im.ImVec4(1,0.2,0.2,1)
local yellowColor = im.ImVec4(1,1,0.2,1)
local greenColor = im.ImVec4(0.2,1,0.2,1)


function C:init(missionEditor)
  self.missionEditor = missionEditor
  self.rawEditPerMission = {}
  self.careerSetup = {}
  self.tabName = "Career"
  self.rawCheckbox = im.BoolPtr(false)

  self.showInCareerCheckbox = im.BoolPtr(false)
  self.showInFreeroamCheckbox = im.BoolPtr(false)

  self.copiedStars = {}
  self.attributeOptions = {'money','beamXP'}
  extensions.load('career_branches')
  for _, branch in ipairs(career_branches.getSortedBranches()) do
    table.insert(self.attributeOptions, branch.attributeKey)
  end
end

function C:getMissionIssues(m)
  self:setMission(m)
  local issues = {}
  -- check for no stars set
  local starSet = false
  for key, act in pairs(m.careerSetup.starsActive) do
    starSet = starSet or act
  end

  if not starSet then
    table.insert(issues, {type = 'No Stars set at all!'})
  end

  if m.careerSetup.showInCareer then
    -- check rewards being 0
    for key, rewards in pairs(m.careerSetup.starRewards) do
      for _, re in ipairs(rewards) do
        if re.rewardAmount == 0 then
          table.insert(issues, {type = key .. " Reward for " .. re.attributeKey .. " is 0!"})
        end
      end
    end
  end

  return issues
end

function C:setMission(mission)
  self.mission = mission
  self.missionInstance = gameplay_missions_missions.getMissionById(mission.id)
  self.careerSetup = mission.careerSetup or {}
  self.showInCareerCheckbox[0] = mission.careerSetup.showInCareer or false
  self.showInFreeroamCheckbox[0] = mission.careerSetup.showInFreeroam or false
  -- notify type editor
  self.rawCheckbox[0] = false
  if not self.rawEditPerMission[mission.id] then
    self.rawEditPerMission[mission.id] = false
  end
  self.starKeysSorted = self.missionInstance.sortedStarKeys or tableKeysSorted(self.missionInstance.starLabels or {})
  inputBuffers = {}
  self.missionTypeEditor = editor_missionEditor.getCurrentEditorHelperWhenActive()
  if self.missionTypeEditor then
    self.missionTypeEditor:setMission(self.mission)
  end
  self._translatedTexts = {}
end

function C:drawDefaultStar(defaultIndex)
  if im.BeginCombo("Default Star " .. defaultIndex, self.mission.careerSetup.defaultStarKeys[defaultIndex] or "None!") then
    if im.Selectable1("None", not self.mission.careerSetup.defaultStarKeys[defaultIndex]) then
      self.mission.careerSetup.defaultStarKeys[defaultIndex] = nil
      self.mission._dirty = true
    end
    im.Separator()
    for i, key in ipairs(self.starKeysSorted) do
      if not self.mission.careerSetup.starsActive[key] then im.BeginDisabled() end
      if im.Selectable1(key, self.mission.careerSetup.defaultStarKeys[defaultIndex] == key) then
        self.mission.careerSetup.defaultStarKeys[defaultIndex] = key
        self.mission._dirty = true
      end
      im.tooltip(translateLanguage(self.missionInstance.starLabels[key],self.missionInstance.starLabels[key], true))
      if not self.mission.careerSetup.starsActive[key] then im.EndDisabled() end
    end
    im.EndCombo()
  end
  if self.mission.careerSetup.defaultStarKeys[defaultIndex] then
    im.tooltip(translateLanguage(self.missionInstance.starLabels[self.mission.careerSetup.defaultStarKeys[defaultIndex]],self.missionInstance.starLabels[self.mission.careerSetup.defaultStarKeys[defaultIndex]], true))
  end
end

function C:attributeDropdown()
  im.PushItemWidth(20)
  local ret
  if im.BeginCombo('','...') then
    for _, key in ipairs(self.attributeOptions) do
      if im.Selectable1(key,false) then
        ret = key
      end
    end
    im.EndCombo()
  end
  return ret
end

local function getBuffer(key, default)
  if not inputBuffers[key] then inputBuffers[key] = im.ArrayChar(2048, default or "") end
  return inputBuffers[key]
end

local editEnded = im.BoolPtr(false)
function C:drawAttributeInput(re, idx, key)
  editEnded[0] = false
  im.PushItemWidth(200)

  editor.uiInputText("##AI", getBuffer(idx.."--"..key, re.attributeKey), 512, nil, nil, nil, editEnded)
  im.SameLine()
  local att = self:attributeDropdown()
  if att or editEnded[0] then
    self.mission._dirty = true
    re.attributeKey = att or ffi.string(getBuffer(idx.."--"..key, re.attributeKey))
    inputBuffers[idx.."--"..key] = nil
  end
  im.PopItemWidth()
end



function C:drawRewardAmount(re, idx, key)
  local raInput = im.IntPtr(re.rewardAmount or 0)
  im.PushItemWidth(200)
  if im.InputInt("##RA",raInput) then
    self.mission._dirty = true
    re.rewardAmount = raInput[0]
  end
  im.PopItemWidth()
end

function C:drawAddReward(key)

  editEnded[0] = false
  im.PushItemWidth(200)
  editor.uiInputText("##AddReward", getBuffer("addReward--"..key, ""), 512, im.InputTextFlags_EnterReturnsTrue, nil, nil, editEnded)
  im.PopItemWidth()
  im.SameLine()
  local att = self:attributeDropdown()
  im.SameLine()
  if (editor.uiIconImageButton(editor.icons.add, im.ImVec2(22, 22)) or att or  editEnded[0]) then
    local addKey = att or ffi.string(getBuffer("addReward--"..key, ""))
    if addKey ~= "" then
      self.mission._dirty = true
      self.mission.careerSetup.starRewards[key] = self.mission.careerSetup.starRewards[key] or {}
      table.insert(self.mission.careerSetup.starRewards[key], {
        attributeKey = addKey,
        rewardAmount = 0
      })
      inputBuffers["addReward--"..key] = nil
    end
  end

  im.SameLine()
  if editor.uiIconImageButton(editor.icons.content_copy, im.ImVec2(22, 22)) then
    self.copiedRewards = deepcopy(self.mission.careerSetup.starRewards[key] or {})
  end
  im.tooltip("Copy Rewards")
  im.SameLine()
  if not self.copiedRewards then
    im.BeginDisabled()
  end
  if editor.uiIconImageButton(editor.icons.content_paste, im.ImVec2(22, 22)) then
     self.mission.careerSetup.starRewards[key] = deepcopy(self.copiedRewards)
     self.mission._dirty = true
  end
  im.tooltip("Paste Rewards: " ..dumps(self.copiedRewards))
  if not self.copiedRewards then
    im.EndDisabled()
  end
end

function C:drawStarRewards(key)
  im.PushID1(key.."starReward")
  local rewards = self.mission.careerSetup.starRewards[key] or {}
  local remIdx = -1
  for i, re in ipairs(rewards) do
    im.PushID1("Reward"..i)
    self:drawAttributeInput(re, i, key)
    im.SameLine()
    self:drawRewardAmount(re, i, key)
    im.SameLine()
    if im.SmallButton("Rem") then
      remIdx = i
    end
    im.PopID()
  end
  if remIdx then
    table.remove(rewards, remIdx)
  end
  self:drawAddReward(key)
  im.PopID()
end


function C:starSlotSelector(key)
  local currentSlot = 'Bonus Star'
  local idx = tableFindKey(self.mission.careerSetup.defaultStarKeys, key)
  if idx then
    currentSlot = "Default Star " .. idx
  end
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if im.BeginCombo("##sss"..key, currentSlot) then
    if im.Selectable1("Bonus Star", currentSlot == "Bonus Star") then
      if idx then
        self.mission.careerSetup.defaultStarKeys[idx] = nil
      end
      self.mission._dirty = true
    end
    for i = 1, 3 do
      if im.Selectable1("Default Star " .. i, currentSlot == "Default Star " .. i) then
        if idx then
          self.mission.careerSetup.defaultStarKeys[idx] = nil
        end
        self.mission.careerSetup.defaultStarKeys[i] = key
        self.mission._dirty = true
      end
    end
    im.EndCombo()
  end
  im.PopItemWidth()
end

function C:drawOutroText(key)
  im.Text("Outro Text")
  im.NextColumn()
  im.PushID1(key.."starReward")

  local hasDefault = self.missionInstance.defaultStarOutroTexts[key]
  local usingDefault = hasDefault and (self.mission.careerSetup.starOutroTexts[key] or "") == ""
  if not hasDefault then
    editor.uiIconImage(editor.icons.font_download, im.ImVec2(22, 22), grayColor)
    im.tooltip("No Default Text found.")
  else
    editor.uiIconImage(editor.icons.font_download, im.ImVec2(22, 22), usingDefault and greenColor or yellowColor)
    if usingDefault then
      im.tooltip("Using Default Translation: " ..self.missionInstance.defaultStarOutroTexts[key].." : " ..translateLanguage(self.missionInstance.defaultStarOutroTexts[key], self.missionInstance.defaultStarOutroTexts[key], true))
    else
      im.tooltip("Available Default Translation: " ..self.missionInstance.defaultStarOutroTexts[key].." : " ..translateLanguage(self.missionInstance.defaultStarOutroTexts[key], self.missionInstance.defaultStarOutroTexts[key], true))
    end
  end
  local buf = getBuffer(key.."--OutroText", self.mission.careerSetup.starOutroTexts[key] or "")
  editEnded[0] = false

  im.SameLine()
  im.PushItemWidth(im.GetContentRegionAvailWidth() -35)
  editor.uiInputText("##outroText", buf, 2048, nil, nil, nil, editEnded)
  if editEnded[0] then
    self.mission._dirty = true
    self.mission.careerSetup.starOutroTexts[key] = ffi.string(buf)
    self._translatedTexts[key] = nil
  end
  im.PopItemWidth()

  im.SameLine()
  if not self._translatedTexts[key] then
    self._translatedTexts[key] = translateLanguage(self.mission.careerSetup.starOutroTexts[key] or "", noTranslation, true)
  end
  editor.uiIconImage(editor.icons.translate, imVec24x24 , (self._translatedTexts[key] or noTranslation) == noTranslation and (usingDefault and yellowColor or imVec4Red) or imVec4Green)
  if im.IsItemHovered() then
    im.tooltip(self._translatedTexts[key])
  end
  im.PopID()
end


function C:drawCareerSetup()
  if im.Checkbox("Show In Career", self.showInCareerCheckbox) then
    self.mission.careerSetup.showInCareer = self.showInCareerCheckbox[0]
    self.mission._dirty = true
  end

  if im.Checkbox("Show In Freeroam", self.showInFreeroamCheckbox) then
    self.mission.careerSetup.showInFreeroam = self.showInFreeroamCheckbox[0]
    self.mission._dirty = true
  end
  im.Separator()
  im.HeaderText("Stars")




  for i, key in ipairs(self.starKeysSorted) do
    im.PushID1(key.."child")
    local toggle = false
    if im.Checkbox(key.."##StarKey"..i, im.BoolPtr(self.mission.careerSetup.starsActive[key] or false)) then
      toggle = true
    end
    im.SameLine()

    im.TextColored(grayColor, translateLanguage(self.missionInstance.starLabels[key],self.missionInstance.starLabels[key], true))
    toggle = im.IsItemClicked() or toggle

    if toggle then
      self.mission.careerSetup.starsActive[key] = not(self.mission.careerSetup.starsActive[key] or false)
      self.mission._dirty = true
      if self.mission.careerSetup.starsActive[key] then
        for i = 1, 3 do
          if self.mission.careerSetup.defaultStarKeys[i] == nil then
            self.mission.careerSetup.defaultStarKeys[i] = key
            break
          end
        end
      else
        for i = 1, 3 do
          if self.mission.careerSetup.defaultStarKeys[i] == key then
            self.mission.careerSetup.defaultStarKeys[i] = nil

          end
        end
      end
    end
    if self.mission.careerSetup.starsActive[key] then
      im.Columns(2)
      im.SetColumnWidth(0,150)
      im.Text("Slot")
      im.NextColumn()
      self:starSlotSelector(key)
      im.Columns(1)

      if self.missionTypeEditor then
        self.missionTypeEditor:draw({onlyStar = key})
      end
      im.Columns(2)
      im.SetColumnWidth(0,150)
      im.Separator()
      im.Text("Rewards")
      im.NextColumn()
      self:drawStarRewards(key)
      im.NextColumn()
      im.Separator()
      self:drawOutroText(key)



      im.Columns(1)
    end
    im.PopID()
    if i ~= #self.starKeysSorted  then
      im.Separator()
    end
  end
  im.Columns(2)
  im.SetColumnWidth(0,150)
  im.Text("No Star Unlocked") im.NextColumn()im.NextColumn()
  self:drawOutroText("noStarUnlocked")
  im.Columns()
  im.HeaderText("Summary")
  im.Columns(2)
  im.SetColumnWidth(0,150)
  im.Text("Default Stars")
  im.NextColumn()
  im.Text(
    (self.mission.careerSetup.defaultStarKeys[1] or "None!") .. ", " ..
    (self.mission.careerSetup.defaultStarKeys[2] or "None!") .. ", " ..
    (self.mission.careerSetup.defaultStarKeys[3] or "None!")
    )
  im.NextColumn()

  im.Text("Bonus Stars")
  local bonusStars = {}
  for idx, key in ipairs(self.starKeysSorted) do
    if self.mission.careerSetup.starsActive[key] and not tableFindKey(self.mission.careerSetup.defaultStarKeys, key) then
      table.insert(bonusStars,key)
    end
  end
  im.NextColumn()
  im.Text(next(bonusStars) and table.concat(bonusStars,", ") or "None!")
  im.NextColumn()
  local sums = {all = {}, defaultOnly = {}, bonusOnly = {}}
  for key, rewards in pairs(self.mission.careerSetup.starRewards) do
    for _, re in ipairs(rewards) do
      sums.all[re.attributeKey] = (sums.all[re.attributeKey] or 0) + re.rewardAmount
      if tableFindKey(self.mission.careerSetup.defaultStarKeys, key) then
        sums.defaultOnly[re.attributeKey] = (sums.defaultOnly[re.attributeKey] or 0) + re.rewardAmount
      end
      if tableFindKey(bonusStars, key) then
        sums.bonusOnly[re.attributeKey] = (sums.bonusOnly[re.attributeKey] or 0) + re.rewardAmount
      end
    end
  end
  im.Text("Total Rewards")
  im.NextColumn()
  for _, key in ipairs(tableKeysSorted(sums.all)) do
    im.Text(key .." -> ".. sums.all[key])
  end
  im.Dummy(im.ImVec2(2,2))
  im.NextColumn()
  im.Text("Default Star Rewards")
  im.NextColumn()
  for _, key in ipairs(tableKeysSorted(sums.defaultOnly)) do
    im.Text(key .." -> ".. sums.defaultOnly[key])
  end
  im.Dummy(im.ImVec2(2,2))
  im.NextColumn()
  im.Text("Bonus Star Rewards")
  im.NextColumn()
  for _, key in ipairs(tableKeysSorted(sums.bonusOnly)) do
    im.Text(key .." -> ".. sums.bonusOnly[key])
  end
  im.Dummy(im.ImVec2(2,2))
  im.NextColumn()

  im.Columns(1)
  im.Separator()

  if self.mission.allowCustomStars then

  end

end


function C:draw()
  im.HeaderText("Career Setup")
  im.SameLine()
  self.rawCheckbox[0] = self.rawEditPerMission[self.mission.id] or false
  if im.Checkbox("Raw", self.rawCheckbox) then
    self.rawEditPerMission[self.mission.id] = self.rawCheckbox[0]
  end

  im.SameLine()
  if editor.uiIconImageButton(editor.icons.content_copy, im.ImVec2(22, 22)) then
    self.copiedStars[self.mission.missionType] = deepcopy(self.mission.careerSetup or {})
  end
  im.tooltip("Copy Career Setup and Rewards")
  im.SameLine()
  if not self.copiedStars[self.mission.missionType] then
    im.BeginDisabled()
  end
  if editor.uiIconImageButton(editor.icons.content_paste, im.ImVec2(22, 22)) then
    self.mission.careerSetup = deepcopy(self.copiedStars[self.mission.missionType])
    self.mission._dirty = true
  end
  im.tooltip("Paste Career Setup and Rewards: " ..dumps(self.copiedStars[self.mission.missionType]))
  if not self.copiedStars[self.mission.missionType] then
    im.EndDisabled()
  end

  im.Separator()

  -- draw type editor if exists
  if not self.rawEditPerMission[self.mission.id] then
    self:drawCareerSetup()
  else
    -- otherwise draw generic json editor
    if not self._editing then
      if im.Button("Edit") then
        self._editing = true
        local serializedSaveData = jsonEncodePretty(self.mission.careerSetup or "{}")
        local arraySize = 8*(2+math.max(128, 4*serializedSaveData:len()))
        local arrayChar = im.ArrayChar(arraySize)
        ffi.copy(arrayChar, serializedSaveData)
        self._text = {arrayChar, arraySize}
      end
      im.Text(dumps(self.mission.careerSetup or {}))
    else
      if im.Button("Finish Editing") then
        local progressString = ffi.string(self._text[1])
        local state, newSaveData = xpcall(function() return jsonDecode(progressString) end, debug.traceback)
        if newSaveData == nil or state == false then
          self._text[3] = "Cannot save. Check log for details (probably a JSON syntax error)"
        else
          self.mission.careerSetup = newSaveData
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
