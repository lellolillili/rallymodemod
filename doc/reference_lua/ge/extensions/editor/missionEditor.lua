-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local ffi = require("ffi")
local im = ui_imgui
local toolWindowName = "mission_editor"
M.dependencies = {'gameplay_missions_missions'}

-- form backend
local generalInfo
local issuesWindow
local startCondition
local devEditor
local visibleCondition
local startTrigger
local prefabs
local missionTypeData
local additionalAttributes
local careerSetup
local progressSingle
local progressMulti
local playbookUtils
local unsavedColor = im.ImVec4(1, 0.6, 0.5, 1.0)
local windows = {}
local tabs = {}
local showWindows = {
  generalWindows = true,
  additionalWindows = false,
  missionTypeWindows = true
}
local generalWindows, additionalWindows, missionTypeWindows = {}, {} ,{}
local missionTypeWindow = {}
local oldMissionTypeData = {}

local filter = {
  onlyCurrentLevel = false,
  hideProcedural = true,
  showCareerMissions = true,
  showFreeroamMissions = true,
}
local filterNamesSorted = {
  {name = "Current Level Only", key = "onlyCurrentLevel"},
  {name = "Hide Procedural Missions", key = "hideProcedural"},
  {name = "Hide non-Career Missions", key = "showCareerMissions"},
  {name = "Hide non-Freeroam Missions", key = "showFreeroamMissions"}
}

local grouping = {
  mode = "none",
  missions = {}
}
local groupingNamesSorted = {
  {name = "None", key = "none"},
  {name = "Level", key = "level"},
  {name = "Mission Type", key = "type"},
}


local sort

local hoveredMission
local clickedMission
local newMissionData = {
  name = im.ArrayChar(1024, "Name"),
  id = im.ArrayChar(1024, "Id"),
  level = "gridmap",
  type = "flowgraph",
  copy = false,
  autoId = true
}
local missionList = nil
local filterInput = im.ArrayChar(1024,'')

local missionSearch = require('/lua/ge/extensions/editor/util/searchUtil')()
local missionSearchTxt = im.ArrayChar(256, "")
local missionSearchDisplayResult = false
local missionSearchResults = {}



local lastShownMission = nil -- always force an update on first call
local function displayHeader(clickedMission, hoveredMission, shownMission)
  if shownMission then
    if shownMission._dirty then
      if editor.uiIconImageButton(editor.icons.save, im.ImVec2(40, 40), unsavedColor) then
        gameplay_missions_missions.saveMission(shownMission,shownMission.missionFolder)
        shownMission._dirty = false
      end
      ui_flowgraph_editor.tooltip("Save unsaved changes for this mission")
    else
      if editor.uiIconImageButton(editor.icons.save, im.ImVec2(40, 40)) then end
      ui_flowgraph_editor.tooltip("No unsaved changes for this mission")
    end
    im.SameLine()
    if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(40, 40)) then
      -- check if map loaded and player has vehicle
      -- TODO: load map and player vehicle if not loaded
      local playerVehicle = be:getPlayerVehicle(0)
      if (getCurrentLevelIdentifier() == shownMission.startTrigger.level) and playerVehicle and shownMission.startTrigger then
        -- teleport vehicle
        spawn.safeTeleport(playerVehicle,vec3(shownMission.startTrigger.pos), quat(shownMission.startTrigger.rot))

        -- deactivate editor
        editor.setEditorActive(false)

        -- exitBigMap
        freeroam_bigMapMode.exitBigMap(true,true)

        -- TODO: open mission popup
        -- TODO: switch to this mission in cluster
      end
    end

    ui_flowgraph_editor.tooltip("Start Mission\n(Needs loaded map and vehicle)")
    im.SameLine()
  end
  if shownMission then
    im.Text("Mission ID:\n"..shownMission.id)
  else
    im.BeginDisabled()
    im.Text("Mission ID:\n(no mission selected)")
    im.EndDisabled()
  end
end
local initializeColumnWidth = true
local function loadWindows()
  -- general info
  generalInfo = require('/lua/ge/extensions/editor/missionEditor/general')(M)
  table.insert(windows, generalInfo)
  table.insert(generalWindows, generalInfo)
  --devEditor = require('/lua/ge/extensions/editor/missionEditor/dev')(M)

  issuesWindow = require('/lua/ge/extensions/editor/missionEditor/issues')(M)
  table.insert(windows, issuesWindow)

  --prefabs = require('/lua/ge/extensions/editor/missionEditor/prefabs')(M)
  startTrigger = require('/lua/ge/extensions/editor/missionEditor/startTrigger')(M)
  table.insert(windows, startTrigger)
  table.insert(generalWindows, startTrigger)


  local preview = require('/lua/ge/extensions/editor/missionEditor/previewChecker')(M)
  table.insert(windows, preview)
  table.insert(additionalWindows, preview)

  -- additional Info
  startCondition = require('/lua/ge/extensions/editor/missionEditor/conditions')(M, 'startCondition','Start Condition')
  table.insert(windows, startCondition)
  table.insert(additionalWindows, startCondition)

  visibleCondition = require('/lua/ge/extensions/editor/missionEditor/conditions')(M, 'visibleCondition','Visibility Conditions')
  table.insert(windows, visibleCondition)
  table.insert(additionalWindows, visibleCondition)

  additionalAttributes = require('/lua/ge/extensions/editor/missionEditor/additionalAttributes')(M)
  table.insert(windows, additionalAttributes)
  table.insert(additionalWindows, additionalAttributes)

  -- missionType Info
  missionTypeWindow = require('/lua/ge/extensions/editor/missionEditor/genericTypeData')(M)
  table.insert(windows, missionTypeWindow)
  table.insert(missionTypeWindows, missionTypeWindow)

  careerSetup = require('/lua/ge/extensions/editor/missionEditor/careerSetup')(M)
  table.insert(windows, careerSetup)
  table.insert(tabs, careerSetup)

  progressSingle = require('/lua/ge/extensions/editor/missionEditor/progressSingle')(M)
  table.insert(windows, progressSingle)
  table.insert(tabs, progressSingle)

  progressMulti = require('/lua/ge/extensions/editor/missionEditor/progressMulti')(M)
  table.insert(windows, progressMulti)
  table.insert(tabs, progressMulti)

  playbookUtils = require('/lua/ge/extensions/editor/missionEditor/playbookUtils')(M)
  table.insert(windows, playbookUtils)
  table.insert(tabs, playbookUtils)
  --table.insert(windows, devEditor)
  --table.insert(windows, visibleCondition)
  --table.insert(windows, prefabs)
end
local infoSize = im.ImVec2(18, 18)
local infoColors = {
  check = im.ImVec4(0, 1, 0, 1.0),
  warning = im.ImVec4(1, 1, 0, 1.0),
  error = im.ImVec4(1, 0, 0, 1.0)
}



local function loadGroupFilter()
  local groupFilter = editor.getPreference("missionEditor.general.groupFilter") or {}
  missionList = nil
  if groupFilter.filter then
    for _, f in ipairs(filterNamesSorted) do
      if groupFilter.filter[f.key] ~= nil then
        filter[f.key] = groupFilter.filter[f.key]
      end
    end
  end
  if groupFilter.grouping ~= nil then
    grouping.mode = groupFilter.grouping
    editor.savePreferences()
  end
end

local function saveGroupFilter()
  local groupFilter = { filter = {}}
  for _, f in ipairs(filterNamesSorted) do
    groupFilter.filter[f.key] = filter[f.key]
  end
  groupFilter.grouping = grouping.mode
  editor.setPreference("missionEditor.general.groupFilter", groupFilter)
end


local function displayMissionSelector(missionData)
  if missionData._issueList then
    local icon = missionData._issueList.type
    if missionData._issueList.count < 10 and missionData._issueList.count > 0 then
      icon = "filter_"..tostring(missionData._issueList.count)
    end
    editor.uiIconImageButton(editor.icons[icon], infoSize, missionData._issueList.color)
    if im.IsItemHovered() then
      im.BeginTooltip()
      if missionData._issueList.count == 0 then
        im.Text("No Issues!")
      end

      for _, issue in ipairs(missionData._issueList) do
        im.BulletText(issue.type)
      end
      im.EndTooltip()
    end

  else
    im.Dummy(infoSize)
  end
  im.SameLine()


  local name = missionData.id

  if editor.getPreference('missionEditor.general.shortIds') then
    local p, fn, _ = path.split(name)
    name = fn
    --[[
    if string.find(p or '', '/') then
      name = name .. ' (' .. p..')'
    end
    ]]
  end


  if missionData._dirty then
    name = "*** " .. name .. " ***"
    im.PushStyleColor2(im.Col_Text, unsavedColor)
  end
  if missionSearchDisplayResult then
    im.HighlightSelectable(name, ffi.string(missionSearchTxt), clickedMission == missionData)
  else
    im.Selectable1(name, clickedMission == missionData)
  end
  if im.IsItemClicked() then
    if clickedMission == missionData then
      clickedMission = nil
    else
      clickedMission = missionData
    end
  end
  if missionData._dirty then im.PopStyleColor() end
  if im.IsItemHovered() then
    hoveredMission = missionData
  end
  im.tooltip(missionData.id)
end


local filterFunctions = {
  onlyCurrentLevel = function(mission, f) return not f or mission.startTrigger.level == getCurrentLevelIdentifier() end,
  hideProcedural = function(mission, f) return not f or not mission.procedural end,
  showCareerMissions = function(mission, f) return not f or f and mission.careerSetup.showInCareer end,
  showFreeroamMissions = function(mission, f) return not f or f and mission.careerSetup.showInFreeroam end,
}
local function applyFilter()
  missionList = {}

  for _, mission in ipairs(gameplay_missions_missions.getFilesData() or {}) do
    local passed = true
    for key, fun in pairs(filterFunctions) do
      passed = passed and ( filterFunctions[key](mission, filter[key]))
    end
    if passed then
      table.insert(missionList, mission)
    end
  end

end

local function idSort(a,b) return a.id < b.id end
local function getMissionType(mission) return mission.missionType end
local function getMissionLevelOrNone(mission) return mission.startTrigger.level or "No Level" end
local function groupMissionsByFunction(missions, propertyFunction)
  local result = {missions = {}, sortedKeys = {}}
  for _, mission in ipairs(missions) do
    local key = propertyFunction(mission)
    if not result.missions[key] then
      result.missions[key] = {}
      table.insert(result.sortedKeys, key)
    end
    table.insert(result.missions[key], mission)
  end
  table.sort(result.sortedKeys)
  for key, list in pairs(result.missions) do
    table.sort(list, idSort)
  end
return result
end


local function applyGrouping()
  if grouping.mode == "none" then
    grouping.missions = missionList
    table.sort(grouping.missions, idSort)
  elseif grouping.mode == "type" then
    grouping = groupMissionsByFunction(missionList, getMissionType)
    grouping.mode = "type"
  elseif grouping.mode == "level" then
    grouping = groupMissionsByFunction(missionList, getMissionLevelOrNone)
    grouping.mode = "level"
  end
end

local function applySearch()
  local s = ffi.string(missionSearchTxt)
  missionSearchDisplayResult = s:len() > 0
  if missionSearchDisplayResult then
    missionSearch:startSearch(s)
    for k,missionData in ipairs(missionList) do
      missionSearch:queryElement({
        name = missionData.id,
        score = 1,
        data = missionData
      })
    end
    missionSearchResults = missionSearch:finishSearch()
  end
end

local function newMissionPopup()
  if im.BeginPopup("NewMission") then
    --print("ok?")
    local scale = editor.getPreference("ui.general.scale")
    im.BeginChild1("createNewMissionPopupChild", im.ImVec2(350*scale,180*scale), 0)
    im.HeaderText("Create New Mission")
    im.PushStyleVar2(im.StyleVar_FramePadding, im.ImVec2(0,0))
    im.Columns(2)
    im.PopStyleVar()
    im.SetColumnWidth(0, im.CalcTextSize("MissionType").x +5)
    im.Text("Name: ")
    im.NextColumn()
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if editor.uiInputText("##NameNewMission", newMissionData.name, 1024) and newMissionData.autoId then
      newMissionData.recalcId = true
    end
    im.PopItemWidth()
    im.NextColumn()
    im.Text("Id: ")
    im.NextColumn()
    im.PushItemWidth(im.GetContentRegionAvailWidth()-26*scale)
    if editor.uiInputText("##idNewMission", newMissionData.id, 1024) then
      newMissionData.autoId = false
    end
    im.PopItemWidth()
    im.SameLine()
    local sameTypeLevelCount = 1
    local level = getCurrentLevelIdentifier() or "gridmap"

    local id = ffi.string(newMissionData.id)
    -- check if the id is already taken
    local taken = false
    for _, mission in ipairs(missionList or {}) do
      if mission.id == id then
        taken = true
      end

      if mission.missionType == newMissionData.type and mission.startTrigger.type == 'coordinates' and mission.startTrigger.level == level then
        sameTypeLevelCount = sameTypeLevelCount + 1
      end
    end

    if not taken then
      editor.uiIconImage(editor.icons.check, im.ImVec2(24,24), im.ImVec4(0,1,0,1))
      im.tooltip("This ID is available.")
    else
      editor.uiIconImage(editor.icons.error_outline, im.ImVec2(24,24), im.ImVec4(1,0,0,1))
      im.tooltip("This ID is already taken!")
    end
    im.NextColumn()
    im.Text("Auto Id")
    im.NextColumn()
    if im.Checkbox("##Automatic Id", im.BoolPtr(newMissionData.autoId)) then
      newMissionData.autoId = not newMissionData.autoId
    end

    if newMissionData.recalcId then
      local name = ffi.string(newMissionData.name)
      name = name:match("(.-) ") or name
      name = name:gsub('%W','') or name

      local id = string.format("%s/%s/%03d-%s", level, newMissionData.type, sameTypeLevelCount, name)
      newMissionData.id = im.ArrayChar(1024, id)
    end
    newMissionData.recalcId = false

    im.NextColumn()
    im.Text("Missiontype")
    im.NextColumn()
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if im.BeginCombo('##MissionType',newMissionData.type) then
      for _, mType in ipairs(missionTypeWindow.missionTypes) do
        if im.Selectable1(mType, mType == newMissionData.type) then
          newMissionData.type = mType
          newMissionData.recalcId = true
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
    im.PopItemWidth()

    local cameraPosition = getCameraPosition()
    local position = quat(getCameraQuat()) * vec3(0, 15, 0)
    local beforeCam = position + cameraPosition

    --debugDrawer:drawSphere(beforeCam, 3, ColorF(1,0,0,0.5))
    im.Columns(1)

    if taken then
      im.BeginDisabled()
    end
    if im.Button("Create Mission", im.ImVec2(-1, -1)) then
      -- create mission and add into mission list
      local data = {
        name = ffi.string(newMissionData.name),
        id = ffi.string(newMissionData.id),
        missionType = newMissionData.type,
        startTrigger = {
          type = 'coordinates',
          level = getCurrentLevelIdentifier() or "gridmap",
          pos = (beforeCam):toTable(),
          radius = 3,
          rot = quat(0,0,0,1)
          },
        careerSetup = {
          showInFreeroam = true,
          }

        }
      local newMis

      if newMissionData.copy then
        newMis = gameplay_missions_missions.createMission(data.id, deepcopy(lastShownMission))
      else
        newMis = gameplay_missions_missions.createMission(data.id, data)
        missionTypeWindow:fillGeneric(newMis)
      end

      gameplay_missions_missions.saveMission(newMis)
      M.reloadMissionSystem()

      M.setMissionById(data.id)
      M.forceOpenTree = true
      im.CloseCurrentPopup()
    end
    if taken then
      im.EndDisabled()
    end
    im.EndChild()
    im.EndPopup()
  end
end
local openNewMissionPopup = false

local translationData = nil
local function makeTranslation()
  local translation = {}
  local prefix = ffi.string(translationData.translationKeyPtr)
  local instance = gameplay_missions_missions.getMissionById(clickedMission.id)
  table.insert(translation,{ key = prefix..".title",       value = clickedMission.name,       source = 'name' })
  table.insert(translation,{ key = prefix..".description", value = clickedMission.description, source = 'description' })
  local editHelper = missionTypeWindow:getCurrentEditorHelper()
  if editHelper then
    for _, elem in ipairs(editHelper.elements) do
      if elem.displayOptions and elem.displayOptions.isTranslation then
        if elem.type == 'string' then
          table.insert(translation,{key = prefix.."."..elem.fieldName, value = ffi.string(elem.ac), source = elem})
        end
      end
    end
  end
  local keys = deepcopy(instance.sortedStarKeys)
  table.insert(keys,"noStarUnlocked")
  for _, key in ipairs(keys) do
    local t = clickedMission.careerSetup.starOutroTexts[key]
    if t and t ~= "" then
      table.insert(translation,{ key = prefix..".starOutroTexts."..key,       value = t,       source = key, starText = true})
    end
  end
  for _, elem in ipairs(translation) do
    if translateLanguage(elem.value, "NoTranslation!") ~= "NoTranslation!" then
      elem.value = translateLanguage(elem.value, elem.value)
    end
  end

  local translationStrings = {}
  for _, elem in ipairs(translation) do
    table.insert(translationStrings,string.format('    "%s": "%s"', elem.key, elem.value))
  end

  translationData.copyPastaPtr = im.ArrayChar(100000, table.concat( translationStrings, ",\n")..",\n")
  translationData.translation = translation
end

local function exportMissionOverview()
  local csvdata = require('csvlib').newCSV("Mission ID", "Mission Name", "Mission Type", "Branch", "Tier", "Star Id", "Star Label", "Star Type", "money", "beamXP","motorsport","labourer","adventurer","specialized")

  for _, mission in ipairs(missionList) do
    local instance = gameplay_missions_missions.getMissionById(mission.id)
    local translatedName = translateLanguage(mission.name, mission.name, true)
    local missionType = mission.missionType
    local firstBranch = nil
    for b, _ in pairs(instance.unlocks.branchTags) do
      firstBranch = b
    end

    for _, key in ipairs(instance.careerSetup._activeStarCache.sortedStars) do
      local translatedStarLabel = translateLanguage(instance.starLabels[key], instance.starLabels[key], true)
      local rewards = {}
      for _, r in ipairs(instance.careerSetup._activeStarCache.sortedStarRewardsByKey[key]) do
        rewards[r.attributeKey] = r.rewardAmount
      end
      local starType = instance.careerSetup._activeStarCache.defaultStarKeysByKey[key] and "default" or "bonus"
      csvdata:add(mission.id, translatedName, missionType, firstBranch, instance.unlocks.maxBranchlevel, key, translatedStarLabel, starType, rewards.money or 0,rewards.beamXP or 0,rewards.motorsport or 0,rewards.labourer or 0,rewards.adventurer or 0,rewards.specialized or 0 )
    end
  end
  csvdata:write("missionOverview.csv")
end

local function escapeCSV(s)
  if string.find(s, '[,"]') then
    s = '"' .. string.gsub(s, '"', '""') .. '"'
  end
  return s
end
local function loadMissionCSV()
  local f = io.open('missionImport.csv')
  local header = f:read()
  local data = {}
  local keys = {}
  for x in header:gmatch("([^',']+)") do table.insert(keys, x) end
  local row = f:read()
  while row do
    local values, idx = {}, 1
    for x in row:gmatch("([^,]+)") do
      --print(idx, x)
      local val = tonumber(x) or x
      values[keys[idx]] = val
      idx = idx + 1
    end
    table.insert(data, values)
    row = f:read()
  end
  f:close()
  return data
end

local function importMissionOverview()
  local data = loadMissionCSV()
  local fDataById = {}
  for _, m in ipairs(gameplay_missions_missions.getFilesData()) do
    fDataById[m.id] = m
  end
  for _, row in ipairs(data) do
    local mission = fDataById[row['Mission ID']]
    if mission then
      local starKey = row['Star Id']
      local rewards = {}
      for _, key in ipairs({"money", "beamXP","motorsport","labourer","adventurer","specialized"}) do
        if row[key] ~= 0 then
          table.insert(rewards,{attributeKey = key, rewardAmount = row[key]})
        end
      end
      mission.careerSetup.starRewards[starKey] = rewards
      mission._dirty = true
    end
  end

end

local function getTranslatableStrings()

  --[[
  for _, mission in ipairs(missionList) do
    mission.careerSetup.showInFreeroam = false
    mission.careerSetup.showInCareer = true
    mission.date = 1663575239
    mission.author = "BeamNG"
    mission._dirty = true

  end
  local addedKeys = {}
  local lastCount = 0
  local finalList = {}
  for _, mission in ipairs(missionList) do

    local translation = {}
    local instance = gameplay_missions_missions.getMissionById(mission.id)
    table.insert(translation,mission.name)
    table.insert(translation,mission.description)
    local editHelper = missionTypeWindow:getCurrentEditorHelper()
    if editHelper then
      for _, elem in ipairs(editHelper.elements) do
        if elem.displayOptions and elem.displayOptions.isTranslation then
          if elem.type == 'string' then
            table.insert(translation,ffi.string(elem.ac))
          end
        end
      end
    end
    local keys = deepcopy(instance.sortedStarKeys or {})
    table.insert(keys,"noStarUnlocked")
    for _, key in ipairs(keys) do
      local t = mission.careerSetup.starOutroTexts[key]
      if t and t ~= "" then
        table.insert(translation,t)
      end
      local d = instance.defaultStarOutroTexts[key]
      if d and d ~= "" then
        table.insert(translation,d)
      end
      local s = instance.starLabels[key]
      if s and s ~= "" then
        table.insert(translation,s)
      end
    end
    local count = 0
    for _, elem in ipairs(translation) do
      if elem ~= "" and translateLanguage(elem, "NoTranslation!") ~= "NoTranslation!" then
        if not addedKeys[elem] then
          table.insert(finalList,{key = elem, value = translateLanguage(elem, elem)})
          count = count +1
        end
        addedKeys[elem] = true
      end
    end
    print(mission.id .. " -> " ..count)
  end



  local wordCount = 0
  local translationStrings = {}
  local translationJson = {}
  for _, elem in ipairs(finalList) do
    table.insert(translationStrings,string.format('"%s": "%s"', elem.key, elem.value))
    translationJson[elem.key] = elem.value
    local _,n = elem.value:gsub("%S+","")
    wordCount = wordCount + n
  end
  dump("Words: " .. wordCount)
  writeFile("translationText.json",table.concat( translationStrings, ",\n")..",\n")
  jsonWriteFile("translationJson.json",translationJson, true)
  ]]
end

local function applyTranslation()
  for _, elem in ipairs(translationData.translation) do
    if elem.starText then
      clickedMission.careerSetup.starOutroTexts[elem.source] = elem.key
    elseif elem.source == 'name' then
      clickedMission.name = elem.key
    elseif elem.source == 'description' then
      clickedMission.description = elem.key
    else
      if elem.source.type == 'string' then
        elem.source.ac = im.ArrayChar(elem.source.len, elem.key)
        clickedMission.missionTypeData[elem.source.fieldName] = elem.key
      end
    end
  end

  for _, win in ipairs(windows) do
    win:setMission(clickedMission)
  end
  clickedMission._dirty = true
end

local function missionTranslationHelperPopup()
  if im.BeginPopup("missionTranslationHelper") then
    if translationData == nil then
      local shortId = nil
      local f,t =  string.find(clickedMission.id, "-[^-]*$")
      if not f or not t then
        local p, fn, _ = path.split(clickedMission.id)
        shortId = fn
      else
        shortId = clickedMission.id:sub(f+1,t)
      end
      local level = clickedMission.startTrigger and clickedMission.startTrigger.level or "noLevel"
      translationData = {
        copyPastaPtr = im.ArrayChar(100000),
        copyPastaLength = 100000,
        translationKeyPtr = im.ArrayChar(1000,string.format("missions.%s.%s.%s",clickedMission.missionType, level, shortId)),
        translationKeyLength = 1000
      }
      makeTranslation()
    end
    if im.Button("Change Auto Key",im.ImVec2(-1,0)) then
      local level = clickedMission.startTrigger and clickedMission.startTrigger.level or "noLevel"
      local shortId = nil
      local f,t =  string.find(clickedMission.id, "-[^-]*$")
      if not f or not t then
        local p, fn, _ = path.split(clickedMission.id)
        shortId = fn
      else
        shortId = clickedMission.id:sub(f+1,t)
      end
      translationData.translationKeyPtr = im.ArrayChar(1000,string.format("missions.%s.%s.%s",level, clickedMission.missionType, shortId))
    end
    im.InputText("Key:##translationKey", translationData.translationKeyPtr, translationData.translationKeyLength)
    if im.Button("Make Translation",im.ImVec2(-1,0)) then
      makeTranslation()
    end
    im.InputTextMultiline("##translationCopyPasta", translationData.copyPastaPtr, translationData.copyPastaLength, im.ImVec2(500,500))
    if im.Button("Replace Mission Data with Keys",im.ImVec2(-1,0)) then
      applyTranslation()
    end
    im.EndPopup()
  else
    translationData = nil
  end
end


-- display window
local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Mission Editor",  im.WindowFlags_MenuBar) then

    if not generalInfo then
      loadWindows()
    end

    if im.BeginMenuBar() then
      if im.BeginMenu("File") then
        if im.MenuItem1("New Mission...") then
          openNewMissionPopup = true
          newMissionData.name = im.ArrayChar(1024, "Name")
          newMissionData.id = im.ArrayChar(1024, "Id")
          newMissionData.type = "flowgraph"
          newMissionData.copy = false
          newMissionData.autoId = true
          newMissionData.recalcId = true
        end
        local saveable = lastShownMission ~= nil
        if not saveable then im.BeginDisabled() end
        if im.MenuItem1("Save") then
          gameplay_missions_missions.saveMission(lastShownMission,lastShownMission.missionFolder)
          lastShownMission._dirty = false
        end
        if not saveable then im.EndDisabled() end
        if saveable then
          im.tooltip(dumps(lastShownMission.id) .. " to " .. lastShownMission.missionFolder .. "/info.json")
        end
        local changedMissioncount = 0
        for _, m in ipairs(missionList or {}) do
          if m._dirty then changedMissioncount = changedMissioncount + 1 end
        end
        if im.MenuItem1("Save All ("..changedMissioncount..")") then
          for _, m in ipairs(missionList) do
            if m._dirty then
              gameplay_missions_missions.saveMission(m,m.missionFolder)
              m._dirty = false
            end
          end
        end
        im.Separator()
        if im.BeginMenu("Delete") then
          if not saveable then im.BeginDisabled() end
          local files = {}
          local dirs = {}
          if lastShownMission then
            for _, f in ipairs(FS:findFiles(lastShownMission.missionFolder, "*", -1, true, false)) do
              table.insert(files, f)
              local dir, filename, ext =path.split(string.sub(f, 2+string.len(lastShownMission.missionFolder)))
              if dir then
                table.insert(dirs, dir)
              end
            end
          end
          im.Text("Contains " .. #files.." files and " .. #dirs .. " directories:")
          table.sort(files)
          table.sort(dirs)
          for _, f in ipairs(files) do
            im.Text(f)
          end
          im.Separator()
          for _, d in ipairs(dirs) do
            im.Text(d)
          end
          im.Separator()
          if im.MenuItem1("PERMANENTLY delete mission") then
            for _, f in ipairs(files) do
              FS:removeFile(f)
            end
            table.sort(dirs, function(a,b) return a>b end)
            for _, d in ipairs(dirs) do
              FS:directoryRemove(lastShownMission.missionFolder .. '/'..d)
            end
            FS:directoryRemove(lastShownMission.missionFolder)
            local newMissions = {}
            for _, m in ipairs(missionList) do
              if m.id ~= lastShownMission.id then
                table.insert(newMissions, m)
              end
            end
            missionList = newMissions
            lastShownMission = nil
            hoveredMission = nil
            clickedMission = nil

          end
          if lastShownMission then im.tooltip("Deletes the folder " .. lastShownMission.missionFolder.."!") end
          if not saveable then im.EndDisabled() end
          im.EndMenu()

        end
        if im.MenuItem1("Reload Mission System " .. (changedMissioncount > 0 and ("(" .. changedMissioncount .. " unsaved missions!)") or "")) then
          M.reloadMissionSystem()
        end
        if im.MenuItem1("(Debug) Print Mission Dependency Tree") then
          local currentMission = lastShownMission
        end
        im.EndMenu()
      end
      local variableClicked, translationClicked = false, false
      if im.BeginMenu("Tools") then
        if im.MenuItem1("Calculate Mission Issues") then
          issuesWindow:calculateMissionIssues(missionList, windows)
        end
        im.Separator()
        if not clickedMission then im.BeginDisabled() end
        if im.BeginMenu("Custom Editor Functions...") then
          local helper = M.getCurrentEditorHelperWhenActive()
          if helper then
            local sortedFunctions = tableKeysSorted(helper)
            for _, funName in ipairs(sortedFunctions) do
              if string.startswith(funName, "customFunction") then
                if im.MenuItem1(funName) then
                  helper[funName](helper, clickedMission, M)
                  for _, win in ipairs(windows) do
                    win:setMission(clickedMission)
                  end
                end
                if im.MenuItem1("All Mission of same type: " ..funName) then
                  for _, m in ipairs(missionList) do
                    if m.missionType == clickedMission.missionType then
                      helper[funName](helper, m, M)
                    end
                  end
                  for _, win in ipairs(windows) do
                    win:setMission(clickedMission)
                  end
                end
              end
            end

          end
          im.EndMenu()
        end
        im.Separator()

        if im.MenuItem1("Flowgraph Variable check") then
          variableClicked = true
        end
        if im.MenuItem1("Translation Helper") then
          translationClicked = true
        end
        if im.MenuItem1("Translation List (Debug)") then
          getTranslatableStrings()
        end
        if not clickedMission then im.EndDisabled() end
        im.Separator()
        if im.BeginMenu("Generate Attempts") then
          if not clickedMission then im.BeginDisabled() end
          if im.MenuItem1("Generate 25 Attempts") then
            gameplay_missions_progress.generateAttempts(clickedMission.id, 25, true)
          end
          if im.MenuItem1("Generate one 1-star attempt") then
            gameplay_missions_progress.generateAttempt(clickedMission.id, {unlockedStars = {oneStar = true}})
          end
          if im.MenuItem1("Generate one 2-star attempt") then
            gameplay_missions_progress.generateAttempt(clickedMission.id, {unlockedStars = {oneStar = true, twoStar = true}})
          end
          if im.MenuItem1("Generate one 3-star attempt") then
            gameplay_missions_progress.generateAttempt(clickedMission.id, {unlockedStars = {oneStar = true, twoStar = true, threeStar = true}})
          end
          if not clickedMission then im.EndDisabled() end
          if im.MenuItem1("Generate 1-5 Attempts for all Missions") then
            gameplay_missions_progress.startBatchMode()
            for _, mission in ipairs(missionList) do
              gameplay_missions_progress.generateAttempts(mission.id, 1 + math.floor(math.random()*4))
            end
            gameplay_missions_progress.endBatchMode()
            M.reloadMissionSystem()
          end
          im.tooltip("This will a few seconds, check the log for progress!")

          if im.MenuItem1("Generate 1-5 Attempts for random half of all Missions") then
            gameplay_missions_progress.startBatchMode()
            for _, mission in ipairs(missionList) do
              if math.random() < 0.5 then
                gameplay_missions_progress.generateAttempts(mission.id, 1 + math.floor(math.random()*4))
              end
            end
            gameplay_missions_progress.endBatchMode()
            M.reloadMissionSystem()
          end
          im.tooltip("This will a few seconds, check the log for progress!")
          im.EndMenu()
        end

        if im.MenuItem1("Export mission overview") then
          exportMissionOverview()
        end
        if im.MenuItem1("Import mission overview") then
          importMissionOverview()
        end

        im.EndMenu()
      end
      if variableClicked then missionTypeWindow:openPopup() end
      if translationClicked then im.OpenPopup("missionTranslationHelper") end

      if openNewMissionPopup then
        im.OpenPopup("NewMission")
        openNewMissionPopup = nil
      end
      newMissionPopup()
      if missionTypeWindow and missionTypeWindow.variablesHelperPopup then
        missionTypeWindow:variablesHelperPopup()
      end
      missionTranslationHelperPopup()
      im.EndMenuBar()
    end
    if missionList == nil then
      applyFilter()
      applyGrouping()
    end
    -- no missions indicator


    if missionTypeWindow.drawViews then
      missionTypeWindow:drawViews()
    end

    im.Columns(2)
    if initializeColumnWidth then
      im.SetColumnWidth(0, 420)
      initializeColumnWidth = nil
    end
    local missionListWidth = im.GetColumnWidth(0) -15
    local filterHeight = im.GetTextLineHeightWithSpacing()
    local winHeight = im.GetContentRegionAvail().y - filterHeight
    local yOrigin = im.GetCursorPos().y
    -- mission list ----
    local areaWidth = missionListWidth
    im.BeginChild1("Search",im.ImVec2(areaWidth, filterHeight+2), false)

    if editor.uiInputSearch(nil, missionSearchTxt, (areaWidth-40) ) then
      applyFilter()
      applySearch()
    end
    im.SameLine()

    local clr = nil
    local groupFilterText = {}
    if grouping.mode ~= "none" then
      table.insert(groupFilterText, "Grouped by: " .. grouping.mode)
    end
    for _, fl in ipairs(filterNamesSorted) do
      if filter[fl.key] then
        table.insert(groupFilterText, fl.name)
      end
    end

    if editor.uiIconImageButton(editor.icons.ab_filter_default, im.ImVec2(21,21), next(groupFilterText) and im.ImVec4(0,1,0,1)) then
      im.OpenPopup("MissionEditorGroupFilter")
      --grouping.mode = "type"
      --applyGrouping()
    end
    if im.IsItemHovered() then
      im.BeginTooltip()
      for _, elem in ipairs(groupFilterText) do
        im.BulletText(elem)
      end
      if not next(groupFilterText) then
        im.BulletText("No Filter active!")
      end
      im.EndTooltip()
    end


    if im.BeginPopup("MissionEditorGroupFilter") then
      im.BeginChild1("MissionEditorGroupFilterChild", im.ImVec2(300,200))
      im.PushItemWidth(im.GetContentRegionAvailWidth())
      if im.BeginCombo("##GroupMissions", "Grouping: " .. grouping.mode) then
        for _, gr in ipairs(groupingNamesSorted) do
          if im.Selectable1(gr.name, gr.key == grouping.mode) then
            grouping.mode = gr.key
            applyFilter()
            applyGrouping()
            saveGroupFilter()
            im.CloseCurrentPopup()
          end
        end
        im.EndCombo()
      end
      im.PopItemWidth()
      for _, fl in ipairs(filterNamesSorted) do
        local bl = im.BoolPtr(filter[fl.key])
        if im.Checkbox(fl.name, bl) then
          filter[fl.key] = not filter[fl.key]
          applyFilter()
          applySearch()
          applyGrouping()
          saveGroupFilter()
        end
      end
      if im.Checkbox('Short IDs', im.BoolPtr(editor.getPreference('missionEditor.general.shortIds'))) then
        editor.setPreference('missionEditor.general.shortIds', not editor.getPreference('missionEditor.general.shortIds'))
        editor.savePreferences()
      end
      im.EndChild()
      im.EndPopup()
    end


    im.EndChild()
    im.BeginChild1("missionList", im.ImVec2(areaWidth, -1), true)
      -- header
    local displayed = false
    if missionSearchDisplayResult then
      for _, item in ipairs(missionSearchResults) do
        displayMissionSelector(item.data)
        displayed = true
      end
    else
      if grouping.mode == "none" then
        for k,missionData in ipairs(missionList) do
          displayMissionSelector(missionData)
          displayed = true
        end
      else
        for _, key in ipairs(grouping.sortedKeys) do
          displayed = true
          local prevOther = nil
          if M.forceOpenTree then
            for k,missionData in ipairs(grouping.missions[key]) do
              if missionData.id == (hoveredMission or clickedMission or {}).id then
                im.SetNextItemOpen(true, im.Cond_Once)
              end
            end
          end
          if im.TreeNode1(key..'##'..key.."missionEditorGrouping") then
            for k,missionData in ipairs(grouping.missions[key]) do
              local other = nil
              if grouping.mode == 'type' then
                other = getMissionLevelOrNone(missionData)
              elseif grouping.mode == 'level' then
                other = getMissionType(missionData)
              end
              if other and prevOther and other ~= prevOther then
                im.Separator()
              end
              displayMissionSelector(missionData)
              prevOther = other
            end
            im.TreePop()
          end
        end
        M.forceOpenTree = nil
      end
    end
    if not displayed then
      im.Text("No missions were found!")
    end


    if im.IsItemHovered() then
      hoveredMission = nil
    end
    if not editor.keyModifiers.alt then
      hoveredMission = nil
    end

    local shownMission = hoveredMission or clickedMission
    if shownMission ~= lastShownMission then
      lastShownMission = shownMission
      shownMission = shownMission or nil -- default fill
      if shownMission then
        for _, win in ipairs(windows) do
          win:setMission(shownMission)
        end
      end
    end
    im.EndChild()

    im.NextColumn()
    if im.BeginTabBar('MissionEditorTabBar##') then
      local selectTab = nil
      if M.forceOpenTab then
        if M.forceOpenTab == 'Mission Properties' then
          selectTab = im.TabItemFlags_SetSelected
        end
      end
      if im.BeginTabItem('Mission Properties', nil, selectTab) then
        M.lastTabItemShown = 'Mission Properties'
        -- mission details ----
        local areaWidth = im.GetWindowContentRegionWidth() - im.GetCursorPos().x
        im.BeginChild1("missionDetails", im.ImVec2(areaWidth, winHeight-20), false, 0)

        -- header
        displayHeader(clickedMission, hoveredMission, shownMission)
        im.Separator()
        im.NewLine()

        -- details
        if shownMission then
          if shownMission.procedural then
            --im.BeginDisabled()
          end
          if shownMission._issueList then
            im.HeaderText("Issues: "..shownMission._issueList.count)
            if im.IsItemClicked() then
              showWindows.issuesWindow = not showWindows.issuesWindow
              --editor.setPreference("missionEditor.general.showWindows", showWindows)
              --editor.savePreferences()
            end
            if showWindows.issuesWindow then
              im.PushID1("issues" ..shownMission.id)
              issuesWindow:draw()
              im.PopID()
              im.Separator()
            else
              im.SameLine()
              im.HeaderText("(...)")
              im.Separator()
            end
          end

          im.HeaderText("General Info")
          if im.IsItemClicked() then
            showWindows.generalWindows = not showWindows.generalWindows
            editor.setPreference("missionEditor.general.showWindows", showWindows)
            editor.savePreferences()
          end
          if showWindows.generalWindows then
            for idx, win in ipairs(generalWindows) do
              im.PushID1("generalWindows" .. idx.."_"..shownMission.id)
              win:draw()
              im.PopID()
              im.Separator()
            end
          else
            im.SameLine()
            im.HeaderText("(...)")
            im.Separator()
          end
          im.HeaderText("Additional Info")
          if im.IsItemClicked() then
            showWindows.additionalWindows = not showWindows.additionalWindows
            editor.setPreference("missionEditor.general.showWindows", showWindows)
            editor.savePreferences()
          end
          if showWindows.additionalWindows then
            for idx, win in ipairs(additionalWindows) do
              im.PushID1("additionalWindows" .. idx.."_"..shownMission.id)
              win:draw()
              im.PopID()
              im.Separator()
            end
          else
            im.SameLine()
            im.HeaderText("(...)")
            im.Separator()
          end
          im.HeaderText("Mission Type Data")
          if im.IsItemClicked() then
            showWindows.missionTypeWindows = not showWindows.missionTypeWindows
            editor.setPreference("missionEditor.general.showWindows", showWindows)
            editor.savePreferences()
          end
          if showWindows.missionTypeWindows then
            for idx, win in ipairs(missionTypeWindows) do
              im.PushID1("missionTypeWindows" .. idx.."_"..shownMission.id)
              win:draw()
              im.PopID()
              im.Separator()
            end
          else
            im.SameLine()
            im.HeaderText("(...)")
          end
          if shownMission.procedural then
            --im.EndDisabled()
          end
        else
          im.Text("No Mission Selected.")
        end
        im.EndChild()
        im.EndTabItem()
      end
      for _, tab in ipairs(tabs) do
        selectTab = nil
        if M.forceOpenTab then
          if M.forceOpenTab == tab.tabName then
            selectTab = im.TabItemFlags_SetSelected
          end
        end
        if im.BeginTabItem(tab.tabName, nil, selectTab) then
          M.lastTabItemShown = tab.tabName
          local areaWidth = im.GetWindowContentRegionWidth() - im.GetCursorPos().x
          im.BeginChild1(tab.tabName.."windowhild", im.ImVec2(areaWidth, winHeight-20), false, 0)
          if shownMission then
            local mission = gameplay_missions_missions.getMissionById(shownMission.id)
            if mission then
              tab:draw()
            end
          else
            im.Text("No Mission Selected.")
          end
          im.EndChild()
          im.EndTabItem()
        end
      end
      M.forceOpenTab = nil
      im.EndTabBar()
    end
    im.Columns(1)
  end
  editor.endWindow()
  hoveredMission = nil
end


local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
  loadGroupFilter()
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(1500,700))
  editor.addWindowMenuItem("Mission Editor", onWindowMenuItem, {groupMenuName="Missions"})
  loadGroupFilter()
  showWindows = editor.getPreference("missionEditor.general.showWindows")
end


local function onEditorRegisterPreferences(prefsRegistry)

  prefsRegistry:registerCategory("missionEditor")
  prefsRegistry:registerSubCategory("missionEditor", "general", "General",
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {groupFilter = {"table", {}, "",nil, nil, nil, true}},
    {showWindows = {"table", showWindows, "",nil, nil, nil, true}},
    {shortIds = {"bool", false, "Use Short Ids", nil, nil, nil, false}},
    {alwaysShowScreenshots = {'bool',false,"",nil, nil, nil, true}},

  })
end


local function onSerialize()
  local data = {
    lastSelectedMissionId = lastShownMission and lastShownMission.id,
    lastTabItemShown = M.lastTabItemShown
  }
  return data
end

local function onDeserialized(data)

  if data then
    if data.lastSelectedMissionId then
      M.setMissionById(data.lastSelectedMissionId)
      M.forceOpenTree = true
    end
    if data.lastTabItemShown then
      M.forceOpenTab = data.lastTabItemShown
    end
  end
end
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.onEditorInitialized = onEditorInitialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorGui = onEditorGui
M.getMissionList = function() return missionList end
M.clickMission = function(m) clickedMission = m end
M.show = onWindowMenuItem
M.getStartTriggerWindow = function() return startTrigger end
M.getMissionTypeWindow = function() return missionTypeWindow end
M.setMissionById = function(id)
  if missionList == nil then
    missionList = gameplay_missions_missions.getFilesData() or {}
  end
  for k,missionData in ipairs(missionList) do
    if missionData.id == id then
      clickedMission = missionData
      return
    end
  end
end

M.getCurrentEditorHelperWhenActive = function()
  if not editor.isWindowVisible(toolWindowName) then return nil end
  if not missionTypeWindow or not missionTypeWindow.mission then return nil end
  return missionTypeWindow:getCurrentEditorHelper()
end

M.reloadMissionSystem = function()
  gameplay_missions_missions.reloadCompleteMissionSystem()
  missionList = gameplay_missions_missions.getFilesData()

  local oldId = lastShownMission and lastShownMission.id
  lastShownMission = nil
  hoveredMission = nil
  clickedMission = nil
  if oldId then
    for _,m in ipairs(missionList) do
      if m.id == oldId then
        clickedMission = m
        for _, win in ipairs(windows) do
          win:setMission(m)
        end
      end
    end
  end
  applyFilter()
  applySearch()
  applyGrouping()
  saveGroupFilter()
end
return M
