-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Props Touch'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Lets the flow through if a vehicle is touching any prop in the table.'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'flow', name = 'touching', description = 'Outflow for this node when touching.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of vehicle to check collision for.' },
  { dir = 'in', type = 'table', name = 'propsIds', description = 'Table of all the props that will be checked' },
  { dir = 'out', type = 'bool', name = 'isTouching', hidden = true, description = 'True when vehicle collides with any of the props.' },
}
C.tags = {'collision','collide','hit'}

function C:init(mgr, ...)

end

function C:work()
  self.pinOut.touching.value = false
  self.pinOut.isTouching.value = false
  self.pinOut.flow.value = true
  if map and map.objects[self.pinIn.vehId.value] then
    local cols = map.objects[self.pinIn.vehId.value].objectCollisions
    if self.pinIn.propsIds.value then
      for k,v in pairs(self.pinIn.propsIds.value) do
        if cols[v] then
          self.pinOut.touching.value = true
          self.pinOut.isTouching.value = true
          return
        end
      end
    end
  end
end

return _flowgraph_createNode(C)
