-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Get Button'
C.description = "Gets various Button values."
C.icon = ui_flowgraph_editor.nodeIcons.button
C.color = ui_flowgraph_editor.nodeColors.button
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'buttonId', description = 'ID of the button.' },
  { dir = 'out', type = 'flow', name = 'clicked', description = 'Outflow once when the button is clicked.', impulse = true },
  { dir = 'out', type = 'flow', name = 'used', description = 'Outflow after the button has been clicked the first time.', hidden = true },
  { dir = 'out', type = 'flow', name = 'unused', description = 'Outflow as long as the button has not yet been clicked.', hidden = true },
  {dir = 'out', type = 'string', name = 'label', description = 'The buttons label.', hidden=true},
  {dir = 'out', type = 'bool', name = 'active', description = 'If the button is active or not', hidden=true},
  {dir = 'out', type = 'number', name = 'order', description = 'The buttons order.', hidden=true},
  {dir = 'out', type = 'string', name = 'style', description = 'The buttons style.', hidden=true},
}

C.legacyPins = {
  out = {
    complete = 'used',
    incomplete = 'unused'
  }
}

function C:workOnce()
  local id = self.pinIn.buttonId.value
  local button = self.mgr.modules.button:getButton(id)
  if id and button then
    -- calculate basic values.
    self.pinOut.clicked.value = button.clicked.value
    self.pinOut.used.value = button.complete.value
    self.pinOut.unused.value = not self.pinOut.complete.value
    self.pinOut.label.value = button.label.value
    self.pinOut.active.value = button.active.value
    self.pinOut.order.value = button.order.value
    self.pinOut.style.value = button.style.value
  end
end

return _flowgraph_createNode(C)
