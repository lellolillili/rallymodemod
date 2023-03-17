-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'statistics'

local helper = require('scenario/scenariohelper')

local statsTable = {}
local scenarioStats = {}

local statsProperties = {}

local function reset()
  scenarioStats = {}
end

local function clamp(value, minValue, maxValue )
  minValue = minValue or 0
  maxValue = maxValue or 1
  return math.max(math.min(value, math.max(minValue, maxValue)), math.min(minValue, maxValue))
end

local function getStatKey(statName)
  return 'stat_'..statName
end

local function getGoalKey(goalName)
  return 'goal_'..goalName
end

local function enableStatisticTracking(vehicleID, statisticName)
  local vehicleTable = statsTable[vehicleID]
  local statEntry = nil

  local key = getStatKey(statisticName)

  if vehicleTable then
    statEntry = vehicleTable[key]
  end

  if not statEntry then
   return
  end

  statEntry.enabled = true

  for _, instance in pairs(statEntry.instances) do
    local vehicle = nil
    if instance.source then
      vehicle = scenetree.findObject(instance.source)
    else
      vehicle = be:getObjectByID(vehicleID)
    end

    if key == getStatKey('altitude') then
      statEntry.initialZPos = vehicle:getPosition().z
    elseif key == getStatKey('distance') then
      statEntry.initialPos = vehicle:getPosition()
    end
  end
end

local function disableStatisticTracking(vehicleID, statisticName)
  local vehicleTable = statsTable[vehicleID]
  local key = getStatKey(statisticName)

  if vehicleTable and vehicleTable[key]then
     vehicleTable[key].enabled = false
  end
end

local function getGoalAlias(goalId)
  local result = nil

  if statsProperties and statsProperties.alias then
    result = statsProperties.alias[goalId]
  end
  if not result then
    if goalId == 'nomove' then
      result = 'ui.goals.' .. goalId
    elseif goalId == 'wayPointAction' then
      result = 'ui.goals.' .. goalId
    elseif goalId == 'timeLimit' then
      result = 'ui.goals.' .. goalId
    elseif goalId == 'position' then
      result = 'ui.goals.' .. goalId
    elseif goalId == 'distance' then
      result = 'ui.goals.' .. goalId
    elseif goalId == 'speed' then
      result = 'ui.goals.' .. goalId
    elseif goalId == 'damage' then
      result = 'ui.goals.' .. goalId
    elseif goalId == 'finishRace' then
      result = 'ui.goals.' .. goalId
    else
      -- TODO check if this case exists and remove the whole if statement
      result = goalId
    end
  end
  return result
end

local function getScenarioOverallStat(scenario)
  local entry = scenarioStats[scenario.name]
  if not entry then
    return {}
  end

  return entry
end

local function getVehicleStat(vehicleID)
  local statsData = {}

  local vehicleTable = statsTable[vehicleID]
  if not vehicleTable then
    return
  end

  log('D', logTag, 'getVehicleStat called...')
  --dump(vehicleTable)

  for dataKey,data in pairs(vehicleTable) do
    local entry = {}
    -- dump(data)
    entry.label = data.label
    entry.decimals = data.decimals
    entry.predefinedUnit = data.predefinedUnit
    entry.unit = data.unit
    entry.required = data.required
    entry.failed = data.failed

    local points = nil
    local maxPoints = nil
    local value = nil
    local maxValue = nil
    if data.instances then
      for _,instance in pairs(data.instances) do
        if instance.maxPoints and instance.maxPoints  ~= 0 then
          if maxPoints then
            maxPoints = maxPoints + instance.maxPoints
          else
            maxPoints = instance.maxPoints
          end
        end

        if instance.points then
          if points then
            points = points + instance.points
          else
            points = instance.points
          end
        end

        if instance.value then
          value = (value or 0) + instance.value
        end

        if instance.maxValue then
          maxValue = (maxValue or 0) + instance.maxValue
        end

        if instance.failed then
          entry.failed = true
        end

        if instance.required then
          entry.required = true
        end
      end
    end

    if entry.predefinedUnit == '%' and maxValue and maxValue ~= 0 then
      value = (value / maxValue) * 100
    end

    entry.value = value
    entry.points = points
    entry.maxPoints = maxPoints
    if points and maxPoints then
      entry.relativePoints = (points / maxPoints) * 100
    end

    table.insert(statsData, entry)
  end
  return statsData
end

local function getSummaryStats(statsOrder)
  local overallStats = {}
  local playerPoints = 0
  local totalMaxPoints = 0
  for _, entryName in pairs(statsOrder) do
    local data = scenarioStats[entryName]
    playerPoints = playerPoints + data.points
    totalMaxPoints = totalMaxPoints + data.maxPoints
    if data.points and data.maxPoints > 0 then
      data.relativePoints = (data.points / data.maxPoints) * 100
    else
      data.relativePoints = 0
    end

    table.insert(overallStats, data)
  end
  return overallStats, playerPoints ,totalMaxPoints
end

local function setGoalProgress(vehicleID, goalName, instanceId, goalData)
  local vehicleTable = statsTable[vehicleID]
  if not vehicleTable then
    return
  end

  local key = getGoalKey(goalName)
  local goal = vehicleTable[key]

  if not goal then
    local goalAlias = getGoalAlias(goalName)
    goal = {label=goalAlias, instances = {}, required = true, failed=false, isGoal = true}
    vehicleTable[key] = goal
  end

  if not goal.instances[instanceId] then
    goal.instances[instanceId] = {}
  end
  goal.instances[instanceId].points = goalData.points
  goal.instances[instanceId].maxPoints = goalData.maxPoints

  if goalData.status == 'failed' then
      goal.instances[instanceId].failed = true
  else
      goal.instances[instanceId].failed = false
  end
end

local function setStatProgress(vehicleID, statName, instanceId, statData)

  if not instanceId or not statData then
    return
  end

  if statData and type(statData) ~= 'table' then
    return
  end

  if statData.isGoal == nil then
    statData.isGoal = false
  end

  -- log('D','statistics', 'setStatProgress called '..vehicleID ..','..statName..','..instanceId..','..dumps(statData))

  local vehicleTable = statsTable[vehicleID]
  if not vehicleTable then
    vehicleTable = {}
    statsTable[vehicleID] = vehicleTable
  end
  local key = getStatKey(statName)
  local statEntry = vehicleTable[key]
  if not statEntry then
    statEntry = {instances = {}}
    vehicleTable[key] = statEntry
  end

    local instance = statEntry.instances[instanceId]
    if not instance then
      instance = {}
      statEntry.instances[instanceId] = instance
    end

      local ignoreInstanceFields = {'decimals', 'enabled', 'label', 'predefinedUnit', 'unit', 'isGoal'}

      for _, fieldName in ipairs(ignoreInstanceFields) do
        if statData[fieldName] ~= nil then
          -- log('D','statistics', 'statData['..fieldName..'] = '..dumps(statData[fieldName]))
          statEntry[fieldName] = statData[fieldName]
        end
      end

       for k,v in pairs(statData) do
          if not tableFindKey(ignoreInstanceFields, k) then
            instance[k] = v
          end
      end
end

local function initialiseAltitudeStat(vehicle, vehicleName)
  local vehicleID = vehicle:getID()
  local altitudeProperties = statsProperties['altitude']
  if not altitudeProperties then
    altitudeProperties = {}
  end

  if #altitudeProperties > 0 then
    for i,entry in ipairs(altitudeProperties) do
      -- dump(entry)
      if entry.target == vehicleName then
        local altitudeSource = entry.source or vehicleName
        local altitudeData = {label='ui.stats.altitude',  initialZPos=0, value=0.0, decimals=2, enabled = true, source=altitudeSource}
        altitudeData.maxValue = entry.maxValue
        altitudeData.maxPoints = entry.maxPoints
        setStatProgress(vehicleID, 'altitude', altitudeSource, altitudeData)
      end
    end
  else
   local altitudeSource = altitudeProperties.source or vehicleName
    local altitudeData = {label='ui.stats.altitude',  initialZPos=0, value=0.0, decimals=2, enabled = true, source=altitudeSource}
    altitudeData.maxPoints = altitudeProperties.maxPoints
    altitudeData.maxValue = altitudeProperties.maxValue
    setStatProgress(vehicleID, 'altitude', altitudeSource, altitudeData)
  end
end

local function initialiseDamageStat(vehicle, vehicleName)
  local vehicleID = vehicle:getID()

  local damageProperties = statsProperties['damage']
  if not damageProperties then
    damageProperties = {}
  end
  -- log('D', logTag, vehicleName ..': Damage type: '..type(statsProperties['damage']) ..' Size: '..#damageProperties)

  -- multiple entries present (an array)
  if #damageProperties > 0 then
    for i,entry in ipairs(damageProperties) do
      -- log('D',logTag, 'damage count: ' .. i)
      -- dump(entry)
      if entry.target == vehicleName then
        local damageSource = entry.source or vehicleName
        local damageData = {label='ui.stats.damage', value=0.0, decimals=1, predefinedUnit="%", enabled = true, source=damageSource}
        damageData.maxValue = entry.maxValue
        damageData.maxPoints = entry.maxPoints
        damageData.required = entry.required
        setStatProgress(vehicleID, 'damage', damageSource, damageData)
      end
    end
  else
    local damageSource = damageProperties.source or vehicleName
    local damageData = {label='ui.stats.damage', value=0.0, decimals=1, predefinedUnit="%", enabled = true, source=damageSource}
    damageData.maxValue = damageProperties.maxValue
    damageData.maxPoints = damageProperties.maxPoints
    damageData.required = damageProperties.required
    setStatProgress(vehicleID, 'damage', damageSource, damageData)
  end
end

local function initialiseDistanceStat(vehicle, vehicleName)
  -- log('A',logTag,'initialiseDistanceStat called...')

  local vehicleID = vehicle:getID()
  local distanceProperties = statsProperties['distance']
  if not distanceProperties then
    distanceProperties = {}
  end

  if #distanceProperties > 0 then
    for i,entry in ipairs(distanceProperties) do
      -- dump(entry)
      if entry.target == vehicleName then
        local distanceSource = entry.source or vehicleName
        local distanceData = {label='ui.stats.distance', initialPos=vec3(0,0,0), value=0.0, decimals=2, enabled=true, source=distanceSource}
        distanceData.maxValue = entry.maxValue
        distanceData.maxPoints = entry.maxPoints
        setStatProgress(vehicleID, 'distance', distanceSource, distanceData)
      end
    end
  else
   local distanceSource = distanceProperties.source or vehicleName
    local distanceData = {label='ui.stats.distance', initialPos=vec3(0,0,0), value=0.0, decimals=2, enabled=true, source=distanceSource}
    distanceData.maxPoints = distanceProperties.maxPoints
    distanceData.maxValue = distanceProperties.maxValue
    setStatProgress(vehicleID, 'distance', distanceSource, distanceData)
  end
  -- dump(statsTable[vehicleID] )
end

local function initialiseGoalStat(vehicle, vehicleName)
  if scenario_scenarios.getScenario().goals then
    local vehicleID = vehicle:getID()
    local vehicleTable = statsTable[vehicleID] --or {}
    local goalVehicles = scenario_scenarios.getScenario().goals.vehicles or {}
    for _, goal in pairs(goalVehicles) do
      if goal.id ~= 'wayPointAction' then
        local goalAlias = getGoalAlias(goal.id)
        local maxPoints = 0.0
        if statsProperties and statsProperties[goal.id] then
          maxPoints = statsProperties[goal.id].maxPoints or 0
        end

        local playerVid = be:getPlayerVehicleID(0)
        if goal.vId == vehicleID or (goal.id == 'nomove' and vehicleID == playerVid and not goal.value.triggerEndOnly) then
           setGoalProgress(vehicleID, goal.id, goal.vId, {status='init', maxPoints=nil})
        end
      end
    end
  end
end

local function initialiseArbitraryStat(statName, statLabel, vehicle, vehicleName, maxPoints, maxValue)
  local data = {label=statLabel, value=0.0, decimals=2, unit=nil, enabled = true, source=vehicleName}
  data.maxPoints = maxPoints
  data.maxValue = maxValue
  setStatProgress(vehicle:getID(), statName, vehicleName, data)
end

local function initialiseSpeedStat(vehicle, vehicleName)
  local vehicleID = vehicle:getID()
  local speedProperties = statsProperties['speed']
  if not speedProperties then
    speedProperties = {}
  end

  if #speedProperties > 0 then
    for i,entry in ipairs(speedProperties) do
      -- dump(entry)
      if entry.target == vehicleName then
        local speedSource = entry.source or vehicleName
        local speedData = {label='ui.stats.maxSpeed', value=0.0, decimals=2, unit='speed', enabled = true, source=speedSource}
        speedData.maxValue = entry.maxValue
        speedData.maxPoints = entry.maxPoints
        setStatProgress(vehicleID, 'speed', speedSource, speedData)
      end
    end
  else
    local speedSource = speedProperties.source or vehicleName
    local speedData = {label='ui.stats.maxSpeed', value=0.0, decimals=2, unit='speed', enabled = true, source=speedSource}
    speedData.maxPoints = speedProperties.maxPoints
    speedData.maxValue = speedProperties.maxValue
    setStatProgress(vehicleID, 'speed', speedSource, speedData)
  end
end

local function initialiseTimeStat(vehicle, vehicleName)
  local vehicleID = vehicle:getID()
  local timeProperties = statsProperties['time']
  if not timeProperties then
    timeProperties = {}
  end

  if #timeProperties > 0 then
    for i,entry in ipairs(timeProperties) do
      if entry.target == vehicleName then
        local timeSource = entry.source or vehicleName
        local timeData = {label='ui.stats.time', value=0.0, predefinedUnit = 's', decimals=2, enabled = true, source=timeSource}
        timeData.maxPoints = timeProperties.maxPoints
        timeData.best = timeProperties.best
        timeData.worst = timeProperties.worst

        if timeData.best and timeData.worst and timeData.worst < timeData.best then
          local temp = timeData.worst
          timeData.worst = timeData.best
          timeData.best = temp
        end

        setStatProgress(vehicleID, 'time', timeSource, timeData)
      end
    end
  else
    local timeSource = timeProperties.source or vehicleName
    local timeData = {label='ui.stats.time', value=0.0, predefinedUnit = 's', decimals=2, enabled = true, source=timeSource}
    timeData.maxPoints = timeProperties.maxPoints
    timeData.best = timeProperties.best
    timeData.worst = timeProperties.worst

    if timeData.best and timeData.worst and timeData.worst < timeData.best then
      local temp = timeData.worst
      timeData.worst = timeData.best
      timeData.best = temp
    end

    setStatProgress(vehicleID, 'time', timeSource, timeData)
  end
end

local function initialiseTables(scenario)
  log('D', logTag, 'initialiseTables called...')

  if not scenario then
    log('E', logTag, 'Scenario is null')
    return
  end

  statsProperties = scenario.statistics or  {}
  scenarioStats[scenario.name] = {label=scenario.name, player=0, community=0, failed=false, points=0, maxPoints=0}

  statsTable = {}

  local vehicles = scenetree.findClassObjects('BeamNGVehicle')
  if not vehicles then
    log('E', logTag, 'initialiseTables: No Vehicles found')
    return
  end

  for _, vehicleName in pairs(vehicles) do
    if not map.objectNames[vehicleName] or not map.objects[map.objectNames[vehicleName]] then
      helper.trackVehicle(vehicleName, vehicleName)
    end

    local vehicle = scenetree.findObject(vehicleName)
    if vehicle then
      initialiseDistanceStat(vehicle, vehicleName)
      initialiseAltitudeStat(vehicle, vehicleName)
      initialiseSpeedStat(vehicle, vehicleName)
      initialiseGoalStat(vehicle, vehicleName)
      initialiseDamageStat(vehicle, vehicleName)
      initialiseTimeStat(vehicle, vehicleName)

      -- dump(statsTable[vehicle:getID()])
    end
  end
end

local function calculateStatPoints(key, statData)
  log('A', logTag, 'calculateStatPoints called '.. key ..': ')

  if not statData then
    return 0
  end

  local points = nil

  for _,instance in pairs(statData.instances) do
    if statData.enabled then
      if statData.isGoal then
        if instance.failed ~= true then
          instance.points = instance.maxPoints
        end
      else
        if instance.value then
          if instance.maxValue  and instance.maxValue > 0 and instance.maxPoints then
            if (instance.maxPoints > 0) or (instance.maxPoints < 0 and instance.value > 0) then
              instance.points = (instance.value / instance.maxValue) * instance.maxPoints
            end
          elseif instance.best and instance.worst and instance.maxPoints then
            local range = instance.worst - instance.best
            if range > 0 then
              local value = clamp(instance.value, instance.best, instance.worst)
              local remainder = range - (value - instance.best)
              instance.points = (remainder / range) * instance.maxPoints
            end
          end

          -- Quick fix for cases where a single stat is relevant and user scores zero meaning it will get filtered out
          if instance.required and instance.points and instance.maxPoints and instance.maxPoints > 0 and  instance.points == 0 then
            instance.failed = true
          end
        end
      end
    end

    if instance.points and instance.maxPoints then
      instance.points = clamp(instance.points, -instance.maxPoints, instance.maxPoints)
      instance.points = math.floor(instance.points)
      points = (points or 0) + instance.points
    end
  end

  return points
end

local function calculatePoints(scenario, vehicleID)
  -- log('D', logTag, 'calculatePoints called... ')
  local vehicleTable = statsTable[vehicleID]
  if not vehicleTable then
    log('E', logTag, 'Vehicle not found in stats table: vehicleID = '..tostring(vehicleID))
    return 0,0
  end

  local playerPoints = 0
  local totalMaxPoints = 0
  for key, statsData in pairs(vehicleTable) do
    local statPoints = calculateStatPoints(key, statsData)
    if statPoints then
      playerPoints = playerPoints + statPoints
    end
    for _, instance in pairs(statsData.instances) do
      if instance.maxPoints and instance.maxPoints > 0 then
        totalMaxPoints = totalMaxPoints + instance.maxPoints
      end
    end
  end

  --log('D', logTag, 'Points Calculated: '..playerPoints..' totalMaxPoints: '..totalMaxPoints)
  playerPoints = clamp(playerPoints, 0, totalMaxPoints)

  return playerPoints,totalMaxPoints
end

local function getMedalRanking(medalString)
  local rank = -1

  if medalString == 'wood' then
    rank = 0
  elseif medalString == 'bronze' then
    rank = 1
  elseif medalString == 'silver' then
    rank = 2
  elseif medalString == 'gold' then
    rank = 3
  end

  return rank
end

local function fillScenarioOverallStats(scenario, vehicleID, playerPoints, maxPoints)
  if not scenario then
    return
  end

 local entry = scenarioStats[scenario.name]
 if not entry then
  log('E', logTag, 'Scenario stats missing entry for '.. scenario.name)
  return
 end

 entry.label = scenario.name
 entry.player = playerPoints
 --entry.community = 0
 entry.points = playerPoints
 entry.maxPoints = maxPoints
 entry.decimals = 1

 if scenario.result.failed then
  entry.failed = true
 else
  entry.failed = false
 end

 local overall = statsProperties.overall or {goldCutoff=90, silverCutoff=70, bronzeCutoff=0}

  if entry.failed then
    entry.medal = 'wood'
  else
    local scorePerctage = (playerPoints / maxPoints) * 100;
    if scorePerctage >= overall.goldCutoff or maxPoints == 0 then
      entry.medal = 'gold'
    elseif scorePerctage >= overall.silverCutoff then
      entry.medal = 'silver'
    elseif scorePerctage >= overall.bronzeCutoff then
      entry.medal = 'bronze'
    else
      entry.medal = 'wood'
    end
  end
end

local function stopStatsGathering(scenario)
  for vehicleID, vehicleTable in pairs(statsTable) do
    local data = vehicleTable[getStatKey('distance')]
    local value = 0
    if data and data.enabled then
        -- 1 mile = 1609.34 meters
      for _,instance in pairs(data.instances) do
        value = value + (instance.value or 0)
      end
      if value < 1609.34 then
        data.predefinedUnit = 'm'
        data.unit = nil
      else
        data.unit='distance'
        data.predefinedUnit = nil
      end
    end

    data = vehicleTable[getStatKey('altitude')]
    value = 0
    if data and data.enabled then
     for _,instance in pairs(data.instances) do
        value = value + (instance.value or 0)
      end
      if value < 1609.34 then
        data.predefinedUnit = 'm'
        data.unit = nil
      else
        data.unit='distance'
        data.predefinedUnit = nil
      end
    end
  end

  local playerVid = be:getPlayerVehicleID(0)
  local playerPoints, totalMaxPoints = calculatePoints(scenario, playerVid)
  fillScenarioOverallStats(scenario, playerVid, playerPoints, totalMaxPoints)
end

local function onScenarioRestarted(scenario)
  log('D', logTag, 'onScenarioRestarted: called ')
  initialiseTables(scenario)
end

local function onRaceGoalsInitilised(scenario)
  log('D', logTag, 'onRaceGoalsInitilised: called ')
  initialiseTables(scenario)
end

local function captureFinalDamageData(damageData)
  log('D', logTag, 'captureFinalDamageData called ')
  if damageData and damageData.enabled then
    for _,instance in pairs(damageData.instances) do
      if instance.source then
        local sourceVehicle = scenetree.findObject(instance.source)
        if sourceVehicle then
          local vehicleData = map.objects[sourceVehicle:getID()]
          if vehicleData then
            instance.value = vehicleData.damage
          end
        end
      end
    end
  end
end

local function onScenarioChange(scenario)
  -- log('D', logTag, 'onScenarioChange called.. ')
  if not scenario then
    return
  end

  if scenario.state == 'pre-start' then
  end

  if scenario.state == 'post' then
    for vehicleID, vehicleTable in pairs(statsTable) do
      captureFinalDamageData(vehicleTable[getStatKey('damage')])
    end
  end
end

local function onUpdate()
  local scenario = scenario_scenarios and scenario_scenarios.getScenario()
  if not scenario or not scenario.raceState or scenario.raceState ~= 'racing' or scenario.state == 'post' then
    return
  end

  for vehicleID, vehicleTable in pairs(statsTable) do
    local data = vehicleTable[getStatKey('distance')]
    if data and data.enabled then
      for _,instance in pairs(data.instances) do
        local vehicle = nil
        if instance.source then
          vehicle = scenetree.findObject(instance.source)
        else
          vehicle = be:getObjectByID(vehicleID)
        end
        if vehicle then
          local pos = vehicle:getPosition()
          local delta = pos - instance.initialPos
          instance.value = delta:length()
        end
      end
    end

    data = vehicleTable[getStatKey('altitude')]
    if data and data.enabled then
      for _,instance in pairs(data.instances) do
        local vehicle = nil
        if instance.source then
          vehicle = scenetree.findObject(instance.source)
        else
          vehicle = be:getObjectByID(vehicleID)
        end

        if vehicle then
          local pos = vehicle:getPosition()
          instance.value = math.abs(pos.z - instance.initialZPos)
        end
      end
    end

    data = vehicleTable[getStatKey('speed')]
    if data and data.enabled then
      for _,instance in pairs(data.instances) do
        local vehicleData = nil
        if instance.source then
          local vehicle = scenetree.findObject(instance.source)
          if vehicle then
            vehicleData = map.objects[vehicle:getID()]
          end
        else
          vehicleData = map.objects[vehicleID]
        end

        if vehicleData and instance.value then
          local speed = vehicleData.vel:length()
          if speed > instance.value then
            instance.value = speed
          end
        end
      end
    end
  end
end

local function onRaceInit()
  for vehicleID, vehicleTable in pairs(statsTable) do
    local data = vehicleTable[getStatKey('distance')]
    if data and data.enabled then
      for _,instance in pairs(data.instances) do
        local vehicle = nil
        if instance.source then
          vehicle = scenetree.findObject(instance.source)
        else
          vehicle = be:getObjectByID(vehicleID)
        end
        if vehicle then
          local pos = vehicle:getPosition()
          instance.initialPos = pos
        end
      end
    end

    data = vehicleTable[getStatKey('altitude')]
    if data and data.enabled then
      for _,instance in pairs(data.instances) do
        local vehicle = nil
        if instance.source then
          vehicle = scenetree.findObject(instance.source)
        else
          vehicle = be:getObjectByID(vehicleID)
        end
        if vehicle then
          local pos = vehicle:getPosition()
          instance.initialZPos = pos.z
        end
      end
    end
  end
end

local function captureTimeData(time)
 for vehicleID, vehicleTable in pairs(statsTable) do
    local data = vehicleTable[getStatKey('time')]
    if data and data.enabled then
      for _,instance in pairs(data.instances) do
        instance.value = time
      end
    end
  end
end

local function onRaceTick(raceTickTime, timer )
  captureTimeData(timer)
end

local function onRaceResult(status)
  captureTimeData(status.finalTime)
end

local function onSerialize()
  -- log('D', logTag, 'onSerialize called...')
  local data = {}
  data.statsTable = convertVehicleIdKeysToVehicleNameKeys(statsTable)
  data.scenarioStats = scenarioStats
  --writeFile("statistics_data.txt", dumps(data))

  return data
end

local function onDeserialized(data)
  log('D', logTag, 'onDeserialized called...')
  -- dump(data)
  statsTable = convertVehicleNameKeysToVehicleIdKeys(data.statsTable)
  scenarioStats = data.scenarioStats
  -- dump(scenarioStats)
  -- dump(statsTable)
end

local function onSaveCampaign(saveCallback)
  local data = {}
  data.statsTable = convertVehicleIdKeysToVehicleNameKeys(statsTable)
  data.scenarioStats = scenarioStats
  saveCallback(M.__globalAlias__, data)
end

local function onResumeCampaign(campaignInProgress, data)
  log('I', logTag, 'resume campaign called.....')
  statsTable = convertVehicleNameKeysToVehicleIdKeys(data.statsTable)
  scenarioStats = data.scenarioStats
end

local function DEBUG_generateScoreForMedal(medalString)
  if shipping_build then
    log('E', logTag, 'DEBUG_generateScoreForMedal SHOULD BE REMOVED from statistics.lua')
    log('E', logTag, 'DEBUG_generateScoreForMedal SHOULD BE REMOVED from statistics.lua')
    log('E', logTag, 'DEBUG_generateScoreForMedal SHOULD BE REMOVED from statistics.lua')
  end

  log('I', logTag, 'DEBUG_generateScoreForMedal called...'..tostring(medalString))

  local scenario = scenario_scenarios.getScenario()
  if not scenario then return end
  local playerVid = be:getPlayerVehicleID(0)

  local playerPoints, totalMaxPoints = calculatePoints(scenario, playerVid)
  local overall = statsProperties.overall or {goldCutoff=90, silverCutoff=70, bronzeCutoff=0}
  local percent
  if medalString == 'bronze' then
    percent = (overall.bronzeCutoff + 1) / 100.0
  elseif medalString == 'silver' then
    percent = (overall.silverCutoff + 1) / 100.0
  elseif medalString == 'gold' then
    percent = (overall.goldCutoff + 1) / 100.0
  end
  percent = clamp(percent, 0, 100)

  log('I', logTag, 'percent: '..tostring(percent))
  log('I', logTag, 'totalMaxPoints: '..tostring(totalMaxPoints))

  playerPoints = percent * totalMaxPoints
  log('I', logTag, 'playerPoints: '..tostring(playerPoints))

  fillScenarioOverallStats(scenario, playerVid, playerPoints, totalMaxPoints)

  if shipping_build then
    log('E', logTag, 'DEBUG_generateScoreForMedal SHOULD BE REMOVED from statistics.lua')
    log('E', logTag, 'DEBUG_generateScoreForMedal SHOULD BE REMOVED from statistics.lua')
    log('E', logTag, 'DEBUG_generateScoreForMedal SHOULD BE REMOVED from statistics.lua')
  end
end

-- public interface
M.onRaceGoalsInitilised     = onRaceGoalsInitilised
M.onScenarioRestarted       = onScenarioRestarted
M.onScenarioChange          = onScenarioChange
M.onUpdate                  = onUpdate
M.getVehicleStat            = getVehicleStat
M.getSummaryStats           = getSummaryStats
M.getScenarioOverallStat    = getScenarioOverallStat
M.initialiseArbitraryStat   = initialiseArbitraryStat
M.stopStatsGathering        = stopStatsGathering
M.onRaceInit                = onRaceInit
M.onRaceTick                = onRaceTick
M.onRaceResult              = onRaceResult
M.setGoalProgress           = setGoalProgress
M.setStatProgress           = setStatProgress
M.disableStatisticTracking  = disableStatisticTracking
M.enableStatisticTracking   = enableStatisticTracking
M.reset                     = reset
M.onSerialize               = onSerialize
M.onDeserialized            = onDeserialized
M.onSaveCampaign            = onSaveCampaign
M.onResumeCampaign          = onResumeCampaign
M.getMedalRanking           = getMedalRanking
M.DEBUG_generateScoreForMedal  = DEBUG_generateScoreForMedal
return M
