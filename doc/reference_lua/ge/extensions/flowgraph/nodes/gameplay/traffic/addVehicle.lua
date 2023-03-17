-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Add Vehicle (Traffic)'
C.description = 'Adds a vehicle to the traffic table.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'insert'}


C.pinSchema = {
  {dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle Id.'},
}

function C:workOnce()
  if self.pinIn.vehId.value then
    self.mgr.modules.traffic:insertTraffic(self.pinIn.vehId.value)
  end
end

return _flowgraph_createNode(C)