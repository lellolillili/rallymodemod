-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'ResearchGE'

local rcom = require('tech/techCommunication')
local scenariosLoader = require('scenario/scenariosLoader')
local procPrimitives = require('util/trackBuilder/proceduralPrimitives')
local jbeamIO = require('jbeam/io')

local port = 64256

local quitRequested = false

local conSleep = 1
local stepsLeft = 0

local blocking = nil
local waiting = nil

local spawnPending = nil

local vehicleInfoPending = 0
local vehicleInfo = nil

local frameDelayFuncQueue = {}

local sensors = {}

-- Containers for each sensor type, where the keys are the unique sensor name (given in beamNGpy), and the values are the unique sensor Id
-- in the simulator. Any interaction with the sensors in the simulator must be done through this unique sensor Id number.
local cameras = {}
local lidars = {}
local ultrasonics = {}
local advancedIMUs = {}
local powertrains = {}

local objectCount = 1

local server = nil
local clients = nil

local missingLicenseFeature = 'MISSING_LICENSE'

local debugObjects = { spheres = {},
                       dynamicSpheres = {},
                       polylines = {},
                       cylinders = {},
                       triangles = {},
                       rectangles ={},
                       text = {},
                       squarePrisms = {}
                      }
local debugObjectCounter = {sphereNum = 0,
                            dynamicSphereNum = 0,
                            lineNum = 0,
                            cylinderNum = 0,
                            triangleNum = 0,
                            rectangleNum = 0,
                            textNum = 0,
                            prismNum = 0
                          }

local hostOS = Engine.Platform.getOSInfo().type

local _log = log
local function log(level, message)
  _log(level, logTag, message)
end

local function addFrameDelayFunc(func, delay)
  table.insert(frameDelayFuncQueue, {callback=func, frameCountDown=delay})
end

local function addDynamicDebugSphere(getSpec)
  debugObjectCounter.dynamicSphereNum = debugObjectCounter.dynamicSphereNum + 1
  table.insert(debugObjects.dynamicSpheres, {getSpec = getSpec})
  return debugObjectCounter.dynamicSphereNum
end

local function getRunningFlowgraphManager()
  local mgrs = extensions.core_flowgraphManager.getAllManagers()
  for i = 1, #mgrs do
    if mgrs[i].runningState == 'running' then
      return mgrs[i]
    end
  end
end

local function block(reason, request)
  if blocking ~= nil then
    request:sendBNGError('Cannot fullfill this request. It needs blocking, but BeamNG.tech is already blocked (\'' .. reason .. '\').')
    return false
  end
  blocking = reason
  waiting = request

  return true
end

local function stopBlocking()
  blocking = nil
  waiting = nil
end

local function reportMissingLicenseFeature(request)
  request:sendBNGValueError('This feature requires a BeamNG.tech license.')
end

local function reportMissingLinuxFeature(request)
  request:sendBNGValueError('This feature is not yet supported on Linux hosts.')
end

M.onPreRender = function(dt)
  if quitRequested then
    shutdown(0)
  end

  local obsoleteFuncIndices = {}
  if frameDelayFuncQueue then
    for idx, item in pairs(frameDelayFuncQueue) do
      item.frameCountDown = item.frameCountDown-1
      if item.frameCountDown == 0 then
        item.callback()
        table.insert(obsoleteFuncIndices, idx)
      end
    end
  end

  if obsoleteFuncIndices then
    for k, idx in pairs(obsoleteFuncIndices) do
      table.remove(obsoleteFuncIndices, idx)
    end
  end

  if blocking ~= nil then
    if blocking == 'returnMainMenu' then
      if next(core_gamestate.state) == nil then
        waiting:sendACK('ScenarioStopped')
        stopBlocking()
        goto continue
      end
    end

    if blocking == 'step' then
      stepsLeft = stepsLeft - 1
      if stepsLeft == 0 then
        waiting:sendACK('Stepped')
        stopBlocking()
        goto continue
      end
    end

    return
  end

  ::continue::

  if server ~= nil then
    if conSleep <= 0 then
      conSleep = 1
      local newClients = rcom.checkForClients(server)
      for i = 1, #newClients do
        clients:insert(newClients[i])
        local ip, clientPort = newClients[i]:getsockname()
        log('I', 'Accepted new client: ' .. tostring(ip) .. '/' .. tostring(clientPort))
      end
    else
      conSleep = conSleep - dt
    end
  else
    return
  end

  while rcom.checkMessages(M, clients) do end
end

M.onLoadingScreenFadeout = function()
  if blocking == 'loadScenarioFG' then
    waiting:sendACK('MapLoaded')
    stopBlocking()
  elseif blocking == 'restartScenarioFG' then
    guihooks.trigger('ScenarioPlay')
    waiting:sendACK('ScenarioRestarted')
    stopBlocking()
  end
end

M.onScenarioLoaded = function()
  if blocking == 'loadScenario' then
    waiting:sendACK('MapLoaded')
    stopBlocking()
  end
end

M.onCountdownEnded = function()
  if blocking == 'startScenario' then
    waiting:sendACK('ScenarioStarted')
    stopBlocking()
  end
end

M.onScenarioRestarted = function(scenario)
  if blocking == 'restartScenario' then
    scenario_scenarios.changeState('running')
    scenario.showCountdown = false
    scenario.countDownTime = 0

    guihooks.trigger('ScenarioPlay')
    waiting:sendACK('ScenarioRestarted')
    stopBlocking()
  end
end

M.onVehicleConnectionReady = function(vehicleID, port)
  log('I', 'New vehicle connection: ' .. tostring(vehicleID) .. ', ' .. tostring(port))
  if blocking == 'vehicleConnection' then
    local name = ''
    local veh = scenetree.findObjectById(vehicleID)
    if veh ~= nil then
      name = veh:getName()
    end
    if name == '' then
      name = tostring(vehicleID)
    end
    local resp = {type = 'StartVehicleConnection', vid = name, result = port}
    waiting:sendResponse(resp)
    stopBlocking()
  end
end

M.onVehicleInfoReady = function(vehicleID, info)
  if blocking == 'vehicleInfo' then
    local current = vehicleInfo[vehicleID]
    current['port'] = info.port
    vehicleInfoPending = vehicleInfoPending - 1

    if vehicleInfoPending == 0 then
      local resp = {}
      for k, v in pairs(vehicleInfo) do
        resp[v.name] = v
      end
      resp = {type = 'GetCurrentVehicles', result = resp}
      waiting:sendResponse(resp)
      vehicleInfo = nil
      stopBlocking()
    end
  end
end

local function setup()
  settings.setValue('uiUnits', 'metric')
  settings.setValue('uiUnitLength', 'metric')
  settings.setValue('uiUnitTemperature', 'c')
  settings.setValue('uiUnitWeight', 'kg')
  settings.setValue('uiUnitTorque', 'metric')
  settings.setValue('uiUnitConsumptionRate', 'metric')
  settings.setValue('uiUnitEnergy', 'metric')
  settings.setValue('uiUnitDate', 'iso')
  settings.setValue('uiUnitPower', 'hp')
  settings.setValue('uiUnitVolume', 'l')
  settings.setValue('uiUnitPressure', 'bar')

  extensions.load('util/partAnnotations')

  if server == nil then
    server = rcom.newSet()
    server:insert(rcom.openServer(port))
    clients = rcom.newSet()
  end
end

M.onInit = function()
  local cmdArgs = Engine.getStartingArgs()
  for i, v in ipairs(cmdArgs) do
    if v == "-rport" then
      port = tonumber(cmdArgs[i + 1])
      setup()
    end
  end
end

M.startConnection = function(p)
  port = p
  setup()
end

M.notifyUI = function()
  local state = {}
  if server ~= nil then
    state.running = true
    state.port = port
  else
    state.running = false
  end
  guihooks.trigger('BeamNGpyExtensionReady', state)
end

-- Handlers

M.handleHello = function(request)
  local resp = {type = 'Hello', protocolVersion = rcom.protocolVersion}
  request:sendResponse(resp)
end

M.handleEcho = function(request)
  local delay = request['delay']
  local func = function ()
    local resp = {type = 'Echo', data = request['data']}
    request:sendResponse(resp)
  end

  if delay == nil or delay == 0 then
    func()
  else
    addFrameDelayFunc(func, delay)
  end
end

M.handleQuit = function(request)
  request:sendACK('Quit')
  quitRequested = true
  blocking = 'quit'
end

M.handleLoadScenario = function(request)
  local scenarioPath = request['path']
  if not scenarioPath then
    log('I', 'Scenario path empty...')
    request:sendBNGValueError(
      'Scenario not found, empty path was provided. ' ..
      'Run scenario.make() before starting the scenario.')
    return false
  end

  FS:updateDirectoryWatchers() -- late prefab file notification could cause a bug, update explicitly

  log('I', 'Loading scenario: '..scenarioPath)
  local sc = scenariosLoader.loadScenario(scenarioPath)
  if not sc then
    log('I', 'Scenario not found...')
    request:sendBNGValueError('Scenario not found: "' .. scenarioPath .. '"')
    return false
  end

  be:setPhysicsRunning(true) -- StartScenario does not work when the physics are paused

  local flowgraph = sc.flowgraph
  scenariosLoader.startByPath(scenarioPath)
  log('I', 'Scenario found...')
  if flowgraph then
    if not block('loadScenarioFG', request) then return false end
  else
    if not block('loadScenario', request) then return false end
  end
  return false -- keep false here -> do not process any more commands in this frame after loadscenario to avoid bugs
end

M.handleStartScenario = function(request)
  local scenario = scenario_scenarios and scenario_scenarios.getScenario()
  if scenario then -- blocked until countdown ends
    if not block('startScenario', request) then return false end
  end

  if scenario then -- 'normal' scenario loading (not flowgraph)
    scenario_scenarios.changeState('running')
    scenario.showCountdown = false
    scenario.countDownTime = 0
  end
  guihooks.trigger('ScenarioPlay')

  if not request['restrict_actions'] then -- allow freeroam-like controls of the scenario
    core_input_actionFilter.clear(0)
    core_gamestate.setGameState('exploration', nil, 'freeroam', 'freeroam')
  end
  if not scenario then
    request:sendACK('ScenarioStarted')
  end
  return true
end

M.handleRestartScenario = function(request)
  local scenario = scenario_scenarios and scenario_scenarios.getScenario()

  if scenario then
    if not block('restartScenario', request) then return false end
    scenario_scenarios.restartScenario()
  else
    local fgMgr = getRunningFlowgraphManager()
    if not block('restartScenarioFG', request) then return false end
    fgMgr:queueForRestart()
  end
  return true
end

M.handleStopScenario = function(request)
  if not block('returnMainMenu', request) then return false end
  returnToMainMenu()
end

M.handleGetScenarioName = function(request)
  local name
  if scenario_scenarios then
    name = scenario_scenarios.getscenarioName()
  else
    local fgMgr = getRunningFlowgraphManager()
    name = fgMgr.name
  end
  local resp = {type = 'ScenarioName', name = name}
  request:sendResponse(resp)
end

M.handleHideHUD = function(request)
  be:executeJS('document.body.style.opacity = "0.0";')
end

M.handleShowHUD = function(request)
  be:executeJS('document.body.style.opacity = "1.0";')
end

M.handleSetPhysicsDeterministic = function(request)
  be:setPhysicsSpeedFactor(-1)
  request:sendACK('SetPhysicsDeterministic')
end

M.handleSetPhysicsNonDeterministic = function(request)
  be:setPhysicsSpeedFactor(0)
  request:sendACK('SetPhysicsNonDeterministic')
end

M.handleFPSLimit = function(request)
  settings.setValue('FPSLimiter', request['fps'], true)
  settings.setState({FPSLimiterEnabled = true}, true)
  request:sendACK('SetFPSLimit')
end

M.handleRemoveFPSLimit = function(request)
  settings.setState({FPSLimiterEnabled = false}, true)
  request:sendACK('RemovedFPSLimit')
end

M.handlePause = function(request)
  be:setPhysicsRunning(false)
  request:sendACK('Paused')
end

M.handleResume = function(request)
  be:setPhysicsRunning(true)
  request:sendACK('Resumed')
end

M.handleStep = function(request)
  local count = request["count"]
  stepsLeft = count
  if request['ack'] then
    if not block('step', request) then return false end
  end
  be:physicsStep(count)
  return true
end

M.handleTeleport = function(request)
  local vID = request['vehicle']
  local veh = scenetree.findObject(vID)
  local resp = {type = 'Teleported', success = false}
  if veh == nil then
    request:sendResponse(resp)
    return
  end

  local reset = request['reset'] == nil or request['reset']
  if request['rot'] ~= nil then
    local rot = quat(request['rot'][1], request['rot'][2], request['rot'][3], request['rot'][4])
    rot = quat(-rot.y, rot.x, rot.w, -rot.z) -- vehicles' forward is inverted
    if not reset then
      local vehRot = quat(veh:getClusterRotationSlow(veh:getRefNodeId()))
      local diffRot = vehRot:inversed() * rot
      veh:setClusterPosRelRot(veh:getRefNodeId(), request['pos'][1], request['pos'][2], request['pos'][3], diffRot.x, diffRot.y, diffRot.z, diffRot.w)
    else
      veh:setPositionRotation(request['pos'][1], request['pos'][2], request['pos'][3], rot.x, rot.y, rot.z, rot.w)
    end
  else
    veh:setPosition(Point3F(request['pos'][1], request['pos'][2], request['pos'][3]))
  end
  resp.success = true
  request:sendResponse(resp)
end

M.handleTeleportScenarioObject = function(request)
  local sobj = scenetree.findObject(request['id'])
  if request['rot'] ~= nil then
    local quat = quat(request['rot'][1], request['rot'][2], request['rot'][3], request['rot'][4])
    sobj:setPosRot(request['pos'][1], request['pos'][2], request['pos'][3], quat.x, quat.y, quat.z, quat.w)
  else
    sobj:setPosition(Point3F(request['pos'][1], request['pos'][2], request['pos'][3]))
  end
  request:sendACK('ScenarioObjectTeleported')
end

M.handleStartVehicleConnection = function(request)
  local vid, veh, command

  vid = request['vid']

  command = 'extensions.load("tech/techCore")'
  veh = scenetree.findObject(vid)
  veh:queueLuaCommand(command)

  local exts = request['exts']
  if exts then
    for idx, ext in pairs(exts) do
      command = 'extensions.load("' .. ext .. '")'
      veh:queueLuaCommand(command)
    end
  end

  if not block('vehicleConnection', request) then return false end

  command = 'tech_techCore.startConnection()'
  veh:queueLuaCommand(command)
  return true
end

M.handleWaitForSpawn = function(request)
  local name = request['name']
  spawnPending = name
  return block('spawnVehicle', request)
end

M.onVehicleSpawned = function(vID)
  if blocking == 'spawnVehicle' and spawnPending ~= nil then
    local obj = scenetree.findObject(spawnPending)
    log('I', 'Vehicle spawned: ' .. tostring(vID))
    if obj ~= nil and obj:getID() == vID then
      local resp = {type = 'VehicleSpawned', name = spawnPending, success = true}
      spawnPending = nil
      waiting:sendResponse(resp)
      stopBlocking()
    end
  end
end

M.handleSpawnVehicle = function(request)
  local replace = request['replace']

  local alreadyExists = scenetree.findObject(request['name'])
  if alreadyExists and not replace then
    local resp = {type = 'VehicleSpawned', name = spawnPending, success = false}
    request:sendResponse(resp)
    return false
  end

  local name = request['name']
  local model = request['model']
  local pos = request['pos']
  local rot = request['rot']
  local cling = request['cling']

  if not core_vehicles.getModel(model).model then
    request:sendBNGError('Model not found: ' .. tostring(model))
    return false
  end

  if not replace then
    pos = vec3(pos[1], pos[2], pos[3])
    rot = quat(rot)
  end

  local partConfig = request['partConfig']

  local options = {}
  options.config = partConfig
  options.pos = pos
  options.rot = rot
  options.cling = cling
  options.vehicleName = name
  options.color = request['color']
  options.color2 = request['color2']
  options.color3 = request['color3']
  options.licenseText = request['licenseText']

  spawnPending = name
  if not block('spawnVehicle', request) then return false end

  if replace then
    local replaceVid = request['replace_vid']
    if replaceVid then
      local cur = be:getPlayerVehicle(0)
      local veh = scenetree.findObject(replaceVid)
      if not veh then
        request:sendBNGError('Vehicle \'' .. replaceVid .. '\' to be replaced was not found.')
        spawnPending = nil
        stopBlocking()
        return false
      end

      be:enterVehicle(0, veh)
      veh:setField('name', '', options.vehicleName)
      core_vehicles.replaceVehicle(model, options)
      be:enterVehicle(0, cur)
    else
      local cur = be:getPlayerVehicle(0)
      cur:setField('name', '', options.vehicleName)
      core_vehicles.replaceVehicle(model, options)
    end
  else
    local veh = core_vehicles.spawnNewVehicle(model, options)
    if options.licenseText ~= nil then
      core_vehicles.setPlateText(options.licenseText, veh:getID()) -- BUG: licenseText not respected in spawnNewVehicle
    end
  end
end

M.handleDespawnVehicle = function(request)
  local name = request['vid']
  local veh = scenetree.findObject(name)
  if veh ~= nil then
    veh:delete()
  end
  request:sendACK('VehicleDespawned')
end

sensors.Timer = function(req, callback)
  local time
  if scenario_scenarios then
    time = scenario_scenarios.getScenario().timer
  else
    local fgMgr = getRunningFlowgraphManager()
    time = Engine.Platform.getRuntime() - fgMgr.startTime
  end
  callback({time = time})
end

local function getSensorData(request, callback)
  local response, sensor_type, handler
  sensor_type = request['type']
  handler = sensors[sensor_type]
  if handler ~= nil then
    handler(request, callback)
  else
    callback(nil)
  end
end

local function getNextSensorData(requests, response, callback)
  local key = next(requests)
  if key == nil then
    callback(response)
    return
  end

  local request = requests[key]
  requests[key] = nil

  local cb = function(data)
    if data == missingLicenseFeature then
      response = missingLicenseFeature
      callback(response)
      return
    end

    response[key] = data
    getNextSensorData(requests, response, callback)
  end

  getSensorData(request, cb)
end

M.handleSensorRequest = function(request)
  local requests

  local cb = function(response)
    if response == missingLicenseFeature then
      reportMissingLicenseFeature(request)
      return false
    end
    response = {type = 'SensorData', data = response}
    request:sendResponse(response)
  end

  requests = request['sensors']

  getNextSensorData(requests, {}, cb)
  return true
end

M.handleGetDecalRoadVertices = function(request)
  local response = Sim.getDecalRoadVertices()
  response = {type = 'DecalRoadVertices', vertices = response}
  request:sendResponse(response)
end

M.handleGetDecalRoadData = function(request)
  local resp = {type = 'DecalRoadData'}
  local data = {}
  local roads = scenetree.findClassObjects('DecalRoad')
  for idx, roadID in ipairs(roads) do
    local road = scenetree.findObject(roadID)
    local roadData = {
      drivability = road:getField('drivability', ''),
      lanesLeft = road:getField('lanesLeft', ''),
      lanesRight = road:getField('lanesRight', ''),
      oneWay = road:getField('oneWay', '') ~= nil,
      flipDirection = road:getField('flipDirection', '') ~= nil
    }
    data[roadID] = roadData
  end
  resp['data'] = data
  request:sendResponse(resp)
end

M.handleGetDecalRoadEdges = function(request)
  local roadID = request['road']
  local response = {type = 'DecalRoadEdges'}
  local road = scenetree.findObject(roadID)
  local edges = {}
  for i, e in ipairs(road:getEdgesTable()) do
    local edge = {
      left = {
        e[1].x,
        e[1].y,
        e[1].z
      },
      middle = {
        e[2].x,
        e[2].y,
        e[2].z
      },
      right = {
        e[3].x,
        e[3].y,
        e[3].z
      }
    }
    table.insert(edges, edge)
  end
  response['edges'] = edges
  request:sendResponse(response)
end

M.handleTimeOfDayChange = function(request)
  core_environment.setTimeOfDay({time = request['tod']})
  request:sendACK('TimeOfDayChanged')
end

M.handleGetAdvancedImuId = function(request)
  local sensorId = advancedIMUs[request['name']]
  local resp = {type = 'getAdvancedImuId', data = sensorId}
  request:sendResponse(resp)
  request:sendACK('CompletedGetAdvancedImuId')
end

M.handleGetPowertrainId = function(request)
  local sensorId = powertrains[request['name']]
  local resp = {type = 'getPowertrainId', data = sensorId}
  request:sendResponse(resp)
  request:sendACK('CompletedGetPowertrainId')
end

M.handleOpenCamera = function(request)
  if not ResearchVerifier.isTechLicenseVerified() then
    reportMissingLicenseFeature(request)
    return false
  end

  if hostOS == 'linux' then
    reportMissingLinuxFeature(request)
    return false
  end

  local args = {}
  args.requestedUpdateTime = request['updateTime']
  args.updatePriority = request['priority']
  args.size = request['size']
  args.fovY = request['fovY']
  args.nearFarPlanes = request['nearFarPlanes']
  args.pos = Point3F(request['pos'][1], request['pos'][2], request['pos'][3])
  args.dir = Point3F(request['dir'][1], request['dir'][2], request['dir'][3])
  args.up = Point3F(request['up'][1], request['up'][2], request['up'][3])
  args.colourShmemHandle = request['colourShmemName']
  args.colourShmemSize = request['colourShmemSize']
  args.annotationShmemHandle = request['annotationShmemName']
  args.annotationShmemSize = request['annotationShmemSize']
  args.depthShmemHandle= request['depthShmemName']
  args.depthShmemSize = request['depthShmemSize']
  args.renderColours = request['renderColours']
  args.renderAnnotations = request['renderAnnotations']
  args.renderDepth = request['renderDepth']
  args.renderInstance = request['renderInstance']
  args.isVisualised = request['isVisualised']
  args.isStatic = request['isStatic']
  args.isSnappingDesired = request['isSnappingDesired']
  args.isForceInsideTriangle = request['isForceInsideTriangle']

  -- If annotations are required, we need to enable this in the engine.
  if request['renderAnnotations'] == true then
    Engine.Annotation.enable(true)
    log('I', 'Camera sensor - annotaton rendering enabled')
  end

  local name = request['name']
  local vid = 0
  if request['vid'] ~= 0 then
    vid = scenetree.findObject(request['vid']):getID();
  end
  if request['useSharedMemory'] == true then
    cameras[name] = extensions.tech_sensors.createCameraWithSharedMemory(vid, args)
    log('I', 'Opened camera sensor (with shared memory)')
  else
    cameras[name] = extensions.tech_sensors.createCamera(vid, args)
    log('I', 'Opened camera sensor (without shared memory)')
  end

  request:sendACK('OpenedCamera')
end

M.handleCloseCamera = function(request)
  local name = request['name']
  local sensorId = cameras[name]
  if sensorId ~= nil then
    extensions.tech_sensors.removeSensor(sensorId)
    cameras[name] = nil
    log('I', 'Closed camera sensor')
  end

  request:sendACK('ClosedCamera')
end

M.handlePollCamera = function(request)
  local name = request['name']
  local isUsingSharedMemory = request['isUsingSharedMemory']

  local sensorId = cameras[name]
  if sensorId ~= nil then
    if isUsingSharedMemory then
      -- Shared memory is being used, so the memory sizes are the response.
      local cameraSizes = Research.Camera.getLastCameraDataShmem(sensorId)
      local resp = {type = 'PollCamera', data = cameraSizes}
      request:sendResponse(resp)
    else
      -- Shared memory is not being used, so the data is the response.
      local cameraData = Research.Camera.getLastCameraData(sensorId)
      local resp = {type = 'PollCamera', data = {
        colour = cameraData['colour'],
        annotation = cameraData['annotation'],
        depth = cameraData['depth'] } }
      request:sendResponse(resp)
    end
  else
    -- The sensor was not found, so send an empty response.
    local resp = {type = 'PollCamera', data = nil}
    log('I', 'WARNING: Camera sensor not found')
    request:sendResponse(resp)
  end

  request:sendACK('PolledCamera')
end

M.handleSendAdHocRequestCamera = function(request)
  local requestId = extensions.tech_sensors.sendCameraRequest(cameras[request['name']])
  local resp = {type = 'requestId', data = requestId}
  request:sendResponse(resp)
  request:sendACK('CompletedSendAdHocRequestCamera')
end

M.handleIsAdHocPollRequestReadyCamera = function(request)
  local isRequestComplete = extensions.tech_sensors.isRequestComplete(request['requestId'])
  local resp = {type = 'isRequestComplete', data = isRequestComplete}
  request:sendResponse(resp)
  request:sendACK('CompletedIsAdHocPollRequestReadyCamera')
end

M.handleCollectAdHocPollRequestCamera = function(request)
  local cameraData = extensions.tech_sensors.collectCameraRequest(request['requestId'])
  local resp = {type = 'AdHocPollRequest', data = cameraData}
  request:sendResponse(resp)
  request:sendACK('CompletedCollectAdHocPollRequestCamera')
end

-- TODO Should be replaced when GE-2170 is complete.
M.handleGetFullCameraRequest = function(request)
  local camera = cameras[request['name']]
  if camera == nil then
    -- The sensor was not found, so send an empty response.
    local resp = {type = 'FullCameraRequest', data = nil}
    log('I', 'WARNING: Camera sensor not found')
    request:sendResponse(resp)
    request:sendACK('CompletedGetFullCameraRequest')
    return true
  end

  local cameraData = extensions.tech_sensors.getFullCameraRequest(camera)
  local data = {}
  data['colour'] = cameraData['colour']
  data['annotation'] = cameraData['annotation']
  data['instance'] = cameraData['instance']
  data['depth'] = cameraData['depth']
  local resp = {type = 'FullCameraRequest', data = data}
  request:sendResponse(resp)
  request:sendACK('CompletedGetFullCameraRequest')
end

M.handleCameraWorldPointToPixel = function(request)
  local point = vec3(request['pointX'], request['pointY'], request['pointZ'])
  local pixel = extensions.tech_sensors.convertWorldPointToPixel(cameras[request['name']], point)
  local resp = {type = 'CameraWorldPointToPixel', data = { x = pixel.x, y = pixel.y }}
  request:sendResponse(resp)
  request:sendACK('CompletedCameraWorldPointToPixel')
end

M.handleGetCameraSensorPosition = function(request)
  local pos = extensions.tech_sensors.getCameraSensorPosition(cameras[request['name']])
  local resp = {type = 'GetCameraSensorPosition', data = { x = pos.x, y = pos.y, z = pos.z}}
  request:sendResponse(resp)
  request:sendACK('CompletedGetCameraSensorPosition')
end

M.handleGetCameraSensorDirection = function(request)
  local dir = extensions.tech_sensors.getCameraSensorDirection(cameras[request['name']])
  local resp = {type = 'dir', data = { x = dir.x, y = dir.y, z = dir.z}}
  request:sendResponse(resp)
  request:sendACK('CompletedGetCameraSensorDirection')
end

M.handleGetCameraSensorUp = function(request)
  local up = extensions.tech_sensors.getCameraSensorUp(cameras[request['name']])
  local resp = {type = 'up', data = { x = up.x, y = up.y, z = up.z}}
  request:sendResponse(resp)
  request:sendACK('CompletedGetCameraSensorUp')
end

M.handleGetCameraMaxPendingGpuRequests = function(request)
  local maxRequests = extensions.tech_sensors.getCameraMaxPendingGpuRequests(cameras[request['name']])
  local resp = {type = 'maxPendingGpuRequests', data = maxRequests}
  request:sendResponse(resp)
  request:sendACK('CompletedGetCameraMaxPendingGpuRequests')
end

M.handleGetCameraRequestedUpdateTime = function(request)
  local updateTime = extensions.tech_sensors.getCameraRequestedUpdateTime(cameras[request['name']])
  local resp = {type = 'updateTime', data = updateTime}
  request:sendResponse(resp)
  request:sendACK('CompletedGetCameraRequestedUpdateTime')
end

M.handleGetCameraUpdatePriority = function(request)
  local priority = extensions.tech_sensors.getCameraUpdatePriority(cameras[request['name']])
  local resp = {type = 'updatePriority', data = priority}
  request:sendResponse(resp)
  request:sendACK('CompletedGetCameraUpdatePriority')
end

M.handleSetCameraSensorPosition = function(request)
  extensions.tech_sensors.setCameraSensorPosition(cameras[request['name']], vec3(request['posX'], request['posY'], request['posZ']))
  request:sendACK('CompletedSetCameraSensorPosition')
end

M.handleSetCameraSensorDirection = function(request)
  extensions.tech_sensors.setCameraSensorDirection(cameras[request['name']], vec3(request['dirX'], request['dirY'], request['dirZ']))
  request:sendACK('CompletedSetCameraSensorDirection')
end

M.handleSetCameraSensorUp = function(request)
  extensions.tech_sensors.setCameraSensorUp(cameras[request['name']], vec3(request['upX'], request['upY'], request['upZ']))
  request:sendACK('CompletedSetCameraSensorUp')
end

M.handleSetCameraMaxPendingGpuRequests = function(request)
  extensions.tech_sensors.setCameraMaxPendingGpuRequests(cameras[request['name']], request['maxPendingGpuRequests'])
  request:sendACK('CompletedSetCameraMaxPendingGpuRequests')
end

M.handleSetCameraRequestedUpdateTime = function(request)
  extensions.tech_sensors.setCameraRequestedUpdateTime(cameras[request['name']], request['updateTime'])
  request:sendACK('CompletedSetCameraRequestedUpdateTime')
end

M.handleSetCameraUpdatePriority = function(request)
  extensions.tech_sensors.setCameraUpdatePriority(cameras[request['name']], request['updatePriority'])
  request:sendACK('CompletedSetCameraUpdatePriority')
end

M.handleOpenLidar = function(request)
  if not ResearchVerifier.isTechLicenseVerified() then
    reportMissingLicenseFeature(request)
    return false
  end

  if hostOS == 'linux' then
    reportMissingLinuxFeature(request)
    return false
  end

  local args = {}
  args.pointCloudShmemName = request['pointCloudShmemHandle']
  args.pointCloudShmemSize = request['pointCloudShmemSize']
  args.colourShmemName = request['colourShmemHandle']
  args.colourShmemSize = request['colourShmemSize']
  args.requestedUpdateTime = request['updateTime']
  args.updatePriority = request['priority']
  args.pos = Point3F(request['pos'][1], request['pos'][2], request['pos'][3])
  args.dir = Point3F(request['dir'][1], request['dir'][2], request['dir'][3])
  args.up = Point3F(request['up'][1], request['up'][2], request['up'][3])
  args.verticalResolution = request['vRes']
  args.verticleAngle = request['vAngle']
  args.raysPerSecond = request['rps']
  args.frequency = request['hz']
  args.horizontalAngle = request['hAngle']
  args.maxDistance = request['maxDist']
  args.isVisualised = request['isVisualised']
  args.isAnnotated = request['isAnnotated']
  args.isStatic = request['isStatic']
  args.isSnappingDesired = request['isSnappingDesired']
  args.isForceInsideTriangle = request['isForceInsideTriangle']

  local name = request['name']
  local vid = 0
  if request['vid'] ~= 0 then
    vid = scenetree.findObject(request['vid']):getID();
  end
  if request['useSharedMemory'] == true then
    lidars[name] = extensions.tech_sensors.createLidarWithSharedMemory(vid, args)
    log('I', 'Opened LiDAR sensor (with shared memory)')
  else
    lidars[name] = extensions.tech_sensors.createLidar(vid, args)
    log('I', 'Opened LiDAR sensor (without shared memory)')
  end
  request:sendACK('OpenedLidar')
end

M.handleCloseLidar = function(request)
  local name = request['name']
  local sensorId = lidars[name]
  if sensorId ~= nil then
    extensions.tech_sensors.removeSensor(sensorId)
    lidars[name] = nil
    log('I', 'Closed LiDAR sensor')
  end
  request:sendACK('ClosedLidar')
end

M.handlePollLidar = function(request)
  local name = request['name']
  local isUsingSharedMemory = request['isUsingSharedMemory']
  local sensorId = lidars[name]
  if sensorId ~= nil then
    if isUsingSharedMemory then
      -- Shared memory is being used, so the memory sizes goes in the response.
      local pointCloudSize = Research.Lidar.getLastPointCloudDataShmem(sensorId)
      local colourSize = Research.Lidar.getLastColourDataShmem(sensorId)
      local resp = {type = 'PollLidar', data = { points = pointCloudSize, colours = colourSize }}
      request:sendResponse(resp)
    else
      -- Shared memory is not being used, so the point cloud and colour data goes in the response.
      local pointCloud = Research.Lidar.getLastPointCloudData(sensorId)       -- get the LiDAR point cloud data.
      local colours = Research.Lidar.getLastColourData(sensorId)              -- get the LiDAR colour data.
      local resp = {type = 'PollLidar', data = { pointCloud = pointCloud, colours = colours } }
      request:sendResponse(resp)
    end
  else
    -- The sensor was not found, so send an empty response.
    local resp = {type = 'PollLidar', data = nil}
    log('I', 'WARNING: LiDAR sensor not found')
    request:sendResponse(resp)
  end
  request:sendACK('PolledLidar')
end

M.handleSendAdHocRequestLidar = function(request)
  local requestId = extensions.tech_sensors.sendLidarRequest(lidars[request['name']])
  local resp = {type = 'requestId', data = requestId}
  request:sendResponse(resp)
  request:sendACK('CompletedSendAdHocRequestLidar')
end

M.handleIsAdHocPollRequestReadyLidar = function(request)
  local isRequestComplete = extensions.tech_sensors.isRequestComplete(request['requestId'])
  local resp = {type = 'isRequestComplete', data = isRequestComplete}
  request:sendResponse(resp)
  request:sendACK('CompletedIsAdHocPollRequestReadyLidar')
end

M.handleCollectAdHocPollRequestLidar = function(request)
  local data = extensions.tech_sensors.collectLidarRequest(request['requestId'])
  local resp = {type = 'AdHocPollRequestData', data = data }
  request:sendResponse(resp)
  request:sendACK('CompletedCollectAdHocPollRequestLidar')
end

M.handleGetLidarSensorPosition = function(request)
  local pos = extensions.tech_sensors.getLidarSensorPosition(lidars[request['name']])
  local resp = {type = 'pos', data = { x = pos.x, y = pos.y, z = pos.z}}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarSensorPosition')
end

M.handleGetLidarSensorDirection = function(request)
  local dir = extensions.tech_sensors.getLidarSensorDirection(lidars[request['name']])
  local resp = {type = 'dir', data = { x = dir.x, y = dir.y, z = dir.z}}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarSensorDirection')
end

M.handleGetLidarMaxPendingGpuRequests = function(request)
  local maxRequests = extensions.tech_sensors.getLidarMaxPendingGpuRequests(lidars[request['name']])
  local resp = {type = 'maxPendingGpuRequests', data = maxRequests}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarMaxPendingGpuRequests')
end

M.handleGetLidarRequestedUpdateTime = function(request)
  local updateTime = extensions.tech_sensors.getLidarRequestedUpdateTime(lidars[request['name']])
  local resp = {type = 'updateTime', data = updateTime}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarRequestedUpdateTime')
end

M.handleGetLidarUpdatePriority = function(request)
  local priority = extensions.tech_sensors.getLidarUpdatePriority(lidars[request['name']])
  local resp = {type = 'updatePriority', data = priority}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarUpdatePriority')
end

M.handleGetLidarVerticalResolution = function(request)
  local vRes = extensions.tech_sensors.getLidarVerticalResolution(lidars[request['name']])
  local resp = {type = 'verticalResolution', data = vRes}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarVerticalResolution')
end

M.handleGetLidarRaysPerSecond = function(request)
  local rps = extensions.tech_sensors.getLidarRaysPerSecond(lidars[request['name']])
  local resp = {type = 'raysPerSecond', data = rps}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarRaysPerSecond')
end

M.handleGetLidarFrequency = function(request)
  local freq = extensions.tech_sensors.getLidarFrequency(lidars[request['name']])
  local resp = {type = 'frequency', data = freq}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarFrequency')
end

M.handleGetLidarMaxDistance = function(request)
  local maxDist = extensions.tech_sensors.getLidarMaxDistance(lidars[request['name']])
  local resp = {type = 'maxDistance', data = maxDist}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarMaxDistance')
end

M.handleGetLidarIsVisualised = function(request)
  local isVisualised = extensions.tech_sensors.getLidarIsVisualised(lidars[request['name']])
  local resp = {type = 'isVisualised', data = isVisualised}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarIsVisualised')
end

M.handleGetLidarIsAnnotated = function(request)
  local isAnnotated = extensions.tech_sensors.getLidarIsAnnotated(lidars[request['name']])
  local resp = {type = 'isAnnotated', data = isAnnotated}
  request:sendResponse(resp)
  request:sendACK('CompletedGetLidarIsAnnotated')
end

M.handleSetLidarVerticalResolution = function(request)
  extensions.tech_sensors.setLidarVerticalResolution(lidars[request['name']], request['verticalResolution'])
  request:sendACK('CompletedSetLidarVerticalResolution')
end

M.handleSetLidarRaysPerSecond = function(request)
  extensions.tech_sensors.setLidarRaysPerSecond(lidars[request['name']], request['raysPerSecond'])
  request:sendACK('CompletedSetLidarRaysPerSecond')
end

M.handleSetLidarFrequency = function(request)
  extensions.tech_sensors.setLidarFrequency(lidars[request['name']], request['frequency'])
  request:sendACK('CompletedSetLidarFrequency')
end

M.handleSetLidarMaxDistance = function(request)
  extensions.tech_sensors.setLidarMaxDistance(lidars[request['name']], request['maxDistance'])
  request:sendACK('CompletedSetLidarMaxDistance')
end

M.handleSetLidarIsVisualised = function(request)
  extensions.tech_sensors.setLidarIsVisualised(lidars[request['name']], request['isVisualised'])
  request:sendACK('CompletedSetLidarIsVisualised')
end

M.handleSetLidarIsAnnotated = function(request)
  extensions.tech_sensors.setLidarIsAnnotated(lidars[request['name']], request['isAnnotated'])
  request:sendACK('CompletedSetLidarIsAnnotated')
end

M.handleSetLidarMaxPendingGpuRequests = function(request)
  extensions.tech_sensors.setLidarMaxPendingGpuRequests(lidars[request['name']], request['maxPendingGpuRequests'])
  request:sendACK('CompletedSetLidarMaxPendingGpuRequests')
end

M.handleSetLidarRequestedUpdateTime = function(request)
  extensions.tech_sensors.setLidarRequestedUpdateTime(lidars[request['name']], request['updateTime'])
  request:sendACK('CompletedSetLidarRequestedUpdateTime')
end

M.handleSetLidarUpdatePriority = function(request)
  extensions.tech_sensors.setLidarUpdatePriority(lidars[request['name']], request['updatePriority'])
  request:sendACK('CompletedSetLidarUpdatePriority')
end

M.handleOpenUltrasonic = function(request)
  if not ResearchVerifier.isTechLicenseVerified() then
    reportMissingLicenseFeature(request)
    return false
  end

  if hostOS == 'linux' then
    reportMissingLinuxFeature(request)
    return false
  end

  local args = {}
  args.requestedUpdateTime = request['updateTime']
  args.updatePriority = request['priority']
  args.size = request['size']
  args.fovY = request['fovY']
  args.nearFarPlanes = request['near_far_planes']
  args.rangeRoundness = request['range_roundness']
  args.rangeCutoffSensitivity = request['range_cutoff_sensitivity']
  args.rangeShape = request['range_shape']
  args.rangeFocus = request['range_focus']
  args.rangeMinCutoff = request['range_min_cutoff']
  args.rangeDirectMaxCutoff = request['range_direct_max_cutoff']
  args.sensitivity = request['sensitivity']
  args.fixedWindowSize = request['fixed_window_size']
  args.pos = Point3F(request['pos'][1], request['pos'][2], request['pos'][3])
  args.dir = Point3F(request['dir'][1], request['dir'][2], request['dir'][3])
  args.up = Point3F(request['up'][1], request['up'][2], request['up'][3])
  args.isVisualised = request['isVisualised']
  args.isStatic = request['isStatic']
  args.isSnappingDesired = request['isSnappingDesired']
  args.isForceInsideTriangle = request['isForceInsideTriangle']
  local name = request['name']
  local vid = 0
  if request['vid'] ~= 0 then
    vid = scenetree.findObject(request['vid']):getID();
  end
  ultrasonics[name] = extensions.tech_sensors.createUltrasonic(vid, args)
  log('I', 'Opened ultrasonic sensor')
  request:sendACK('OpenedUltrasonic')
end

M.handleCloseUltrasonic = function(request)
  local name = request['name']
  local sensorId = ultrasonics[name]
  if sensorId ~= nil then
    extensions.tech_sensors.removeSensor(sensorId)
    ultrasonics[name] = nil
    log('I', 'Closed ultrasonic sensor')
  end

  request:sendACK('ClosedUltrasonic')
end

M.handlePollUltrasonic = function(request)
  local name = request['name']
  local sensorId = ultrasonics[name]
  if sensorId ~= nil then
    local readings = Research.Ultrasonic.getLastReadings(sensorId)
    local resp = {type = 'PollUltrasonic', data = readings}
    request:sendResponse(resp)
  else
    -- The sensor was not found, so send an empty response.
    local resp = {type = 'PollUltrasonic', data = nil}
    log('I', 'WARNING: Ultrasonic sensor not found')
    request:sendResponse(resp)
  end
  request:sendACK('PolledUltrasonic')
end

M.handleSendAdHocRequestUltrasonic = function(request)
  local requestId = extensions.tech_sensors.sendUltrasonicRequest(ultrasonics[request['name']])
  local resp = {type = 'requestId', data = requestId}
  request:sendResponse(resp)
  request:sendACK('CompletedSendAdHocRequestUltrasonic')
end

M.handleIsAdHocPollRequestReadyUltrasonic = function(request)
  local isRequestComplete = extensions.tech_sensors.isRequestComplete(request['requestId'])
  local resp = {type = 'isRequestComplete', data = isRequestComplete}
  request:sendResponse(resp)
  request:sendACK('CompletedIsAdHocPollRequestReadyUltrasonic')
end

M.handleCollectAdHocPollRequestUltrasonic = function(request)
  local ultrasonicData = extensions.tech_sensors.collectUltrasonicRequest(request['requestId'])
  local resp = {type = 'AdHocPollRequestData', data = ultrasonicData}
  request:sendResponse(resp)
  request:sendACK('CompletedCollectAdHocPollRequestUltrasonic')
end

M.handleGetUltrasonicSensorPosition = function(request)
  local pos = extensions.tech_sensors.getUltrasonicSensorPosition(ultrasonics[request['name']])
  local resp = {type = 'pos', data = { x = pos.x, y = pos.y, z = pos.z}}
  request:sendResponse(resp)
  request:sendACK('CompletedGetUltrasonicSensorPosition')
end

M.handleGetUltrasonicSensorDirection = function(request)
  local dir = extensions.tech_sensors.getUltrasonicSensorDirection(ultrasonics[request['name']])
  local resp = {type = 'dir', data = { x = dir.x, y = dir.y, z = dir.z}}
  request:sendResponse(resp)
  request:sendACK('CompletedGetUltrasonicSensorDirection')
end

M.handleGetUltrasonicMaxPendingGpuRequests = function(request)
  local maxRequests = extensions.tech_sensors.getUltrasonicMaxPendingGpuRequests(ultrasonics[request['name']])
  local resp = {type = 'maxPendingGpuRequests', data = maxRequests}
  request:sendResponse(resp)
  request:sendACK('CompletedGetUltrasonicMaxPendingGpuRequests')
end

M.handleGetUltrasonicRequestedUpdateTime = function(request)
  local updateTime = extensions.tech_sensors.getUltrasonicRequestedUpdateTime(ultrasonics[request['name']])
  local resp = {type = 'updateTime', data = updateTime}
  request:sendResponse(resp)
  request:sendACK('CompletedGetUltrasonicRequestedUpdateTime')
end

M.handleGetUltrasonicUpdatePriority = function(request)
  local priority = extensions.tech_sensors.getUltrasonicUpdatePriority(ultrasonics[request['name']])
  local resp = {type = 'updatePriority', data = priority}
  request:sendResponse(resp)
  request:sendACK('CompletedGetUltrasonicUpdatePriority')
end

M.handleGetUltrasonicIsVisualised = function(request)
  local isVisualised = extensions.tech_sensors.getUltrasonicIsVisualised(ultrasonics[request['name']])
  local resp = {type = 'isVisualised', data = isVisualised}
  request:sendResponse(resp)
  request:sendACK('CompletedGetUltrasonicIsVisualised')
end

M.handleSetUltrasonicMaxPendingGpuRequests = function(request)
  extensions.tech_sensors.setUltrasonicMaxPendingGpuRequests(ultrasonics[request['name']], request['maxPendingGpuRequests'])
  request:sendACK('CompletedSetUltrasonicMaxPendingGpuRequests')
end

M.handleSetUltrasonicRequestedUpdateTime = function(request)
  extensions.tech_sensors.setUltrasonicRequestedUpdateTime(ultrasonics[request['name']], request['updateTime'])
  request:sendACK('CompletedSetUltrasonicRequestedUpdateTime')
end

M.handleSetUltrasonicUpdatePriority = function(request)
  extensions.tech_sensors.setUltrasonicUpdatePriority(ultrasonics[request['name']], request['updatePriority'])
  request:sendACK('CompletedSetUltrasonicUpdatePriority')
end

M.handleSetUltrasonicIsVisualised = function(request)
  extensions.tech_sensors.setUltrasonicIsVisualised(ultrasonics[request['name']], request['isVisualised'])
  request:sendACK('CompletedSetUltrasonicIsVisualised')
end

M.handleOpenAdvancedIMU = function(request)
  if not ResearchVerifier.isTechLicenseVerified() then
    reportMissingLicenseFeature(request)
    return false
  end

  local args = {}
  args.GFXUpdateTime = request['GFXUpdateTime']
  args.physicsUpdateTime = request['physicsUpdateTime']
  args.pos = Point3F(request['pos'][1], request['pos'][2], request['pos'][3])
  args.dir = Point3F(request['dir'][1], request['dir'][2], request['dir'][3])
  args.up = Point3F(request['up'][1], request['up'][2], request['up'][3])
  args.windowWidth = request['windowWidth']
  args.isSendImmediately = request['isSendImmediately']
  args.frequencyCutoff = request['frequencyCutoff']
  args.isVisualised = request['isVisualised']
  args.isUsingGravity= request['isUsingGravity']
  args.isSnappingDesired = request['isSnappingDesired']
  args.isForceInsideTriangle = request['isForceInsideTriangle']

  local name = request['name']
  local vid = scenetree.findObject(request['vid']):getID();

  advancedIMUs[name] = extensions.tech_sensors.createAdvancedIMU(vid, args)
  log('I', 'Opened AdvancedIMU sensor')

  request:sendACK('OpenedAdvancedIMU')
end

M.handleCloseAdvancedIMU = function(request)
  local name = request['name']
  local vid = request['vid']
  local sensorId = advancedIMUs[name]
  if sensorId ~= nil then
    advancedIMUs[name] = nil                                    -- remove from ge lua
    extensions.tech_sensors.removeAdvancedIMU(vid, sensorId)    -- remove from vlua.
    log('I', 'Closed Advanced IMU sensor')
  end

  request:sendACK('ClosedAdvancedIMU')
end

M.handlePollAdvancedImuGE = function(request)
  local name = request['name']
  local sensorId = advancedIMUs[name]
  if sensorId ~= nil then
    local readings = extensions.tech_sensors.getAdvancedIMUReadings(sensorId)
    if readings ~= nil then
      local resp = { type = 'PollAdvancedImuGE', data = readings }
      request:sendResponse(resp)
      request:sendACK('PolledAdvancedImuGECompleted')
      return true
    end
  end

  -- The sensor was not found, or the readings did not exist, so send an empty response.
  local resp = {type = 'PollAdvancedImuGE', data = {} }
  log('I', 'WARNING: Advanced IMU sensor not found')
  request:sendResponse(resp)
  request:sendACK('PolledAdvancedImuGECompleted')
end

M.handleSendAdHocRequestAdvancedIMU = function(request)
  local requestId = extensions.tech_sensors.sendAdvancedIMURequest(advancedIMUs[request['name']], request['vid'])
  local resp = {type = 'requestId', data = requestId}
  request:sendResponse(resp)
  request:sendACK('CompletedSendAdHocRequestAdvancedIMU')
end

M.handleIsAdHocPollRequestReadyAdvancedIMU = function(request)
  local isRequestComplete = extensions.tech_sensors.isVluaRequestComplete(request['requestId'])
  local resp = {type = 'isRequestComplete', data = isRequestComplete}
  request:sendResponse(resp)
  request:sendACK('CompletedIsAdHocPollRequestReadyAdvancedIMU')
end

M.handleCollectAdHocPollRequestAdvancedIMU = function(request)
  local reading = extensions.tech_sensors.collectAdvancedIMURequest(request['requestId'])
  local resp = {type = 'AdHocPollRequestData', data = reading}
  request:sendResponse(resp)
  request:sendACK('CompletedCollectAdHocPollRequestAdvancedIMU')
end

M.handleSetAdvancedIMURequestedUpdateTime = function(request)
  extensions.tech_sensors.setAdvancedIMUUpdateTime(advancedIMUs[request['name']], request['vid'], request['updateTime'])
  request:sendACK('CompletedSetAdvancedIMURequestedUpdateTime')
end

M.handleSetAdvancedIMUIsUsingGravity = function(request)
  extensions.tech_sensors.setAdvancedIMUIsUsingGravity(advancedIMUs[request['name']], request['vid'], request['isUsingGravity'])
  request:sendACK('CompletedSetAdvancedIMUIsUsingGravity')
end

M.handleSetAdvancedIMUIsVisualised = function(request)
  extensions.tech_sensors.setAdvancedIMUIsVisualised(advancedIMUs[request['name']], request['vid'], request['isVisualised'])
  request:sendACK('CompletedSetAdvancedIMUIsVisualised')
end

M.handleOpenPowertrain = function(request)
  if not ResearchVerifier.isTechLicenseVerified() then
    reportMissingLicenseFeature(request)
    return false
  end

  local args = {}
  args.GFXUpdateTime = request['GFXUpdateTime']
  args.physicsUpdateTime = request['physicsUpdateTime']
  args.isSendImmediately = request['isSendImmediately']

  local name = request['name']
  local vid = scenetree.findObject(request['vid']):getID();

  powertrains[name] = extensions.tech_sensors.createPowertrainSensor(vid, args)
  log('I', 'Opened Powertrain sensor')

  request:sendACK('OpenedPowertrain')
end

M.handleClosePowertrain = function(request)
  local name = request['name']
  local vid = request['vid']
  local sensorId = powertrains[name]
  if sensorId ~= nil then
    powertrains[name] = nil                                    -- remove from ge lua
    extensions.tech_sensors.removePowertrainSensor(vid, sensorId)    -- remove from vlua.
    log('I', 'Closed Powertrain sensor')
  end

  request:sendACK('ClosedPowertrain')
end

M.handlePollPowertrainGE = function(request)
  local name = request['name']
  local sensorId = powertrains[name]
  if sensorId ~= nil then
    local readings = extensions.tech_sensors.getPowertrainReadings(sensorId)
    if readings ~= nil then
      local resp = { type = 'PollPowertrainGE', data = readings }
      request:sendResponse(resp)
      request:sendACK('PolledPowertrainGECompleted')
      return true
    end
  end

  -- The sensor was not found, or the readings did not exist, so send an empty response.
  local resp = {type = 'PollPowertrainGE', data = {} }
  log('I', 'WARNING: Powertrain sensor not found')
  request:sendResponse(resp)
  request:sendACK('PolledPowertrainGECompleted')
end

M.handleSendAdHocRequestPowertrain = function(request)
  local requestId = extensions.tech_sensors.sendPowertrainRequest(powertrains[request['name']], request['vid'])
  local resp = {type = 'requestId', data = requestId}
  request:sendResponse(resp)
  request:sendACK('CompletedSendAdHocRequestPowertrain')
end

M.handleIsAdHocPollRequestReadyPowertrain = function(request)
  local isRequestComplete = extensions.tech_sensors.isVluaRequestComplete(request['requestId'])
  local resp = {type = 'isRequestComplete', data = isRequestComplete}
  request:sendResponse(resp)
  request:sendACK('CompletedIsAdHocPollRequestReadyPowertrain')
end

M.handleCollectAdHocPollRequestPowertrain = function(request)
  local reading = extensions.tech_sensors.collectPowertrainRequest(request['requestId'])
  local resp = {type = 'AdHocPollRequestData', data = reading}
  request:sendResponse(resp)
  request:sendACK('CompletedCollectAdHocPollRequestPowertrain')
end

M.handleSetPowertrainRequestedUpdateTime = function(request)
  extensions.tech_sensors.setPowertrainUpdateTime(powertrains[request['name']], request['vid'], request['updateTime'])
  request:sendACK('CompletedSetPowertrainRequestedUpdateTime')
end

M.handleSetWeatherPreset = function(request)
  local preset = request['preset']
  local time = request['time']
  core_weather.switchWeather(preset, time)
  request:sendACK('WeatherPresetChanged')
end

M.handleGameStateRequest = function(request)
  local state = core_gamestate.state.state
  local resp = {type = 'GameState'}
  if state == 'scenario' then
    resp['state'] = 'scenario'
    resp['scenario_state'] = scenario_scenarios.getScenario().state
    resp['level'] = getCurrentLevelIdentifier()
  else
    resp['state'] = 'menu'
  end
  request:sendResponse(resp)
end

M.handleDisplayGuiMessage = function(request)
  local message = request['message']
  guihooks.message(message)
  request:sendACK('GuiMessageDisplayed')
end

M.handleSwitchVehicle = function(request)
  local vID = request['vid']
  local vehicle = scenetree.findObject(vID)
  be:enterVehicle(0, vehicle)
  request:sendACK('VehicleSwitched')
end

M.handleSetFreeCamera = function(request)
  local pos = request['pos']
  local direction = request['dir']
  local rot = quatFromDir(vec3(direction[1], direction[2], direction[3]))

  commands.setFreeCamera()
  commands.setCameraPosRot(pos[1], pos[2], pos[3], rot.x, rot.y, rot.z, rot.w)
  request:sendACK('FreeCameraSet')
end

M.handleParticlesEnabled = function(request)
  local enabled = request['enabled']
  Engine.Render.ParticleMgr.setEnabled(enabled)
  request:sendACK('ParticlesSet')
end

M.handleAnnotateParts = function(request)
  local vehicle = scenetree.findObject(request['vid'])
  util_partAnnotations.annotateParts(vehicle:getID())
  request:sendACK('PartsAnnotated')
end

M.handleRevertAnnotations = function(request)
  local vehicle = scenetree.findObject(request['vid'])
  util_partAnnotations.revertAnnotations(vehicle:getID())
  request:sendACK('AnnotationsReverted')
end

M.handleGetPartAnnotations = function(request)
  local vehicle = scenetree.findObject(request['vid'])
  local colors = util_partAnnotations.getPartAnnotations(vehicle:getID())
  local converted = {}
  for key, val in pairs(colors) do
    converted[key] = {val.r, val.g, val.b}
  end
  request:sendResponse({type = 'PartAnnotations', colors = converted})
end

M.handleGetPartAnnotation = function(request)
  local part = request['part']
  local color = util_partAnnotations.getPartAnnotation(part)
  if color ~= nil then
    color = {color.r, color.g, color.b}
  end
  request:sendResponse({type = 'PartAnnotation', color = color})
end

M.handleGetAnnotations = function(request)
  if not ResearchVerifier.isTechLicenseVerified() then
    reportMissingLicenseFeature(request)
    return false
  end

  local annotations = AnnotationManager.getAnnotations()
  for k, v in pairs(annotations) do
    annotations[k] = {v.r, v.g, v.b}
  end
  local ret = {type = 'Annotations', annotations = annotations}
  request:sendResponse(ret)
end

M.handleFindObjectsClass = function(request)
  local clazz = request['class']
  local objects = scenetree.findClassObjects(clazz)
  local resp = {type='ClassObjects'}
  local list = {}
  for idx, object in ipairs(objects) do
    object = scenetree.findObject(object)

    local obj = {type=clazz, id=object:getID(), name=object:getName()}

    local scl = object:getScale()
    local pos = object:getPosition()
    local rot = object:getRotation()
    if clazz == 'BeamNGVehicle' then
      local vehicleData = map.objects[obj.id]
      rot = quatFromDir(vehicleData.dirVec, vehicleData.dirVecUp)
    end

    pos = {pos.x, pos.y, pos.z}
    rot ={rot.x, rot.y, rot.z, rot.w}

    scl = {scl.x, scl.y, scl.z}

    obj['position'] = pos
    obj['rotation'] = rot
    obj['scale'] = scl

    obj['options'] = {}
    for fld, nfo in pairs(object:getFieldList()) do
      if fld ~= 'position' and fld ~= 'rotation' and fld ~= 'scale' and fld ~= 'id' and fld ~= 'type' and fld ~= 'name' then
        local val = object:getField(fld, '')
        obj['options'][fld] = val
      end
    end

    table.insert(list, obj)
  end
  resp['objects'] = list
  request:sendResponse(resp)
end

local function placeObject(name, mesh, pos, rot)
  if name == nil then
    name = 'procObj' .. tostring(objectCount)
    objectCount = objectCount + 1
  end

  pos = vec3(pos)
  rot = quat(rot):toTorqueQuat()

  local proc = createObject('ProceduralMesh')
  proc:registerObject(name)
  proc.canSave = false
  scenetree.MissionGroup:add(proc.obj)
  proc:createMesh({{mesh}})
  proc:setPosition(pos:toPoint3F())
  proc:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
  proc.scale = Point3F(1, 1, 1)

  be:reloadCollision()

  return proc
end

M.handleCreateCylinder = function(request)
  local name = request['name']
  local radius = request['radius']
  local height = request['height']
  local material = request['material']
  local pos = request['pos']
  local rot = request['rot']

  local cylinder = procPrimitives.createCylinder(radius, height, material)
  placeObject(name, cylinder, pos, rot)

  request:sendACK('CreatedCylinder')
end

M.handleCreateBump = function(request)
  local name = request['name']
  local length = request['length']
  local width = request['width']
  local height = request['height']
  local upperLength = request['upperLength']
  local upperWidth = request['upperWidth']
  local material = request['material']
  local pos = request['pos']
  local rot = request['rot']

  local bump = procPrimitives.createBump(length, width, height, upperLength, upperWidth, material)
  placeObject(name, bump, pos, rot)

  request:sendACK('CreatedBump')
end

M.handleCreateCone = function(request)
  local name = request['name']
  local radius = request['radius']
  local height = request['height']
  local material = request['material']
  local pos = request['pos']
  local rot = request['rot']

  local cone = procPrimitives.createCone(radius, height, material)
  placeObject(name, cone, pos, rot)

  request:sendACK('CreatedCone')
end

M.handleCreateCube = function(request)
  local name = request['name']
  local size = vec3(request['size'])
  local material = request['material']
  local pos = request['pos']
  local rot = request['rot']

  local cube = procPrimitives.createCube(size, material)
  placeObject(name, cube, pos, rot)

  request:sendACK('CreatedCube')
end

M.handleCreateRing = function(request)
  local name = request['name']
  local radius = request['radius']
  local thickness = request['thickness']
  local material = request['material']
  local pos = request['pos']
  local rot = request['rot']

  local ring = procPrimitives.createRing(radius, thickness, material)
  placeObject(name, ring, pos, rot)

  request:sendACK('CreatedRing')
end

M.handleGetBBoxCorners = function(request)
  local veh = scenetree.findObject(request['vid'])
  local resp = {type = 'BBoxCorners'}
  local points = {}
  local bbox = veh:getSpawnWorldOOBB()
  for i = 0, 7 do
    local point = bbox:getPoint(i)
    point = {tonumber(point.x), tonumber(point.y), tonumber(point.z)}
    table.insert(points, point)
  end
  resp['points'] = points
  request:sendResponse(resp)
end

M.handleSetGravity = function(request)
  local gravity = request['gravity']
  core_environment.setGravity(gravity)
  request:sendACK('GravitySet')
end

M.handleGetAvailableVehicles = function(request)
  local resp = {type = 'AvailableVehicles', vehicles = {}}

  local models = core_vehicles.getModelList().models
  local configs = core_vehicles.getConfigList().configs

  for model, modelData in pairs(models) do
    local data = {
      author = modelData.Author,
      name = modelData.Name,
      type = modelData.Type,
      key = modelData.key,
    }
    data.configurations = {}
    for key, config in pairs(configs) do
      if config.model_key == model then
        data.configurations[config.key] = {
          author = config.Author,
          model_key = config.model_key,
          key = config.key,
          name = config.Name,
          type = config.Type
        }
      end
    end
    resp.vehicles[model] = data
  end

  request:sendResponse(resp)
end

M.handleSpawnTraffic = function(request)
  local maxAmount = request['max_amount']
  local policeRatio = request['police_ratio']
  local extraAmount = request['extra_amount']
  local parkedAmount = request['parked_amount']

  gameplay_traffic.setupTraffic(maxAmount, policeRatio, extraAmount, parkedAmount)
  request:sendACK('TrafficSpawned')
end

M.handleStartTraffic = function(request)
  local participants = request.participants
  local ids = {}
  for idx, participant in ipairs(participants) do
    local veh = scenetree.findObject(participant)

    if veh == nil then
      request:sendBNGValueError('Vehicle not present for traffic: ' .. tostring(participant))
      return
    end

    table.insert(ids, veh:getID())
  end

  gameplay_traffic.activate(ids)
  request:sendACK('TrafficStarted')
end

M.handleResetTraffic = function(request)
  gameplay_traffic.forceTeleportAll()
  request:sendACK('TrafficReset')
end

M.handleStopTraffic = function(request)
  local stop = request.stop
  gameplay_traffic.deactivate(stop)
  request:sendACK('TrafficStopped')
end

M.handleChangeSetting = function(request)
  local key = request['key']
  local value = request['value']
  settings.setValue(key, value, true)
  request:sendACK('SettingsChanged')
end

M.handleApplyGraphicsSetting = function(request)
  core_settings_graphic.applyGraphicsState()
  request:sendACK('GraphicsSettingApplied')
end

M.handleSetRelativeCam = function(request)
  core_camera.setByName(0, 'relative', false, {})

  local vid = be:getPlayerVehicle(0):getID()
  local pos = request['pos']
  local rot = request['rot']
  local func = function()
    pos = vec3(pos[1], pos[2], pos[3])
    core_camera.getCameraDataById(vid)['relative'].pos = pos

    if rot ~= nil then
      rot = quat(rot[1], rot[2], rot[3], rot[4]):toEulerYXZ()
      core_camera.getCameraDataById(vid)['relative'].rot = rot
    end

    request:sendACK('RelativeCamSet')
  end
  addFrameDelayFunc(func, 3)
  return false
end

local function tableToPoint3F(point, cling, offset)
  local point = Point3F(point[1], point[2], point[3])
  if cling then
    local z = be:getSurfaceHeightBelow(point)
    point = Point3F(point.x, point.y, z+offset)
  end
  return point
end

M.handleAddDebugSpheres = function(request)
  local sphereIDs = {}
  for idx = 1,#request.radii do
    local coo = tableToPoint3F(request.coordinates[idx], request.cling, request.offset)
    local color = request.colors[idx]
    color = ColorF(color[1], color[2], color[3], color[4])
    local sphere = {coo = coo, radius = request.radii[idx], color = color}
    debugObjectCounter.sphereNum = debugObjectCounter.sphereNum + 1
    debugObjects.spheres[debugObjectCounter.sphereNum] = sphere
    table.insert(sphereIDs, debugObjectCounter.sphereNum)
  end
  local resp = {type = 'DebugSphereAdded', sphereIDs = sphereIDs}
  request:sendResponse(resp)
end

M.handleRemoveDebugObjects = function(request)
  for _, idx in pairs(request.objIDs) do
    debugObjects[request.objType][idx] = nil
  end
  request:sendACK('DebugObjectsRemoved')
end

M.handleAddDebugPolyline = function(request)
  local polyline = {segments = {}}
  polyline.color = ColorF(request.color[1], request.color[2], request.color[3], request.color[4])
  local origin = tableToPoint3F(request.coordinates[1], request.cling, request.offset)
  for i = 2, #request.coordinates do
    local target = tableToPoint3F(request.coordinates[i], request.cling, request.offset)
    local segment = {origin = origin, target = target}
    table.insert(polyline.segments, segment)
    origin = target
  end
  debugObjectCounter.lineNum = debugObjectCounter.lineNum + 1
  table.insert(debugObjects.polylines, debugObjectCounter.lineNum, polyline)
  local resp = {type = 'DebugPolylineAdded', lineID = debugObjectCounter.lineNum}
  request:sendResponse(resp)
end

M.handleAddDebugCylinder = function(request)
  local circleAPos = tableToPoint3F(request.circlePositions[1], false, 0)
  local circleBPos = tableToPoint3F(request.circlePositions[2], false, 0)
  local color = ColorF(request.color[1], request.color[2], request.color[3], request.color[4])
  local cylinder = {circleAPos=circleAPos, circleBPos=circleBPos, radius=request.radius, color=color}
  debugObjectCounter.cylinderNum = debugObjectCounter.cylinderNum + 1
  table.insert(debugObjects.cylinders, debugObjectCounter.cylinderNum, cylinder)
  local resp = {type='DebugCylinderAdded', cylinderID=debugObjectCounter.cylinderNum}
  request:sendResponse(resp)
end

M.handleAddDebugTriangle = function(request)
  local color = ColorF(request.color[1], request.color[2], request.color[3], request.color[4])
  local pointA = tableToPoint3F(request.vertices[1], request.cling, request.offset)
  local pointB = tableToPoint3F(request.vertices[2], request.cling, request.offset)
  local pointC = tableToPoint3F(request.vertices[3], request.cling, request.offset)
  local triangle = {a=pointA, b=pointB, c=pointC, color=color}
  debugObjectCounter.triangleNum = debugObjectCounter.triangleNum + 1
  table.insert(debugObjects.triangles, debugObjectCounter.triangleNum, triangle)
  local resp = {type ='DebugTriangleAdded', triangleID = debugObjectCounter.triangleNum}
  request:sendResponse(resp)
end

M.handleAddDebugRectangle = function(request)
  local color = ColorF(request.color[1], request.color[2], request.color[3], request.color[4])
  local pointA = tableToPoint3F(request.vertices[1], request.cling, request.offset)
  local pointB = tableToPoint3F(request.vertices[2], request.cling, request.offset)
  local pointC = tableToPoint3F(request.vertices[3], request.cling, request.offset)
  local pointD = tableToPoint3F(request.vertices[4], request.cling, request.offset)
  local rectangle = {a=pointA, b=pointB, c=pointC, d=pointD, color=color}
  debugObjectCounter.rectangleNum = debugObjectCounter.rectangleNum + 1
  table.insert(debugObjects.rectangles, debugObjectCounter.rectangleNum, rectangle)
  local resp = {type ='DebugRectangleAdded', rectangleID = debugObjectCounter.rectangleNum}
  request:sendResponse(resp)
end

M.handleAddDebugText = function(request)
  local color = ColorF(request.color[1], request.color[2], request.color[3], request.color[4])
  local origin = tableToPoint3F(request.origin, request.cling, request.offset)
  local content = String(request.content)
  local text = {origin = origin, content = content, color = color}
  debugObjectCounter.textNum = debugObjectCounter.textNum + 1
  table.insert(debugObjects.text, debugObjectCounter.textNum, text)
  local resp = {type ='DebugTextAdded', textID = debugObjectCounter.textNum}
  request:sendResponse(resp)
end

M.handleAddDebugSquarePrism = function(request)
  local color = ColorF(request.color[1], request.color[2], request.color[3], request.color[4])
  local az, bz = request.endPoints[1][3], request.endPoints[2][3]
  local sideA = tableToPoint3F(request.endPoints[1], false, 0)
  local sideB = tableToPoint3F(request.endPoints[2], false, 0)
  local sideADims = Point2F(request.dims[1][1], request.dims[1][2])
  local sideBDims = Point2F(request.dims[2][1], request.dims[2][2])
  local prism = {sideA=sideA, sideB=sideB, sideADims=sideADims, sideBDims=sideBDims, color = color}
  debugObjectCounter.prismNum = debugObjectCounter.prismNum + 1
  table.insert(debugObjects.squarePrisms, debugObjectCounter.prismNum, prism)
  local resp = {type ='DebugSquarePrismAdded', prismID = debugObjectCounter.prismNum}
  request:sendResponse(resp)
end

M.onDrawDebug = function(dtReal, lastFocus)
  for _, sphere in pairs(debugObjects.spheres) do
    debugDrawer:drawSphere(sphere.coo, sphere.radius, sphere.color)
  end
  for _, dSphere in pairs(debugObjects.dynamicSpheres) do
    local spec = dSphere.getSpec()
    debugDrawer:drawSphere(spec.coo, spec.radius, spec.color)
  end
  for _, polyline in pairs(debugObjects.polylines) do
    for _, segment in pairs(polyline.segments) do
      debugDrawer:drawLine(segment.origin, segment.target, polyline.color)
    end
  end
  for _, cylinder in pairs(debugObjects.cylinders) do
    debugDrawer:drawCylinder(cylinder.circleAPos, cylinder.circleBPos, cylinder.radius, cylinder.color)
  end
  for _, triangle in pairs(debugObjects.triangles) do
    debugDrawer:drawTriSolid(triangle.a, triangle.b, triangle.c, triangle.color)
  end
  for _, rectangle in pairs(debugObjects.rectangles) do
    debugDrawer:drawQuadSolid(rectangle.a, rectangle.b, rectangle.c, rectangle.d, rectangle.color)
  end
  for _, line in pairs(debugObjects.text) do
    debugDrawer:drawText(line.origin, line.content, line.color)
  end
  for _, prism in pairs(debugObjects.squarePrisms) do
    debugDrawer:drawSquarePrism(prism.sideA, prism.sideB, prism.sideADims, prism.sideBDims, prism.color)
  end
end

M.handleQueueLuaCommandGE = function(request)
  local func, loading_err = load(request.chunk)
  if func then
    local status, err = pcall(func)
    if not status then
      log('E', 'execution error: "' .. err .. '"')
    end
  else
    log('E', 'compilation error in: "' .. request.chunk .. '"')
  end
  request:sendACK('ExecutedLuaChunkGE')
end

M.handleGetLevels = function(request)
  local list = core_levels.getList()
  local resp = {type = 'GetLevels', result = list}
  request:sendResponse(resp)
end

M.handleGetScenarios = function(request)
  local list = scenario_scenariosLoader.getList(nil, true)
  local resp = {type = 'GetScenarios', result = list}
  request:sendResponse(resp)
end

M.handleGetCurrentScenario = function(request)
  if not scenario_scenarios and not getRunningFlowgraphManager() then
    request:sendBNGValueError('No scenario loaded.')
    return false
  end

  local sourceFile
  if scenario_scenarios then
    sourceFile = scenario_scenarios.getScenario().sourceFile
  else
    local fgMgr = getRunningFlowgraphManager()
    local name = string.gsub(fgMgr.savedFilename, "(.*)%.flow.json", "%1")
    sourceFile = fgMgr.savedDir .. name .. '.json'
    if string.sub(sourceFile, 1, 1) ~= '/' then
      sourceFile = '/' .. sourceFile
    end
  end

  -- Horribly inefficient but the scenario object returned by the extension contains a lot of fields
  -- that are not serializable and not suitable to be sent over the socket so we find the respective
  -- scenario entry in the list of all scenarios instead
  -- TODO: Filter out unserializable fields from scenario object and send those instead
  local scenarios = scenario_scenariosLoader.getList()
  local scenario = nil
  for i = 1, #scenarios do
    if scenarios[i].sourceFile == sourceFile then
      scenario = scenarios[i]
      break
    end
  end

  local resp = {type = 'GetCurrentScenario', result = scenario}
  request:sendResponse(resp)
end

M.handleCreateScenario = function(request)
  local name = request['name']
  local level = request['level']
  local prefab = request['prefab']
  local info = request['info']

  if name == nil then
    request:sendBNGValueError('Scenario needs a name.')
    return false
  end

  if level == nil then
    request:sendBNGValueError('Scenario needs an associated level.')
    return false
  end

  if info == nil then
    request:sendBNGValueError('Scenario needs an info file definition.')
    return false
  end

  local path = '/levels/' .. level .. '/scenarios/'
  local infoPath = path .. name .. '.json'

  local writePrefab = true
  if prefab ~= nil then
    local prefabPath = path .. name .. '.prefab'
    local existingFile = io.open(prefabPath, 'r')
    if existingFile then
      local content = existingFile:read('a')
      -- when a prefab file is rewritten, the game reloads the vehicles in it, causing a bug
      -- this check is to limit this buggy behaviour until it is fixed in the game engine
      if content == prefab then
        writePrefab = false
      end
      existingFile:close()
    end

    if writePrefab then
      local outFile = io.open(prefabPath, 'w')
      if not outFile then
        request:sendBNGValueError('Could not write scenario prefab file.')
        return false
      end
      outFile:write(prefab)
      outFile:flush()
      outFile:close()

      local scenario = scenario_scenarios and scenario_scenarios.getScenario()
      if scenario and scenario.sourceFile == infoPath then
        log('W', 'Overwritten currently loaded scenario\'s prefab file. The scenario has to be stopped.')
        returnToMainMenu()
      end
    end
  end

  local outFile = io.open(infoPath, 'w')
  if not outFile then
    request:sendBNGValueError('Could not write scenario info file.')
    return false
  end
  outFile:write(jsonEncode({info}))
  outFile:flush()
  outFile:close()

  FS:updateDirectoryWatchers() -- late prefab file notification could cause a bug, update explicitly
  local resp = {type = 'CreateScenario', result = infoPath}
  request:sendResponse(resp)
end

M.handleDeleteScenario = function(request)
  local infoPath = request['path']
  local scenarioDir, infoFile, _ = path.splitWithoutExt(infoPath)
  local prefabPath = scenarioDir .. infoFile .. '.prefab'

  FS:removeFile(infoPath)
  FS:removeFile(prefabPath)

  request:sendACK('DeleteScenario')
end

M.handleGetCurrentVehicles = function(request)
  vehicleInfo = {}

  for id, v in pairs(map.objects) do
    local veh = scenetree.findObjectById(id)
    if not veh then
      goto continue
    end

    local info = {}
    info['id'] = id
    info['model'] = veh:getJBeamFilename()
    info['name'] = veh:getName()
    if info['name'] == nil then
      info['name'] = tostring(id)
    end

    if request['include_config'] then
      local playerVeh = be:getPlayerVehicle(0)
      local currentId = playerVeh and playerVeh:getID() or nil
      be:enterVehicle(0, veh)
      info['config'] = core_vehicle_partmgmt.getConfig()
      if playerVeh then
        be:enterVehicle(0, scenetree.findObjectById(currentId))
      else
        be:exitVehicle(0)
      end
    end

    info['options'] = jsonReadFile('/vehicles/' .. info['model'] .. '.json')

    vehicleInfo[id] = info

    vehicleInfoPending = vehicleInfoPending + 1
    veh:queueLuaCommand('extensions.load("tech/techCore")')
    veh:queueLuaCommand('tech_techCore.requestVehicleInfo()')

    ::continue::
  end

  return block('vehicleInfo', request)
end

local function getSceneTreeNode(obj)
  local node = {}
  node.class = obj:getClassName()
  node.name = obj:getName()
  node.id = obj:getID()
  if obj.getObject ~= nil and obj.getCount ~= nil then
    node.children = {}
    local count = obj:getCount()
    for i=0, count - 1 do
      local child = getSceneTreeNode(Sim.upcast(obj:getObject(i)))
      table.insert(node.children, child)
    end
  end
  return node
end

M.handleGetSceneTree = function(request)
  local rootGrp = Sim.upcast(Sim.findObject('MissionGroup'))
  local tree = getSceneTreeNode(rootGrp)
  local resp = {type = 'GetSceneTree', result = tree}
  request:sendResponse(resp)
end

local typeConverters = {}
typeConverters['MatrixPosition'] = function(t)
  return string.split(t)
end
typeConverters['MatrixRotation'] = function(t)
  return string.split(t)
end
typeConverters['Point3F'] = function(t)
  return string.split(t)
end

local function serializeGenericObject(obj)
  local ignoreNames = {
    id = true,
    name = true,
    internalName = true,
    isSelectionEnabled = true,
    isRenderEnabled = true,
    hidden = true,
    canSaveDynamicFields = true,
    canSave = true,
    parentGroup = true,
    persistentId = true,
    rotationMatrix = true,
    class = true,
    superClass = true,
    edge = true,
    plane = true,
    point = true,
  }

  local okayTypes = {
    int = true,
    string = true,
    filename = true,
    float = true,
    MatrixPosition = true,
    MatrixRotation = true,
    annotation = true,
    bool = true,
    Point3F = true,
    ColorF = true,
    TSMeshType = true,
  }

  local position = nil
  if obj.getPosition ~= nil then
    position = obj:getPosition()
    position = {position.x, position.y, position.z}
  else
    position = {0, 0, 0}
  end

  local rotation = nil
  if obj.getRotation ~= nil then
    rotation = obj:getRotation()
    rotation = {rotation.x, rotation.y, rotation.z, rotation.w}
  else
    rotation = {0, 0, 0, 0}
  end

  local scale = nil
  if obj.getScale ~= nil then
    scale = obj:getScale()
    scale = {scale.x, scale.y, scale.z}
  else
    scale = {0, 0, 0}
  end

  local ret = {
    id = obj:getID(),
    name = obj:getName(),
    class = obj:getClassName(),
    position = position,
    rotation = rotation,
    scale = scale
  }

  local fields = obj:getFieldList()
  for field, props in pairs(fields) do
    if ignoreNames[field] == nil then
      local type = props['type']
      if okayTypes[type] then
        local converter = typeConverters[type]
        if converter ~= nil then
          ret[field] = converter(obj:getField(field, ''))
        else
          ret[field] = obj:getField(field, '')
        end
      end
    end
  end

  return ret
end

local objectSerializers = {}
objectSerializers['DecalRoad'] = function(obj)
  local ret = serializeGenericObject(obj)

  local position = obj:getPosition()
  position = {position.x, position.y, position.z}
  local rotation = obj:getRotation()
  rotation = {rotation.x, rotation.y, rotation.z, rotation.w}
  local scale = obj:getScale()
  scale = {scale.x, scale.y, scale.z}

  local annotation = obj:getField('annotation', '')
  local detail = obj:getField('Detail', '')
  local material = obj:getField('Material', '')
  local breakAngle = obj:getField('breakAngle', '')
  local drivability = obj:getField('drivability', '')
  local flipDirection = obj:getField('flipDirection', '')
  local improvedSpline = obj:getField('improvedSpline', '')
  local lanesLeft = obj:getField('lanesLeft', '')
  local lanesRight = obj:getField('lanesRight', '')
  local oneWay = obj:getField('oneWay', '')
  local overObjects = obj:getField('overObjects', '')

  local lines = {}
  local edges = obj:getEdgesTable()
  for i = 1, #edges do
    local edge = edges[i]
    table.insert(lines, {
      left = {
        edge[1].x,
        edge[1].y,
        edge[1].z
      },
      middle = {
        edge[2].x,
        edge[2].y,
        edge[2].z
      },
      right = {
        edge[3].x,
        edge[3].y,
        edge[3].z
      }
    })
  end

  ret.lines = lines

  return ret
end

M.handleGetObject = function(request)
  local id = request['id']
  local obj = Sim.findObjectById(id)
  if obj ~= nil then
    obj = Sim.upcast(obj)
    local class = obj:getClassName()
    local serializer = objectSerializers[class]
    if serializer ~= nil then
      obj = serializer(obj)
    else
      obj = serializeGenericObject(obj)
    end
    local resp = {type = 'GetObject', result = obj}
    request:sendResponse(resp)
  else
    request:sendBNGValueError('Unknown object ID: ' .. tostring(id))
  end
end

M.handleGetPartConfig = function(request)
  local vid = request['vid']
  local veh = scenetree.findObject(vid)
  local cur = be:getPlayerVehicle(0)
  if cur ~= nil then
    cur = cur:getID()
  end

  be:enterVehicle(0, veh)
  local cfg = core_vehicle_partmgmt.getConfig()
  local resp = {type = 'PartConfig', config = cfg}

  if cur ~= nil then
    veh = scenetree.findObjectById(cur)
    be:enterVehicle(0, veh)
  end

  request:sendResponse(resp)
end

M.handleGetPartOptions = function(request)
  local vid = request['vid']
  local veh = scenetree.findObject(vid)
  local cur = be:getPlayerVehicle(0):getID()
  be:enterVehicle(0, veh)
  local data = core_vehicle_manager.getPlayerVehicleData()
  local slotMap = jbeamIO.getAvailableSlotMap(data.ioCtx)
  local resp = {type = 'PartOptions', options = slotMap}
  veh = scenetree.findObjectById(cur)
  be:enterVehicle(0, veh)
  request:sendResponse(resp)
end

M.handleSetPartConfig = function(request)
  local vid = request['vid']
  local veh = scenetree.findObject(vid)
  local cur = be:getPlayerVehicle(0):getID()
  be:enterVehicle(0, veh)
  local cfg = request['config']
  core_vehicle_partmgmt.setConfig(cfg)
  veh = scenetree.findObjectById(cur)
  be:enterVehicle(0, veh)
end

M.handleSetPlayerCameraMode = function(request)
  local vid = request['vid']
  local mode = request['mode']
  local config = request['config']
  local customData = request['customData']

  local veh = scenetree.findObject(vid)
  local id = veh:getID()
  core_camera.setVehicleCameraByNameWithId(id, mode, nil, customData)

  for k, v in pairs(config) do
    if k == 'rotation' then
      local rotation = vec3(v[1], v[2], v[3])
      core_camera.setRotation(id, rotation)
    end

    if k == 'fov' then
      core_camera.setFOV(id, v)
    end

    if k == 'offset' then
      local offset = vec3(v[1], v[2], v[3])
      core_camera.setOffset(id, offset)
    end

    if k == 'distance' then
      core_camera.setDistance(id, v)
    end
  end

  request:sendACK('PlayerCameraModeSet')
end

M.handleGetPlayerCameraMode = function(request)
  local vid = request['vid']
  local veh = scenetree.findObject(vid)
  -- Serialize & deserialize to get rid of data MessagePack can't serialize
  local cameraData = deserialize(serialize(core_camera.getCameraDataById(veh:getID())))
  cameraData['unicycle'] = nil
  cameraData = rcom.sanitizeTable(cameraData)
  local resp = {type = 'PlayerCameraMode', cameraData = cameraData}
  request:sendResponse(resp)
end

M.handleLoadTrackBuilderTrack = function(request)
  local trackPath = request['path']
  if not FS:fileExists(trackPath) then
    request:sendBNGValueError('The track file does not exist.')
    return false
  end

  local _, filename, _ = path.split(sanitizePath(trackPath))

  local tb = extensions['util_trackBuilder_splineTrack']
  tb.load(readJsonFile(trackPath), true, nil, nil, true, false)

  -- rename the created meshes so multiple trackbuilder mesh names don't collide
  for _, objName in ipairs(scenetree.findClassObjects("ProceduralMesh")) do
    if string.find(objName, "procMesh") and not string.find(objName, ".json") then
      scenetree.findObject(objName):setName(filename..'-'..objName)
    end
  end
  tb.unloadAll()

  request:sendACK('TrackBuilderTrackLoaded')
end

M.handleSetLicensePlate = function(request)
  local veh = scenetree.findObject(request['vid'])
  if not veh then
    request:sendBNGValueError('Vehicle not found: "' .. tostring(request['vid']) .. '"')
    return false
  end
  core_vehicles.setPlateText(request['text'], veh:getID())
end

M.handleGetSystemInfo = function(request)
  local response = {}
  response['tech'] = ResearchVerifier.isTechLicenseVerified()
  if request['os'] then
    response['os'] = Engine.Platform.getOSInfo()
  end
  if request['power'] then
    response['power'] = Engine.Platform.getPowerInfo()
  end
  if request['cpu'] then
    response['cpu'] = Engine.Platform.getCPUInfo()
  end
  if request['gpu'] then
    response['gpu'] = Engine.Platform.getGPUInfo()
  end

  request:sendResponse(response)
end

return M
