-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local im = ui_imgui
local smallButtonColor = im.ImVec4(1, 1, 1, 0.5)
local activeColor = im.ImVec4(0.5, 1, 0.5, 0.8)
local _uid = 0 -- do not use ever
local function getNextUniqueIdentifier()
  _uid = _uid + 1
  return _uid
end

local buttonData = {
  {
    key = "downToTerrain",
    label = "Down to Terrain",
    icon = "terrain_height_lower",
    tooltip = "Drops the transform down to the height of the terrain, if a terrain exists.",
    fun = "helperPositionDownToTerrain",
    needsPos = true
  },
  {
    key = "focus",
    label = "Focus Position",
    icon = "center_focus_strong",
    tooltip = "Focusses the transform with the camera.",
    fun = "helperFocus",
    needsPos = true,
  },
  {
    key = "inFront",
    label = "Move before Camera",
    icon = "switch_camera",
    tooltip = "Moves the transform 15m in front of the camera.",
    fun = "helperPositionInFrontOfToCamera",
    needsPos = true,
  },
  {
    key = "rotateWithCam",
    label = "Rotate with Camera",
    icon = "rotate_90_degrees_ccw",
    tooltip = "Rotates the transform to face away from the camera.",
    fun = "helperRotateWithCamera",
    needsRot = true,
  },
  {
    key = "alignWithTerrain",
    label = "Align with Terrain",
    icon = "vertical_align_center",
    tooltip = "Aligns the transform with the normal of the terrain, if a terrain exists.",
    fun = "helperAlignWithTerrain",
    needsRot = true,
  },
  {
    key = "moveToTransform",
    label = "Move to Transform",
    icon = "play_for_work",
    tooltip = "Moves the player vehicle to the transform.",
    fun = "helperMoveToTransform",
    needsPos = true,
  }
}


-- initializes stuff for the helper.
function C:init(editName, objectName)
  self.id = getNextUniqueIdentifier()
  self.editName = editName
  self.objectName = objectName or "Object"

  -- which components of the transform are editable
  self.allowTranslate = true
  self.allowRotate = true
  self.allowScale = true
  -- if the scale is one or three dimensions
  self.oneDimensionalScale = false

  self.pos = vec3(0, 0, 0)
  self.rot = quat(0, 0, 0, 1)
  self.scl = vec3(1, 1, 1)
  self:setOneDimensionalScale(self.oneDimensionalScale)

  self.inputPos = im.ArrayFloat(3)
  self.inputRot = im.ArrayFloat(4)

  -- which elements should show when you call update()
  self.showWidgets = true
  self.showGizmo = true
  self.widgetSettings = {}

  self:set()

  editor.editModes[editName] = {
    displayName = editName,
    onUpdate = function()
      if im.IsKeyDown(im.GetKeyIndex(im.Key_Escape)) then
        editor.selectEditMode(editor.editModes.objectSelect)
      end
    end,
    onActivate = function()
      self:onActivate()
    end,
    onDeactivate = function()
      self:onDeactivate()
    end,
    auxShortcuts = { esc = 'Exit editing ' .. editName }
  }
end

-- toggles between single value and vec3 value for scale.
function C:setOneDimensionalScale(ods)
  self.oneDimensionalScale = ods
  if ods then
    self.scl = self.scl.x or 1
    self.inputScl = im.FloatPtr(self.scl)
  else
    self.scl = vec3(1, 1, 1) * (type(self.scl) == 'number' and self.scl or 1)
    self.inputScl = im.ArrayFloat(3)
    self.inputScl[0] = im.Float(self.scl.x)
    self.inputScl[1] = im.Float(self.scl.y)
    self.inputScl[2] = im.Float(self.scl.z)
  end
end

-- starts the edit mode if not already in it
function C:start()
  if not self:correctEditMode() then
    editor.selectEditMode(editor.editModes[self.editName])
  end
end

-- stops the edit mode if currently in it
function C:stop()
  if self:correctEditMode() then
    editor.selectEditMode(nil)
  end
end

-- sets the position, rotation and scale of the helper. nil parameters are ignored,
-- so you can only set the rotation with :set(nil, quat(...), nil) for example
function C:set(pos, rot, scl)
  if self.oneDimensionalScale then
    if scl and type(scl) ~= 'number' then
      scl = (scl and (scl.x or scl[1])) or 1
    end
  else
    if scl and type(scl) == 'number' then
      scl = vec3(1, 1, 1) * (scl or 1)
    end
  end
  self.rot = rot or self.rot
  self.pos = pos or self.pos
  self.scl = scl or self.scl
  self:updateTransform()
  self:updateInputFields()
end

-- updates the transform associated with the object
function C:updateTransform()
  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
    self.transform = QuatF(self.rot.x, self.rot.y, self.rot.z, self.rot.w):getMatrix()
  else
    self.transform = QuatF(0, 0, 0, 1):getMatrix()
  end
  self.transform:setPosition(self.pos)
  if self:correctEditMode() then
    editor.setAxisGizmoTransform(self.transform)
  end
end

-- updates the input fields
function C:updateInputFields()
  self.inputPos[0] = im.Float(self.pos.x)
  self.inputPos[1] = im.Float(self.pos.y)
  self.inputPos[2] = im.Float(self.pos.z)

  self.inputRot[0] = im.Float(self.rot.x)
  self.inputRot[1] = im.Float(self.rot.y)
  self.inputRot[2] = im.Float(self.rot.z)
  self.inputRot[3] = im.Float(self.rot.w)

  if self.oneDimensionalScale then
    self.inputScl[0] = self.scl
  else
    self.inputScl[0] = im.Float(self.scl.x)
    self.inputScl[1] = im.Float(self.scl.y)
    self.inputScl[2] = im.Float(self.scl.z)
  end
end

function C:shiftUpdate(mouseInfo)
  if not mouseInfo.rayCast then
    return
  end

  if mouseInfo.down then
    self._temp = {
      pos = vec3(self.pos),
      rot = quat(self.rot),
      scl = self.oneDimensionalScale and self.scl or vec3(self.scl),
      moved = false

    }
  end
  if mouseInfo.hold then
    local len = (mouseInfo._holdPos - mouseInfo._downPos):length()
    if len > 1 then
      self._temp.moved = true
    end
    local fwd = self.switchRotationForMouse and mouseInfo._downPos - mouseInfo._holdPos or mouseInfo._holdPos - mouseInfo._downPos

    local rot = quatFromDir(fwd, mouseInfo._downNormal):normalized()
    self:set(mouseInfo._downPos,
        self._temp.moved and rot,
        self._temp.moved and self.oneDimensionalScale and len or nil)
  else
    if mouseInfo.up then
      self._temp = nil
      return true
    end
  end
end

function C:update(mouseInfo)
  --local gizmo = self:gizmo()
  --local widget = nil
  --if self.drawWidgetCondensed then
  --  self:widgetCondensed()
  --else
  --  self:widget()
  --end
  local change = false
  if self:correctEditMode() then
    if self._beginCooldown then
      self._beginCooldown = self._beginCooldown - 1
      if self._beginCooldown <= 0 then
        self._beginCooldown = nil
      end
    else
      if mouseInfo and mouseInfo.valid then
        local txt
        local clr
        if editor.keyModifiers.shift then
          txt = "Click and Drag to place this here."
          clr = ColorI(0, 0, 96, 255)
          change = self:shiftUpdate(mouseInfo) or change
        else
          if self._temp then
            self:set(self._temp.pos, self._temp.rot, self._temp.scl)
            self._temp = nil
          end
          if not editor.isAxisGizmoHovered() then
            txt = "Hold Shift for Quick Edit."
          end
          if im.IsMouseClicked(0) and not im.GetIO().WantCaptureMouse and not editor.isAxisGizmoHovered() then
            editor.selectEditMode(editor.editModes.objectSelect)
          end
        end
        if txt then
          debugDrawer:drawTextAdvanced(vec3(mouseInfo.rayCast.pos), String(txt), ColorF(1, 1, 1, 1), true, false, clr or ColorI(0, 0, 0, 255))
        end
      else
        if im.IsMouseClicked(0) and not im.GetIO().WantCaptureMouse and not editor.isAxisGizmoHovered() then
          editor.selectEditMode(editor.editModes.objectSelect)
        end
      end
    end
  end

  change = self:combinedWidget() or change
  return change
end

function C:enableEditing()
  self:updateTransform()
  editor.selectEditMode(editor.editModes[self.editName])
  self._beginCooldown = 1
end

function C:helperFocus()
  editor.fitViewToSelectionSmooth(self.pos)
end
function C:helperPositionToCamera()
  self:set(getCameraPosition())
end
function C:helperPositionInFrontOfToCamera()
  self:set(vec3(quat(getCameraQuat()) * vec3(0, 15, 0)) + getCameraPosition())
end
function C:helperPositionDownToTerrain()
  if not core_terrain.getTerrain() then return end
  self:set(vec3(self.pos.x, self.pos.y, core_terrain.getTerrainHeight(self.pos) or self.pos.z))
end
function C:helperRotationToCamera()
  self:set(nil , quat(getCameraQuat()))
end
function C:helperCameraToPosition()
  if not commands.isFreeCamera() then
    commands.setFreeCamera()
  end
  local camRot = quat(getCameraQuat())
  setCameraPosRot(self.pos.x, self.pos.y, self.pos.z, camRot.x, camRot.y, camRot.z, camRot.w)
end
function C:helperCameraToRotation()
  if not commands.isFreeCamera() then
    commands.setFreeCamera()
  end
  local pos = getCameraPosition()
  setCameraPosRot(pos.x, pos.y, pos.z, self.rot.x, self.rot.y, self.rot.z, self.rot.w)
end
function C:helperCameraToPositionRotation()
  if not commands.isFreeCamera() then
    commands.setFreeCamera()
  end
  setCameraPosRot(self.pos.x, self.pos.y, self.pos.z, self.rot.x, self.rot.y, self.rot.z, self.rot.w)
end
function C:helperMoveToTransform()
  local playerVehicle = be:getPlayerVehicle(0)
  if playerVehicle then
    spawn.safeTeleport(playerVehicle, self.pos, self.rot)
  end
end
function C:helperAlignWithTerrain()
  if not core_terrain.getTerrain() then return end
  local terrainNormal = core_terrain.getTerrainSmoothNormal(self.pos)
  local fwd = (self.rot * vec3(0,1,0)):projectToOriginPlane(terrainNormal)
  self:set(nil, quatFromDir(fwd, terrainNormal))
end
function C:helperRotateWithCamera()
  self:set(nil, quat(getCameraQuat()))
end

-- draws helper functionality
function C:contextMenu()
  local change = false
  if self.hasPos then
    if im.MenuItem1("Position to Camera", nil, false, true) then
      self:helperPositionToCamera()
      im.CloseCurrentPopup()
      change = true
    end
    if im.MenuItem1("Position in front of Camera", nil, false, true) then
      self:helperPositionInFrontOfToCamera()
      im.CloseCurrentPopup()
      change = true
    end
    if im.MenuItem1("Position down to Terrain", nil, false, true) then
      self:helperPositionDownToTerrain()
      im.CloseCurrentPopup()
      change = true
    end
  end
  if self.hasRot then
    if im.MenuItem1("Rotation to Camera", nil, false, true) then
      self:helperRotationToCamera()
      im.CloseCurrentPopup()
      change = true
    end
  end
  im.Separator()
  if self.hasPos then
    if im.MenuItem1("Camera to Position", nil, false, true) then
      self:helperCameraToPosition()
      im.CloseCurrentPopup()
      change = true
    end
  end
  if self.hasRot then
    if im.MenuItem1("Camera to Rotation", nil, false, true) then
      self:helperCameraToRotation()

      im.CloseCurrentPopup()

    end
  end
  if self.hasPos and self.hasRot then
    if im.MenuItem1("Camera to Position+Rotation", nil, false, true) then
      self:helperCameraToPositionRotation()
      im.CloseCurrentPopup()

    end
  end
  return change
end

function C:combinedWidget()
  local changed = false
  im.PushID1("transform_util_" .. self.id)
  --self.widgetSettings.width = 350
  local width = self.widgetSettings.width or im.GetContentRegionAvailWidth()
  local elemCount = (self.allowTranslate and 1 or 0) + (self.allowRotate and 1 or 0) + (self.allowScale and 1 or 0)
  local scale = editor.getPreference("ui.general.scale")
  local spacing, elemHeight = 0, im.GetFrameHeightWithSpacing()
  local height = elemCount * elemHeight / scale + (elemCount - 2) * spacing
  --dump(elemCount, spacing, elemHeight)
  local prePos = im.GetCursorPos()
  --[[
  im.Text(self.objectName)
  im.SameLine()
  im.SetCursorPosX(prePos.x + width - 23*scale)
  if editor.uiIconImageButton(editor.icons.settings, vec22x22) then
    im.OpenPopup("Tranform Util Context Menu " .. self.objectName)
  end
  if im.BeginPopup("Tranform Util Context Menu " .. self.objectName) then
    changed = self:contextMenu() or changed
    im.EndPopup()
  end
  ]]
  local startPosX = im.GetCursorPosX()
  prePos = im.GetCursorPos()
  if not self:correctEditMode() then
    if editor.uiIconImageButton(editor.icons.mode_edit, im.ImVec2(height, height)) then
      self:enableEditing()
    end
    im.tooltip("Start Editing " .. self.objectName)
  else
    editor.updateAxisGizmo(function()
      self:beginDrag()
    end, function()
      self:endDragging()
    end, function()
      self:dragging()
    end)
    editor.drawAxisGizmo()

    if editor.uiIconImageButton(editor.icons.check, im.ImVec2(height, height), activeColor) then
      editor.selectEditMode(nil)
    end
    im.tooltip("Finish Editing " .. self.objectName)
  end
  local endPos = im.GetCursorPos()
  im.SameLine()
  local btnX = im.GetCursorPosX()
  local buttons = self:getValidButtons()
  local rowsNeeded = elemCount > 1 and 2 or 1
  local buttonHeight = (elemHeight * elemCount) / (rowsNeeded * scale)
  local columnsNeeded = math.ceil(#buttons / rowsNeeded)
  local prevRow = 0
  for i, btn in ipairs(buttons) do
    local row = math.floor((i - 1) / columnsNeeded)
    if row ~= prevRow then
      prevRow = row
      --im.NewLine()
      im.SetCursorPos(im.ImVec2(btnX, math.ceil(prePos.y + buttonHeight * row * scale + spacing * row * scale)))
    end
    if editor.uiIconImageButton(editor.icons[btn.icon] or editor.icons.settings, im.ImVec2(buttonHeight, buttonHeight), smallButtonColor) then
      self[btn.fun](self)
      changed = true
    end
    im.tooltip(btn.tooltip)
    im.SameLine()
    prePos.x = math.max(prePos.x, im.GetCursorPosX())
  end

  im.SameLine()

  local row = 0
  if self.allowTranslate then
    im.SetCursorPos(im.ImVec2(prePos.x, math.ceil(prePos.y + elemHeight * row + spacing * row)))
    row = row + 1
    im.Text("Pos")
    im.SameLine()
    im.SetCursorPosX(prePos.x + 35 * scale)
    im.PushItemWidth(width - (im.GetCursorPosX() - startPosX))
    if im.InputFloat3("##Pos", self.inputPos, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f") then
      self.pos = vec3(self.inputPos[0], self.inputPos[1], self.inputPos[2])
      changed = true
    end
    im.PopItemWidth()
  end
  if self.allowRotate then
    im.SetCursorPos(im.ImVec2(prePos.x, math.ceil(prePos.y + elemHeight * row + spacing * row)))
    row = row + 1
    im.Text("Rot")
    im.SameLine()
    im.SetCursorPosX(prePos.x + 35 * scale)
    im.PushItemWidth(width - (im.GetCursorPosX() - startPosX))
    if im.InputFloat4("##Rot", self.inputRot, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f") then
      self.rot = quat(self.inputRot[0], self.inputRot[1], self.inputRot[2], self.inputRot[3])
      changed = true
    end
    im.PopItemWidth()
  end
  if self.allowScale then
    im.SetCursorPos(im.ImVec2(prePos.x, math.ceil(prePos.y + elemHeight * row + spacing * row)))
    row = row + 1
    im.Text("Scl")
    im.SameLine()
    im.SetCursorPosX(prePos.x + 35 * scale)
    im.PushItemWidth(width - (im.GetCursorPosX() - startPosX))
    if self.oneDimensionalScale then
      if im.InputFloat("##Scl", self.inputScl, nil, nil, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f") then
        self.scl = self.inputScl[0]
        changed = true
      end
    else
      if im.InputFloat3("##Scl", self.inputScl, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f") then
        self.scl = vec3(self.inputScl[0], self.inputScl[1], self.inputScl[2])
        changed = true
      end
    end
    im.PopItemWidth()
  end
  if changed then
    self:updateTransform()
  end
  im.SetCursorPos(endPos)
  im.PopID()
  changed = self.changedDragged or self.changedDragging or changed
  self.changedDragged, self.changedDragging = nil, nil
  return changed
end

function C:getValidButtons()
  local validButtons = {}
  for i, btn in ipairs(buttonData) do
    if (btn.needsPos and not self.allowTranslate) or (btn.needsRot and not self.allowRotate) then
      break
    end
    table.insert(validButtons,btn)
  end
  return validButtons
end

-- draws a button to enter the editmode and handles the gizmo if in the edit mode
function C:gizmo()
  local contextChanged = false
  if self.showGizmo then
    im.PushID1("transform_util_" .. self.id)
    if not self:correctEditMode() then
      if im.Button("Edit " .. self.objectName) then
        self:enableEditing()
      end
    else
      editor.updateAxisGizmo(function()
        self:beginDrag()
      end, function()
        self:endDragging()
      end, function()
        self:dragging()
      end)
      editor.drawAxisGizmo()
      if im.Button("Exit Editing " .. self.objectName) then
        editor.selectEditMode(nil)
      end
    end
    im.SameLine()
    if im.Button("...") then
      im.OpenPopup("Tranform Util Context Menu " .. self.objectName)
    end
    if im.BeginPopup("Tranform Util Context Menu " .. self.objectName) then
      contextChanged = self:contextMenu()
      im.EndPopup()
    end
    im.PopID()
  end
  print("gizmo change dragged " .. dumps(self.changedDragging))
  local changed = self.changedDragged or self.changedDragging or contextChanged
  self.changedDragged, self.changedDragging = nil, nil
  return changed
end

-- draws all widgets that are enabled.
function C:widget()
  im.PushID1("transform_util_" .. self.id)
  local changed = false
  if self.showWidgets then
    if self.allowTranslate then
      if im.InputFloat3(self.objectName .. " Position", self.inputPos, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        self.pos = vec3(self.inputPos[0], self.inputPos[1], self.inputPos[2])
        changed = true
      end
    end
    if self.allowRotate then
      if im.InputFloat4(self.objectName .. " Rotation", self.inputRot, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        self.rot = quat(self.inputRot[0], self.inputRot[1], self.inputRot[2], self.inputRot[3])
        changed = true
      end
    end
    if self.allowScale then
      if self.oneDimensionalScale then
        if im.InputFloat(self.objectName .. " Scale", self.inputScl, nil, nil, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          self.scl = self.inputScl[0]
          changed = true
        end
      else
        if im.InputFloat3(self.objectName .. " Scale", self.inputScl, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          self.scl = vec3(self.inputScl[0], self.inputScl[1], self.inputScl[2])
          changed = true
        end
      end
    end
    if changed then
      self:updateTransform()
    end
  end
  im.PopID()
  return changed
end

-- draws all widgets that are enabled.
function C:widgetCondensed()
  im.PushID1("transform_util_" .. self.id)
  local changed = false
  if self.showWidgets then
    im.Text(self.objectName)
    if self.allowTranslate then
      if im.InputFloat3("Pos", self.inputPos, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        self.pos = vec3(self.inputPos[0], self.inputPos[1], self.inputPos[2])
        changed = true
      end
    end
    if self.allowRotate then
      if im.InputFloat4("Rot", self.inputRot, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        self.rot = quat(self.inputRot[0], self.inputRot[1], self.inputRot[2], self.inputRot[3])
        changed = true
      end
    end
    if self.allowScale then
      if self.oneDimensionalScale then
        if im.InputFloat("Scl", self.inputScl, nil, nil, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          self.scl = self.inputScl[0]
          changed = true
        end
      else
        if im.InputFloat3("Scl", self.inputScl, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
          self.scl = vec3(self.inputScl[0], self.inputScl[1], self.inputScl[2])
          changed = true
        end
      end
    end
    if changed then
      self:updateTransform()
    end
  end
  im.PopID()
  return changed
end

-- dragging functions
function C:beginDrag()
  self.beginDragPos = vec3(self.pos)
  self.beginDragRot = quat(self.rot)
  self.beginDragScl = self.oneDimensionalScale and self.scl or vec3(self.scl)
end
function C:dragging()
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate and self.allowTranslate then
    self.pos = vec3(editor.getAxisGizmoTransform():getColumn(3))
    self.inputPos[0] = im.Float(self.pos.x)
    self.inputPos[1] = im.Float(self.pos.y)
    self.inputPos[2] = im.Float(self.pos.z)
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate and self.allowRotate then
    local rotation = QuatF(0, 0, 0, 1)
    rotation:setFromMatrix(editor.getAxisGizmoTransform())
    if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
      self.rot = quat(rotation)
    else
      self.rot = self.beginDragRot * quat(rotation)
    end
    self.inputRot[0] = im.Float(self.rot.x)
    self.inputRot[1] = im.Float(self.rot.y)
    self.inputRot[2] = im.Float(self.rot.z)
    self.inputRot[3] = im.Float(self.rot.w)
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale and self.allowScale then
    if self.oneDimensionalScale then
      local scl = vec3(worldEditorCppApi.getAxisGizmoScale())
      if scl.x ~= 1 then
        scl = scl.x
      elseif scl.y ~= 1 then
        scl = scl.y
      elseif scl.z ~= 1 then
        scl = scl.z
      else
        scl = 1
      end
      if scl < 0 then
        scl = 0
      end
      self.scl = self.beginDragScl * scl
      self.inputScl[0] = self.scl
    else
      local scl = vec3(worldEditorCppApi.getAxisGizmoScale())
      self.scl = self.beginDragScl:componentMul(scl)
      self.inputScl[0] = im.Float(self.scl.x)
      self.inputScl[1] = im.Float(self.scl.y)
      self.inputScl[2] = im.Float(self.scl.z)
    end
  end
  local x, y, z = self.rot * vec3(1, 0, 0), self.rot * vec3(0, 1, 0), self.rot * vec3(0, 0, 1)
  debugDrawer:drawLine((self.pos - x * 1000), (self.pos + x * 1000), ColorF(0.9, 0, 0, 0.6))
  debugDrawer:drawLine((self.pos - y * 1000), (self.pos + y * 1000), ColorF(0, 0.9, 0, 0.6))
  debugDrawer:drawLine((self.pos - z * 1000), (self.pos + z * 1000), ColorF(0, 0, 0.9, 0.6))

  self.changedDragging = true

end
function C:endDragging()
  self.changedDragged = true
end

-- helper function for getting if the correct edit mode is active
function C:correctEditMode()
  return (editor.editMode and editor.editMode.displayName == self.editName) or false
end

-- helper callbacks for the edit mode
function C:onActivate()
  editor.clearObjectSelection()
  self:set()
end
function C:onDeactivate()
  editor.clearObjectSelection()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end