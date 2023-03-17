-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Activity Attempt'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
C.description = "Creates an attempt for an activity."
C.category = 'once_instant'

C.pinSchema = {

  --{ dir = 'in', type = 'string', name = "type", description = "Attempt Type. Can be 'completed' (100%), 'passed' (enough to unlock next missions etc), 'attempted' (not enough to proceed, but not failed), and 'failed'", fixed=true },
  { dir = 'in', type = 'bool', name = "passed", description = "If this attempt will unlock next mission etc.", fixed=true },
  { dir = 'in', type = 'bool', name = "completed", description = "If this attempt got the best score and considers the mission completed.", fixed=true },
  { dir = 'out', type = 'table', name = "attempt", tableType = "attemptData", description = "Attempt Data for other nodes to process", fixed=true },

}

C.tags = {'activity'}
C.allowedManualPinTypes = {
  flow = false,
  string = true,
  number = true,
  bool = true,
  any = true,
  table = true,
  vec3 = true,
  quat = true,
  color = true,
}


function C:init()
  self.savePins = true
  self.allowCustomInPins = true
end

function C:postInit()
    --[[self.pinInLocal.type.hardTemplates = {
    {label = "completed (Got all there is to get)", value = "completed"},
    {label = "passed (Enough to unlock next mission)", value = "passed"},
    {label = "attempted (not enough tp proceed, but not failed)", value = "passed"},
    {label = "failed (failure)", value = "failed"},
  }]]
end

function C:workOnce()
  if self.pinIn.flow.value then
    local tData = {}
    local added = false
    for name, pin in pairs(self.pinIn) do
      if not pin.fixed then
        tData[name] = pin.value
        added = true
      end
    end
    local type = 'attempted'
    --if self.pinIn.passed.value then type = 'passed' end
    --if self.pinIn.completed.value then type = 'completed' end
    local attempt = gameplay_missions_progress.newAttempt(type, tData)
    self.pinOut.attempt.value = attempt
  end
end


return _flowgraph_createNode(C)
