-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Display Flow'
C.type = 'simple'
C.description = "Displays a checked box when flow reaches this node."
C.category = 'logic'
C.todo = "Randomly bugs out when first starting the execution sometimes"

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'value', description = 'Inflow for this node.' },
}

C.tags = {'util'}
function C:init()
  self.lastTime = 1
  self.time = 0
  self.lastUsedFrame = 0
end

function C:work()
  self.lastTime = self.time
  self.time = 0
  self.lastUsedFrame = self.mgr.frameCount
end

function C:drawMiddle(builder, style)
  builder:Middle()

  local activeBool = self.mgr.frameCount - self.lastUsedFrame < 5 -- (im.GetIO().Framerate)
  local activeColor = im.ImVec4(0, 1, 0, (activeBool and 1 or 0.5))
  local iconImage = activeBool and editor.icons.check_box or editor.icons.check_box_outline_blank
  editor.uiIconImage(iconImage, im.ImVec2(32, 32), activeColor)

  self.time = self.time + self.mgr.dtReal
end

function C:drawTooltip()
  im.BeginTooltip()
  local rate = 1 / self.lastTime
  im.Text('%0.0f fps', rate)
  im.EndTooltip()
end

return _flowgraph_createNode(C)
