-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Set Vehicle Colors'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.description = 'Sets vehicle colors.'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'ID of vehicle to change color to. If empty, player vehicle will be used.' },
  { dir = 'in', type = 'color', name = 'color1', description = 'Primary color.' },
  { dir = 'in', type = 'color', name = 'color2', description = 'Secondary color.' },
  { dir = 'in', type = 'color', name = 'color3', description = 'Tertiary color.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {'colors', 'colours', 'vehicle'}

function C:postInit()
  self.pinInLocal.color1.colorSetup = {
    vehicleColor = true
  }

  self.pinInLocal.color2.colorSetup = {
    vehicleColor = true
  }

  self.pinInLocal.color3.colorSetup = {
    vehicleColor = true
  }
end

function C:work()
  local veh = self.pinIn.vehId.value or be:getPlayerVehicleID(0)
  local obj = scenetree.findObjectById(veh)

  local paintsData = {}
  if self.pinIn.color1.value ~= nil then
    local color = self.pinIn.color1.value
    local paint = createVehiclePaint({x = color[1], y = color[2], z = color[3], w = color[4]}, {color[5], color[6], color[7], color[8]})
    obj.color = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
    paintsData[1] = paint
  end

  if self.pinIn.color2.value ~= nil then
    local color = self.pinIn.color2.value
    local paint = createVehiclePaint({x = color[1], y = color[2], z = color[3], w = color[4]}, {color[5], color[6], color[7], color[8]})
    obj.colorPalette0 = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
    paintsData[2] = paint
  end

  if self.pinIn.color3.value ~= nil then
    local color = self.pinIn.color3.value
    local paint = createVehiclePaint({x = color[1], y = color[2], z = color[3], w = color[4]}, {color[5], color[6], color[7], color[8]})
    obj.colorPalette1 = ColorF(paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4]):asLinear4F()
    paintsData[3] = paint
  end
  obj:setMetallicPaintData(paintsData)
end

return _flowgraph_createNode(C)
