-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Debug Cylinder'
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.description = "Draws a debug Cylinder."
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'in', type = 'number', name = 'radius', description = 'Radius of the Cylinder' },
    { dir = 'in', type = 'vec3', name = 'posA', description = 'Start of this Cylinder.' },
    { dir = 'in', type = 'vec3', name = 'posB', description = 'End of this Cylinder.' },
    { dir = 'in', type = 'color', name = 'color', hidden = true, hardcoded = true, default = { 0.91, 0.05, 0.48, 0.5 }, description = 'Color of the Cylinder, defaults to pink.' },
}

C.tags = {'util', 'draw'}

function C:init()
end

local color = ColorF(1,1,1,1)
local defaultColor = {0.91,0.05,0.48,0.5}
local posA = vec3()
local posB = vec3()
function C:work()
  if self.pinIn.posA.value ~= nil and self.pinIn.posB.value ~= nil then
    if self.pinIn.color.value ~= nil then
      color.r = self.pinIn.color.value[1]
      color.g = self.pinIn.color.value[2]
      color.b = self.pinIn.color.value[3]
      color.a = self.pinIn.color.value[4] or 0.5
    else
      color.r = defaultColor[1]
      color.g = defaultColor[2]
      color.b = defaultColor[3]
      color.a = defaultColor[4]
    end
    posA:setFromTable(self.pinIn.posA.value)
    posB:setFromTable(self.pinIn.posB.value)
    debugDrawer:drawCylinder(posA, posB, self.pinIn.radius.value or 1, color)
  end
end

return _flowgraph_createNode(C)
