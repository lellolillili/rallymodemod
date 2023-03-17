--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local function process(vehicleObj, vehicleConfig, vehicle)
  local paints = vehicleConfig.paints
  if not paints and vehicleConfig.colors then
    paints = convertVehicleColorsToPaints(vehicleConfig.colors)
  end

  if paints and type(paints) == 'table' then
    local paint = paints[1]
    if paint then
      validateVehiclePaint(paint)
      vehicleObj.color = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
    end

    paint = paints[2]
    if paint then
      validateVehiclePaint(paint)
      vehicleObj.colorPalette0 = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
    end

    paint = paints[3]
    if paint then
      validateVehiclePaint(paint)
      vehicleObj.colorPalette1 = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
    end
    vehicleObj:setMetallicPaintData(paints)
  end
end

M.process = process

return M
