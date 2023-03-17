-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'scenario_scenarios'}

local logTag = 'campaigns'
local campaign = nil

local function getKeyForNextScenario(subsection, scenario)
  if subsection and subsection.locations then
    local entry = subsection.locations[scenario.scenarioKey]
    if scenario and scenario.result and entry.onEvent then
      if not scenario.result.failed and entry.onEvent.onSucceed then
        return entry.onEvent.onSucceed.nextScenario or entry.nextScenario
      elseif scenario.result.failed and entry.onEvent.onFail then
        return entry.onEvent.onFail.nextScenario or entry.nextScenario
      elseif entry.nextScenario then
        return  entry.nextScenario
      end
    end
  end
  return nil
end


local function getOwningSubsection(locationKey)
  local found = nil
  if campaign and campaign.meta.subsections then
    for subsectionKey,subsection in pairs(campaign.meta.subsections) do
      for k,_ in pairs(subsection.locations) do
        if k == locationKey then
          found = subsection
          goto continue
        end
      end
    end
  end

  ::continue::
  return found
end

local function isCampaignOver(scenario)
  if scenario and not scenario.result then
    return false
  end
  local subsection = getOwningSubsection(scenario.scenarioKey)
  local nextScenario = getKeyForNextScenario(subsection, scenario)
  return nextScenario == 'END' or not nextScenario
end

local function getCampaignTitle()
  if campaign then
    return campaign.meta.title;
  end
  return nil
end

local function startScenarioFromKey(key, processedScenario)
  log('D', logTag, 'startScenarioFromKey '..key)

  local ownerSubsection = getOwningSubsection(key)
  if not ownerSubsection then
    log('E', logTag, 'No subsection defines this scenario named '..key)
    return
  end

  local location = ownerSubsection.locations[key]
  if not location then
    log('E', logTag, 'Trying to start undefined scenario '..key)
    return
  end

  if not processedScenario then
    --log('D', logTag, 'campaign scenarioPath: ' .. location.path)
    local scenarioPath = location.path
    processedScenario = scenario_scenariosLoader.loadScenario(scenarioPath, key)
    -- dump(processedScenario)

    if not processedScenario then
      log('E', logTag, 'Campaign is invalid - Cannot find campaign scenario '..tostring(scenarioPath))
      return
    end
  end

  if location.collectables then
    processedScenario.collectables =  location.collectables
  end

  --TODO(AK): Fix this. We should have this passed in and not have to recombine, as its already in this form
  --          in some places that call this function e.g startCampaign
  campaign.state.currentLocation = ownerSubsection.key ..'.'..key
  campaign.state.scenarioKey = key
  campaign.state.activeSubsection = ownerSubsection.key
  --dump(location)

  campaign_exploration.endSubsectionExploration()

  campaign.meta.scenarioName = processedScenario.name
  campaign.meta.scenarioDirectory = processedScenario.directory
  table.insert(campaign.state.scenarioExecutionOrder, processedScenario.name)
  processedScenario.whiteListActions = processedScenario.whiteListActions or {"default_whitelist_campaign"}

  --dump(campaign)
  campaign_campaignsLoader.saveCampaign(campaign)

  processedScenario.useTrailerRespawn = campaign.useTrailerRespawn
  scenario_scenarios.executeScenario(processedScenario)
end

local function stop()
  -- log('I', logTag, 'stop called....')
  if not campaign then
    return
  end

  if campaign_exploration then
    campaign_exploration.stop()
  end

  campaign = nil
end

local function checkRequiredScenarios(subsection, reqData)
  if not subsection then return false end
  if not reqData or not reqData.data or #reqData.data == 0 then return true end

  local locationStatusTable = campaign.state.locationStatus
  local subsectionKey = subsection.key

  local completed = 0
  local numRequired = #reqData.data
  for index = 1, numRequired do
    local locationKey = reqData.data[index]
    local locationData = locationStatusTable[subsectionKey..'.'..locationKey]
    if locationData and (locationData.state == 'completed') then
      completed = completed + 1
    end
  end

  return completed == numRequired
end

local function checkRequiredVehicles(reqData)
  local vid = be:getPlayerVehicleID(0)
  local vehicleData = extractVehicleData(vid)

  for _, vehicle in ipairs(reqData.data) do
    if vehicle.model == vehicleData.model and vehicle.config == vehicleData.config then
      return true
    end
  end

  return false
end

local function canStartScenario(scenarioKey)
  local ownerSubsection = getOwningSubsection(scenarioKey)

  local scenarioData = ownerSubsection and ownerSubsection.locations[scenarioKey]
  if not scenarioData then return false end

  local canStart = true
  for _, reqData in ipairs(scenarioData.requires or {}) do
    if reqData.dataType == "scenarios" then
      canStart = canStart and checkRequiredScenarios(ownerSubsection, reqData)
    end

    if reqData.dataType == "vehicles" then
      canStart = canStart and checkRequiredVehicles(reqData)
    end
  end

  return canStart
end

local function isLocationCompleted(locationKey)
  local locationStatusTable = campaign.state.locationStatus
  local subsection = getOwningSubsection(locationKey)
  local locationStatus = subsection and locationStatusTable[subsection.key..'.'..locationKey]
  return locationStatus and (locationStatus.state == 'completed')
end

local function canImproveResult(locationKey)
  local locationStatusTable = campaign.state.locationStatus
  local subsection = getOwningSubsection(locationKey)
  local locationStatus = subsection and locationStatusTable[subsection.key..'.'..locationKey]
  return locationStatus and locationStatus.medal ~= 'gold'
end

local function execEndCallback()
  if campaign and campaign.meta.endCampaignCallback then
    campaign.meta.endCampaignCallback()
    campaign.meta.endCampaignCallback = nil
  end
end

local function isOverallResultFail()
  -- log('E', logTag, 'isOverallResultFail called....')
  local campaignFailed = false


  return campaignFailed
end

local function isOverallResultPass()
  return not isOverallResultFail()
end

local function displayCampaignSummary()
  -- log('E', logTag, 'displayCampaignSummary called....')

  local summaryHeading = campaign.meta.summaryHeading
  if not summaryHeading then
    log('E', logTag, 'Campaign - '.. campaign.meta.title ..'- is missing summray heading field')
    summaryHeading = '...Summary Heading...'
  end

  local summaryMessage = campaign.meta.summaryMessage
  if not summaryMessage then
    log('E', logTag, 'Campaign - '.. campaign.meta.title ..'- is missing summray message field')
    summaryMessage = '...Summary Message...'
  end

  local stats, playerPoints, maxPoints = statistics_statistics.getSummaryStats(campaign.state.scenarioExecutionOrder)
  local campaignFailed = isOverallResultFail()

  local data = {
                title = campaign.meta.title,
                achievments = {'Not [br] Implemented'},
                summaryHeading = summaryHeading,
                summaryMessage = summaryMessage,
                buttons = {{label = 'Menu', cmd = 'openMenu'}, {label = 'Campaigns', cmd = 'openCampaigns'}},
                overall =
                {
                  community = 20,
                  player= 78,
                  points= playerPoints,
                  maxPoints= maxPoints,
                  failed= campaignFailed
                  },
                  stats = stats
                }
  if campaign.meta.endCampaignCallback then
    data.buttons = {{label = 'Continue', cmd = 'campaign_campaigns.execEndCallback()'}}
  end
  guihooks.trigger('ChangeState', {state = 'chapter-end', params = {stats = data}})
end

local function processCancelScenario()
  local scenario = scenario_scenarios.getScenario()

  if scenario then
    scenario_scenarios.stop()
  end

  local vehicleData = extractVehicleData(vid)
  local spawningData = createPlayerSpawningData(vehicleData.model, vehicleData.config, vehicleData.color, vehicleData.licenseText)
  campaign_exploration.startSubsectionExploration(campaign.state.activeSubsection, nil, spawningData)
end

local function processNextScenario()
  local scenario = scenario_scenarios.getScenario()

  if isCampaignOver(scenario) then
    displayCampaignSummary()
    stop()
    return
  end

  if scenario then
    scenario_scenarios.stop()
  end

  local ownerSubsection = getOwningSubsection(campaign.state.scenarioKey)

  if campaign.state.selectedRewardIndex then
    campaign_rewards.processUserSelection(scenario.scenarioKey, campaign.state.selectedRewardIndex)
  end

  local nextKey = getKeyForNextScenario(ownerSubsection, scenario)

  if campaign_exploration.isValidSubsection(campaign, nextKey) then
    local vid = be:getPlayerVehicleID(0)
    local vehicleData = extractVehicleData(vid)
    local spawningData = createPlayerSpawningData(vehicleData.model, vehicleData.config, vehicleData.color, vehicleData.licenseText)
    local subsection = campaign.meta.subsections[nextKey]
    local locationMarker = subsection.locations[campaign.state.scenarioKey] and subsection.locations[campaign.state.scenarioKey].exitLocation

    campaign.state.scenarioKey = nil

    campaign_exploration.startSubsectionExploration(nextKey, locationMarker, spawningData)
  else
    campaign.state.scenarioKey = nextKey
    if campaign.state.scenarioKey then
      startScenarioFromKey(campaign.state.scenarioKey)
    end
  end
end

local function buildEndScreenButtons(sc, scenarioData)

  if not sc or not scenarioData then return end

  if sc.stats and scenarioData.endOptions then
    sc.stats.buttons = {}

    local defaultToRetry = false
    local defaultContinue = false
    local rewardSelectionRequired = sc.scenarioRewards and sc.scenarioRewards.choices

    if sc.result.failed then
      defaultToRetry = true
    else
      defaultContinue = true
    end

    if tableFindKey(scenarioData.endOptions, "retry") then
      table.insert(sc.stats.buttons, {label='ui.common.retry', cmd='scenario_scenarios.uiEventRetry()',  active = defaultToRetry} )
    end

    if not sc.result.failed and tableFindKey(scenarioData.endOptions, "next") then
      table.insert(sc.stats.buttons, {label='ui.common.next', cmd='campaign_campaigns.uiEventNext()', active = defaultContinue, showLoadingScreen = true, enableOnChooseReward = rewardSelectionRequired} )
    elseif sc.result.failed and tableFindKey(scenarioData.endOptions, "cancel") then
      table.insert(sc.stats.buttons, {label='ui.common.cancel', cmd='campaign_campaigns.uiEventCancel()', active = defaultContinue, showLoadingScreen = true, enableOnChooseReward = rewardSelectionRequired} )
    end

    if tableFindKey(scenarioData.endOptions, "menu") then
      table.insert(sc.stats.buttons, {label='ui.common.menu', cmd='openMenu'} )
    end

    if tableFindKey(scenarioData.endOptions, "freeroam") then
      table.insert(sc.stats.buttons, {label='ui.scenarios.end.freeroam', cmd='scenario_scenarios.uiEventFreeRoam()'} )
    end

    if isCampaignOver(sc) then
      table.insert(sc.stats.buttons, {label='ui.common.finish', cmd='campaign_campaigns.uiEventNext()', showLoadingScreen = false, active = true} )
    end
  end
end

local function processCampaignOnEvent(campaign, onEventData)
  -- log('I', logTag, 'processCampaignOnEvent called...')
  if onEventData and onEventData.inventory then
    core_inventory.processOnEvent(onEventData.inventory)
  end
end

local function processScenarioOnEvent(scenario, onEventData)
  -- log('I', logTag, 'processScenarioOnEvent called...')

  if onEventData and onEventData.inventory then
    core_inventory.processOnEvent(onEventData.inventory, scenario.stats.overall.medal)
  end

  local usingComics = onEventData and onEventData.comic
  if usingComics then
    local controlRefs = (scenario.state == 'post' and 'displayEndUIRefs') or 'displayStartUIRefs'

    scenario[controlRefs] = scenario[controlRefs] + 1
    local comicFinishedCallback = function()
      -- log('I', logTag, 'comicFinishedCallback called...')
      scenario[controlRefs] = scenario[controlRefs] - 1

      if scenario.state == 'post' and scenario.displayEndUIRefs == 0 then
        scenario_scenarios.displayEndUI()
      else
        scenario_scenarios.displayStartUI()
      end
    end

    local locationData = campaign.state.locationStatus[campaign.state.currentLocation]
    local playComic = true --(locationData.attempts > 0 and onEventData.comic.playOnRetry) or (locationData.attempts == 0)
    if playComic then
      campaign_comics.playComic(onEventData.comic, comicFinishedCallback)
    else
      comicFinishedCallback()
    end
  else
    if scenario.state == 'post' and scenario.displayEndUIRefs == 0 then
      scenario_scenarios.displayEndUI()
    else
      scenario_scenarios.displayStartUI()
    end
  end

  if onEventData and onEventData.disableEndUI then
    scenario.endScreenController = function()
        if onEventData.endOptions[1] == "next" then
          M.uiEventNext()
        elseif onEventData.endOptions[1] == "skip" then
          M.uiEventNext()
        elseif onEventData.endOptions[1] == "retry" then
          scenario_scenarios.uiEventRetry()
        end
      end
  end
end

local function scenarioStarted(scenario)
  if not campaign or campaign.meta.scenarioName ~= scenario.name then
    return
  end

  log('D', logTag, 'scenarioStarted called: scenario state '..tostring(scenario.state))
  if scenario.state and scenario.state == 'pre-start' then
    local owningSubsection = getOwningSubsection(campaign.state.scenarioKey)
    local  entry = owningSubsection and owningSubsection.locations[campaign.state.scenarioKey]
    processScenarioOnEvent(scenario, entry.onEvent.onIntro)
  end

  local locationStatus = campaign.state.currentLocation and campaign.state.locationStatus[campaign.state.currentLocation]
  if locationStatus then
    locationStatus.attempts = locationStatus.attempts + 1
  end
end

local function achievementRequirementMet(achievement)
  -- log('D', logTag, 'achievementRequirementMet called...')

  if not achievement.requires then
    return true
  end

  local result = false
  for _,entry in ipairs(achievement.requires) do
    -- dump(entry)
    if entry.dataType and entry.dataType == 'statistics' then
      if entry.data and type(entry.data) == 'string' and entry.data == 'overall_pass' then
        result = result or isOverallResultPass()
      end
    end
  end

  -- log('D', logTag, 'achievementRequirementMet returned '..tostring(result))
  return result
end

local function processCampaignAchievements(player, scenarioResult, scenarioData)
  -- log('D', logTag, 'processCampaignAchievements called...')
  -- dump(scenarioData)
  local data = (not scenarioResult.failed and scenarioData.onEvent.onSucceed) or scenarioData.onEvent.onFail
  if not data or not data.achievements then
    data = {achievements = scenarioData.achievements}
    if not data.achievements then return end
  end

  for _, v in ipairs(data.achievements) do
    if v.key and type(v.key) == 'string' then
      if achievementRequirementMet(v) then
        -- log('D', logTag, 'Unlocking achievement: '..v.key)
        Steam.unlockAchievement(v.key)
      else
        -- log('D', logTag, 'Rquirements not met: '..tostring(v.key))
      end

    else
      log('E', logTag, 'Failed to unlock achievement: '..tostring(v.key))
    end
  end
end

local function markCompleted(subsection,locationKey)
  local locationStatusTable = campaign.state.locationStatus
  local locationStatus = subsection and locationStatusTable[subsection.key..'.'..locationKey]
  if locationStatus then
    locationStatus.state = 'completed'
  end
end

local function scenarioFinished(scenario)
  if not campaign or campaign.meta.scenarioName ~= scenario.name then
    return
  end

  log('D', logTag, 'scenarioFinished called: scenario state '..scenario.state)

  -- if not campaign or campaign.scenario.name ~= scenario.name then
  --   return
  -- end

  if scenario.state == 'post' then
    local ownerSubsection = getOwningSubsection(campaign.state.scenarioKey)
    local scenarioData = ownerSubsection and ownerSubsection.locations[campaign.state.scenarioKey]
    local onEventData = (scenario.result.failed and scenarioData.onEvent.onFail) or (not scenario.result.failed and scenarioData.onEvent.onSucceed)

    local locationStatusTable = campaign.state.locationStatus
    local locationStatus = ownerSubsection and locationStatusTable[ownerSubsection.key..'.'..campaign.state.scenarioKey]

    local stateValue = statistics_statistics.getMedalRanking(locationStatus.medal)
    local medalValue = statistics_statistics.getMedalRanking(scenario.stats.overall.medal)

    if scenarioData.info.subtype ~= 'timeTrial' then
      if locationStatus.state == 'ready' or (stateValue < medalValue) then
        locationStatus.state = (scenario.result.failed and 'failed') or 'completed'
        locationStatus.medal = scenario.stats.overall.medal
      end
    end

    campaign.state.scenarioRewards = campaign_rewards.processRewards(scenario.scenarioKey, scenarioData, scenario.result, scenario.stats.overall.medal)

    if campaign.state.scenarioRewards then
      scenario.scenarioRewards = campaign.state.scenarioRewards
      scenario.scenarioRewards.callback="campaign_campaigns.rewardSelectionCallback"
      campaign.state.selectedRewardIndex = nil
    end

    buildEndScreenButtons(scenario, onEventData)
    processCampaignAchievements(0, scenario.result, scenarioData)
    processScenarioOnEvent(scenario, onEventData)
  end
end

local function rewardSelectionCallback(itemIndex)
  log('I', logTag, 'rewardSelectionCallback call...'..tostring(itemIndex))
  local vehReward = campaign.state.scenarioRewards.choices.vehicles[itemIndex]
  if vehReward then
    campaign.state.selectedRewardIndex = itemIndex
  end
end

local function uiEventCancel()
  log('D', logTag, 'uiEventCancel Triggered: '..campaign.state.scenarioKey)
  guihooks.trigger('MenuHide')
  guihooks.trigger('ChangeState', 'menu')

  processCancelScenario()
end

local function uiEventNext()
  log('D', logTag, 'uiEventNext Triggered: '..campaign.state.scenarioKey)
  guihooks.trigger('MenuHide')
  guihooks.trigger('ChangeState', 'menu')

  processNextScenario()
end

local function uiEventRetry()
end

local function getCampaignActive()
  return campaign and campaign.state.campaignActive
end

local function getCampaign()
  return campaign
end

local function getSubsection(subsectionKey)
  if getCampaignActive() and campaign.meta.subsections then
    return campaign.meta.subsections[subsectionKey]
  end
  return nil
end

local function getActiveSubsection()
  return getSubsection(campaign.state.activeSubsection)
end

local function getLocationData(subsectionKey, locationKey)
  if getCampaignActive() and campaign.meta.subsections and subsectionKey and locationKey then
    return campaign.meta.subsections[subsectionKey].locations and campaign.meta.subsections[subsectionKey].locations[locationKey]
  end
  return nil
end

local function getActiveSubsectionLocationData(locationKey)
  return getLocationData(campaign.state.activeSubsection, locationKey)
end

local function getCurrentLocation()
  if getCampaignActive() then
    return campaign.state.currentLocation
  end
  return nil
end

local function onSerialize()
  -- log('D', logTag, 'onSerialize called...')
  local data = {}

  if getCampaignActive() then
    data = campaign.state
    data.sourceFile = campaign.meta.sourceFile
  end
  -- dump(data)

  return data
end

-- local function onDeserialized(data)
--   -- log('I', logTag, 'onDeserialized called...')
--   -- dump(data)
--   if data.campaignActive then
--     --load the campaign in the data
--     local campaignToStart = loadCampaign(data.sourceFile)
--     -- dump(campaignToStart)
--     campaign = processCampaignStartInternal(campaignToStart)

--     if campaign then
--       campaign.state = data

--       if campaign.state.campaignActive then
--         if campaign.state.scenarioKey and campaign.meta.subsections and campaign.state.activeSubsection then
--           local subsection = campaign.meta.subsections[campaign.state.scenarioKey]
--           local scenarioPath = subsection.locations[campaign.state.scenarioKey].path
--           local scenario = scenario_scenariosLoader.loadScenario(scenarioPath, campaign.state.scenarioKey)
--           if not scenario then
--             log('E', logTag, 'Campaign is invalid - Cannot find campaign scenario '..scenarioPath)
--             return
--           end

--           campaign.meta.scenarioName = scenario.name
--           campaign.meta.scenarioDirectory = scenario.directory
--         end
--       end

--     else
--       log('E', logTag, 'onDeserialized failed, campaign not recreated')
--     end
--   end
-- end

local function isTransitionPoint(subsectionKey, locationKey)
  local locationData = getLocationData(subsectionKey, locationKey)
  return locationData and locationData.info.type == 'site' and locationData.info.subtype == 'transitionPoint'
end

local function isPlayerHQ(subsectionKey, locationKey)
  local locationData = getLocationData(subsectionKey, locationKey)
  return locationData and locationData.info.type == 'site' and locationData.info.subtype == 'playerHQ'
end

local function isMissionGiver(subsectionKey, locationKey)
  local locationData = getLocationData(subsectionKey, locationKey)
  return locationData and locationData.info.type == 'site' and locationData.info.subtype == 'missionGiver'
end

local function isSiteLocation(subsectionKey, locationKey)
  local locationData = getLocationData(subsectionKey, locationKey)
  return locationData and locationData.info.type == 'site'
end

local function isScenarioLocation(subsectionKey, locationKey)
  local locationData = getLocationData(subsectionKey, locationKey)
  return locationData and locationData.info.type ~= 'site' and locationData.info.subtype ~= 'timeTrial'
end

local function isTimeTrialLocation(subsectionKey, locationKey)
  local locationData = getLocationData(subsectionKey, locationKey)
  return locationData and locationData.info.type == 'race' and locationData.info.subtype == 'timeTrial'
end

local function isSubsectionMarker(subsectionKey, markerName)
  local locations = campaign.meta.subsections[subsectionKey].locations
  for key,location in pairs(locations) do
    if location.entryMarker == markerName or location.exitLocation == markerName then
      return true
    end
  end
  return false
end

local function getDefaultVehicle()
  local defaultVehicle = campaign.meta.defaultVehicle or {model=core_vehicles.defaultVehicleModel, color="0.99 0.99 0.99 1.60", config="levels/Utah/scenarios/chapter_2/rusty.pc", licenseText=nil}
  return defaultVehicle
end

local function startExecution()
  local entryTarget = nil
  local subsectionKey = nil
  local startingLocationParts = campaign_campaignsLoader.splitFieldByToken(campaign.state.currentLocation, '.')
  subsectionKey = startingLocationParts[1]
  entryTarget = startingLocationParts[2]

  -- log('I', logTag, 'subsectionKey = '..tostring(subsectionKey) ..' entryTarget: '..tostring(entryTarget))

  if subsectionKey then
    local vehicleData = campaign.state.userVehicle
    -- log('I', logTag, 'campaign.state.userVehicle = '..dumps(campaign.state.userVehicle))

    if not vehicleData then
      local subsectionData = getSubsection(subsectionKey)
      vehicleData = (subsectionData.startSpawningData and subsectionData.startSpawningData.startVehicle) or getDefaultVehicle()
      campaign.state.userVehicle = vehicleData
    end

    local spawningData = createPlayerSpawningData(vehicleData.model, vehicleData.config, vehicleData.color, vehicleData.licenseText)

    -- If we are trying to start a time trial directly, change the entry target to be the starting marker so we go through the correct flow
    if entryTarget and isTimeTrialLocation(subsectionKey, entryTarget) then
      local locationData = getLocationData(subsectionKey, entryTarget)
      entryTarget = locationData.entryMarker
    end

    if not entryTarget or isSubsectionMarker(subsectionKey, entryTarget) then
      campaign_exploration.startSubsectionExploration(subsectionKey, entryTarget, spawningData)
    elseif isSiteLocation(subsectionKey, entryTarget) then
      local locationData = getLocationData(subsectionKey, entryTarget)
      campaign_exploration.startSubsectionExploration(subsectionKey, locationData.entryMarker, spawningData)
    else
      startScenarioFromKey(entryTarget)
    end
  else
      log('E', logTag, 'Starting location format wrong. Correct format is startingLocation = <subsection name> OR <subsection name>.<location name> OR <subsection name>.<entry marker name>')
  end
end

local function startCampaign(newCampaign)
  log('I', logTag, 'startCampaign called...'..tostring(newCampaign.meta.startingLocation))

  if newCampaign and newCampaign.meta.startingLocation then
    campaign = newCampaign
    campaign.state.campaignActive = true
    campaign.state.currentLocation = newCampaign.meta.startingLocation
    if campaign.meta.onEvent then
      processCampaignOnEvent(campaign, campaign.meta.onEvent.onStart or {})
    end

    startExecution()
  end
end

local function onExtensionUnloaded()
  stop()
end

local function onScenarioChange(scenario)
  if not getCampaignActive() then
    extensions.unload("campaign_campaigns")
  end
end

local function resumeCampaign(campaignInProgress, data)
  log('I', logTag, 'resume campaign called.....')
  if data then
    campaign = campaignInProgress
    campaign.state = data
    --dump(campaign.state)
    startExecution()
  end
end

local function getLocationStatusTable()
  return campaign.state.locationStatus
end

local function onSaveCampaign(saveCallback)
  local data = {}
  data = campaign.state
  data.sourceFile = campaign.meta.sourceFile
  saveCallback(M.__globalAlias__, data)
end

local function onResetGameplay(playerID)
  if not getCampaignActive() then return end
  if campaign_exploration.getExplorationActive() then
    be:resetVehicle(playerID)
  end
end

-- public interface
M.markCompleted           = markCompleted
M.rewardSelectionCallback = rewardSelectionCallback
M.isSubsectionMarker      = isSubsectionMarker
M.isTransitionPoint       = isTransitionPoint
M.isMissionGiver          = isMissionGiver
M.isPlayerHQ              = isPlayerHQ
M.isSiteLocation          = isSiteLocation
M.isScenarioLocation      = isScenarioLocation
M.startCampaign           = startCampaign
M.getLocationData         = getLocationData
M.isCampaignOver          = isCampaignOver
M.getCampaign             = getCampaign
M.getCurrentLocation      = getCurrentLocation
M.getCampaignTitle        = getCampaignTitle
M.canStartScenario        = canStartScenario
M.scenarioFinished        = scenarioFinished
M.scenarioStarted         = scenarioStarted
M.stop                    = stop
M.uiEventCancel           = uiEventCancel
M.uiEventNext             = uiEventNext
M.getCampaignActive       = getCampaignActive
M.getActiveSubsectionLocationData       = getActiveSubsectionLocationData
M.getActiveSubsection     = getActiveSubsection
M.getSubsection           = getSubsection
M.isLocationCompleted     = isLocationCompleted
M.canImproveResult        = canImproveResult
M.startScenarioFromKey    = startScenarioFromKey
M.execEndCallback         = execEndCallback
M.onSerialize             = onSerialize
M.onDeserialized          = onDeserialized
M.onExtensionUnloaded     = onExtensionUnloaded
M.onScenarioChange        = onScenarioChange
M.getOwningSubsection     = getOwningSubsection
M.resumeCampaign          = resumeCampaign
M.getLocationStatusTable  = getLocationStatusTable
M.onSaveCampaign          = onSaveCampaign
M.onResetGameplay         = onResetGameplay

return M

