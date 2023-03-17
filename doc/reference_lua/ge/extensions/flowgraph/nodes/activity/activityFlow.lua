-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Activity Flow'
C.color = im.ImVec4(0.03, 0.41, 0.64, 0.75)
C.description = "Provides flow when the activity of this project is ongoing. Also provides flow once when the activity is no longer ongoing."
C.category = 'logic'

C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'started', description = "Puts out flow once, before the first regular update", impulse = true },
  { dir = 'out', type = 'flow', name = 'update', description = "This ticks every frame when the activity is ongoing." },
  { dir = 'out', type = 'flow', name = 'stopped', description = "Puts out flow once, after the activity is no longer ongoing.", impulse = true },
  { dir = 'out', type = 'number', name = 'dtReal', hidden = true, description = "Puts out the real delta time." },
  { dir = 'out', type = 'number', name = 'dtSim', hidden = true, description = "Puts out the simulated delta time." },
  { dir = 'out', type = 'number', name = 'dtRaw', hidden = true, description = "Puts out the raw delta time." }
}

C.tags = { 'activity' }

C.legacyPins = {
  _out = {
    start = 'started',
    stop = 'stopped'
  }
}

-- start ------------------------------------------
function C:start()
  self.pinOut.start.value = true
  self.pinOut.update.value = false
  self.pinOut.stop.value = false
  self:trigger()
end
function C:onExecutionStarted()
  if self.mgr.activity then
    if not gameplay_missions_missionManager.isOngoing(self.mgr.activity) then
      gameplay_missions_missionManager.start(self.mgr.activity)
    end
  else
    self:start()
  end
end
function C:onStartActivity()
  self:start()
end

-- update -----------------------------------------
function C:update(dtReal, dtSim, dtRaw)
  self.mgr.dtReal = dtReal
  self.mgr.dtSim = dtSim
  self.mgr.dtRaw = dtRaw
  self.pinOut.dtReal.value = self.mgr.dtReal
  self.pinOut.dtSim.value = self.mgr.dtSim
  self.pinOut.dtRaw.value = self.mgr.dtRaw
  self.pinOut.start.value = false
  self.pinOut.update.value = true
  self.pinOut.stop.value = false
  self:trigger()
end
function C:onUpdate(...)
  if not self.mgr.activity then
    self:update(...)
  end
end
function C:onUpdateActivity(...)
  self:update(...)
end

-- stop -------------------------------------------
function C:stop()
  self.pinOut.start.value = false
  self.pinOut.update.value = false
  self.pinOut.stop.value = true
  self:trigger()
end

function C:changedRunningState(newState)
  if newState == "stopped" then
    if self.mgr.activity then
      if gameplay_missions_missionManager.isOngoing(self.mgr.activity) then
        self:stop()
        gameplay_missions_missionManager.stop(self.mgr.activity)
      end
    else
      self:stop()
    end
  end
end

function C:onStopActivity()
  self:stop()
end

-----
local colorDisabled = im.ImVec4(1, 1, 1, 0.25)
local colorEnabled  = im.ImVec4(1, 1, 1, 1.00)
function C:drawMiddle()
  im.Text("Activity: "..(self.mgr.activity and "yes" or "no"))
  im.TextColored(self.mgr.activity and colorEnabled or colorDisabled, self.mgr.activity and ("..."..self.mgr.activity.id:sub(-15)) or "(standalone)")
end
function C:drawTooltip()
  im.BeginTooltip()
  im.Text(self.mgr.activity and ("This flowgraph is being managed by activity id: "..self.mgr.activity.id) or "This flowgraph has no associated activity. Running in limited compatibility mode (some activity nodes may not work correctly)")
  im.EndTooltip()
end

return _flowgraph_createNode(C)
