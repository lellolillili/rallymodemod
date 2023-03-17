-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'core_vehicle_manager'}

local multicams = { "onboard" }
local lastVehicleName = nil -- used to detect vehicle switches.
local pendingTrigger = nil
local requestedCam = {}   -- {name=foo, customData=bar}
local configuration = {}  -- {   {name=foo, enabled=true},  {name=bar, enabled=false},    ...      }
local currentVersion = 1
local activeGlobalCameraName

M.speedFactor = 1 -- used to fix too smooth and slow camera movement when creating thumbnails

-- returns the data for all vehicle cameras, with this structure:
--   { vid1={focusedCamName=orbit, cameras={orbit=C, ...}},
--     vid2={focusedCamName=driver, cameras={orbit=C, ...}},
--     vid3={focusedCamName=orbit, cameras={orbit=C, ...}} }
local vehicleCamerasCache

local resPos, resTargetPos, resRot = vec3(), vec3(), quat()

local camData = { veh = 0, vid = 0, dtSim = 0.0001, dtReal = 0.0001, dtRaw = 0.0001, dt = 0.0001, speed = 0, pos=vec3(), prevPos=vec3(), vel=vec3(), prevVel=vec3(), res = {pos = resPos, targetPos = resTargetPos, rot = resRot, fov = 60} }

local function addVehicleData(vid, target)
  local vdata = target[vid] or {}
  local focusedCamNamePrevious = ((vehicleCamerasCache or {})[vid] or {}).focusedCamName
  M.processVehicleCameraConfigChanged(vid, vdata, focusedCamNamePrevious)
  target[vid] = vdata
end

local function getVehicleData()
  if not vehicleCamerasCache then
    local result = {}
    for i=0, be:getObjectCount()-1 do
      local vid = be:getObject(i):getId()
      addVehicleData(vid, result)
    end
    vehicleCamerasCache = result
  end
  return vehicleCamerasCache
end

local function delVehicleData(vid)
  getVehicleData()[vid] = nil
end

local function onVehicleSpawned(vid)
  addVehicleData(vid, getVehicleData())
end

local function onVehicleDestroyed(vid)
  delVehicleData(vid)
end

-- constructors for all camera types (cached)
local camDirectory = '/lua/ge/extensions/core/cameraModes'
local constructorsCache
local function getConstructors()
  if not constructorsCache then
    constructorsCache = {}
    for _,file in ipairs(FS:findFiles(camDirectory, "*.lua", 1, false, false)) do
      local _,camMode,_ = path.splitWithoutExt(file)
      constructorsCache[camMode] = require('core/cameraModes/' .. camMode)
    end
  end
  return constructorsCache
end

-- cameras that always exist once (even if no vehicle is spawned)
local globalCamerasCache
local function getGlobalCameras()
  if not globalCamerasCache then
    globalCamerasCache = {}
    for camName,constructor in pairs(getConstructors()) do
      local cam = constructor()
      if cam.isGlobal then
        globalCamerasCache[camName] = cam
      end
    end
  end
  return globalCamerasCache
end

-- cameras that always run (except when using the old C++ camera path, e.g. shift+c camera, some World Editor cameras, etc)
local runningCamsOrderCache
local function getRunningCamsOrder()
  if not runningCamsOrderCache then
    runningCamsOrderCache = {}
    for camName,cam in pairs(getGlobalCameras()) do
      if cam.runningOrder then
        table.insert(runningCamsOrderCache, {name=camName, cam=cam})
      end
    end
    table.sort(runningCamsOrderCache, function(a,b) return a.cam.runningOrder < b.cam.runningOrder end)
    log("D", "", "Running cameras order:")
    for i,v in ipairs(runningCamsOrderCache) do
      log("D", "", string.format(" #%i: order=%5.3f, name=%s", i, v.cam.runningOrder, v.name))
    end
  end
  return runningCamsOrderCache
end

-- gather data used by Options > Cameras and other code
local function getExtendedConfig(vdata)
  if p then p:add("ext begin") end
  local config = deepcopy(configuration)
  if p then p:add("ext deepcopied") end
  local slotId = 1
  for _, v in ipairs(config) do
    if p then p:add("ext it begin") end
    local visible = vdata.cameras[v.name] and not vdata.cameras[v.name].hidden
    if p then p:add("ext it visible 1") end
    v.hidden = not visible
    -- set the binding camera number (keys 1 to 9, for example)
    if p then p:add("ext it visible 2") end
    if visible then
      v.slotId = slotId
      slotId = slotId + 1
    end
    if p then p:add("ext it visible 3") end
  end
  if p then p:add("ext it end") end
  return config
end

local function getVdata(player)
  local veh = be:getPlayerVehicle(player)
  if not veh then return end
  return getVehicleData()[veh:getId()]
end

-- send data to Messages UI app
local function displayCameraNameUI(player)
  local vdata = getVdata(player)
  if not vdata then return end
  if not vdata.focusedCamName then return end
  ui_message({txt='ui.camera.switched', context={name='ui.camera.mode.' .. vdata.focusedCamName}}, 10, 'cameramode')
end

local function getCamIdFromName(camName)
  for id,config in ipairs(configuration) do
    if config.name == camName then
      return id
    end
  end
end
-- send configuration to Options > Cameras menu
local function updateOptionsUI(vdata)
  if p then p:add("ui options begin") end
  local config = getExtendedConfig(vdata)
  if p then p:add("ui options cfg") end
  guihooks.trigger('CameraConfigChanged', {cameraConfig=config, focusedCamName=vdata.focusedCamName})
  if p then p:add("ui options js") end
end

local function saveConfiguration(vdata)
  updateOptionsUI(vdata)
  settings.setValue('cameraConfig', jsonEncode({ version=currentVersion, data=configuration }))
end

-- send data to UI apps and other things
local function updateAppsUI(vdata, forcedCamName)
  if p then p:add("ui start") end
  local camName = forcedCamName or vdata.focusedCamName
  if not camName then return end
  if p then p:add("ui checked") end
  -- tell JS for hiding the apps in cockpit for example
  guihooks.trigger('onCameraNameChanged', {name = camName})
  if p then p:add("ui js") end
  extensions.hook('onCameraModeChanged', camName)
  if p then p:add("ui hook") end
  updateOptionsUI(vdata)
  if p then p:add("ui options") end
end

-- request/send data to Options > Cameras menu
local function requestConfig(forcedCamName)
  local vdata = getVdata(0)
  if not vdata then return nil end
  updateOptionsUI(vdata, forcedCamName)
end

local function clearInputs()
  MoveManager.rollRight = 0
  MoveManager.rollLeft = 0
  MoveManager.pitchUp = 0
  MoveManager.pitchDown = 0
  MoveManager.yawRight = 0
  MoveManager.yawLeft = 0
  MoveManager.zoomIn = 0
  MoveManager.zoomOut = 0
end

local function changeOrder (camId, offset)
  local vdata = getVdata(0)
  if not vdata then return end
  -- iterate through cameras, skipping hidden cams
  local newIdx = camId
  local n = #configuration
  for i = 1, n do
    newIdx = clamp(newIdx + offset, 1, n)
    if not configuration[newIdx].hidden then break end
  end
  if newIdx == camId then return end

  -- move camera to the calculated new index
  configuration[camId], configuration[newIdx] = configuration[newIdx], configuration[camId]

  -- update the focused camera too
  local focusedCamId = getCamIdFromName(vdata.focusedCamName)
  if focusedCamId == newIdx then
    vdata.focusedCamName = configuration[camId].name
  elseif focusedCamId == camId then
    vdata.focusedCamName = configuration[newIdx].name
  end

  saveConfiguration(vdata)
end

local function toggleEnabledCameraById(camId)
  if camId > #configuration then return end
  if camId < 1 then return end
  local vdata = getVdata(0)
  if not vdata then return end
  configuration[camId].enabled = not configuration[camId].enabled
  saveConfiguration(vdata)
end

local function setGlobalCameraByName(name, withTransition, customData)
  -- process old cam
  local c = getGlobalCameras()[activeGlobalCameraName]
  if c and type(c.onCameraChanged) == 'function' then c:onCameraChanged(false) end
  -- process new cam
  activeGlobalCameraName = name
  local c = getGlobalCameras()[activeGlobalCameraName]
  if c and c.setCustomData then c:setCustomData(customData) end
  if c and type(c.onCameraChanged) == 'function' then c:onCameraChanged(true) end
end

local function getConfigByName(camName)
  for i,config in ipairs(configuration) do
    if config.name == camName then
      return config
    end
  end
end

local function _setVehicleCameraByIndex(vdata, focusedCamId)
  -- if in a global camera, exit it
  -- we dont want to exit freecam here, because it should override vehicle cam in some cases
  if getGlobalCameras()[activeGlobalCameraName] then
    setGlobalCameraByName(nil)
  end

  -- satefy checks
  if focusedCamId > #configuration then focusedCamId = 1 end
  if focusedCamId < 1 then focusedCamId = 1 end
  if p then p:add("setby 1") end

  -- tell cameras about the focus change
  local success = false
  local camConfig = configuration[focusedCamId]
  if p then p:add("setby config begin") end
  if camConfig then
    local newCam = vdata.cameras[camConfig.name]
    if p then p:add("setby newc") end
    if newCam then
      newCam.focused = true
      if type(newCam.onCameraChanged) == 'function' then
        if p then p:add("setby func exists") end
        newCam:onCameraChanged(true)
        if p then p:add("setby func run") end
      end
      success = true
    end
  end
  if p then p:add("setby config end") end
  if success then
    if p then p:add("setby success begin") end
    log("D","", "Camera switched to "..dumps(camConfig.name))
    if p then p:add("setby success log") end
    local oldCam = vdata.cameras[vdata.focusedCamName]
    if p then p:add("setby success oc") end
    if oldCam then
      oldCam.focused = false
      if type(oldCam.onCameraChanged) == 'function' then
        if p then p:add("setby oldfunc exists") end
        oldCam:onCameraChanged(false)
        if p then p:add("setby oldfunc run") end
      end
    end
    if p then p:add("setby odlcam end") end

    -- set it actually. This is the only function that is allowed to change focusedCamName directly
    vdata.focusedCamName = configuration[focusedCamId].name
    if p then p:add("setby config focus") end
    clearInputs()
    if p then p:add("setby clear inputs") end
    updateAppsUI(vdata)
    if p then p:add("setby update ui") end
  else
    log("D","", "Camera not switched to anything")
  end
  return success
end

local function _setVehicleCameraByName(vdata, camName, withTransition)
  for camId, config in ipairs(configuration) do
    if config.name == camName then
      local success = _setVehicleCameraByIndex(vdata, camId)
      if withTransition then
        getGlobalCameras().transition:start()
      end
      return success
    end
  end
  log("E", "", "Vehicle camera "..dumps(camName).. " not found")
  return false
end

local function setVehicleCameraByName(player, name, withTransition, customData)
  local veh = be:getPlayerVehicle(player)
  if not veh then
    log("E", "", "Player #"..dumps(player).." is not seated in a vehicle")
    return false
  end

  local vid = veh:getId()
  local vdata = getVehicleData()[vid]
  if not vdata then
    -- store the request for when we get the data
    requestedCam[vid] = { name = name, customData = customData }
    return false
  end

  local res = _setVehicleCameraByName(vdata, name, withTransition, customData)
  if res and vdata.cameras[name].setCustomData then
    vdata.cameras[name]:setCustomData( customData )
  end
  return res
end

local function setVehicleCameraByNameWithId(vehId, name, withTransition, customData)
  if not vehId then return end
  local veh = scenetree.findObjectById(vehId)
  if not veh then
    log("E", "", "Player #"..dumps(player).." is not seated in a vehicle")
    return false
  end

  local vid = veh:getId()
  local vdata = getVehicleData()[vid]
  if not vdata then
    -- store the request for when we get the data
    requestedCam[vid] = { name = name, customData = customData }
    return false
  end

  local res = _setVehicleCameraByName(vdata, name, withTransition, customData)
  if res and vdata.cameras[name].setCustomData then
    vdata.cameras[name]:setCustomData( customData )
  end
  return res
end

local function set(camName, withTransition, customData, player)
  if player then
    setVehicleCameraByName(player, camName, withTransition, customData)
  else
    setGlobalCameraByName(camName, withTransition, customData)
  end
end

--TODO handle transition from global to vehicle camera and viceversa? wasFocused, .focus, and all of that?
--TODO or keep global cameras as overlay for vehicle cameras, all running at ocne?
local function setByName(...)
  local arg = {...}
  local player, camName, withTransition, customData
  if type(arg[1]) == "number" then
    player, camName, withTransition, customData = unpack(arg, 1, table.maxn(arg)) -- without arguments, unpack can stop at the first nil it encounters, cutting the row short
  else
    camName, withTransition, customData = unpack(arg, 1, table.maxn(arg)) -- without arguments, unpack can stop at the first nil it encounters, cutting the row short
  end
  local isGlobal = (camName == nil) or getGlobalCameras()[camName]
  if isGlobal then player = nil end
  set(camName, withTransition, customData, player)
end

local function isWithinRadius(cameraName, camPos, veh, vehPos, vdata, radius)
  if not vdata.cameras[cameraName] then return false end
  local cameraPos = veh:getNodePosition(vdata.cameras[cameraName].camNodeID)
  local nodePos = veh:getNodePosition(vdata.cameras[cameraName].camNodeID)
  nodePos:setAdd(vehPos)
  return nodePos:squaredDistance(camPos) < radius * radius
end

local function isUnicycle(vehId)
  return not activeGlobalCameraName and core_vehicle_manager and core_vehicle_manager.getPlayerVehicleData() and core_vehicle_manager.getVehicleData(vehId).mainPartName == "unicycle"
end

local function isCameraInside(player, camPos)
  local veh = be:getPlayerVehicle(player)
  if not veh then return false end
  local vehId = veh:getId()
  local vdata = getVehicleData()[vehId]
  if not vdata then return false end
  if isUnicycle(vehId) then return false end

  local oobb = veh:getSpawnWorldOOBB()
  if not oobb:isContained(camPos) then return false end

  local vehPos = veh:getPosition()
  return isWithinRadius("onboard.driver", camPos, veh, vehPos, vdata, 0.6) or isWithinRadius("onboard.rider", camPos, veh, vehPos, vdata, 0.6)
end

local function getCameraDataById(vid)
  local vehData = getVehicleData()[vid]
  if vehData then
    return vehData.cameras
  end
end

local function getDriverDataById(vehId)
  local camNodeID, rightHandDrive, rightHandDoor = nil, false, false
  local vdata = getVehicleData()[vehId]
  if not vdata         then return camNodeID, rightHandDrive, rightHandDoor end
  if not vdata.cameras then return camNodeID, rightHandDrive, rightHandDoor end
  local cam = vdata.cameras["onboard.driver"]
  if not cam           then return camNodeID, rightHandDrive, rightHandDoor end
  camNodeID, rightHandDrive, rightHandDoor = cam.camNodeID, cam.rightHandCamera or false, cam.rightHandDoor or false -- convert nil to false
  return camNodeID, rightHandDrive, rightHandDoor
end
local function getDriverData(veh)
  return getDriverDataById(veh and veh:getId())
end

local function getActiveCamName(player)
  if activeGlobalCameraName then return activeGlobalCameraName end
  local veh = be:getPlayerVehicle(player or 0)
  if not veh then return end -- no LUA camera is being used atm
  local camName
  local vid = veh:getId()
  if requestedCam[vid] then
    camName = requestedCam[vid].name
  else
    local vdata = getVehicleData()[vid]
    if vdata then
      camName = vdata.focusedCamName
    else
      log('W', '', 'Unable to find vdata for player '..tostring(player))
    end
  end
  return camName
end

local function getActiveCamNameByVehId(vehId)
  if not vehId then return end
  local veh = scenetree.findObjectById(vehId)
  if not veh then return end -- no LUA camera is being used atm
  local camName
  local vid = veh:getId()
  if requestedCam[vid] then
    camName = requestedCam[vid].name
  else
    local vdata = getVehicleData()[vid]
    if vdata then
      camName = vdata.focusedCamName
    else
      log('W', '', 'Unable to find vdata for player '..tostring(player))
    end
  end
  return camName
end

local function setBySlotId(player, slotId)
  local vdata = getVdata(player)
  if not vdata then return end
  local config = getExtendedConfig(vdata)
  for k,v in ipairs(config) do
    if v.slotId == slotId then
      -- if in freecamera, exit it
      if commands.isFreeCamera() then
        commands.setGameCamera()
      end
      _setVehicleCameraByIndex(vdata, k)
      displayCameraNameUI(player)
      saveConfiguration(vdata)
      return
    end
  end
end

local function initCam(camera, jbeamConfig, constructor)
  local jbeamConfig = deepcopy(jbeamConfig)
  if camera then
    camera.camBase = nil
    camera.defaultRotation = nil
    tableMergeRecursive(camera, jbeamConfig)
    if type(camera.onVehicleCameraConfigChanged) == 'function' then
      camera:onVehicleCameraConfigChanged()
    end
  else
    camera = constructor(jbeamConfig)
  end
  if camera.isFilter then return end
  if camera.isGlobal then return end
  camera.hidden = camera.hidden == true -- convert to boolean
  camera.focused = false -- make sure its set to inactive on start --TODO why track this here?
  return camera
end

-- TODO trigger this also for global cameras?
local function processVehicleCameraConfigChanged(vid, vdata, focusedCamNamePrevious)
  local camerasOld = vdata.cameras or {}
  vdata.cameras = {}
  local vmvd = extensions.core_vehicle_manager.getVehicleData(vid)
  if vmvd then
    vmvd = vmvd.vdata
  else
    return
  end

  local refNodes = vmvd.refNodes[0]
  local vmcd = vmvd.cameraData or {}
  local camConfigs = {}
  for camMode,constructor in pairs(getConstructors()) do
    if tableFindKey(multicams, camMode) then
      local jbeamConfigs = vmcd[camMode] or {}
      for i,jbeamConfig in pairs(jbeamConfigs) do
        table.insert(camConfigs, {name=camMode.."."..jbeamConfig.name, constructor=constructor, jbeamConfig=jbeamConfig})
      end
    else
      local jbeamConfig = vmcd[camMode] or {}
      table.insert(camConfigs, {name=camMode, constructor=constructor, jbeamConfig=jbeamConfig})
    end
  end
  for k,v in ipairs(camConfigs) do
    if v.name ~= "onboard.driver" and string.lower(v.name) == "onboard.driver" then
      log("W", "", "Possibly incorrect camera name '"..v.name.."' (rename to 'onboard.driver'?)")
    end
    local cam = initCam(camerasOld[v.name], v.jbeamConfig, v.constructor)
    if cam then
      if cam.setRefNodes then
        cam:setRefNodes(refNodes.ref, refNodes.left, refNodes.back)
      end
      vdata.cameras[v.name] = cam
    end
  end

  if not arrayFindValueIndex(tableKeys(vdata.cameras), "onboard.driver") then
    vdata.cameras.driver = nil -- there's no driver data to feed the driver cam, so remove it
  end

  -- initial camera config
  local initialConfiguration = {
     {name="orbit"}
    ,{name="driver"}
    ,{name="onboard.hood"}
    ,{name="external"}
    ,{name="relative"}
    ,{name="chase"}
  }
  local savedConfiguration = settings.getValue('cameraConfig')
  if savedConfiguration and savedConfiguration ~= "" then
    -- fix INI values that passed through javascript (e.g. when opening Options menu)
    savedConfiguration = savedConfiguration:gsub("'",'"')
    -- and then deserialize, so we can follow the user settings
    savedConfiguration = jsonDecode(savedConfiguration)
    -- if user settings version is good, go ahead and use it
    if savedConfiguration and (savedConfiguration.version or 0) >= currentVersion then
      initialConfiguration = savedConfiguration.data
    end
  end

  -- fill pre-configured cameras (even if it's a disabled/unknown camera)
  configuration = {}
  for k,v in ipairs(initialConfiguration) do
    local enabled = v.enabled
    if enabled == nil then
      enabled = true
      local cam = vdata.cameras[v.name]
      if cam then
        enabled = cam.disabledByDefault ~= true
      end
    end
    table.insert(configuration, {name=v.name, enabled=enabled})
  end

  -- append non-configured cameras
  local renaminingCamNames = {}
  for name, cam in pairs(vdata.cameras) do
    local configured = false
    for _,v in ipairs(configuration) do
      if v.name == name then configured = true end
    end
    if not configured then
      table.insert(renaminingCamNames, name)
    end
  end

  -- now, a bit more complex: order the remaining cameras with their order number (if present) or jbeam order
  while #renaminingCamNames > 0 do
    local orderMin = 99999
    local lowestOrderId = nil
    for k, name in ipairs(renaminingCamNames) do
      -- locate idx with the minimum order value
      local cam = vdata.cameras[name]
      if cam.order then
        if type(cam.order) == 'number' then
          if cam.order < orderMin then
            orderMin = cam.order
            lowestOrderId = k
          end
        else
          log("E", "", "Incorrectly defined camera, 'order' field is not numeric: "..dumps(type(order)))
        end
      end
    end

    if not lowestOrderId then
      -- no ordering? simply take first one then
      lowestOrderId = 1
    end

    local name = renaminingCamNames[lowestOrderId]
    local enabled = vdata.cameras[name].disabledByDefault ~= true
    table.insert(configuration, {name=name, enabled=enabled})
    table.remove(renaminingCamNames, lowestOrderId)
  end

  -- 1st try: we got a saved request, honour it before anything else
  local cameraSet = false
  if requestedCam[vid] then
    cameraSet = _setVehicleCameraByName(vdata, requestedCam[vid].name)
    if cameraSet and vdata.cameras[requestedCam[vid].name].setCustomData then
      vdata.cameras[requestedCam[vid].name]:setCustomData( requestedCam[vid].customData )
    end
    requestedCam[vid] = nil
  end

  -- 2nd try: let's continue using the previous cam (which may have disappeared if we replaced the vehicle)
  if not cameraSet and focusedCamNamePrevious then
    cameraSet = _setVehicleCameraByName(vdata, focusedCamNamePrevious)
  end

  -- 3rd try: let's find the first 'enabled' camera and use it (i.e. the default camera)
  if not cameraSet then
    for k,v in pairs(configuration) do
      if v.enabled and vdata.cameras[v.name] and not vdata.cameras[v.name].hidden then
        cameraSet = _setVehicleCameraByIndex(vdata, k)
        if cameraSet then break end
      end
    end
  end

  -- 4th try: let's find the first 'visible' camera and use it
  if not cameraSet then
    for k,v in pairs(configuration) do
      if vdata.cameras[v.name] then
        cameraSet = _setVehicleCameraByIndex(vdata, k)
        if cameraSet then break end
      end
    end
  end

  -- 5th try: panic and don't keep calm
  if not cameraSet then
    log("E", "", "Unable to find a single usable camera, not even 'orbit' fallback. All bets are off from this point on")
  end

  saveConfiguration(vdata)
end
M.processVehicleCameraConfigChanged = processVehicleCameraConfigChanged

local function vehicleChanged(oldVehId, newVehId)
  if oldVehId then
    -- disable all cameras
    local vdata = getVehicleData()[oldVehId]
    if vdata then
      for camName, camera in pairs(vdata.cameras) do
        camera.wasFocused = vdata.focusedCamName == camName
        camera.focused = false
        if camera.wasFocused then
          if type(camera.onCameraChanged) == 'function' then
            camera:onCameraChanged(camera.focused)
          end
        end
      end
    end
  end

  if newVehId then
    -- enable previously disabled cameras
    local vdata = getVehicleData()[newVehId]
    if vdata then
      for _, camera in pairs(vdata.cameras) do
        if camera.wasFocused == true then
          camera.focused = true
          if type(camera.onCameraChanged) == 'function' then
            camera:onCameraChanged(camera.focused)
          end
        end
        camera.wasFocused = nil
      end
      updateAppsUI(vdata)
    end
  end
end


-- Provides high-quality near shadows when using interior camera, by adjusting the logWeight parameter of the shadows
local lastLogWeight
local isCameraInsidePrevious = false
local function setShadowLogWeight(veh)
  lastLogWeight = lastLogWeight or core_environment.getShadowLogWeight() -- initialize LogWeight value from the level

  -- Check the camera position, and sets the shadow's logWeight accordingly
  if not veh then return false end

  local vehId = veh:getId()
  if isUnicycle(vehId) then return false end
  local camPos = getCameraPosition()
  local vdata = getVehicleData()[vehId]
  if not vdata then return false end

  local vehPos = camData.pos
  local isCameraInsideNow = isWithinRadius("onboard.driver", camPos, veh, vehPos, vdata, 0.6) or isWithinRadius("onboard.rider", camPos, veh, vehPos, vdata, 0.6)
  local updateShadowLogWeight = (isCameraInsideNow ~= isCameraInsidePrevious)
  if updateShadowLogWeight and not freeroam_bigMapMode.bigMapActive() then
    local oobb = veh:getSpawnWorldOOBB()
    local inside = (isCameraInsideNow and oobb:isContained(camPos))
    core_environment.setShadowLogWeight( (inside and 0.996) or lastLogWeight )
    scenetree.SSAOPostFx:setRadiusTarget((inside and 0.5) or 1.5)
  end
  isCameraInsidePrevious = isCameraInsideNow
end

-- level-defined nearClip handling
local levelNearClip
local function getLevelNearClip()
  if levelNearClip == nil then
    if not TorqueScriptLua.getBoolVar("$loadingLevel") then
      levelNearClip = scenetree.theLevelInfo and scenetree.theLevelInfo.nearClip
      levelNearClip = levelNearClip or false -- disables re-checking if the map has no nearclip
    end
  end
  return levelNearClip
end

local function onClientPostStartMission()
  levelNearClip = nil
  lastLogWeight = nil
  isCameraInsidePrevious = false
end

-- figure out if an object has teleported, by analyzing its position and speed
-- e.g. a car that has moved 2 meters in a single frame via the insert-recovery key has been teleported
--      but a space rocket hurtling through the solar system, that has moved 5kms in the last frame, is not a teleport
local function objectTeleported(curPos, prevPos, prevVel, dt)
  -- if we have no previous data, assume this was a teleport event
  -- e.g. the object just got spawned from nowhere into existence, we interpret that as a teleport
  if not curPos or not prevPos then return true end

  -- if the object barely moved, assume it was not a teleport event
  -- e.g. when changing vehicle parts, the car will respawn "in-place"; normally a few cms or dms away. we interpret that as NOT a teleporting event
  -- e.g. we use insert-key recovery. the vehicle gets smartly placed 0.5m away to avoid spawning through a tree. this is also NOT a teleport. but if Smart recovery moves it 5 meters, then that's a teleport event
  -- e.g. a plane travelling mach 1 gets 'recovered' in place (insert key), this is also not a teleporting event
  -- if the object travels slow enough, assume it was not a teleport event
  -- e.g. if the object didn't even reaching mach 1, assume it's unlikely to have been a teleport
  -- more complex example: during a teleport, velocities might look like [10, 10, 10, 50000, 0, 0, 0]. there are two clear spikes in acceleration - two potential teleport events. however, the second potential teleport will get ignored with this check
  local teleportDist = 277 * dt
  if prevPos:distance(curPos) < math.max(1.5, teleportDist) then return false end -- in m/s, threshold to detect teleport with F7 / recovery / reset / replay seeking

  -- if the object velocity is consistent (such as, consistently extreme), assume this was not a teleport
  -- e.g. a concorde is flying at mach 2 speed. every frame might look like a teleport, but that's just a normal day of 90s transatlantic travel for bill gates
  return ((curPos - prevPos) / dt):distance(prevVel) > teleportDist
end

local validData
local lastValidData = { rot=60, pos=vec3(), rot=quat() } -- protect against getting NaNs on the very first frame
-- guard against sending NaN and inf to C++, which will put it in an unrecoverable state

local function validateData(data)
  local valid = not(isnaninf(data.res.fov + data.res.pos:squaredLength()) or isnaninf(data.res.rot:squaredNorm()))
  if valid then
    -- all is ok, let's save this data for render
    lastValidData.fov = data.res.fov
    lastValidData.pos:set(data.res.pos)
    lastValidData.rot:set(data.res.rot)
  else
    if validData ~= valid then
      log("E", "", "Invalid camera calculations detected (should only happen after a vehicle instability)")
      log("D", "", "Attempting to fix invalid camera data: "..dumps(data))
    end
    data.res.fov = lastValidData.fov
    data.res.pos:set(lastValidData.pos)
    data.res.rot:set(lastValidData.rot)
  end
  validData = valid
  return valid
end

local lastNotifiedFov
local function onPreRender(dtReal, dtSim, dtRaw)
  if not levelLoaded then return end
  local player = 0
  local veh = be:getPlayerVehicle(player)
  local vid = veh and veh:getId()

  -- fixup res if a reference in it has been altered
  resPos:set(camData.pos)
  resTargetPos:set(0, 0, 0)
  resRot:set(1,0,0,0)
  camData.res.pos = resPos
  camData.res.targetPos = resTargetPos
  camData.res.rot = resRot

  camData.veh = veh
  camData.vid = vid
  camData.dtSim = dtSim * M.speedFactor-- smoothed dt used by physics, includes time scaling
  camData.dtReal = dtReal * M.speedFactor -- smoothed gfx render dt
  camData.dtRaw = dtRaw  * M.speedFactor -- gfx render dt, in seconds from wall clock
  camData.dt = camData.dtReal * M.speedFactor
  camData.prevPos:set(camData.pos)
  camData.pos:set(veh and veh:getPosition() or vec3()) -- vehicle position
  local paused = dtSim < 0.00001
  if not paused then
    camData.prevVel:set(camData.vel)
    camData.vel:set(camData.pos)
    camData.vel:setSub(camData.prevPos)
    camData.vel:setScaled(1/dtSim)
    camData.teleported = objectTeleported(camData.pos, camData.prevPos, camData.prevVel, dtSim)
    if camData.teleported then
      camData.vel:set(0,0,0)
    end
  else
    camData.teleported = false
  end

  if veh then setShadowLogWeight(veh) end -- First instance

  if commands.isFreeCamera() then
    camData.res.pos:set(getCameraPosition())
    -- free camera fov
    local input = MoveManager.zoomIn - MoveManager.zoomOut
    if input ~= 0 then
      local currFov = getCameraFovDeg()
      local extraFov = 4.5 * dtReal * M.speedFactor * input * currFov
      local fov = clamp(currFov + extraFov, 10, 120)
      local mustNotifyFov = round(fov*10) ~= round((lastNotifiedFov or currFov) * 10)
      if mustNotifyFov then
        lastNotifiedFov = fov
        ui_message({txt='ui.camera.fov', context={degrees=fov}}, 2, 'cameramode')
      end
      setCameraFovDeg(fov)
    end
    return
  end -- check for freecam *after* we make sure we got vehicle config data, which may be used on updatedSettings callbacks and other stuff

  if veh then
    local vehicleName = veh:getField('name', '')
    if vehicleName ~= lastVehicleName then
      local lastVehicle = lastVehicleName and scenetree.findObject(lastVehicleName) or nil
      local lastVehicleId = lastVehicle and lastVehicle:getId() or nil
      vehicleChanged(lastVehicleId, vid)
      lastVehicleName = vehicleName
    end
  end

  if not configuration then return end

  camData.speed = tonumber(getConsoleVariable('$Camera::movementSpeed'))
  camData.res.targetPos:set(camData.pos)   -- tracked target
  camData.res.fov = 60
  camData.res.nearClip = getLevelNearClip() or 0.1 -- choose a sane default if the level hasn't defined a nearclip

  -- update the selected camera
  local globalCam = getGlobalCameras()[activeGlobalCameraName]
  if globalCam then
    -- one of the global cameras
    if not globalCam:update(camData) then
      setGlobalCameraByName(nil)
    else
      extensions.hook("onCameraPreRender", camData)
    end
  else
    -- one of the vehicle cameras
    local vdata = getVehicleData()[vid]
    if vdata then
      local plvdata = core_vehicle_manager.getPlayerVehicleData()
      local isUnicycle = plvdata and plvdata.mainPartName == "unicycle"
      local camName = (isUnicycle and vdata.focusedCamName ~= "path") and "unicycle" or vdata.focusedCamName
      local cam = vdata.cameras[camName]
      if cam then
        cam:update(camData)
        if not validateData(camData) and cam.init then cam:init() end -- if present, clean up NaN/infs in camera state, by re-initting it
      else
        local fallbackCamName = "orbit"
        local fallbackCam = vdata.cameras[fallbackCamName]
        if fallbackCam then
          log("E", "", "Vehicle cam "..dumps(vdata.focusedCamName).." not found. Falling back to "..dumps(fallbackCamName))
          setByName(0, fallbackCamName)
        else
          log("E", "", "Vehicle cam "..dumps(vdata.focusedCamName).." not found. Fallback cam "..dumps(fallbackCamName).." not found either. Falling back to free camera")
          commands.setFreeCamera()
        end
        return
      end
      camData.dt = camData.dtReal -- revert back to gfx dt, in case one filter switched it
    else
      --log("E", "", "No global cam used, and no vehicle exists either")
      return
    end
  end

  -- running cameras
  for _,v in ipairs(getRunningCamsOrder()) do
    v.cam:update(camData)
  end

  MoveManager.yawRelative = 0
  MoveManager.pitchRelative = 0
  MoveManager.rollRelative = 0
end

local profiler = LuaProfiler("Camera")
local p
local profilerEnabled
M.profile = function(enabled)
  profilerEnabled = enabled
end

local function setVehicleCameraByIndexOffset(player, offset)
  if profilerEnabled then p = profiler end
  if p then p:start() end

  -- if we're in freecamera or a global camera, just switch back regular game camera, whichever that was
  local isFreeCamera = commands.isFreeCamera()
  local isGlobalCamera = getGlobalCameras()[activeGlobalCameraName]
  if isFreeCamera or isGlobalCamera then
    if p then p:add("nongame check") end
    if isFreeCamera then
      commands.setGameCamera()
    end
    if isGlobalCamera then
      setGlobalCameraByName(nil)
    end
    if p then p:add("set gamecam") end
    displayCameraNameUI(player)
    if p then p:add("display 1") end
    if p then p:finish(true) end
    return
  end

  local vdata = getVdata(player)
  if p then p:add("getvdata") end
  if not vdata then return end

  -- this loop is supposed to skip over hidden/disabled cameras
  local focusedCamId = getCamIdFromName(vdata.focusedCamName)
  if p then p:add("getcamid") end
  for i = 1, #configuration do
    if p then p:add("config it begin") end
    focusedCamId = focusedCamId + offset
    if p then p:add("config it 1") end
    if focusedCamId > #configuration then focusedCamId = 1 end
    if p then p:add("config it 2") end
    if focusedCamId < 1 then focusedCamId = #configuration end
    if p then p:add("config it 3") end
    local m = configuration[focusedCamId]
    if p then p:add("config it 4") end
    local enabled = m.enabled
    if p then p:add("config it 5") end
    local visible = vdata.cameras[m.name] and not vdata.cameras[m.name].hidden
    if p then p:add("config it 6") end
    if visible and enabled then break end
    if p then p:add("config it 7") end
  end
  if p then p:add("config it end") end

  _setVehicleCameraByIndex(vdata, focusedCamId)
  if p then p:add("set by index") end
  displayCameraNameUI(player)
  if p then p:add("display name 2") end
  getGlobalCameras().transition:start()
  if p then p:add("transition") end
  if p then p:finish(true) end
  if profilerEnabled then p = nil end
end

local function proxy_VID(vid, fct, ...)
  local vdata = getVehicleData()[vid]
  if not vdata then return end

  local c = vdata.cameras[vdata.focusedCamName]
  if c and type(c[fct]) == 'function' then
    return c[fct](c, ...) -- c = self
  end
end

local function proxy_PID(player, fct, ...)
  local globalCam = getGlobalCameras()[activeGlobalCameraName]
  if globalCam then
    if globalCam[fct] then
      return globalCam[fct](globalCam, ...)
    end
  else
    local vid = be:getPlayerVehicleID(player)
    if vid < 0 then return end -- player is not seated in any vehicle at the moment
    return proxy_VID(vid, fct, ...)
  end
end

--- VID

local function resetCameraByID(vid, ...)
  return proxy_VID(vid, 'reset', ...)
end

local function setRotation(vid, ...)
  return proxy_VID(vid, 'setRotation', ...)
end

local function setFOV(vid, ...)
  return proxy_VID(vid, 'setFOV', ...)
end

local function setOffset(vid, ...)
  return proxy_VID(vid, 'setOffset', ...)
end

local function setup(vid, ...)
  return proxy_VID(vid, 'setup', ...)
end

local function setRefNodes(vid, ...)
  return proxy_VID(vid, 'setRefNodes', ...)
end

local function setRef(vid, ...)
  return proxy_VID(vid, 'setRef', ...)
end

local function setTargetMode(vid, ...)
  return proxy_VID(vid, 'setTargetMode', ...)
end

local function setDefaultDistance(vid, ...)
  return proxy_VID(vid, 'setDefaultDistance', ...)
end

local function setDistance(vid, ...)
  return proxy_VID(vid, 'setDistance', ...)
end

local function setMaxDistance(vid, ...)
  return proxy_VID(vid, 'setMaxDistance', ...)
end

local function setDefaultRotation(vid, ...)
  return proxy_VID(vid, 'setDefaultRotation', ...)
end

local function setSkipFovModifier(vid, ...)
  return proxy_VID(vid, 'setSkipFovModifier', ...)
end
--- PID

local function globalCameraFunction(globalCameraName, functionName, ...)
  local cam = getGlobalCameras()[globalCameraName]
  if not cam then
    log("E", "", "Camera "..dumps(globalCameraName).." not found, cannot call its "..dumps(functionName).." function")
    return
  end
  if not cam[functionName] then
    log("E", "", "Camera "..dumps(globalCameraName).." function "..dumps(functionName).." is invalid, cannot call it")
    return
  end
  return cam[functionName](cam, ...)
end

local function proxy_Player(fct, ...)
  local player = 0
  return proxy_PID(player, fct, ...)
end

local function onTrigger(trigger)
  if not trigger or not trigger.subjectID then return end

  local player = 0
  local vid = be:getPlayerVehicleID(player)
  local otherId = nil
  local triggerTargetOverride = nil
  if trigger.triggerOverride then
    local overrideObj = scenetree.findObject(trigger.triggerOverride)
    if overrideObj then
      otherId = overrideObj:getId()
    end
    if otherId == trigger.subjectID then
      triggerTargetOverride = trigger.triggerOverride
    end
  end

  if vid < 0 and not otherId then return end

  if not commands.isFreeCamera() then
    -- TODO FIXME: this spams the whole UI, needs to be a stream
    --guihooks.trigger('cameraDistance', {state = 'notfree'}) -- TODO: convert into stream
  end

  if trigger.subjectID ~= vid and trigger.subjectID ~= otherId then return end

  local triggeredDuringSpawning = false
  local scenario = scenario_scenarios and scenario_scenarios.getScenario()
  if scenario and (scenario.state == nil or (scenario.state == 'pre-start' or scenario.state == 'restart')) then
    triggeredDuringSpawning = true
  end

  if getActiveCamName() == 'path' or triggeredDuringSpawning then
    if type(trigger.cameraOnEnter) == 'string' and trigger.cameraOnEnter ~= "" then
      local cam = scenetree.findObject(trigger.cameraOnEnter)
      if cam.showApps ~= '1' then
        guihooks.trigger('appContainer:loadLayoutByType', "scenario_cinematic_start")
      end
      pendingTrigger = trigger
      return
    end
  end

  local vehicle = be:getObjectByID(vid)
  if trigger.event == 'exit' and trigger.cameraOnLeave == true then
    setGlobalCameraByName(nil)
    local vdata = getVehicleData()[vid]
    if vdata then
      updateAppsUI(vdata)
    end
  elseif trigger.event == 'enter' and type(trigger.cameraOnEnter) == 'string' and trigger.cameraOnEnter ~= "" then
    local cam = scenetree.findObject(trigger.cameraOnEnter)
    if cam then
      --getGlobalCameras().observer:setCamera(cam, triggerTargetOverride or cam.targetOverride)
      setGlobalCameraByName("observer", nil, {cam = cam, triggerTargetOverride = triggerTargetOverride or cam.targetOverrid})
    else
      log('E', 'camera', 'camera not found for trigger: ' .. dumps(trigger.cameraOnEnter))
    end
  end
end

local function resetCamera(player)
  clearInputs()
  if commands.isFreeCamera() then
    setCameraFovDeg(65)
  else
    return proxy_PID(player, 'reset')
  end
end

local function lookBack(player, value)
  return proxy_PID(player, 'lookback', value)
end

local function hotkey(player, hotkeyid, modifier)
  return proxy_PID(player, 'hotkey', hotkeyid, modifier)
end

local lastFilter = FILTER_KBD
local function getLastFilter() return lastFilter end

local lastRotatedTime = 0
local function rotatedCamera()
  lastRotatedTime = Engine.Platform.getSystemTimeMS()
end

local function timeSinceLastRotation()
  return Engine.Platform.getSystemTimeMS() - lastRotatedTime
end

local function rotate_yaw_left (val, filter)
  MoveManager.yawLeft = val
  lastFilter = filter
  rotatedCamera()
end

local function rotate_yaw_right(val, filter)
  MoveManager.yawRight = val
  lastFilter = filter
  rotatedCamera()
end

local function rotate_yaw(val, filter)
  lastFilter = filter
  if val > 0 then
    MoveManager.yawRight = val;
    MoveManager.yawLeft = 0;
  else
    MoveManager.yawLeft = -val;
    MoveManager.yawRight = 0;
  end
  rotatedCamera()
end

local function rotate_pitch_up(val, filter)
  MoveManager.pitchUp = val
  lastFilter = filter
  rotatedCamera()
end

local function rotate_pitch_down(val, filter)
  MoveManager.pitchDown = val
  lastFilter = filter
  rotatedCamera()
end

local function rotate_pitch(val, filter)
  lastFilter = filter
  if val > 0 then
    MoveManager.pitchUp = val
    MoveManager.pitchDown = 0
  else
    MoveManager.pitchDown = -val
    MoveManager.pitchUp = 0
  end
  rotatedCamera()
end

local function moveForwardBackward(val)
  if val > 0 then
    MoveManager.forward = val
    MoveManager.backward = 0
  else
    MoveManager.forward = 0
    MoveManager.backward = -val
  end
end

local function moveLeftRight(val)
  if val > 0 then
    MoveManager.right = val
    MoveManager.left = 0
  else
    MoveManager.right = 0
    MoveManager.left = -val
  end
end

local function cameraZoom(val)
  if val > 0 then
    MoveManager.zoomIn = val
    MoveManager.zoomOut = 0
  else
    MoveManager.zoomIn = 0
    MoveManager.zoomOut = -val
  end
end

-- rmb mouse camera
local function rotate_yaw_relative(val)
  MoveManager.yawRelative = MoveManager.yawRelative + getCameraFovDeg() * val / 4500
  rotatedCamera()
end
local function rotate_pitch_relative(val)
  MoveManager.pitchRelative = MoveManager.pitchRelative + getCameraFovDeg() * val / 4500
  rotatedCamera()
end
-- Movement Keys
local function moveleft    (val) MoveManager.left     = val end
local function moveright   (val) MoveManager.right    = val end
local function moveforward (val) MoveManager.forward  = val end
local function movebackward(val) MoveManager.backward = val end
local function moveup      (val) MoveManager.up       = val end
local function movedown    (val) MoveManager.down     = val end

-- 3d spacemouse support :)
local absRotateAxisFactor= 0.0005
local yawTemp   = 0
local rollTemp  = 0
local pitchTemp = 0
local function   yawAbs(val) MoveManager.yawRelative   = (  yawTemp - val) * absRotateAxisFactor;   yawTemp = val end
local function  rollAbs(val) MoveManager.rollRelative  = ( rollTemp - val) * absRotateAxisFactor;  rollTemp = val end
local function pitchAbs(val) MoveManager.pitchRelative = (pitchTemp - val) * absRotateAxisFactor; pitchTemp = val end
local absTranslateAxisFactor = 0.02
local xAxisAbsTemp = 0
local yAxisAbsTemp = 0
local zAxisAbsTemp = 0
local function xAxisAbs(val) local tmp = (xAxisAbsTemp - val) * absTranslateAxisFactor; MoveManager.absXAxis = tmp; xAxisAbsTemp = val end
local function yAxisAbs(val) local tmp = (yAxisAbsTemp - val) * absTranslateAxisFactor; MoveManager.absYAxis = tmp; yAxisAbsTemp = val end
local function zAxisAbs(val) local tmp = (zAxisAbsTemp - val) * absTranslateAxisFactor; MoveManager.absZAxis = tmp; zAxisAbsTemp = val end

-- PID end

local function onVehicleResetted(vid, ...)
  local vdata = getVehicleData()[vid]
  if not vdata then return end
  local c = vdata.cameras[vdata.focusedCamName]
  if not c then return end
  local resetCamOnVehicleReset = c.resetCameraOnVehicleReset ~= false

  if resetCamOnVehicleReset then
    resetCameraByID(vid, ...)
  end
end

local function onMouseLocked(locked)
  local player = 0
  if commands.isFreeCamera() then return end
  return proxy_PID(player, 'mouseLocked', locked)
end

local function onDespawnObject(vid, isReloading)
  if isReloading == false then
    delVehicleData(vid)
  end
end

-- run the desired function on all cameras
local function proxy_all(functionName, ...)
  for vid, vdata in pairs(getVehicleData()) do
    for _, cam in pairs(vdata.cameras) do
      if cam[functionName] then
        cam[functionName](cam, ...)
      end
    end
  end
  for _,cam in pairs(getGlobalCameras()) do
    if cam[functionName] then
      cam[functionName](cam, ...)
    end
  end
end

local function onSettingsChanged(...)
  proxy_all("onSettingsChanged", ...)
end

local function resetConfiguration()
  settings.setValue('cameraConfig', "")
  for vid, vdata in pairs(getVehicleData()) do
    processVehicleCameraConfigChanged(vid, vdata, vdata.focusedCamName)
  end
end

local function onScenarioRestarted(...)
  proxy_all("onScenarioRestarted", ...)
end

local function onScenarioChange(...)
  proxy_all("onScenarioChange", ...)
  local arg = {...}
  local scenario = arg[1]
  if pendingTrigger and scenario and scenario.state == 'running' then
    log('I', 'camera', 'onScenarioChange processing pendingTrigger...')
    local tempTrigger = deepcopy(pendingTrigger)
    pendingTrigger = nil
    onTrigger(tempTrigger)
  end
end

local function onVehicleSwitched(...)
  getGlobalCameras().transition:start(true)
  proxy_all("onVehicleSwitched", ...)
end

local function onSerialize()
  -- Revert log weight to levels' normal log weight instead of keeping the in-vehicle one
  if lastLogWeight and isCameraInsidePrevious then
    core_environment.setShadowLogWeight(lastLogWeight)
  end

  local data = {}
  -- global cameras
  data.globalCameras = {}
  for k,cam in pairs(getGlobalCameras()) do
    if cam.onSerialize then cam:onSerialize() end
    data.globalCameras[k] = serialize(cam)
  end

  -- per-vehicle cameras
  data.vehicleCameras = {}
  for vid, vdata in pairs(getVehicleData()) do
    data.vehicleCameras[vid] = {}
    data.vehicleCameras[vid].cameras = {}
    data.vehicleCameras[vid].focusedCamName = vdata.focusedCamName
    for camName,cam in pairs(vdata.cameras) do
      data.vehicleCameras[vid].cameras[camName] = serialize(cam)
    end
  end
  data.vehicleCameras = convertVehicleIdKeysToVehicleNameKeys(data.vehicleCameras)

  -- general camera data
  data.activeGlobalCameraName = activeGlobalCameraName
  data.lastVehicleName = lastVehicleName
  data.pendingTrigger = pendingTrigger
  data.requestedCam = requestedCam
  data.lastLogWeight = lastLogWeight
  return data
end

local function onDeserialized(data)
  -- general camera data
  lastVehicleName = data.lastVehicleName
  pendingTrigger = data.pendingTrigger
  requestedCam = data.requestedCam
  lastLogWeight = data.lastLogWeight

  -- global cameras
  for camName, cam in pairs(getGlobalCameras()) do
    if data.globalCameras[camName] then
      tableMergeRecursive(cam, deserialize(data.globalCameras[camName]))
      if cam.onDeserialized then cam:onDeserialized() end
    end
  end

  -- per-vehicle cameras
  data.vehicleCameras = convertVehicleNameKeysToVehicleIdKeys(data.vehicleCameras)
  for vid, vdata in pairs(getVehicleData()) do
    local svdata = data.vehicleCameras[vid]
    for camName,cam in pairs(vdata.cameras) do
      if svdata then
        if svdata.cameras[camName] then
          tableMergeRecursive(cam, deserialize(svdata.cameras[camName]))
        end
        if camName == svdata.focusedCamName then
          vdata.focusedCamName = svdata.focusedCamName
        end
      end
    end
  end

  -- vehicle cameras will have attempted to remove the global cam name, so overwrite that now
  activeGlobalCameraName = data.activeGlobalCameraName
end

local function invalidateCaches()
  constructorsCache = nil
  globalCamerasCache = nil
  runningCamsOrderCache = nil
  vehicleCamerasCache = nil
end

local function onFileChanged(filePath, changeType)
  if (changeType == "added" or changeType == "deleted") and string.startswith(filePath, '/lua/ge/extensions/core/cameraModes/') then
    invalidateCaches()
  end
end

local function onClientEndMission()
  -- clear the camera object of the render view so we dont access a garbage reference
  local mainRenderView = RenderViewManagerInstance:getView('main')
  if mainRenderView then
    mainRenderView:clearCameraObject()
  end
end

-- callbacks
M.onPreRender = onPreRender -- just update the camera right before the rendering
M.onTrigger = onTrigger
M.onSettingsChanged = onSettingsChanged
M.onVehicleResetted = onVehicleResetted
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleSwitched = onVehicleSwitched
M.onDespawnObject = onDespawnObject
M.onVehicleDestroyed = onVehicleDestroyed
M.onScenarioRestarted = onScenarioRestarted
M.onScenarioChange = onScenarioChange
M.onFileChanged = onFileChanged
M.onMouseLocked = onMouseLocked
M.onClientPostStartMission = onClientPostStartMission
M.onClientEndMission = onClientEndMission


-- internal things
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

-- functions used by other GE lua code
M.clearInputs = clearInputs
M.resetCameraByID = resetCameraByID
M.setRotation = setRotation
M.setFOV = setFOV
M.setOffset = setOffset
M.setRefNodes = setRefNodes
M.setRef = setRef
M.setTargetMode = setTargetMode
M.setDefaultDistance = setDefaultDistance
M.setDistance = setDistance
M.setMaxDistance = setMaxDistance
M.setDefaultRotation = setDefaultRotation
M.setSkipFovModifier = setSkipFovModifier
M.setByName = setByName
M.setVehicleCameraByNameWithId = setVehicleCameraByNameWithId
M.exitCinematicCamera = function() setGlobalCameraByName(nil) end -- retrocompatibility layer
M.toggleEnabledById = toggleEnabledCameraById
M.setBySlotId = setBySlotId
M.changeOrder = changeOrder
M.getCameraDataById = getCameraDataById
M.getDriverData = getDriverData
M.getDriverDataById = getDriverDataById
M.getActiveCamName = getActiveCamName
M.getActiveCamNameByVehId = getActiveCamNameByVehId
M.displayCameraNameUI = displayCameraNameUI
M.isCameraInside = isCameraInside
M.timeSinceLastRotation = timeSinceLastRotation
M.getGlobalCameras = getGlobalCameras
M.objectTeleported = objectTeleported

M.proxy_Player = proxy_Player
M.globalCameraFunction = globalCameraFunction

-- functions used by UI options
M.requestConfig = requestConfig
M.resetConfiguration = resetConfiguration

-- functions used from the input code
M.setVehicleCameraByIndexOffset = setVehicleCameraByIndexOffset
M.resetCamera = resetCamera
M.lookBack = lookBack
M.hotkey = hotkey
M.rotate_pitch = rotate_pitch
M.rotate_pitch_up = rotate_pitch_up
M.rotate_pitch_down = rotate_pitch_down
M.rotate_yaw = rotate_yaw
M.rotate_yaw_left = rotate_yaw_left
M.rotate_yaw_right = rotate_yaw_right
M.cameraZoom = cameraZoom
M.rotate_yaw_relative = rotate_yaw_relative
M.rotate_pitch_relative = rotate_pitch_relative

M.yawAbs = yawAbs
M.rollAbs = rollAbs
M.pitchAbs = pitchAbs
M.xAxisAbs = xAxisAbs
M.yAxisAbs = yAxisAbs
M.zAxisAbs = zAxisAbs

M.moveleft     = moveleft
M.moveright    = moveright
M.moveforward  = moveforward
M.movebackward = movebackward
M.moveup       = moveup
M.movedown     = movedown
M.moveForwardBackward = moveForwardBackward
M.moveLeftRight = moveLeftRight
M.getLastFilter = getLastFilter

return M
