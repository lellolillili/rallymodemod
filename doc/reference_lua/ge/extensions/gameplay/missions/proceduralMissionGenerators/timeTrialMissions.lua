-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}


local function getBaseMission()
  return {
    description = "Mission Description for newIdadssad",
    name = "newIdadssad",
    missionType = "generatedTimeTrial",
    retryBehaviour = "infiniteRetries",
    startCondition = {
        type = "vehicleDriven"
      },
    visibleCondition = {},
    startTrigger = {
      type = "coordinates",
      level = "gridmap",
      pos = nil,
      radius = 3
    },
    trafficAllowed = false,
  }
end

local autoPrefabs = {
  prefabs = '',
  reversePrefabs = '_reverse',
  forwardPrefabs = '_forward'
}
local prefabExt = {'.prefab', '.prefab.json'}
local previewExt = {'.jpg','.png','.jpeg'}

local cacheFields = {'trackName','closed','reversible','allowRollingStart'}
local cachePath = "gameplay/temp/timeTrials/"
local cachedRaceFiles = {}
local function getCachedRacefile(level, race)
  local id = string.lower(level.levelName)..'-'..race.trackName.."-procedural"
  local cacheFile = cachePath.. id .. '.json'
  if not cachedRaceFiles[cacheFile] then
    if not FS:fileExists(cacheFile) then
      local path = require('/lua/ge/extensions/gameplay/race/path')("New Race")
      local succ = path:fromTrack(race, true)
      if succ then
        local data = path:onSerialize()
        for _, field in ipairs(cacheFields) do data[field] = race[field] end
        cachedRaceFiles[cacheFile] = data
        jsonWriteFile(cacheFile, data, true)
      else
        jsonWriteFile(cacheFile, {invalid = true}, true)
        cachedRaceFiles[cacheFile] = {invalid = true}
        log("E","","Failed to convert " .. cacheFile)
      end
    else
      cachedRaceFiles[cacheFile] = jsonReadFile(cacheFile)
    end
  end

  return cachedRaceFiles[cacheFile], cacheFile
end

local function listWithoutEmptyString(list)
  local ret = {}
  for _, elem in ipairs(list or {}) do
    if elem ~= "" and elem ~= "/" then
      table.insert(ret, elem)
    end
  end
  return  ret

end

local function generate()
  extensions.load('scenario_quickRaceLoader')
  local data = scenario_quickRaceLoader.getQuickraceList()
  local missions = {}

  local hiddenFiles = {}
  for _, mission in ipairs(gameplay_missions_missions.getFilesData()) do
    --if mission.missionType == 'timeTrial' then
    --if mission.missionTypeData.hidesOriginalTimeTrialFile then
    --  hiddenFiles[mission.missionTypeData.hidesOriginalTimeTrialFile] = true
    --end
    --end
  end
  --dump(hiddenFiles)
  local hiddenFileCount = 0

  for _, level in ipairs(data) do
    for _, race in ipairs(level.tracks) do
      --dump(dumps(race.ignoreAsMission or "fals").."  ".. dumps(race.trackName) )
      if not race.ignoreAsMission then
        --dumpz(race,1)
        -- for now, only convert quickraces with a .race.json file
        local raceFile = race.raceFile
        local raceId = string.lower(level.levelName)..'-'..race.trackName.."-procedural"
        if not raceFile and not race.isTrackEditorTrack and not race.lapConfigBranches then
          race, raceFile = getCachedRacefile(level, race)
          race = race or {}
          if not race or race.invalid or race.hideMission or race == {} then
            --log("I","","INVALID Race from cache: " .. raceId)
            --dump(raceFile)
            raceFile = nil
          end
        end


        if raceFile  then
          if hiddenFiles[raceFile] then
            hiddenFileCount = hiddenFileCount +1
          else
            local mission = getBaseMission()
            mission.id = "timeTrials/"..string.lower(level.levelName)..'/'..race.trackName.."-procedural"
            mission.name = race.name
            mission.description = race.description
            local previewFilenameExt = nil
            for _, ext in ipairs(previewExt) do
              if not mission.previewFile then
                local file = "/levels/"..level.levelName.."/quickrace/"..race.trackName..ext
                if FS:fileExists(file) then
                  previewFilenameExt = ext
                  mission.previewFile = file
                  mission.thumbnailFile = file
                end
              end
            end
            mission.missionFolder = string.lower(level.levelName)..'-'..race.trackName
            mission.careerSetup = {
              defaultStarKeys = {'justFinish'},
              showInCareer = false,
              showInFreeroam = true,
              starsActive = {justFinish=true},
              starRewards = {},
            }

            local isRaceJson = string.sub(raceFile,#raceFile-9,#raceFile) == '.race.json'

            mission.missionTypeData = {
              --hidesOriginalTimeTrialFile = raceFile,
              raceFile = raceFile,
              closed = race.closed,
              reversible = race.reversible,
              allowRollingStart = race.allowRollingStart,
              defaultLaps = race.defaultLaps,
              prefabs = listWithoutEmptyString(race.prefabs),
              reversePrefabs = listWithoutEmptyString(race.reversePrefabs),
              forwardPrefabs = listWithoutEmptyString(race.forwardPrefabs),
              trackName = race.trackName
            }
            for key, _ in pairs(autoPrefabs) do
              for i, p in ipairs(mission.missionTypeData[key] or {}) do
                if not FS:fileExists(p) then
                  local found = false
                  for _, ext in ipairs(prefabExt) do
                    local file = "levels/"..level.levelName.."/"..p..ext
                    if FS:fileExists(file) then
                      mission.missionTypeData[key][i] = file
                      found = true
                    end
                  end
                  if not found then
                    mission.missionTypeData[key][i] = nil
                  end
                end
              end
            end

            -- add automatic prefabs only if they exist
            for list, suf in pairs(autoPrefabs) do
              for _, ext in ipairs(prefabExt) do
                local file = "levels/"..level.levelName.."/quickrace/"..race.trackName..suf..ext
                if FS:fileExists(file) then
                  table.insert(mission.missionTypeData[list], file)
                end
              end
            end

            mission.startTrigger.level = string.lower(level.levelName)
            for _, sp in ipairs(race.startPositions) do
              if sp.oldId == race.defaultStartPosition then
                mission.startTrigger.pos = sp.pos
                mission.startTrigger.rot = sp.rot
              end
            end
            -- only add the mission if a startTrigger was found
            if mission.startTrigger.pos then

              local enableConversion = false
              if enableConversion then
                if #mission.missionTypeData.prefabs <= 1 and #mission.missionTypeData.reversePrefabs <= 1 and #mission.missionTypeData.forwardPrefabs <= 1 then
                  mission.id = 'gameplay/missions/'..level.levelName..'/timeTrial/'..race.trackName
                  mission.missionFolder = 'gameplay/missions/'..level.levelName..'/timeTrial/'..race.trackName
                  mission.missionType = "timeTrial"
                  --FS:copyFile(mission.previewFile, mission.missionFolder.."/preview."..ext)
                  if mission.previewFile then
                    local dir, fn, ext = path.split(mission.previewFile)
                    FS:copyFile(mission.previewFile, mission.missionFolder.."/preview."..ext)
                  end
                  local fixPrefab = function(key, newKey)
                    if mission.missionTypeData[key][1] then
                      local dir, fn, ext = path.split(mission.missionTypeData[key][1])
                      FS:copyFile(mission.missionTypeData[key][1], mission.missionFolder.."/"..newKey..'.'..ext)
                      mission.missionTypeData[key] = nil
                      mission.missionTypeData[newKey] = newKey..'.'..ext
                    end
                  end
                  fixPrefab("prefabs","prefab")
                  fixPrefab("reversePrefabs","reversePrefab")
                  fixPrefab("forwardPrefabs","forwardPrefab")
                  FS:copyFile(raceFile, mission.missionFolder.."/race.race.json")
                  mission.missionTypeData.raceFile = "race.race.json"
                  gameplay_missions_missions.saveMission(mission)
                end

              else
                table.insert(missions, mission)
              end
              --FS:copyFile(mission.previewFile, mission.missionFolder.."/preview"..previewFilenameExt)
            end
            --jsonWriteFile(mission.missionFolder..'/race.race.json', race, true)
          end
        end
      end
    end
  end
  log("D","","Hid " .. hiddenFileCount .. " prodecural TimeTrials missions because they were hidden by real missions.")
  return missions
end

M.generate = generate
return M