-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'on Update'
C.description = "Triggers every frame."
C.color = ui_flowgraph_editor.nodeColors.event
C.icon = ui_flowgraph_editor.nodeIcons.event

C.category = 'logic'
C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'enterState', description = "Outflow when the project enters this state.", impulse = true },
  { dir = 'out', type = 'flow', name = 'flow', description = "Outflow every frame." },
  { dir = 'out', type = 'flow', name = 'exitState', description = "Outflow when the project leaves this state.", impulse = true },
  { dir = 'out', type = 'number', name = 'dtReal', hidden = true, description = "Real delta time." },
  { dir = 'out', type = 'number', name = 'dtSim', hidden = true, description = "Simulated delta time." },
  { dir = 'out', type = 'number', name = 'dtRaw', hidden = true, description = "Raw delta time." }
}


C.tags = {}

function C:init(mgr, ...)
end

function C:onUpdate(dtReal, dtSim, dtRaw)
  self.pinOut.flow.value = true
  self.pinOut.enterState.value = false
  self.pinOut.exitState.value = false
  self.mgr.dtReal = dtReal
  self.mgr.dtSim = dtSim
  self.mgr.dtRaw = dtRaw
  self.pinOut.dtReal.value = self.mgr.dtReal
  self.pinOut.dtSim.value = self.mgr.dtSim
  self.pinOut.dtRaw.value = self.mgr.dtRaw
  self:trigger()
end

function C:onStateStartedTrigger()
  self.pinOut.flow.value = false
  self.pinOut.enterState.value = true
  self.pinOut.exitState.value = false
  self.mgr.dtReal = 0
  self.mgr.dtSim = 0
  self.mgr.dtRaw = 0
  self.pinOut.dtReal.value = self.mgr.dtReal
  self.pinOut.dtSim.value = self.mgr.dtSim
  self.pinOut.dtRaw.value = self.mgr.dtRaw
  self:trigger()
end


function C:onStateStoppedTrigger()
  self.pinOut.flow.value = false
  self.pinOut.enterState.value = false
  self.pinOut.exitState.value = true
  self.mgr.dtReal = 0
  self.mgr.dtSim = 0
  self.mgr.dtRaw = 0
  self.pinOut.dtReal.value = self.mgr.dtReal
  self.pinOut.dtSim.value = self.mgr.dtSim
  self.pinOut.dtRaw.value = self.mgr.dtRaw
  self:trigger()
end


function C:work(args)
end

return _flowgraph_createNode(C)
