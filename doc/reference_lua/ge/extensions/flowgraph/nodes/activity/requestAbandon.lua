-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Request Abandon'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
--C.icon = ui_flowgraph_editor.nodeIcons.activity
C.description = [[Lets flow through if the player requests an abandon from the mission. If this node exists, the flowgraph needs to be stopped manually at the end.]]

C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow once when abandon has been pressed.', impulse = true },
  { dir = 'out', type = 'bool', name = 'value', hidden = true, description = 'True if abandon has been pressed, false otherwise.' },
}

C.tags = {'input'}

function C:init(mgr, ...)
  self.reset = false
  self.data.blocksOnResetGameplay = true
end

function C:_executionStopped()
  self.reset = false
  --popActionMap("FlowgraphControls")
end

function C:_executionStarted()
  self.reset = false
  --pushActionMap("FlowgraphControls")
end

function C:onRequestAbandon()
  self.reset = true
end

function C:_afterTrigger()
  self.reset = false
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:work(args)
  if self.reset then
    self.pinOut.flow.value = true
    self.pinOut.value.value = true
    self.reset = false
    self.mgr:logEvent("Player pressed 'Abandon'.","I", "The Player has pressed the button to Abandon this mission", {type = "node", node = self})
  else
    self.pinOut.flow.value = false
    self.pinOut.value.value = false
  end
end

return _flowgraph_createNode(C)
