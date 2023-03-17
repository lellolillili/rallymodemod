-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"gameplay_missions_missionManager","gameplay_missions_startTrigger", "freeroam_bigMapMode","gameplay_missions_progress"}
local proceduralMissionGenerators = {}

-- mission recommended attributes
local recommendedAttributes = { "durability", "offroading", "rock crawling", "acceleration", "top speed", "nimble" }
local function getRecommendedAttributesList()
  return recommendedAttributes
end

local additionalAttributesSortedKeys = { "vehicle", "difficulty" }

local additionalAttributes = {
  vehicle = {
    valuesSorted = {
      {
        key = "own",
        label = "Own Vehicle"
      }, {
        key = "provided",
        label = "Provided Vehicle"
      },{
        key = "choice",
        label = "Own or Provided Vehicle"
      }, {
        key = "multi",
        label = "Multiple Vehicles"
      }, {
        key = "none",
        label = "No Vehicle"
      }
    },
    icon = "directions_car",
    label = "Vehicle Used",
    translationKey = "Vehicle Used"
  },
  difficulty = {
    valuesSorted = {
      {
        key = "veryLow",
        label = "Very Low "
      }, {
        key = "low",
        label = "Low"
      }, {
        key = "medium",
        label = "Medium"
      }, {
        key = "high",
        label = "High"
      }, {
        key = "veryHigh",
        label = "Very High"
      }
    },
    icon = "flag",
    label = "Difficulty",
    translationKey = "Difficulty",
  }
}
for _, att in pairs(additionalAttributes) do
  att.valuesByKey = {}
  for _, val in ipairs(att.valuesSorted) do
    val.translationKey = val.translationKey or val.label
    att.valuesByKey[val.key] = val
  end
end

local function getAdditionalAttributes()
  return additionalAttributes, additionalAttributesSortedKeys
end

-- mission types
local missionTypesDir = "/gameplay/missionTypes"
local missionTypeConstructorFilename = 'constructor'
local missionTypes
local function getMissionTypes()
  if not missionTypes then
    missionTypes = {}
    for _,missionFile in ipairs(FS:findFiles(missionTypesDir, missionTypeConstructorFilename..'.lua', 1, false, true)) do
      local dir,_,_ = path.splitWithoutExt(missionFile)
      local splitPath = split(dir,'/')
      local missionType = splitPath[#splitPath-1]
      table.insert(missionTypes, missionType)
    end
  end
  return missionTypes
end

-- mission constructors
local missionConstructors = {}
local function getMissionConstructor(missionTypeName)
  if not missionConstructors[missionTypeName] then
    local reqPath = missionTypesDir.."/"..missionTypeName .."/" .. missionTypeConstructorFilename
    local luaPath = reqPath..".lua"
    if not FS:fileExists(luaPath) then
      log("E", "", "Unable to load mission type, file not found: "..dumps(luaPath))
    else
      missionConstructors[missionTypeName] = require(reqPath)
      if not missionConstructors[missionTypeName] then
        log("E", "", "Unable to load mission type, couldn't require path: "..dumps(reqPath))
      end
    end
  end
  return missionConstructors[missionTypeName]
end

-- mission progress setup data
local missionProgressSetupData = {}
local missionProgressSetupDataFilename = 'progressSetup.json'
local function getMissionProgressSetupData(missionTypeName)
  if not missionProgressSetupData[missionTypeName] then
    local reqPath = missionTypesDir.."/"..missionTypeName .."/" .. missionProgressSetupDataFilename

    if FS:fileExists(reqPath) then
      missionProgressSetupData[missionTypeName] = readJsonFile(reqPath)
      if not missionProgressSetupData[missionTypeName] then
        log("E", "", "Unable to read progress Setup json file: "..dumps(reqPath))
        missionProgressSetupData[missionTypeName] = {}
      end
    else
      missionProgressSetupData[missionTypeName] = {}
    end
  end
  return missionProgressSetupData[missionTypeName]
end

-- mission static data
local missionStaticData = {}
local missionStaticDataFilename = 'staticData.json'
local function getMissionStaticData(missionTypeName)
  if not missionStaticData[missionTypeName] then
    local reqPath = missionTypesDir.."/"..missionTypeName .."/" .. missionStaticDataFilename

    if FS:fileExists(reqPath) then
      missionStaticData[missionTypeName] = readJsonFile(reqPath)
      if not missionStaticData[missionTypeName] then
        log("E", "", "Unable to read static data json file: "..dumps(reqPath))
        missionStaticData[missionTypeName] = {}
      end
    else
      missionStaticData[missionTypeName] = {}
    end
  end
  return missionStaticData[missionTypeName]
end


local missionEditors = {}
local function getMissionEditorForType(missionTypeName)
  if missionEditors[missionTypeName] == nil then
    local reqPath = missionTypesDir.."/"..missionTypeName .."/editor"
    local luaPath = reqPath..".lua"
    if not FS:fileExists(luaPath) then
      log("W", "", "found no editor for mission type " .. missionTypeName ..": "..dumps(luaPath))
    else
      missionEditors[missionTypeName] = require(reqPath)()
      if not missionEditors[missionTypeName] then
        log("E", "", "could not load editor for mission type " .. missionTypeName .. ": "..dumps(reqPath))
      end
    end
    -- make a default editor if none has been found.
    if not missionEditors[missionTypeName] then
      local E = {}
      E.__index = E
      missionEditors[missionTypeName] = gameplay_missions_missions.editorHelper(E)
    end
  end
  return missionEditors[missionTypeName]
end
M.getMissionEditorForType = getMissionEditorForType

local noPreviewFilepath = "/ui/modules/gameContext/noPreview.jpg"
local noThumbFilepath = "/ui/modules/gameContext/noThumb.jpg"
local previewFilenames = {"/preview.jpg","/preview.png","/preview.jpeg"}
local thumbFilenames = {"/thumbnail.jpg","/thumbnail.png","/thumbnail.jpeg"}
M.getNoPreviewFilepath = function() return noPreviewFilepath end
M.getNoThumbFilepath = function() return noThumbFilepath end

local function getMissionPreviewFilepath(missionData)
  -- check in mission Dir
  local found = false
  for _, fn in ipairs(previewFilenames) do
    if FS:fileExists(missionData.missionFolder..fn) then
      return missionData.missionFolder..fn
    elseif FS:fileExists(missionTypesDir.."/"..missionData.missionType.."/"..fn) then
      return missionTypesDir.."/"..missionData.missionType.."/"..fn
    end
  end
  return noPreviewFilepath
end
M.getMissionPreviewFilepath = getMissionPreviewFilepath

local function getThumbnailFilepath(missionData)
  -- check in mission Dir
  local found = false
  for _, fn in ipairs(thumbFilenames) do
    if FS:fileExists(missionData.missionFolder..fn) then
      return missionData.missionFolder..fn
    elseif FS:fileExists(missionTypesDir.."/"..missionData.missionType.."/"..fn) then
      return missionTypesDir.."/"..missionData.missionType.."/"..fn
    end
  end
  local preview = getMissionPreviewFilepath(missionData)
  if preview == noPreviewFilepath then
    return noThumbFilepath
  end
  return preview
end
M.getMissionPreviewFilepath = getMissionPreviewFilepath


local starOrder = {}
local sortStarKeys = function(a,b)
  local aa, bb = starOrder[a] or math.huge, starOrder[b] or math.huge
  if aa == bb then
    return a < b
  else
    return aa < bb
  end
end
-- sorts a list of star keys so that they are ordered by the sortedStarkeys property of a mission.
-- defaultStars will come before bonus stars
local function orderStarKeysDefaultThenBonus(mission)
  local sortedStars = {}
  local defaultStarKeysCache = {}
  local bonusStarKeysCache = {}
  for key, act in pairs(mission.careerSetup.starsActive or {}) do
    if act then
      table.insert(sortedStars, key)
      bonusStarKeysCache[key] = true
    end
  end

  local defaultKeysSorted, bonusKeysSorted = {}, {}
  if not mission.sortedStarKeys or mission.sortedStarKeys == {} then
    for i, key in ipairs(tableKeysSorted(mission.starLabels or {})) do
      starOrder[key] = i
    end
  else
    for i, key in ipairs(mission.sortedStarKeys or {}) do
      starOrder[key] = i
    end
  end
  for _, key in ipairs(mission.careerSetup.defaultStarKeys) do
    defaultStarKeysCache[key] = true
    bonusStarKeysCache[key] = nil
  end

  for _, key in ipairs(sortedStars) do
    if defaultStarKeysCache[key] then
      table.insert(defaultKeysSorted, key)
    else
      table.insert(bonusKeysSorted, key)
    end
  end
  table.sort(defaultKeysSorted, sortStarKeys)
  table.sort(bonusKeysSorted, sortStarKeys)
  return arrayConcat(deepcopy(defaultKeysSorted), deepcopy(bonusKeysSorted)), defaultKeysSorted, bonusKeysSorted, defaultStarKeysCache, bonusStarKeysCache
end

local function sanitizeMissionAfterCreation(mission)
  mission.bigMapIcon = mission.bigMapIcon or {}
  mission.bigMapIcon.icon = mission.bigMapIcon.icon or "mission_primary_01"
  mission.careerSetup._activeStarCache = {}
  local sortedStars, defaultKeysSorted, bonusKeysSorted, defaultStarKeysCache, bonusStarKeysCache = orderStarKeysDefaultThenBonus(mission)
  mission.careerSetup._activeStarCache.sortedStars = sortedStars
  mission.careerSetup._activeStarCache.defaultStarKeysByKey = defaultStarKeysCache
  mission.careerSetup._activeStarCache.defaultStarKeysSorted = defaultKeysSorted
  mission.careerSetup._activeStarCache.defaultStarCount = #defaultKeysSorted
  mission.careerSetup._activeStarCache.defaultStarKeysToIndex = {}
  for k,v in ipairs(defaultKeysSorted) do
    mission.careerSetup._activeStarCache.defaultStarKeysToIndex[v] = k
  end
  mission.careerSetup._activeStarCache.bonusStarKeysByKey = bonusStarKeysCache
  mission.careerSetup._activeStarCache.bonusStarKeysSorted = bonusKeysSorted
  mission.careerSetup._activeStarCache.bonusStarCount = #bonusKeysSorted

  mission.careerSetup._activeStarCache.sortedStarRewardsByKey = {}
  for key, list in pairs(mission.careerSetup.starRewards) do
    local newList = {}
    for _, reward in ipairs(list) do
      local elem = {rewardAmount = reward.rewardAmount, icon = "star", attributeKey = reward.attributeKey}
      table.insert(newList, elem)
    end
    mission.careerSetup._activeStarCache.sortedStarRewardsByKey[key] = newList
  end

  mission.onStart = mission.onStart or nop
  mission.onUpdate = mission.onUpdate or nop
  mission.onStop = mission.onStop or nop
  mission.stateChanged = mission.stateChanged or nop
  mission.getUserSettingsData = mission.getUserSettingsData or nop
  mission.processUserSettings = mission.processUserSettings or nop
  mission.attemptAbandonMission = mission.attemptAbandonMission or nop
  mission.getRandomizedAttempt = mission.getRandomizedAttempt or function() return gameplay_missions_progress.testHelper.randomAttemptType(), {} end
end
M.sanitizeMissionAfterCreation = sanitizeMissionAfterCreation


local function recursiveRemoveNestedFromCondition(mId, cond)
  if cond.nested then
    if cond.type == 'multiAnd' or cond.type =='multiOr' then
      for _, n in ipairs(cond.nested) do
        M.recursiveRemoveNestedFromCondition(mId, cond.nested)
      end
    else
      cond.nested = nil
      log("W","","In Mission " .. mId..": Nested condition found in a condition that should not have nested in it. Re-save the mission to apply fix.")
    end
  end
end
M.recursiveRemoveNestedFromCondition =  recursiveRemoveNestedFromCondition

local function sanitizeMission(missionData, filepath)
  -- sanitize previews
  missionData.previewFile = missionData.previewFile or getMissionPreviewFilepath(missionData)
  missionData.thumbnailFile = missionData.thumbnailFile or getThumbnailFilepath(missionData)
  -- sanitize name
  if not missionData.name or (missionData.name == "") then
    log("E", "", "Missing 'name' field at: "..filepath)
    missionData.name = "MISSING NAME, CHECK LOGS ("..(missionData.name or "")..")"
  end
  if missionData.name == "" or string.find(missionData.name, ".json") then
    log("E", "", "Incorrect 'name' field, please clean it up (no filepaths, no underscores, etc): "..dumps(missionData.name).." at: "..filepath)
    missionData.name = "INCORRECT NAME, CHECK LOGS ("..(missionData.name or "")..")"
  end

  -- sanitize description
  missionData.description = missionData.description or ""

  if #(missionData.startConditions or {}) > 1 then
    log("W", "", "startingConditions field is deprecated, use single startingCondition field: "..filepath)
    missionData.startCondition = missionData.startConditions[1]
  end
  if #(missionData.visibleConditions or {}) > 1 then
    log("W", "", "visibleConditions field is deprecated, use single visibleCondition field: "..filepath)
    missionData.visibleConditions = missionData.visibleConditions[1]
  end

  missionData.startCondition = (missionData.startCondition or {type='always'})
  missionData.visibleCondition = (missionData.visibleCondition or {type='automatic'})
  M.recursiveRemoveNestedFromCondition(missionData.id, missionData.startCondition)
  M.recursiveRemoveNestedFromCondition(missionData.id, missionData.visibleCondition)

  if not missionData.startCondition.type then missionData.startCondition = {type='always'} end
  if not missionData.visibleCondition.type then missionData.visibleCondition = {type='always'} end

  missionData.startTrigger = missionData.startTrigger or {type = 'none'}
  missionData.missionTypeData = missionData.missionTypeData or {}
  missionData.previewFile = missionData.previewFile or noPreviewFilepath

  missionData.grouping = missionData.grouping or {}
  missionData.grouping.id = missionData.grouping.id or ""
  missionData.grouping.label = missionData.grouping.label or ""

  missionData.additionalAttributes = missionData.additionalAttributes or {}
  missionData.customAdditionalAttributes = missionData.customAdditionalAttributes or {}

  missionData.careerSetup = missionData.careerSetup or {
    showInCareer = false,
    showInFreeroam = true,
    starsActive = {},
    defaultStarKeys = {},
    starRewards = {},
    starOutroTexts = {}
  }
  missionData.careerSetup.starsActive = missionData.careerSetup.starsActive or {}
  missionData.careerSetup.defaultStarKeys = missionData.careerSetup.defaultStarKeys or {}
  missionData.careerSetup.starRewards = missionData.careerSetup.starRewards or {}
  missionData.careerSetup.starOutroTexts = missionData.careerSetup.starOutroTexts or {}
  missionData.careerSetup._activeStarCache = {}

  -- sort starReward entries by attributeKey
  for _, list in pairs(missionData.careerSetup.starRewards) do
    -- only order if there's at least 2 elements
    if list[2] then
      local sortedKeys, keyToReward = {}, {}
      for _, elem in ipairs(list) do
        table.insert(sortedKeys, elem.attributeKey)
        keyToReward[elem.attributeKey] = elem
      end
      -- sort keys by attribute
      career_branches.orderAttributeKeysByBranchOrder(sortedKeys)
      -- re-order the list
      for i, key in ipairs(sortedKeys) do
        list[i] = keyToReward[key]
      end
    end
  end


  missionData.starLabels = missionData.starLabels or {}
  missionData.defaultStarOutroTexts = missionData.defaultStarOutroTexts or {}


  missionData.setupModules = missionData.setupModules or {}
  for _, modName in ipairs({'timeOfDay', 'traffic'}) do
    missionData.setupModules[modName] = missionData.setupModules[modName] or {enabled = false}
  end

  --[[
  -- deprecated features
  missionData.prefabs = missionData.prefabs or {}
  missionData.prefabsRequireCollisionReload = missionData.prefabsRequireCollisionReload or false
  missionData.trafficAllowed = missionData.trafficAllowed or (missionData.trafficAllowed == nil)
  missionData.recommendedAttributes = missionData.recommendedAttributes or {}
  table.sort(missionData.recommendedAttributes)
  missionData.devNotes = missionData.devNotes or {text = '', mode = 'silent', devMission = false}
  missionData.devNotes.text = missionData.devNotes.text or ''
  missionData.devNotes.mode = missionData.devNotes.mode or 'silent'
  missionData.devNotes.devMission = missionData.devNotes.devMission or false

  ]]
end


-- loads a single mission from file (no cache)
local infoFile = "info.json"
local missionsDir = "/gameplay/missions/"
local function loadMission(missionDir)
  if not string.startswith(missionDir, missionsDir) then
    log("E", "", "Unable to load mission, not placed in "..missionsDir..": "..dumps(missionDir))
    return
  end
  if string.find(missionDir, " ") then
    log("E", "", "Unable to load mission, the path cannot contain spaces: "..dumps(missionDir))
    return
  end
  local infoPath = missionDir .. "/" .. infoFile
  if not FS:fileExists(infoPath) then
    log("E", "", "Unable to load mission, info file not found: "..dumps(infoPath))
    return nil
  end
  local missionData = jsonReadFile(infoPath)
  if not missionData then
    log("E", "", "Unable to load mission data, couldn't parse file: "..dumps(infoPath))
    return nil
  end
  local _, missionId, _ = path.split(missionDir)
  --dump(missionId)
  missionId = string.sub(missionDir, #missionsDir+1)
  missionData.id = missionId
  missionData.missionFolder = missionDir
  sanitizeMission(missionData, infoPath)

  -- cache mission attributes (with consistent order)
  --missionData.recommendedAttributesKeyBasedCache = {}
  --for _, v in ipairs(missionData.recommendedAttributes) do
  --  missionData.recommendedAttributesKeyBasedCache[v] = true
  --end
  return missionData
end

local function saveMission(missionData, newFolder)
  local targetFolder = (newFolder or missionData.missionFolder) .. "/"..infoFile
  missionData.recommendedAttributes = {}
  for k, v in pairs(missionData.recommendedAttributesKeyBasedCache or {}) do
    if v then
      table.insert(missionData.recommendedAttributes, k)
    end
  end
  local careerSetup = deepcopy(missionData.careerSetup or {})
  careerSetup._activeStarCache = nil
  local data = {
    name = missionData.name or "",
    description = missionData.description or "",
    missionType = missionData.missionType or "",
    retryBehaviour = missionData.retryBehaviour or "infiniteRetries",
    startCondition = missionData.startCondition or {type='always'},
    visibleCondition = missionData.visibleCondition or {type='always'},
    startTrigger = deepcopy(missionData.startTrigger),
    --recommendedAttributes = missionData.recommendedAttributes,
    --prefabs = missionData.prefabs or {},
    --prefabsRequireCollisionReload = missionData.prefabsRequireCollisionReload or false,
    missionTypeData = missionData.missionTypeData or {},
    --trafficAllowed = missionData.trafficAllowed or (missionData.trafficAllowed==nil),
    devNotes = missionData.devNotes,
    additionalAttributes = missionData.additionalAttributes,
    customAdditionalAttributes = missionData.customAdditionalAttributes,
    grouping = missionData.grouping,
    isAvailableAsScenario = missionData.isAvailableAsScenario,
    author = missionData.author,
    date = missionData.date,
    careerSetup = careerSetup,
    setupModules = missionData.setupModules,
  }
  -- write pretty
  jsonWriteFile(targetFolder, data, true)
  log("I","","Wrote mission successfully to " .. targetFolder)
end

-- returns all missions data from info.json files
local filesData
local function getFilesData()
  if not filesData then
    filesData = {}
    local fromFilesCount, genCount = 0, 0
    -- load filebased missions
    for _,missionInfo in ipairs(FS:findFiles(missionsDir, 'info.json', -1, false, true)) do
      --dump(missionInfo)
      local missionDir, _, _ = path.split(missionInfo)
      missionDir = string.sub(missionDir,0,-2)
      local missionData = loadMission(missionDir)
      if not missionData then
        goto continue
      end
      fromFilesCount = fromFilesCount + 1
      table.insert(filesData, missionData)
      ::continue::
    end
    -- load procedural missions.
    for _, generator in ipairs(proceduralMissionGenerators) do

      local genData = generator.generate() or {}
      for _, missionData in ipairs(genData) do
        sanitizeMission(missionData, "proceduralMission")
        missionData.procedural = true
        genCount = genCount + 1
        table.insert(filesData, missionData)
      end
    end

    table.sort(filesData, function(a,b) return a.id<b.id end)
    log("D","","Loaded " .. #filesData .. " total missions: " .. fromFilesCount .. " from files, " .. genCount .. " from generators.")
  end
  return filesData
end

local function createMission(id, data)
  data = data or {}
  data.name = data.name or id
  data.id = id
  data.description = data.description or "Mission Description for " .. id
  data.startCondition = data.startCondition or {{type="vehicleDriven"}}
  data.visibleCondition = data.visibleCondition or {}
  data.missionType = data.missionType or "flowgraph"
  data.startTrigger = data.startTrigger or {type="level", level='gridmap'}
  --data.retryBehaviour = data.retryBehaviour or "infiniteRetries"
  --data.recommendedAttributesKeyBasedCache = data.recommendedAttributesKeyBasedCache or {}
  saveMission(data, missionsDir.."/"..id)
  local loaded = loadMission(missionsDir.."/"..id)
  table.insert(loaded, data)
  table.insert(filesData, loaded)
  return loaded
end


-- return all missions
local missions, missionsById
local function get()
  if not missions then
    missions = {}
    missionsById = {}
    for _, missionData in ipairs(getFilesData()) do
      -- load constructor
      local missionConstructor = getMissionConstructor(missionData.missionType)
      if not missionConstructor then
        log("E", "", "Mission "..dumps(infoPath).." did not specify a valid missionType: "..dumps(missionData.missionType))
        goto continue
      end

      -- actually construct the mission
      local result, mission, add = xpcall(function() return missionConstructor(deepcopy(missionData)) end, debug.traceback)
      if add == true or not mission then
        log("E", "", "Unable to construct mission "..dumps(missionData.id).." of type "..dumps(missionData.missionType)..", its constructor returned "..dumps(add))
        goto continue
      end
      if type(mission) == 'string' then
        log("E", "", "Unable to construct mission "..dumps(missionData.id).." of type "..dumps(missionData.missionType)..", something went wrong:")
        dump(mission)
        goto continue
      end

      -- sanitize after creation
      M.sanitizeMissionAfterCreation(mission)

      -- load progress
      mission.defaultProgressKey = mission.defaultProgressKey or 'default'
      mission.currentProgressKey = mission.currentProgressKey or mission.defaultProgressKey or 'default'
      mission.autoAggregates = mission.autoAggregates or missionData.autoAggregates or {}

      if not mission.defaultUserSettings then
        mission.defaultUserSettings = {}
        if mission.getUserSettingsData then
          for _, d in ipairs(mission:getUserSettingsData() or {}) do
            mission.defaultUserSettings[d.key] = d.value
          end
        end
      end

      -- mission.saveData = gameplay_missions_progress.loadMissionSaveData(mission)
      mission.unlocks = {}

      if not mission.startTrigger then
        log("E", "", "Unable to load mission due to missing startTrigger information: "..dumps(missionData.id))
        goto continue
      end

      table.insert(missions, mission)
      missionsById[mission.id] = mission
      ::continue::
    end

     -- arbitrary but explicit ordering, for determinism when we add mission dependencies (and coincidentally for UI purposes too)
    table.sort(missions, function(a, b) return a.id < b.id end)

    for _,mission in ipairs(missions) do
      mission.saveData = gameplay_missions_progress.loadMissionSaveData(mission)
    end

    gameplay_missions_unlocks.setUnlockForwardBackward(missions)
    gameplay_missions_unlocks.updateUnlockStatus(missions)
  end


  return missions
end

local function getAllIds()
  get()
  return tableKeysSorted(missionsById)
end

local function getMissionById(id)
  get()
  return missionsById[id]
end

local function getMissionsByMissionType(type)
  get()
  local ret = {}
  for _, mission in pairs(missionsById) do
    if mission.missionType == type then
      table.insert(ret, mission)
    end
  end
  return ret
end

-- returns a list of {level="foo", pos=[1,2,3], radius=4} locations where the given mission can be accepted
local locationsCache = {}
local function getLocations(mission)
  if locationsCache[mission.id] then return locationsCache[mission.id] end
  locationsCache[mission.id] = {}
  local t = mission.startTrigger
  if not t then
    log("E", "", "Mission "..dumps(mission.id).." has no startTrigger information")
    return locationsCache[mission.id]
  end
  local locations, err = gameplay_missions_startTrigger.parseMission(mission)
  if err then
    log("E", "", "Error while parsing startTrigger for mission " .. mission.id .. ": " .. dumps(err))
  else
    for _, loc in ipairs(locations) do
      loc.mission = mission
      loc.name = mission.name
      table.insert(locationsCache[mission.id], loc)
    end
  end

  return locationsCache[mission.id]
end

local function onExtensionLoaded()
  local files = FS:findFiles('/lua/ge/extensions/gameplay/missions/proceduralMissionGenerators/','*.lua',-1)
  local count = 0
  for _, file in ipairs(files) do
    local gen = require(file:sub(0,-5))
    gen.generate = gen.generate or nop
    proceduralMissionGenerators[count+1] = gen
    count = count+1
  end
  log("D","","Loaded " .. count .. " procedural Mission Generators from " .. #files .. " files.")
end



M.getLocations = getLocations
M.getFilesData = getFilesData
M.getMissionTypes = getMissionTypes
M.getRecommendedAttributesList = getRecommendedAttributesList
M.getAdditionalAttributes = getAdditionalAttributes
M.getMissionConstructor = getMissionConstructor
M.getMissionStaticData = getMissionStaticData
M.getMissionProgressSetupData = getMissionProgressSetupData
M.get = get
M.getAllIds = getAllIds
M.getMissionById = getMissionById
M.getMissionsByMissionType = getMissionsByMissionType
M.loadMission = loadMission
M.saveMission = saveMission
M.createMission = createMission
M.onExtensionLoaded = onExtensionLoaded

M.reloadCompleteMissionSystem = function()
  log("I","","Reloading complete mission system.")
  log("I","","Clearing MissionEnter.")
  gameplay_missions_missionEnter.clearCache()
  log("I","","Clearing Missions.")
  gameplay_missions_missions.clearCache()
  log("I","","Clearing Complete.")
end

M.clearCache = function() filesData = nil locationsCache = {} missions = nil end
M.baseMission = function(C, ...) return require('/lua/ge/extensions/gameplay/missions/missionTypes/baseMission')(C, ...) end
M.flowMission = function(C, ...) return require('/lua/ge/extensions/gameplay/missions/missionTypes/flowMission')(C, ...) end
M.editorHelper = function(C, ...) return require('/lua/ge/extensions/gameplay/missions/missionTypes/editorHelper')(C, ...) end
return M
