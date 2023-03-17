-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Set Button Property'
C.description = "Sets various button properties. Properties where the pin is not set will not be changed."
C.icon = ui_flowgraph_editor.nodeIcons.button
C.color = ui_flowgraph_editor.nodeColors.button
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'buttonId', description = 'ID of the button.' },
  { dir = 'in', type = 'string', name = 'label', default = "Button", description = 'Displayed named of the button.' },
  { dir = 'in', type = 'bool', name = 'active', description = 'If this button should be active or not' },
  { dir = 'in', type = 'number', name = 'order', description = 'This buttons order in the button list. Leave empty for automatic order.' },
  { dir = 'in', type = 'string', name = 'style', description = 'This buttons styling.', default = 'default' },
}
function C:postInit()
  self.pinInLocal.style.hardTemplates = {{value='default',label="Default"}}
end
local properties = {'active','order','style','label'}

function C:work()
  local id = self.pinIn.buttonId.value
  local button = self.mgr.modules.button:getButton(id)
  if id and button then
    for _, p in ipairs(properties) do
      if self.pinIn[p].value ~= nil then
        self.mgr.modules.button:set(id, p, self.pinIn[p].value)
      end
    end
  end
end

return _flowgraph_createNode(C)
