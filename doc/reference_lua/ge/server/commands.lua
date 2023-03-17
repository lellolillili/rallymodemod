-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M  = {}

local function setCamera(name)
  core_camera.clearInputs()
  local cam = scenetree.findObject(name)
  if not cam then
    log("E", "", "Cannot setCamera, camera not found: "..tostring(name))
    --print(debug.tracesimple())
    return
  end

  local mainView = RenderViewManagerInstance:getOrCreateView('main')

  local currCam = mainView:getCameraObject()
  if currCam and (currCam:getId() == cam:getId()) then
    return -- same camera, nothing to do, let's not trigger onCameraNameChanged (inside requestConfig) when name hasn't truly Changed
  end
  cam:setTransform(getCameraTransform())

  serverConnection.onCameraHandlerSetInitial()
  extensions.hook('onCameraHandlerSet')

  mainView:setCameraObject(cam.obj)

  core_camera.requestConfig(name == "freeCamera" and "free" or nil) -- in the future, when c++ camera is ported to lua, the 'freeCamera' scenetree object will cease to exist, it'll all go through 'gameCamera', and a new camera mode 'free' will exist together with 'orbit', 'driver', 'relative', etc. We begin using that name already here, in preparation for it
  return cam
end

local function getGameCamera() return scenetree.findObject("gameCamera") end
local function getFreeCamera() return scenetree.findObject("freeCamera") end
local function setGameCamera() setCamera("gameCamera") end
local function setFreeCamera() setCamera("freeCamera") core_camera.resetCamera(0) end

local function isFreeCamera()
  return RenderViewManagerInstance:cameraNameEquals("main", "freeCamera")
end

-- camera modifier for faster speed (typically shift key)
local function toggleFastSpeed(enabled)
  local speed = tonumber(TorqueScriptLua.getVar("$Camera::movementSpeed") or 1)
  speed = enabled and (speed*3) or (speed/3)
  TorqueScriptLua.setVar("$Camera::movementSpeed", speed)
end

-- camera modifier for normal speed (typically alt+scrollwheel)
local function changeCameraSpeed(val)
  local speed = tonumber(TorqueScriptLua.getVar("$Camera::movementSpeed") or 1)
  local multiplier = 1 + math.abs(val)*0.2
  if val > 0 then speed = speed * multiplier end
  if val < 0 then speed = speed / multiplier end
  speed = math.max(2, math.min(100,speed))
  TorqueScriptLua.setVar("$Camera::movementSpeed", speed)
  ui_message({txt="ui.camera.speed", context={speed=speed}}, 1, "cameraspeed")
  if editor and editor.active and editor.showNotification then
    editor.showNotification("Camera Speed: " .. string.format("%.2f", speed), nil, "CamSpeed")
  end
end

local wasFreeCamera
local function onNodegrabStart(usingPlayerVehicle)
  wasFreeCamera = isFreeCamera()
  if usingPlayerVehicle then return end
  if not wasFreeCamera then
    setFreeCamera()
  end
end
local function onNodegrabStop(usingPlayerVehicle)
  if not wasFreeCamera then
    setGameCamera()
  end
end

local function dropCameraAtPlayer()
  local playerVehicle = be:getPlayerVehicle(0)
  if not playerVehicle then return end
  local transform = playerVehicle:getTransform()
  setFreeCamera()
  local freeCamera = getFreeCamera()
  if not freeCamera then return end
  freeCamera:setTransform(transform)
end

local function dropPlayerAtCamera()
  local playerVehicle = be:getPlayerVehicle(0)
  if not playerVehicle then return end
  local pos = getCameraPosition()
  local camDir = getCameraForward()
  camDir.z = 0
  local camRot = quatFromDir(camDir, vec3(0,0,1))
  local rot =  quat(0, 0, 1, 0) * camRot -- vehicles' forward is inverted
  playerVehicle:setPositionRotation(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  setGameCamera()
  core_camera.resetCamera(0)
end

local function dropPlayerAtCameraNoReset()
  local playerVehicle = be:getPlayerVehicle(0)
  if not playerVehicle then return end
  local pos = getCameraPosition()
  local camDir = getCameraForward()
  camDir.z = 0
  local camRot = quatFromDir(camDir, vec3(0,0,1))
  camRot = quat(0, 0, 1, 0) * camRot -- vehicles' forward is inverted

  local vehRot = quat(playerVehicle:getClusterRotationSlow(playerVehicle:getRefNodeId()))
  local diffRot = vehRot:inversed() * camRot
  playerVehicle:setClusterPosRelRot(playerVehicle:getRefNodeId(), pos.x, pos.y, pos.z, diffRot.x, diffRot.y, diffRot.z, diffRot.w)
  playerVehicle:applyClusterVelocityScaleAdd(playerVehicle:getRefNodeId(), 0, 0, 0, 0)
  setGameCamera()
  core_camera.resetCamera(0)
  playerVehicle:setOriginalTransform(pos.x, pos.y, pos.z, camRot.x, camRot.y, camRot.z, camRot.w)
end

local function toggleCamera(player)
  player = 0 -- forcibly have multiseat users switch main camera instead of their own
  if isFreeCamera() then
    setGameCamera()
    extensions.core_camera.displayCameraNameUI(player)
    extensions.hook("onCameraToggled", {cameraType='GameCam'})
  else
    setFreeCamera()
    ui_message("ui.camera.freecam",  10, "cameramode")
    extensions.hook("onCameraToggled", {cameraType='FreeCam'})
  end
end

local function setSmoothedFreecam(smoothed)
  local freeCamera = getFreeCamera()
  if not freeCamera then return end
  if smoothed then
    --Switch to Newton Fly Mode with damped rotation
    freeCamera:setFlyMode()
    freeCamera.newtonMode = true
    freeCamera.newtonRotation = true
    freeCamera.angularForce = 100
    freeCamera.angularDrag = 2
    freeCamera.mass = 10
    freeCamera.drag = 2
    freeCamera.force = 500
    freeCamera:setAngularVelocity(vec3(0, 0, 0))
  else
    freeCamera:setFlyMode()
    freeCamera.newtonMode = true
    freeCamera.newtonRotation = true
    -- these should be the same as those in gameengine c++ camera.h declaration
    freeCamera.angularForce = 400
    freeCamera.angularDrag = 16
    -- IMPORTANT: if you touch this, modify camera.mass in editorgui.ed.cs too
    freeCamera.mass = 1
    freeCamera.drag = 17
    freeCamera.force = 600
  end
end

local function getCameraTransformJson()
  local pos = getCameraPosition()
  local rot = getCameraQuat()
  return string.format('[%0.2f, %0.2f, %0.2f, %g, %g, %g, %g]', pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
end

local function setFreeCameraTransformJson(json)
  setFreeCamera()

  json = jsonDecode(json, nil)
  if not json then return end

  for i=1,7 do
    if not json[i] then return end
  end

  setCameraPosRot(json[1], json[2], json[3], json[4], json[5], json[6], json[7])
end

local function onSettingsChanged()
  setSmoothedFreecam(settings.getValue('cameraFreeSmoothMovement'))
end

M.dropCameraAtPlayer = dropCameraAtPlayer
M.dropPlayerAtCamera = dropPlayerAtCamera
M.dropPlayerAtCameraNoReset = dropPlayerAtCameraNoReset
M.getCamera = getFreeCamera -- retrocompat
M.getFreeCamera = getFreeCamera
M.getGame = getGame -- retrocompat
M.onNodegrabStart = onNodegrabStart
M.onNodegrabStop = onNodegrabStop
M.setFreeCamera = setFreeCamera
M.setGameCamera = setGameCamera
M.setCameraFree = setFreeCamera -- retrocompat
M.setCameraPlayer = setGameCamera -- retrocompat
M.changeCameraSpeed = changeCameraSpeed
M.toggleFastSpeed = toggleFastSpeed
M.toggleCamera = toggleCamera
M.isFreeCamera = isFreeCamera
M.getCameraTransformJson = getCameraTransformJson
M.setCameraPosRot = setCameraPosRot
M.setFreeCameraTransformJson = setFreeCameraTransformJson
M.onSettingsChanged = onSettingsChanged

return M
