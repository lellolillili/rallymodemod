-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Set Camera Rotation'
C.description = "Sets the cameras rotation."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'quat', name = 'value', description = 'Defines the rotation to set camera to.' },
}

C.tags = {'observer', 'follow', 'track'}
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera

function C:init()
  self.rotation = quat(0,0,0,0)
  self.mode = 'custom'
  self.modes = {'custom','from Pin'}
end

function C:drawCustomProperties()
  local reason = nil
  local oldMode = self.mode
  if im.BeginCombo("##cameraToMode" .. self.id, self.mode) then
    for _, m in ipairs(self.modes) do
      if im.Selectable1(m, m == self.mode) then
        self.mode = m
        reason = "Changed mode to " .. m
      end
    end
    im.EndCombo()
  end
  if self.mode ~= oldMode then
    if self.mode == 'from Pin' then
      self.valPin = self:createPin('in', "quat", 'rot')
    else
      self:removePin(self.valPin)
    end
  end

  if self.mode == 'custom' then
    im.Text("Rotation: ")
    local pos = im.ArrayFloat(4)
    im.SameLine()
    im.PushItemWidth(200)
    pos[0] = im.Float(self.rotation.x)
    pos[1] = im.Float(self.rotation.y)
    pos[2] = im.Float(self.rotation.z)
    pos[3] = im.Float(self.rotation.w)
    if im.DragFloat4("##pos"..self.id,pos, 0.5) then
      self.rotation = quat(pos[0], pos[1], pos[2], pos[3]):normalized()
      reason = "Changed Rotation"
    end
    if im.Button("Set from camera") then
      self.rotation = quat(getCameraQuat())
      reason = "Got values from Camera"
    end
    im.SameLine()
    if im.Button("Preview") then
      self:SetCamera()
    end
  end
  return reason
end

function C:work()
  if not commands.isFreeCamera() then
    commands.setFreeCamera()
  end
  if self.mode == 'from Pin' then
    self.rotation = quat(self.pinIn.rot.value)
  end
  self:SetCamera()
  self.pinOut.value.value = {self.rotation.x, self.rotation.y, self.rotation.z, self.rotation.w}
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:SetCamera()

  local camPos = getCameraPosition()
  setCameraPosRot(
   camPos.x, camPos.y, camPos.z,
   self.rotation.x, self.rotation.y, self.rotation.z, self.rotation.w)
end


function C:_onSerialize(res)
  res.rot = {self.rotation.x, self.rotation.y, self.rotation.z, self.rotation.w}
  res.mode = self.mode
end

function C:_onDeserialized(nodeData)
  self.rotation = nodeData.rot and (quat(nodeData.rot[1],nodeData.rot[2],nodeData.rot[3],nodeData.rot[4])) or quat(0,0,0,0)
  self.mode = nodeData.mode or 'custom'
  if self.mode == 'from Pin' then
    self.valPin = self:createPin('in', "quat", 'rot')
  end
end

return _flowgraph_createNode(C)
