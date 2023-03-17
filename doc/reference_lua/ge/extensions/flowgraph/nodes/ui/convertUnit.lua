-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'ConvertUnit'
C.description = "Translates Units to user preference."
C.category = 'repeat_instant'

C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'value', description = 'Value to convert.' },
  { dir = 'in', type = 'bool', name = 'velocity', default = false, hidden = true, description = 'Using velocity instead of distance' },
  { dir = 'in', type = 'bool', name = 'big', default = false, hidden = true, description = 'Using big result (km, mi, h)' },
  { dir = 'in', type = 'string', name = 'format', default = "%0.2f%s", hidden = true, description = 'Format for the full output pin.' },
  { dir = 'out', type = 'number', name = 'value', description = 'Numerical value' },
  { dir = 'out', type = 'string', name = 'unit', description = 'Unit' },
  { dir = 'out', type = 'string', name = 'full', description = 'Numerical value plus unit formatted by the format in-pin.', hidden=true },
}

function C:work()
  local fun = self.pinIn.velocity.value and translateVelocity or translateDistance
  local value, unit = fun(self.pinIn.value.value, self.pinIn.big.value)
  self.pinOut.value.value = value
  self.pinOut.unit.value = unit
  if self.pinOut.full:isUsed() then
    if self.pinIn.format.value then
      self.pinOut.full.value = string.format(self.pinIn.format.value, value, unit)
    else
      self.pinOut.full.value = string.format("%0.2f%s", value, unit)
    end
  end
end

return _flowgraph_createNode(C)
