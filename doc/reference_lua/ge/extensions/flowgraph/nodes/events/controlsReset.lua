-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Controls Reset'
C.color = ui_flowgraph_editor.nodeColors.event
C.icon = ui_flowgraph_editor.nodeIcons.event
C.description = [[Lets flow through if Reset has been pressed. If this node is used, default reset from freeroam no longer happens.]]
C.todo = "Figure out how this interacts if you have multiple flowgraphs using this."
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow once when reset has been pressed.', impulse = true },
  { dir = 'out', type = 'bool', name = 'value', hidden = true, description = 'True if reset has been pressed, false otherwise.' },
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

function C:onResetGameplay()
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
    self.mgr:logEvent("Player pressed 'Reset'.","I", "The Player has pressed the button to rese the gameplay. (R)", {type = "node", node = self})
  else
    self.pinOut.flow.value = false
    self.pinOut.value.value = false
  end
end


function C:onGatherGameContextUiButtons(results)
  local active = true
  local stateId = self.mgr.states:getStateIdForNode(self)
  if stateId ~= -1 then
    active = active and self.mgr.states.states[stateId].active
  end

  active = active and (self._frameLastUsed == self.graph.mgr.frameCount)
  table.insert(results, {id="controlsReset",label="Reset",fun = 'extensions.hook("onResetGameplay")', order = 0, active = active})


end

return _flowgraph_createNode(C)
