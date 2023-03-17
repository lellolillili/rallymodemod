-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Return camera to vehicle'
C.description = "Allows to return the camera back to the active vehicle, from other camera modes."
C.category = 'once_instant'
C.pinSchema = {
}

C.tags = { 'freecam', 'free', 'camera', 'vehicle' }
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera

function C:workOnce()
  if be:getPlayerVehicle(0) then
    commands.setGameCamera()
    print('setGameCamera')
  else
    log('W', logTag, 'No active vehicle to return camera to!')
  end
end

return _flowgraph_createNode(C)
