-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- The ultrasonic test is time-based, performing different functionality of the ultrasonic sensor at different frames in the execution.
-- To execute the test, register this extension by add the following to the command arguments when executing:
--  -level gridmap/main.level.json -lua registerCoreModule('tech/ultrasonicTest') -lua extensions.load("tech_ultrasonicTest")

local M = {}

-- A counter for the number of update steps which have occured.
local frameCounter = 0

-- The ID of the vehicle which the sensors under test shall be attached.
local vid

-- The unique ID number of the sensor instance under test.
local sensorId

-- A flag which indicates if the test has completed.
local isTestComplete = false

-- The ultrasonic test.
local function executeUltrasonicTest()

  -- Test Stage 1: Create a typical ultrasonic sensor which is attached to a vehicle, and perform some initialisation tests/basic tests.
  if frameCounter == 100 then

    print("ultrasonic sensor test: stage 1 starting")

    -- Attempt to get the vehicle ID.
    vid = be:getPlayerVehicleID(0)
    if not vid or vid == -1 then
      return
    end
    assert(vid >= 0, "ultrasonicTest.lua - Failed to get a valid vehicle ID")

    -- Attempt to create an ultrasonic sensor.
    sensorId = extensions.tech_sensors.createUltrasonic(
      vid, 0.001, 200, 200, 0.15, 0.15, 0.10, 10.15,
      -1.15, 0.0, 0.3, 0.376, 0.1, 5.0, 3.0, 10.0,
      0, -3, 3,
      0, -1, 0,
      true, false, false, false)

    -- Test that the ultrasonic sensor was created and a valid unique ID number was issued.
    assert(sensorId == 0, "ultrasonicTest.lua - Failed to create valid ultrasonic sensor")
    assert(extensions.tech_sensors.doesSensorExist(sensorId) == true, "ultrasonicTest.lua - doesSensorExist() has failed at sensor initialisation")

    -- Test the getActiveUltrasonicSensors() function.
    local activeUltrasonicSensors = extensions.tech_sensors.getActiveUltrasonicSensors()
    local ctr = 0
    for i, s in pairs(activeUltrasonicSensors) do
      ctr = ctr + 1
      assert(s == 0, "ultrasonicTest.lua - getActiveUltrasonicSensors() has failed. A sensor contains the wrong ID number")
    end
    assert(ctr == 1, "ultrasonicTest.lua - getActiveUltrasonicSensors() has failed. There is not one single ultrasonic sensor.")

    -- Test the core property getters for the ultrasonic sensor.
    assert(extensions.tech_sensors.getUltrasonicIsVisualised(sensorId) == true, "ultrasonicTest.lua - getUltrasonicIsVisualised has failed")
    assert(extensions.tech_sensors.getUltrasonicSensorPosition(sensorId) ~= nil, "ultrasonicTest.lua - getUltrasonicSensorPosition has failed")
    assert(extensions.tech_sensors.getUltrasonicSensorDirection(sensorId) ~= nil, "ultrasonicTest.lua - getUltrasonicDirectionPosition has failed")
    assert(extensions.tech_sensors.getUltrasonicSensorRadius(sensorId, 1) ~= nil, "ultrasonicTest.lua - getUltrasonicSensorRadius has failed")

    -- Test switching the ultrasonic visualisation off then back on again.
    extensions.tech_sensors.setUltrasonicIsVisualised(sensorId, false)
    assert(extensions.tech_sensors.getUltrasonicIsVisualised(sensorId) == false, "ultrasonicTest.lua - getUltrasonicIsVisualised has failed")
    extensions.tech_sensors.setUltrasonicIsVisualised(sensorId, true)
    assert(extensions.tech_sensors.getUltrasonicIsVisualised(sensorId) == true, "ultrasonicTest.lua - getUltrasonicIsVisualised has failed")
  end

  -- Test Stage 2: The ultrasonic sensor readings have now had a chance to update.
  if frameCounter == 200 then

    print("ultrasonic sensor test: stage 2 starting")

    -- Test the ultrasonic sensor readings.
    assert(extensions.tech_sensors.getUltrasonicDistanceMeasurement(sensorId) ~= nil, "ultrasonicTest.lua - failed to valid get distance reading")
    assert(extensions.tech_sensors.getUltrasonicWindowMin(sensorId) ~= nil, "ultrasonicTest.lua - failed to get valid windowMin readings")
    assert(extensions.tech_sensors.getUltrasonicWindowMax(sensorId) ~= nil, "ultrasonicTest.lua - failed to get valid windowMax readings")

    -- Test removing the ultrasonic sensor via its unique sensor ID number.
    extensions.tech_sensors.removeSensor(sensorId)
    assert(extensions.tech_sensors.doesSensorExist(sensorId) == false, "ultrasonicTest.lua - doesSensorExist() has failed after removal by ID")

    -- Test that we can now create a new ultrasonic sensor.
    sensorId = extensions.tech_sensors.createUltrasonic(
      vid, 0.0001, 200, 200, 0.15, 0.15, 0.10, 10.15,
      -1.15, 0.0, 0.3, 0.376, 0.1, 5.0, 3.0, 10.0,
      0, -3, 3,
      0, -1, 0,
      true, false, false, false)
    assert(extensions.tech_sensors.doesSensorExist(sensorId) == true, "ultrasonicTest.lua - doesSensorExist() has failed after retrieval")

    -- Test removing the ultrasonic sensor via the vehicle ID number.
    extensions.tech_sensors.removeAllSensorsFromVehicle(vid)
    assert(extensions.tech_sensors.doesSensorExist(sensorId) == false, "ultrasonicTest.lua - doesSensorExist() has failed after removal by vid")

    isTestComplete = true

    print("ultrasonic sensor test complete")
  end
end

-- Trigger execution to access the ultrasonic test class in every update cycle.
local function onUpdate(dtReal, dtSim, dtRaw)

  -- If the test has already finished, do nothing here for the rest of execution.
  if isTestComplete == true then
    return
  end

  executeUltrasonicTest()
  frameCounter = frameCounter + 1
end

-- If a vehicle is destroyed, remove any attached sensors.
local function onVehicleDestroyed(vid)
  print("ultrasonic sensor test: vehicle destroyed and test sensor removed")
  research.sensorManager.removeAllSensorsFromVehicle(vid)
end

-- Public interface.
M.onUpdate                                  = onUpdate
M.onVehicleDestroyed                        = onVehicleDestroyed
M.onExtensionLoaded                         = function() log('I', 'ultrasonicTest', 'ultrasonicTest extension loaded') end
M.onExtensionUnloaded                       = function() log('I', 'ultrasonicTest', 'ultrasonicTest extension unloaded') end

return M
