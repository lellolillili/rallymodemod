-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Color HSV'
C.description = "Creates a color using the HSV color scheme. All input values are between 0 and 1"
C.category = 'simple'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'h', description = 'Hue' },
  { dir = 'in', type = 'number', name = 's', description = 'Saturation' },
  { dir = 'in', type = 'number', name = 'v', description = 'Value' },
  { dir = 'in', type = 'number', name = 'a', description = 'Alpha, controls paint chrominess in vehicles' },
  { dir = 'out', type = 'color', name = 'color', description = 'Output as color type' },
}

C.tags = {'variable'}

function C:init()

end

function C:HSVtoRGB(h,s,v)

  h = h - math.floor(h)

  h = math.max(0, math.min(1, h))
  s = math.max(0, math.min(1, s))
  v = math.max(0, math.min(1, v))

  local hi = math.floor(h * 6.0)
  local f = (h * 6.0) - hi

  local p = v * (1.0 - s)
  local q = v * (1.0 - s * f)
  local t = v * (1.0 - s * (1.0 - f))

  local rgb = {v, t, p}

  if hi == 1 then
    rgb = {q, v, p}
  elseif hi == 2 then
    rgb = {p, v, t}
  elseif hi == 3 then
    rgb = {p, q, v}
  elseif hi == 4 then
    rgb = {t, p, v}
  elseif hi == 5 then
    rgb = {v, p, q}
  end

  return rgb
end

function C:work()
  local rgb = self:HSVtoRGB(self.pinIn.h.value or 0, self.pinIn.s.value or 1, self.pinIn.v.value or 1)
  self.pinOut.color.value = {rgb[1],rgb[2],rgb[3], self.pinIn.a.value or 1}
end

return _flowgraph_createNode(C)
