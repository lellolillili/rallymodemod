-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Bullet Time'
C.icon = "av_timer"
C.description = "Slows down the passage of time."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'instant', hidden = true, description = 'Defines if the bullet time should start instantly. Otherwise the speed will slowly reach the desired value.' },
  { dir = 'in', type = 'number', name = 'value', description = 'Defines the speed for the bullet time. 0 will pause the game.' },
}

C.tags = { "slow", "fast", "slowmo", "zeitlupe" }

function C:_executionStopped()
  bullettime.set(1)
end

function C:postInit()
  self.pinInLocal.value.numericSetup = {
    min = 0,
    max = 1,
    type = 'float',
    gizmo = 'slider',
  }
end

function C:work()
  if self.pinIn.flow.value then
    if self.pinIn.value.value == 0 then
      bullettime.pause(true)
    else
      if self.pinIn.instant.value then
        bullettime.setInstant(self.pinIn.value.value or 1)
      else
        bullettime.set(self.pinIn.value.value or 1)
      end
      bullettime.pause(false)
    end
  end
end

return _flowgraph_createNode(C)
