-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Offers various functions geared at demonstrating BeamNG.tech capabilities
-- To be used in conjunction with techDemo.json actions


local M = {}
M.dependencies = { "core_camera", "tech_license", "tech_sensors" }

local function isLevelValid()
  return M.level == "italy" or M.level == "east_coast_usa" or M.level == "smallgrid" or M.level == "gridmap"
end

local updateUINextRefresh = 0
local function updateUI(message, permanent)
  updateUINextRefresh = permanent and 0.5 or 5
  ui_message(message, 5, "Tech", "forward")
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if not tech_license.isValid(path) then return end
  if M.relativeCamCountdown then
    M.relativeCamCountdown = M.relativeCamCountdown - 1
    if M.relativeCamCountdown < 0 then
      local vid = be:getPlayerVehicleID(0)
      core_camera.setOffset(vid, M.relativeCamData.offset)
      core_camera.setRotation(vid, M.relativeCamData.rotation)
      core_camera.setFOV(vid, M.relativeCamData.fov)
      M.relativeCamCountdown = nil
    end
  end
  updateUINextRefresh = updateUINextRefresh - dtReal
  if updateUINextRefresh < 0 then
    if M.lidar then
      updateUI('<h2>LIDAR sensor: ON</h2>', true)
    elseif M.annotations then
      updateUI('<h2>Annotations: ON</h2>', true)
    elseif M.ultrasonic then
      updateUI('<h2>Ultrasonic sensors: ON</h2>', true)
    else
      updateUI('', true)
    end
  end
end


local function toggleLidar()
  updateUI('<h2>Toggling LIDAR</h2>')
  if M.lidar then
    tech_sensors.removeSensor(M.lidar)
    M.lidar = nil
    if core_camera.getActiveCamName() == "relative" then
      core_camera.setByName(0, M.prevCamName, true)
      core_camera.resetCamera(0)
    end
    M.prevCamName = nil
    updateUI('<h2>LIDAR sensor: OFF</h2>')
  else
    if M.ultrasonic then M.toggleUltrasonic() end
    if M.annotations then M.toggleAnnotations() end

    local veh = be:getPlayerVehicle(0)
    if not veh then
      updateUI('<h2>LIDAR sensor: <span style="color: red">vehicle needed</span></h2>')
      return
    end

    local vid = be:getPlayerVehicleID(0)
    local driverNodePos = veh:getNodePosition(core_camera.getDriverDataById(vid))
    local args = {}
    args.pos = vec3(0, driverNodePos.y, 3.0) -- TODO x=0 is NOT the centerline of the vehicle
    M.lidar = tech_sensors.createLidar(vid, args)
    M.prevCamName = core_camera.getActiveCamName()
    M.prevCamName = M.prevCamName == "relative" and "orbit" or M.prevCamName
    core_camera.setByName(0, 'relative', true)
    M.relativeCamData = {
      offset=vec3(-3,-10,10),
      rotation=vec3(20, 135, 0),
      fov = 80
    }
    M.relativeCamCountdown = 2
    updateUI('<h2>LIDAR sensor: ON</h2>', true)
  end
end

local function toggleAnnotations()
  updateUI('<h2>Toggling annotations</h2>')
  if not isLevelValid() then
    updateUI('<h2>Annotations: <span style="color: red">unavailable here<n/span></h2>')
    return
  end

  toggleAnnotationVisualize("")

  M.annotations = getConsoleVariable("$AnnotationVisualizeVar") == "1"
  if M.annotations then
    if M.ultrasonic then M.toggleUltrasonic() end
    if M.lidar then M.toggleLidar() end
    updateUI('<h2>Annotations: ON</h2>', true)
  else
    updateUI('<h2>Annotations: OFF</h2>')
  end
end

local function toggleUltrasonic()
  updateUI('<h2>Toggling ultrasonic sensors</h2>')
  if M.ultrasonic then
    local veh = be:getPlayerVehicle(0)
    if not veh then
      updateUI('<h2>Ultrasonic sensors: <span style="color: red">please enter a vehicle</span></h2>')
      return
    end

    veh:setMeshAlpha(1, "", false)
    for _,us in ipairs(M.ultrasonic) do
      tech_sensors.removeSensor(us)
    end
    M.ultrasonic = nil
    if core_camera.getActiveCamName() == "relative" then
      core_camera.setByName(0, M.prevCamName, true)
      core_camera.resetCamera(0)
    end
    M.prevCamName = nil
    updateUI('<h2>Ultrasonic sensors: OFF</h2>')
  else
    if M.lidar then M.toggleLidar() end
    if M.annotations then M.toggleAnnotations() end

    local veh = be:getPlayerVehicle(0)
    if not veh then
      updateUI('<h2>Ultrasonic sensors: <span style="color: red">vehicle needed</span></h2>')
      return
    end

    local vid = be:getPlayerVehicleID(0)
    veh:setMeshAlpha(0.5, "", false)
    local sizeX, sizeY = 200, 200
    local fovX, fovY = 0.15, 0.15
    local nearPlane, farPlane = 0.1, 10.15
    local range_roundness, range_cutoff_sensitivity, range_shape, range_focus, range_min_cutoff, range_direct_max_cutoff = -1.15, 0.0, 0.3, 0.376, 0.1, 5.0
    local sensitivity, fixedWindowSize = 3, 10
    M.ultrasonic = {}
    local z = 0.3
    for _,x in ipairs({-3, 3}) do -- sideways
      for _,y in ipairs({-3, 3}) do -- longitudinally
        local posRef = vec3(0, fsign(y)*(math.abs(y)-1.5), z)
        local args = {}
        args.pos = vec3(x, y, z)
        args.dir = (args.pos - posRef):z0()
        local us = tech_sensors.createUltrasonic(vid, args)
        table.insert(M.ultrasonic, us)
      end
    end
    updateUI('<h2>Ultrasonic sensors: ON</h2>', true)
  end
end

local function disableAll()
  if M.lidar then toggleLidar() end
  if getConsoleVariable("$AnnotationVisualizeVar") == "1" then toggleAnnotations() end
  if M.ultrasonic then toggleUltrasonic() end
end

local function onLevel(levelPath)
  disableAll()
  if levelPath == "" then
    M.level = levelPath
  else
    local _,level,_ = path.split(path.split(levelPath):sub(1, -2))
    M.level = level
  end
end

local function onClientEndMission()
  disableAll()
  M.level = nil
end

local function onVehicleSpawned(vid, veh)
  if vid ~= be:getPlayerVehicleID(0) then return end
  if M.lidar then
    toggleLidar()
    toggleLidar()
  end
  if M.ultrasonic then
    toggleUltrasonic()
    toggleUltrasonic()
  end
end

local function onVehicleDestroyed(vid)
  if vid ~= be:getPlayerVehicleID(0) then return end
  if M.lidar then toggleLidar() end
  if M.ultrasonic then toggleUltrasonic() end
end

local function onVehicleReplaced(vid, veh)
  if vid ~= be:getPlayerVehicleID(0) then return end
  if M.lidar then
    toggleLidar()
    toggleLidar()
  end
  if M.ultrasonic then
    toggleUltrasonic()
    toggleUltrasonic()
  end
end

local function onExtensionLoaded()
  onLevel(getMissionFilename())
end


M.onDeserialize = true
M.onUpdate = onUpdate
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleDestroyed = onVehicleDestroyed
M.onVehicleReplaced = onVehicleReplaced
M.onExtensionLoaded = onExtensionLoaded

M.onClientPreStartMission = onLevel
M.onClientPostStartMission = onLevel
M.onClientStartMission = onLevel
M.onClientEndMission = onClientEndMission

M.toggleLidar = toggleLidar
M.toggleAnnotations = toggleAnnotations
M.toggleUltrasonic = toggleUltrasonic

return M
