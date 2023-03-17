-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'core_camera'}

local min = math.min
local max = math.max

M.cabinFilterStrength = 1

local lastCamPos = nil
local lastCameraForward = nil
local vecDown3F = vec3(0,0,-1)
local frameFlag = true

local function onPreRender(dtReal, dtSim, dtRaw)
  if Engine.Audio.getGlobalParams then
    local globalParams = Engine.Audio.getGlobalParams()
    if globalParams then
      local camPos = getCameraPosition()
      local cameraForward = getCameraForward()

      if dtSim > 0 then
        globalParams:setParameterValue("g_CamSpeedMS", camPos:distance(lastCamPos or camPos) / dtSim)
        globalParams:setParameterValue("g_CamRotationSpeedMS", cameraForward:distance(lastCameraForward or cameraForward) / dtSim)
      end
      lastCamPos = camPos
      lastCameraForward = cameraForward

      if frameFlag then
        local tod = scenetree.tod
        if tod and tod.time then
          globalParams:setParameterValue("g_Tod", tod.time)
        end

        local camAngle = math.atan2(cameraForward.x, -cameraForward.y) * 180 / math.pi + 180.0
        globalParams:setParameterValue("g_CamRotationAngle", camAngle)

        local veh = be:getPlayerVehicle(0)
        if veh then
          globalParams:setParameterValue("g_VehicleSpeedPlayerMS", veh:getVelocity():length())
        end
      else
        globalParams:setParameterValue("g_CamOnboard", core_camera and core_camera.isCameraInside(0, camPos) and 1 or 0) -- cockpit flag, used e.g. for driver camera
        --globalParams:setParameterValue("g_CamOnboard", 1) -- cockpit flag, used e.g. for driver camera
        globalParams:setParameterValue("c_CabinFilterReverbStrength", min(max(M.cabinFilterStrength, 0), 1)) -- cockpit flag, used e.g. for driver camera

        local camObj = getCamera()
        camObj = (camObj and Sim.upcast(camObj)) or camObj
        globalParams:setParameterValue("g_CamFree", commands.isFreeCamera() and 1 or 0)
        local camUnderwater = (camObj and camObj:isCameraUnderwater()) and 1 or 0
        globalParams:setParameterValue("g_CamUnderwater", camUnderwater)
        globalParams:setParameterValue("g_UnderwaterDepth", camUnderwater == 0 and -1 or camObj:getCameraDepthUnderwater())
        local camHeightToGeometry = castRayStatic(camPos, vecDown3F, 200)
        globalParams:setParameterValue("g_CamHeightToGround", (camObj and camHeightToGeometry) or 0)
        globalParams:setParameterValue("g_CamHeightToSea", (camObj and camPos.z) or 0)
      end
    end

    frameFlag = not frameFlag
  end
end

local function initEngineSound(vehicleId, engineId, jsonPath, nodeIdArray, noloadVol, loadVol)
  local vehicle = scenetree.findObjectById(vehicleId)
  if vehicle then
    if type(nodeIdArray) ~= 'table' then
      nodeIdArray = {nodeIdArray}
    end
    vehicle:engineSoundInit(engineId, jsonPath, nodeIdArray, noloadVol or 1, loadVol or 1)
    vehicle:engineSoundParameterList(engineId, {wet_level = 0, dry_level = 1})
  end
end

local function initExhaustSound(vehicleId, engineId, jsonPath, nodeIdPairArray, noloadVol, loadVol)
  local vehicle = scenetree.findObjectById(vehicleId)
  if vehicle then
    if type(nodeIdPairArray) ~= 'table' then
      nodeIdPairArray = {{nodeIdPairArray, nodeIdPairArray}}
    end

    vehicle:engineSoundInit(engineId, jsonPath, nodeIdPairArray, noloadVol or 1, loadVol or 1)
    vehicle:engineSoundParameterList(engineId, {wet_level = 0, dry_level = 1})
  end
end

local function updateEngineSound(vehicleId, engineId, rpm, onLoad, engineVolume)
  local vehicle = scenetree.findObjectById(vehicleId)
  if not vehicle then return end
  vehicle:engineSoundUpdate(engineId, rpm, onLoad, engineVolume)
end

local function setEngineSoundParameter(vehicleId, engineId, paramName, paramValue)
  local vehicle = scenetree.findObjectById(vehicleId)
  if not vehicle then return end
  vehicle:engineSoundParameter(engineId, paramName, paramValue)
end

local function setEngineSoundParameterList(vehicleId, engineId, parameters)
  local vehicle = scenetree.findObjectById(vehicleId)
  if not vehicle then return end
  vehicle:engineSoundParameterList(engineId, parameters)
end

local function setExhaustSoundNodes(vehicleId, engineId, nodeIdPairArray)
  local vehicle = scenetree.findObjectById(vehicleId)
  if not vehicle then return end

  vehicle:engineSoundNodes(engineId, nodeIdPairArray)
end

M.onPreRender                 = onPreRender
M.initEngineSound             = initEngineSound
M.initExhaustSound            = initExhaustSound
M.updateEngineSound           = updateEngineSound
M.setEngineSoundParameter     = setEngineSoundParameter
M.setEngineSoundParameterList = setEngineSoundParameterList
M.setExhaustSoundNodes        = setExhaustSoundNodes
return M
