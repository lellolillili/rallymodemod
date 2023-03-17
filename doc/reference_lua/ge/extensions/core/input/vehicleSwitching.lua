-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}
local vehicleOrder = nil

-- order is a list of vehicle IDs
local function setVehicleOrder(order)
  vehicleOrder = order
end

local lastIndex = -1

local function switchCycleVehicle(player, dir)
  player = player or 0
  -- custom order only if vehicleOrder is present, otherwise default behaviour
  if vehicleOrder ~= nil and #vehicleOrder > 0 then
    local currentId = be:getPlayerVehicleID(player)
    local currentIndex = tableFindKey(vehicleOrder, currentId) or lastIndex
    if currentIndex ~= -1 then
      -- cycle index
      local nextIndex = (currentIndex + dir)
      if nextIndex > #vehicleOrder then
        nextIndex = nextIndex - #vehicleOrder
      elseif nextIndex < 1 then
        nextIndex = nextIndex + #vehicleOrder
      end

      local nextId = vehicleOrder[nextIndex]
      if scenetree.findObjectById(nextId) then
        if be then
          be:enterVehicle(player, scenetree.findObjectById(nextId))
          extensions.hook('trackNewVeh')
        end
        return
      else
        log("E","","Tried switching with custom order to vehicle, but vehicle not found! ")
        vehicleOrder = nil
      end
    else
      log("E","","Tried switching with custom order to vehicle, but player is not in a vehicle in the list!")
      vehicleOrder = nil
    end
  end

  -- if no success with custom order, use default behaviour
  if be then
    be:enterNextVehicle(player, dir)
    extensions.hook('trackNewVeh')
  end
end
M.switchCycleVehicle = switchCycleVehicle
M.setVehicleOrder = setVehicleOrder
return M
