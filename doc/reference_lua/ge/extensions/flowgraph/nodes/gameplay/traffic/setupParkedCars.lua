-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Setup Parking System'
C.description = 'Enables vehicles to use the parking spot placement system.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'parking'}


C.pinSchema = {
  { dir = 'in', type = 'table', name = 'vehicleIds', tableType = 'vehicleIds', description = 'Table of vehicle ids.' },
  { dir = 'in', type = 'table', name = 'sitesData', tableType = 'sitesData', description = '(Optional) Sites data to use for the parking system.' }
}

function C:init()
  self:onNodeReset()
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:onNodeReset()
  gameplay_parking.setState(false)
  gameplay_parking.setSites()
end

function C:workOnce()
  gameplay_parking.setState(true)
  if self.pinIn.sitesData.value then
    gameplay_parking.setSites(self.pinIn.sitesData.value)
  end
  if self.pinIn.vehicleIds.value then
    gameplay_parking.processVehicles(self.pinIn.vehicleIds.value)
  end
end

return _flowgraph_createNode(C)