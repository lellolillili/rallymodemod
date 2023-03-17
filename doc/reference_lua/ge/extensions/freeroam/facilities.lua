-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This module manages general locations and identifications of facilities on a map. It uses map info and sites data to return parking spots and other objects.

-- Feel free to move this module in the future, if needed.

local M = {}

local function getGarage(garageId)
  local fileName = getMissionFilename()
  if not fileName or fileName == '' then return end

  local info = jsonReadFile(fileName)
  if info and info.garagePoints then
    for i, garagePoint in ipairs(info.garagePoints) do
      if not garageId or garagePoint.id == garageId then -- if no name given, return the first one
        return garagePoint
      end
    end
  end
end

local function getBestParkingSpot(vehId, garageId, levelSitesName)
  local garage = getGarage(garageId)
  vehId = vehId or be:getPlayerVehicleID(0)
  local obj = be:getObjectByID(vehId)
  if not obj or not garage then return end

  local garageSites = gameplay_sites_sitesManager.getCurrentLevelSitesByName(levelSitesName or 'garages')
  if garageSites and garage.parkingSpotNames then
    for i, parkingSpotName in ipairs(garage.parkingSpotNames) do
      local parkingSpot = garageSites.parkingSpots.byName[parkingSpotName]
      if parkingSpot and parkingSpot:vehicleFits(obj) then
        return parkingSpot
      end
    end
    return garageSites.parkingSpots.byName[garage.parkingSpotNames[#garage.parkingSpotNames]] -- use the last parking spot as a fallback
  end
end

M.getGarage = getGarage
M.getBestParkingSpot = getBestParkingSpot

return M
