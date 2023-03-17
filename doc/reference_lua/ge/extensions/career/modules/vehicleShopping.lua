-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local jbeamIO = require('jbeam/io')

local vehicleAmount = 10

local shoppingSessionActive = false
local vehiclesInShop
local previousVehicleId
local selectedVehicleIndex

local function sendDataToUi()
  local data = {}
  data.vehiclesInShop = vehiclesInShop
  data.selectedVehicleIndex = selectedVehicleIndex
  guihooks.trigger("vehicleShoppingData", vehiclesInShop)
end

local function calculateVehicleValue(index)
  local playerVehicleData = extensions.core_vehicle_manager.getPlayerVehicleData()
  local value = 0
  for slot, partName in pairs(playerVehicleData.chosenParts) do
    local jbeamData = jbeamIO.getPart(playerVehicleData.ioCtx, partName)
    if jbeamData and jbeamData.information then
      value = value + (jbeamData.information.value or 100)
    end
  end

  return value
end

local function generateVehicleList()
  local vehicleData = core_multiSpawn.createGroup(vehicleAmount)
  for _, spawnData in ipairs(vehicleData) do
    spawnData.paintName = "random"
  end

  vehicleData = core_multiSpawn.setVehicleSpawnData(vehicleData, vehicleAmount)

  vehiclesInShop = {}
  for _, spawnData in ipairs(vehicleData) do
    spawnData.paintName = "random"
    local vehicle = {}
    vehicle.value = 1000
    vehicle.spawnData = spawnData
    table.insert(vehiclesInShop, vehicle)
  end

  sendDataToUi()
end

local function spawnVehicle(index)
  selectedVehicleIndex = index
  local spawnData = vehiclesInShop[index].spawnData
  local vehicleData = {}
  vehicleData.config = spawnData.config
  core_vehicles.replaceVehicle(spawnData.model, vehicleData)
  vehiclesInShop[index].value = calculateVehicleValue(index)

  sendDataToUi()
end

-- TODO At this point, the part conditions of the previous vehicle should have already been saved. for example when entering the garage
local spawnFirstShoppingVehicle
local function startShopping()
  shoppingSessionActive = true
  previousVehicleId = career_modules_inventory.getCurrentVehicle()
  generateVehicleList()
  spawnFirstShoppingVehicle = true
  career_modules_inventory.enterVehicle(nil)
end

local function onEnterVehicleFinished()
  if spawnFirstShoppingVehicle then
    spawnVehicle(1)
    spawnFirstShoppingVehicle = nil
  end
end

local function endShopping()
  shoppingSessionActive = false
  previousVehicleId = nil
  vehiclesInShop =  nil
end

local function cancelShopping()
  career_modules_inventory.enterVehicle(previousVehicleId)
  endShopping()
end

local function applyShopping()
  local previewVehicleValue = vehiclesInShop[selectedVehicleIndex].value
  if career_modules_playerAttributes.getAttribute("money").value < previewVehicleValue then return end
  local vehId = career_modules_inventory.addVehicle(be:getPlayerVehicleID(0))
  career_modules_inventory.enterVehicle(vehId)
  endShopping()
  career_modules_playerAttributes.addAttribute("money", -previewVehicleValue)
end

local function isShoppingSessionActive()
  return shoppingSessionActive
end

local function getVehiclesInShop()
  return vehiclesInShop
end

local function getSelectedVehicleIndex()
  return selectedVehicleIndex
end

M.startShopping = startShopping
M.spawnVehicle = spawnVehicle

M.cancelShopping = cancelShopping
M.applyShopping = applyShopping

M.isShoppingSessionActive = isShoppingSessionActive
M.getVehiclesInShop = getVehiclesInShop
M.getSelectedVehicleIndex = getSelectedVehicleIndex

M.onEnterVehicleFinished = onEnterVehicleFinished

return M