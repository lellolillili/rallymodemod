-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- The LiDAR test is time-based, performing different functionality of the LiDAR sensor at different frames in the execution.
-- To execute the test, register this extension by add the following to the command arguments when executing:
--  -level gridmap/main.level.json -lua registerCoreModule('tech/lidarTest') -lua extensions.load("tech_lidarTest")

local M = {}

-- A counter for the number of update steps which have occured.
local frameCounter = 0

-- The ID of the vehicle which the sensors under test shall be attached.
local vid

-- The unique ID number of the sensor instance under test.
local sensorId

-- A flag which indicates if the test has completed.
local isTestComplete = false

-- The LiDAR test.
local function executeLidarTest()

  -- Test Stage 1: Create a typical LiDAR sensor which is attached to a vehicle, and perform some initialisation tests/basic tests.
  if frameCounter == 100 then

    print("LiDAR sensor test: stage 1 starting")

    -- Attempt to get the vehicle ID.
    vid = be:getPlayerVehicleID(0)
    if not vid or vid == -1 then
        return
    end
    assert(vid >= 0, "lidarTest.lua - Failed to get a valid vehicle ID")

    -- Attempt to create an LiDAR sensor (without shared memory, for now).
    sensorId = extensions.tech_sensors.createLidar(
        vid, 0.0001, vec3(3, 0, 3), vec3(0, -1, 0), 64, 0.47, 2200000, 20, 2 * math.pi, 120,
        true, false, false, false, false)

    -- Test that the LiDAR sensor was created and a valid unique ID number was issued.
    assert(sensorId == 0, "lidarTest.lua - Failed to create valid LiDAR sensor")
    assert(extensions.tech_sensors.doesSensorExist(sensorId) == true, "lidarTest.lua - doesSensorExist() has failed at sensor initialisation")

    -- Test the getActiveLidarSensors() function.
    local activeLidarSensors = extensions.tech_sensors.getActiveLidarSensors()
    local ctr = 0
    for i, s in pairs(activeLidarSensors) do
      ctr = ctr + 1
      assert(s == 0, "lidarTest.lua - getActiveLidarSensors() has failed. A sensor contains the wrong ID number")
    end
    assert(ctr == 1, "lidarTest.lua - getActiveLidarSensors() has failed. There is not one single LiDAR sensor.")

    -- Test the core property getters for the LiDAR sensor.
    assert(extensions.tech_sensors.getLidarIsVisualised(sensorId) == true, "lidarTest.lua - getLidarIsVisualised has failed")
    assert(extensions.tech_sensors.getLidarIsAnnotated(sensorId) == false, "lidarTest.lua - getLidarIsAnnotated has failed")
    assert(extensions.tech_sensors.getLidarSensorPosition(sensorId) == vec3(3, 0, 3), "lidarTest.lua - getLidarSensorPosition has failed")
    assert(extensions.tech_sensors.getLidarSensorDirection(sensorId) == vec3(0, -1, 0), "lidarTest.lua - getLidarDirectionPosition has failed")
    assert(extensions.tech_sensors.getLidarVerticalResolution(sensorId) == 64, "lidarTest.lua - getLidarVerticalResolution has failed")
    assert(extensions.tech_sensors.getLidarRaysPerSecond(sensorId) == 2200000, "lidarTest.lua - getLidarRaysPerSecond has failed")
    assert(extensions.tech_sensors.getLidarFrequency(sensorId) == 20, "lidarTest.lua - getLidarFrequency has failed")
    assert(extensions.tech_sensors.getLidarMaxDistance(sensorId) == 120, "lidarTest.lua - getLidarMaxDistance has failed")

    -- Test setting the LiDAR vertical resolution parameter.
    extensions.tech_sensors.setLidarVerticalResolution(sensorId, 44)
    assert(extensions.tech_sensors.getLidarVerticalResolution(sensorId) == 44, "lidarTest.lua - getLidarVerticalResolution has failed after set")

    -- Test setting the LiDAR rays per second parameters.
    extensions.tech_sensors.setLidarRaysPerSecond(sensorId, 1500000)
    assert(extensions.tech_sensors.getLidarRaysPerSecond(sensorId) == 1500000, "lidarTest.lua - getLidarRaysPerSecond has failed after set")

    -- Test setting the LiDAR frequency parameter.
    extensions.tech_sensors.setLidarFrequency(sensorId, 12)
    assert(extensions.tech_sensors.getLidarFrequency(sensorId) == 12, "lidarTest.lua - getLidarFrequency has failed after set")

    -- Test setting the LiDAR max distance parameter.
    extensions.tech_sensors.setLidarMaxDistance(sensorId, 90)
    assert(extensions.tech_sensors.getLidarMaxDistance(sensorId) == 90, "lidarTest.lua - getLidarMaxDistance has failed after set")

    -- Test switching the LiDAR visualisation off then back on again.
    extensions.tech_sensors.setLidarIsVisualised(sensorId, false)
    assert(extensions.tech_sensors.getLidarIsVisualised(sensorId) == false, "lidarTest.lua - getLidarIsVisualised has failed")
    extensions.tech_sensors.setLidarIsVisualised(sensorId, true)
    assert(extensions.tech_sensors.getLidarIsVisualised(sensorId) == true, "lidarTest.lua - getLidarIsVisualised has failed")

    -- Test switching the LiDAR annotations on then back off again.
    extensions.tech_sensors.setLidarIsAnnotated(sensorId, true)
    assert(extensions.tech_sensors.getLidarIsAnnotated(sensorId) == true, "lidarTest.lua - getLidarIsAnnotated has failed")
    extensions.tech_sensors.setLidarIsAnnotated(sensorId, false)
    assert(extensions.tech_sensors.getLidarIsAnnotated(sensorId) == false, "lidarTest.lua - getLidarIsAnnotated has failed")
  end

  -- Test Stage 2: The LiDAR sensor readings have now had a chance to update.
  if frameCounter == 200 then

    print("LiDAR sensor test: stage 2 starting")

    -- Test the LiDAR sensor readings.
    local lidarPointCloud = extensions.tech_sensors.getLidarPointCloud(sensorId)
    assert(lidarPointCloud ~= nil, "lidarTest.lua - Failed to get valid LiDAR point cloud data")
    local ctr = 0
    for i, s in pairs(lidarPointCloud) do
      ctr = ctr + 1
    end
    assert(ctr > 0, "lidarTest.lua - Failed. There are no points in the LiDAR point cloud data.")

    -- Test removing the LiDAR sensor via its unique sensor ID number.
    extensions.tech_sensors.removeSensor(sensorId)
    assert(extensions.tech_sensors.doesSensorExist(sensorId) == false, "lidarTest.lua - doesSensorExist() has failed after removal by ID")

    -- Test that we can now create a new LiDAR sensor.
    sensorId = extensions.tech_sensors.createLidar(
      vid, 0.0001, vec3(3, 0, 3), vec3(0, -1, 0), 64, 0.47, 2200000, 20, 2 * math.pi, 120,
      true, false, false, false, false)
    assert(extensions.tech_sensors.doesSensorExist(sensorId) == true, "lidarTest.lua - doesSensorExist() has failed to create with shared memory")

    -- Test removing the LiDAR sensor via the vehicle ID number.
    extensions.tech_sensors.removeAllSensorsFromVehicle(vid)
    assert(extensions.tech_sensors.doesSensorExist(sensorId) == false, "lidarTest.lua - doesSensorExist() has failed after removal by vid")

    isTestComplete = true

    print("LiDAR sensor test complete")
  end
end

-- Trigger execution to access the LiDAR test class in every update cycle.
local function onUpdate(dtReal, dtSim, dtRaw)

  -- If the test has already finished, do nothing here for the rest of execution.
  if isTestComplete == true then
    return
  end

  executeLidarTest()
  frameCounter = frameCounter + 1
end

-- If a vehicle is destroyed, remove any attached sensors.
local function onVehicleDestroyed(vid)
  print("LiDAR sensor test: vehicle destroyed and test sensor removed")
  research.sensorManager.removeAllSensorsFromVehicle(vid)
end

-- Public interface.
M.onUpdate                                  = onUpdate
M.onVehicleDestroyed                        = onVehicleDestroyed
M.onExtensionLoaded                         = function() log('I', 'lidarTest', 'lidarTest extension loaded') end
M.onExtensionUnloaded                       = function() log('I', 'lidarTest', 'lidarTest extension unloaded') end

return M