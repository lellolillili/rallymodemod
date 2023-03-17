-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local jbeamIO = require('jbeam/io')

local parts = {}

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

local function installPart(part, vehId)
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

local function doesVehicleHaveSlot(vehObjId, slot)
  local vehicleData = extensions.core_vehicle_manager.getVehicleData(vehObjId)
  return vehicleData.chosenParts[slot]
end

local function movePart(from, to, part)
  if from >= 1 then

  end

  if to >= 1 then
    local vehObjId = career_modules_inventory.getObjectIdFromVehicleId(to)
    if not vehObjId then return end

  end

  -- The part couldnt be moved
  return false
end


return M