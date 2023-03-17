-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Transform'
C.description = 'Manages a position, rotation and scale in 3D space.'
C.todo = "Rotation is not working i guess"
C.category = 'provider'

C.icon = "d_rotation"
C.pinSchema = {
  {dir = 'out', type = 'vec3', name = 'pos', description= 'The position of this transform.'},
  {dir = 'out', type = 'quat', name = 'rot', description= 'The rotation of this transform.'},
  {dir = 'out', type = 'vec3', name = 'scl', description= 'The scale of this transform.'},

}

local displayModes = {'default','sphereX','sphereY','sphereZ','halfBox','fullBox','aproxVehicle'}

function C:init()
  local cameraPosition = getCameraPosition()
  local position = quat(getCameraQuat()) * vec3(0, 15, 0)
  self.position = position + cameraPosition
  self.rotation = quat(0,0,0,1)
  self.scale = vec3(1,1,1)
  self.markerColor =  ColorF(1,0,0.5,0.25)
  self.changed = true
  --self.transform = MatrixF(true)
  self.mode = 'gizmo'
  self.modes = {'gizmo','fromID'}
  self.useQuatForRotation = false
  self.editMode = im.IntPtr(0)
  self.reason = nil
  self.displayMode = 'halfBox'
end


function C:gizmoBeginDrag()
  self._beginDragRotation = deepcopy(quat(self.rotation))
  self._beginDragScale = vec3(self.scale)
  self._beginDragPosition = vec3(self.position)
end

function C:gizmoDragging()

  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    self.position = vec3(editor.getAxisGizmoTransform():getColumn(3))
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    local gizmoTransform = editor.getAxisGizmoTransform()
    local rotation = QuatF(0,0,0,1)
    rotation:setFromMatrix(gizmoTransform)

    if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
      self.rotation = quat(rotation)
    else
      self.rotation = self._beginDragRotation * quat(rotation)
    end
    self.euler = nil
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
    local scl = vec3(worldEditorCppApi.getAxisGizmoScale())
    self.scale = vec3(self._beginDragScale):componentMul(scl)
  end

  local x, y, z = self.rotation * vec3(1,0,0), self.rotation * vec3(0,1,0), self.rotation * vec3(0,0,1)
  --if self.isDragging then
    debugDrawer:drawLine((self.position-x*1000), (self.position+x*1000), ColorF(0.5,0,0,0.75))
    debugDrawer:drawLine((self.position-y*1000), (self.position+y*1000), ColorF(0,0.5,0,0.75))
    debugDrawer:drawLine((self.position-z*1000), (self.position+z*1000), ColorF(0,0,0.5,0.75))
  --end
end



function C:gizmoEndDrag()
  self.reason = "Finished Dragging"
end

-- called when the properties are shown
-- setting up the gizmo here
function C:showProperties()
  --print("Properties Shown.")

  editor.editModes.flowgraphTransform.onUpdate = function()
    if self._oldGizmoAlignment and self._oldGizmoAlignment ~= editor.getAxisGizmoAlignment() then
      self:updateTransform()
    end
    editor.updateAxisGizmo(
      function() self:gizmoBeginDrag() end,
      function() self:gizmoEndDrag() end,
      function() self:gizmoDragging() end )
    editor.drawAxisGizmo()
    self._oldGizmoMode = editor.getAxisGizmoMode()
    self._oldGizmoAlignment = editor.getAxisGizmoAlignment()

  end
  editor.selectEditMode(editor.editModes.flowgraphTransform)

  --self.transform = MatrixF(true)
  --self.transform:set(self.rotation:toEulerYXZ(), self.position)
  --editor.setAxisGizmoMode(self._oldGizmoMode or editor.AxisGizmoMode_Translate)
  --editor.setAxisGizmoAlignment(self._oldGizmoAlignment or editor.AxisGizmoAlignment_World)
  --editor.setAxisGizmoTransform(self.transform)
  self:updateTransform()
end

-- called when the properties are no longer shown
-- "destroying" the gizmo
function C:hideProperties()
  --print("Properties Hidden")
  self._oldGizmoMode = editor.getAxisGizmoMode()
  self._oldGizmoAlignment = editor.getAxisGizmoAlignment()
  editor.editModes.flowgraphTransform.onUpdate = nop
  editor.selectEditMode(editor.editModes.objectSelect)

end


function C:drawCustomProperties()
  local oldMode = self.mode
  im.TextUnformatted("Mode:")
  im.SameLine()
  if im.BeginCombo("##transformMode" .. self.id, self.mode) then
    for _, m in ipairs(self.modes) do
      if im.Selectable1(m, m == self.mode) then
        self.mode = m
        self.reason = "Changed mode to " ..m
      end
    end
    im.EndCombo()
  end
  if self.mode ~= oldMode then
    if self.mode == 'fromID' then
      self.idPin = self:createPin('in', "number", 'objID')
    else
      self:removePin(self.idPin)
    end
  end
  if self.mode == 'gizmo' then
    self:drawCustom()
  end
  local r = self.reason
  self.reason = nil
  return r
end



function C:updateTransform()
  local q = self.rotation
  local rotation
  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
    rotation = QuatF(q.x, q.y, q.z, q.w)
  else
    rotation = QuatF(0, 0, 0, 1)
  end
  local transform = rotation:getMatrix()
  transform:setPosition(self.position)
  editor.setAxisGizmoTransform(transform)
end

function C:drawCustom()
  -- buttons to change the mode of the gizmo

  im.Separator()
  im.Columns(2)
  im.SetColumnWidth(0, 70)
  im.Text("Display")
  im.NextColumn()
  if im.BeginCombo("##displayMode" .. self.id, self.displayMode) then
    for _, m in ipairs(displayModes) do
      if im.Selectable1(m, m == self.displayMode) then
        self.displayMode = m
        self.reason = "Changed displayMode to " ..m
      end
    end
    im.EndCombo()
  end
  im.NextColumn()

  im.Text("Position")
  im.NextColumn()
  local columnSize = im.GetContentRegionAvail()
  local pos = im.ArrayFloat(3)
  pos[0] = im.Float(self.position.x)
  pos[1] = im.Float(self.position.y)
  pos[2] = im.Float(self.position.z)
  im.PushItemWidth(columnSize.x)
  if im.DragFloat3("##pos"..self.id,pos, 0.5) then
    self.position:set(pos[0], pos[1], pos[2])
    self:updateTransform()
    self.changed = true
    self.reason = "Changed Position"
  end
  im.PopItemWidth()
  im.NextColumn()
  im.Text("Rotation")
  im.NextColumn()
  if self.useQuatForRotation then
    local rot = im.ArrayFloat(4)
    rot[0] = im.Float(self.rotation.x)
    rot[1] = im.Float(self.rotation.y)
    rot[2] = im.Float(self.rotation.z)
    rot[3] = im.Float(self.rotation.w)
    im.PushItemWidth(columnSize.x)
    if im.DragFloat4("##rot"..self.id,rot, 0.025) then
      self.rotation = quat(rot[0],rot[1],rot[2],rot[3]):normalized()
      self:updateTransform()
      self.changed = true
      self.reason = "Changed Rotation"
    end
    im.PopItemWidth()
  else
    if self.euler == nil then
      self.euler = self.rotation:toEulerYXZ()
    end

    local eul = im.ArrayFloat(3)
    eul[0] = im.Float(self.euler.x/math.pi * 180)
    eul[1] = im.Float(self.euler.y/math.pi * 180)
    eul[2] = im.Float(self.euler.z/math.pi * 180)
    im.PushItemWidth(columnSize.x)
    if im.DragFloat3("##rot"..self.id,eul, 0.1) then
      self.euler = {x = eul[0]/180*math.pi, y = eul[1]/180*math.pi, z = eul[2]/180*math.pi}
      self.rotation = quatFromEuler(eul[0]/180*math.pi,eul[1]/180*math.pi,eul[2]/180*math.pi)
      self.reason = "Changed Rotation"
      self.changed = true
      self:updateTransform()
    end
    im.PopItemWidth()
  end
  im.NextColumn()
  im.Text("Scale")
  im.NextColumn()
  local scl = im.ArrayFloat(3)
  scl[0] = im.Float(self.scale.x)
  scl[1] = im.Float(self.scale.y)
  scl[2] = im.Float(self.scale.z)
  im.PushItemWidth(columnSize.x)
  if im.DragFloat3("##scl"..self.id,scl, 0.1) then
    self.scale:set(scl[0], scl[1], scl[2])
    self:updateTransform()
    self.changed = true
    self.reason = "Changed Scale"
  end
  im.PopItemWidth()
  im.NextColumn()
  im.Text("Color")
  im.NextColumn()
  local clr = im.ArrayFloat(4)
  clr[0] = im.Float(self.markerColor.red)
  clr[1] = im.Float(self.markerColor.green)
  clr[2] = im.Float(self.markerColor.blue)
  clr[3] = im.Float(self.markerColor.alpha)
  im.PushItemWidth(columnSize.x)
  if im.ColorEdit4("##color"..self.id,clr) then
    self.markerColor = ColorF(clr[0],clr[1],clr[2],clr[3])
    self.reason = "Changed Color"
  end
  im.PopItemWidth()
  im.Columns(1)


  im.Separator()
  if editor and editor.selection and editor.selection.object and #editor.selection.object == 1 then
    if im.Button("Copy from current Selection") then
      local obj = scenetree.findObjectById(editor.selection.object[1])
      if not obj then return end
      self.position = vec3(obj:getPosition())
      self.rotation = quat(obj:getRotation())
      self.scale = vec3(obj:getScale())
    end
  else
    im.Text("Select single object to copy from")
  end
  im.Separator()

  local cameraPosition = getCameraPosition()
  local position = quat(getCameraQuat()) * vec3(0, 15, 0)
  local beforeCam = position + cameraPosition
  if self.mode == 'gizmo' then

    if im.Button("Position to 15m before Camera") then
      self.position = beforeCam
      self:updateTransform()
      self.reason = "Moved in from of Camera"
    end
    if im.Button("Position To Camera") then
      self.position = vec3(cameraPosition)
      self:updateTransform()
      self.reason = "Moved directly to Camera"
    end

    if im.Button("Rotation To Camera") then
      self.rotation = quat(getCameraQuat())
      self:updateTransform()
      self.euler = nil
      self.reason = "Rotated to camera"
    end

    if im.Button("Down to Terrain") then
      if scenetree.findClassObjects("TerrainBlock") then
        self.position.z = core_terrain.getTerrainHeight(self.position)
        self:updateTransform()
        self.reason = "Dropped to terrain"
      else
        log("E",'Position Node','could not find terrain block to lower position onto!')
      end
    end
  end
  debugDrawer:drawLine(beforeCam, self.position, ColorF(self.markerColor.r,self.markerColor.g,self.markerColor.b,1))
end
function C:_executionStarted()
  self.changed = true
end

function C:work()
  if self.mode == 'gizmo' then

  else
    local obj = scenetree.findObjectById(self.pinIn.objID.value)
    if not obj then return end
    self.position = vec3(obj:getPosition())
    self.rotation = quat(obj:getRotation())
    self.scale = vec3(obj:getScale())
    self.changed = true
  end
  if self.changed then
    self.pinOut.pos.value = {self.position.x, self.position.y, self.position.z}
    self.pinOut.rot.value = {self.rotation.x, self.rotation.y, self.rotation.z, self.rotation.w}
    self.pinOut.scl.value = {self.scale.x, self.scale.y, self.scale.z}
    self.changed = false
  end
end

function C:_executionStopped()
  self.changed = true
end


function C:drawMiddle(builder, style)
  builder:Middle()
  --local euler = quatFromEuler(self.rotation.x, self.rotation.y, self.rotation.z)
  local rot = self.rotation
  local x, y, z = rot * vec3(self.scale.x,0,0), rot * vec3(0,self.scale.y,0), rot * vec3(0,0,self.scale.z)
  x = x + self.position
  y = y + self.position
  z = z + self.position
  debugDrawer:drawSphere(x, 0.1, ColorF(1,0,0,1))
  debugDrawer:drawSphere(y, 0.1, ColorF(0,1,0,1))
  debugDrawer:drawSphere(z, 0.1, ColorF(0,0,1,1))
  debugDrawer:drawLine(self.position, x, ColorF(1,0,0,1))
  debugDrawer:drawLine(self.position, y, ColorF(0,1,0,1))
  debugDrawer:drawLine(self.position, z, ColorF(0,0,1,1))
  if self.displayMode == 'default' then
    debugDrawer:drawSphere(self.position, 0.25, self.markerColor)
  elseif self.displayMode == 'sphereX' then
    debugDrawer:drawSphere(self.position, self.scale.x, self.markerColor)
  elseif self.displayMode == 'sphereY' then
    debugDrawer:drawSphere(self.position, self.scale.y, self.markerColor)
  elseif self.displayMode == 'sphereZ' then
    debugDrawer:drawSphere(self.position, self.scale.z, self.markerColor)
  elseif self.displayMode == 'halfBox' then
    x, y, z = rot * vec3(self.scale.x,0,0), rot * vec3(0,self.scale.y,0), rot * vec3(0,0,self.scale.z)
    local scl = (x+y+z)/2
    self:drawAxisBox((-scl+self.position),x,y,z,ColorI(self.markerColor.red*255, self.markerColor.green*255, self.markerColor.blue*255, self.markerColor.alpha*255))
  elseif self.displayMode == 'fullBox' then
    x, y, z = rot * vec3(self.scale.x,0,0), rot * vec3(0,self.scale.y,0), rot * vec3(0,0,self.scale.z)
    local scl = (x+y+z)
    self:drawAxisBox((-scl+self.position),x*2,y*2,z*2,ColorI(self.markerColor.red*255, self.markerColor.green*255, self.markerColor.blue*255, self.markerColor.alpha*255))
  elseif self.displayMode == 'aproxVehicle' then
    x, y, z = rot * vec3(self.scale.x,0,0), rot * vec3(0,self.scale.y,0), rot * vec3(0,0,self.scale.z)
    self:drawAxisBox(((-x-1*y-0.3*z)+self.position),x*2,y*4.2,z*1.8,ColorI(self.markerColor.red*255, self.markerColor.green*255, self.markerColor.blue*255, self.markerColor.alpha*255))
    debugDrawer:drawTriSolid(
      vec3(self.position+x/2    ),
      vec3(self.position-x/2    ),
      vec3(self.position-y/2    ),
      ColorI(self.markerColor.red*128, self.markerColor.green*128, self.markerColor.blue*128, self.markerColor.alpha*255))
    debugDrawer:drawTriSolid(
      vec3(self.position-x/2    ),
      vec3(self.position+x/2    ),
      vec3(self.position-y/2    ),
      ColorI(self.markerColor.red*128, self.markerColor.green*128, self.markerColor.blue*128, self.markerColor.alpha*255))
  end
end

function C:drawAxisBox(corner, x, y, z, clr)
  -- draw all faces in a loop
  for _, face in ipairs({{x,y,z},{x,z,y},{y,z,x}}) do
    local a,b,c = face[1],face[2],face[3]
    -- spokes
    debugDrawer:drawLine((corner    ), (corner+c    ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a  ), (corner+c+a  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+b  ), (corner+c+b  ), ColorF(0,0,0,0.75))
    debugDrawer:drawLine((corner+a+b), (corner+c+a+b), ColorF(0,0,0,0.75))
    -- first side
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+a  ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner+b  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    -- back of first side
    debugDrawer:drawTriSolid(
      vec3(corner+a  ),
      vec3(corner    ),
      vec3(corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(corner    ),
      vec3(corner+b  ),
      vec3(corner+a+b),
      clr)
    -- other side
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+a  ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner+b  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    -- back of other side
    debugDrawer:drawTriSolid(
      vec3(c+corner+a  ),
      vec3(c+corner    ),
      vec3(c+corner+a+b),
      clr)
    debugDrawer:drawTriSolid(
      vec3(c+corner    ),
      vec3(c+corner+b  ),
      vec3(c+corner+a+b),
      clr)
  end
end

function C:_onSerialize(res)
  res.position = {self.position.x, self.position.y, self.position.z}
  res.rotation = {self.rotation.x, self.rotation.y, self.rotation.z, self.rotation.w}
  res.scale = {self.scale.x, self.scale.y, self.scale.z}

  res.markerClr = {self.markerColor.red, self.markerColor.green, self.markerColor.blue, self.markerColor.alpha}
  res.mode = self.mode
  res.useQuatForRotation = self.useQuatForRotation
  res.displayMode = self.displayMode
end

function C:_onDeserialized(nodeData)
  if nodeData.position then
    self.position = vec3(nodeData.position[1], nodeData.position[2], nodeData.position[3])
  end
  if nodeData.rotation then
    self.rotation = quat(nodeData.rotation[1], nodeData.rotation[2], nodeData.rotation[3], nodeData.rotation[4])
  end
  if nodeData.scale then
    self.scale = vec3(nodeData.scale[1], nodeData.scale[2], nodeData.scale[3])
  end
  if nodeData.markerClr then
    self.markerColor = ColorF(nodeData.markerClr[1],nodeData.markerClr[2], nodeData.markerClr[3], nodeData.markerClr[4])
  end
  self.changed =true
  self.mode = 'gizmo'
  if nodeData.mode == 'fromID' then
    self.mode = 'fromID'
    self.idPin = self:createPin('in', "number", 'objID')
  end
  self.useQuatForRotation = nodeData.useQuatForRotation
  self.displayMode = nodeData.displayMode or "default"
end

return _flowgraph_createNode(C)
