-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local jbeamIO = require('jbeam/io')

local shoppingSessionActive = false
local initialVehicle
local initialVehicleParts
local previewVehicle
local shoppingCart

local partInfos
local partToSlotMap
local currentVehicle

-- From: https://web.archive.org/web/20131225070434/http://snippets.luacode.org/snippets/Deep_Comparison_of_Two_Values_3
-- available under MIT/X11
local function compareParts(t1,t2)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 == 'number' then return math.floor(t1*1000) == math.floor(t2*1000)  end
  if ty1 ~= 'table' then return t1 == t2 end

  local testedKeys = {}
  for k1, v1 in pairs(t1) do
    if k1 ~= "id" then
      local v2 = t2[k1]
      if v2 == nil or not compareParts(v1, v2) then return false end
      testedKeys[k1] = true
    end
  end
  for k2, v2 in pairs(t2) do
    if k2 ~= "id" then
      if not testedKeys[k2] then
        local v1 = t1[k2]
        if v1 == nil or not compareParts(v1, v2) then return false end
      end
    end
  end
  return true
end

local function convertShoppingCartForUI()
  shoppingCart.partsInList = {}
  shoppingCart.partsOutList = {}
  shoppingCart.slotList = {}

  -- Convert the partsIn/partsOut tables to lists
  local slotsAdded = {}
  local counter = 1
  for slot, part in pairs(shoppingCart.partsIn) do
    shoppingCart.slotList[counter] = slot
    shoppingCart.partsInList[counter] = part
    shoppingCart.partsOutList[counter] = shoppingCart.partsOut[part.slot]
    slotsAdded[part.slot] = true
    counter = counter + 1
  end

  for slot, part in pairs(shoppingCart.partsOut) do
    if not slotsAdded[part.slot] then
      shoppingCart.slotList[counter] = slot
      shoppingCart.partsOutList[counter] = part
      slotsAdded[part.slot] = true
      counter = counter + 1
    end
  end

  --dump(shoppingCart.slotList)
  --dump(shoppingCart.partsInList)
  --dump(shoppingCart.partsOutList)

  -- Calculate the total price of the whole shopping cart
  local total = 0
  for slot, part in pairs(shoppingCart.partsIn) do
    total = total + part.value
  end
  for slot, part in pairs(shoppingCart.partsOut) do
    total = total - part.value
  end
  shoppingCart.total = total
end

local function updatePreviewVehicle(currentPartConditions)
  -- get the data
  local playerVehicleData = extensions.core_vehicle_manager.getPlayerVehicleData()
  if not playerVehicleData then
    log('E', 'inventory', 'unable to get vehicle data')
    return false
  end
  local vehicles = career_modules_inventory.vehicles
  if not currentVehicle then return end

  previewVehicle.config.parts = deepcopy(playerVehicleData.chosenParts)
  if currentPartConditions then
    previewVehicle.partConditions = currentPartConditions
  end

  partInfos = {partsInVehicle = {}, partsInShop = {}}
  local availableParts = jbeamIO.getAvailableParts(playerVehicleData.ioCtx)
  local slotMap = jbeamIO.getAvailableSlotMap(playerVehicleData.ioCtx)

  -- Make a map from part to its slot
  partToSlotMap = {}
  for slotName, parts in pairs(slotMap) do
    for _, part in ipairs(parts) do
      partToSlotMap[part] = slotName
    end
  end

  local partId = 1
  for partName, partCondition in pairs(previewVehicle.partConditions) do
    local jbeamData = jbeamIO.getPart(playerVehicleData.ioCtx, partName)
    local part = {}
    part.name = partName
    part.value = jbeamData.information.value or 100
    part.partCondition = partCondition
    part.description = availableParts[partName] or "no description found"
    part.tags = {}
    part.slot = partToSlotMap[partName]
    part.id = partId

    partInfos.partsInVehicle[partName] = part
    partId = partId + 1
  end

  if not initialVehicleParts then
    initialVehicleParts = deepcopy(partInfos.partsInVehicle)
  end

  -- Compare old parts with new parts to see what has changed
  shoppingCart.partsIn = {}
  shoppingCart.partsOut = {}
  for partName, part in pairs(partInfos.partsInVehicle) do
    local oldPartName = initialVehicle.config.parts[part.slot]
    local oldPart = initialVehicleParts[oldPartName]
    if not oldPart then
      shoppingCart.partsIn[part.slot] = part
    elseif not compareParts(part, oldPart) then
      shoppingCart.partsIn[part.slot] = part
      shoppingCart.partsOut[part.slot] = oldPart
    end
  end
  for partName, part in pairs(initialVehicleParts) do
    local newPartName = previewVehicle.config.parts[part.slot]
    local newPart = partInfos.partsInVehicle[newPartName]
    if not newPart then
      shoppingCart.partsOut[part.slot] = part
    end
  end
  convertShoppingCartForUI()

  for partName, partInfo in pairs(availableParts) do
    if playerVehicleData.chosenParts[partToSlotMap[partName]] then
      local jbeamData = jbeamIO.getPart(playerVehicleData.ioCtx, partName)
      local part = {}
      part.name = partName
      part.value = jbeamData.information.value or 100
      part.partCondition = {0, 1, 1}
      part.description = partInfo.description or "no description found"
      part.tags = {}
      part.slot = partToSlotMap[partName]
      part.id = partId

      partInfos.partsInShop[partName] = part
      partId = partId + 1
    end
  end

  local data = {
    mainPartName     = playerVehicleData.mainPartName,
    chosenParts      = playerVehicleData.chosenParts,
    variables        = playerVehicleData.vdata.variables,
    slotMap          = slotMap,
    shoppingCart     = shoppingCart
  }

  data.partInfos = partInfos

  guihooks.trigger("partShoppingData", data)
end

local function startShopping()
  local vehicles = career_modules_inventory.vehicles
  currentVehicle = career_modules_inventory.getCurrentVehicle()
  if not currentVehicle then return end

  shoppingCart = {partsIn = {}, partsOut = {}, total = 0}
  shoppingSessionActive = true

  initialVehicle = deepcopy(vehicles[currentVehicle])
  local playerVehicleData = extensions.core_vehicle_manager.getPlayerVehicleData()
  initialVehicle.config.parts = deepcopy(playerVehicleData.chosenParts)
  previewVehicle = deepcopy(initialVehicle)
  updatePreviewVehicle()
end

local newPartInstalled = false
local function installPart(part)
  if not shoppingSessionActive then return end
  local previousPartName = initialVehicle.config.parts[part.slot]
  local previousPart = initialVehicleParts[previousPartName]

  local carModelToLoad = previewVehicle.model
  local vehicleData = {}
  vehicleData.config = previewVehicle.config
  vehicleData.config.parts[part.slot] = part.name

  -- Add the partCondition of the new part to the previewVehicle
  previewVehicle.partConditions[part.name] = part.partCondition

  core_vehicles.replaceVehicle(carModelToLoad, vehicleData)
  be:getPlayerVehicle(0):queueLuaCommand("partCondition.initConditions(" .. serialize(previewVehicle.partConditions) .. ", " .. part.partCondition[1] .. ", " .. part.partCondition[2] .. ", " .. part.partCondition[3] .. ")")
  -- Doing the callback immediately will result in wrong values for some parts, so we do it one frame later in the update function
  newPartInstalled = true
end

local function installPartById(id)
  for partName, part in pairs(partInfos.partsInShop) do
    if part.id == id then
      installPart(part)
      return
    end
  end
end

local function onUpdate()
  if not shoppingSessionActive or not newPartInstalled then return end
  queueCallbackInVehicle(be:getPlayerVehicle(0), "career_modules_partShopping.updatePreviewVehicle", "partCondition.getConditions()")
  newPartInstalled = false
end

local function endShopping()
  shoppingSessionActive = false
  initialVehicleParts = nil
end

local function cancelShopping()
  career_modules_inventory.enterVehicle(currentVehicle)
  endShopping()
end

local function applyShopping()
  if career_modules_playerAttributes.getAttribute("money").value < shoppingCart.total then return end
  local vehicles = career_modules_inventory.vehicles
  vehicles[currentVehicle] = previewVehicle
  career_modules_inventory.enterVehicle(currentVehicle)
  endShopping()
  career_modules_playerAttributes.addAttribute("money", -shoppingCart.total)
  career_saveSystem.saveCurrent()
end

local function isShoppingSessionActive()
  return shoppingSessionActive
end

local function getPartInfos()
  return partInfos
end

local function getShoppingCart()
  return shoppingCart
end

M.startShopping = startShopping
M.installPart = installPart
M.installPartById = installPartById
M.updatePreviewVehicle = updatePreviewVehicle
M.cancelShopping = cancelShopping
M.applyShopping = applyShopping

M.getPartInfos = getPartInfos
M.getShoppingCart = getShoppingCart
M.isShoppingSessionActive = isShoppingSessionActive

M.onUpdate = onUpdate

return M