-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Can Enter From Walking'
C.description = 'Checks if the player is walking and close enough to a stationary vehicle to enter it.'
C.color = ui_flowgraph_editor.nodeColors.walking
C.icon = ui_flowgraph_editor.nodeIcons.walking
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'canEnter', description = "Outflow when the player is currently walking and can enter a stationary vehicle." },
  { dir = 'out', type = 'number', name = 'vehId', description = "ID of the closes vehicle the player can enter. Nil if none is present." },
  { dir = 'out', type = 'flow', name = 'closeButNotStopped', description = "Outflow when the player is currently walking and close to a vehicle, but the vehicle is not stopped.", hidden = true },
}
C.dependencies = {'gameplay_walk'}

function C:work(args)
  self.pinOut.canEnter.value = gameplay_walk.isWalking() and gameplay_walk.getVehicleInFront() and gameplay_walk.isAtParkingSpeed()
  self.pinOut.closeButNotStopped.value = gameplay_walk.isWalking() and gameplay_walk.getVehicleInFront() and not gameplay_walk.isAtParkingSpeed()
  self.pinOut.vehId.value = gameplay_walk.getVehicleInFront() and gameplay_walk.getVehicleInFront():getID() or nil
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if gameplay_walk then
    editor.uiIconImage(editor.icons.simobject_bng_vehicle, im.ImVec2(40, 40), (gameplay_walk.isWalking() and gameplay_walk.getVehicleInFront() and gameplay_walk.isAtParkingSpeed()) and im.ImVec4(0.3,1,0.3,1) or im.ImVec4(1,1,1,0.3))
  end
end

return _flowgraph_createNode(C)
