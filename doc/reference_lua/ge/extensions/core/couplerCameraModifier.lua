-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local obj1OriginalDistance = 5
local obj2OriginalDistance = 5

local playerId

local objId1
local objId2

local detached = true

local function checkForTrailer(objId1_, objId2_)
  local playerId = be:getPlayerVehicleID(0)

  if playerId ~= objId1_ and playerId ~= objId2_ then return false end

  if objId1_ == objId2_ then return false end

  local obj1 = scenetree.findObjectById(objId1_)
  local obj2 = scenetree.findObjectById(objId2_)

  local pos1
  local pos2

  pos1 = obj1:getPosition()
  pos2 = obj2:getPosition()

  if obj1 ~= nil and obj2 ~= nil then
    local dist = (pos1 - pos2):len()
    if dist < 1 or dist > 15 then return false end
  end
  return true
end

local function initCameraModifier()
  local dist1 = 5
  local dist2 = 5

  if core_camera ~= nil then
    local obj1 = core_camera.getCameraDataById(objId1)
    local obj2 = core_camera.getCameraDataById(objId2)

    if obj1 ~= nil then
      dist1 = obj1.orbit.distance
      obj1OriginalDistance = dist1
    end
    if obj2 ~= nil then
      dist2 = obj2.orbit.distance
      obj2OriginalDistance = dist2
    end

    -- set camera to orbit if not already
    local activeCam = core_camera.getActiveCamName()

    if activeCam ~= 'orbit' then
      core_camera.setByName(0, 'orbit')
    end
    core_camera.getCameraDataById(objId1).orbit.lockCamera = true
    core_camera.setDefaultDistance(objId1, (dist1+dist2)/1.5+1)
    core_camera.setDistance(objId1, (dist1+dist2)/1.5+1)
    core_camera.getCameraDataById(objId2).orbit.lockCamera = true
    core_camera.setDefaultDistance(objId2, (dist1+dist2)/1.5+1)
    core_camera.setDistance(objId2, (dist1+dist2)/1.5+1)
    -- change camera back to what it used to be
    if activeCam ~= 'orbit' then
      core_camera.setByName(0, activeCam)
    end
  end

  detached = false
end

local function restoreOriginalCamera()
  if core_camera then
    local obj1, obj2
    if objId1 then obj1 = scenetree.findObjectById(objId1) end
    if objId2 then obj2 = scenetree.findObjectById(objId2) end
    local activeCam1 = core_camera.getActiveCamNameByVehId(objId1)
    local activeCam2 = core_camera.getActiveCamNameByVehId(objId2)
    if obj1 and activeCam1 ~= 'orbit' then
      core_camera.setVehicleCameraByNameWithId(objId1, 'orbit')
    end
    if obj2 and activeCam2 ~= 'orbit' then
      core_camera.setVehicleCameraByNameWithId(objId2, 'orbit')
    end

    if obj1 then
      if obj1OriginalDistance ~= nil then
        core_camera.setTargetMode(objId1, 'ref', nil)
        core_camera.setRef(objId1, nil, nil, nil)
        core_camera.setDefaultDistance(objId1, obj1OriginalDistance)
        core_camera.setDistance(objId1, obj1OriginalDistance)
      end
    end

    if obj2 then
      if obj2OriginalDistance ~= nil then
        core_camera.setTargetMode(objId2, 'ref', nil)
        core_camera.setRef(objId2, nil, nil, nil)
        core_camera.setDefaultDistance(objId2, obj2OriginalDistance)
        core_camera.setDistance(objId2, obj2OriginalDistance)
      end
    end

    if obj1 and activeCam1 ~= 'orbit' then
      core_camera.setVehicleCameraByNameWithId(objId1, activeCam1)
    end

    if obj2 and activeCam2 ~= 'orbit' then
      core_camera.setVehicleCameraByNameWithId(objId2, activeCam2)
    end
  end
  detached = true
end

local function onCouplerAttached(objId1_, objId2_)
  if checkForTrailer(objId1_, objId2_) == true then
    restoreOriginalCamera()
    objId1 = objId1_
    objId2 = objId2_
    playerId = be:getPlayerVehicleID(0)
    initCameraModifier()
  end
end

local function onCouplerDetached(objId1_, objId2_)
  restoreOriginalCamera()
  objId1 = nil
  objId2 = nil
end

local function onUpdate()
  local vehicleId = be:getPlayerVehicleID(0)
  if objId1 == nil or objId2 == nil or (vehicleId ~= objId2 and vehicleId ~= objId1) then return end

  local obj1 = scenetree.findObjectById(objId1)
  local obj2 = scenetree.findObjectById(objId2)

  if obj2 == nil or obj1 == nil then onCouplerDetached() return end

  local vehicle = be:getPlayerVehicle(0)
  local playerVehiclePos = vehicle:getPosition()

  local obj1refNodePos = obj1:getNodePosition(core_camera.getCameraDataById(objId1).orbit.refNodes.ref)
  local obj2refNodePos = obj2:getNodePosition(core_camera.getCameraDataById(objId2).orbit.refNodes.ref)

  local obj1leftNodePos = obj1:getNodePosition(core_camera.getCameraDataById(objId1).orbit.refNodes.left)
  local obj2leftNodePos = obj2:getNodePosition(core_camera.getCameraDataById(objId2).orbit.refNodes.left)

  local obj1backNodePos = obj1:getNodePosition(core_camera.getCameraDataById(objId1).orbit.refNodes.back)
  local obj2backNodePos = obj2:getNodePosition(core_camera.getCameraDataById(objId2).orbit.refNodes.back)

  local ref = vec3(obj1refNodePos)
  local left = vec3(obj1leftNodePos)
  local back = vec3(obj1backNodePos)

  local nx = left - ref
  local ny = back - ref
  local nz = nx:cross(ny):normalized()
  ny = nx:cross(-nz):normalized() * ny:length()

  local offset = core_camera.getCameraDataById(objId1).orbit.offset
  local camBase = vec3(offset.x / nx:length(), offset.y / ny:length(), offset.z / nz:length())
  local camOffset2 = nx * camBase.x + ny * camBase.y + nz * camBase.z

  local obj1Pos = vec3(ref + obj1:getPosition() + camOffset2)

  ref =   vec3(obj2refNodePos)
  left =  vec3(obj2leftNodePos)
  back =  vec3(obj2backNodePos)

  nx = left - ref
  ny = back - ref
  nz = nx:cross(ny):normalized()
  ny = nx:cross(-nz):normalized() * ny:length()

  offset = core_camera.getCameraDataById(objId2).orbit.offset
  camBase = vec3(offset.x / nx:length(), offset.y / ny:length(), offset.z / nz:length())
  camOffset2 = nx * camBase.x + ny * camBase.y + nz * camBase.z

  local obj2Pos = vec3(ref + obj2:getPosition() + camOffset2)

  if (obj1Pos - obj2Pos):length() > (obj1OriginalDistance + obj2OriginalDistance) then
    restoreOriginalCamera()
  elseif detached then
    detached = false
    initCameraModifier()
  end

  if detached then return end

  local meanLocation = vec3(obj1Pos + obj2Pos)/2 - vec3(playerVehiclePos)
  local meanLeft = (vec3(obj1leftNodePos) + vec3(obj1Pos) + vec3(obj2leftNodePos) + vec3(obj2Pos)) / 2 - vec3(playerVehiclePos)
  local meanBack = (vec3(obj1backNodePos) + vec3(obj1Pos) + vec3(obj2backNodePos) + vec3(obj2Pos)) / 2 - vec3(playerVehiclePos)

  if core_camera then
    local vid = be:getPlayerVehicleID(0)
    core_camera.setTargetMode(vid, 'notCenter', nil)
    core_camera.setRef(vid, meanLocation, meanLeft, meanBack)
  end
end

local function onVehicleSpawned(vehId)
  if vehId == objId1 or vehId == objId2 then -- This means that one of the coupled vehicles got replaced
    onCouplerDetached()
  end
end

M.checkForTrailer = checkForTrailer
M.onCouplerAttached = onCouplerAttached
M.onCouplerDetached = onCouplerDetached
M.onVehicleSpawned = onVehicleSpawned
M.onUpdate = onUpdate

return M