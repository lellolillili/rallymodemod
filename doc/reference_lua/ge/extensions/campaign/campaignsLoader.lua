-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local logTag = 'campaignsLoader'

local M = {}
M.campaignModules   = {'campaign_campaigns', 'campaign_exploration', 'campaign_comics','campaign_rewards', 'campaign_dealer','campaign_photoSafari'}

local scenariosInAllCampaigns = {}

local function loadCampaign(campaignfile)
  -- log('D', logTag, 'loading campaign : ' .. campaignfile)
  --TODO(AK): add code to validate that this campaign is valid
  local campaign = jsonReadFile(campaignfile)
  campaign.sourceFile =  string.gsub(campaignfile, "(.*:)(.*)", "%2")
  campaign.sourcePath = string.gsub(campaignfile, "(.*)/(.*)", "%1")
  campaign.official = isOfficialContentVPath(campaign.sourcePath)
  local index = string.find(campaign.sourcePath, "/[^/]*$") + 1
  -- todo: insert all images of the scenarios belong to this as well
  campaign.previews = {
    imageExistsDefault(campaign.sourcePath..'/'..campaign.sourcePath:sub(index)..'.jpg')
  }

  --dump(campaign)
  return campaign
end


local function getCampaignFilenames()
  if not FS:directoryExists('/campaigns/') then
    return {}
  end
  local campaigns = {}
  local files = FS:findFiles('/campaigns/', '*.json', 1, true, false)
  for k,filename in pairs(files) do
    local fileData = jsonReadFile(filename) or {}
    if fileData.header and fileData.header.type == 'campaign' then
      table.insert(campaigns, filename)
    end
  end
  return campaigns
end

local function getList()
  -- log('D', logTag, 'getList called...')
  local campaignInfofiles = getCampaignFilenames()
  -- dump(campaignInfofiles)
  local campaignList = {}
  for _,campaignfile in pairs(campaignInfofiles) do
    local entry = loadCampaign(campaignfile)
    if entry then
      table.insert(campaignList, entry)
      --dump(entry)
    end
  end
  -- dump(campaignList)
  return campaignList
end

local function getCampaignScenarios()
  return scenariosInAllCampaigns
end

local function isLocationForScenario(campaign, subsectionKey, locationKey)
  -- log('I', logTag, 'isLocationForScenario called ... '..subsectionKey..', '..locationKey)
  if campaign and campaign.meta.subsections then
    local subsection = campaign.meta.subsections[subsectionKey]
    if subsection and subsection.locations[locationKey] then
      local location = subsection.locations[locationKey]
      -- dump(location.path)
      return location.path ~= nil
    end
  end

  return false
end

local function generateCampaignScenariosList()
  local scenariosList = {}

  local campaigns = getList()
  for _,campaign in pairs(campaigns) do
    if campaign.meta.subsections then
      for subsectionKey,subsection in pairs(campaign.meta.subsections) do
        for locationKey,location in pairs(subsection.locations) do
           if isLocationForScenario(campaign, subsectionKey, locationKey) then
            table.insert(scenariosList, location.path)
          end
        end
      end
    end
  end
  return scenariosList
end

local function getIsScenarioRestricted(scenarioFullPath)
  log('D', logTag, 'getIsScenarioRestricted')
  local campaignScenarios = getCampaignScenarios()
  for _,path in pairs(campaignScenarios) do
    if scenarioFullPath == path then
      return true
    end
  end
  return false
end

local function splitFieldByToken(field, token)
  --log('D', logTag, 'splitFieldByToken called...')
  --log('D', logTag, 'field: '..tostring(field))
  --log('D', logTag, 'token: '..tostring(token))

  local fieldParts = {}
  local pattern = "([^"..token..".]+)"
  for part in field:gmatch(pattern) do
    table.insert(fieldParts, part)
  end
  --dump(fieldParts)
  return fieldParts
end

local function validate(newCampaign)
  --log('I', logTag, 'Validating campaign...')
  --check has the minimum fields
  ---title
  ---summaryHeading
  ---summaryMessage
  ---1. scenarios
  ---2. startingLocation is valid

  --if campaign has subsections, make sure
  ---1. locations field is valid
  ---2. triggers field is valid - prefab exists
  if not newCampaign.meta.title then
    newCampaign.meta.title = '<missing title>'
  end

  newCampaign.meta.subsections = newCampaign.meta.subsections or {}
  --Validate the starting location if not in section, patch to one
  -- newCampaign.meta.startingLocation = newCampaign.meta.startingLocation or newCampaign.meta.startingScenario

  for k,subsection in pairs(newCampaign.meta.subsections) do
    subsection.locations = subsection.locations or {}
    for locationKey, locationData in pairs(subsection.locations) do
      locationData.info = locationData.info or {}

      if not locationData.info.title then
        locationData.info.title = locationData.title or '<missing title>'
        locationData.title = nil
      end

      if not locationData.info.description then
        locationData.info.description = locationData.description
        locationData.description = nil
      end

      locationData.info.typeName = locationData.info.typeName or 'ui.mission.type.race'
      locationData.info.type = locationData.info.type or 'race'
      local typeParts = splitFieldByToken(locationData.info.type, '.')
      locationData.info.type = typeParts[1]
      locationData.info.subtype = typeParts[2]

      locationData.onEvent = locationData.onEvent or {}
      for eventKey, eventData in pairs(locationData.onEvent) do
        if eventData.disableEndUI then
          if not eventData.endOptions or #eventData.endOptions ~= 1 then
            eventData.disableEndUI = false
            eventData.endOptions = nil
            log('E', logTag, 'Location '..locationKey..". Required endOptionsShould with only 1 entry")
          end
        end
      end

      --dump(locationData)
    end
  end

  --log('I', logTag, 'Validation done...')
  return true
end

local function processCampaignStartInternal(newCampaign, endCallback)
  -- log('D', logTag, 'processCampaignStartInternal called...')
  if not newCampaign then
   log('E', logTag, 'can not process a campaign that is NULL')
   return
  end

  -- TODO(AK): need a way to check if a module is loaded and use it
  -- or will the unloading of all modules be sufficient?
  if campaign then
    stop()
  end

  newCampaign.endCampaignCallback = endCallback

  local processedCampaign = {meta = newCampaign, state = {}}
  -- dump(processedCampaign)

  if not validate(processedCampaign) then
    log('E', logTag, 'campaign ' .. processedCampaign.meta.title .. 'is not fully valid due to missing data.')
    return
  end

  processedCampaign.state.scenarioExecutionOrder = {}
  processedCampaign.state.locationStatus = {}

  if processedCampaign.meta.subsections then
    local statusTable = processedCampaign.state.locationStatus
    for subsectionKey,subsection in pairs(processedCampaign.meta.subsections) do
      subsection.key = subsectionKey
      for locationKey,location in pairs(subsection.locations) do
          statusTable[subsectionKey..'.'..locationKey] = {attempts = 0, state = 'ready', medal=''}
      end
    end
  end

  -- dump(campaign)
  return processedCampaign
end

-- this function is called when the user selects a campaign to play from the UI
local function start(newCampaign, endCallback)
  log('D', logTag, 'starting a campaign')

  -- this is to prevent bug where campaign is started while a different level is still loaded.
  -- Loading the first scenario in the campaign causes the current loaded level to unload which breaks the campaign.
  if scenetree.MissionGroup then
    log('D', logTag, 'Delaying start of campaign until current level is unloaded...')
    M.triggerDelayedStart = function()
      log('D', logTag, 'Triggering a delayed start of campaign...')
      M.triggerDelayedStart = nil
      start(newCampaign, endCallback)
    end

    endActiveGameMode(M.triggerDelayedStart)
  else
    loadGameModeModules(scenario_scenariosLoader.scenarioModules, scenario_quickRaceLoader.quickRaceModules, M.campaignModules)

    local processedCampaign = processCampaignStartInternal(newCampaign, endCallback)

    -- Auto load a campaign in progress
    local campaignSaveFilename = campaign_campaignsLoader.checkSaveExists(processedCampaign.meta.title, processedCampaign.meta.enableSaves)
    --log('I', logTag, 'Found saved campaign: '..tostring(campaignSaveFilename))

    if campaignSaveFilename then
      campaign_campaignsLoader.resumeSavedCampaign(processedCampaign, campaignSaveFilename)
    else
      campaign_campaigns.startCampaign(processedCampaign)
    end
  end
end

local function startByFolder(path, endCallback)
  local campaignList = getList()
  for _,camp in ipairs(campaignList) do
    if camp.sourcePath == path then
      campaign_campaigns.start(camp, endCallback)
      return
    end
  end
end

local function getCampaignSaveInfo()
  --log('I', logTag, 'getCampaignSaveInfo called....')

  -- Make sure save directory for the campaigns exists
  if not FS:directoryExists("saves/campaigns/") then FS:directoryCreate("saves/campaigns/") end

  local savesFiles = {}
  local files = FS:findFiles('/saves/campaigns/', '*.json', 1, true, false)
  --dump(files)

  for k,filename in pairs(files) do
    local fileData = jsonReadFile(filename) or {}
    if fileData.header and fileData.header.type == 'campaignSave' then
      table.insert(savesFiles, {filename = filename, title = fileData.header.title})
    end
  end
  return savesFiles
end

local function checkSaveExists(title, savesEnabled)
  --log('I', logTag, 'checkSaveExists called....Title: '..title..' savesEnabled: '..tostring(savesEnabled))

  if savesEnabled and title then
    local saveInfo = getCampaignSaveInfo()
    for k,entry in pairs(saveInfo) do
      if entry.title == title then
        return entry.filename;
      end
    end
  end

  return nil
end

local function getFreeSaveFilename()
  local saveInfos = getCampaignSaveInfo()
  local fileCount = 0
  if saveInfos then
    fileCount = #saveInfos
  end
  return 'slot'..fileCount..'.json'
end

local function AddSaveDataCallback(moduleKey, data)
  -- do all the verification here
  if not moduleKey then
    return
  end

  local next = next
  if not data or next(data) == nil then
    return
  end
  local saveDataTable = M.saveDataTable
  saveDataTable[moduleKey] = data
end

local function saveCampaign(campaign)
  log('I', logTag, 'saving campaign json file: '..tostring(campaign.meta.enableSaves))

  if campaign.meta.enableSaves then
    local filename = campaign_campaignsLoader.checkSaveExists(campaign.meta.title, campaign.meta.enableSaves)

    if not filename then
      filename = '/saves/campaigns/'..getFreeSaveFilename()
    end

    M.saveDataTable = {}
    extensions.hook("onSaveCampaign", AddSaveDataCallback)
    M.saveDataTable.header = {version = 1, type = 'campaignSave', title = campaign.meta.title}
    jsonWriteFile(filename, M.saveDataTable, true)
    M.saveDataTable = nil
  end
end

local function resumeSavedCampaign(campaign, saveFilename)
  log('I', logTag, 'resuming saved campaign from json file: '..saveFilename)
  -- TODO(AK): Look into the use of global _G. Once system is up and running, confirm if there is a better approach
  local savedData = jsonReadFile(saveFilename)
  for name,data in pairs(savedData) do
    if name ~= 'campaign_campaigns' then
      if _G[name] and type(_G[name].onResumeCampaign) == 'function' then
        _G[name].onResumeCampaign(campaign, data)
      end
    end
  end

  _G['campaign_campaigns'].resumeCampaign(campaign, savedData['campaign_campaigns'])
end

-- public interface
M.getCampaignFilenames  = getCampaignFilenames
M.getList               = getList
M.getCampaignScenarios  = getCampaignScenarios
M.onInit                = onInit
M.start                 = start
M.startByFolder         = startByFolder
M.splitFieldByToken     = splitFieldByToken
M.checkSaveExists       = checkSaveExists
M.saveCampaign          = saveCampaign
M.resumeSavedCampaign   = resumeSavedCampaign
return M

