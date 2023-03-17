-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Show/Hide Object'
C.description = 'Shows or hides an object.'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'objID', description = 'Id of the object that should be hidden or shown.' },
  { dir = 'in', type = 'bool', name = 'hide', description = 'When true, hides the object, otherwise shows it.' },
}

C.tags = {}

function C:init()

end

function C:work()
  local obj
  if self.pinIn.objID.value then
    obj = scenetree.findObjectById(self.pinIn.objID.value)
    self:__setNodeError("input", nil)
  else
    self:__setNodeError("input", "objID must be set")
    return
  end
  obj.hidden = self.pinIn.hide.value or false
  obj:updateInstanceRenderData()
end


return _flowgraph_createNode(C)
