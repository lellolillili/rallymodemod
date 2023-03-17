-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Stars Active'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
C.description = "Lets flow through if stars with specific keys are active. Only lets flow through if this mission is played in career."
C.category = 'repeat_instant'

C.pinSchema = {}

C.allowedManualPinTypes = {
  flow = true,
}


C.tags = {'activity'}

function C:init()
  self.savePins = true
  self.allowCustomOutPins = true
end

function C:work()
  if self.pinIn.flow.value and self.mgr.activity and self.mgr.activity.careerSetup.starsActive then
    for _, pin in pairs(self.pinOut) do
      if pin.type == 'flow' then
        pin.value = self.mgr.activity.careerSetup.starsActive[pin.name] or false
      end
    end
  else
    for _, pin in pairs(self.pinOut) do
      if pin.type == 'flow' then
        pin.value = false
      end
    end
  end
end


return _flowgraph_createNode(C)
