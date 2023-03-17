-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt












--- This utility is obsolete and superseeded by screenshotCreator.lua














local M = {}
M.dependencies = {"ui_imgui"}
M.state = {show= false}
local logTag = 'createThumbnails'

local workerCoroutine = nil
local forceQuit = false
local redoPass = false

local config = jsonReadFile('settings/createThumbnails_config.json')
local options = config.options
local views = config.views

local transparentMats = {}

local im = ui_imgui
local guiModule = require("ge/extensions/editor/api/gui")
local gui = {setupEditorGuiTheme = nop}
local windowOpen = im.BoolPtr(false)
local windowOpenTweak = im.BoolPtr(false)
local initialWindowSize = im.ImVec2(300, 100)
local vehList --table array  {vehFolder, boolptr, nameStr, config numbr?}
local viewsList = {default=im.BoolPtr(true), sideGarage=im.BoolPtr(false), frontGarage=im.BoolPtr(false)}
local viewComboStr  = "default\0sideGarage\0frontGarage\0\0"
local viewComboTable  = {"default", "sideGarage", "frontGarage"}
local cameraTweakVal = {rotation = im.FloatPtr(135),
dist = im.FloatPtr(1),
fov = im.FloatPtr(20),
offset = {x = im.FloatPtr(0), y=im.FloatPtr(0), z=im.FloatPtr(0)},
freeOffset = {x = im.FloatPtr(0), y=im.FloatPtr(0), z=im.FloatPtr(0)},
diffuse = im.BoolPtr(true),
annotation = im.BoolPtr(false),
light = im.BoolPtr(false),
info= {dim="", prefix="", suffix="", allow="", imgFormat=""}
}
local ComboCurrentItem = im.IntPtr(0)
local bgComboStr = ""
for _,v in ipairs(options.backgrounds) do
  bgComboStr = bgComboStr .. tostring(v) .. "\0"
end
local ComboCurrentBg = im.IntPtr(0)

local supersampling = 16


local function reloadConfig()
  config = jsonReadFile('settings/createThumbnails_config.json')
  options = config.options
  views = config.views
end

local function overwriteOptionGui()
  options.views = {}
  for k,v in pairs(viewsList) do
    if v[0] then table.insert( options.views, k ) end
  end
  options.models = {}
  for k,v in pairs(vehList) do
    if v[2][0] then
      table.insert( options.models, v[1] )
    end
  end
end

local function populateVehGui()
  vehList = {}
  local models = core_vehicles.getModelList().models --because
  local modelKeys={}
  for k,_ in pairs(models) do table.insert(modelKeys,k) end
  table.sort(modelKeys)
  for _,k in ipairs(modelKeys) do
    local v = models[k]
    vehList[_] = {k,im.BoolPtr(false), string.format("%s %s",v.Brand or "(No Brand)", v.Name or "(No Name)")}
  end
end

local function isBatch()
  local cmdArgs = Engine.getStartingArgs()
  local probability = 0
  for i = 1, #cmdArgs do
    local arg = cmdArgs[i]
    arg = arg:stripchars('"')
    if arg == "-onLevelLoad_ext" or arg == "'util/createThumbnails'" then
      probability = probability +1
    end
  end
  return probability > 1
end

local function yieldSec(yieldfn,sec)
  local start  = os.clock()
  while (start+sec)>os.clock() do
    yieldfn()
  end
end

local previousDisplayResolution
local function onPreRender(dt)
  if workerCoroutine ~= nil then
    local errorfree, value = coroutine.resume(workerCoroutine)
    if not errorfree then
      log('E', logTag, "workerCoroutine: "..value)
      log("E", logTag, debug.traceback(workerCoroutine))
    end
    if coroutine.status(workerCoroutine) == "dead" then

      -- Reset resolution to what it was before
      local graphicsOptions = core_settings_graphic.getOptions()
      graphicsOptions.GraphicDisplayResolutions.set(previousDisplayResolution)

      extensions.hook("onThumbnailTriggered", false)
      workerCoroutine = nil
      settings.setValue('GraphicBorderless', false)
      core_settings_graphic.applyGraphicsState()
      extensions.ui_visibility.set(true)
      settings.setValue('cameraOrbitSmoothing', true)
      bullettime.pause(false)
      redoPass = false
      if isBatch() then
        log('E', '', 'coroutine BROKE')
        shutdown(0)
      end
    end
  end
end

local function findVal (model, config)
  return function (view)
    return function (val)
      if view.models ~= nil and view.models[model] ~= nil then
        local temp = view.models[model]

        if temp.configs ~= nil and temp.configs[config] ~= nil and temp.configs[config][val] ~= nil then
          return temp.configs[config][val]
        end

        if temp[val] ~= nil then
          return temp[val]
        end
      end
      return view[val]
    end
  end
end

-- called when the module is loaded. Note: not all system may be up and running at this point
local function onInit()
  log('I', logTag, "initialized")
end

local function setDimHelper (useView)
  local vm = GFXDevice.getVideoMode()
  if vm.width == useView.width and vm.height == useView.height and vm.displayMode == "Borderless" then
    -- nothing to change
    return
  end
  log('I', logTag, "requesting new video mode")
  vm.width = useView.width
  vm.height = useView.height
  vm.displayMode = "Borderless"
  -- canvas:setMinExtent(vm.width, vm.height)
  GFXDevice.setVideoMode(vm)
end

-- executed when a level was loaded
local function onClientStartMission(levelPath)
  log('I', logTag, "onClientStartMission")
  setDimHelper({width = 1600, height = 900})
end

local function fVal2Bool(v,default)
  if v then
    if v == "false" or v == "0" then
      return false
    else
      return true
    end
  else
    return default
  end
end

local function getCameraTweak()
  local useView = views.default
  local newVehicle = be:getPlayerVehicle(0)
  local findValConf = findVal(newVehicle.JBeam, newVehicle.partConfig)
  local findValView = findValConf(views[viewComboTable[ComboCurrentItem[0]+1]])
  --disp dim

  cameraTweakVal.rotation[0] = findValView('rotation')
  local dist = findValView('dist')
  if dist == nil then
    cameraTweakVal.dist[0] = 1
  else
    cameraTweakVal.dist[0] = dist
  end
  cameraTweakVal.fov[0] = findValView('fov')
  local offset = findValView('offset')--vec3
  cameraTweakVal.offset.x[0] = offset[1]
  cameraTweakVal.offset.y[0] = offset[2]
  cameraTweakVal.offset.z[0] = offset[3]

  local bg = findValView("background")
  local bgindex = 1
  if bg then
    for k,v in ipairs(options.backgrounds) do
      if v == bg then
        bgindex = k
        break
      end
    end
  end
  ComboCurrentBg[0] = bgindex-1

  local freeOffset = findValView('freeOffset') --vec3
  cameraTweakVal.freeOffset.x[0] = freeOffset[1]
  cameraTweakVal.freeOffset.y[0] = freeOffset[2]
  cameraTweakVal.freeOffset.z[0] = freeOffset[3]
  cameraTweakVal.diffuse[0] = fVal2Bool(findValView("diffuse"),true)
  cameraTweakVal.annotation[0] = fVal2Bool(findValView("annotation"),false) and (Engine.Annotation ~= nil)
  cameraTweakVal.light[0] = fVal2Bool(findValView("light"),false)

  cameraTweakVal.info.dim = tostring(findValView("width")) .."x" ..tostring(findValView("height"))
  cameraTweakVal.info.prefix = dumps(findValView("prefix"))
  cameraTweakVal.info.suffix = dumps(findValView("suffix"))
  cameraTweakVal.info.allow = dumps(findValView("allow"))
  cameraTweakVal.info.imgFormat = dumps(findValView("imgFormat"))
end

local function menuToolbar(uiScale,isRunning)
  if im.BeginMenuBar() then
    if im.BeginMenu("Tools") then
      -- if im.MenuItem1("Open Camera tweaking") then
      --   windowOpenTweak[0] = true
      -- end
      im.MenuItem2("Camera tweaking Window", "", windowOpenTweak)

      im.EndMenu()
    end

    local imgsize = (im.CalcTextSize("yes_texture.dds").y + im.GetStyle().FramePadding.y * 1) / uiScale

    if isRunning then im.BeginDisabled() end
    if gui.uiIconImageButton(gui.icons.play_arrow, {x=imgsize, y=imgsize}, (isRunning) and im.ImColorByRGB(0,255,0,127).Value or im.ImColorByRGB(0,255,0,255).Value, nil, im.ImColorByRGB(32,32,32,255).Value) then
      redoPass = false
      reloadConfig()
      overwriteOptionGui()
      M.startWork()
    end
    im.tooltip("Run Thumbnails")

    if gui.uiIconImageButton(gui.icons.refresh, {x=imgsize, y=imgsize}, (isRunning) and im.ImColorByRGB(255,255,255,127).Value or im.ImColorByRGB(255,255,255,255).Value, nil, im.ImColorByRGB(32,32,32,255).Value) then
      redoPass = true
      reloadConfig()
      overwriteOptionGui()
      M.startWork()
    end
    im.tooltip("Redo missing Thumbnails")
    if isRunning then im.EndDisabled() end

    if not isRunning then im.BeginDisabled() end
    if gui.uiIconImageButton(gui.icons.stop, {x=imgsize, y=imgsize}, (isRunning) and im.ImColorByRGB(255,0,0,255).Value or im.ImColorByRGB(255,0,0,127).Value, nil, im.ImColorByRGB(32,32,32,255).Value) then
      forceQuit = true
    end
    im.tooltip("Stop")
    if not isRunning then im.EndDisabled() end

    if not isRunning then
      im.TextUnformatted("Ready")
    else --running
      if forceQuit then
        im.TextUnformatted("Will stop")
      else
        im.TextUnformatted("Running")
      end
    end

    im.EndMenuBar()
  end
end


local function onUpdate(dtReal, dtSim, dtRaw)
  if windowOpen[0] ~= true then return end

  local uiScale = 1
  if editor and editor.getPreference and editor.getPreference("ui.general.scale") then
    uiScale = editor.getPreference("ui.general.scale")
  else
    uiScale = im.GetIO().FontGlobalScale
  end
  local isRunning = workerCoroutine ~= nil


  im.SetNextWindowSize(initialWindowSize, im.Cond_FirstUseEver)
  im.SetNextWindowPos(im.GetWindowPos(), im.Cond_FirstUseEver)
  if( im.Begin("util_createThumbnails GUI", windowOpen, im.WindowFlags_MenuBar) ) then
    menuToolbar(uiScale,isRunning)

    im.TextUnformatted("Views :")
    im.SameLine()

    if isRunning then im.BeginDisabled() end

    im.Checkbox("default", viewsList.default)
    im.SameLine()
    im.Checkbox("sideGarage", viewsList.sideGarage)
    im.SameLine()
    im.Checkbox("frontGarage", viewsList.frontGarage)


    im.TextUnformatted("models:")
    im.SameLine()
    if im.SmallButton("Select only current") then
      local playerVehicle = be:getPlayerVehicle(0)
      if playerVehicle then
        for _,v in ipairs(vehList) do
          v[2][0] = v[1] == playerVehicle.JBeam
        end
      else
        log("E", "selectCurVeh", "Failed to get current vehicle")
      end
    end
    im.SameLine()
    if im.SmallButton("unselect all") then
      for _,v in ipairs(vehList) do
        v[2][0] = false
      end
    end
    im.SameLine()
    if im.SmallButton("select all") then
      for _,v in ipairs(vehList) do
        v[2][0] = true
      end
    end
    im.SameLine()
    if im.SmallButton("invert selection") then
      for _,v in ipairs(vehList) do
        v[2][0] = not v[2][0]
      end
    end

    if im.BeginChild1("modelsChild", im.ImVec2(0, 0 * uiScale), true) then
      if vehList then
        for _,v in ipairs(vehList) do
          im.Selectable2(v[1],v[2])
          im.SameLine(200)
          im.TextUnformatted(v[3])
        end
      end
    end
    im.EndChild()
    if isRunning then im.EndDisabled() end
  end
  local wSize = im.GetWindowSize()
  im.End() --Begin

  if windowOpenTweak[0] then
    im.SetNextWindowSize(initialWindowSize, im.Cond_FirstUseEver)
    im.SetNextWindowPos(im.ImVec2(0, wSize.y))
    if( im.Begin("util_createThumbnails - Camera tweaking", windowOpenTweak, im.WindowFlags_MenuBar) ) then
      if isRunning then im.BeginDisabled() end
      if im.BeginMenuBar() then
        if im.SmallButton("get values") then
          reloadConfig()
          getCameraTweak()
        end
        if im.SmallButton("execute") then
          reloadConfig()
          M.startTweak()
        end

        im.EndMenuBar()
      end

      if im.Combo2("##cmdctx", ComboCurrentItem, viewComboStr) then
        --print("context changed")
      end
      im.SameLine()
      im.TextUnformatted("View")

      if im.SliderFloat("rotation ", cameraTweakVal.rotation, -180, 180) then
      end

      if im.SliderFloat("dist ", cameraTweakVal.dist, 0.2, 4) then
      end

      if im.SliderFloat("fov", cameraTweakVal.fov, 1, 110) then
      end

      local valLimits = 30

      --vec3
      if im.SliderFloat("offset x", cameraTweakVal.offset.x, -valLimits, valLimits) then
      end
      if im.SliderFloat("offset y", cameraTweakVal.offset.y, -valLimits, valLimits) then
      end
      if im.SliderFloat("offset z", cameraTweakVal.offset.z, -valLimits, valLimits) then
      end


      --vec3
      if im.SliderFloat("freeOffset x", cameraTweakVal.freeOffset.x, -valLimits, valLimits) then
      end
      if im.SliderFloat("freeOffset y", cameraTweakVal.freeOffset.y, -valLimits, valLimits) then
      end
      if im.SliderFloat("freeOffset z", cameraTweakVal.freeOffset.z, -valLimits, valLimits) then
      end

      if im.Combo2("##bg", ComboCurrentBg, bgComboStr) then
        --print("context changed")
      end
      im.SameLine()
      im.TextUnformatted("Background")

      --bool
      im.Checkbox("diffuse", cameraTweakVal.diffuse)
      if not Engine.Annotation then im.BeginDisabled() end
      im.Checkbox("annotation", cameraTweakVal.annotation)
      if not Engine.Annotation then
        im.EndDisabled()
        im.SameLine()
        im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), "Annotation not available!")
      end

      im.Checkbox("light", cameraTweakVal.light)

      im.Separator()

      im.TextUnformatted("Dim :" ..cameraTweakVal.info.dim)
      im.TextUnformatted("prefix :" ..cameraTweakVal.info.prefix)
      im.TextUnformatted("suffix :" ..cameraTweakVal.info.suffix)
      im.TextUnformatted("allow :" ..cameraTweakVal.info.allow)
      im.TextUnformatted("imgFormat :" ..cameraTweakVal.info.imgFormat)

      im.Separator()

      im.TextUnformatted("offset : orbit offset")
      im.TextUnformatted("freeOffset : camera translate in world coordinate\n(-Y south = Vehicle forward, X = Vehicle left)")


      if isRunning then im.EndDisabled() end
    end
    im.End() --Begin
  end
end

local function disableTransparency()
  local matObjNames = scenetree.findClassObjects('Material')
  for i,v in ipairs(matObjNames) do
    if v:find("light") or v:find("glass") then
      local mat = scenetree.findObject(v)
      if mat and mat:getField('translucent', 0) == "1" then
        mat:setField('translucent', "", "0")
        mat:flush()
        mat:reload()
        table.insert( transparentMats, mat )
      end
    end
  end
end

local function enableTransparency()
  for _,mat in ipairs(transparentMats) do
    mat:setField('translucent', "", "1")
    mat:flush()
    mat:reload()
  end
  transparentMats = {}
end

local function setBackground(namebackground, bgs)

  for i,v in ipairs(bgs) do
    local obj = scenetree.findObject(v)
    if obj then
      obj:setHidden(true)
    end
  end

  -- print("bgs = "..dumps(bgs))
  -- print("getcfg".. dumps(namebackground))

  local ubg = namebackground or bgs[1]
  -- print("using "..dumps(ubg) )
  local obj = scenetree.findObject(ubg)
  if obj then
    obj:setHidden(false)
  end
end

local function onExtensionLoaded()
  guiModule.initialize(gui)
  populateVehGui()
end

-- set currentVehicleConfigName, to make a screenshot only of the current vehicle with the specified name
M.startWork = function(currentVehicleConfigName)
  log('I', logTag, "module loaded")
  extensions.hook("onThumbnailTriggered", true)

  -- Save resolution before changing it
  local graphicsOptions = core_settings_graphic.getOptions()
  previousDisplayResolution = graphicsOptions.GraphicDisplayResolutions.get()

  options.currentVehConfigName = currentVehicleConfigName
  if workerCoroutine then
    log('E', "startWork", "coroutine already exist")
    return
  end

  -- set GraphicBorderless to true, to make sure the view dimensions actually are the ones the picture is taken in
  settings.setValue('GraphicBorderless', true)
  settings.setValue('cameraOrbitSmoothing', false)
  core_settings_graphic.applyGraphicsState()

  -- set correct level
  --core_levels.startLevel(levelFullPath)


  -- main thing

  -- todo: since we need to load the whole vehicle for each config anyway we should cycle each view for each vehicle so that we don't need to set the window dimensions that often
  workerCoroutine = coroutine.create(function()
    forceQuit = false

    if core_camera == nil then
      -- extensions.load("core_camera")
      loadGameModeModules()
    end

    editor.setEditorActive(false)
    be:setPhysicsSpeedFactor(2)
    core_camera.speedFactor = 10000
    TorqueScriptLua.setVar('$Camera::movementSpeed', '1000')


    local lights = {"light4garagepass"}
    local lightsobj = {}
    for _,v in ipairs(lights) do
      table.insert( lightsobj, scenetree.findObject(v) )
    end

    yieldSec(coroutine.yield, 0.1)

    log('I', logTag, 'Getting config list')
    local configs = core_vehicles.getConfigList(true).configs
    local models = core_vehicles.getModelList().models --because

    local configCount = tableSize(configs)
    log('I', logTag, table.maxn(configs).." configs")
    local modelInfo = nil
    local fovModifier = settings.getValue('cameraOrbitFovModifier') * -1 --only apply in orbit camera !!!!!

    yieldSec(coroutine.yield, 0.1)

    local counter = 0
    for _, v in pairs(configs) do
      counter = counter + 1
      local findValConf = findVal(v.model_key, v.key)
      -- if v.model_key == 'bigramp' or v.model_key == 'ramptest' or v.model_key == 'roadsigns' then goto continue end

      -- skip props
      -- if v.aggregates.Type.Prop then goto skipConfig end
      if options.models ~= nil and not tableContains(options.models, v.model_key) then goto skipConfig end

      if redoPass then
        local redoing = false
        for _,vname in pairs(config.options.views) do
          local useView = views[vname]
          if useView.allow and tableContains(useView.allow, "onlyDefault") then goto nextviewschk end
          local tbname = "/vehicles/"..v.model_key.."/"..v.key..(useView.suffix or "")..".png"
          local realname = FS:getFileRealPath(tbname)
          if not realname:find(getUserPath()) then
            log("D","redo", dumps(realname))
            redoing = true
            break --need to do
          else
            log("D","redo", "existing")
          end
          ::nextviewschk::
        end
        if not redoing then
          log("W", "redoPass" , "skipConfig "..dumps(v.model_key.."/"..v.key))
          goto skipConfig
        end
      end

      if models == nil or models[v.model_key] == nil then
        log("E", logTag, "Model Info  not found for model ='"..v.model_key .."'")
        break
      end
      modelInfo = models[v.model_key]

      -- Replace the vehicle
      log('I', logTag, string.format("Spawning vehicle %05d / %05d", counter, configCount) .. ' : ' .. ' name: ' .. tostring(v.model_key) .. ', config: ' .. tostring(v.key))
      yieldSec(coroutine.yield, 0.1)
      local oldVehicle = be:getPlayerVehicle(0)
      local newVehicle = oldVehicle
      if not options.currentVehConfigName then
        oldVehicle:setDynDataFieldbyName("licenseText", 0, "BeamNG")

        core_vehicles.replaceVehicle(v.model_key, { config = v.key, licenseText = options.plate or ' '})
        yieldSec(coroutine.yield, 0.2)

        newVehicle = oldVehicle
        while newVehicle == oldVehicle do
          yieldSec(coroutine.yield, 0.1)
          newVehicle = be:getPlayerVehicle(0)
        end

        newVehicle:queueLuaCommand("input.event('parkingbrake', 1, 1)")
        newVehicle:queueLuaCommand("input.event('throttle', 0, 2)")
        newVehicle:queueLuaCommand("controller.mainController.setEngineIgnition(false)")

        if tableContains(options.oldveh, newVehicle:getJBeamFilename()) then
          yieldSec(coroutine.yield, 0.5)
        end
        yieldSec(coroutine.yield, 0.1)
      end
      extensions.ui_visibility.set(false)
      bullettime.pause(true)

      for viewName, useView in pairs(views) do
        if forceQuit then
          be:setPhysicsSpeedFactor(0)
          core_camera.speedFactor = 1
          TorqueScriptLua.setVar('$Camera::movementSpeed', '30')
          return
        end

        if useView.allow == nil then
          useView.allow = {}
        end

        if modelInfo.Type == "Prop" and not tableContains(useView.allow, "Prop") then goto skipView end
        if modelInfo.Type == "Trailer" and not tableContains(useView.allow, "Trailer") then goto skipView end
        if not v.is_default_config and tableContains(useView.allow, "onlyDefault") then goto skipView end
        if options.views ~= nil and not tableContains(options.views, viewName) then goto skipView end
        local findValView = findValConf(useView)

        yieldSec(coroutine.yield, 0.1)
        setDimHelper(useView)
        yieldSec(coroutine.yield, 0.1)

        local vehicleId = newVehicle:getID()
        commands.setGameCamera()
        core_camera.setByName(0, "orbit", false)
        core_camera.setMaxDistance(be:getPlayerVehicleID(0), nil)
        core_camera.resetCameraByID(vehicleId)

        core_camera.setFOV(vehicleId, 20 + fovModifier)

        yieldSec(coroutine.yield, 0.1)

        core_camera.resetCameraByID(vehicleId)
        core_camera.setFOV(vehicleId, 20 + fovModifier)

        core_camera.setRotation(vehicleId, vec3(findValView('rotation'), 0, 0))
        yieldSec(coroutine.yield, 0.1)

        core_camera.setRotation(vehicleId, vec3(findValView('rotation'), 0, 0))
        yieldSec(coroutine.yield, 0.1)

        if findValView('dist') == nil then
          useView.dist = 1
        end

        local idealDistance = newVehicle:getViewportFillingCameraDistance() * findValView('dist')
        core_camera.setDistance(vehicleId, idealDistance)
        if findValView('fov') then
          core_camera.setFOV(vehicleId, findValView('fov') + fovModifier)
        end
        if findValView('offset') then
          core_camera.setOffset(vehicleId, vec3(findValView('offset')[1] / idealDistance, findValView('offset')[2] / idealDistance, findValView('offset')[3] / idealDistance))
        end
        --MoveManager.zoomInSpeed = idealDistance
        --print("* new distance: " .. tostring(idealDistance))
        setBackground(findValView("background"), options.backgrounds)
        yieldSec(coroutine.yield, 0.1)

        if findValView('freeOffset') then
          commands.setFreeCamera()
          local camera = commands.getFreeCamera()
          local pos = getCameraPosition()
          pos.x = pos.x + findValView('freeOffset')[1] / idealDistance
          pos.y = pos.y + findValView('freeOffset')[2] / idealDistance
          pos.z = pos.z + findValView('freeOffset')[3] / idealDistance
          camera:setPosition(pos)
          setCameraFovDeg(findValView('fov'))
          yieldSec(coroutine.yield, 0.1)
        end

        --newVehicle:queueLuaCommand("input.event('steering', 0.0, 1); input.event('parkingbrake', 1, 1); electrics.toggle_lights() ; electrics.toggle_lightbar_signal() ; electrics.toggle_fog_lights()")
        newVehicle:queueLuaCommand("input.event('parkingbrake', 1, 1)")

        local screenShotName = ""

        -- Take screenshot
        if findValView("diffuse") == "true" or findValView("diffuse")== nil then
          Engine.imgui.setEnabled(false)
          local fileEnding
          if options.currentVehConfigName then
            local vehManager = extensions.core_vehicle_manager
            local playerVehicle = vehManager.getPlayerVehicleData()
            screenShotName = (playerVehicle.vehicleDirectory .. options.currentVehConfigName)
            fileEnding = "jpg"
            supersampling = 1
          else
            screenShotName = "vehicles/" .. v.model_key .. "/" .. (findValView('prefix') or '') .. v.key .. (findValView('suffix') or '')
            fileEnding = findValView('imgFormat') or "png"
          end

          log('I', logTag, "saved screenshot:" .. screenShotName  ..'.'..fileEnding)
          createScreenshot(screenShotName, fileEnding, supersampling)
          if viewName == "default" and v.is_default_config then
            -- wait for a bit longer and then copy the last screenshot for the default thumbnail
            yieldSec(coroutine.yield, 1)
            FS:copyFile(screenShotName .. "." .. (findValView('imgFormat') or "png"), 'vehicles/' .. v.model_key .. '/default.' .. (findValView('imgFormat') or "png"))
            log('I', logTag, "saved default:" .. v.model_key  ..'.'..(findValView('imgFormat') or "png"))
          end
          yieldSec(coroutine.yield, 0.01)
          Engine.imgui.setEnabled(true)
        end

        if findValView("annotation") == "true" then
          disableTransparency()
          yieldSec(coroutine.yield, 0.2)
          TorqueScript.eval('toggleAnnotationVisualize(true);')
          Engine.imgui.setEnabled(false)
          screenShotName = "vehicles/" .. v.model_key .. "/" .. (findValView('prefix') or '') .. v.key .. (findValView('suffix') or '')
          yieldSec(coroutine.yield, 0.1)
          log('I', logTag, "saved screenshot:" .. screenShotName  ..'_ann.'..(findValView('imgFormat') or "png"))
          createScreenshot(screenShotName ..'_ann', (findValView('imgFormat') or "png"), supersampling)
          yieldSec(coroutine.yield, 0.1)
          TorqueScript.eval('toggleAnnotationVisualize(false);')
          Engine.imgui.setEnabled(true)
          enableTransparency()
        end

        if findValView("light") == "true" then
          yieldSec(coroutine.yield, 0.2)
          -- setBackground("light_bg", options.backgrounds)
          for _,o in ipairs(lightsobj) do
            if o then o.isEnabled = true end
          end
          Engine.imgui.setEnabled(false)
          TorqueScript.eval('toggleLightColorViz(true);')
          screenShotName = "vehicles/" .. v.model_key .. "/" .. (findValView('prefix') or '') .. v.key .. (findValView('suffix') or '')
          yieldSec(coroutine.yield, 0.1)
          log('I', logTag, "saved screenshot:" .. screenShotName  ..'_li.'..(findValView('imgFormat') or "png"))
          createScreenshot(screenShotName ..'_li', (findValView('imgFormat') or "png"), supersampling)
          yieldSec(coroutine.yield, 0.1)
          for _,o in ipairs(lightsobj) do
            if o then o.isEnabled = false end
          end
          setBackground(findValView("background"), options.backgrounds)
          TorqueScript.eval('toggleLightColorViz(false);')
          Engine.imgui.setEnabled(true)
        end

        setBackground(nil, options.backgrounds)

        if findValView('freeOffset') then
          commands.setGameCamera()
        end
        ::skipView::
      end

      bullettime.pause(false)
      if options.currentVehConfigName then
        break
      end

      ::skipConfig::
    end

    be:setPhysicsSpeedFactor(0)
    core_camera.speedFactor = 1
    TorqueScriptLua.setVar('$Camera::movementSpeed', '30')
    core_camera.setFOV(be:getPlayerVehicleID(0), 65)
    core_camera.resetCamera(0)
    supersampling = 16
  end)
end


M.startTweak = function()
  if workerCoroutine then
    log('W', "startTweak", "coroutine already exist")
    return
  end
  workerCoroutine = coroutine.create(function()
    local lights = {"light4garagepass"}
    local lightsobj = {}
    for _,v in ipairs(lights) do
      table.insert( lightsobj, scenetree.findObject(v) )
    end

    local newVehicle = be:getPlayerVehicle(0)
    local findValConf = findVal(newVehicle.JBeam, newVehicle.partConfig)
    newVehicle:setPositionRotation(0,0,0.4,0,0,0,1)
    newVehicle:queueLuaCommand("input.event('parkingbrake', 1, 1)")
    newVehicle:queueLuaCommand("input.event('throttle', 0, 2)")
    newVehicle:queueLuaCommand("controller.mainController.setEngineIgnition(false)")
    yieldSec(coroutine.yield, 1)
    extensions.ui_visibility.set(false)
    bullettime.pause(true)

    local fovModifier = settings.getValue('cameraOrbitFovModifier') * -1

    local useView = views[viewComboTable[ComboCurrentItem[0]+1]]
    local findValView = findValConf(useView)

    settings.setValue('GraphicBorderless', true)
    extensions.ui_visibility.set(false)
    settings.setValue('cameraOrbitSmoothing', false)

    yieldSec(coroutine.yield, 0.1)
    setDimHelper(useView)
    yieldSec(coroutine.yield, 0.1)

    local vehicleId = newVehicle:getID()

    core_camera.resetCameraByID(vehicleId)
    core_camera.setFOV(vehicleId, 20 + fovModifier)

    yieldSec(coroutine.yield, 0.2)

    core_camera.resetCameraByID(vehicleId)
    core_camera.setFOV(vehicleId, 20 + fovModifier)

    yieldSec(coroutine.yield, 0.2)


    -- core_camera.setRotation(vehicleId, vec3(findValView('rotation'), 0, 0))
    core_camera.setRotation(vehicleId, vec3(cameraTweakVal.rotation[0], 0, 0))

    -- if findValView('dist') == nil then
    --   useView.dist = 1
    -- end

    -- local idealDistance = newVehicle:getViewportFillingCameraDistance() * findValView('dist')
    local idealDistance = newVehicle:getViewportFillingCameraDistance() * cameraTweakVal.dist[0]
    core_camera.setDistance(vehicleId, idealDistance)
    -- if findValView('fov') then
    --   core_camera.setFOV(vehicleId, findValView('fov'))
    -- end
    core_camera.setFOV(vehicleId, cameraTweakVal.fov[0] + fovModifier)
    -- if findValView('offset') then
    --   core_camera.setOffset(vehicleId, vec3(findValView('offset')[1] / idealDistance, findValView('offset')[2] / idealDistance, findValView('offset')[3] / idealDistance))
    -- end
    core_camera.setOffset(vehicleId, vec3(cameraTweakVal.offset.x[0] / idealDistance, cameraTweakVal.offset.y[0] / idealDistance, cameraTweakVal.offset.z[0] / idealDistance))
    --MoveManager.zoomInSpeed = idealDistance
    --print("* new distance: " .. tostring(idealDistance))
    setBackground(options.backgrounds[ComboCurrentBg[0]+1], options.backgrounds) --TODO
    yieldSec(coroutine.yield, 1)

    --if findValView('freeOffset') then --most probably we do that all the time
      commands.setFreeCamera()
      local camera = commands.getFreeCamera()
      local pos = camera:getPosition()
      pos.x = pos.x + cameraTweakVal.freeOffset.x[0] / idealDistance
      pos.y = pos.y + cameraTweakVal.freeOffset.y[0] / idealDistance
      pos.z = pos.z + cameraTweakVal.freeOffset.z[0] / idealDistance
      camera:setPosition(vec3(pos))
      setCameraFovDeg(cameraTweakVal.fov[0])
      yieldSec(coroutine.yield, 0.75)
    --end

    local configName = newVehicle.partConfig:gsub(".pc$","")
    local screenShotName = ""
    screenShotName = "screenshots/thumbnail_" .. newVehicle.JBeam .. "_" .. (findValView('prefix') or '') .. configName .. (findValView('suffix') or '') .. tostring(getScreenShotDateTimeString())

    -- Take screenshot
    if cameraTweakVal.diffuse[0] then
      log('I', logTag, "saved screenshot:" .. screenShotName  ..'.'..(findValView('imgFormat') or "png"))
      createScreenshot(screenShotName, (findValView('imgFormat') or "png"), supersampling)
      yieldSec(coroutine.yield, 1)
    end

    if cameraTweakVal.annotation[0] and Engine.Annotation then
      disableTransparency()
      yieldSec(coroutine.yield, 0.2)
      TorqueScript.eval('toggleAnnotationVisualize(true);')
      screenShotName = "screenshots/thumbnail_" .. newVehicle.JBeam .. "_" .. (findValView('prefix') or '') .. configName .. (findValView('suffix') or '') .. tostring(getScreenShotDateTimeString())
      yieldSec(coroutine.yield, 1.0)
      log('I', logTag, "saved screenshot:" .. screenShotName  ..'_ann.'..(findValView('imgFormat') or "png"))
      createScreenshot(screenShotName .. '_ann', (findValView('imgFormat') or "png"), supersampling)
      yieldSec(coroutine.yield, 1.0)
      TorqueScript.eval('toggleAnnotationVisualize(false);')
      enableTransparency()
    end

    if cameraTweakVal.light[0] then
      yieldSec(coroutine.yield, 0.2)
      -- setBackground("light_bg", options.backgrounds)
      for _,o in ipairs(lightsobj) do
        if o then o.isEnabled = true end
      end

      TorqueScript.eval('toggleLightColorViz(true);')
      screenShotName = "screenshots/thumbnail_" .. newVehicle.JBeam .. "_" .. (findValView('prefix') or '') .. configName .. (findValView('suffix') or '') .. tostring(getScreenShotDateTimeString())
      yieldSec(coroutine.yield, 1.0)
      log('I', logTag, "saved screenshot:" .. screenShotName  ..'_li.'..(findValView('imgFormat') or "png"))
      createScreenshot(screenShotName .. '_li', (findValView('imgFormat') or "png"), supersampling)
      yieldSec(coroutine.yield, 1.0)
      for _,o in ipairs(lightsobj) do
        if o then o.isEnabled = false end
      end
      setBackground(findValView("background"), options.backgrounds)
      TorqueScript.eval('toggleLightColorViz(false);')
    end
    setBackground(nil, options.backgrounds)

    commands.setGameCamera()
    core_camera.resetCameraByID(vehicleId)
    yieldSec(coroutine.yield, 0.2)
    core_camera.resetCameraByID(vehicleId)

    settings.setValue('GraphicBorderless', false)
    extensions.ui_visibility.set(true)
    settings.setValue('cameraOrbitSmoothing', true)
  end)
end

local function onExtensionUnloaded()
  log('I', logTag, "module unloaded")
  settings.setValue('GraphicBorderless', false)
end

local function stop()
  forceQuit = true
end

local function redo()
  redoPass = true
  onClientStartMission()
end

local function openWindow()
  windowOpen[0] = true
end

M.onPreRender = onPreRender
M.onInit = onInit
M.onUpdate = onUpdate
M.onClientStartMission = onClientStartMission
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.openWindow = openWindow

M.stop = stop
M.redo = redo

return M
