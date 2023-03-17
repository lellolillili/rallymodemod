-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Simple Button'
C.description = "Creates a new Button inside an all-in-one node. Button values can not be changed after creation in this node."
C.icon = ui_flowgraph_editor.nodeIcons.button
C.color = ui_flowgraph_editor.nodeColors.button
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'hideWhenDone', description = 'If true, the button will be hidden once it has been clicked once.' },
  { dir = 'in', type = 'string', name = 'label', default = "Button", description = 'Displayed named of the button.' },
  { dir = 'in', type = 'number', name = 'order', hidden = true, description = 'This buttons order in the button list. Leave empty for automatic order.' },
  { dir = 'in', type = 'string', name = 'style', hidden = true, description = 'This buttons styling.', hardcoded = true, default = 'default' },
  { dir = 'out', type = 'number', name = 'buttonId', description = 'ID of the Button.', hidden = true },
  {dir = 'out', type = 'flow', name = 'clicked', description = 'Outflow once when the button is clicked.', impulse=true},
  {dir = 'out', type = 'flow', name = 'used', description = 'Outflow after the button has been clicked the first time.',hidden=true},
  {dir = 'out', type = 'flow', name = 'unused', description = 'Outflow as long as the button has not yet been clicked.', hidden=true},
}

C.legacyPins = {
  out = {
    complete = 'used',
    incomplete = 'unused'
  }
}

function C:_executionStarted()
  self.hiddenAfterDone = false
  self.hiddenAfterReset = false
end

function C:postInit()
  self.pinInLocal.style.hardTemplates = {{value='default',label="Default"}}
end

function C:onNodeReset()
  -- hide existing button, and clear the afterDone flag.
  if self.pinOut.buttonId.value then
    if not self.hiddenAfterReset then
      self.mgr.modules.button:set(self.pinOut.buttonId.value, "active", false)
      self.hiddenAfterReset = true
    end
  end
  self.hiddenAfterDone = false
end

function C:workOnce()

end

function C:workOnce()
  -- create new button.
    self.pinOut.buttonId.value = self.mgr.modules.button:addButton({
    label = self.pinIn.label.value,
    active = self.pinIn.active.value,
    order = self.pinIn.order.value,
    stlye = self.pinIn.style.value})
end

function C:work()
  local id = self.pinOut.buttonId.value
  local button = self.mgr.modules.button:getButton(id)
  -- un-hide if reset before.
  if self.hiddenAfterReset then
    self.mgr.modules.button:set(id, "active", true)
  end
  -- check button status.
  self.pinOut.clicked.value = button.clicked.value
  self.pinOut.used.value = button.complete.value
  self.pinOut.unused.value = not self.pinOut.used.value
  -- auto-hide after completion.
  if self.pinIn.hideWhenDone.value and not self.hiddenAfterDone and button.used.value then
    self.mgr.modules.button:set(id, "active", false)
    self.hiddenAfterDone = true
  end
end

return _flowgraph_createNode(C)
