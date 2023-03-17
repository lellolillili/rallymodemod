-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Set Camera Position'
C.description = "Sets the cameras position."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'vec3', name = 'value', description = 'Defines the position to set camera to.' },
}

C.tags = {}
C.color = ui_flowgraph_editor.nodeColors.camera
C.icon = ui_flowgraph_editor.nodeIcons.camera
function C:init()
  self.position = vec3(0,0,0)
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
        reason = "Changed Mode to " .. m
      end
    end
    im.EndCombo()
  end
  if self.mode ~= oldMode then
    if self.mode == 'from Pin' then
      self.valPin = self:createPin('in', "vec3", 'pos')
    else
      self:removePin(self.valPin)
    end
  end

  if self.mode == 'custom' then
    im.Text("Position: ")
    local pos = im.ArrayFloat(3)
    im.SameLine()
    im.PushItemWidth(150)
    pos[0] = im.Float(self.position.x)
    pos[1] = im.Float(self.position.y)
    pos[2] = im.Float(self.position.z)
    if im.DragFloat3("##pos"..self.id,pos, 0.5) then
      self.position:set(pos[0], pos[1], pos[2])
      self.changed = true
      reason = "Changed Position"
    end
    if im.Button("Set from camera") then
      local cameraPosition = getCameraPosition()
      self.position = vec3(cameraPosition)
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
    self.position = vec3(self.pinIn.pos.value)
  end
  self:SetCamera()
  self.pinOut.value.value = {self.position.x, self.position.y, self.position.z}
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:SetCamera()
  local camRot = quat(getCameraQuat())
  setCameraPosRot(
   self.position.x, self.position.y, self.position.z,
   camRot.x, camRot.y, camRot.z, camRot.w)
end


function C:_onSerialize(res)
  res.ppos = {self.position.x,self.position.y,self.position.z}
  res.mode = self.mode

end

function C:_onDeserialized(nodeData)
  self.position = nodeData.ppos and vec3(nodeData.ppos[1], nodeData.ppos[2], nodeData.ppos[3]) or vec3({0,0,0})
  self.mode = nodeData.mode or 'custom'
  if self.mode == 'from Pin' then
    self.valPin = self:createPin('in', "vec3", 'pos')
  end
end
return _flowgraph_createNode(C)
