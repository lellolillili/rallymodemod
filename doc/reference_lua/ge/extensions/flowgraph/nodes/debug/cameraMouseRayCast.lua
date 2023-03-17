-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Camera Mouse Raycast'
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.description = "Fires a Raycast from the Camera to the mouse position."
C.category = 'repeat_instant'
C.todo = "Might not be needed anymore, since we have mouse tool node."

C.pinSchema = {
    { dir = 'out', type = 'flow', name = 'clicking', description = 'Puts out flow, if mouse is clicked.', impulse = true },
    { dir = 'out', type = 'number', name = 'objID', description = 'Id of object that was hit.' },
    { dir = 'out', type = 'string', name = 'objName', description = 'Name of object that was hit.' },
    { dir = 'out', type = 'number', name = 'distance', hidden = true, description = 'Distance to object that was hit.' },
    { dir = 'out', type = 'vec3', name = 'pos', hidden = true, description = 'Position where raycast hit.' },
    { dir = 'out', type = 'vec3', name = 'normal', hidden = true, description = 'Normal vector for raycast hit.' },
    { dir = 'out', type = 'number', name = 'face', hidden = true, description = 'Face value for raycast hit.' },
}

C.tags = {'util','click'}

function C:work()
    local hit = cameraMouseRayCast()
    if hit then
      self.pinOut.distance.value = hit.distance
      self.pinOut.face.value = hit.face
      self.pinOut.normal.value = {hit.normal.x,hit.normal.y,hit.normal.z}
      self.pinOut.objID.value = hit.object and hit.object:getID() or nil
      self.pinOut.objName.value = hit.object and hit.object:getName() or nil
      self.pinOut.pos.value = {hit.pos.x,hit.pos.y,hit.pos.z}
      self.pinOut.clicking.value = im.IsMouseClicked(0) and not im.GetIO().WantCaptureMouse
    else
      self.pinOut.distance.value = nil
      self.pinOut.face.value = nil
      self.pinOut.normal.value = nil
      self.pinOut.objID.value = nil
      self.pinOut.objName.value = nil
      self.pinOut.pos.value = nil
      self.pinOut.clicking.value = false
    end
end

return _flowgraph_createNode(C)
