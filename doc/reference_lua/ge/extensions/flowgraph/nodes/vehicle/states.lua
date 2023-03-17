-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Vehicle States'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle

C.description = [[Gives information about the state of a vehicle: currently has Horn and Lightbar.]]
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'horn', description = 'Outflow for this node when horn is active.' },
  { dir = 'out', type = 'flow', name = 'lightbar', description = 'Outflow for this node when lightbar is active.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Id of Vehicle to receive state information for.' },
  { dir = 'out', type = 'bool', name = 'hornb', hidden = true, description = 'Puts out if the horn is active.' },
  { dir = 'out', type = 'bool', name = 'lightbarb', hidden = true, description = 'Puts out if the lightbar is active.' },
}

function C:work()
  self.pinOut.lightbar.value = false
  self.pinOut.horn.value = false

  if map and map.objects[self.pinIn.vehId.value] then
    local state = map.objects[self.pinIn.vehId.value].states
    self.pinOut.lightbar.value = state.lightbar and true or false
    self.pinOut.horn.value = state.horn and true or false
    self.pinOut.lightbarb.value = self.pinOut.lightbar.value
    self.pinOut.hornb.value = self.pinOut.horn.value
  end
end

return _flowgraph_createNode(C)
