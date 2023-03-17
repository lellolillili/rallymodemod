-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.vehicleDriven = {
  info = 'The player has to be seated in a vehicle.',
  getLabel = function(c) return {txt = "Driving a vehicle"} end,
  conditionMet = function(c) return true, {} end
}

--[[
M.busDriven = {
  info = 'The player has to be seated in a bus.',
  conditionString = function(c) return "Driving a bus" end,
  conditionMet = function(c)
    if not M.vehicleDriven.conditionMet(c) then return false end
    local vDetails = core_vehicles.getCurrentVehicleDetails()
    if not vDetails or not vDetails.model then return false end
    return vDetails.model['Body Style'] == 'Bus'

  end
}
]]
return M