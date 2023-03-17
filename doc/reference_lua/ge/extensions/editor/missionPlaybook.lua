-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local ffi = require("ffi")
local im = ui_imgui
local grayColor = im.ImVec4(0.6,0.6,0.6,1)
local toolWindowName = "Mission Playbook"
M.dependencies = {'gameplay_missions_missions','editor_missionPlaybook_attributeViewer','editor_missionPlaybook_unlockedMissionsViewer','editor_missionPlaybook_missionTreeViewer'}

local missionList = nil
local filterInput = im.ArrayChar(1024,'')
local defaultPlaybookPath = "missionPlaybooks/"
local testingSlotName = "playbookTestingSlot"

local missionSearch = require('/lua/ge/extensions/editor/util/searchUtil')()
local missionSearchTxt = im.ArrayChar(256, "")
local missionSearchDisplayResult = false
local missionSearchResults = {}
local careerMissionIds = nil

local condensed = true

local function newBook()
  return {
    page = 1,
    instructions = {},
    results = {}
  }
end
M.book = newBook()

local function drawMissionSelector(e)
  if not careerMissionIds then
    careerMissionIds = {}
    for _, m in ipairs(gameplay_missions_missions.get()) do
      if m.careerSetup.showInCareer then
        table.insert(careerMissionIds, m.id)
      end
    end
  end
  local ret = missionSearch:beginSearchableSimpleCombo(im, '##selectMission', e.missionId, careerMissionIds)
  if ret then
    e.missionId = ret
    e.stars = {}
    e._dirty = true
  end
end


local function drawMissionAttempt(e)
  local mission = gameplay_missions_missions.getMissionById(e.missionId)
  if not condensed then
    im.Text("Playing Mission: \"" ..translateLanguage(mission.name, mission.name, true).."\"")
    im.SameLine()
    im.PushItemWidth(100)
    drawMissionSelector(e)
    im.PopItemWidth()
    im.Text("And getting these Stars:")
    if mission then
      local sortedStars = mission.careerSetup._activeStarCache.sortedStars
      for sIdx, key in ipairs(sortedStars) do
        im.PushID1(key.."child")
        local toggle = false
        if im.Checkbox(key.."##StarKey"..sIdx, im.BoolPtr(e.stars[key] or false)) then
          toggle = true
        end
        im.SameLine()
        im.TextColored(grayColor, translateLanguage(mission.starLabels[key],mission.starLabels[key], true))
        toggle = im.IsItemClicked() or toggle
        if toggle then
          e.stars[key] = not (e.stars[key] or false)
        end
        im.PopID()
      end
    end
  else
    local txt = "Mission: \"" ..translateLanguage(mission.name, mission.name, true).."\" "
    local sortedStars = mission.careerSetup._activeStarCache.sortedStars
    for sIdx, key in ipairs(sortedStars) do
      if e.stars[key] then
        txt = txt .. "["..key.."] "
      end
    end

    im.TextWrapped(txt)
  end

end

local drawFunctions = {
  missionAttempt = drawMissionAttempt
}


local function executeMissionAttempt(e)
  local change = gameplay_missions_progress.generateAttempt(e.missionId, {unlockedStars = e.stars})
  local ret = {}
  ret.missionId = e.missionId
  ret.unlockChange = change.unlockChange
  ret.starRewards = change.starRewards
  ret.unlockedStarsChanged = change.unlockedStarsChanged
  return ret
end

local executeFunctions = {
  missionAttempt = executeMissionAttempt
}


local function play(untilIdx)
  untilIdx = untilIdx or math.huge
  M.book.results = {}

  for i, e in ipairs(M.book.instructions) do
    if i < untilIdx then
      dump("Instructions:")
      dump(e)
      local fun = executeFunctions[e.type] or nop
      local funRet = fun(e)
      local resultData = {
        funRet = funRet
      }
      extensions.hook("onPlaybookLogAfterStep", resultData)
      M.book.results[i] = resultData
    end
  end
  --dump(book.results)
end


local function getAllRemainingStarCombos(params)
  params = params or {}
  -- find all missions that still have open stars
  local choiceBook = {}
  for _, m in ipairs(gameplay_missions_missions.get()) do
    if m.careerSetup.showInCareer and m.unlocks.startable then
      local useMission = true

      if params.onlyBranch then
        local isBranch = false
        for key, active in pairs(params.onlyBranch) do
          isBranch = isBranch or (active and m.unlocks.branchTags[key])
        end
        useMission = useMission and isBranch
      end

      if params.onlyTier then
        local isTier = false
        for tier, active in pairs(params.onlyTier) do
          isTier = isTier or (active and m.unlocks.maxBranchlevel == tier)
        end
        dump(m.id .. " -> " .. dumps(isTier))
        useMission = useMission and isTier
      end

      if useMission then
        if not params.onlyBonusStars then
          local defaultChoices = {}
          local defaultCache = {}
          for i, key in ipairs(m.careerSetup._activeStarCache.defaultStarKeysSorted) do
            defaultCache[key] = true
            if not m.saveData.unlockedStars[key] then
              table.insert(defaultChoices, {mId = m.id, starKeys=deepcopy(defaultCache)})
            end
          end
          table.insert(choiceBook, defaultChoices)
        end
        if not params.onlyDefaultStars then
          local bonusChoices = {}
          for _, key in ipairs(m.careerSetup._activeStarCache.bonusStarKeysSorted) do
            if not m.saveData.unlockedStars[key] then
              table.insert(bonusChoices, {mId = m.id, starKeys={[''..key]=true}})
            end
          end
          table.insert(choiceBook, bonusChoices)
        end
      end
    end
  end
  local instructions = {}
  if params.defaultOrder then
    for _, e in ipairs(choiceBook) do
      for _, i in ipairs(e) do
        table.insert(instructions, i)
      end
    end
  else
    local counter = params.count or (#choiceBook*10)
    while next(choiceBook) and counter > 0 do
      local idx = math.floor(math.random()*#choiceBook)+1
      local entry = choiceBook[idx]
      table.insert(instructions, entry[1])
      table.remove(entry, 1)
      if not next(entry) then
        table.remove(choiceBook, idx)
      end
      counter = counter -1
    end
  end
  return instructions
end

local function generateAndPlaybook(params)
  M.book = newBook()

  local count = params.count or 10000
  while count > 0 do
    local allInstructions = getAllRemainingStarCombos(params)
    if not next(allInstructions) then return end
    local instruction = allInstructions[1]
    local e = {type = "missionAttempt", missionId = instruction.mId, stars = instruction.starKeys}
    local fun = executeFunctions[e.type] or nop
    local funRet = fun(e)
    local resultData = {
      funRet = funRet
    }
    extensions.hook("onPlaybookLogAfterStep", resultData)

    table.insert(M.book.instructions, e)
    table.insert(M.book.results, resultData)

    count = count -1
  end

end


local function drawElement(e)
  --im.Text(dumps(e))
end

local function savePlaybook(book, savePath)
  jsonWriteFile(savePath, M.book, true)
end

local function loadPlaybook(filename)
  if not filename then
    return
  end
  local json = readJsonFile(filename)
  if not json then
    log('E', logTag, 'unable to find Book: ' .. tostring(filename))
    return
  end
  return json
end


-- display window
local function onEditorGui()
  if editor.beginWindow(toolWindowName, toolWindowName,  im.WindowFlags_MenuBar) then
    if im.BeginMenuBar() then
      if im.BeginMenu("File...") then
        if im.MenuItem1("Clear") then
          M.book = newBook()
        end
        if im.MenuItem1("Save as...") then
          extensions.editor_fileDialog.saveFile(function(data) savePlaybook(M.book, data.filepath) end, {{"missionPlaybook Files",".missionPlaybook.json"}}, false, defaultPlaybookPath)
        end
        if im.MenuItem1("Load") then
          editor_fileDialog.openFile(function(data) M.book = loadPlaybook(data.filepath) or M.book.instructions end, {{"missionPlaybook Files",".missionPlaybook.json"}}, false, defaultPlaybookPath)
        end
        im.EndMenu()
      end
      if not (career_career and career_career.isCareerActive()) then
        im.BeginDisabled()
      end
      if im.BeginMenu("Util...") then
        if im.MenuItem1("Clear Testing Slot") then
          career_career.deactivateCareer()
          career_saveSystem.removeSaveSlot(testingSlotName)
          career_career.createOrLoadCareerAndStart(testingSlotName)
        end
        im.tooltip("Switches to a clean career slot.")
        im.EndMenu()
      end
      if im.BeginMenu("Run...") then
        if im.MenuItem1("Play") then
          play()
        end
        im.tooltip("Runs all the elements with the current career slot.")
        if im.MenuItem1("Play with Empty Slot") then
          career_career.deactivateCareer()
          career_saveSystem.removeSaveSlot(testingSlotName)
          career_career.createOrLoadCareerAndStart(testingSlotName)
          play()
        end
        im.tooltip("Switches to a clean career slot and runs all the elements there.")
        im.EndMenu()
      end
      if not (career_career and career_career.isCareerActive()) then
        im.EndDisabled()
        im.MenuItem1("(?)")
        im.tooltip("Load career manually the first time and stay in the level.")
      end
      if im.BeginMenu("Generate...") then
        if im.MenuItem1("All Missions") then
          generateAndPlaybook({})
        end
        if im.BeginMenu("All Missions, only...") then
          for _, tier in ipairs({1, 2, 3}) do
            if im.MenuItem1("All Missions, only Tier " .. tier) then
              generateAndPlaybook({onlyTier = {[tier] = true}})
            end
          end
          im.Separator()
          for _, amount in ipairs({1,5,10,25,50,100}) do
            if im.MenuItem1("All Missions, only ".. amount.." stars") then
              generateAndPlaybook({count = amount})
            end
          end
          im.Separator()

          if im.MenuItem1("All Missions, only Default Stars") then
            generateAndPlaybook({onlyDefaultStars=true})
          end
          if im.MenuItem1("All Missions, only Bonus Stars") then
            generateAndPlaybook({onlyBonusStars=true})
          end

          im.EndMenu()
        end
        for _, branch in ipairs(career_branches.getSortedBranches()) do
          im.Separator()
          if im.MenuItem1("Only " .. branch.name) then
            generateAndPlaybook({onlyBranch = {[branch.id] = true}})
          end
          for _, tier in ipairs({1, 2, 3}) do
            if im.MenuItem1("Only " .. branch.name..", only Tier " .. tier) then
              generateAndPlaybook({onlyBranch = {[branch.id] = true}, onlyTier = {[tier] = true}})
            end
          end
        end
        im.EndMenu()
      end
      im.EndMenuBar()
    end
    M.drawBookViewer()
    im.BeginChild1("elements",im.GetContentRegionAvail(), im.WindowFlags_AlwaysVerticalScrollbar)
    im.Columns(2)
    im.SetColumnWidth(0, 100)
    local remIdx, upIdx, downIdx, addIdx = nil, nil, nil

    for i, e in ipairs(M.book.instructions) do
      im.PushID1(i.."ElementPlaybook")
      if i < M.book.page then
        im.PushStyleColor2(im.Col_Text, im.ImVec4(0.4,0.4,0.4,1))
      end
      if i == M.book.page then
        im.PushStyleColor2(im.Col_Text, im.ImVec4(0.4,1,0.4,1))
      end
      im.Text(tostring(i))
      if not condensed then
        if im.Button("Remove") then
          remIdx = i
        end
        if i > 1 and im.Button("Up") then
          upIdx = i
        end
        if i < #M.book.instructions and im.Button("Down") then
          downIdx = i
        end
      end
      im.NextColumn()

      local fun = drawFunctions[e.type] or nop
      fun(e)

      im.NextColumn()
      im.PopID()
      im.Separator()
      if i <= M.book.page then
        im.PopStyleColor(1)
      end
    end
    im.Columns(1)
    im.EndChild()

    if im.Button("Add...") then
      table.insert(M.book.instructions, {type = "missionAttempt", missionId = "italy/delivery/001-mattress", stars = {piecesBronze = true}})
    end

    if remIdx then
      table.remove(M.book.instructions, remIdx)
    end
    if upIdx then
      local tmp = M.book.instructions[upIdx-1]
      M.book.instructions[upIdx-1] = M.book.instructions[upIdx]
      M.book.instructions[upIdx] = tmp
    end
    if downIdx then
      local tmp = M.book.instructions[downIdx+1]
      M.book.instructions[downIdx+1] = M.book.instructions[downIdx]
      M.book.instructions[downIdx] = tmp
    end

    editor.endWindow()
  end
end


local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local bookViewers = {}
local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(1500,700))
  editor.addWindowMenuItem(toolWindowName, onWindowMenuItem, {groupMenuName="Missions"})

end


local function onEditorRegisterPreferences(prefsRegistry)

--  prefsRegistry:registerCategory("missionEditor")
--[[  prefsRegistry:registerSubCategory("missionEditor", "general", "General",
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {groupFilter = {"table", {}, "",nil, nil, nil, true}},
    {showWindows = {"table", showWindows, "",nil, nil, nil, true}},
  })
]]
end



  local pagePtr = im.IntPtr(1)
local function drawBookViewer()

  if #M.book.results == 0 then return end
  im.PushItemWidth(im.GetContentRegionAvailWidth()-150)
  pagePtr[0] = M.book.page
  if im.SliderInt("##SliderIntlaskjdl",pagePtr, 1, #M.book.results) then
    M.book.page = pagePtr[0]
  end
  im.SameLine()
  if im.Checkbox("Condensed", im.BoolPtr(condensed)) then
    condensed = not condensed
  end
  im.PopItemWidth()

end

local function onSerialize()
  local data = {
    book = M.book,
    condensed = condensed
  }
  return data
end

local function onDeserialized(data)
  if data then
    M.book = data.book or newBook()
    condensed = data.condensed or false
  end
end
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.drawBookViewer = drawBookViewer

M.onEditorInitialized = onEditorInitialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorGui = onEditorGui
M.show = onWindowMenuItem

return M
