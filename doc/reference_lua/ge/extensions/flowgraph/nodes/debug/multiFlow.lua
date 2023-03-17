-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Multi Flow'
C.description = "Multiple flow test node."
C.todo = "Maybe merge this with displayFlow node"
C.category = 'logic'

C.type = 'simple'
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'a', description = 'Inflow to test.'},
  {dir = 'in', type = 'flow', name = 'b', description = 'Inflow to test.'},
  {dir = 'in', type = 'flow', name = 'c', description = 'Inflow to test.'},
  {dir = 'in', type = 'flow', name = 'd', description = 'Inflow to test.'},
}

C.tags = {'util'}
function C:init()
  self.data.logOnWork = false
end

function C:work()
  if self.data.logOnWork then
    print("a: " .. (self.pinIn.a.value and "true" or "false"))
    print("b: " .. (self.pinIn.b.value and "true" or "false"))
    print("c: " .. (self.pinIn.c.value and "true" or "false"))
    print("d: " .. (self.pinIn.d.value and "true" or "false"))
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()

  local activeBool = self.pinIn.a.value -- (im.GetIO().Framerate)
  local activeColor = im.ImVec4(0, 1, 0, (activeBool and 1 or 0.5))
  local iconImage = activeBool and editor.icons.check_box or editor.icons.check_box_outline_blank
  editor.uiIconImage(iconImage, im.ImVec2(32, 32), activeColor)

  activeBool = self.pinIn.b.value -- (im.GetIO().Framerate)
  activeColor = im.ImVec4(1, 1, 0, (activeBool and 1 or 0.5))
  iconImage = activeBool and editor.icons.check_box or editor.icons.check_box_outline_blank
  editor.uiIconImage(iconImage, im.ImVec2(32, 32), activeColor)

    activeBool = self.pinIn.c.value -- (im.GetIO().Framerate)
  activeColor = im.ImVec4(1, 0, 0, (activeBool and 1 or 0.5))
  iconImage = activeBool and editor.icons.check_box or editor.icons.check_box_outline_blank
  editor.uiIconImage(iconImage, im.ImVec2(32, 32), activeColor)

    activeBool = self.pinIn.d.value -- (im.GetIO().Framerate)
  activeColor = im.ImVec4(1, 0, 1, (activeBool and 1 or 0.5))
  iconImage = activeBool and editor.icons.check_box or editor.icons.check_box_outline_blank
  editor.uiIconImage(iconImage, im.ImVec2(32, 32), activeColor)

end


return _flowgraph_createNode(C)
