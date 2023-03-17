-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'scenarioHelper'

--sends the specified command to a vehicle of choice
local function queueLuaCommand(vehicle, command)
  vehicle:queueLuaCommand(command)
end

--returns a BeamObject for given name
local function getVehicleByName(name)
  return scenetree.findObject(name)
end

--sends the specified command to a vehicle via its name in the scenetree
local function queueLuaCommandByName(vehicleName, command)
  local vehicle = getVehicleByName(vehicleName)
  if vehicle then
    queueLuaCommand(vehicle, command)
  else
    log('E', logTag, 'Failed - queueLuaCommandByName('..vehicleName..','..command..') - Vehicle not found.')
  end
end

--breaks a single break group in a vehicle
local function breakBreakGroup(vehicleName, group)
  queueLuaCommand(getVehicleByName(vehicleName), 'beamstate.breakBreakGroup("'..group..'")')
end

--trigger a deform group, switch to a broken material (ie:break a window)
local function triggerDeformGroup(vehicleName, group)
  queueLuaCommand(getVehicleByName(vehicleName), 'beamstate.triggerDeformGroup("'..group..'")')
end

--enables tracking for the specified vehicle with a custom tracking name
local function trackVehicle(vehicleName, trackingName)
  queueLuaCommandByName(vehicleName, 'mapmgr.enableTracking("'..trackingName..'")')
end

-- sets ai vehicle mode and optionaly specifies the target Vehicle from targetVehicleName
local function setAiMode(vehicleName, mode, targetVehicleName)
  if targetVehicleName ~= nil then
    local vehicle = getVehicleByName(targetVehicleName)
    local vehicleID = vehicle.obj:getId()
    queueLuaCommandByName(vehicleName, 'ai.setState({mode="'..mode..'", targetObjectID='..vehicleID..'})')
  else
    queueLuaCommandByName(vehicleName, 'ai.setState({mode="'..mode..'"})')
  end

  if scenario_scenarios then
    scenario_scenarios.updateVehicleAiState(vehicleName, {mode = mode})
  end
end

local function setAiAggression(vehicleName, aggression)
  queueLuaCommandByName(vehicleName, 'ai.setAggression('..aggression..')')
  if scenario_scenarios then
    scenario_scenarios.updateVehicleAiState(vehicleName, {aggression = aggression})
  end
end

-- dynamic Aggression mode for the AI manual mode
-- aggreMode = 'rubberBand', makes AI aggression vary with opponent distance.
local function setAiAggressionMode(vehicleName, aggrMode)
  queueLuaCommandByName(vehicleName, 'ai.setAggressionMode("'..aggrMode..'")')
  if scenario_scenarios then
    scenario_scenarios.updateVehicleAiState(vehicleName, {aggressionMode = aggrMode})
  end
end

local function setAiTarget(vehicleName, target)
  queueLuaCommandByName(vehicleName, 'ai.setTarget("'..target..'")')
  if scenario_scenarios then
    scenario_scenarios.updateVehicleAiState(vehicleName, {target = target})
  end
end

local function setAiAvoidCars(vehicleName, value)
  -- value should be either 'off' or 'on' accordingly
  queueLuaCommandByName(vehicleName, 'ai.setAvoidCars("'..value..'")')
  if scenario_scenarios then
    scenario_scenarios.updateVehicleAiState(vehicleName, {value = value})
  end
end

--enables automatic waypoint progression for the specified ai vehicle (mode needs to be manual or flee)
local function setAiRoute(vehicleName, waypoints)
  queueLuaCommandByName(vehicleName, 'ai.driveUsingPath({wpTargetList = '..serialize(waypoints)..'})')
  if scenario_scenarios then
    scenario_scenarios.updateVehicleAiState(vehicleName, {waypoints = waypoints})
  end
end

local function setCutOffDrivability(vehicleName, drivability)
  queueLuaCommandByName(vehicleName, 'ai.setCutOffDrivability('..drivability..')')
  if scenario_scenarios then
    scenario_scenarios.updateVehicleAiState(vehicleName, {drivability = drivability})
  end
end

local function setAiPath(arg)
  --[[ USAGE
  Function Arguments: arg -> a table with the following keys:

  !!! Note: All arguments keys except "vehicleName" and "waypoints" are OPTIONAL !!!
  -- vehicleName
    The name of the vehicle to set as AI vehicle
  -- waypoints (type: a list of strings. Required field)
    The AI will figure out the shortest route between any consecutive waypoints entered in the list.
  -- routeSpeed (type: number)
    Speed in m/s this will apply to the entire route defined by "waypoints"
  -- routeSpeedMode (type: string)
    Options -> 'limit' / 'set'
    defines whether the routeSpeed argument above will act as a limiter (AI will not exceed difined speed) or will be forced on the AI vehicle
  -- driveInLane (type: string)
    Options -> 'on' / 'off'
    AI will drive in the appropriate side (lane) of the road in two way streets.
    Currently only works correctly with bidirectional roads one lane in each direction.
  -- lapCount (type: number)
    Defines the number of laps a vehicle will do on a circuit.
    In order for this to work the first and last waypoints in the "waypoints" list above should be the same (i.e. define a closed route).
  -- aggression (type: number)
    Acts as a multipliyer to the AI internal Aggression
    e.g. if aggression here is set to 1 the AI actuall aggression will be 1 * 0.7 = 0.7.
    The maximum value is 2.
  -- aggressionMode (type: string)
    Options -> 'rubberBand' (currently the only option)
    will adjust the aggression of the AI depending on the AI distance from an opponent. The closer the AI to the opponent the less aggressive it will be
    This option applies only to the AI manual mode. The chase and flee modes are set to a rubberBand aggression by default.
  -- resetLearning (type: boolean. When not defined same as setting to false)
      when set to true it will reset the learned acceleration envelopes (traction limits) of the vehicle
      when the function is called. To be used when driving concistency is more important than performance

  Example 1: AI vehicle will go from "scenario_wp01" to "scenario_wp02".
  local arg = {vehicleName = aiInstance,
              waypoints = {"scenario_wp01", "scenario_wp02"},
              aggression = 1.2,
              routeSpeed = 5,
              routeSpeedMode = 'limit',
              driveInLane = 'on',
              resetLearning = true}

  setAiPath(arg)

  Example 2: AI vehicle will do 5 laps on the route "scenario_wp01" - ... - "scenario_wp01".
  local arg = {vehicleName = aiInstance,
              waypoints = {"scenario_wp01", "scenario_wp02", "scenario_wp03", "scenario_wp04", "scenario_wp01"},
              lapCount = 5,
              aggression = 1.2}

  setAiPath(arg)
  --]]

  local vehicleName = arg.vehicleName
  local waypoints = arg.waypoints
  local routeSpeed = arg.routeSpeed or 0
  local routeSpeedMode = arg.routeSpeedMode or 'off'
  local driveInLane = arg.driveInLane or 'off'
  local speeds = arg.speeds or {}
  local lapCount = arg.lapCount or 0
  local aggression = arg.aggression or 1
  local avoidCars = arg.avoidCars or 'off'
  local aggressionMode = arg.aggressionMode or '' -- rubberBand or nil (aggression decreases with distance from opponent)
  local resetLearning = arg.resetLearning and 'true' or 'false'
  queueLuaCommandByName(vehicleName, 'ai.driveUsingPath({wpTargetList = '..serialize(waypoints)..', routeSpeed = '..routeSpeed..', routeSpeedMode = "'..routeSpeedMode..'", driveInLane = "'..driveInLane..'", wpSpeeds = '..serialize(speeds)..', noOfLaps = '..lapCount..', aggression = '..aggression..', aggressionMode = "'..aggressionMode..'", resetLearning = '..resetLearning..', avoidCars = "'..tostring(avoidCars)..'"})')

  -- we need this stored somewhere so when we reset ai vehicles we can set this again
  if core_checkpoints then
    core_checkpoints.saveAIPath(vehicleName, arg)
  end

  if scenario_scenarios then
    scenario_scenarios.updateVehicleAiState(vehicleName, {pathArgs = arg})
  end
end

local function flashUiMessage(msg, duration, useBiggerText)
  if useBiggerText ~= true then
    useBiggerText = false
  end
  guihooks.trigger('ScenarioFlashMessage', {{msg, duration, 0, useBiggerText}} )
end

local function realTimeUiDisplay (msg)
  guihooks.trigger('ScenarioRealtimeDisplay', {msg = msg} )
end

local function getDistanceBetweenSceneObjects(sceneObjectName1, sceneObjectName2)
  local sceneObject1 = scenetree.findObject(sceneObjectName1)
  local sceneObject2 = scenetree.findObject(sceneObjectName2)
  if sceneObject1 and sceneObject2 then
    return (sceneObject1:getPosition() - sceneObject2:getPosition()):len()
  else
    return -1
  end
end

-- public interface
M.queueLuaCommand = queueLuaCommand
M.queueLuaCommandByName = queueLuaCommandByName
M.getVehicleByName = getVehicleByName
M.breakBreakGroup = breakBreakGroup
M.triggerDeformGroup = triggerDeformGroup
M.trackVehicle = trackVehicle
M.setAiMode = setAiMode
M.setAiAggression = setAiAggression
M.setAiAggressionMode = setAiAggressionMode
--M.setAiTargetVehicle = setAiTargetVehicle
M.setAiTarget = setAiTarget
M.setAiAvoidCars = setAiAvoidCars
M.setAiRoute = setAiRoute
M.setAiPath = setAiPath
M.setCutOffDrivability = setCutOffDrivability
M.flashUiMessage = flashUiMessage
M.realTimeUiDisplay = realTimeUiDisplay
M.getDistanceBetweenSceneObjects = getDistanceBetweenSceneObjects

return M
