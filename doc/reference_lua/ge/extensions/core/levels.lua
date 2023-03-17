-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local cache = nil

-- finds all levels: this has a lot of backward compatibility code in there
-- warning: slow, lots of filesystem interaction
local function _findAvailableLevels()
  local res = {}
  local level_dirs = FS:findFiles('/levels/', '*', 0, false, true)
  table.sort(level_dirs, function(a,b) return string.lower(a) < string.lower(b) end )

  for _, d in pairs(level_dirs) do
    -- check if its a valid folder really
    if FS:fileExists(d) or not FS:directoryExists(d) or d == "/levels/mod_info" then
      goto continue
    end
    local l = {}
    -- valid level?
    l.dir = d
    l.infoPath = d .. '/info.json'
    if not FS:fileExists(l.infoPath) then
      log('W', '', 'info.json missing: ' .. l.infoPath)
    end

    -- figure out name
    l.levelName = d:match('levels/([^/]+)')

    -- figure out entry points (in order of priority)
    local newSceneTreeEntry = d .. '/main/'
    local oldMainFile = d .. '/main.level.json'
    if FS:directoryExists(newSceneTreeEntry) then
      l.fullfilename = newSceneTreeEntry
    elseif FS:fileExists(oldMainFile) then
      l.fullfilename = oldMainFile
    else
      -- look for any mission files in there and use the first
      local files = FS:findFiles(d, '*.mis', 1, true, false)
      if #files ~= 0 then
        l.fullfilename = files[1]
      else
        log('E', '', 'No entry point for level found: ' .. d .. '. Ignoring level.')
        goto continue
      end
    end

    -- figure out the entry point value. We use that to find some other files (decals, images, etc)
    local dirname, filename, ext = path.split(l.fullfilename)
    filename = string.gsub(filename, "%.mis$", "")
    l.entryPoint = string.gsub(filename, "%.level.json$", "")

    l.dirEntry = l.dir .. '/' .. l.entryPoint

    table.insert(res, l)
    ::continue::
  end
  return res
end

local function getList()
  if cache ~= nil then
    --dump{'cache valid: ', cache}
    return cache
  end

  local levels = {}
  if not FS:directoryExists('/levels/') then
    log('E', '', 'main levels folder not found: /levels/')
    return {}
  end

  -- find all levels
  local found_levels = _findAvailableLevels()
  --dump{'found_levels', found_levels}

  for _, l in pairs(found_levels) do
    -- so, enrich the data of the levels for the user interface below
    local info = jsonReadFile(l.infoPath) or {}

    -- figure out the mod this belongs to
    -- info.mod = extensions.core_modmanager.getModFromPath(l.infoPath) or 'BeamNG' -- TODO: FIXME: SUPER SLOW

    info.misFilePath = l.dir ..'/'..l.entryPoint
    info.levelName = l.levelName
    info.fullfilename = l.fullfilename

    if info.x86Compatible ~= nil then
      log("W", "", "Found deprecated flag 'x86Compatible' in level: "..dumps(l.levelName)..". The flag will be ignored")
      info.x86Compatible = nil
    end

    if info.hidden ~= nil then
      log("W", "", "Found deprecated flag 'hidden' in level: "..dumps(l.levelName)..". The flag has been renamed to 'isAuxiliary'")
      if info.isAuxiliary == nil then
        info.isAuxiliary = info.hidden
      end
    end

    info["official"] = isOfficialContentVPath(l.dir)

    if type(info["previews"]) == 'table' and #info["previews"] > 0 then
      -- add prefix
      local newPreviews = {}
      for _, img in pairs(info["previews"]) do
        table.insert(newPreviews, l.dir..'/' .. img)
      end
      info["previews"] = newPreviews
    else
      info["title"] = l.levelName
      info["previews"] = {
        imageExistsDefault(l.dirEntry..'.png', imageExistsDefault(l.dirEntry..'_preview.png')),
      }
    end
    info["preview"] = nil

    local foundDefaultSpawn = false
    if type(info.spawnPoints) == 'table' then
      for _, point in pairs(info.spawnPoints) do
        if not point.previews then point.previews = {} end

        -- add path prefix
        local newPreviews = {}
        for _, img in pairs(point.previews) do
          table.insert(newPreviews, l.dir..'/' .. img)
        end
        table.insert(newPreviews, imageExistsDefault(l.dir..'/'.. (point.preview or ''), l.dirEntry..'_preview.png'))
        point.previews = newPreviews
        point.preview = nil
        if point.objectname == info.defaultSpawnPointName then
          foundDefaultSpawn = true
          point.previews = info["previews"]
          point.flag = 'default'
        end
      end
    else
      info.spawnPoints = {}
    end

    if type(info.garagePoints) == 'table' then
      for _, point in pairs(info.garagePoints) do
        if not point.previews then point.previews = {} end

        -- add path prefix
        local newPreviews = {}
        for _, img in pairs(point.previews) do
          table.insert(newPreviews, l.dir..'/' .. img)
        end
        table.insert(newPreviews, imageExistsDefault(l.dir..'/'.. (point.preview or ''), l.dirEntry..'_preview.png'))
        point.previews = newPreviews
        point.preview = nil
      end
    else
      info.garagePoints = {}
    end

    if type(info.gasStationPoints) == 'table' then
      for _, point in pairs(info.gasStationPoints) do
        if not point.previews then point.previews = {} end

        -- add path prefix
        local newPreviews = {}
        for _, img in pairs(point.previews) do
          table.insert(newPreviews, l.dir..'/' .. img)
        end
        table.insert(newPreviews, imageExistsDefault(l.dir..'/'.. (point.preview or ''), l.dirEntry..'_preview.png'))
        point.previews = newPreviews
        point.preview = nil
      end
    else
      info.gasStationPoints = {}
    end

    if not foundDefaultSpawn then
      -- insert default spawn point
      table.insert(info.spawnPoints, {
        previews = info["previews"],
        translationId = 'ui.common.default',
        flag = 'default'
      })
    end

    table.insert(levels, info)
    ::continue::
  end

  -- now filter out .mis levels if a json version of the same exists
  local jsonLevels = {}
  for _, level in pairs(levels) do
    if string.find(level.fullfilename, ".json") then
      jsonLevels[level.levelName] = true
    end
  end

  local newLevels = {}
  for _, level in pairs(levels) do
    -- check if there is a json version of this, thus hide the old .mis file format
    if string.find(level.fullfilename, ".mis") and jsonLevels[level.levelName] then
      --log('D', '', 'not adding .mis level as .json format is existing for the same level: ' .. dumps(level))
    else
      table.insert(newLevels, level)
    end
  end
  levels = newLevels

  -- sort by name, case insensitive
  table.sort(levels, function(a, b) return string.lower(a.levelName) < string.lower(b.levelName) end )

  cache = levels
  --dump{"generated levels cache: ", cache}

  return cache
end

-- Returns array of level names only
local function getSimpleList()
  local res = {}
  for _, level in ipairs(getList()) do
    table.insert(res, level.levelName)
  end
  return res
end

local function notifyUI()
  guihooks.trigger('onLevelsChanged', getList())
end

local function getLevelByName(levelName)
  levelName = string.lower(levelName)
  for _, l in ipairs(getList()) do
    if string.lower(l.levelName) == levelName then
      return l
    end
  end
  return nil
end

local function onFilesChanged(files)
  for _,v in pairs(files) do
    local filename = v.filename
    if string.startswith(filename, '/levels/') then
      -- dump{'onFileChanged: invalidating level cache', filename, type}
      cache = nil
      notifyUI()
      return
    end
  end
end

local nextSpawnVehicle = nil
local function maybeLoadDefaultVehicle()
  local success = core_vehicles.loadMaybeVehicle(nextSpawnVehicle)
  if not success then
    log("E", "", "Wrong 'spawnVehicle' parameter used on level load request: "..dumps(nextSpawnVehicle))
  end
  nextSpawnVehicle = nil
end

local function onClientPostStartMission()
  for _, name in ipairs(scenetree.findClassObjects('DecalRoad')) do
    local road = scenetree.findObject(name)
    if road then
      road:regenerate()
    end
  end
end

local function expandMissionFileName(missionFileName)
  if FS:directoryExists(missionFileName) then
    return missionFileName
  end
  local mfn = String(missionFileName)
  local missionFile = FS:expandFilename(missionFileName)

  if  FS:fileExists(missionFile) then
    return missionFile
  end
  --If the mission file doesn't exist... try to fix up the string.
  local newMission = missionFile
  --Support for old .mis files
  if string.find(missionFile, ".mis$") then
    newMission = string.gsub(missionFile, ".mis$", ".level.json")

    if FS:fileExists(newMission) then
      return newMission
    end
  end

  --try the new filename
  if not string.find(missionFile, ".level.json$") then
    newMission = missionFile..".level.json"

    if FS:fileExists(newMission) then
      return newMission
    end
  end

  if FS:fileExists(missionFile..'.mis') then
    return missionFile..'.mis'
  end
end

local function startLevelActual(levelPath, delayedStart, customLoadingFunction)
  if scenetree.MissionCleanup then
    return
  end

  -- check if new format
  if levelPath:find('main.level.json') and not FS:fileExists(levelPath) then
    local newName = levelPath:sub(0, levelPath:find('main.level.json') - 1)
    if FS:directoryExists(newName) then
      log('D', '', 'converting level argument to new format: ' .. tostring(levelPath) .. ' > ' .. tostring(newName))
      levelPath = newName
    end
  end

  local loadLevel = function()
    local expandedLevelPath = expandMissionFileName(levelPath)
    if not expandedLevelPath or expandedLevelPath == "" then
      log('E', '', 'expanded mission file is invalid - '..dumps(expandedLevelPath) .. ' from ' .. tostring(levelPath))
      core_gamestate.requestExitLoadingScreen('')
      return false
    end

    server.createGame(expandedLevelPath, customLoadingFunction)
    core_gamestate.requestExitLoadingScreen('')
  end

  if delayedStart then
    log('D', '', 'Triggering a delayed start of loading level...')
    endActiveGameMode(loadLevel)
  else
    return loadLevel()
  end
end

local function getLevelName(path)
  return string.match(path, '^/*levels/(.-)/.*')
end

local function startLevel(levelPath, delayedStart, customLoadingFunction, spawnVehicle)
  nextSpawnVehicle = spawnVehicle
  -- restirct from calling again until done
  if core_gamestate.getLoadingStatus('') then return end
  core_gamestate.requestEnterLoadingScreen('')
  local function help ()
    return startLevelActual(levelPath, delayedStart, customLoadingFunction)
  end
  if scenetree.MissionCleanup then
    return serverConnection.disconnect(help)
  else
    return help()
  end
end

-- metatable for this module for backward compatibility
M.levelsDir = '/levels/' -- backward compatibility

-- public interface
M.onFilesChanged         = onFilesChanged
M.onClientPostStartMission = onClientPostStartMission
M.maybeLoadDefaultVehicle = maybeLoadDefaultVehicle
M.requestData           = notifyUI
M.startLevel            = startLevel
M.expandMissionFileName = expandMissionFileName
M.getLevelName          = getLevelName

-- main API
M.getList        = getList
M.getSimpleList  = getSimpleList
M.getLevelByName = getLevelByName

return M
