-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}
local imgui = ui_imgui

local maxFuelFlowRate = 50000000
local fuelFlowRate = 0

local fuelData
local fuelingActive = {}
local energyTypeFuelingActive = {}
local energyTypes = {}
local defaultEnergyType

local startingFuelData
local fuelingData = {}
local overallPrice = 0

local gasSoundId
local electricSoundId
local paySoundId

local isSoundPlaying = {}

local showUI

local pricePerMJ = {
  gasoline = 0.061044176706827,
  diesel = 0.058139534883721,
  kerosine = 0.072674418604651,
  n2o = 3.01204819277108,
  electricEnergy = 0.088888888888889
}

local factorMJToReadable = {
  gasoline = 31.125,
  diesel = 36.112,
  kerosine = 34.4,
  n2o = 8.3,
  electricEnergy = 3.6
}

local readableUnit = {
  gasoline = "L",
  diesel = "L",
  kerosine = "L",
  n2o = "kg",
  electricEnergy = "kWh"
}

local function setDefaultEnergyType(energyType)
  defaultEnergyType = energyType
end

local function jouleToReadableUnit(value, fuelType)
  return value / 1000000 / factorMJToReadable[fuelType]
end

local function initializeDefaultEnergyType()
  local defaultTypeCandidate

  -- if the vehicle has one of these types, use this as default
  for i, energyType in ipairs(energyTypes) do
    if energyType == "gasoline" or energyType == "diesel" or energyType == "kerosine" then
      defaultTypeCandidate = energyType
      break
    end
  end

  if not defaultTypeCandidate then
    for i, energyType in ipairs(energyTypes) do
      if energyType == "electricEnergy" then
        defaultTypeCandidate = energyType
        break
      end
    end
  end

  setDefaultEnergyType(defaultTypeCandidate)
end

local function saveEnergyStorageData(data)
  fuelData = data[1]
  showUI = true
  for i, data in ipairs(fuelData) do
    table.insert(fuelingData, {price = 0, fueledEnergy = 0})
  end

  table.clear(energyTypes)
  for index, tankData in ipairs(fuelData) do
    if not tableContains(energyTypes, tankData.energyType) then
      table.insert(energyTypes, tankData.energyType)
    end
  end
end

local function requestEnergyStorageData()
  local veh = be:getPlayerVehicle(0)
  core_vehicleBridge.requestValue(veh, saveEnergyStorageData, 'energyStorage')
end

local function startTransaction()
  if not career_modules_inventory.getCurrentVehicle() then return end
  pushActionMap("Refueling")
  core_vehicleBridge.executeAction(be:getPlayerVehicle(0),'setIgnitionLevel', 0)
  requestEnergyStorageData()
end

local function getFuelData()
  return fuelData
end

local function applyFuelData(data)
  local veh = be:getPlayerVehicle(0)
  for index, tankData in ipairs(data or fuelData) do
    core_vehicleBridge.executeAction(veh, 'setEnergyStorageEnergy', tankData.name, tankData.currentEnergy)
  end
end

local function activateSound(soundId, active)
  local sound = scenetree.findObjectById(soundId)
  if sound then
    if active then
      sound:play(-1)
    else
      sound:stop(-1)
    end
    sound:setTransform(getCameraTransform())
    isSoundPlaying[soundId] = active
  end
end

local function getRelativeFuelLevel()
  local maxVolume = 0
  local currentVolume = 0
  for index, data in ipairs(fuelData) do
    if data.energyType == "gasoline" or data.energyType == "diesel" or data.energyType == "kerosine" then
      currentVolume = currentVolume + data.currentEnergy
      maxVolume = maxVolume + data.maxEnergy
    end
  end
  return currentVolume / maxVolume
end

local function updateFuelSoundParameters()
  local relativeFuelLevel = getRelativeFuelLevel()
  local sound = scenetree.findObjectById(gasSoundId)
  if sound then
    sound:setParameter("volume", relativeFuelLevel)
    sound:setParameter("pitch", fuelFlowRate / maxFuelFlowRate)
    sound:setTransform(getCameraTransform())
  end
end

local function updateFuelingFlags()
  table.clear(energyTypeFuelingActive)
  for i, data in ipairs(fuelingActive) do
    if fuelingActive[i] then
      energyTypeFuelingActive[fuelData[i].energyType] = true
    end
  end

  if energyTypeFuelingActive["gasoline"] or energyTypeFuelingActive["diesel"] or energyTypeFuelingActive["kerosine"] then
    if not isSoundPlaying[gasSoundId] then
      activateSound(gasSoundId, true)
    end
  else
    if isSoundPlaying[gasSoundId] then
      updateFuelSoundParameters()
      activateSound(gasSoundId, false)
    end
  end

  if energyTypeFuelingActive["electricEnergy"] then
    if not isSoundPlaying[electricSoundId] then
      activateSound(electricSoundId, true)
    end
  else
    if isSoundPlaying[electricSoundId] then
      updateFuelSoundParameters()
      activateSound(electricSoundId, false)
    end
  end
end

local function startFueling(index)
  if career_modules_inventory.getCurrentVehicle() then
    local veh = be:getPlayerVehicle(0)
    if veh:getVelocity():length() < 1 then
      fuelingActive[index] = true
      startingFuelData = startingFuelData or deepcopy(fuelData)
    end
  end
end

local function stopFueling(index)
  if not index then
    for i, data in ipairs(fuelingActive) do
      fuelingActive[i] = false
    end
  else
    fuelingActive[index] = false
  end
  updateFuelingFlags()
  applyFuelData()
end

local function startFuelingType(energyType)
  for index, data in ipairs(fuelData) do
    if data.energyType == energyType then
      startFueling(index)
    end
  end
  updateFuelingFlags()
end

local function stopFuelingType(energyType)
  for index, data in ipairs(fuelData) do
    if data.energyType == energyType then
      stopFueling(index)
    end
  end
  updateFuelingFlags()
end

local function changeFlowRate(factor)
  factor = clamp(factor, 0, 1)
  if factor <= 0 then
    stopFueling()
  else
    if not defaultEnergyType then
      initializeDefaultEnergyType()
    end
    if defaultEnergyType and not energyTypeFuelingActive[defaultEnergyType] then
      if getRelativeFuelLevel() < 1 then
        startFuelingType(defaultEnergyType)
      end
    end
  end
  fuelFlowRate = maxFuelFlowRate * factor
end

local function isFuelingActive()
  return fuelingActive
end

local function getFuelingData()
  return fuelingData
end

local function endTransaction()
  popActionMap("Refueling")
  table.clear(fuelingData)
  table.clear(fuelingActive)
  table.clear(energyTypeFuelingActive)
  table.clear(energyTypes)
  showUI = false
  overallPrice = 0
  startingFuelData = nil
  fuelData = nil
  defaultEnergyType = nil
  activateSound(gasSoundId, false)
  activateSound(electricSoundId, false)
  core_vehicleBridge.executeAction(be:getPlayerVehicle(0),'setIgnitionLevel', 3)
  career_saveSystem.saveCurrent()
end

local function payPrice()
  stopFueling()
  if career_modules_playerAttributes.getAttribute("money").value >= overallPrice then
    career_modules_playerAttributes.addAttribute("money", -overallPrice)
    endTransaction()
    activateSound(paySoundId, true)
  end
end

local function onUpdate(dtReal, dtSim)
  if showUI then
    local veh = be:getPlayerVehicle(0)
    if veh:getVelocity():length() > 2 then
      stopFueling()
      endTransaction()
    end
  end

  if fuelData then
    if overallPrice >= career_modules_playerAttributes.getAttribute("money").value then
      stopFueling()
      overallPrice = career_modules_playerAttributes.getAttribute("money").value
    else
      for index, data in ipairs(fuelData) do
        if fuelingActive[index] then
          data.currentEnergy = data.currentEnergy + dtSim * fuelFlowRate
          fuelingData[index].fueledEnergy = data.currentEnergy - startingFuelData[index].currentEnergy
          fuelingData[index].price = math.floor((pricePerMJ[data.energyType] * (fuelingData[index].fueledEnergy / 1000000) * 100) + 0.5) / 100
          if data.currentEnergy > data.maxEnergy then
            data.currentEnergy = data.maxEnergy
            stopFueling(index)
          end
        end
      end

      overallPrice = 0
      for _, data in ipairs(fuelingData) do
        overallPrice = overallPrice + data.price
      end
    end
    if energyTypeFuelingActive["gasoline"] or energyTypeFuelingActive["diesel"] or energyTypeFuelingActive["kerosine"] then
      updateFuelSoundParameters()
    end
  end

  if showUI then
    imgui.SetNextWindowSize(imgui.ImVec2(200, 200), imgui.Cond_FirstUseEver)
    imgui.Begin("Fueling")

    for index, tankData in ipairs(fuelData) do
      if imgui.BeginChild1("Tank " .. index, imgui.ImVec2(0, 150), true) then
        imgui.Text("Tank " .. index)
        imgui.Text(string.format("Fuel Type: %s", tankData.energyType))
        local unit = readableUnit[tankData.energyType]
        imgui.Text(string.format("Energy: %.2f %s / %.2f %s", jouleToReadableUnit(tankData.currentEnergy, tankData.energyType), unit, jouleToReadableUnit(tankData.maxEnergy, tankData.energyType), unit))
        imgui.Text(string.format("Fueled Energy: %.2f %s", jouleToReadableUnit(fuelingData[index].fueledEnergy, tankData.energyType) or 0, unit))

        imgui.Text("Price " .. fuelingData[index].price or 0)
      end
      imgui.EndChild()
    end

    for i, energyType in ipairs(energyTypes) do
      if imgui.Button(string.format("Start Fueling %s ##%d", energyType, i)) then
        setDefaultEnergyType(energyType)
        changeFlowRate(1)
      end
      imgui.SameLine()
      if imgui.Button(string.format("Stop Fueling %s ##%d", energyType, i)) then
        stopFuelingType(energyType)
      end
    end

    imgui.Text(string.format("Overall Price: %.2f $", overallPrice))
    if overallPrice <= career_modules_playerAttributes.getAttribute("money").value then
      if imgui.Button(string.format("Pay")) then
        payPrice()
      end
    else
      imgui.Text("Not enough money to pay")
    end
    imgui.End()
  end
end

local function minimumRefuelingCheck(data)
  local tanksData = data[1]
  for i, tank in ipairs(tanksData) do
    -- for now, always refuel the car in the garage
    --[[if tank.energyType == "electricEnergy" then
      tank.currentEnergy = tank.maxEnergy
    elseif tank.currentEnergy <= tank.maxEnergy * 0.01 then
      tank.currentEnergy = tank.maxEnergy * 0.05
    end]]

    tank.currentEnergy = tank.maxEnergy
  end
  applyFuelData(tanksData)
  gameplay_garageMode.initStepFinished()
end

local function garageModeStartStep()
  local vehId = career_modules_inventory.getCurrentVehicleObjectId()
  if vehId then
    local veh = be:getObjectByID(vehId)
    if veh then
      core_vehicleBridge.requestValue(veh, minimumRefuelingCheck, 'energyStorage')
    end
  end
end

local function onCareerActivatedWhileLevelLoaded()
  gasSoundId = gasSoundId or Engine.Audio.createSource('AudioGui', 'event:>UI>Special>Fueling_Petrol')
  electricSoundId = electricSoundId or Engine.Audio.createSource('AudioGui', 'event:>UI>Special>Fueling_Electric')
  paySoundId = paySoundId or Engine.Audio.createSource('AudioGui', 'event:>UI>Special>Buy')
end

local function onClientStartMission(levelPath)
  onCareerActivatedWhileLevelLoaded()
end

local function onClientEndMission(levelPath)
  gasSoundId = nil
  electricSoundId = nil
end

M.startTransaction = startTransaction
M.getFuelData = getFuelData
M.startFueling = startFueling
M.stopFueling = stopFueling
M.isFuelingActive = isFuelingActive
M.getFuelingData = getFuelingData
M.payPrice = payPrice
M.changeFlowRate = changeFlowRate

M.onUpdate = onUpdate
M.onCareerActivatedWhileLevelLoaded = onCareerActivatedWhileLevelLoaded
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.garageModeStartStep = garageModeStartStep

return M
