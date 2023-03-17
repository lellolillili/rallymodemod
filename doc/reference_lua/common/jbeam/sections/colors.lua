--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local function process(vehicleObj, vehicleConfig, vehicle)
  -- global vehicle color
  local col = vehicleConfig.colors

  if col then
    if col[1] then
      vehicleObj.color = ColorF(col[1][1], col[1][2], col[1][3], col[1][4]):asLinear4F()
    end

    if col[2] then
      vehicleObj.colorPalette0 = ColorF(col[2][1], col[2][2], col[2][3], col[2][4]):asLinear4F()
    end

    if col[3] then
      vehicleObj.colorPalette1 = ColorF(col[3][1], col[3][2], col[3][3], col[3][4]):asLinear4F()
    end
  end
end

M.process = process

return M
