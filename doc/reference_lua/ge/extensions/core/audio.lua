-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local forLoad = {}
local forLoadLevel = {}

local asset_banks = {}
local meta_banks = {}
local ambient_banks = {}

local inited = false

local loadedBankCache = {} -- keeps track on what banks are already loaded for faster lua reloading
local levelProjectsCache = {}

local function cacheSetEntry(bankFilePath)
 if string.sub(bankFilePath, 1, 1) ~= '/' then
    bankFilePath = "/"..bankFilePath
  end
  bankFilePath = string.lower(bankFilePath)
  loadedBankCache[bankFilePath] = true
end

local function cacheClearEntry(bankFilePath)
 if string.sub(bankFilePath, 1, 1) ~= '/' then
    bankFilePath = "/"..bankFilePath
  end
  bankFilePath = string.lower(bankFilePath)
  loadedBankCache[bankFilePath] = false
end

local function loadBanksInFolder(folder)
  local bankFiles = FS:findFiles(folder, '*.bank', 0, true, false)

  local stringFiles = {}
  local preloadFiles = {}
  local normalFile = {}

  for _,filepath in ipairs(bankFiles) do
    if string.sub(filepath, 1, 1) ~= '/' then
      filepath = "/"..filepath
    end
    filepath = string.lower(filepath)
    if string.find(filepath, 'string') then
      table.insert(stringFiles, filepath)
    elseif not string.find(filepath, 'ambient_maps') then
      if string.find(filepath, 'preload') then
        table.insert(preloadFiles, filepath)
      else
        table.insert(normalFile, filepath)
      end
    end
  end

  table.sort(stringFiles, function(a, b) return a < b end)
  table.sort(preloadFiles, function(a, b) return a < b end)
  table.sort(normalFile, function(a, b) return a < b end)

  -- log("I", "onFirstUpdate", 'found bank files'..dumps(bankFiles))

  for _,filepath in ipairs(stringFiles) do
    if not loadedBankCache[filepath] then
      loadedBankCache[filepath] = true
      SFXFMODProject.loadBaseBank(filepath, true)
    end
  end
  for _,filepath in ipairs(preloadFiles) do
    if not loadedBankCache[filepath] then
      loadedBankCache[filepath] = true
      SFXFMODProject.loadBaseBank(filepath, true)
    end
  end
  for _,filepath in ipairs(normalFile) do
    if not loadedBankCache[filepath] then
      loadedBankCache[filepath] = true
      SFXFMODProject.loadBaseBank(filepath, false)
    end
  end
end

local function populateAssetBanks(directory)
  local bankFiles = FS:findFiles(directory, '*.bank', 0, true, false)
  bankFiles = tableMerge(bankFiles, FS:findFiles(directory..'/mods', '*.bank', 0, true, false))
  asset_banks = {}

  for _,filepath in ipairs(bankFiles) do
    if string.sub(filepath, 1, 1) ~= '/' then
      filepath = "/"..filepath
    end
    filepath = string.lower(filepath)
    if string.find(filepath, 'assets') or string.find(filepath, 'streams')  then
      table.insert(asset_banks, filepath)
    end
  end

  table.sort(asset_banks, function(a, b) return a < b end)

  -- log("I", "populateAssetBanks", 'Asset banks: '..dumps(asset_banks))
  return asset_banks
end

local function populateMetaBanks(directory)
  local bankFiles = FS:findFiles(directory, '*.bank', 0, true, false)
  bankFiles = tableMerge(bankFiles, FS:findFiles(directory..'/mods', '*.bank', 0, true, false))
  local meta_banks = {}

  for _,filepath in ipairs(bankFiles) do
    if string.sub(filepath, 1, 1) ~= '/' then
      filepath = "/"..filepath
    end
    filepath = string.lower(filepath)
    if not string.find(filepath, 'assets') and not string.find(filepath, 'streams')  then
      table.insert(meta_banks, filepath)
    end
  end

  table.sort(meta_banks, function(a, b) return a < b end)

  -- log("I", "populateMetaBanks", 'Meta banks: '..dumps(meta_banks))
  return meta_banks
end

local function loadBanks(bankFiles)
  local stringFiles = {}
  local preloadFiles = {}
  local normalFile = {}

  for _,filepath in ipairs(bankFiles) do
    if string.sub(filepath, 1, 1) ~= '/' then
      filepath = "/"..filepath
    end
    filepath = string.lower(filepath)
    if string.find(filepath, 'string') then
      table.insert(stringFiles, filepath)
    elseif string.find(filepath, 'preload') then
        table.insert(preloadFiles, filepath)
    else
        table.insert(normalFile, filepath)
    end
  end

  table.sort(stringFiles, function(a, b) return a < b end)
  table.sort(preloadFiles, function(a, b) return a < b end)
  table.sort(normalFile, function(a, b) return a < b end)

   for _,filepath in ipairs(stringFiles) do
    if not loadedBankCache[filepath] then
      loadedBankCache[filepath] = true
      SFXFMODProject.loadBaseBank(filepath, true)
    end
  end
  for _,filepath in ipairs(preloadFiles) do
    if not loadedBankCache[filepath] then
      loadedBankCache[filepath] = true
      SFXFMODProject.loadBaseBank(filepath, true)
    end
  end
  for _,filepath in ipairs(normalFile) do
    if not loadedBankCache[filepath] then
      loadedBankCache[filepath] = true
      SFXFMODProject.loadBaseBank(filepath, false)
    end
  end
end

local function loadBaseBanks()
  loadBanks(asset_banks)
  loadBanks(meta_banks)

  inited = true

  for i, v in ipairs(forLoad) do
    if not loadedBankCache[v] then
      loadedBankCache[v] = true
      SFXFMODProject.loadBaseBank(v)
    end
  end
  forLoad = {}
end

local function registerBaseBank(path)
  local inLevelOrLoadingOrLoading = getMissionFilename() ~= "" or LoadingManager:isLoadingInProgress()
  if inLevelOrLoading then
    return
  end
  if string.sub(path, 1, 1) ~= '/' then
    path = "/"..path
  end
  path = string.lower(path)
  if inited then
    if not loadedBankCache[path] then
      loadedBankCache[path] = true
      SFXFMODProject.loadBaseBank(path)
    end
  else
    table.insert(forLoad, path)
  end
end

local function loadLevelBank(bankFilePath)
  if string.sub(bankFilePath, 1, 1) ~= '/' then
    bankFilePath = "/"..bankFilePath
  end
  bankFilePath = string.lower(bankFilePath)
  local inLevelOrLoading = getMissionFilename() ~= "" or LoadingManager:isLoadingInProgress()
  if not inLevelOrLoading then
    for _,v in ipairs(forLoadLevel) do
      if v == bankFilePath then
        return
      end
    end
    table.insert(forLoadLevel, bankFilePath)
    return
  end

  if loadedBankCache[bankFilePath] then
    return
  end

  loadedBankCache[bankFilePath] = true

  local project = SFXFMODProject()
  project.fileName = String(bankFilePath)
  local _, filename, _ = path.split(bankFilePath)
  local projectName = 'project_'..filename
  project:registerObject(projectName)
  scenetree.DataBlockGroup:addObject(project) -- TODO find a way to do it implicitly
  table.insert(levelProjectsCache, projectName)
end

local function loadVehicleBank(bankPath)
  if string.sub(bankPath, 1, 1) ~= '/' then
    bankPath = "/"..bankPath
  end
  bankPath = string.lower(bankPath)
  if loadedBankCache[bankPath] then
    return
  end
  SFXFMODProject.loadBaseBank(bankPath, true, false)
  loadedBankCache[bankPath] = true
end

local function loadLevelBanks()
  for i, v in ipairs(ambient_banks) do
    loadLevelBank(v)
  end
  for i, v in ipairs(forLoadLevel) do
    loadLevelBank(v)
  end
  forLoadLevel = {}
end

local function populateBankTables()
  local useHeadphones = TorqueScriptLua.getBoolVar('$pref::SFX::enableHeadphonesMode')
  --dump("useHeadphones = "..tostring(useHeadphones))

  local asset_directory
  local meta_directory

  asset_directory = '/art/sound/fmod/desktop'
  if useHeadphones then
    meta_directory = '/art/sound/fmod/desktop_headphones'
  else
    meta_directory = '/art/sound/fmod/desktop'
  end

  asset_banks = populateAssetBanks(asset_directory)
  meta_banks = populateMetaBanks(meta_directory)
  ambient_banks = {}

  for i,filepath in ipairs(asset_banks) do
    if string.find(filepath, 'ambient_maps') then
      table.insert(ambient_banks, filepath)
      table.remove(asset_banks, i)
    end
  end

  for i,filepath in ipairs(meta_banks) do
    if string.find(filepath, 'ambient_maps') then
      table.insert(ambient_banks, filepath)
      table.remove(meta_banks, i)
    end
  end

  table.sort(ambient_banks, function(a, b) return a < b end)

  --log("I", "populateAssetBanks", 'Asset banks: '..dumps(asset_banks))
  --log("I", "populateMetaBanks", 'Meta banks: '..dumps(meta_banks))
  --log("I", "onFirstUpdate", 'Ambients banks: '..dumps(ambient_banks))
end

local function onFirstUpdate()
  --log("I", "onFirstUpdate", 'onFirstUpdate called....')

  profilerPushEvent('audioLoadBanksFirstFrame')
  if M.hotloadTriggered then
    log("I", "audio", 'Hotloading banks....')
    loadedBankCache = {}
    levelProjectsCache  = {}
    SFXFMODProject.hotloadingTriggered()
  end

  populateBankTables()
  loadBaseBanks()

  if M.hotloadTriggered then
    -- We need to trigger what would have happened in onClientPreStartMission because we are
    -- already in the level and triggered hotloading
    loadLevelBanks()
    SFXFMODProject.hotloadingCompleted()
  end

  M.hotloadTriggered = nil

  profilerPopEvent() -- audioLoadBanksFirstFrame
end

local function onClientPreStartMission(levelPath)
  -- log("I", "loadLevelBank", "Loading default level banks")
   profilerPushEvent('loadAudioBanks')

  loadLevelBanks()
  profilerPopEvent() -- loadAudioBanks
end

local function onClientEndMission()
  -- These banks get unloaded on level unload in C++ as the containing SFXFMODProject is destroyed
  -- so clear their cache entries so they get loaded on next level load
  for _, v in ipairs(ambient_banks) do
    cacheClearEntry(v)
  end
  levelProjectsCache  = {}
end

local function startProcessForHotloading()
    for i, projectName in ipairs(levelProjectsCache) do
      local project = scenetree.findObject(projectName)
      if project then
        project:deleteObject()
      end
    end
end

local function triggerBankHotloading()
  log('I', 'audio', 'Banks hotloading started.....')
  startProcessForHotloading()
  loadedBankCache = {}
  levelProjectsCache  = {}
  SFXFMODProject.hotloadingTriggered()
  populateBankTables()
  loadBaseBanks()
  loadLevelBanks()
  SFXFMODProject.hotloadingCompleted()
  log('I', 'audio', 'Banks hotloading finished.')
end

local function onFilesChanged(files)
  local reloadBanks = false
  for _,v in pairs(files) do
    local filename = v.filename
    -- file notification strips leading forward slash but the loadedBankCache keys start with a leading forward slash.
    -- make sure the key we use here matches that used previously in loadBaseBank
    if string.sub(filename, 1, 1) ~= '/' then
      filename = "/"..filename
    end

    if filename and filename:match('.*%.bank$') then
      filename = string.lower(filename)
      loadedBankCache[filename] = false

      -- We have to wait for all banks to complete building before we trigger hotloading
      for k,v1 in pairs(loadedBankCache) do
        if v1 == true then
          goto continue
        end
      end
      log("I", "onFileChanged", 'onFileChanged called....')
      reloadBanks = true
    end
    ::continue::
  end

  if reloadBanks then
    triggerBankHotloading()
  end
end

local function onSerialize()
    -- Note(AK) 20/07/2020: Uncomment to reenable hotloading banks on Ctrl + L, and delete the current return statment
    -- startProcessForHotloading()
    -- return { hotloadTriggered = true }
    return {loadedBankCache = loadedBankCache, levelProjectsCache = levelProjectsCache}
end

local function onDeserialized(data)
  -- Note(AK) 20/07/2020: Uncomment to reenable hotloading banks on Ctrl + L, and delete the current active statments
  --M.hotloadTriggered = data.hotloadTriggered
  loadedBankCache = data.loadedBankCache
  levelProjectsCache = data.levelProjectsCache
end

M.onFirstUpdate = onFirstUpdate
M.registerBaseBank = registerBaseBank
M.loadLevelBank = loadLevelBank
M.loadVehicleBank = loadVehicleBank

M.onClientPreStartMission = onClientPreStartMission
M.onClientEndMission = onClientEndMission

M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onFilesChanged = onFilesChanged
M.triggerBankHotloading = triggerBankHotloading
return M
