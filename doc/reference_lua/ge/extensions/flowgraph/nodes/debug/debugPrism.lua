-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Debug Prism'
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.description = "Draws a debug Prism"
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'widthA', hardcoded = true, default = 1, description = 'Width of the Prism at point A' },
  { dir = 'in', type = 'number', name = 'heightA', hardcoded = true, default = 1, description = 'Height of the Prism at point A' },
  { dir = 'in', type = 'vec3', name = 'posA', description = 'Start of this Prism.' },
  { dir = 'in', type = 'number', name = 'widthB', hardcoded = true, default = 1, description = 'Width of the Prism at point B' },
  { dir = 'in', type = 'number', name = 'heightB', hardcoded = true, default = 1, description = 'Height of the Prism at point B' },
  { dir = 'in', type = 'vec3', name = 'posB', description = 'End of this Prism.' },
  { dir = 'in', type = 'color', name = 'color', hidden = true, hardcoded = true, default = { 0.91, 0.05, 0.48, 0.5 }, description = 'Color of the Prism, defaults to pink.' },
}

C.tags = {'util', 'draw'}

function C:init()
end

function C:work()
  if self.pinIn.posA.value ~= nil and self.pinIn.posB.value ~= nil then
    local color
    if self.pinIn.color.value ~= nil then
      color = ColorF(self.pinIn.color.value[1], self.pinIn.color.value[2], self.pinIn.color.value[3], self.pinIn.color.value[4] or 0.5)
    else
      color = ColorF(0.91,0.05,0.48,0.5)
    end

    debugDrawer:drawSquarePrism(
      vec3(self.pinIn.posA.value),
      vec3(self.pinIn.posB.value),
      Point2F(self.pinIn.heightA.value or 1, self.pinIn.widthA.value or 1),
      Point2F(self.pinIn.heightB.value or 1, self.pinIn.widthB.value or 1),
      color)
  end
end

return _flowgraph_createNode(C)
