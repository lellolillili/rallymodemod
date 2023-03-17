-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Mission Defaults'
C.description = "Provides a variety of mission default values."
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'color', name = 'markerInactive', description = 'Inactive 3D-Markers, for the Parking Markers node, light orange' },
  { dir = 'out', type = 'color', name = 'markerActive', description = 'Inactive 3D-Markers, for the Parking Markers node, light green' },
  { dir = 'out', type = 'number', name = 'fadeTransitionTime', description = 'Time for the fade transition, 0.75s' },
}

function C:init()
  self.clearOutPinsOnStart = false
end

function C:_executionStarted()
  self.pinOut.markerInactive.value = {232/255, 132/255, 52/255, 255/255}
  self.pinOut.markerActive.value = {156/255, 229/255, 61/255, 255/255}
  self.pinOut.fadeTransitionTime.value = 0.75
end



return _flowgraph_createNode(C)
