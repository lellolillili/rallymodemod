-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}
local logTag = 'Remove Vehicle'
C.name = 'Remove Vehicle'
C.description = "Removes a Vehicle."
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', default = nil, description = 'ID of the vehicle to be removed.' },
}

C.tags = {'gameplay', 'utils'}

function C:work()
  local source
  if self.pinIn.vehId.value and self.pinIn.vehId.value ~= 0 then
    source = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    --source = be:getPlayerVehicle(0)
    self.pinOut.flow.value = true
  end
  if source then
    if editor and editor.onRemoveSceneTreeObjects then
      editor.onRemoveSceneTreeObjects({source:getId()})
    end
    source:delete()
  end
end



return _flowgraph_createNode(C)
