--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local min, max = math.min, math.max
local str_byte, str_sub, str_len, str_find = string.byte, string.sub, string.len, string.find

local jbeamUtils = require("jbeam/utils")

-- these are defined in C, do not change the values
local NORMALTYPE = 0

local function cleanCameraData(d)
  for k, v in pairs(d) do
    -- delete unneeded data to keep the messages small
    if k == 'group' or k == 'firstGroup' or k == 'partOrigin' or k == 'childParts'
    or k == 'partName' or k == 'slotType' or k == 'collision' or k == 'selfCollision'
    or k == 'nodeWeight' or  k == 'beamnDamp' or k == 'beamDeform' or k == 'beamSpring'
    or k == 'beamDamp' or k == 'cid' or k == 'globalSkin' or k == 'skinName' or k == 'beamStrength' then
      d[k] = nil
    elseif type(v) == 'table' then
      cleanCameraData(v)
    end
  end
end

local function getCameraData(vehicle)
  local cameraData = {}
  for k,v in pairs(vehicle.cameras) do
    v = deepcopy(v) or {}
    -- shift ipair() iterable indices, from 0..N-1  to  1..N
    if v[0] ~= nil then
      table.insert(v, 1, v[0])
      v[0] = nil
    end
    cameraData[k] = v
  end
  cleanCameraData(cameraData)
  return cameraData
end

-- Camera retrocompatibility conversions:
local function upgradeCamera(vehicle, oldName, newName)
  if vehicle[oldName] ~= nil then
    if vehicle.cameras[newName] then
      --log("E", "", "Overwriting existing vehicle.cameras."..newName.." with old deprecated vehicle."..oldName.." field")
    end
    if oldName == "camerasInternal" or oldName == "camerasRelative" then
      local driverCameraSet = false -- only set 'driver' once
      for k, v in pairs(vehicle[oldName]) do
        -- rename variable "type" to "name"
        if v.type ~= nil then
          --log("W", "", "Renaming deprecated 'type' camera field to 'name': vehicle."..oldName.."::"..dumps(v.type))
          v.name = v.type
          v.type = nil
        end
        -- backward compatibility for old cockpitCamera flag
        if oldName == "camerasInternal" and v.cockpitCamera == true and v.name == nil and not driverCameraSet then
          --log("W", "", "Renaming deprecated 'cockpitCamera' flag to 'driver'")
          v.name = 'driver'
          driverCameraSet = true
        end
        -- backward compatibility for old 'dash' name
        if v.name == "dash" then
          --log("W", "", "Renaming deprecated 'dash' onboard camera to 'driver'")
          v.name = "driver"
        end
        if v.name == "driver" then
          v.rightHandCamera = v.rightHandCamera or false -- replace missing field with actual, explicit value
          if v.rightHandDoor == nil then
            v.rightHandDoor = v.rightHandCamera -- by default, the vehicle is entered/exited from the same side as the camera is located (used for e.g. walking mode)
          end
        end
      end
    end
    vehicle.cameras[newName] = vehicle[oldName]
    vehicle[oldName] = nil
    --log("W", "", "Upgraded old deprecated vehicle."..oldName.." to new vehicle.cameras."..newName.." field")
  end
end

local function processOnboard(vehicle)
  if vehicle.cameras ~= nil and vehicle.cameras.onboard ~= nil then
    for icKey, icam in pairs(vehicle.cameras.onboard) do
      if type(icam.x) == 'number' and type(icam.y) == 'number' and type(icam.z) == 'number' then
        if (not icam.ignoreNodeOffset) and icam.nodeOffset and type(icam.nodeOffset) == 'table' and icam.nodeOffset.x and icam.nodeOffset.y and icam.nodeOffset.z then
          icam.x, icam.y, icam.z = icam.x + sign(icam.x) * icam.nodeOffset.x, icam.y + icam.nodeOffset.y, icam.z + icam.nodeOffset.z
        end
        if icam.nodeMove and type(icam.nodeMove) == 'table' and icam.nodeMove.x and icam.nodeMove.y and icam.nodeMove.z then
          icam.x, icam.y, icam.z = icam.x + icam.nodeMove.x, icam.y + icam.nodeMove.y, icam.z + icam.nodeMove.z
        end

        local camNodeID = jbeamUtils.addNodeWithOptions(vehicle, vec3(icam.x, icam.y, icam.z), NORMALTYPE, icam)

        if icam.id1 ~= nil then jbeamUtils.addBeamWithOptions(vehicle, camNodeID, icam.id1, NORMALTYPE, icam) end
        if icam.id2 ~= nil then jbeamUtils.addBeamWithOptions(vehicle, camNodeID, icam.id2, NORMALTYPE, icam) end
        if icam.id3 ~= nil then jbeamUtils.addBeamWithOptions(vehicle, camNodeID, icam.id3, NORMALTYPE, icam) end
        if icam.id4 ~= nil then jbeamUtils.addBeamWithOptions(vehicle, camNodeID, icam.id4, NORMALTYPE, icam) end
        if icam.id5 ~= nil then jbeamUtils.addBeamWithOptions(vehicle, camNodeID, icam.id5, NORMALTYPE, icam) end
        if icam.id6 ~= nil then jbeamUtils.addBeamWithOptions(vehicle, camNodeID, icam.id6, NORMALTYPE, icam) end
        if icam.id7 ~= nil then jbeamUtils.addBeamWithOptions(vehicle, camNodeID, icam.id7, NORMALTYPE, icam) end
        if icam.id8 ~= nil then jbeamUtils.addBeamWithOptions(vehicle, camNodeID, icam.id8, NORMALTYPE, icam) end
        icam.camNodeID = camNodeID
      else
        icam.camNodeID = icam.idCam or icam.idRef
      end

      -- record the camera node id that was created
    end
    --log('D', "jbeam.postProcess"," - processed "..tableSize(vehicle.cameras.onboard).." cameras.onboard")
  end
end

local function processRelative(vehicle)
  -- emulation mode for camerasRelative
  if vehicle.cameras.relative == nil and vehicle.cameras.onboard then
    -- backward compatibility: import onboard cameras
    vehicle.cameras.relative = {}
    -- try to emulate one from deducing values from the onboard camera system
    for icKey, icam in pairs(vehicle.cameras.onboard) do
      if type(icam.x) == 'number' and type(icam.y) == 'number' and type(icam.z) == 'number' then
        local cr = {}
        local nPos = {x=icam.x, y=icam.y, z=icam.z}
        if vehicle.refNodes and vehicle.refNodes[0] and vehicle.refNodes[0].ref and vehicle.nodes[vehicle.refNodes[0].ref] then
          local refNode = vehicle.nodes[vehicle.refNodes[0].ref]
          cr.pos = nPos - vec3(refNode.pos) -- calculate out the refnode
          cr.pos.x = - cr.pos.x -- invert X and Y axis for some reason?!
          cr.pos.y = - cr.pos.y -- invert X and Y axis for some reason?!
        end
        cr.name = icam.name
        cr.fov = icam.fov
        cr.rot = vec3(0, 180, 0) -- look forward by default
        table.insert(vehicle.cameras.relative, cr)
      end
    end
  elseif vehicle.cameras.relative ~= nil then
    if vehicle.refNodes and vehicle.refNodes[0] and vehicle.refNodes[0].ref and vehicle.nodes[vehicle.refNodes[0].ref] then
      local refNodePos = vec3(vehicle.nodes[vehicle.refNodes[0].ref].pos)

      -- convert position table to vec3
      for _, cr in pairs(vehicle.cameras.relative) do
        cr.pos = vec3(cr)
        cr.x, cr.y, cr.z = nil, nil, nil

        cr.pos = cr.pos - refNodePos -- calculate out the refnode
        cr.pos.x = - cr.pos.x -- invert X and Y axis for some reason?!
        cr.pos.y = - cr.pos.y -- invert X and Y axis for some reason?!

        -- some default values
        if cr.rot == nil then
          cr.rot = vec3()
        else
          cr.rot = vec3(cr.rot)
        end
        if cr.fov == nil then cr.fov = 70 end

        -- rotation is 180 dg off? O_o
        cr.rot = cr.rot + vec3(0, 180, 0)
      end
    end
  end
end

local function processOnboard2(vehicle)
  -- Onboard cameras
  if vehicle.cameras.onboard ~= nil then
    local counter = 1
    local foundCameras = {}
    for k, v in pairs(vehicle.cameras.onboard) do
      -- automatic numeric naming
      if v.name == nil or type(v.name) ~= 'string' then
        v.name = 'onboard_' .. tostring(counter)
        v.order = v.order or counter + 20
        counter = counter + 1
      end
      if v.fov == nil then v.fov = 75 end

      -- check for duplicates:
      if foundCameras[v.name] then
        log('E', "jbeam.pushToPhysics", "Ignoring onboard camera with duplicate name: " .. tostring(v.name))
      end
      foundCameras[v.name] = 1
    end
    --log("I", "", "Found cameras: "..dumps(vehicle.cameras.onboard))
  end
end

local function process(objID, vehicle)
  profilerPushEvent('jbeam/camera.process')

  vehicle.cameras = vehicle.cameras or {}
  upgradeCamera(vehicle, "camerasInternal", "onboard")
  upgradeCamera(vehicle, "cameraExternal",  "orbit")
  upgradeCamera(vehicle, "camerasRelative", "relative")
  upgradeCamera(vehicle, "cameraChase",     "chase")

  processOnboard(vehicle)
  processRelative(vehicle)
  processOnboard2(vehicle)

  vehicle.cameraData = getCameraData(vehicle)

  --[[
  if vehicle.mirrors then
    if obj then
      obj:queueGameEngineLua("extensions.load('core_vehicleMirrors')")
    else
      extensions.load('core_vehicleMirrors')
    end
  end
  --]]
  profilerPopEvent() -- jbeam/camera.process
end

M.process = process

return M
