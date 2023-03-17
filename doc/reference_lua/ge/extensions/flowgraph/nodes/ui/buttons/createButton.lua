-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Create Button'
C.description = "Creates a new Button object."
C.icon = ui_flowgraph_editor.nodeIcons.button
C.color = ui_flowgraph_editor.nodeColors.button
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'label', default = "Button", description = 'Displayed named of the button.' },
  { dir = 'in', type = 'bool', name = 'active', hardcoded = true, default = true, hidden = true, description = 'If this button should be active or not' },
  { dir = 'in', type = 'number', name = 'order', hidden = true, description = 'This buttons order in the button list. Leave empty for automatic order.' },
  { dir = 'in', type = 'string', name = 'style', hidden = true, description = 'This buttons styling.', hardcoded = true, default = 'default' },
  { dir = 'out', type = 'number', name = 'buttonId', description = 'ID of the Button.' },
}

function C:postInit()
  self.pinInLocal.style.hardTemplates = {{value='default',label="Default"}}
end

function C:workOnce()
  self.pinOut.buttonId.value = self.mgr.modules.button:addButton({
  label = self.pinIn.label.value,
  active = self.pinIn.active.value,
  order = self.pinIn.order.value,
  style = self.pinIn.style.value})
end

return _flowgraph_createNode(C)
