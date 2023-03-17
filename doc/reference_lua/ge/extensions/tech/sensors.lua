-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

-- Vlua ad-hoc request data.
local requestId = -1                            -- The counter for unique vlua ad-hoc request Id numbers.
local adHocVluaRequests = {}                    -- The collection of pending ad-hoc requests for vlua sensors.

-- AVlua sensor readings data.
local advancedIMULastRawReadings = {}           -- Most recently-read Advanced IMU data (this is a table).
local powertrainLastRawReadings = {}            -- Most recently-read Powertrain data (this is a table)

-- Ultrasonic sensor visualisation data/parameters.
local visualisedUltrasonicSensors = {}
local pulseWidthDispersion = 0.1  -- The rate of longitudinal growth of the pulse (width). Used for the ultrasonic sensor visualisation.
local minPulseWidth = 0.1         -- The minimum possible displayed pulse width. Used for the ultrasonic sensor visualisation.
local maxPulseWidth = 0.25        -- The maximum possible displayed pulse width. Used for the ultrasonic sensor visualisation.
local minAlpha = 0.02             -- The smallest possible displayed alpha channel value. Used for the ultrasonic sensor visualisation.
local maxDistance = 6.0           -- The maximum distance that the animated pulse can travel, before being considered unsuccessful.
local animationPeriod = 1.50      -- The animation wave period length (in seconds). Used for the ultrasonic sensor visualisation.
local animationSpeed = 6.0        -- The animation wave speed (in m/s). Used for the ultrasonic sensor visualisation.

local function unpack_float(b4, b3, b2, b1)
  local sign = b1 > 0x7F and -1 or 1
  local expo = (b1 % 0x80) * 0x2 + math.floor(b2 / 0x80)
  local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4
  if mant == 0 and expo == 0 then
    return sign * 0
  elseif expo == 0xFF then
    return mant == 0 and sign * math.huge or 0/0
  else
    return sign * math.ldexp(1 + mant / 0x800000, expo - 0x7F)
  end
end

local function getUniqueRequestId()
  requestId = requestId + 1
  return requestId
end

local function doesSensorExist(sensorId)
  return Research.SensorManager.doesSensorExist(sensorId)
end

local function removeSensor(sensorId)
  Research.SensorManager.removeSensor(sensorId)
end

local function removeAllSensorsFromVehicle(vid)
  Research.SensorManager.removeSensorByVid(vid)
end

local function getAverageUpdateTime(sensorId)
  return Research.GpuRequestManager.getAverageUpdateTime(sensorId)
end

local function getMaxLoadPerFrame()
  return Research.GpuRequestManager.getMaxLoadPerFrame()
end

local function setMaxLoadPerFrame(maxLoadPerFrame)
  Research.GpuRequestManager.setMaxLoadPerFrame(maxLoadPerFrame)
end

local function sendCameraRequest(sensorId)
  return Research.GpuRequestManager.sendAdHocCameraGpuRequest(sensorId)
end

local function sendLidarRequest(sensorId)
  return Research.GpuRequestManager.sendAdHocLidarGpuRequest(sensorId)
end

local function sendUltrasonicRequest(sensorId)
  return Research.GpuRequestManager.sendAdHocUltrasonicGpuRequest(sensorId)
end

local function collectCameraRequest(requestId)
  return Research.GpuRequestManager.collectAdHocCameraGpuRequest(requestId)
end

local function collectLidarRequest(requestId)
  return Research.GpuRequestManager.collectAdHocLidarGpuRequest(requestId)
end

local function collectUltrasonicRequest(requestId)
  return Research.GpuRequestManager.collectAdHocUltrasonicGpuRequest(requestId)
end

local function isRequestComplete(requestId)
  return Research.GpuRequestManager.isAdHocGpuRequestComplete(requestId)
end

-- TODO Should be replaced when GE-2170 is complete.
local function getFullCameraRequest(sensorId)
  Engine.Annotation.enable(true)
  AnnotationManager.setInstanceAnnotations(false)
  local semanticData = Research.GpuRequestManager.sendBlockingCameraGpuRequest(sensorId)
  AnnotationManager.setInstanceAnnotations(true)
  local fcrVehicleColors = {}
  for k, v in pairs(map.objects) do
    local veh = scenetree.findObject(k)
    if fcrVehicleColors[k] == nil then
      fcrVehicleColors[k] = ColorI(math.ceil(255 * math.random()), math.ceil(255 * math.random()), math.ceil(255 * math.random()), 255)
    end
    local meshes = veh:getMeshNames()
    for i = 1, #meshes do
      veh:setMeshAnnotationColor(meshes[i], fcrVehicleColors[k])
    end
  end
  local instanceData = Research.GpuRequestManager.sendBlockingCameraGpuRequest(sensorId)
  for k, v in pairs(map.objects) do
    local veh = scenetree.findObject(k)
    local meshes = veh:getMeshNames()
    for i = 1, #meshes do
      veh:setMeshAnnotationColor(meshes[i], ColorI(0, 255, 0, 255))
    end
  end
  AnnotationManager.setInstanceAnnotations(false)
  Engine.Annotation.enable(false)
  local out = {}
  out['colour'] = instanceData['colour']
  out['annotation'] = semanticData['annotation']
  out['depth'] = instanceData['depth']
  out['instance'] = instanceData['annotation']
  return out
end

local function sendAdvancedIMURequest(sensorId, vid)
  local requestId = getUniqueRequestId()
  local vehicleId = scenetree.findObject(vid):getID();
  be:queueObjectLua(vehicleId, "extensions.tech_advancedIMU.adHocRequest(" .. sensorId .. ", " .. requestId .. ")")
  return requestId
end

local function collectAdvancedIMURequest(requestId)
  if adHocVluaRequests[requestId] ~= nil then
    local data = adHocVluaRequests[requestId]
    adHocVluaRequests[requestId] = nil
    return data
  end
  return false
end

local function sendPowertrainRequest(sensorId, vid)
  local requestId = getUniqueRequestId()
  local vehicleId = scenetree.findObject(vid):getID();
  be:queueObjectLua(vehicleId, "extensions.tech_powertrainSensor.adHocRequest(" .. sensorId .. ", " .. requestId .. ")")
  return requestId
end

local function collectPowertrainRequest(requestId)
  if adHocVluaRequests[requestId] ~= nil then
    local data = adHocVluaRequests[requestId]
    adHocVluaRequests[requestId] = nil
    return data
  end
  return false
end

local function isVluaRequestComplete(requestId)
  if adHocVluaRequests[requestId] ~= nil then
    return true
  end
  return true
end

local function attachSensor(sensorId, pos, dir, up, vid, isSensorStatic, isSnappingDesired, forceInsideTriangle, isAllowWheelNodes)
  Research.SensorMatrixManager.attachSensor(sensorId, pos, dir, up, vid, isSensorStatic, isSnappingDesired, forceInsideTriangle, isAllowWheelNodes)
end

local function getSensorMatrix(sensorId)
  Research.SensorMatrixManager.getSensorMatrixExternal(sensorId)
end

local function getWorldFrame(sensorId)
  return Research.SensorMatrixManager.getWorldFrameVectors(sensorId)
end

local function getLocalFrame(sensorId)
  return Research.SensorMatrixManager.getLocalFrameVectors(sensorId)
end

local function getClosestTriangle(vid, point, includeWheelNodes)
  return Research.SensorMatrixManager.getClosestTriangle(vid, point, includeWheelNodes)
end

local function createCamera(vid, args)
  return Research.SensorManager.createCameraSensorWithoutSharedMemory(vid, args)
end

local function createCameraWithSharedMemory(vid, args)
  return Research.SensorManager.createCameraSensorWithSharedMemory(vid, args)
end

local function getCameraData(sensorId)
  return Research.Camera.getLastCameraData(sensorId)
end

local function getCameraDataShmem(sensorId)
  return Research.Camera.getLastCameraDataShmem(sensorId)
end

local function processCameraData(sensorId)
  local binary = Research.Camera.getLastCameraData(sensorId)
  local colourData = {}
  for i=1,#binary['colour'] do
    table.insert(colourData, binary['colour']:byte(i))
  end
  local annotationData = {}
  for i=1,#binary['annotation'] do
    table.insert(annotationData, binary['annotation']:byte(i))
  end
  local depthData = {}
  local dd = binary['depth']
  for i=1,#dd, 4 do
    table.insert(depthData, unpack_float(dd:byte(i), dd:byte(i + 1), dd:byte(i + 2), dd:byte(i + 3)))
  end
  return { colour = colourData, annotation = annotationData, depth = depthData}
end

local function getCameraSensorPosition(sensorId)
  return Research.Camera.getSensorPosition(sensorId)
end

local function getCameraSensorDirection(sensorId)
  return Research.Camera.getSensorDirection(sensorId)
end

local function getCameraSensorUp(sensorId)
  return Research.Camera.getSensorUp(sensorId)
end

local function getCameraMaxPendingGpuRequests(sensorId)
  return Research.Camera.getMaxPendingGpuRequests(sensorId)
end

local function getCameraRequestedUpdateTime(sensorId)
  return Research.Camera.getRequestedUpdateTime(sensorId)
end

local function getCameraUpdatePriority(sensorId)
  return Research.Camera.getUpdatePriority(sensorId)
end

local function setCameraSensorPosition(sensorId, pos)
  Research.Camera.setSensorPosition(sensorId, pos)
end

local function setCameraSensorDirection(sensorId, dir)
  Research.Camera.setSensorDirection(sensorId, dir)
end

local function setCameraSensorUp(sensorId, up)
  Research.Camera.setSensorUp(sensorId, up)
end

local function setCameraMaxPendingGpuRequests(sensorId, maxPendingGpuRequests)
  Research.Camera.setMaxPendingGpuRequests(sensorId, maxPendingGpuRequests)
end

local function setCameraRequestedUpdateTime(sensorId, requestedUpdateTime)
  Research.Camera.setRequestedUpdateTime(sensorId, requestedUpdateTime)
end

local function setCameraUpdatePriority(sensorId, priority)
  Research.Camera.setUpdatePriority(sensorId, priority)
end

local function convertWorldPointToPixel(sensorId, point)
  return Research.Camera.convertWorldPointToPixel(sensorId, point)
end

local function createLidar(vid, args)
  return Research.SensorManager.createLidarSensorWithoutSharedMemory(vid, args)
end

local function createLidarWithSharedMemory(vid, args)
  return Research.SensorManager.createLidarSensorWithSharedMemory(vid, args)
end

local function getLidarPointCloud(sensorId)
  return Research.Lidar.getLastPointCloudData(sensorId)
end

local function getLidarColourData(sensorId)
  return Research.Lidar.getLastColourData(sensorId)
end

local function getLidarPointCloudShmem(sensorId)
  return Research.Lidar.getLastPointCloudDataShmem(sensorId)
end

local function getLidarColourDataShmem(sensorId)
  return Research.Lidar.getLastColourDataShmem(sensorId)
end

local function getLidarDataPositions(sensorId)
  local pts = Research.Lidar.getLastPointCloudData(sensorId)
  local pointsData = {}
  for i=1,#pts, 12 do
    local x = unpack_float(pts:byte(i), pts:byte(i + 1), pts:byte(i + 2), pts:byte(i + 3))
    local y = unpack_float(pts:byte(i + 4), pts:byte(i + 5), pts:byte(i + 6), pts:byte(i + 7))
    local z = unpack_float(pts:byte(i + 8), pts:byte(i + 9), pts:byte(i + 10), pts:byte(i + 11))
    table.insert(pointsData, vec3(x, y, z))
  end
  local colourBinary = Research.Lidar.getLastColourData(sensorId)
  local colourData = {}
  for i=1,#colourBinary do
    table.insert(colourData, colourBinary:byte(i))
  end
  return { pointCloud = pointsData, colour = colourData}
end

local function getActiveLidarSensors()
  return Research.Lidar.getActiveLidarSensors()
end

local function getLidarSensorPosition(sensorId)
  return Research.Lidar.getSensorPosition(sensorId)
end

local function getLidarSensorDirection(sensorId)
  return Research.Lidar.getSensorDirection(sensorId)
end

local function getLidarVerticalResolution(sensorId)
  return Research.Lidar.getVerticalRes(sensorId)
end

local function getLidarRaysPerSecond(sensorId)
  return Research.Lidar.getRaysPerSecond(sensorId)
end

local function getLidarFrequency(sensorId)
  return Research.Lidar.getFrequency(sensorId)
end

local function getLidarMaxDistance(sensorId)
  return Research.Lidar.getMaxDistance(sensorId)
end

local function getLidarIsVisualised(sensorId)
  return Research.Lidar.getIsVisualised(sensorId)
end

local function getLidarIsAnnotated(sensorId)
  return Research.Lidar.getIsAnnotated(sensorId)
end

local function getLidarMaxPendingGpuRequests(sensorId)
  return Research.Lidar.getMaxPendingGpuRequests(sensorId)
end

local function getLidarRequestedUpdateTime(sensorId)
  return Research.Lidar.getRequestedUpdateTime(sensorId)
end

local function getLidarUpdatePriority(sensorId)
  return Research.Lidar.getUpdatePriority(sensorId)
end

local function setLidarVerticalResolution(sensorId, verticalResolution)
  Research.Lidar.setVerticalRes(sensorId, verticalResolution)
end

local function setLidarRaysPerSecond(sensorId, raysPerSecond)
  Research.Lidar.setRaysPerSecond(sensorId, raysPerSecond)
end

local function setLidarFrequency(sensorId, frequency)
  Research.Lidar.setFrequency(sensorId, frequency)
end

local function setLidarMaxDistance(sensorId, maxDistance)
  Research.Lidar.setMaxDistance(sensorId, maxDistance)
end

local function setLidarIsVisualised(sensorId, isVisualised)
  Research.Lidar.setIsVisualised(sensorId, isVisualised)
end

local function setLidarIsAnnotated(sensorId, isAnnotated)
  Research.Lidar.setIsAnnotated(sensorId, isAnnotated)
end

local function setLidarMaxPendingGpuRequests(sensorId, maxPendingGpuRequests)
  Research.Lidar.setMaxPendingGpuRequests(sensorId, maxPendingGpuRequests)
end

local function setLidarRequestedUpdateTime(sensorId, requestedUpdateTime)
  Research.Lidar.setRequestedUpdateTime(sensorId, requestedUpdateTime)
end

local function setLidarUpdatePriority(sensorId, updatePriority)
  Research.Lidar.setUpdatePriority(sensorId, updatePriority)
end

local function createUltrasonic(vid, args)
  local sensorId = Research.SensorManager.createUltrasonicSensor(vid, args)
  if args.isVisualised or args.isVisualised == nil  then
    visualisedUltrasonicSensors[sensorId] = { animationTime = 0.0 }
  end
  return sensorId
end

local function getUltrasonicReadings(sensorId)
  return Research.Ultrasonic.getLastReadings(sensorId)
end

local function getActiveUltrasonicSensors()
  return Research.Ultrasonic.getActiveUltrasonicSensors()
end

local function getUltrasonicIsVisualised(sensorId)
  return visualisedUltrasonicSensors[sensorId] ~= nil
end

local function getUltrasonicMaxPendingGpuRequests(sensorId)
  return Research.Ultrasonic.getMaxPendingGpuRequests(sensorId)
end

local function getUltrasonicRequestedUpdateTime(sensorId)
  return Research.Ultrasonic.getRequestedUpdateTime(sensorId)
end

local function getUltrasonicUpdatePriority(sensorId)
  return Research.Ultrasonic.getUpdatePriority(sensorId)
end

local function setUltrasonicIsVisualised(sensorId, isVisualised)
  if isVisualised then
    visualisedUltrasonicSensors[sensorId] = { animationTime = 0.0 }
  else
    visualisedUltrasonicSensors[sensorId] = nil
  end
end

local function getUltrasonicSensorPosition(sensorId)
  return Research.Ultrasonic.getSensorPosition(sensorId)
end

local function getUltrasonicSensorDirection(sensorId)
  return Research.Ultrasonic.getSensorDirection(sensorId)
end

local function getUltrasonicSensorRadius(sensorId, distanceFromSensor)
  return Research.Ultrasonic.getSensorRadius(sensorId, distanceFromSensor)
end

local function setUltrasonicMaxPendingGpuRequests(sensorId, maxPendingGpuRequests)
  Research.Lidar.setMaxPendingGpuRequests(sensorId, maxPendingGpuRequests)
end

local function setUltrasonicRequestedUpdateTime(sensorId, requestedUpdateTime)
  Research.Lidar.setRequestedUpdateTime(sensorId, requestedUpdateTime)
end

local function setUltrasonicUpdatePriority(sensorId, updatePriority)
  Research.Lidar.setUpdatePriority(sensorId, updatePriority)
end

local function visualiseUltrasonicSensor(sensorId, dtSim)
  -- If this sensor no longer exists, remove from visualisation array and leave early.
  if not doesSensorExist(sensorId) then
    visualisedUltrasonicSensors[sensorId] = nil
    return
  end

  -- Get the world space position and direction of this ultrasonic sensor.
  local pos = getUltrasonicSensorPosition(sensorId)
  local dir = getUltrasonicSensorDirection(sensorId):normalized()

  -- Draw the ultrasonic sensor at its current position in world space, in green.
  debugDrawer:drawSphere(pos, 0.05, ColorF(0, 1, 0, 1))

  -- Cycle the animation phase based on the simDt value and the wave parameters (period, speed).
  local animationTime = visualisedUltrasonicSensors[sensorId].animationTime + dtSim
  if animationTime >= animationPeriod then
    animationTime = animationTime - animationPeriod
  end

  visualisedUltrasonicSensors[sensorId].animationTime = animationTime

  -- Get the latest measurements computed by this ultrasonic sensor.
  local lastReadings = getUltrasonicReadings(sensorId)
  local lastDistance = lastReadings['distance']
  local lastWindowMin = lastReadings['windowMin']

  -- Compute the physical distance travelled by the outgoing pulse, at the current animation phase.
  local pulseDistance = animationSpeed * animationTime

  -- If we are in the transmission phase, draw the red transmission pulse (heading outward from the sensor).
  if pulseDistance <= lastDistance then

    -- Compute the centre point of the outward-travelling pulse.
    local pulseCentre = pos + pulseDistance * dir

    -- Compute the half width of the pulse. The pulse slowly disperses longitudinally as the distance increases.
    local halfPulseWidth = math.min(maxPulseWidth, math.max(minPulseWidth, lastDistance - lastWindowMin) + pulseDistance * pulseWidthDispersion)

    -- Compute the top and bottom cylinder points for the pulse. We use the measurement window width as the height.
    local halfCylinderVector = halfPulseWidth * dir
    local firstPoint = pulseCentre - halfCylinderVector
    local secondPoint = pulseCentre + halfCylinderVector

    -- Compute the radius and alpha channel value for the pulse at this distance.
    local radius = getUltrasonicSensorRadius(sensorId, pulseDistance)
    local alpha = math.max(minAlpha, 1.0 - pulseDistance)

    -- Draw a red cylinder to represent the outgoing pulse.
    debugDrawer:drawCylinder(firstPoint, secondPoint, radius, ColorF(1, 0, 0, alpha))
  else

    local bounceDistance = pulseDistance - lastDistance

    -- Compute the physical distance travelled by the returning pulse.
    local pulseDistance = lastDistance - bounceDistance

    -- If we have reached the sensor position, stop the returning pulse animation.
    if pulseDistance < 0 then
      return
    end

    -- Compute the centre point of the returning pulse.
    local pulseCentre = pos + pulseDistance * dir

    -- Compute the half width of the pulse. The pulse slowly disperses longitudinally as the distance increases.
    local halfPulseWidth = math.max(minPulseWidth, lastDistance - lastWindowMin) + bounceDistance * pulseWidthDispersion

    -- Compute the top and bottom cylinder points for the pulse. We use the measurement window width as the height.
    local halfCylinderVector = halfPulseWidth * dir
    local firstPoint = pulseCentre - halfCylinderVector
    local secondPoint = pulseCentre + halfCylinderVector

    -- Compute the radius and alpha channel value for the pulse at this distance.
    local radius = getUltrasonicSensorRadius(sensorId, lastDistance) + bounceDistance * 0.1
    local alpha = math.max(minAlpha, 1 - bounceDistance)

    -- Draw a blue cylinder to represent the returning pulse. The radius grows linearly for this pulse (unlike the outgoing pulse).
    debugDrawer:drawCylinder(firstPoint, secondPoint, radius, ColorF(0, 0, 1, alpha))
  end
end

local function createAdvancedIMU(vid, args)

  -- Set optional parameters to defaults if they are not provided by the user.
  if args.pos == nil then args.pos = vec3(0, 0, 3) end
  if args.dir == nil then args.dir = vec3(0, -1, 0) end
  if args.up == nil then args.up = vec3(0, 0, 1) end
  if args.GFXUpdateTime == nil then args.GFXUpdateTime = 0.1 end
  if args.isUseGravity == nil then args.isUseGravity = false end
  if args.isVisualised == nil then args.isVisualised = true end
  if args.isSnappingDesired == nil then args.isSnappingDesired = true end
  if args.isForceInsideTriangle == nil then args.isForceInsideTriangle = true end
  if args.isAllowWheelNodes == nil then args.isAllowWheelNodes = false end
  if args.physicsUpdateTime == nil then args.physicsUpdateTime = 0.015 end

  -- The user should provide either a window width or a cutoff frequency for the filtering.
  if args.windowWidth == nil and args.frequencyCutoff == nil then args.windowWidth = 50 end

  -- Attach the sensor to the vehicle.
  local sensorId = Research.SensorManager.getNewSensorId()
  Research.SensorMatrixManager.attachSensor(sensorId, args.pos, args.dir, args.up, vid, false, args.isSnappingDesired,
    args.isForceInsideTriangle, args.isAllowWheelNodes)
  local attachData = Research.SensorMatrixManager.getAttachData(sensorId)

  -- Create the AdvancedIMU in vlua.
  local data =
  {
    sensorId = sensorId,
    GFXUpdateTime = args.GFXUpdateTime,
    physicsUpdateTime = args.physicsUpdateTime,
    isUsingGravity = args.isUseGravity,
    nodeIndex1 = attachData['nodeIndex1'],
    nodeIndex2 = attachData['nodeIndex2'],
    nodeIndex3 = attachData['nodeIndex3'],
    u = attachData['u'],
    v = attachData['v'],
    signedProjDist = attachData['signedProjDist'],
    triangleSpaceForward = attachData['triangleSpaceForward'],
    triangleSpaceUp = attachData['triangleSpaceUp'],
    isVisualised = args.isVisualised,
    windowWidth = args.windowWidth,
    frequencyCutoff = args.frequencyCutoff
  }
  local serializedData = string.format("extensions.tech_advancedIMU.create(%q)", lpack.encode(data))
  be:queueObjectLua(vid, serializedData)

  advancedIMULastRawReadings[sensorId] = {}

  return sensorId
end

local function removeAdvancedIMU(vid, sensorId)
  local vehicleId = scenetree.findObject(vid):getID()
  be:queueObjectLua(vehicleId, "extensions.tech_advancedIMU.remove(" .. sensorId .. ")")
  advancedIMULastRawReadings[sensorId] = nil
end

local function getAdvancedIMUReadings(sensorId)
  return advancedIMULastRawReadings[sensorId]
end

local function updateAdvancedIMULastReadings(data)
  local d = lpack.decode(data)
  advancedIMULastRawReadings[d.sensorId] = d.reading
end

local function updateAdvancedIMUAdHocRequest(data)
  local d = lpack.decode(data)
  adHocVluaRequests[d.requestId] = d.reading
end

local function setAdvancedIMUUpdateTime(sensorId, vid, updateTime)
  local vehicleId = scenetree.findObject(vid):getID();
  be:queueObjectLua(vehicleId, "extensions.tech_advancedIMU.setUpdateTime(" .. sensorId .. ", " .. updateTime .. ")")
end

local function setAdvancedIMUIsUsingGravity(sensorId, vid, isUsingGravity)
  local data = { sensorId = sensorId, isUsingGravity = isUsingGravity }
  local serialisedData = string.format("extensions.tech_advancedIMU.setIsUsingGravity(%q)", lpack.encode(data))
  be:queueObjectLua(scenetree.findObject(vid):getID(), serialisedData)
end

local function setAdvancedIMUIsVisualised(sensorId, vid, isVisualised)
  local data = { sensorId = sensorId, isVisualised = isVisualised }
  local serialisedData = string.format("extensions.tech_advancedIMU.setIsVisualised(%q)", lpack.encode(data))
  be:queueObjectLua(scenetree.findObject(vid):getID(), serialisedData)
end

local function createPowertrainSensor(vid, args)

  -- Set optional parameters to defaults if they are not provided by the user.
  if args.GFXUpdateTime == nil then args.GFXUpdateTime = 0.1 end
  if args.physicsUpdateTime == nil then args.physicsUpdateTime = 0.015 end

  -- Get a unique sensor Id for this Powertrain sensor.
  local sensorId = Research.SensorManager.getNewSensorId()

  -- Create the Powertrain in vlua.
  local data = { sensorId = sensorId, GFXUpdateTime = args.GFXUpdateTime, physicsUpdateTime = args.physicsUpdateTime }
  local serializedData = string.format("extensions.tech_powertrainSensor.create(%q)", lpack.encode(data))
  be:queueObjectLua(vid, serializedData)

  powertrainLastRawReadings[sensorId] = {}

  return sensorId
end

local function removePowertrainSensor(vid, sensorId)
  local vehicleId = scenetree.findObject(vid):getID()
  be:queueObjectLua(vehicleId, "extensions.tech_powertrainSensor.remove(" .. sensorId .. ")")
  powertrainLastRawReadings[sensorId] = nil
end

local function getPowertrainReadings(sensorId)
  return powertrainLastRawReadings[sensorId]
end

local function updatePowertrainLastReadings(data)
  local d = lpack.decode(data)
  powertrainLastRawReadings[d.sensorId] = d.reading
end

local function updatePowertrainAdHocRequest(data)
  local d = lpack.decode(data)
  adHocVluaRequests[d.requestId] = d.reading
end

local function setPowertrainUpdateTime(sensorId, vid, updateTime)
  local vehicleId = scenetree.findObject(vid):getID();
  be:queueObjectLua(vehicleId, "extensions.tech_powertrainSensor.setUpdateTime(" .. sensorId .. ", " .. updateTime .. ")")
end

local function onUpdate(dtReal, dtSim, dtRaw)
  for sensorId, _ in pairs(visualisedUltrasonicSensors) do
    visualiseUltrasonicSensor(sensorId, dtSim)              -- Perform visualisation for all ultrasonic sensors which require it.
  end
end

local function onVehicleDestroyed(vid)
  removeAllSensorsFromVehicle(vid)                          -- Removes any sensors attached to the destroyed vehicle.
end

-- Public interface:

-- General sensor functions.
M.doesSensorExist                           = doesSensorExist
M.removeSensor                              = removeSensor
M.removeAllSensorsFromVehicle               = removeAllSensorsFromVehicle

-- GPU manager functions.
M.getAverageUpdateTime                      = getAverageUpdateTime
M.getMaxLoadPerFrame                        = getMaxLoadPerFrame
M.setMaxLoadPerFrame                        = setMaxLoadPerFrame

-- Ad-hoc sensor reading functions (for C++ managed sensors).
M.getFullCameraRequest                      = getFullCameraRequest            -- TODO This hack should be replaced when GE-2170 is complete.
M.sendCameraRequest                         = sendCameraRequest
M.sendLidarRequest                          = sendLidarRequest
M.sendUltrasonicRequest                     = sendUltrasonicRequest
M.collectCameraRequest                      = collectCameraRequest
M.collectLidarRequest                       = collectLidarRequest
M.collectUltrasonicRequest                  = collectUltrasonicRequest
M.isRequestComplete                         = isRequestComplete

-- Ad-hoc sensor reading functions (for Lua sensors with a vlua controller).
M.sendAdvancedIMURequest                    = sendAdvancedIMURequest
M.collectAdvancedIMURequest                 = collectAdvancedIMURequest
M.sendPowertrainRequest                     = sendPowertrainRequest
M.collectPowertrainRequest                  = collectPowertrainRequest
M.isVluaRequestComplete                     = isVluaRequestComplete           -- this query is generic to any request from vlua.

-- Sensor matrix manager functions.
M.attachSensor                              = attachSensor
M.getSensorMatrix                           = getSensorMatrix
M.getWorldFrame                             = getWorldFrame
M.getLocalFrame                             = getLocalFrame
M.getClosestTriangle                        = getClosestTriangle

-- Camera-specific sensor functions.
M.createCamera                              = createCamera
M.createCameraWithSharedMemory              = createCameraWithSharedMemory
M.getCameraData                             = getCameraData                   -- returns a binary string.
M.getCameraDataShmem                        = getCameraDataShmem
M.processCameraData                         = processCameraData               -- returns processed data.
M.getCameraSensorPosition                   = getCameraSensorPosition
M.getCameraSensorDirection                  = getCameraSensorDirection
M.getCameraSensorUp                         = getCameraSensorUp
M.getCameraMaxPendingGpuRequests            = getCameraMaxPendingGpuRequests
M.getCameraRequestedUpdateTime              = getCameraRequestedUpdateTime
M.getCameraUpdatePriority                   = getCameraUpdatePriority
M.setCameraSensorPosition                   = setCameraSensorPosition
M.setCameraSensorDirection                  = setCameraSensorDirection
M.setCameraSensorUp                         = setCameraSensorUp
M.setCameraMaxPendingGpuRequests            = setCameraMaxPendingGpuRequests
M.setCameraRequestedUpdateTime              = setCameraRequestedUpdateTime
M.setCameraUpdatePriority                   = setCameraUpdatePriority
M.convertWorldPointToPixel                  = convertWorldPointToPixel

-- LiDAR-specific sensor functions.
M.createLidar                               = createLidar
M.createLidarWithSharedMemory               = createLidarWithSharedMemory
M.getLidarPointCloud                        = getLidarPointCloud              -- returns a binary string.
M.getLidarPointCloudShmem                   = getLidarPointCloudShmem
M.getLidarColourData                        = getLidarColourData              -- returns a binary string.
M.getLidarColourDataShmem                   = getLidarColourDataShmem
M.getLidarDataPositions                     = getLidarDataPositions           -- returns the LiDAR point cloud positions.
M.getActiveLidarSensors                     = getActiveLidarSensors
M.getLidarSensorPosition                    = getLidarSensorPosition
M.getLidarSensorDirection                   = getLidarSensorDirection
M.getLidarVerticalResolution                = getLidarVerticalResolution
M.getLidarRaysPerSecond                     = getLidarRaysPerSecond
M.getLidarFrequency                         = getLidarFrequency
M.getLidarMaxDistance                       = getLidarMaxDistance
M.getLidarIsVisualised                      = getLidarIsVisualised
M.getLidarIsAnnotated                       = getLidarIsAnnotated
M.getLidarMaxPendingGpuRequests             = getLidarMaxPendingGpuRequests
M.getLidarRequestedUpdateTime               = getLidarRequestedUpdateTime
M.getLidarUpdatePriority                    = getLidarUpdatePriority
M.setLidarVerticalResolution                = setLidarVerticalResolution
M.setLidarRaysPerSecond                     = setLidarRaysPerSecond
M.setLidarFrequency                         = setLidarFrequency
M.setLidarMaxDistance                       = setLidarMaxDistance
M.setLidarIsVisualised                      = setLidarIsVisualised
M.setLidarIsAnnotated                       = setLidarIsAnnotated
M.setLidarMaxPendingGpuRequests             = setLidarMaxPendingGpuRequests
M.setLidarRequestedUpdateTime               = setLidarRequestedUpdateTime
M.setLidarUpdatePriority                    = setLidarUpdatePriority

-- Ultrasonic-specific sensor functions.
M.createUltrasonic                          = createUltrasonic
M.getUltrasonicReadings                     = getUltrasonicReadings
M.getActiveUltrasonicSensors                = getActiveUltrasonicSensors
M.getUltrasonicIsVisualised                 = getUltrasonicIsVisualised
M.getUltrasonicMaxPendingGpuRequests        = getUltrasonicMaxPendingGpuRequests
M.getUltrasonicRequestedUpdateTime          = getUltrasonicRequestedUpdateTime
M.getUltrasonicUpdatePriority               = getUltrasonicUpdatePriority
M.setUltrasonicIsVisualised                 = setUltrasonicIsVisualised
M.getUltrasonicSensorPosition               = getUltrasonicSensorPosition
M.getUltrasonicSensorDirection              = getUltrasonicSensorDirection
M.getUltrasonicSensorRadius                 = getUltrasonicSensorRadius
M.setUltrasonicMaxPendingGpuRequests        = setUltrasonicMaxPendingGpuRequests
M.setUltrasonicRequestedUpdateTime          = setUltrasonicRequestedUpdateTime
M.setUltrasonicUpdatePriority               = setUltrasonicUpdatePriority

-- Advanced IMU-specific sensor functions.
M.createAdvancedIMU                         = createAdvancedIMU
M.removeAdvancedIMU                         = removeAdvancedIMU
M.getAdvancedIMUReadings                    = getAdvancedIMUReadings
M.updateAdvancedIMULastReadings             = updateAdvancedIMULastReadings
M.updateAdvancedIMUAdHocRequest             = updateAdvancedIMUAdHocRequest
M.setAdvancedIMUUpdateTime                  = setAdvancedIMUUpdateTime
M.setAdvancedIMUIsUsingGravity              = setAdvancedIMUIsUsingGravity
M.setAdvancedIMUIsVisualised                = setAdvancedIMUIsVisualised

-- Powertrain-specific sensor functions.
M.createPowertrainSensor                    = createPowertrainSensor
M.removePowertrainSensor                    = removePowertrainSensor
M.getPowertrainReadings                     = getPowertrainReadings
M.updatePowertrainLastReadings              = updatePowertrainLastReadings
M.updatePowertrainAdHocRequest              = updatePowertrainAdHocRequest
M.setPowertrainUpdateTime                   = setPowertrainUpdateTime

-- Functions triggered by hooks.
M.onUpdate                                  = onUpdate
M.onVehicleDestroyed                        = onVehicleDestroyed

return M