-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Finish Mission'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
C.description = "Stops the current mission."
C.pinSchema = {
  { dir = 'in', type = 'flow', name = "flow", description = "Ends the mission." },
  { dir = 'in', type = 'table', name = "attempt", tableType = "attemptData", description = "Attempt Data" },
}

C.legacyPins = {

}

C.tags = {'activity'}

function C:work()
  self.stopping = true

end
function C:_afterTrigger()
  if not self.stopping then return end
  self.stopping = false
  local att = self.pinIn.attempt.value or gameplay_missions_progress.newAttempt("attempted", {})


  if self.mgr.activity then
    --log("I", "", "Saving attempt: "..dumps(att))
    gameplay_missions_missionManager.stop(self.mgr.activity, {attempt = att})
  else
    log("W", "", "No associated activity, attempt discarded: "..dumps(att))
    self.mgr:setRunning(false)
    ui_fadeScreen.stop(0)
  end
end

return _flowgraph_createNode(C)
