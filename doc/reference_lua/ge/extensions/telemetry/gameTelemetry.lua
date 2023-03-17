-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- Used for timing in ms
local socket = require("socket")

local timer = hptimer()

local logTag = 'gameTelemetry'
local telemetryVersion = "5"
local multiplePossible = {AIEnabled = true}
local writeReportToFileRequested

-- Activities to stop, when changing the level
local levelActivities = {"LevelLoaded", "TrafficEnabled", "ScenarioRunning", "VehicleUsed", "EditorRunning", "AIEnabled", "ControlsUsed", "TrackBuilder"}
local multiActivitiesKeys = {AIEnabled = "ID"}
local activityAggregationKeys = {LevelLoaded = {"LevelName"}, TrafficEnabled = {}, ScenarioRunning = {"File"}, ScenarioEnded = {"File", "Result"},
                      VehicleUsed = {"Vehicle", "Config", "CamMode"}, EditorRunning = {}, AIEnabled = {"Vehicle", "Mode"}, GameRunning = {},
                      VehicleResetted = {"Vehicle"}, UIStateUsed = {"State"}, ControlsUsed = {"Method"}, TrackBuilder = {}}

math.randomseed(os.time())
local secondsBetweenReports = 48 * 3600 + math.random(0, 24 * 3600)-- we distribute the reports submission pseudo randomly over 24 hours

local filename = nil

local trackedActivities = {}
local trackedMultiActivities = {AIEnabled = {}}
local activitiesExtraStats = {}

local gameTelemetryData = {}

local framecounter = 0
local delayedCam = false

local reportFileUiState = {
  ["loading"] = true,
  ["menu.levels"] = true,
  ["menu.levelDetails"] = true,
  ["scenario-start"] = true,
  ["scenario-end"] = true,
  ["menu.scenarios"] = true,
  ["menu.mainmenu"] = true,
  ["credits"] = true,
  ["menu.vehicles"] = true
}

local function getRunTime()
  return timer:stop() / 1000
end

local function getSalt()
  if not FS:directoryExists("gameTelemetries") then
    FS:directoryCreate("gameTelemetries")
  end

  local salt = nil
  local saltFile = '/gameTelemetries/.salt'
  if FS:fileExists(saltFile) then
    salt = readFile(saltFile)
  else
    salt = SecureComm.getRandomBytesHexSlow(256)
    local file = io.open(saltFile, 'w')
    file:write(salt)
    file:close()
  end
  return salt
end

-- Searches the trackedActivities for an activity and returns its index or nil if it's not being tracked
local function getTrackedActivity(activityName)
  return trackedActivities[activityName]
end

local function activitiesHaveSameKey(a, b)
  for _, key in ipairs(activityAggregationKeys[a.Name]) do
    if a[key] ~= b[key] then
      return false
    end
  end
  return true
end

local function addActivityToStats(activity)
  if not gameTelemetryData[activity.Name] then
    gameTelemetryData[activity.Name] = {}
  end

  for _, stat in ipairs(gameTelemetryData[activity.Name]) do
    if activitiesHaveSameKey(activity, stat) then
      if stat.Duration then
        stat.Duration = stat.Duration + activity.Duration
      else
        stat.Count = stat.Count + 1
      end
      return
    end
  end

  if not activity.Duration then
    activity.Count = 1
  end

  table.insert(gameTelemetryData[activity.Name], activity)
end


-- Saves the end of an activity
-- The activity must have a field "Name"
local function stopTracking(activity)
  if not activity then return end
  if activity.Name == nil then
    log('W', logTag, "Activity has no Name")
    return
  end

  local trackedActivity
  if multiplePossible[activity.Name] then
    trackedActivity = trackedMultiActivities[activity.Name][activity[multiActivitiesKeys[activity.Name]]]
    if trackedActivity then
      trackedMultiActivities[activity.Name][activity[multiActivitiesKeys[activity.Name]]] = nil
    end
  else
    trackedActivity = getTrackedActivity(activity.Name)
    if trackedActivity then
      trackedActivities[activity.Name] = nil
    end
  end

  if trackedActivity then
    trackedActivity.Duration = getRunTime() - trackedActivity.time
    trackedActivity.time = nil
    addActivityToStats(trackedActivity)
  else
    log('W', logTag, "Couldn't find tracked activity to stop")
  end
end


-- Saves the start of an activity.
-- The activity must have a field "Name"
local function startTracking(activity)
  if activity.Name == nil then
    log('W', logTag, "Activity has no Name")
    return
  end

  activity.time = getRunTime()
  if multiplePossible[activity.Name] then
    local trackedActivity = trackedMultiActivities[activity.Name][activity[multiActivitiesKeys[activity.Name]]]
    if trackedActivity then
      stopTracking(trackedActivity)
    end
    trackedMultiActivities[activity.Name][activity[multiActivitiesKeys[activity.Name]]] = activity
  else
    local trackedActivity = getTrackedActivity(activity.Name)
    if trackedActivity then
      stopTracking(trackedActivity)
    end
    trackedActivities[activity.Name] = activity
  end
end

-- Adds a single activity to the report
-- The activity must have a field "Name"
local function addSingleActivity(activity)
  local activityCopy = shallowcopy(activity)

  if activityCopy.Name == nil then
    log('W', logTag, "Activity has no Name")
    return
  end
  addActivityToStats(activityCopy)
end

local function vehResettedExtraStats(activity)
  local otherActivities = activitiesExtraStats["VehicleResetted"][activity.Vehicle]
  local averageDmg = 0
  local damages = {}
  for _, otherActivity in ipairs(otherActivities) do
    averageDmg = averageDmg + otherActivity.Damage
    table.insert(damages, otherActivity.Damage)
  end
  table.sort(damages)
  activity.MedianDmg = damages[round(table.getn(damages)/2)]
  activity.AverageDmg = averageDmg / table.getn(otherActivities)
  activity.MinDmg = damages[1]
  activity.MaxDmg = damages[table.getn(damages)]
  return activity
end

local function writeReportToFile()
  if not filename then
    if not FS:directoryExists("gameTelemetries") then
      FS:directoryCreate("gameTelemetries")
    end
    filename = "/gameTelemetries/gameTelemetry_" .. math.floor(socket.gettime() * 1000) .. ".json"
  end

  local file = io.open(filename, "w")

  if not gameTelemetryData["SessionStarted"] then
    addSingleActivity({Name = "SessionStarted", Time = os.date("!%Y-%m-%dT%TZ", socket.gettime()), Version = telemetryVersion, GFXAdapterType = Engine.Render.getAdapterType()})
  end

  local telemetryDataCopy = shallowcopy(gameTelemetryData)
  local contentString = jsonEncode(telemetryDataCopy["SessionStarted"][1]) .. "\n"
  local gameRunning = ''
  if telemetryDataCopy["GameRunning"] then
    gameRunning = jsonEncode(telemetryDataCopy["GameRunning"][1]) .. "\n"
  end
  telemetryDataCopy["SessionStarted"] = nil
  telemetryDataCopy["GameRunning"] = nil

  for name, activities in pairs(telemetryDataCopy) do
    for _, activity in ipairs(activities) do
      -- Delete empty strings

      if activity.Name == "VehicleResetted" then
        activity = vehResettedExtraStats(activity)
        activity.Damage = nil
      elseif activity.Name == "AIEnabled" then
        activity.ID = nil
      end

      contentString = contentString .. jsonEncode(activity) .. "\n"
    end
  end
  contentString = contentString .. gameRunning
  file:write(contentString)
  file:close()
end

local function extractVehicleDataTelemetry(vid)
  local campaign = campaign_campaigns and campaign_campaigns.getCampaign()
  local vehicleData = campaign and campaign.state.userVehicle
  local vehicleData
  if not vehicleData then
    local vehicle = scenetree.findObjectById(vid)
    if not vehicle then
      log('W',logTag, 'there is no vehicle with id: '..tostring(vid))
      return
    end
    if not vehicle:isSubClassOf('BeamNGVehicle') then
      log('W',logTag, 'Invalid vehicle id detected. id: '..tostring(vid))
      return
    end

    vehicleData = {}
    if vehicle.partConfig ~= nil and (string.find(vehicle.partConfig, '{') ~= nil or string.find(vehicle.partConfig, '\\[')) then
      vehicleData.config = ":custom"
    else
      local _, config, _ = path.splitWithoutExt(vehicle.partConfig)
      vehicleData.config = config
    end
    vehicleData.model = vehicle.JBeam
  end

  return vehicleData
end


local function trackNewVeh(vehicleID)
  if not vehicleID then
    vehicleID = be:getPlayerVehicleID(0)
  end
  if trackedActivities["VehicleUsed"] then
    stopTracking(trackedActivities["VehicleUsed"])
  end

  if vehicleID ~= -1 then
    -- Get the name of the new vehicle and start tracking
    local vehicleData = extractVehicleDataTelemetry(vehicleID)
    if not vehicleData then return end
    local activity = {}
    activity.Vehicle = vehicleData.model
    activity.Config = vehicleData.config
    activity.CamMode = core_camera.getActiveCamName() or "NA"
    activity.Name = "VehicleUsed"
    startTracking(activity)
  end
end

local function trackCamMode()
  trackNewVeh()
end


local function trackVehReset(vehicleID)
  if not vehicleID then
    vehicleID = be:getPlayerVehicleID(0)
  end
  if vehicleID == -1 then return end
  local vehicleData = extractVehicleDataTelemetry(vehicleID)
  if not vehicleData then return end

  local activity = {}
  activity.Name = "VehicleResetted"
  activity.Vehicle = vehicleData.model
  activity.Damage = 0

  local moreData = map.objects[vehicleID]
  if moreData then
    activity.Damage = moreData.damage
  end

  if not activitiesExtraStats["VehicleResetted"] then
    activitiesExtraStats["VehicleResetted"] = {}
  end
  if not activitiesExtraStats["VehicleResetted"][activity.Vehicle] then
    activitiesExtraStats["VehicleResetted"][activity.Vehicle] = {}
  end
  table.insert(activitiesExtraStats["VehicleResetted"][activity.Vehicle], activity)
  addSingleActivity(activity)

  writeReportToFileRequested = true
end

local function trackAISingleVeh(mode, vehicleID)
  if not vehicleID then
    vehicleID = be:getPlayerVehicleID(0)
  end
  if vehicleID == -1 then return end
  if trackedMultiActivities["AIEnabled"][vehicleID] then
    stopTracking(trackedMultiActivities["AIEnabled"][vehicleID])
  end

  if mode ~= "disabled" then
    local vehicleData = extractVehicleDataTelemetry(vehicleID)
    if not vehicleData then return end
    local activity = {}
    activity.Name = "AIEnabled"
    activity.Vehicle = vehicleData.model
    activity.ID = vehicleID
    activity.Mode = mode
    startTracking(activity)
  end
end

local function trackAIAllVeh(mode)
  local vehicleID = be:getPlayerVehicleID(0)
  for _, vehicle in ipairs(getObjectsByClass("BeamNGVehicle")) do
    if vehicle:getID() ~= vehicleID then
      trackAISingleVeh(mode, vehicle:getID())
    end
  end
end


-- called when the module is loaded. Note: not all system may be up and running at this point
local function onInit()
  --log('I', logTag, "initialized")
end


local function onExtensionUnloaded()
  log('I', logTag, "module unloaded")
end

local function postCallback(request)
  local files = nil
  if request and request.result == 'ok' then
    log('I', logTag, "Telemetry sent succesfully")

    files = FS:findFiles('/gameTelemetries/', '*.json', 1, true, false)
    for k,filename in pairs(files) do
      FS:removeFile(filename)
    end
    return
  end

  log('E', logTag, "Telemetry sending failed.")

  files = FS:findFiles('/gameTelemetries/', '*.json', 1, true, false)
  table.sort(files)
  local count = 0
  for k,filename in pairs(files) do
    FS:removeFile(filename)
    count = count + 1
    if count >= 3 then
      return
    end
  end
end

local function makeReport(gameSessionReport)
  log('I', logTag, "Sending telemetry data")
  local salt = getSalt()
  local userID = hashStringSHA256(salt)
  local data = {userID = userID, report = gameSessionReport}
  core_online.apiCall('s5/v2/telemetryReports', function(r) postCallback(r.responseData) end, data)
end

local function onClientStartMission(levelPath)
  -- Start tracking of the level
  startTracking({Name = "LevelLoaded", LevelName = levelPath})
end

local function trackCamModeDelayed()
  framecounter = framecounter + 1
  if framecounter > 10 then
    delayedCam = false
  end
  if core_camera.getActiveCamName() then
    trackCamMode()
    delayedCam = false
  end
end


local function onClientPostStartMission(levelPath)
  framecounter = 0

  -- Track the camera mode delayed by at least one frame, so the vlua can set the vdata correctly
  delayedCam = true
end


local function onClientEndMission(levelPath)
  -- Stop tracking for level related activity types
  for k, activityName in ipairs(levelActivities) do
    local activity = trackedActivities[activityName]
    if activity then
      if activityName == "ScenarioRunning" then
        addSingleActivity({Name = "ScenarioEnded", File = activity.File, Result = "aborted", ScenarioName = activity.ScenarioName})
      end
      stopTracking(activity)
    end
  end

  for id, activity in pairs(trackedMultiActivities["AIEnabled"]) do
    stopTracking(activity)
  end
  trackedMultiActivities["AIEnabled"] = {}
end


local function onEditorActivated()
  startTracking({Name = "EditorRunning"})
end

local function onEditorDeactivated()
  stopTracking({Name = "EditorRunning"})
end


local function makeTimeStamp(dateString)
  if not dateString then return 0 end
  local pattern = "(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)Z"
  local xyear, xmonth, xday, xhour, xminute,
      xseconds = dateString:match(pattern)
  local convertedTimestamp = os.time({year = xyear, month = xmonth,
      day = xday, hour = xhour, min = xminute, sec = xseconds})
  return convertedTimestamp
end


local function processReports(job)
  job.sleep(2)
  local startTime

  local allReports = {}
  local files = FS:findFiles('/gameTelemetries/', '*.json', 1, true, false)
  for k,filename in pairs(files) do
    local reportStartTime
    local version
    local report = {}
    local fileString = readFile(filename)
    for line in fileString:gmatch("([^\n]*)\n?") do
      if line:len() > 0 then
        local lineData = jsonDecode(line)
        if lineData then
          for key, value in pairs(lineData) do
            if value == '' then
              lineData[key] = nil
            end
          end

          if lineData.Name == "SessionStarted" then
            reportStartTime = makeTimeStamp(lineData.Time)
            version = lineData.Version
          end

          if lineData.Config ~= nil and (string.find(lineData.Config, '{') ~= nil or string.find(lineData.Config, '\\[')) then
            lineData.Config = ":custom"
          end

          if lineData.Duration ~= nil then
            if lineData.Duration > 1 then
              local duration = tostring(lineData.Duration)
              local rounded = string.format('%.3f', lineData.Duration)
              if string.len(rounded) + 2 < string.len(duration) then
                lineData.Duration = rounded
              end
              table.insert(report, lineData)
            end
          else
            table.insert(report, lineData)
          end
        end
      end
    end
    if version == telemetryVersion then
      table.insert(allReports, report)
      if not startTime or startTime > reportStartTime then
        startTime = reportStartTime
      end
    else
      FS:removeFile(filename)
    end

    job.yield()
  end

  -- Send the report if enough time has passed
  if (#allReports > 0) and startTime and (socket.gettime() > startTime + secondsBetweenReports) then
    log('I', logTag, "Sending report")
    makeReport(allReports)
  end
end

local function startTelemetry()
  local job = extensions.core_jobsystem.create(processReports, 0.5)
  startTracking({Name = "GameRunning"})
  registerCoreModule('telemetry/gameTelemetry')
end


local function onExit()
  -- Stop all activities that haven't stopped yet
  local activitiesCopy = shallowcopy(trackedActivities)
  for k, activity in pairs(activitiesCopy) do
    if activity.Name == "ScenarioRunning" then
      addSingleActivity({Name = "ScenarioEnded", File = activity.File, Result = "aborted", ScenarioName = activity.ScenarioName})
    end
    stopTracking(activity)
  end

  for id, activity in pairs(trackedMultiActivities["AIEnabled"]) do
    stopTracking(activity)
  end
  trackedMultiActivities["AIEnabled"] = {}

  writeReportToFile()
end

local function onUiChangedState(to, from)
  local activity = {}
  activity.Name = "UIStateUsed"
  activity.State = to
  startTracking(activity)

  if reportFileUiState[to] ~= nil then
    writeReportToFileRequested = true
  end
end

local function onVehicleSpawned(vehicleId)
  writeReportToFileRequested = true
end

local function onVehicleSwitched(oldId, newId, player)
  -- Retrack control filter type when switching vehicle
  if newId == -1 then return end
  local newVeh = scenetree.findObjectById(newId)
  if newVeh then
    newVeh:queueLuaCommand('input.lastFilterType = -1')
  end

  writeReportToFileRequested = true
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if delayedCam then
    trackCamModeDelayed()
  end

  if writeReportToFileRequested then
    writeReportToFileRequested = nil
    writeReportToFile()
  end
end

local function onScenarioFinished(scenario)
  local result = "success"
  if scenario.pooledResults[1] and scenario.pooledResults[1].failed then
    result = "failed"
  end

  stopTracking(getTrackedActivity("ScenarioRunning"))
  addSingleActivity({Name = "ScenarioEnded", File = scenario.sourceFile, Result = result, ScenarioName = scenario.name})
  writeReportToFileRequested = true
end

local function onScenarioLoaded(scenario)
  startTracking({Name = "ScenarioRunning", ScenarioName = scenario.name, File = scenario.sourceFile})
  writeReportToFileRequested = true
end

local function onScenarioRestarted(scenario)
  startTracking({Name = "ScenarioRunning", ScenarioName = scenario.name, File = scenario.sourceFile})
  addSingleActivity({Name = "ScenarioEnded", File = scenario.sourceFile, Result = "restarted", ScenarioName = scenario.name})
  writeReportToFileRequested = true
end


M.onInit = onInit
M.onExtensionUnloaded = onExtensionUnloaded
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onClientPostStartMission = onClientPostStartMission
M.onEditorActivated = onEditorActivated
M.onEditorDeactivated = onEditorDeactivated
M.onExit = onExit
M.onUiChangedState = onUiChangedState
M.onScenarioLoaded = onScenarioLoaded
M.onScenarioFinished = onScenarioFinished
M.onScenarioRestarted = onScenarioRestarted
M.onUpdate = onUpdate
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleSwitched = onVehicleSwitched

M.trackVehReset = trackVehReset
M.trackNewVeh = trackNewVeh
M.trackAISingleVeh = trackAISingleVeh
M.trackAIAllVeh = trackAIAllVeh
M.trackCamMode = trackCamMode

M.startTracking = startTracking
M.stopTracking = stopTracking
M.makeReport = makeReport

M.startTelemetry = startTelemetry

return M
