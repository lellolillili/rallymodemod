-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Debug Text'
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.description = "Draws debug Text at a position."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'vec3', name = 'pos', description = 'Position of the Text.' },
  { dir = 'in', type = 'any', name = 'text', description = 'The text to be displayed.' },
  { dir = 'in', type = 'color', name = 'colorText', hidden = true, hardcoded = true, default = { 1, 1, 1, 1 }, description = 'Color of the text, defaults to white.' },
  { dir = 'in', type = 'color', name = 'colorBG', hidden = true, hardcoded = true, default = { 0, 0, 0, 0.75 }, description = 'Color of the background, defaults to semi-transparent black.' },
}

C.tags = {'util', 'draw'}

function C:init()
end

function C:work()
  local pos = vec3(self.pinIn.pos.value)
  local clr = ColorF(1,1,1,1)
  if self.pinIn.colorText.value then
    clr = ColorF(self.pinIn.colorText.value[1],self.pinIn.colorText.value[2],self.pinIn.colorText.value[3],self.pinIn.colorText.value[4])
  end
  local clrBG = ColorI(0,0,0,192)
  if self.pinIn.colorBG.value then
    clrBG = ColorI(self.pinIn.colorBG.value[1]*255,self.pinIn.colorBG.value[2]*255,self.pinIn.colorBG.value[3]*255,self.pinIn.colorBG.value[4]*255)
  end
  debugDrawer:drawTextAdvanced(pos, String(tostring(self.pinIn.text.value)), clr, true, false, clrBG)
end

return _flowgraph_createNode(C)
