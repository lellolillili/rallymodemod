-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Blur'

C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui

C.description = 'Blurs the scene'
C.category = 'repeat_instant'


C.pinSchema = {
  { dir = 'in', type = 'number', name = 'blurAmount', default = 1, description = 'Defines the amount of blur.' },
}

C.tags = { 'gfx', 'blur' }

function C:init(mgr, ...)
  self.lastWorking = 0
  self.blurAmount = 1
  self.blurColor = ColorF(1, 1, 1, 1)
end

function C:postInit()
  self.pinInLocal.blurAmount.numericSetup = {
    min = 0,
    max = 1,
    type = 'float',
    gizmo = 'slider',
  }
end

function C:work()
  self.blurAmount = self.pinIn.blurAmount.value or 1
  self.blurColor = ColorF(1, 1, 1, self.blurAmount)
  self.lastWorking = Engine.Render.getFrameId()
end

function C:onPreRender(dt, dtSim)
  if not extensions.ui_visibility.getCef() then return end
  -- this really does need to happen in the render pass and not in work
  -- work() will tag the thing to be enabled dynamically and it has a timeout of 10 frames
  local frameDiff = Engine.Render.getFrameId() - self.lastWorking
  if frameDiff > 10 then return end

  -- render otherwise
  local o = scenetree.ScreenBlurFX
  if o then
    -- (0, 0) is top left corner; (1, 1) bottom right
    o.obj:addFrameBlurRect(0, 0, 1, 1, self.blurColor)
  end
end


return _flowgraph_createNode(C)
