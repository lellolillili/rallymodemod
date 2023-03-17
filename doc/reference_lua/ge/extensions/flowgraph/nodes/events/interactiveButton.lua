-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Interactive Button'
C.type = 'simple'
C.description = "A button that triggers execution."
C.category = 'logic'
C.todo = "should be moved to debug/"

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow once when the button has been pressed.', impulse = true },
}

C.tags = {'input'}

function C:init(mgr, ...)
  self.data.btnName = "Push"
  self.doTrigger = false
end

function C:drawMiddle(builder, style)
  builder:Middle()
  local name = self.data.btnName
  if name == "" then
    name = "Push"
  end
  if im.Button(name..'##'..self.id) then
    if self.graph.mgr.runningState == "running" then
      self.doTrigger = true
    end

  end
end

function C:work()
  self.pinOut.flow.value = self.doTrigger
  self.doTrigger = false

end


function C:onLink(link)
  if self.data.btnName == "Push" then
    self.data.btnName = link.targetPin.name
    if self.data.btnName == 'flow' then
      self.data.btnName = link.targetNode.name
    end
  end
end

return _flowgraph_createNode(C)
