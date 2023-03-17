-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local manualzoom = require('core/cameraModes/manualzoom')

local C = {}
C.__index = C

local factorSmoother, dxSmoother, dySmoother, dzSmoother

local function rotateEuler(x, y, z, q)
  q = q or quat()
  q = quatFromEuler(0, z, 0) * q
  q = quatFromEuler(0, 0, x) * q
  q = quatFromEuler(y, 0, 0) * q
  return q
end

function C:init()
  self.resetCameraOnVehicleReset = false
  self.disabledByDefault = true

  self.lightBrightness = 0 -- disable light by default
  self.camMaxDist = math.huge
  self.mustResetCam = 0

  self.slots = {} -- stored position/rotations
  self.slotNameIndexMap = {}

  self.manualzoom = manualzoom()
  self:onVehicleCameraConfigChanged()
  self:reset()
end

function C:onVehicleCameraConfigChanged()
  if not self.refNodes or not self.refNodes.ref or not self.refNodes.left or not self.refNodes.back then
    log('D', 'core_camera.relative', 'No refNodes found, using default fallback')
    self.refNodes = { ref=0, left=1, back=2 }
  end

  self.vehicleCameraConfigJustChanged = true
end

function C:_updateLight(brightness)
  if brightness ~= nil then
    self.lightBrightness = brightness
  end
  self.lightBrigtness = math.max(0, self.lightBrightness)
  if not scenetree.relativecameralight then
    local l = createObject('PointLight')
    l.canSave  = false
    l.radius = 20
    l:registerObject('relativecameralight')
  end
  scenetree.relativecameralight.isEnabled = self.lightBrightness > 0
  scenetree.relativecameralight.brightness = self.lightBrightness
  scenetree.relativecameralight:postApply()
end

function C:sendMenus()
  -- add menus?
  core_quickAccess.addEntry({ level = '/', uniqueID = 'relativeCameraMenu', generator = function(entries)
    if not self.focused then return {} end
    table.insert(entries, { title = 'RelCam', icon = 'radial_relative_camera', priority = 10, goto = '/camera_relative_mode/'})
  end})

  core_quickAccess.addEntry({ level = '/camera_relative_mode/', uniqueID = 'index', generator = function(entries)
    if not self.focused then return {} end
    local tmp = { title = 'Light', icon = 'radial_electrics', priority = 10, onSelect = function()
      if self.lightBrightness >= 0 and  self.lightBrightness < 0.1 then
        self.lightBrightness = 0.1
      elseif self.lightBrightness >= 0.1 and self.lightBrightness < 0.5 then
        self.lightBrightness = 0.5
      elseif self.lightBrightness >= 0.5 and self.lightBrightness < 1 then
        self.lightBrightness = 1
      elseif self.lightBrightness >= 1 then
        self.lightBrightness = 0
      end
      --print("new light brightness mode: " .. tostring(self.lightBrightness))
      self:_updateLight()
      ui_message('Light intensity: ' .. math.ceil(self.lightBrightness * 100) .. ' %' , 10, 'cameramode')
      return {'reload'}
    end}
    if self.lightBrightness > 0 then tmp.color = '#ff6600' end
    table.insert(entries, tmp)
    local nearClipLabel = self.nearClip and (self.nearClip.." m") or "level defined"
    table.insert(entries, { title = 'Near Clip: ' .. nearClipLabel, icon = 'radial_near_clip_value', priority = 10, onSelect = function()
      if self.nearClip == nil then
        self.nearClip = 0.0005
      elseif self.nearClip >= 0 and self.nearClip < 0.01 then
        self.nearClip = 0.01
      elseif self.nearClip >= 0.01 and self.nearClip < 0.1 then
        self.nearClip = 0.1
      elseif self.nearClip >= 0.1 then
        self.nearClip = nil
      end
      ui_message('Near clip: '..nearClipLabel, 10, 'cameramode')
      return {'reload'}
    end})
    tmp = { title = 'Slots', icon = 'radial_slots', priority = 50, goto = '/camera_relative_mode/slots/' }
    if self.slots[1] then
      tmp.color = '#ff6600'
    end
    table.insert(entries, tmp)
  end})

  core_quickAccess.addEntry({ level = '/camera_relative_mode/slots/', uniqueID = 'slots', generator = function(entries)
    if not self.focused then return {} end

    for i = 1, 10 do
      local tmp = { title = tostring(i), icon = 'radial_relative_camera', priority = i, onSelect = function()
        if self.slots[i] == nil then
          self:saveSlot(i)
        else
          self:loadSlot(i)
        end
        return {'reload'}
      end}
      if self.slots[i] then
        -- existing?
        tmp.desc = "Load position from this slot"
        tmp.color = '#ff6600'
        -- use name if existing :)
        if self.slots[i].name then
          tmp.title = self.slots[i].name
        end
      else
        -- not existing?
        tmp.title = tmp.title.." (empty)"
        tmp.desc = "Save position into this slot"
      end
      table.insert(entries, tmp)
    end
  end})
end

function C:restoreLightInfo()
  -- restore light brightness info
  if self.storedLightBrightness ~= nil then
    self:_updateLight(self.storedLightBrightness)
    self.storedLightBrightness = nil
  end
end

function C:saveSlot(slot)
  self.slots[slot] = {
    pos = vec3(self.pos),
    rot = vec3(self.rot),
    fov = self.manualzoom.fov
  }
  ui_message('Camera position stored in slot ' .. tostring(slot), 10, 'cameramode')
end

function C:loadSlot(slot)
  if type(slot) == 'string' then
    --print(">> slot " .. tostring(slot) .. " is ID " .. tostring(self.slotNameIndexMap[slot]))
    slot = self.slotNameIndexMap[slot] -- convert name to ID
    if not slot then return false end
  end
  if not self.slots[slot] then
    ui_message('Slot ' .. tostring(slot) .. ' empty'  , 10, 'cameramode')
    return false
  end

  -- load
  local slot = self.slots[slot]
  self.pos = slot.pos
  self.rot = slot.rot
  self.manualzoom:init(slot.fov)
  return true
end

function C:setFOV(fov)
  self.manualzoom:init(fov)
end

function C:setRotation(rot)
  self.rot = rot
end

function C:setOffset(pos)
  self.pos = pos
end

function C:hotkey(hotkey, modifier)
  if not self.focused then return end
  if modifier == 0 then
    self:loadSlot(hotkey)
  elseif modifier == 1 then
    self:saveSlot(hotkey)
  end
end

function C:storeLightInfo()
  -- store light brightness info
  self.storedLightBrightness = self.lightBrightness
  self:_updateLight(0)
end

function C:onCameraChanged(focused)
  if focused then
    self:sendMenus()
    self:restoreLightInfo()
  else
    self:storeLightInfo()
  end
end

function C:reset()
  self.pos = self.resetPos
  self.rot = self.resetRot
  self.manualzoom:reset()
  factorSmoother = newTemporalSmoothing(50,50)
  dxSmoother = newTemporalSmoothing(10,7)
  dySmoother = newTemporalSmoothing(10,7)
  dzSmoother = newTemporalSmoothing(10,7)
end

function C:setMaxDistance(d)
  self.camMaxDist = d
end

function C:update(data)
  local ref  = vec3(data.veh:getNodePosition(self.refNodes.ref))
  local left = vec3(data.veh:getNodePosition(self.refNodes.left))
  local back = vec3(data.veh:getNodePosition(self.refNodes.back))

  -- check if we must reset the camera
  if self.vehicleCameraConfigJustChanged then
    self.vehicleCameraConfigJustChanged = false
    local vehicleName = data.veh:getField('JBeam','0')
    if self.lastVehicleName ~= vehicleName then
      self.mustResetCam = 1 -- spawnWorldOOBBRearPoint is not valid after a vehicle change until 1 frame later
    end
    self.lastVehicleName = vehicleName
  end

  if self.mustResetCam == 0 then
    self.pos = nil
    self.resetPos = nil
    self.manualzoom:reset()
  end

  self.mustResetCam = math.max(self.mustResetCam - 1, -1)
  if self.pos == nil or self.rot == nil then
    if #self > 0 then -- onboard/relative cameras were defined
      for k, cr in ipairs(self) do
        if cr.name then
          table.insert(self.slots, cr)
          self.slotNameIndexMap[cr.name] = #self.slots
        else
          log("W","","Relative camera #"..dumps(k)..": missing node name: "..dumps(cr))
        end
      end
      self:loadSlot(1)
    end
    if self.pos == nil then
      local nx = (left-ref):normalized()
      local ny = (back-ref):normalized()
      local nz = nx:cross(ny):normalized()
      local carPos = vec3(data.veh:getSpawnWorldOOBBRearPoint())
      local pos = data.pos - carPos
      pos = vec3(pos:dot(nx), pos:dot(ny), pos:dot(nz))
      pos.z = ref.z
      local offset = vec3(0,-0.5,0)
      self.pos = pos + offset
    end
    self.rot = self.rot or vec3(0,180,0)
  end

  if self.resetPos == nil then
    self.resetPos = vec3(self.pos) -- copy
    self.resetRot = vec3(self.rot) -- copy
  end

  -- update input
  local dx = dxSmoother:getCapped(MoveManager.right   - MoveManager.left,     data.dt)
  local dy = dySmoother:getCapped(MoveManager.forward - MoveManager.backward, data.dt)
  local dz = dzSmoother:getCapped(MoveManager.up      - MoveManager.down,     data.dt)
  local dtPosFactor = factorSmoother:getUncapped(data.speed / 80, data.dt)
  local pd = dtPosFactor * data.dt * vec3(dx, dy, dz)

  local rdx = MoveManager.yawRelative   + 10*data.dt*(MoveManager.yawRight - MoveManager.yawLeft  )
  local rdy = MoveManager.pitchRelative + 10*data.dt*(MoveManager.pitchUp  - MoveManager.pitchDown)
  self.rot = self.rot + 7*vec3(rdx, rdy, 0)

  local dir = (ref - back):normalized()
  local up = dir:cross(left):normalized()
  local qdir = quatFromDir(dir, up)

  if dir:squaredLength() == 0 or up:squaredLength() == 0 then
    data.res.pos = data.pos
    data.res.rot = quatFromDir(vec3(0,1,0), vec3(0, 0, 1))
    if self.nearClip then data.res.nearClip = self.nearClip end
    return false
  end

  local camOffset = qdir * self.pos

  local qdirLook = rotateEuler(-math.rad(self.rot.x), -math.rad(self.rot.y), 0) --math.rad(self.rot.z))
  local qdirLook2 = rotateEuler(0, 0, math.rad(self.rot.z), qdirLook)
  qdir = qdirLook2 * qdir

  local newPos = self.pos + qdirLook * pd
  local distance = newPos:distance(ref)
  if self.camMaxDist and distance < self.camMaxDist then
    self.pos = self.pos + qdirLook * pd
  end

  local pos = data.pos + camOffset

  self.manualzoom:update(data)

  -- application
  data.res.pos = pos
  data.res.rot = qdir
  if self.nearClip then data.res.nearClip = self.nearClip end

  if self.lightBrightness > 0 then
    local lightPos = pos -- + qdirLook * vec3(0.01, 0.01, -0.02)
    scenetree.relativecameralight:setPosRot(lightPos.x, lightPos.y, lightPos.z, data.res.rot.x, data.res.rot.y, data.res.rot.z, data.res.rot.w)
  end

  return true
end

function C:setRefNodes(centerNodeID, leftNodeID, backNodeID)
  self.refNodes = self.refNodes or {}
  self.refNodes.ref = centerNodeID
  self.refNodes.left = leftNodeID
  self.refNodes.back = backNodeID
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
