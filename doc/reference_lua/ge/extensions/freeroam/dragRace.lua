-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local helper = require('scenario/scenariohelper')
local level = 'gridmap_v2'
--local debugDist = true

local exitTrigger = false
local time = 0
local starttimer = 0
-- TStatic objects used for left and right number displays
local leftTimeDigits = {}
local rightTimeDigits = {}
local leftSpeedDigits = {}
local rightSpeedDigits = {}
local started = false
local countDownStarted = false
local jumpStarted = false
local speedUnit = 2.2369362920544
local vehicles = {}

local opponentPrestageReady = false
local opponentStageReady = false
local opponentStartReady = false
local opponentVehicleName = "drag_opponent"

local playerPrestageReady = false
local playerStageReady = false

local playerVehicleInsideTrigger
local playerVehicle = nil
local opponentVehicle = nil

local disqualified = false

local quickReset = false

local cinematicCam = true

local proTree = false

local opponentResetPosRot      = { pos = {x = -220.921, y = -207.704, z = 119.006}, rot = {x = 0, y = 0, z = 1, w = 234.052} }
local opponentQuickResetPosRot = { pos = {x = -203.675, y = -157.578, z = 119.604}, rot = {x = 0, y = 0, z = 1, w = 234.052} }
local playerResetPosRot        = { pos = {x = -198.578, y = -164.132, z = 119.651}, rot = {x = 0, y = 0, z = 1, w = 234.052} }

local alignMsgTimer = 0

local lights = {}
local triggers = {}

local results = {}

local function updateDisplay(side, finishTime, finishSpeed)
  log("D","updateDisplay",dumps(side).." = "..dumps(finishTime).." ="..dumps(finishSpeed))

  local timeDisplayValue = {}
  local speedDisplayValue = {}
  local timeDigits = {}
  local speedDigits = {}

  if side == "r" then
    timeDigits = rightTimeDigits
    speedDigits = rightSpeedDigits
  elseif side == "l" then
    timeDigits = leftTimeDigits
    speedDigits = leftSpeedDigits
  end

  if finishTime < 10 then
    table.insert(timeDisplayValue, "empty")
  end

  if finishSpeed < 100 then
    table.insert(speedDisplayValue, "empty")
  end

  -- Three decimal points for time
  for num in string.gmatch(string.format("%.3f", finishTime), "%d") do
    table.insert(timeDisplayValue, num)
  end

  -- Two decimal points for speed
  for num in string.gmatch(string.format("%.2f", finishSpeed), "%d") do
    table.insert(speedDisplayValue, num)
  end

  if #timeDisplayValue > 0 and #timeDisplayValue < 6 then
    for i,v in ipairs(timeDisplayValue) do
      timeDigits[i]:preApply()
      timeDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_".. v ..".dae")
      timeDigits[i]:setHidden(false)
      timeDigits[i]:postApply()
    end
  end

  for i,v in ipairs(speedDisplayValue) do
    speedDigits[i]:preApply()
    speedDigits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_".. v ..".dae")
    speedDigits[i]:setHidden(false)
    speedDigits[i]:postApply()
  end
end

local function resetLights()
  for _,group in pairs(lights) do
    for _,light in pairs(group) do
      if light.obj then
        light.obj:setHidden(true)
      end
    end
  end
end

local function initLights()
  log("D","initLight","--------------")
  lights = {
    stageLights = {
      prestageLightL  = {obj = scenetree.findObject("Prestagelight_l"), anim = "prestage"},
      prestageLightR  = {obj = scenetree.findObject("Prestagelight_r"), anim = "prestage"},
      stageLightL     = {obj = scenetree.findObject("Stagelight_l"),    anim = "prestage"},
      stageLightR     = {obj = scenetree.findObject("Stagelight_r"),    anim = "prestage"}
    },
    countDownLights = {
      amberLight1R    = {obj = scenetree.findObject("Amberlight1_R"), anim = "tree"},
      amberLight2R    = {obj = scenetree.findObject("Amberlight2_R"), anim = "tree"},
      amberLight3R    = {obj = scenetree.findObject("Amberlight3_R"), anim = "tree"},
      amberLight1L    = {obj = scenetree.findObject("Amberlight1_L"), anim = "tree"},
      amberLight2L    = {obj = scenetree.findObject("Amberlight2_L"), anim = "tree"},
      amberLight3L    = {obj = scenetree.findObject("Amberlight3_L"), anim = "tree"},
      greenLightR     = {obj = scenetree.findObject("Greenlight_R"),  anim = "tree"},
      greenLightL     = {obj = scenetree.findObject("Greenlight_L"),  anim = "tree"},
      redLightR       = {obj = scenetree.findObject("Redlight_R"),  anim = "tree"},
      redLightL       = {obj = scenetree.findObject("Redlight_L"),  anim = "tree"}
    }
  }
end

local function clearDisplay(digits)
  -- Setting display meshes to empty object
  -- We can assume 5 as we know there are only 5 digits available for each display
  for i=1, #digits do
    -- digits[i]:setField('shapeName', 0, "art/shapes/quarter_mile_display/display_empty.dae")
    -- digits[i]:postApply()
    digits[i]:setHidden(true)
  end
end

local function resetDisplays()
  clearDisplay(leftTimeDigits)
  clearDisplay(rightTimeDigits)
  clearDisplay(leftSpeedDigits)
  clearDisplay(rightSpeedDigits)
end

local function setupPrestage()
  log("D","setupPrestage", dumps(playerPrestageReady) )
  lights.stageLights.prestageLightL.obj:setHidden(false)
  -- player is not ready therefore we need ai to wait
  if playerPrestageReady == false then
    opponentVehicle:queueLuaCommand('controller.setFreeze(1)')
    log("D","setupPrestage", "setSpeed = 0" )
    opponentVehicle:queueLuaCommand('ai.setSpeed('.. 0 ..')')
  else
    -- player is ready, lets move the ai vehicle forward so it can start the staging process
    opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
    log("D","setupPrestage", "setSpeed = 5" )
    opponentVehicle:queueLuaCommand('ai.setSpeed('.. 5 ..')')
  end
  opponentVehicle:queueLuaCommand('ai.setAggression('.. 0 ..')')
  opponentVehicle:queLuaComuemand('controller.onGameplayEvent("freeroam_dragRace", "AI_prestage")') --moded controller support
  opponentPrestageReady = true
  be:enterVehicle(0, playerVehicle)
  guihooks.trigger('Message', {ttl = 5, msg = "Please drive up to start line.", category = "fill", icon = "flag"})
end

local function setupStage()
  if startRace then log("E","setupStage", "startRace"); return end
  log("D","setupStage", "AIAIAIAIAIAI")
  lights.stageLights.stageLightL.obj:setHidden(false)
  opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
  opponentVehicle:queueLuaCommand('ai.setAggression(0)')
  opponentVehicle:queueLuaCommand('ai.setSpeed(5)')
  opponentVehicle:queueLuaCommand('ai.setAvoidCars("on")')
  opponentVehicle:queueLuaCommand('controller.onGameplayEvent("freeroam_dragRace", "AI_stage")') --moded controller support

  log("D","setupStage", "setSpeed = 5" )
  opponentStageReady = true
end

local function setupStart()
  log("D","setupStart", "AIAIAIAIAIAI")
  opponentVehicle:queueLuaCommand('controller.setFreeze(1)')
  opponentVehicle:queueLuaCommand('ai.setAggression(2)')
  opponentVehicle:queueLuaCommand('ai.setSpeed(nil)')
  opponentVehicle:queueLuaCommand('controller.onGameplayEvent("freeroam_dragRace", "AI_setupStart")') --moded controller support
  log("D","setupStart", "setSpeed = NIL" )
  opponentStartReady = true
end

local function startOpponent()
  log("D","startOpponent", "AIAIAIAIAIAI")
  opponentVehicle:queueLuaCommand('if electrics.values.jatoInput then electrics.values.jatoInput = 1 end')
  opponentVehicle:queueLuaCommand([[local nc = controller.getController("nitrousOxideInjection")
  if nc then
    local engine = powertrain.getDevice("mainEngine")
    if engine and engine.nitrousOxideInjection and not engine.nitrousOxideInjection.isArmed then
      nc.toggleActive()
    end
  end]])
  opponentVehicle:queueLuaCommand('controller.onGameplayEvent("freeroam_dragRace", "AI_start")') --moded controller support
end

local function stopOpponent()
  log("D","stopOpponent", "AIAIAIAIAIAI")
  opponentVehicle:queueLuaCommand('if electrics.values.jatoInput then electrics.values.jatoInput = 0 end')
  opponentVehicle:queueLuaCommand([[local nc = controller.getController("nitrousOxideInjection")
  if nc then
    local engine = powertrain.getDevice("mainEngine")
    if engine and engine.nitrousOxideInjection and engine.nitrousOxideInjection.isArmed then
      nc.toggleActive()
    end
  end]])
  opponentVehicle:queueLuaCommand('controller.onGameplayEvent("freeroam_dragRace", "AI_stop")') --moded controller support
  opponentVehicle:queueLuaCommand('ai.setAvoidCars("on")')
end


local function calculateDistanceFromStart(vehicle, trigger)
  if vehicle and trigger then
    local wheels = {}
    local maxFwd = -math.huge
    -- get the most forward-y wheel, then project that position to the center-line of the vehicle.
    for i=0, vehicle:getWheelCount()-1 do
      local axisNodes = vehicle:getWheelAxisNodes(i)
      local nodePos = vehicle:getNodePosition(axisNodes[1])
      local wheelNodePos = vehicle:getPosition() + vec3(nodePos.x, nodePos.y, nodePos.z)
      --local wheelNodePosToTrigger = vec3(wheelNodePos - trigger:getPosition())
      -- We need actual distance from starting line and not the center
      local dot = vec3(nodePos.x, nodePos.y, nodePos.z):dot(vehicle:getDirectionVector():normalized())
      maxFwd = math.max(dot, maxFwd)
      --wheels[i+1] = {wheelNodePos = wheelNodePos, distance = distance}
    end

    -- In order to accurately calculate that AI is in the correct position
    -- we need to find the wheels that are closest to the start line


    -- Point inbetween both wheels is calculated so that we can get a somewhat accurate distance measurement
    local centerPoint = vehicle:getPosition() + maxFwd * vehicle:getDirectionVector():normalized()
    local centerPointToTrigger = vec3(centerPoint - trigger:getPosition())
    centerPointToTrigger.z = 0

    if centerPointToTrigger:len() > 10 then return end

    local dot = centerPointToTrigger:dot(vehicle:getDirectionVector():normalized())
    local distanceFromStart = -dot

    if debugDist and debugDrawer then
      debugDrawer:drawLine((vehicle:getDirectionVector() + centerPoint), centerPoint, ColorF(1,0,0,1))

      -- Line between two closest wheels
      --debugDrawer:drawLine(closestWheels[1].wheelNodePos, closestWheels[2].wheelNodePos, ColorF(0.5,0.0,0.5,1.0))
      -- Sphere indicating center point of the wheels
      debugDrawer:drawSphere(centerPoint, 0.2, ColorF(0.0,0.0,1.0,1.0))
      -- Sphere indicating start line
      debugDrawer:drawLine(centerPoint, trigger:getPosition(), ColorF(1,0.0,0.5,1.0))
      -- Text to indicate current distance from start line
      debugDrawer:drawTextAdvanced(trigger:getPosition(), String('Distance:' .. distanceFromStart), ColorF(0,0,0,1), true, false, ColorI(255, 255, 255, 255))
    end

    return distanceFromStart
  end
end

local currentCam
local camTransforms = {
  west_coast_usa = "[123.70, 75.43, 120.50, -0.0177324, 0.0090892, 0.456055, 0.889729]",
  gridmap_v2 = "[329.57, 409.86, 101.94, 0.00438566, -0.00435474, 0.704588, 0.70959]"
}
local function displayOverview(enableSlowmo, enableResults)
  currentCam = core_camera.getActiveCamName()
  guihooks.trigger('MenuHide', false)
  if enableSlowmo then
    bullettime.set(1/100)
  end
  if enableResults then
    commands.setFreeCamera()
    commands.setFreeCameraTransformJson(camTransforms[level])
    setCameraFovDeg(12)
  end
  guihooks.trigger('ChangeState', {state = "menu.dragRaceOverview", params = {results = results, cinematicEnabled = (level ~= 'gridmap_v2')}})
  core_camera.setByName(0, "external", true)
end

local function closeOverview()
  bullettime.set(1)
  if currentCam and core_camera then
    setCameraFovDeg(65) --rst
    commands.setGameCamera()
    core_camera.setByName(0, currentCam, true)
  end
end

local function init()
  started = false
  time = 0
  starttimer = 0
  jumpStarted = false
  countDownStarted = false
  opponentPrestageReady = false
  opponentStageReady = false
  opponentStartReady = false
  playerPrestageReady = false
  playerStageReady = false
  disqualified = false
  results = {}
  log("D","init","rst vehicles")
  vehicles = {}
  resetLights()
end

local function finishRace()
  if started then
    displayOverview(true, true)
    init()
  end
  log("D","finishRace","--------------------------------------------------------------------------------\n---------------------------------------------------------------------------------------------------")
end

local function onPreRender(dtReal, dtSim, dtRaw)
  if not opponentVehicle then return end

  if countDownStarted and not started then
    starttimer = starttimer + dtSim
    if proTree then
      if starttimer > 2.0 then
        if starttimer < 2.4 and lights.countDownLights.amberLight1L.obj:isHidden() then
          lights.countDownLights.amberLight1L.obj:setHidden(false)
          lights.countDownLights.amberLight2L.obj:setHidden(false)
          lights.countDownLights.amberLight3L.obj:setHidden(false)
          lights.countDownLights.amberLight1R.obj:setHidden(false)
          lights.countDownLights.amberLight2R.obj:setHidden(false)
          lights.countDownLights.amberLight3R.obj:setHidden(false)
        end
        if starttimer > 2.4 and not started then
          lights.countDownLights.amberLight1L.obj:setHidden(true)
          lights.countDownLights.amberLight2L.obj:setHidden(true)
          lights.countDownLights.amberLight3L.obj:setHidden(true)
          lights.countDownLights.amberLight1R.obj:setHidden(not jumpStarted)
          lights.countDownLights.amberLight2R.obj:setHidden(not jumpStarted)
          lights.countDownLights.amberLight3R.obj:setHidden(not jumpStarted)
          lights.countDownLights.greenLightL.obj:setHidden(false)
          lights.countDownLights.greenLightR.obj:setHidden(jumpStarted)
          if not jumpStarted then
            started = true
            guihooks.trigger('Message', {ttl = 0.25, msg =  nil, category = "align", icon = "check"})
            time = 0
            resetDisplays()
            opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
            startOpponent()
            guihooks.trigger('Message', {ttl = 5, msg = "Quarter mile started", category = "fill", icon = "flag"})
          end
        end
      end
    else
      if starttimer > 1.0 and starttimer < 1.5 and lights.countDownLights.amberLight1L.obj:isHidden() then
        lights.countDownLights.amberLight1L.obj:setHidden(false)
        lights.countDownLights.amberLight1R.obj:setHidden(jumpStarted)
      end
      if starttimer > 1.5 and starttimer < 2.0 and lights.countDownLights.amberLight2L.obj:isHidden() then
        lights.countDownLights.amberLight1L.obj:setHidden(true)
        lights.countDownLights.amberLight2L.obj:setHidden(false)
        if not jumpStarted then
          lights.countDownLights.amberLight1R.obj:setHidden(true)
          lights.countDownLights.amberLight2R.obj:setHidden(jumpStarted)
        end
      end
      if starttimer > 2.0 and starttimer < 2.5 and lights.countDownLights.amberLight3L.obj:isHidden() then
        lights.countDownLights.amberLight2L.obj:setHidden(true)
        lights.countDownLights.amberLight3L.obj:setHidden(false)
        if not jumpStarted then
          lights.countDownLights.amberLight2R.obj:setHidden(true)
          lights.countDownLights.amberLight3R.obj:setHidden(jumpStarted)
        end
      end
      if starttimer > 2.5 and not started then
        lights.countDownLights.amberLight3L.obj:setHidden(true)
        lights.countDownLights.greenLightL.obj:setHidden(false)
        if not jumpStarted then
          lights.countDownLights.amberLight3R.obj:setHidden(true)
          lights.countDownLights.greenLightR.obj:setHidden(jumpStarted)
          started = true
          guihooks.trigger('Message', {ttl = 0.25, msg =  nil, category = "align", icon = "check"})
          resetDisplays()
          time = 0
          opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
          startOpponent()
          guihooks.trigger('Message', {ttl = 5, msg = "Quarter mile started", category = "fill", icon = "flag"})
        end
      end
    end
  end

  if started then
    time = time + dtSim
  end
  if playerVehicle and not started then
    local playerDistanceFromStart = calculateDistanceFromStart(playerVehicle, triggers["startTriggerR"])
    if playerDistanceFromStart then

      if not started and not countDownStarted then
        alignMsgTimer = alignMsgTimer + dtSim
        if alignMsgTimer >= 0.1 then
          alignMsgTimer = 0
          if playerDistanceFromStart > 0.35 then
            guihooks.trigger('Message', {ttl = 0.25, msg = "Align your front wheels with the starting line. (Move forward)", category = "align", icon = "arrow_upward"})
          elseif playerDistanceFromStart < 0 then
            guihooks.trigger('Message', {ttl = 0.25, msg = "Align your front wheels with the starting line. (Move backward)", category = "align", icon = "arrow_downward"})
          else
            guihooks.trigger('Message', {ttl = 0.25, msg = "Stop your vehicle now.", category = "align", icon = "check"})
          end
        end
      end

      if playerDistanceFromStart > 0 then
        -- if playerDistanceFromStart < 1 and playerDistanceFromStart > 0 and playerPrestageReady == false then
        --   lights.stageLights.prestageLightR.obj:setHidden(false)
        --   playerPrestageReady = true
        -- end
        playerPrestageReady = playerDistanceFromStart < 1 and playerDistanceFromStart > 0
        lights.stageLights.prestageLightR.obj:setHidden(not playerPrestageReady)

        if playerDistanceFromStart <= 0.35 and playerStageReady == false and playerVehicle:getVelocity():len() < 0.1 then
          lights.stageLights.stageLightR.obj:setHidden(false)
          playerStageReady = true
        end

        if playerDistanceFromStart > 0.35 and playerPrestageReady and playerStageReady and not started and not countDownStarted then
          playerStageReady = false
          started = false
          countDownStarted = false
          lights.stageLights.stageLightR.obj:setHidden(true)
        end

        if (countDownStarted and playerDistanceFromStart < -0.25 and not jumpStarted and not started) then
          countDownStarted = false
          jumpStarted = true
          disqualified = true
          lights.countDownLights.amberLight1R.obj:setHidden(false)
          lights.countDownLights.amberLight2R.obj:setHidden(false)
          lights.countDownLights.amberLight3R.obj:setHidden(false)
          lights.countDownLights.greenLightR.obj:setHidden(true)
          lights.countDownLights.redLightR.obj:setHidden(false)
          guihooks.trigger('Message', {ttl = 5, msg = "Disqualified for jumping the start, you need to restart the race.", category = "fill", icon = "flag"})
          log("D","pre","JUMPED *****************************************************************")
          opponentVehicle:queueLuaCommand('ai.setSpeed(0)')
          opponentVehicle:queueLuaCommand('controller.setFreeze(1)')
          stopOpponent()
          playerStageReady = false
          countDownStarted = false
          time = 0
          -- displayOverview(true)
        end
      end
    end
  end
  if playerVehicle and started then
    local playerDistanceFromStart = calculateDistanceFromStart(playerVehicle, triggers["startTriggerR"])
    if playerDistanceFromStart and playerDistanceFromStart > 8 then
      lights.stageLights.prestageLightR.obj:setHidden(true)
      lights.stageLights.stageLightR.obj:setHidden(true)
    end
  end

  if opponentVehicle and not started then
    local opponentDistanceFromStart = calculateDistanceFromStart(opponentVehicle, triggers["startTriggerL"])
    -- TODO: fine tune this value as some vehicles don't stop as well as others,
    -- not sure how this could be solved atm though
    if opponentDistanceFromStart then
      if opponentDistanceFromStart > 0 then
        -- AI vehicle is approximately 20cm from start line including tire radius
        if opponentDistanceFromStart < 1 and opponentDistanceFromStart > 0 and opponentPrestageReady == false then
          setupPrestage()
        end
        if opponentDistanceFromStart < 0.7 and opponentStageReady == false and playerPrestageReady then
          setupStage()
        end
        -- AI vehicle is approximately on the start line
        if opponentDistanceFromStart < 0.3 and opponentStageReady and not opponentStartReady and not jumpStarted then
          setupStart()
        end
      end
    end
  end
  if started and (not opponentStartReady or not opponentStageReady) then
    log("E","prerdr","force start, was not ready")
    setupStart()
    opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
    startOpponent()
  end
  if opponentVehicle and started then
    local opponentDistanceFromStart = calculateDistanceFromStart(opponentVehicle, triggers["startTriggerL"])
    if opponentDistanceFromStart and opponentDistanceFromStart > 8 then
      lights.stageLights.prestageLightL.obj:setHidden(true)
      lights.stageLights.stageLightL.obj:setHidden(true)
    end
  end

  if opponentStageReady and playerStageReady and not countDownStarted then
    countDownStarted = true
  end
end
local wpSetupByLevel = {
  west_coast_usa = {'drag_2', 'drag_3', 'drag_7', 'drag_5', 'drag_8', 'drag_6', 'drag_2'},
  gridmap_v2 = {'drag_6','drag_2'}
}
local function setupVehicle()
  if cinematicCam == false then
    local pos = opponentQuickResetPosRot.pos
    local rot = opponentQuickResetPosRot.rot
    local rot = AngAxisF(rot.x, rot.y, rot.z, (rot.w * 3.1459) / 180.0 ):toQuatF()
    opponentVehicle:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
    helper.setAiPath({vehicleName = opponentVehicleName, routeSpeed = 5, lapCount = 999, routeSpeedMode = 'set', waypoints = wpSetupByLevel[level], aggression = 0})
  else
    local pos = triggers["opponentSpawnTrigger"]:getPosition()
    local rot = triggers["opponentSpawnTrigger"]:getRotation()
    opponentVehicle:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
    helper.setAiPath({vehicleName = opponentVehicleName, routeSpeed = 10, lapCount = 999, routeSpeedMode = 'set', waypoints = {'drag_2', 'drag_3', 'drag_7', 'drag_5', 'drag_8', 'drag_6', 'drag_2'}, aggression = 0})
  end
  --print("Setting name: drag_opponent")
  --opponentVehicle:setField('name', '', opponentVehicleName)
  --dump(opponentVehicle.name)
  opponentVehicle:queueLuaCommand('controller.setFreeze(0)')
  --opponentVehicle:setField('canSave', '', 'false')
  -- opponentVehicle:queueLuaCommand('ai.setVehicleDebugMode({debugMode="trajectory"})')
end

local function onVehicleSpawned(vehicleID)
  if opponentVehicle and vehicleID == opponentVehicle:getID() then
    guihooks.trigger('MenuHide', true)
    setupVehicle()
  end

  playerVehicle = scenetree.findObject("thePlayer")
end

local function onVehicleDestroyed(id)
  if playerVehicle and playerVehicle:getID() == id then
    playerVehicle = nil
    playerVehicleInsideTrigger = nil
    resetLights()
  elseif opponentVehicle and opponentVehicle:getID() == id then
    opponentVehicle = nil
    resetLights()
  end
end

-- if sameClass = true then random opponent will be the same performance class as player vehicle
local function selectRandomOpponent(sameClass)
  local randomVehicle
  local configs = core_vehicles.getConfigList()
  local vehicleConfigs = {}
  for i,v in pairs(configs.configs) do
    local model = core_vehicles.getModel(v.model_key).model
    if model.Type == "Truck" or model.Type == "Car" then
      table.insert(vehicleConfigs, v)
    end
  end
  local currentVehicle = core_vehicles.getCurrentVehicleDetails()
  local currentConfig
  if currentVehicle.current.key and currentVehicle.current.config_key then
    currentConfig = currentVehicle.current.key .. " " .. currentVehicle.current.config_key
  else
    -- TODO: figure out a better solution to vehicles that dont have config keys (messes up same performance class selection)
    currentConfig = currentVehicle.current.key .. " " .. currentVehicle.model.default_pc
  end
  if sameClass then
    local zeroToHundred = nil
    local similarVehicles = {}
    local similarVehicleCount = 0

    for _,v in pairs(vehicleConfigs) do
      if currentConfig == (v.model_key .. " " .. v.key) then
        if (v["0-100 km/h"]) then
          zeroToHundred = v["0-100 km/h"]
        end
      end
    end

    for i,v in pairs(vehicleConfigs) do
      if (v["0-100 km/h"] and zeroToHundred)then
        if v["0-100 km/h"] >= zeroToHundred - 1 and v["0-100 km/h"] <= zeroToHundred + 1 then
          table.insert(similarVehicles, v)
        end
      end
    end

    for i,v in pairs(similarVehicles) do
      similarVehicleCount = similarVehicleCount + 1
    end
    randomVehicle = similarVehicles[math.random(similarVehicleCount)]
  else
    local vehiclesConfigs = {}
    for _,v in pairs(vehicleConfigs) do
      table.insert(vehiclesConfigs, v)
    end
    randomVehicle = vehiclesConfigs[math.random(#vehiclesConfigs)]
  end

  -- append Brand and Country for UI
  local randomVehicleModel = core_vehicles.getModel(randomVehicle.model_key).model
  randomVehicle.Brand = randomVehicleModel.Brand
  randomVehicle.Country = randomVehicleModel.Country
  return randomVehicle
end

local function onBeamNGTrigger(data)
  local veh = be:getPlayerVehicle(0)

  if data.triggerName == "dragTrigger" and data.subjectID == veh:getId() then
    if data.event == "enter" then
      playerVehicleInsideTrigger = true
      local buttonsTable = {}
      local txt = opponentVehicle == nil and 'ui.dragrace.Accept' or 'ui.dragrace.Configure'
      table.insert(buttonsTable, {action = 'accept', text = txt, cmd = 'freeroam_dragRace.accept()'})
      table.insert(buttonsTable, {action = 'decline', text = "Close", cmd = 'guihooks.trigger("MenuHide", true) ui_missionInfo.closeDialogue()'})
      local content = {title = "ui.wca.dragstrip.title", type="race", typeName="", buttons = buttonsTable}
      ui_missionInfo.openDialogue(content)
    end

    if data.event == "exit" then
      playerVehicleInsideTrigger = nil
      guihooks.trigger('MenuHide', true)
      ui_missionInfo.closeDialogue()
    end
  end
  -- log("D","trig",dumps(data.triggerName).." = "..dumps(data.event).." player="..dumps((veh and veh:getId())==data.subjectID))
  if data.event == "enter" and data.triggerName == "endTrigger" then
    if started == true then
      for i,v in pairs(vehicles) do
        if v.lane == "right" and v.id == data.subjectID then
          local rightVehicle = be:getObjectByID(v.id)
          -- Updating right display
          updateDisplay("r", time, rightVehicle:getVelocity():len() * speedUnit)
          local currentVehicle = core_vehicles.getCurrentVehicleDetails()
          local vehicleName = ""
          if currentVehicle.configs then
            vehicleName = currentVehicle.configs.Name
          else
            vehicleName = currentVehicle.model.Name
          end
          table.insert(results, {time = (disqualified and "Disqualified" or time), speed = rightVehicle:getVelocity():len() * speedUnit, vehicle = vehicleName})
          table.remove(vehicles, i)
        end

        if v.lane == "left" and v.id == data.subjectID then
          local leftVehicle = be:getObjectByID(data.subjectID)
          -- Updating left display
          updateDisplay("l", time, leftVehicle:getVelocity():len() * speedUnit)
          table.insert(results, {time = time, speed = leftVehicle:getVelocity():len() * speedUnit, vehicle = opponentVehicleName .. ' (opponent)'})
          table.remove(vehicles, i)
          opponentVehicle:queueLuaCommand('ai.setSpeed(30)')
          opponentVehicle:queueLuaCommand('ai.setSpeedMode("limit")')
          opponentVehicle:queueLuaCommand('ai.setAggression(0.5)')
          stopOpponent()
        end

        if table.getn(vehicles) == 0 then
          finishRace()
        end
      end
    end
  end

  if data.triggerName == "laneTrigger_L" then
    if data.event == "enter" and data.subjectID == be:getPlayerVehicleID(0) then
      if started then
        disqualified = true
        guihooks.trigger('Message', {ttl = 5, msg = "Disqualifed for driving within opponents lane.", category = "fill", icon = "flag"})
      end
    end
  end

  if data.triggerName == "startTrigger_R" then
    if data.event == "enter" or not vehicles[1] or (vehicles[1].id ~= data.subjectID) then
      log("D","trig","set 1")
      vehicles[1] = {id = data.subjectID, lane = "right"}
    end
  end

  if data.triggerName == "startTrigger_L" then
    if data.event == "enter" then
      vehicles[2] = {id = data.subjectID, lane = "left"}
    end
  end

  if data.triggerName == "dragTrigger_L" and opponentVehicle then
    if data.event == "enter" then
      init()
      opponentVehicle:queueLuaCommand('ai.setSpeed(5)')
      opponentVehicle:queueLuaCommand('ai.setSpeedMode("set")')
      opponentVehicle:queueLuaCommand('ai.setAggression(0)')
    end
  end

  if data.triggerName == "dragTrigger" then
    if data.event == "enter" and not playerVehicle then
      playerVehicle = be:getObjectByID(data.subjectID)
      playerVehicleInsideTrigger = true
    end
  end
end

local function restartRace()
  quickReset = true
  opponentVehicle:reset()
  stopOpponent()
  playerVehicle:reset()
  guihooks.trigger('ChangeState', 'menu')
  guihooks.trigger('MenuHide', true)
  bullettime.set(1)
  core_camera.setByName(0, "orbit", true)
end

local function accept()
  displayOverview(true, false)
end

local function exit()
  guihooks.trigger('MenuHide', true)
  ui_missionInfo.closeDialogue()
  closeOverview()
  if scenetree.drag_opponent then scenetree.drag_opponent:deleteObject() end
  opponentVehicle = nil
  M.onExtensionLoaded()
end


local function onExtensionLoaded()

  initLights()
  resetLights()
  -- local unitType = settings.getValue('uiUnitLength')
  -- speedUnit = unitType == "metric" and 3.6 or 2.2369362920544
  started = false
  playerVehicle = be:getPlayerVehicle(0)


  -- Creating a table for the TStatics that are being used to display drag time and final speed
  for i=1, 5 do
    local leftTimeDigit = scenetree.findObject("display_time_" .. i .. "_l")
    table.insert(leftTimeDigits, leftTimeDigit)

    local rightTimeDigit = scenetree.findObject("display_time_" .. i .. "_r")
    table.insert(rightTimeDigits, rightTimeDigit)

    local rightSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_r")
    table.insert(rightSpeedDigits, rightSpeedDigit)

    local leftSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_l")
    table.insert(leftSpeedDigits, leftSpeedDigit)
  end
  resetDisplays()

  triggers = {
    dragTriggerL  = scenetree.findObject("dragTrigger_L"),
    dragTriggerR  = scenetree.findObject("dragTrigger_R"),
    startTriggerL = scenetree.findObject("startTrigger_L"),
    startTriggerR = scenetree.findObject("startTrigger_R"),
    endTriggerL   = scenetree.findObject("endTrigger_L"),
    endTriggerR   = scenetree.findObject("endTrigger_R"),
    laneTriggerL  = scenetree.findObject("laneTrigger_L"),
    laneTriggerR  = scenetree.findObject("laneTrigger_R"),
    opponentSpawnTrigger = scenetree.findObject("opponentSpawnTrigger")
  }

  if level == 'gridmap_v2' then
    opponentResetPosRot      = { pos = {x = 26.946, y = 413.808, z = 100.2}, rot = {x = 0, y = 0, z = 1, w = -90} }
    opponentQuickResetPosRot = { pos = {x = 26.946, y = 413.808, z = 100.2}, rot = {x = 0, y = 0, z = 1, w = -90} }
    playerResetPosRot        = { pos = {x = 26.946, y = 405.062, z = 100.2}, rot = {x = 0, y = 0, z = 1, w = -90} }
  elseif level == 'west_coast_usa' then
    opponentResetPosRot      = { pos = {x = -220.921, y = -207.704, z = 119.006}, rot = {x = 0, y = 0, z = 1, w = 234.052} }
    opponentQuickResetPosRot = { pos = {x = -203.675, y = -157.578, z = 119.604}, rot = {x = 0, y = 0, z = 1, w = 234.052} }
    playerResetPosRot        = { pos = {x = -198.578, y = -164.132, z = 119.651}, rot = {x = 0, y = 0, z = 1, w = 234.052} }
  end
end

local function onVehicleResetted(vid)

  local vehicle = be:getObjectByID(vid)
  if not vehicle then return end
  if playerVehicleInsideTrigger and playerVehicle and playerVehicle:getID() == vid then
    ui_missionInfo.closeDialogue()
  end
  if vehicle:getName() == opponentVehicleName then
    if quickReset == true then
      setupVehicle()
      quickReset = false
    else
      setupVehicle()
    end
  end
end

local function enableCinematicCam(value)
  if value ~= nil then
    cinematicCam = value
  end
  return cinematicCam
end

local function enableProTree(val)
  if val ~= nil then
    proTree = val
  end
  return proTree
end

local function selectOpponent(selection)
  init()
  resetDisplays()
  if level == 'gridmap_v2' then
    cinematicCam = false
  end

  if scenetree.drag_opponent then scenetree.drag_opponent:deleteObject() end

  if not scenetree.findObject(opponentVehicleName) then
    local options = {}
    options.config=selection.config
    options.color=selection.color
    options.licenseText="2slow"
    options.vehicleName = opponentVehicleName
    opponentVehicle = core_vehicles.spawnNewVehicle(selection.model, options)
    if cinematicCam == true then
      core_camera.setByName(0, "external", true)
    else
      if playerVehicle then
        be:enterVehicle(0, playerVehicle)
      end
    end
  end
  if playerVehicle and not playerVehicleInsideTrigger then
    -- move player back to the dragstrip starting line if we're not there already (such as right after finishing a run)
    -- a vehicle reset will trigger the start line BeamNGTrigger object with an enter + an exit event, which will re-trigger the initial dialog. so we're trying to avoid resetting vehicle as much as possible. the dialog is a pain for users with Realistic shifting mode using an XBox gamepad, since the 'A' button interacts with this recurring dialog rather than allowing them to shift up a gear to move forwards towards the race. see GE-2205
    playerVehicle:reset()
    local pos = playerResetPosRot.pos
    local rot = playerResetPosRot.rot
    rot = AngAxisF(rot.x, rot.y, rot.z, (rot.w * 3.1459) / 180.0 ):toQuatF()
    playerVehicle:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  end
  guihooks.trigger('MenuHide', true)
  ui_missionInfo.closeDialogue()
end

local function onExtensionUnloaded()
  guihooks.trigger('MenuHide', true)
  ui_missionInfo.closeDialogue()
  closeOverview()
  if scenetree.drag_opponent then scenetree.drag_opponent:deleteObject() end
  opponentVehicle = nil
end

local function onClientEndMission()
  lights = {}
  leftTimeDigits = {}
  rightTimeDigits = {}
  leftSpeedDigits = {}
  rightSpeedDigits = {}
  vehicles = {}
  triggers = {}
  results = {}
end

local function setLevel(lvl)
  level = lvl
  M.onExtensionLoaded()
end

M.accept = accept
M.exit = exit
M.onVehicleResetted = onVehicleResetted
M.onPreRender = onPreRender
M.onUpdate = onUpdate
M.onBeamNGTrigger = onBeamNGTrigger
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleDestroyed = onVehicleDestroyed
M.onClientEndMission = onClientEndMission
M.selectOpponent = selectOpponent
M.selectRandomOpponent = selectRandomOpponent
M.setupPrestage = setupPrestage
M.setupStage = setupStage
M.startRace = startRace
M.resetLights = resetLights
M.restartRace = restartRace
M.enableCinematicCam = enableCinematicCam
M.enableProTree = enableProTree
M.closeOverview = closeOverview
M.setLevel = setLevel
return M