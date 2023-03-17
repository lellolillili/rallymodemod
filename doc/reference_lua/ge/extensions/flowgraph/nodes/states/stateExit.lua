-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ufe = ui_flowgraph_editor
local C = {}

C.name = 'State Exit'
C.icon = "trending_up"
C.description = [[Exit point for this stategraph.]]

C.pinSchema = {
  {dir = 'in', type = 'state', name = 'flow', description = "This is a flow pin."},

}
C.hidden = true
C.color = im.ImVec4(1, 0.4, 0.4, 1)
C.type = 'node' --
C.allowedManualPinTypes = {
  state = true,
}
-- This gets called when the node has been created for the first time. Init field here
function C:init(mgr)
  self.autoStart = false
  self.savePins = true
  self.transitionName = ''
end

function C:drawCustomProperties()
  local reason
  local target
  if self.graph:getParent() then
    for id, node in pairs(self.graph:getParent().nodes) do
      if node.targetGraph and node.targetGraph.id == self.graph.id then
        target = node
      end
    end
    if target then
      if im.BeginCombo("Transition Name", self.transitionName) then
        if im.Selectable1("(None)", self.transitionName == nil) then
          self.transitionName = nil
          reason = "Changed Transition Name to (None)."
        end
        for _, tName in ipairs(target:getTransitionNames()) do
          if im.Selectable1(tName, tName == self.transitionName) then
            self.transitionName = tName
            reason = "Changed Transition Name to " .. tName
          end
        end
        im.EndCombo()
      end
      im.Separator()
    end
  end
  return reason
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.transitionName or "No Transition!")
  --im.BeginChild1("child",im.ImVec2(self.sliderWidth[0],50), true)
end

function C:_onSerialize(res)
  res.transitionName = self.transitionName
end

function C:_onDeserialized(data)
  self.transitionName = data.transitionName or ''
end



return _flowgraph_createStateNode(C)
