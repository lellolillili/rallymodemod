-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Vehicle Touch'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = 'Lets the flow through if a vehicle if touching another vehicle. If no second ID is given, checks for any collisions.'
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'flow', name = 'touching', description = 'Outflow for this node when touching.' },
  { dir = 'in', type = 'number', name = 'vehIdA', description = 'Id of vehicle to check collision for.' },
  { dir = 'in', type = 'number', name = 'vehIdB', description = 'Optional: Id of vehicle to check collision with vehicle A for.' },
  { dir = 'out', type = 'number', name = 'vehId1', hidden = true, description = 'The ID of the lowest-id-ed vehicle that is touched, -1 if none.' },
  { dir = 'out', type = 'number', name = 'vehId2', hidden = true, description = 'The ID of the lowest-id-ed vehicle that is touched, -1 if none.' },
  { dir = 'out', type = 'number', name = 'vehId3', hidden = true, description = 'The ID of the lowest-id-ed vehicle that is touched, -1 if none.' },
  { dir = 'out', type = 'number', name = 'vehId4', hidden = true, description = 'The ID of the lowest-id-ed vehicle that is touched, -1 if none.' },
  { dir = 'out', type = 'number', name = 'vehId5', hidden = true, description = 'The ID of the lowest-id-ed vehicle that is touched, -1 if none.' },
  { dir = 'out', type = 'bool', name = 'touchingb', hidden = true, description = 'True when vehicle A collides with vehicle B.' },
}
C.tags = {'collision','collide','hit'}

function C:init(mgr, ...)

end

function C:work()
  self.pinOut.touching.value = false
  self.pinOut.touchingb.value = false
  self.pinOut.flow.value = true
  self.pinOut.vehId1.value = -1
  self.pinOut.vehId2.value = -1
  self.pinOut.vehId3.value = -1
  self.pinOut.vehId4.value = -1
  self.pinOut.vehId5.value = -1

  if map and map.objects[self.pinIn.vehIdA.value] then
    local cols = map.objects[self.pinIn.vehIdA.value].objectCollisions
    if self.pinIn.vehIdB.value then
      if cols[self.pinIn.vehIdB.value] then
        self.pinOut.touching.value = true
        self.pinOut.touchingb.value = true
        -- self.pinOut.vehId.value = self.pinIn.vehIdB.value
        return
      end
    else
      local ids = {}
      for k,v in pairs(cols) do
        table.insert(ids,k)
      end
      if #ids > 0 then
        table.sort(ids)
        self.pinOut.vehId1.value = ids[1] or -1
        self.pinOut.vehId2.value = ids[2] or -1
        self.pinOut.vehId3.value = ids[3] or -1
        self.pinOut.vehId4.value = ids[4] or -1
        self.pinOut.vehId5.value = ids[5] or -1
        self.pinOut.touching.value = true
        self.pinOut.touchingb.value = true
        return
      end
    end
  end
end

return _flowgraph_createNode(C)
