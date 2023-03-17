-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Set Object Field'
C.description = 'Sets a field of an object.'
C.category = 'repeat_instant'
C.todo = "Not tested at all."

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'objectId', description = 'Defines the id of the object to modify.' },
  { dir = 'in', type = 'string', name = 'fieldName', description = 'Defines the name of the field to modify.' },
  { dir = 'in', type = 'number', name = 'fieldArrayNum', default = 0, hardcoded = true, hidden = true, description = 'Field array number to modify.' },
  { dir = 'in', type = 'any', name = 'value', description = 'Value to be set. Vectors and Quaternions are automatically converted into correctly formatted strings.' },
  { dir = 'out', type = 'bool', name = 'objectFound', hidden = true, description = 'Puts out true, when the object was found.' },
}
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.tags = {}

function C:work()
  if not self.pinIn.objectId or not self.pinIn.fieldName or not self.pinIn.value then return end
  local obj = scenetree.findObjectById(self.pinIn.objectId.value)
  self.pinOut.objectFound.value = (obj ~= nil)
  if not obj then return end

  local val = self.pinIn.value.value
  if type(val) =='table' then
    val = table.concat(val,' ')
  end
  obj:setField(self.pinIn.fieldName.value, self.pinIn.fieldArrayNum.value or 0, val)
end


return _flowgraph_createNode(C)
