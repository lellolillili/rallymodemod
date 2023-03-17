-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'gameplay_missions_missions','freeroam_bigMapMode', 'gameplay_missions_clustering'}

local skipIconFading = false
-- detect player velocity
local lastPosition = vec3(0,0,0)
local lastVel
local tmpVec = vec3()
local garageBorderClr = {1,0.5,0.5}
local forceReevaluateOpenPrompt = true

local function getVelocity(dtSim, position)
  --local veh = be:getPlayerVehicle(0)
  --return veh:getVelocity():length()
  lastPosition = lastPosition or position
  lastVel = lastVel or 10

  if dtSim > 0 then
    local vel = (position - lastPosition)
    lastVel = vel:length() / dtSim
  end
  lastPosition = position
  return lastVel
end

local function inverseLerp(min, max, value)
 if math.abs(max - min) < 1e-30 then return min end
 return (value - min) / (max - min)
end
local function depthIdSort(a,b)
  if not a.unlocks or not b.unlocks or a.unlocks.depth == b.unlocks.depth then
    return a.id < b.id
  else
    return a.unlocks.depth < b.unlocks.depth
  end
end

local atParkingSpeed, atParkingSpeedPrev
local parkingSpeedMin, parkingSpeedMax = 5/3.6, 7/3.6
local function getParkingSpeedFactor(playerVelocity)
  if playerVelocity < parkingSpeedMin then atParkingSpeed =  true end
  if playerVelocity > parkingSpeedMax then atParkingSpeed = false end
  if atParkingSpeed == nil    then atParkingSpeed = playerVelocity < parkingSpeedMin end
  local atParkingSpeedChanged = atParkingSpeed ~= atParkingSpeedPrev
  atParkingSpeedPrev = atParkingSpeed
  return clamp(inverseLerp(parkingSpeedMin*1.25, parkingSpeedMin*0.75, playerVelocity),0,1), atParkingSpeed, atParkingSpeedChanged
end

local atCruisingSpeed, atCruisingSpeedPrev
local CruisingSpeedMin, CruisingSpeedMax = 20/3.6, 30/3.6
local function getCruisingSpeedFactor(playerVelocity)
  if playerVelocity < CruisingSpeedMin then atCruisingSpeed =  false end
  if playerVelocity > CruisingSpeedMax then atCruisingSpeed = true end
  if atCruisingSpeed == nil    then atCruisingSpeed = playerVelocity > CruisingSpeedMin end
  local atCruisingSpeedChanged = atCruisingSpeed ~= atCruisingSpeedPrev
  atCruisingSpeedPrev = atCruisingSpeed
  return (atCruisingSpeed and 1 or 0), atCruisingSpeed, atCruisingSpeedChanged
end


local currentCluster = nil

M.formatMission = function(m)
  local info = {
    id = m.id,
    name = m.name,
    description = m.description,
    preview = m.previewFile,
    missionTypeLabel = m.missionTypeLabel or mission.missionType,
    userSettings = m:getUserSettingsData() or {},
    defaultUserSettings = m.defaultUserSettings or {},
    additionalAttributes = {},
    progress = m.saveData.progress,
    currentProgressKey = m.currentProgressKey or m.defaultProgressKey,
    unlocks = m.unlocks,
    hasUserSettingsUnlocked = gameplay_missions_progress.missionHasUserSettingsUnlocked(m.id),
  }
  info.hasUserSettings = #info.userSettings > 0
  local additionalAttributes, additionalAttributesSortedKeys = gameplay_missions_missions.getAdditionalAttributes()

  for _, attKey in ipairs(additionalAttributesSortedKeys) do
    local att = additionalAttributes[attKey]
    local mAttKey = m.additionalAttributes[attKey]
    local val
    if type(mAttKey) == 'string' then
      val = att.valuesByKey[m.additionalAttributes[attKey]]
    elseif type(mAttKey) == 'table' then
      val = m.additionalAttributes[attKey]
    end
    if val then
      table.insert(info.additionalAttributes, {
        icon = att.icon or "",
        labelKey = att.translationKey,
        valueKey = val.translationKey
      })
    end
  end
  for _, customAtt in ipairs(m.customAdditionalAttributes or {}) do
    table.insert(info.additionalAttributes, customAtt)
  end
  info.formattedProgress =  gameplay_missions_progress.formatSaveDataForUi(m.id)
  info.leaderboardKey = m.defaultLeaderboardKey or 'recent'

  --info.gameContextUiButtons = {}
  info.gameContextUiButtons = m.getGameContextUiButtons and m:getGameContextUiButtons()

  return info
end
M.formatDataForUi = function()
  if not M.isStateFreeroam() then return nil end
  local dataToSend = {}
  if not currentCluster then return end
  for _, m in ipairs(currentCluster.elemData or {}) do
    if m.missionId then
      table.insert(dataToSend, M.formatMission(gameplay_missions_missions.getMissionById(m.missionId)))
    end
  end
  table.sort(dataToSend, depthIdSort)
  return dataToSend
end

M.startMissionById = function(id, userSettings)
  local m = gameplay_missions_missions.getMissionById(id)
  if m then
    if m.unlocks.startable then
      gameplay_missions_missionManager.startWithFade(m, userSettings)
      return
    else
      log("E","","Trying to start mission that is not startable due to unlocks: " .. dumps(id))
    end
  else
    log("E","","Trying to start mission with invalid id: " .. dumps(id))
  end

end

M.stopMissionById = function(id)
  for _, m in ipairs(gameplay_missions_missions.get()) do
    if m.id == id then
      gameplay_missions_missionManager.attemptAbandonMissionWithFade(m)
      return
    end
  end
end

M.changeUserSettings = function(id, settings)
  local mission = gameplay_missions_missions.getMissionById(id)
  if not mission then return end
  mission:processUserSettings(settings)
  guihooks.trigger('missionProgressKeyChanged', id, mission.currentProgressKey)
end

local function getGameContext()
  if gameplay_missions_missionManager.getForegroundMissionId() ~= nil then
    local activeMission = nil
    for _, m in ipairs(gameplay_missions_missions.get()) do
      if m.id == gameplay_missions_missionManager.getForegroundMissionId() then
        activeMission = m
      end
    end
    return {context = 'ongoingMission', mission = M.formatMission(activeMission)}
  else

    local missions = M.formatDataForUi()
    if M.isStateFreeroam() and missions and next(missions) then
      return {context = 'availableMissions', missions = missions }
    else
      return {context = 'empty' }
    end
  end
end
M.getGameContext = getGameContext

local lastValidPlayerPosition
local function getPlayerPosition()
  local playerVehicle = be:getPlayerVehicle(0)
  local pos = playerVehicle and playerVehicle:getPosition() or getCameraPosition()
  lastValidPlayerPosition = pos
  return lastValidPlayerPosition
end

local detailPromptOpen = false
local function openViewDetailPrompt(cluster)
  local label = "Cluster"
  local firstMissionIndex = -1
  local missionCount = 0
  local firstPoiIndex = -1

  for i, elem in ipairs(cluster.elemData) do
    if elem.type == "mission" then
      missionCount = missionCount + 1
      firstMissionIndex = i
    end
    if elem.type == 'garagePoint' then
      firstPoiIndex = i
    end
    if elem.type == 'gasStationPoint' then
      firstPoiIndex = i
    end
  end
  local buttons = {}
  local am = false
  if missionCount >= 1 then
    --label = missionCount .. " Missions Here"
    label = {txt = "missions.missions.general.accept.nMissionsHere", context = {n = missionCount}}
    if missionCount == 1 then
      if cluster.elemData[firstMissionIndex].type == "mission" then
        local m = gameplay_missions_missions.getMissionById(cluster.elemData[firstMissionIndex].missionId)
        if m then
          label = m.name
        else
          label = cluster.containedIds[firstMissionIndex]
        end
      else
        label = cluster.containedIds[firstMissionIndex]
      end
    end

    table.insert(buttons, {
        action = "toggleMenues",
        text = "missions.missions.general.accept.viewDetails",
        cmd = "gameplay_missions_missionEnter.onViewMissionDetailsPromptClicked()"
      })

    if cluster.hasType['garagePoint'] then
      table.insert(buttons, {
        action = "oke",
        text = "ui.career.openGarageTitle",
        cmd = "gameplay_missions_missionEnter.onOpenGarageDetailsPromptClicked()"
      })
    end
    if cluster.hasType['gasStationPoint'] then
      table.insert(buttons, {
        action = "oke",
        text = "ui.freeroam.refuel.prompt",
        --cmd = "career_modules_fuel.startTransaction() ui_missionInfo.closeDialogue()"
        cmd = "gameplay_missions_missionEnter.refuelCurrentCarCompletely()"
      })
    end
  else
    label = {txt = cluster.elemData[firstPoiIndex].translationId, context = {}}
    if cluster.hasType['garagePoint'] then
      table.insert(buttons, {
        action = "accept",
        text = "ui.career.openGarageTitle",
        cmd = "gameplay_missions_missionEnter.onOpenGarageDetailsPromptClicked()"
      })
      table.insert(buttons, {
        action = "decline",
        text = "missions.missions.general.accept.close",
        cmd = "gameplay_missions_missionEnter.onCloseViewDetailsPropmptClicked()"
      })
      am = true
    end

    if cluster.hasType['gasStationPoint'] then
      table.insert(buttons, {
        action = "accept",
        text = "ui.freeroam.refuel.prompt",
        --cmd = "career_modules_fuel.startTransaction() ui_missionInfo.closeDialogue()"
        cmd = "gameplay_missions_missionEnter.refuelCurrentCarCompletely()"
      })
      table.insert(buttons, {
        action = "decline",
        text = "missions.missions.general.accept.close",
        cmd = "gameplay_missions_missionEnter.onCloseViewDetailsPropmptClicked()"
      })
      am = true
    end
  end

  local content = {title = label or "", typeName = "", altMode = false, actionMap = am, buttons = buttons }


  ui_missionInfo.openDialogue(content)
  guihooks.trigger("onMissionAvailabilityChanged", {missionCount = missionCount})
  detailPromptOpen = true
end

M.onViewMissionDetailsPromptClicked = function()
  detailPromptOpen = false
  ui_missionInfo.closeDialogue()
  guihooks.trigger('MenuOpenModule','menu.careermission')
end


M.onOpenGarageDetailsPromptClicked = function()
  detailPromptOpen = false
  ui_missionInfo.closeDialogue()
  gameplay_garageMode.start(true)
end

M.refuelCurrentCarCompletely = function()
  local veh = be:getPlayerVehicle(0)
  ui_missionInfo.closeDialogue()
  core_vehicleBridge.requestValue(veh,
    function(ret)
      for _, tank in ipairs(ret[1]) do
        core_vehicleBridge.executeAction(veh,'setEnergyStorageEnergy', tank.name, tank.maxEnergy)
      end
      local msg = {msg = "ui.freeroam.refuel.complete", category = "refuelling", icon = "local_gas_station"}

      guihooks.trigger('Message',msg)
    end
    , 'energyStorage')

end


local function closeViewDetailPrompt(force)
  if detailPromptOpen or force then
    ui_missionInfo.closeDialogue()
    guihooks.trigger("onMissionAvailabilityChanged", {missionCount = 0})
    detailPromptOpen = false
  end
end
M.onCloseViewDetailsPropmptClicked = function()
  closeViewDetailPrompt()
end

local function onUiChangedState(newUIState, prevUIState)
  if newUIState:sub(1, 4) == 'menu' then
    closeViewDetailPrompt()
  end
end

local function defaultLocationCheck(location, level, playerPosition, mission)
  -- fix to obb/sphere collision
  return location.pos and location.radius and playerPosition:distance(location.pos) <= location.radius
end



local markersPerCluster = {}
local function getAllMarkersPerCluster()
  return markersPerCluster
end
M.getAllMarkersPerCluster = getAllMarkersPerCluster

local function getClusterMarker(cluster)
  if not markersPerCluster[cluster.clusterId] then
    local marker = require('lua/ge/extensions/gameplay/missions/markers/playmodeMarker')()
    marker:createObjects()
    local label = "Cluster"
    if #cluster.containedIds > 1 then
      label = #cluster.containedIds .. " Points of Interest"
    else
      if cluster.elemData[1].type == "mission" then
        local m = gameplay_missions_missions.getMissionById(cluster.containedIds[1])
        if m then
          label = m.name
        else
          label = cluster.containedIds[1]
        end
      elseif cluster.hasType['garagePoint'] then
        label = cluster.elemData[1].translationId
      elseif cluster.hasType['spawnPoint'] then
        label = cluster.elemData[1].translationId
      else
        label = cluster.containedIds[1]
      end
    end
    local playModeIconName, bigMapIconName = gameplay_missions_clustering.getIconNamesForCluster(cluster)
    local visibleInPlayMode = cluster.hasType['mission'] or cluster.hasType['garagePoint']
    marker:setup({pos = cluster.pos, radius = cluster.radius, clusterId = cluster.clusterId, label = label, bigMapIconName = bigMapIconName, playModeIconName = playModeIconName, visibleInPlayMode = visibleInPlayMode, cluster = cluster })
    markersPerCluster[cluster.clusterId] = marker
  end
  return markersPerCluster[cluster.clusterId]
end

local updateData = {}
local decals = {}
local visibleIds, visibleIdsSorted = {}, {}
local function displayMissionMarkers(level, dtSim, dtReal)
  profilerPushEvent("MissionMarker precalc")
  local activeMission = gameplay_missions_missionManager.getForegroundMissionId()
  local globalAlpha = 1
  if activeMission then
    globalAlpha = 0
  end
  local camPos = getCameraPosition()
  local playerPosition = getPlayerPosition()
  local playerVelocity = getVelocity(dtSim, playerPosition)

  profilerPushEvent("MissionEnter parkingSpeedFactor")
  local parkingSpeedFactor, isAtParkingSpeed, parkingSpeedChanged = getParkingSpeedFactor(playerVelocity)
  local cruisingSpeedFactor, isAtcruisingSpeed, cruisingSpeedChanged = getCruisingSpeedFactor(playerVelocity)

  profilerPopEvent("MissionEnter parkingSpeedFactor")

  -- put reference for icon manager in
  updateData.playerPosition = playerPosition
  updateData.parkingSpeedFactor = parkingSpeedFactor
  updateData.cruisingSpeedFactor = cruisingSpeedFactor
  updateData.dt = dtReal
  updateData.globalAlpha = globalAlpha
  updateData.camPos = camPos
  updateData.bigMapActive = freeroam_bigMapMode.bigMapActive()
  updateData.bigmapTransitionActive = freeroam_bigMapMode.isTransitionActive()

  table.clear(visibleIds)
  for id, marker in pairs(markersPerCluster) do
    visibleIds[id] = false
  end
  -- hide all the markers behind the camera
  local maxRadius = 100
  profilerPushEvent("MissionEnter QTStuff")
  if freeroam_bigMapMode.bigMapActive() then
    if freeroam_bigMapMode.isTransitionActive() then
      -- transitioning
      local clusterQtData = gameplay_missions_clustering.getClusterAsQuadtree({levelIdentifier = level})
      for id in clusterQtData.quadtree:queryNotNested(playerPosition.x-maxRadius, playerPosition.y-maxRadius, playerPosition.x+maxRadius, playerPosition.y + maxRadius) do
        visibleIds[id] = true
      end
    end
  else
    -- play mode
    local clusterQtData = gameplay_missions_clustering.getClusterAsQuadtree({levelIdentifier = level})
    for id in clusterQtData.quadtree:queryNotNested(camPos.x-maxRadius, camPos.y-maxRadius, camPos.x+maxRadius, camPos.y+maxRadius) do
      visibleIds[id] = true
    end
  end
  if freeroam_bigMapMode.markerToNavigateTo then
    visibleIds[freeroam_bigMapMode.markerToNavigateTo.cluster.clusterId] = true
  end

  profilerPopEvent("MissionEnter QTStuff")
  table.clear(visibleIdsSorted)
  tableKeys(visibleIds, visibleIdsSorted)
  table.sort(visibleIdsSorted)
  profilerPopEvent("MissionEnter precalc")
  if not isAtParkingSpeed then
    currentCluster = nil
  end
  table.clear(decals)
  local decalCount = 0
  -- TODO: optimize
  local clustersById = {}
  for _, c in ipairs(gameplay_missions_clustering.getAllClusters({levelIdentifier = level})) do
    clustersById[c.clusterId] = c
  end
  -- draw/show all visible markers.
  for _, id in ipairs(visibleIdsSorted) do
    local cluster = clustersById[id]
    if cluster then
      local marker = getClusterMarker(cluster)
      if skipIconFading then
        marker:instantFade(visibleIds[id])
      end
      if marker then
        -- Check if the marker should be visible
        local showMarker = false
        -- never show marker if not visible, if in photomode or in editor
        if visibleIds[id] and not photoModeOpen and not editor.active then
          -- always show marker in bigmap mode
          --if freeroam_bigMapMode.bigMapActive() then
          --  showMarker = true
          -- check if marker contains a mission
          if cluster.hasType['mission'] or cluster.hasType['garagePoint'] or cluster.hasType['gasStationPoint'] then
            -- check if "showMissionMarkers" is active or the marker is forced visible
            -- if there is a marker being navigated to, then show only that one
            if ((career_career and career_career.isCareerActive()) or settings.getValue("showMissionMarkers") or marker.forceVisible) and (not freeroam_bigMapMode.markerToNavigateTo == not marker.forceVisible) then
              showMarker = true
            end
          end
        end

        if showMarker then
          -- Show the marker if it's visible and not in photomode and if in play-mode only when it has at least one mission
          if cluster.hasZones then
            marker:hide()
       --     for _, z in ipairs(cluster.zones) do
       --       z:drawDebug(nil, garageBorderClr, 0.25, -0.5, true)
       --     end
          else
            marker:show()
            marker:update(updateData)
          end

          if marker.groundDecalData then
            decalCount = decalCount + 1
            decals[decalCount] = marker.groundDecalData
          end
          if not freeroam_bigMapMode.bigMapActive() and not activeMission then
            if cluster.hasType['mission'] or cluster.hasType['garagePoint'] or cluster.hasType['gasStationPoint'] then
              local openCluster = isAtParkingSpeed and (forceReevaluateOpenPrompt or parkingSpeedChanged)
              if openCluster then
                if cluster.hasZones then
                  local inZone = false
                  local veh = be:getPlayerVehicle(0)
                  if veh then
                    local oobb = veh:getSpawnWorldOOBB()
                    for _, z in ipairs(cluster.zones) do
                      inZone = inZone or (z:containsPoint2D(oobb:getPoint(0)) and z:containsPoint2D(oobb:getPoint(3)) and z:containsPoint2D(oobb:getPoint(4)) and z:containsPoint2D(oobb:getPoint(7)))
                    end
                  end
                  openCluster = inZone
                else
                  openCluster = defaultLocationCheck(cluster, level, playerPosition, nil)
                end
              end
              if openCluster then
                currentCluster = cluster
                openViewDetailPrompt(cluster)
              end
            end
          end
        else
          marker:hide()
        end
      end
    end
  end
  forceReevaluateOpenPrompt = false

  if not activeMission and not currentCluster then
    if not isAtParkingSpeed or parkingSpeedChanged then
      closeViewDetailPrompt(parkingSpeedChanged)
    end
  end
  skipIconFading = false
  Engine.Render.DynamicDecalMgr.addDecals(decals, decalCount)
end

local sendToMinimap = true
local function forceSend() sendToMinimap = true end
M.onClientStartMission = forceSend
M.requestMissionLocationsForMinimap = forceSend

local function sendMissionLocationsToMinimap()
  local send = true
  if not M.isStateFreeroam() or gameplay_missions_missionManager.getForegroundMissionId() then
    send = false
  end
  if send then
    local data = {
      key = 'missions',
      items = {}
    }
    local level = getCurrentLevelIdentifier()
    local i = 1
    for _, cluster in ipairs(gameplay_missions_clustering.getAllClusters({mergeRadius = 20})) do
      if cluster.hasType['mission'] then
        data.items[i] = cluster.pos.x
        data.items[i+1] = cluster.pos.y
        data.items[i+2] = cluster.containedIds
        data.items[i+3] = getIconNamesForCluster(cluster)
        i = i+4
      end
    end
    guihooks.trigger("NavigationStaticMarkers", data)
  else
    M.clearMissionsFromMinimap()
  end
  sendToMinimap = false
end

M.sendMissionLocationsToMinimap = sendMissionLocationsToMinimap
M.clearMissionsFromMinimap = function()
  if getCurrentLevelIdentifier() then
    guihooks.trigger("NavigationStaticMarkers", {key = 'missions', items = {}})
  end
end

M.formatPoiForBigmap = function(elemData)
  return {
    id = elemData.id,
    idInCluster = elemData.idInCluster,
    name = translateLanguage(elemData.translationId, elemData.translationId, true),
    description = elemData.description,
    thumbnailFile = elemData.previews[1],
    previewFiles = elemData.previews,
    type = elemData.type,
    label = '',
    quickTravelAvailable = (elemData.type == 'garagePoint' or elemData.type == 'spawnPoint'),
    quickTravelUnlocked = true,
  }
end

M.formatMissionForBigmap = function(elemData)
  local mission = gameplay_missions_missions.getMissionById(elemData.missionId)
  if mission then
    local ret = {
      id = elemData.missionId,
      clusterId = elemData.clusterId,
      idInCluster = elemData.idInCluster,
      name = translateLanguage(mission.name, mission.name, true),
      label = mission.missionTypeLabel or mission.missionType,
      description = mission.description,
      thumbnailFile = mission.thumbnailFile,
      previewFiles = {mission.previewFile},
      type = "mission",
      difficulty = mission.additionalAttributes.difficulty,
      bigmapCycleProgressKeys = mission.bigmapCycleProgressKeys,
      unlocks = mission.unlocks,
      quickTravelAvailable = true,
      quickTravelUnlocked = gameplay_missions_progress.missionHasQuickTravelUnlocked(elemData.missionId),
      branchTagsSorted = tableKeysSorted(mission.unlocks.branchTags),
      -- these two will show below the mission and will be a context translation.
      aggregatePrimary = {
        --label = {txt = 'Test', context = {}},
        --value = {txt = 'general.onlyValue', context = {value = '99m'}}
      },
      aggregateSecondary = {
        --label = {txt = 'ui.apps.gears.name', context = {}},
        --value = {txt = 'general.onlyValue', context = {value = '12345'}}
      },

      --[[ rating can have different types: attempts, done, new, stars, with context data.
      rating = {type = 'attempts', attempts = 12345}, -- show attempts: 12345 in this case
      --rating = {type = 'stars', stars = 2}, -- show stars: 2 in this case
      --rating = {type = 'done'}, -- show done
      --rating = {type = 'new'}, -- show new
      ]]
    }
    ret.formattedProgress =  gameplay_missions_progress.formatSaveDataForUi(elemData.missionId)
    ret.leaderboardKey = mission.defaultLeaderboardKey or 'recent'


    for key, val in pairs(gameplay_missions_progress.formatSaveDataForBigmap(mission.id) or {}) do
      ret[key] = val
    end
    return ret
  end
  return nil
end



M.sendCurrentLevelMissionsToBigmap = function()
  local data = {poiData = {}, levelData = {}}
  local level = getCurrentLevelIdentifier()
  local missionData = {}
  local playerPos = getCameraPosition()
  local distanceFilter = {
    {25,'close'},
    {100,'medium'},
    {250,'far'},
    {1000,'veryFar'}
  }
  local difficultyValues = {veryLow=0, low=1, medium=2, high=3, veryHigh=4}
  local groupData = {
    rating_new = {label = "Rating: New"},
    rating_locked = {label = "Rating: Locked"},
    rating_attempts = {label = "Rating: Attempted"},
    rating_done = {label = "Rating: Done"},
    type_mission = {label = "Mission"},
    type_spawnPoint = {label = "Quicktravel Points"},
    type_garage = {label = "Garages"},
    type_gasStation = {label = "Gas Stations"},

    distance_veryClose = {label = "Distance: Very Close"},
    distance_close = {label = "Distance: Close"},
    distance_medium = {label = "Distance: Medium"},
    distance_far = {label = "Distance: Far"},
    distance_veryFar = {label = "Distance: Very Far"},
  }

  for _, branch in ipairs(career_branches.getSortedBranches()) do
    groupData["branch_"..branch.id] = {label = "Branch: " .. branch.name}
  end
  for _, diff in pairs(gameplay_missions_missions.getAdditionalAttributes().difficulty.valuesByKey) do
    groupData["difficulty_"..diff.key] = {label = "Difficulty: " ..diff.translationKey}
  end
  for _, v in pairs(gameplay_missions_missions.getAdditionalAttributes().vehicle.valuesByKey) do
    groupData["vehicleUsed_"..v.key] = {label = "Vehicle Used: " .. v.translationKey}
  end
  for _, gr in pairs(groupData) do
    gr.elements = {}
  end


  for _, poi in ipairs(gameplay_missions_clustering.getRawPoiListByLevel(level)) do
    local filterData = {
      groupTags = {},
      sortingValues = {}
    }
        -- distance
    filterData.sortingValues['distance'] = math.max(0,(poi.pos - playerPos):length() - (poi.radius or 0))
    local distLabel = 'veryClose'
    for _, filter in ipairs(distanceFilter) do
      if filterData.sortingValues['distance'] >= filter[1] then
        distLabel = filter[2]
      end
    end
    filterData.groupTags['distance_'..distLabel] = true
    filterData.sortingValues['id'] = poi.id

    if poi.data.type == 'mission' then
      local formatted = M.formatMissionForBigmap(poi.data)
      data.poiData[poi.id] = formatted
      filterData.groupTags['type_mission'] = true

      local mission = gameplay_missions_missions.getMissionById(poi.data.missionId)
      -- general data
      filterData.groupTags['missionType_'..mission.missionTypeLabel] = true
      if not groupData['missionType_'..mission.missionTypeLabel] then
        groupData['missionType_'..mission.missionTypeLabel] = {label = mission.missionTypeLabel, elements = {}}
      end
      if mission.additionalAttributes.difficulty then
        filterData.groupTags['difficulty_'..mission.additionalAttributes.difficulty] = true
        filterData.sortingValues['difficulty'] = difficultyValues[mission.additionalAttributes.difficulty]
      end
      if mission.additionalAttributes.vehicle then
        filterData.groupTags['vehicleUsed_'..mission.additionalAttributes.vehicle] = true
      end
      filterData.sortingValues['depth'] = mission.unlocks.depth

      -- branch data
      for branchKey, _ in pairs(mission.unlocks.branchTags) do
        filterData.groupTags['branch_'..branchKey] = true
      end
      filterData.sortingValues['maxBranchTier'] = mission.unlocks.maxBranchlevel
      filterData.groupTags['maxBranchTier_'..mission.unlocks.maxBranchlevel] = true
      groupData['maxBranchTier_'..mission.unlocks.maxBranchlevel] = {label = 'Tier ' .. mission.unlocks.maxBranchlevel, elements = {}}

      -- custom groups/tags
      if mission.grouping.id ~= "" then
        local gId = 'missionGroup_'..mission.grouping.id
        if not groupData[gId] then groupData[gId] = {elements = {}} end
        if mission.grouping.label ~= "" and groupData[gId].label == nil then
          groupData[gId].label = mission.grouping.label
        end
        filterData.groupTags[gId] = true
      end

      -- progress
      if formatted.rating then
        filterData.groupTags['rating_'..formatted.rating.type] = true
      end
      filterData.sortingValues['starCount'] = formatted.rating.totalStars
      filterData.sortingValues['defaultUnlockedStarCount'] = formatted.rating.defaultUnlockedStarCount
      filterData.sortingValues['totalUnlockedStarCount'] = formatted.rating.totalUnlockedStarCount

    elseif poi.data.type == 'spawnPoint' then
      data.poiData[poi.id] = M.formatPoiForBigmap(poi.data)
      filterData.groupTags['type_spawnPoint'] = true
    elseif poi.data.type == 'garagePoint' then
      data.poiData[poi.id] = M.formatPoiForBigmap(poi.data)
      filterData.groupTags['type_garage'] = true
    elseif poi.data.type == 'gasStationPoint' then
      data.poiData[poi.id] = M.formatPoiForBigmap(poi.data)
      filterData.groupTags['type_gasStation'] = true
    end

    data.poiData[poi.id].filterData = filterData

    for tag, act in pairs(filterData.groupTags) do
      if act then
        if not groupData[tag] then
          log("W","","Unknown group tag: " .. dumps(tag) .. " for poi " .. dumps(poi.id))
          groupData[tag] = {label = tag, elements = {}}
        end
        table.insert(groupData[tag].elements, poi.id)
      end
    end
  end

  for key, gr in pairs(groupData) do
    local elementsAsPois = {}
    for i, id in ipairs(gr.elements) do elementsAsPois[i] = data.poiData[id] end
    table.sort(elementsAsPois,depthIdSort)
    for i, poi in ipairs(elementsAsPois) do gr.elements[i] = elementsAsPois[i].id end
  end

  -- build premade filters

  local filterQuickTravel = {
    key = 'quickTravelPoints',
    icon = 'mission_system_fast_travel',
    groups = {
      groupData['type_spawnPoint']
    }
  }

  local filterGarages = {
    key = 'garagePoints',
    icon = 'mission_system_fast_travel',
    groups = {
      groupData['type_garage']
    }
  }

  local filterDefault = {
    key = 'default',
    icon = 'flag',
    groups = {
      groupData['type_spawnPoint'],
      groupData['type_gasStation'],
    }
  }
  for _, groupKey in ipairs(tableKeysSorted(groupData)) do
    if string.startswith(groupKey,'missionGroup_') then
      table.insert(filterDefault.groups, groupData[groupKey])
    end
  end

  local filterMissionType = {
    key = 'missionTypes',
    icon = 'mission_system_cup',
    groups = {},
  }
  for _, groupKey in ipairs(tableKeysSorted(groupData)) do
    if string.startswith(groupKey,'missionType_') then
      table.insert(filterMissionType.groups, groupData[groupKey])
      table.insert(filterDefault.groups, groupData[groupKey])
    end
  end


  local filterRating = {
    key = 'missionTypes',
    icon = 'mission_system_flag_new',
    groups = {},
  }
  for _, grName in ipairs({'new', 'attempts', 'locked', 'done'}) do
    table.insert(filterRating.groups, groupData['rating_'..grName])
  end


  local filterBranchTag = {
    key = 'branchTag',
    icon = 'flag',
    groups = {
      groupData['type_spawnPoint'],
      groupData['type_garage'],
      groupData['type_gasStation'],
    }
  }
  local branchOrdered = career_branches.orderBranchNamesKeysByBranchOrder()
  for _, grName in ipairs(branchOrdered) do
    if groupData['branch_'..grName] then
      table.insert(filterBranchTag.groups, groupData['branch_'..grName])
    end
  end

  local filterGarageAndQT = {
    key = 'garageAndQT',
    icon = 'mission_system_fast_travel',
    groups = {
      groupData['type_spawnPoint'],
      groupData['type_garage'],
      groupData['type_gasStation'],
    }
  }

  local filterBranchIndividuals = {}
  for _, grName in ipairs(branchOrdered) do
    filterBranchIndividuals[grName] =
      {
        key = 'branchTag',
        icon = 'flag',
        branchIcon = grName,
        groups = {groupData['branch_'..grName]}
      }
  end


  for _, lvl in ipairs(core_levels.getList()) do
    if string.lower(lvl.levelName) == getCurrentLevelIdentifier() then
      data.levelData = lvl
    end
  end

  local allGroupsFilter = {
    key = 'allGroupsTest',
    icon = 'star',
    groups = {}
  }
  for _, grKey in ipairs(tableKeysSorted(groupData)) do
    table.insert(allGroupsFilter.groups, groupData[grKey])
  end
  if career_career and career_career.isCareerActive() then
    data.filterData = {filterBranchTag, filterGarageAndQT}
    for _, grName in ipairs(branchOrdered) do table.insert(data.filterData, filterBranchIndividuals[grName]) end
    --table.insert(data.filterData, allGroupsFilter)
  else
    data.filterData = {filterDefault, filterGarageAndQT, filterMissionType, filterRating}
  end

  guihooks.trigger("BigmapMissionData", data)
end

local pos2Offset = vec3(0, 0, 1000)
local columnColor = ColorF(1,1,1,1)
local function drawDistanceColumn(targetPos)
  local camPos = getCameraPosition()
  local dist = camPos:distance(targetPos)
  local radius = math.max(dist/400, 0.1)
  local targetPos2 = targetPos + pos2Offset
  local alpha = clamp((dist-50)/200, 0, 0.6)
  columnColor.alpha = alpha
  debugDrawer:drawCylinder(targetPos, targetPos2, radius, columnColor)
end

-- gets called only while career mode is enabled
local function onPreRender(dtReal, dtSim)
  if not M.isStateFreeroam() then
    M.removeAllMarkers()
    closeViewDetailPrompt()
    return
  end
  profilerPushEvent("MissionEnter onPreRender")
  profilerPushEvent("MissionEnter groundMarkers")
  -- Disable navigation when player is close to the goal
  if gameplay_missions_missionManager.getForegroundMissionId() == nil and core_groundMarkers.currentlyHasTarget() then
    if freeroam_bigMapMode and not freeroam_bigMapMode.bigMapActive() and type(core_groundMarkers.endWP[1]) == "cdata" then -- is vec3
      drawDistanceColumn(core_groundMarkers.endWP[1])
      if core_groundMarkers.getPathLength() < 10 then
        freeroam_bigMapMode.reachedTarget()
      end
    end
  end
  if freeroam_bigMapMode and freeroam_bigMapMode.reachedTargetPos then
    local veh = be:getPlayerVehicle(0)
    if veh then
      local vehPos = veh:getPosition()
      if vehPos:distance(freeroam_bigMapMode.reachedTargetPos) > 50 then
        freeroam_bigMapMode.resetForceVisible()
      end
    end
  end

  profilerPopEvent("MissionEnter groundMarkers")

  -- check if we've switched level
  local level = getCurrentLevelIdentifier()
  if level then
    if sendToMinimap then
      M.sendMissionLocationsToMinimap()
    end
    profilerPushEvent("DisplayMissionMarkers")
    displayMissionMarkers(level, dtSim, dtReal)
    profilerPopEvent("DisplayMissionMarkers")
  end

  profilerPopEvent("MissionEnter onPreRender")
end

local function removeAllMarkers()
  for _, m in pairs(markersPerCluster) do
    m:clearObjects()
  end
  markersPerCluster = {}
end

local function clearCache()
  removeAllMarkers()
  gameplay_missions_clustering.clear()
end


local function onVehicleSwitched(old, newId)
  local newVehicle = be:getObjectByID(newId)
end


local function skipNextIconFading()
  skipIconFading = true
end

local function showMissionMarkersToggled(active)
  forceSend()
  M.removeAllMarkers()
  closeViewDetailPrompt()
end


-- from UI
local function restartCurrent()
  resetGameplay(0)
  bullettime.pause(false)
end

-- from UI
local function abandonCurrent()
  M.stopMissionById(gameplay_missions_missionManager.getForegroundMissionId())
  bullettime.pause(false)
end

local function onAnyMissionChanged(state)
  forceSend()
  if state == "started" then
    freeroam_bigMapMode.deselect()
    freeroam_bigMapMode.resetForceVisible()
  end
end

M.isStateFreeroam = function()
  if core_gamestate.state and core_gamestate.state.state ~= "freeroam" then
    return false
  end
  return true
end

M.showMissionMarkersToggled = showMissionMarkersToggled

M.restartCurrent = restartCurrent
M.abandonCurrent = abandonCurrent

M.removeAllMarkers = removeAllMarkers
M.skipNextIconFading = skipNextIconFading
M.onPreRender = onPreRender
M.onClientEndMission = removeAllMarkers
M.onSerialize = removeAllMarkers
M.getClusterMarker = getClusterMarker

M.onUiChangedState = onUiChangedState
M.onAnyMissionChanged = onAnyMissionChanged
M.clearCache = clearCache
M.setForceReevaluateOpenPrompt = function() forceReevaluateOpenPrompt = true end
return M