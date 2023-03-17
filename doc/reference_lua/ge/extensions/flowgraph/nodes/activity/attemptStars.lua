-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'ActivityAttempt Stars'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
C.description = "Adds fulfilled stars to an attempt. Add mroe pins to add star keys."
C.category = 'once_instant'

C.pinSchema = {

  { dir = 'in',  type = 'table', name = "attempt", tableType = "attemptData", description = "Attempt Data for other nodes to process", fixed=true },
  { dir = 'out', type = 'table', name = "attempt", tableType = "attemptData", description = "Attempt Data for other nodes to process", fixed=true },
}

C.allowedManualPinTypes = {
  bool = true,
}


C.tags = {'activity'}

function C:init()
  self.savePins = true
  self.allowCustomInPins = true
end

function C:workOnce()
  if self.pinIn.flow.value then
    local attempt = self.pinIn.attempt.value
    attempt.unlockedStars =  attempt.unlockedStars or {}
    for name, pin in pairs(self.pinInLocal) do
      if not pin.fixed and pin.type ~= 'flow' then
        attempt.unlockedStars[name] = self.pinIn[name].value or false
      end
    end
    self.pinOut.attempt.value = attempt
  end
end


return _flowgraph_createNode(C)
