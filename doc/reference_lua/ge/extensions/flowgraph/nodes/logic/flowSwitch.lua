-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Flow Switch'
C.icon = ui_flowgraph_editor.nodeIcons.logic
C.description = 'Controls the flow of switch using an on and an off pin. Node can be clicked to toggle flow.'
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'on', description = 'Outflow when the switch is ON.' },
  { dir = 'in', type = 'flow', name = 'off', description = 'Outflow when the switch is OFF.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
}


C.tags = {}



function C:init(mgr, ...)
  self.on = false
end

function C:drawMiddle(builder, style)
  builder:Middle()
  local iconImage = self.on and editor.icons.check_box or editor.icons.check_box_outline_blank
  editor.uiIconImage(iconImage, im.ImVec2(32, 32))
  if im.IsItemClicked() then
    self.on = not self.on
    if self.graph.mgr.allowEditing then
      self.storedOn = self.on
    end
  end
end

function C:_executionStopped()
  self.on = self.storedOn
end

function C:_executionStarted()
  self.on = self.storedOn
end

function C:_onSerialize(res)
  res.on = self.storedOn
end

function C:_onDeserialized(nodeData)
  self.storedOn = nodeData.on
end

function C:work(args)
  if self.pinIn.on.value then
    self.on = true
  end
  if self.pinIn.off.value then
    self.on = false
  end
  self.pinOut.flow.value = self.on and self.pinIn.flow.value
end

return _flowgraph_createNode(C)
