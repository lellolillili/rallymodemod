--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local function process(vehicle)
  profilerPushEvent('jbeam/assorted.process')

  -- post process engine differential
  if vehicle.engine ~= nil then
    vehicle.engine.waterDamage = vehicle.engine.waterDamage or {}
    vehicle.engine.waterDamage.nodes = {}
    arrayConcat(vehicle.engine.waterDamage.nodes, vehicle.engine.waterDamage._group_nodes or {})
    arrayConcat(vehicle.engine.waterDamage.nodes, vehicle.engine.waterDamage._engineGroup_nodes or {})
  end

  -- soundscape
  if vehicle.soundscape ~= nil then
    local newTable = {}
    for _, v in pairs(vehicle.soundscape) do
      newTable[v.name] = v
    end
    vehicle.soundscape = newTable
  end

  profilerPopEvent() -- jbeam/assorted.process
end

M.process = process

return M