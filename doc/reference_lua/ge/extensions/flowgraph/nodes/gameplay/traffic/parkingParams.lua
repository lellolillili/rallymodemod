-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Parking System Parameters'
C.description = 'Sets variables for the parking system.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'parking', 'parameters'}


C.pinSchema = {
  { dir = 'in', type = 'number', name = 'precision', description = 'Precision required to validate a vehicle in a parking spot (from 0 to 1)' },
  { dir = 'in', type = 'number', name = 'neatness', description = 'Parking neatness of other parked vehicles used by the parking system (from 0 to 1)' },
  { dir = 'in', type = 'number', name = 'parkingDelay', description = 'Delay, in seconds, until a stopped vehicle is considered parked in a parking spot.' },
  { dir = 'in', type = 'number', name = 'debugLevel', description = 'Debug mode level to use (from 0 to 2)' }
}

function C:workOnce()
  if self.pinIn.precision.value then
    gameplay_parking.precision = clamp(self.pinIn.precision.value, 0, 1)
  end
  if self.pinIn.neatness.value then
    gameplay_parking.neatness = clamp(self.pinIn.neatness.value, 0, 1)
  end
  if self.pinIn.parkingDelay.value then
    gameplay_parking.parkingDelay = self.pinIn.parkingDelay.value
  end
  if self.pinIn.debugLevel.value then
    gameplay_parking.setDebugLevel(math.floor(self.pinIn.debugLevel.value))
  end
end

return _flowgraph_createNode(C)