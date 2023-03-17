-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Controls Action'
C.color = ui_flowgraph_editor.nodeColors.event
C.icon = ui_flowgraph_editor.nodeIcons.event
C.description = [[Lets flow through if Action (Ctrl + Space) has been pressed. Automatically pushes the action map "FlowgraphActions".]]
C.todo = "Figure out how this interacts if you have multiple flowgraphs using this."
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow once when action pressed.', impulse = true },
  { dir = 'out', type = 'bool', name = 'value', hidden = true, description = 'True when the player pressed this action, false otherwise.' },
}


C.tags = {'input'}

function C:init(mgr, ...)
  self.reset = false
end

function C:_executionStopped()
  self.reset = false
  self.atTime = -100
  popActionMap("FlowgraphActions")
end

function C:_executionStarted()
  self.reset = false
  self.atTime = -100
  pushActionMap("FlowgraphActions")
end

function C:onControlsAction()
  self.reset = true
  self.atTime = self.mgr.frameCount
end

function C:drawMiddle(builder, style)
  builder:Middle()

end


function C:work(args)
  if self.reset and self.mgr.frameCount - self.atTime < 2 then
    self.pinOut.flow.value = true
    self.pinOut.value.value = true
    self.reset = false
  else
    self.pinOut.flow.value = false
    self.pinOut.value.value = false
    self.atTime = -100
  end

end

return _flowgraph_createNode(C)
