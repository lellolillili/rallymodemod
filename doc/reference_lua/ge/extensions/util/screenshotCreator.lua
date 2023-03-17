-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"ui_imgui"}
M.state = {show= false}

local workerCoroutine = nil
local forceQuit = false

local workConfig = {}
local ctrls = {} -- imgui controls
local options
local views

local transparentMats = {}

local im = ui_imgui
local guiModule = require("ge/extensions/editor/api/gui")
local gui = {setupEditorGuiTheme = nop}

local windowOpen = im.BoolPtr(false)
local initialWindowSize = im.ImVec2(300, 500)

local vehList --table array  {vehFolder, boolptr, nameStr, config numbr?}

local presetResolutions = { -- name, width, height
  {'thumbnail', 500, 281},
  {'720p'   ,  1280, 720},
  {'1080p'  , 1920, 1080},
  {'Square' , 1920, 1920},
  {'WQHD'   , 2560, 1440},
  {'UWQHD'  , 3440, 1440},
  {'4k'     , 3840, 2160},
  {'8k'     , 8192, 4320},
}

local outputFormats = {'jpg', 'png'}
local updateControls

local function reloadConfig()
  config = jsonReadFile('settings/createThumbnails_config.json')
  options = config.options
  views = config.views
end

local function populateVehGui()
  vehList = {}
  local models = core_vehicles.getModelList().models --because
  local modelKeys={}
  for k,_ in pairs(models) do table.insert(modelKeys,k) end
  table.sort(modelKeys)
  for _,k in ipairs(modelKeys) do
    local v = models[k]
    vehList[_] = {k,im.BoolPtr(false), (v.Brand and (v.Brand.." ") or "") ..v.Name }
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

local function onPreRender(dt)
  if workerCoroutine ~= nil then
    local errorfree, value = coroutine.resume(workerCoroutine)
    if not errorfree then
      log('E', '', "workerCoroutine: "..value)
      log("E", '', debug.traceback(workerCoroutine))
    end
    if coroutine.status(workerCoroutine) == "dead" then
      workerCoroutine = nil
      settings.setValue('GraphicBorderless', false)
      core_settings_graphic.applyGraphicsState()
      extensions.ui_visibility.set(true)
      settings.setValue('cameraOrbitSmoothing', true)
      bullettime.pause(false)
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
  log('I', '', "initialized")
end

local function setDimHelper (useView)
  local canvas = scenetree.findObject("Canvas")
  if not canvas then
    return
  end

  local vm = GFXDevice.getVideoMode()
  if vm.width == useView.width and vm.height == useView.height and vm.displayMode == "Borderless" then
    -- nothing to change
    return
  end
  log('I', '', "requesting new video mode")
  vm.width = useView.width
  vm.height = useView.height
  vm.displayMode = "Borderless"
  -- canvas:setMinExtent(vm.width, vm.height)
  GFXDevice.setVideoMode(vm)
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

local function setBackground(namebackground, bgs)
  for i,v in ipairs(bgs) do
    local obj = scenetree.findObject(v)
    if obj then
      obj:setHidden(true)
    else
      log("E", "setBackground", "Background mesh not found '"..tostring(v).."'")
    end
  end

  -- print("bgs = "..dumps(bgs))
  -- print("getcfg".. dumps(namebackground))
  local ubg = namebackground or bgs[1]
  -- print("using "..dumps(ubg) )
  local obj = scenetree.findObject(ubg)
  if obj then
    obj:setHidden(false)
  else
    log("E", "setBackground", "Background mesh not found '"..tostring(ubg).."'")
  end
end

local function startWork()
  log('I', '', "module loaded")

  if workerCoroutine then
    log('E', "startWork", "coroutine already exist")
    return
  end

  -- set GraphicBorderless to true, to make sure the view dimensions actually are the ones the picture is taken in
  settings.setValue('GraphicBorderless', true)
  settings.setValue('cameraOrbitSmoothing', false)
  settings.setValue('GraphicDynReflectionEnabled', false)
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

    log('I', '', 'Getting config list')
    local configs = core_vehicles.getConfigList(true).configs
    local models = core_vehicles.getModelList().models --because

    local configCount = tableSize(configs)
    log('I', '', table.maxn(configs).." configs")
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

      -- local pcstat = FS:stat("vehicles/"..v.model_key.."/"..v.key..".pc")
      -- local pcdate = 0
      -- if pcstat then
      --     pcdate = pcstat.modtime or 0
      --     log("D", '', "vehicles/"..v.model_key.."/"..v.key..".pc : ctime="..dumps(pcstat.createtime).." mtime="..dumps(pcstat.modtime))
      -- else
      --     log("E", '', "pc FS:stat invalid")
      -- end
      -- local thumbdata = 1e30
      -- for viewName, useView in pairs(views) do
      --     if useView.allow and tableContains(useView.allow, "onlyDefault") then goto nextviewschk end
      --     local tbname = "/vehicles/"..v.model_key.."/"..v.key..(useView.suffix or "")..".png"
      --     local tbstat = FS:stat(tbname)
      --     if tbstat and tbstat.modtime then
      --         log("D", '', tbname.." : ctime="..dumps(tbstat.createtime).." mtime="..dumps(tbstat.modtime))
      --         thumbdata = math.min(thumbdata, tbstat.modtime or 0)
      --     else
      --         log("E", '', "tb FS:stat invalid. fileexist "..dumps(tbname).."="..dumps(FS:fileExists(tbname) ))
      --         if not FS:fileExists(tbname) then pcdate = 1e60 end --missing thumb, force regen
      --     end
      --     ::nextviewschk::
      -- end
      -- log("I", '', "thumbdata = "..dumps(thumbdata))
      -- log("I", '', "pcdate = "..dumps(pcdate))
      -- log("I", '', "isoutdated = "..dumps(pcdate>thumbdata))

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

      -- if( pcdate< thumbdata) then
      --     log("E", '' , "skipConfig "..dumps(v.model_key.."/"..v.key))
      --     goto skipConfig
      -- end

      if models == nil or models[v.model_key] == nil then
        log("E", '', "Model Info  not found for model ='"..v.model_key .."'")
        break
      end
      modelInfo = models[v.model_key]

      -- Replace the vehicle
      log('I', '', string.format("Spawning vehicle %05d / %05d", counter, configCount) .. ' : ' .. ' name: ' .. tostring(v.model_key) .. ', config: ' .. tostring(v.key))
      yieldSec(coroutine.yield, 0.1)
      local playerVehicle = be:getPlayerVehicle(0)
      local oldVehicle = playerVehicle

      oldVehicle:setDynDataFieldbyName("licenseText", 0, "BeamNG")

      core_vehicles.replaceVehicle(v.model_key, { config = v.key, licenseText = options.plate or ' '})
      yieldSec(coroutine.yield, 0.2)

      local newVehicle = oldVehicle
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
      extensions.ui_visibility.set(false)
      bullettime.pause(true)

      for viewName, useView in pairs(views) do
        if forceQuit then
          be:setPhysicsSpeedFactor(1)
          core_camera.speedFactor = 1
          TorqueScriptLua.setVar('$Camera::movementSpeed', '30')
          return
        end

        if useView.allow == nil then
          useView.allow = {}
        end
        -- dump(v.key)
        -- dump(v.aggregates)
        -- print("TYPE ======"..tostring(modelInfo.Type))
        if modelInfo.Type == "Prop" and not tableContains(useView.allow, "Prop") then goto skipView end
        if modelInfo.Type == "Trailer" and not tableContains(useView.allow, "Trailer") then goto skipView end
        if not v.is_default_config and tableContains(useView.allow, "onlyDefault") then goto skipView end
        if options.views ~= nil and not tableContains(options.views, viewName) then goto skipView end
        local findValView = findValConf(useView)

        yieldSec(coroutine.yield, 0.1)
        setDimHelper(useView)
        yieldSec(coroutine.yield, 0.1)



        -- scenetree.hemisphere:setPosition(vec3(pos.x, pos.y, 0))
        -- scenetree.light:setPosition(vec3(pos.x, pos.y, 15))

        local vehicleId = newVehicle:getID()

        core_camera.resetCameraByID(vehicleId)
        core_camera.setFOV(vehicleId, 20 + fovModifier)

        yieldSec(coroutine.yield, 0.1)

        core_camera.resetCameraByID(vehicleId)
        core_camera.setFOV(vehicleId, 20 + fovModifier)



        -- newVehicle:setCamModeByType("orbit")
        --newVehicle:setCamRotation(vec3(-135, 1.3, 0))
        --newVehicle:setCamFOV(20 + fovModifier)
        -- newVehicle:setCamModeByType("onboard.driver")

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
          screenShotName = "vehicles/" .. v.model_key .. "/" .. (findValView('prefix') or '') .. v.key .. (findValView('suffix') or '')
          log('I', '', "saved screenshot:" .. screenShotName  ..'.'..(findValView('imgFormat') or "png"))
          createScreenshot(screenShotName, (findValView('imgFormat') or "png"), supersampling)
          if viewName == "default" and v.is_default_config then
            -- t3d apparently does not like to take two pictures in one frame...
            yieldSec(coroutine.yield, 0.01)
            log('I', '', "saved default:" .. v.model_key  ..'.'..(findValView('imgFormat') or "png"))
            createScreenshot('vehicles/' .. v.model_key .. '/default', (findValView('imgFormat') or "png"), supersampling)
          end
          yieldSec(coroutine.yield, 0.01)
          Engine.imgui.setEnabled(true)
        end

        if findValView("annotation") == "true" then
          yieldSec(coroutine.yield, 0.2)
          TorqueScript.eval('toggleAnnotationVisualize(true);')
          Engine.imgui.setEnabled(false)
          screenShotName = "vehicles/" .. v.model_key .. "/" .. (findValView('prefix') or '') .. v.key .. (findValView('suffix') or '')
          yieldSec(coroutine.yield, 0.1)
          log('I', '', "saved screenshot:" .. screenShotName  ..'_ann.'..(findValView('imgFormat') or "png"))
          createScreenshot(screenShotName ..'_ann', (findValView('imgFormat') or "png"), supersampling)
          yieldSec(coroutine.yield, 0.1)
          TorqueScript.eval('toggleAnnotationVisualize(false);')
          Engine.imgui.setEnabled(true)
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
          log('I', '', "saved screenshot:" .. screenShotName  ..'_li.'..(findValView('imgFormat') or "png"))
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

      ::skipConfig::
    end

    be:setPhysicsSpeedFactor(1)
    core_camera.speedFactor = 1
    TorqueScriptLua.setVar('$Camera::movementSpeed', '30')

  end)
end

-- executed when a level was loaded
local function onClientStartMission(levelPath)
  log('I', '', "onClientStartMission")
  setDimHelper({width = 1600, height = 900})
  startWork()
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if windowOpen[0] ~= true then return end

  local isRunning = workerCoroutine ~= nil

  im.SetNextWindowSize(initialWindowSize, im.Cond_FirstUseEver)

  -- this is not using the editor window api, as this needs to stay visible when the editor is hidden...
  if im.Begin("Vehicle Screenshot Creator", windowOpen) then

    if isRunning then im.BeginDisabled() end
    im.PushStyleColor2(im.Col_Button, im.ImVec4(0,0,0,0))
    if editor.uiIconImageButton(editor.icons.insert_drive_file, nil, nil, nil, nil) then
      workConfig = {}
    end
    if im.IsItemHovered() then im.BeginTooltip() im.Text("New Config") im.EndTooltip() end
    im.SameLine()
    ----
    if editor.uiIconImageButton(editor.icons.folder, nil, nil, nil, nil) then
    end
    if im.IsItemHovered() then im.BeginTooltip() im.Text("Open Config") im.EndTooltip() end
    im.SameLine()
    ----
    if editor.uiIconImageButton(editor.icons.save, nil, nil, nil, nil) then
    end
    if im.IsItemHovered() then im.BeginTooltip() im.Text("Save Config") im.EndTooltip() end
    im.SameLine()

    if isRunning then im.EndDisabled() end

    ----
    if isRunning then
      if editor.uiIconImageButton(editor.icons.stop, nil, im.ImColorByRGB(0,255,0,255).Value, nil, nil) then
        forceQuit = true
      end
      if im.IsItemHovered() then im.BeginTooltip() im.Text("Stop") im.EndTooltip() end
    else
      if editor.uiIconImageButton(editor.icons.play_arrow, nil, im.ImColorByRGB(0,255,0,127).Value, nil, nil) then
        reloadConfig()
        startWork()
      end
      if im.IsItemHovered() then im.BeginTooltip() im.Text("Run") im.EndTooltip() end
    end
    ----

    im.PopStyleColor()

    -- menu end
    -- tabs start

    if isRunning then im.BeginDisabled() end
    if im.BeginTabBar("main Menu##") then
      if im.BeginTabItem('Output') then
        if not ctrls.imageResolution then ctrls.imageResolution = ffi.new("int[3]", { 1920, 1080, 0 }) end
        if im.InputInt2("Image resolution", ctrls.imageResolution) then
          local found = false
          for i, r in ipairs(presetResolutions) do
            if ctrls.commonResolutionsPtr and ctrls.imageResolution[0] == r[2] and ctrls.imageResolution[1] == r[3] then
              ctrls.commonResolutionsPtr[0] = i
              found = true
              break;
            end
          end
          if not found then
            ctrls.commonResolutionsPtr[0] = 0 -- custom
          end
        end

        if not ctrls.commonResolutionsPtr then
          ctrls.commonResolutionsPtr = im.IntPtr(3)
          local s = 'custom\0'
          for _, r in ipairs(presetResolutions) do
            s = s .. r[1] .. ' - ' .. r[2] .. ' x ' .. r[3] .. '\0'
          end
          ctrls.presetResolutionsComboStr = s .. '\0'

        end
        if im.Combo2("Common Resolutions", ctrls.commonResolutionsPtr, ctrls.presetResolutionsComboStr) then
          if ctrls.commonResolutionsPtr[0] > 0 then
            -- ignore custom
            local preset = presetResolutions[ctrls.commonResolutionsPtr[0]]
            ctrls.imageResolution[0] = preset[2]
            ctrls.imageResolution[1] = preset[3]
          end
        end

        if not ctrls.outputFormatPtr then
          ctrls.outputFormatPtr = im.IntPtr(1)
          workConfig.outputFormat = 'png'
          local s = ''
          for _, n in ipairs(outputFormats) do
            s = s .. n .. '\0'
          end
          ctrls.outputFormatsStr = s .. '\0'
        end
        if im.Combo2("File format", ctrls.outputFormatPtr, ctrls.outputFormatsStr) then
          workConfig.outputFormat = outputFormats[ctrls.outputFormatPtr[0] + 1]
        end


        if not ctrls.superSamplingPtr then
          ctrls.superSamplingPtr = im.IntPtr(1)
          workConfig.superSampling = 0
        end
        if im.SliderInt("Supersampling", ctrls.superSamplingPtr, 0, 64) then
          workConfig.superSampling = ctrls.superSamplingPtr[0]
        end

        ----------------------------------------------------------------------------
        local s = math.sqrt(ctrls.superSamplingPtr[0])
        local x = ctrls.imageResolution[0]
        local y = ctrls.imageResolution[1]

        --[[
        local screenSize = im.getCurrentMonitorSize()
        if screenSize.x > 0 and screenSize.y > 0 then
          if x > screenSize.x then
            im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), 'ERROR: Screenshot wider than your screen, will be capped')
            x = screenSize.x
          end
          if y > screenSize.y then
            im.TextColored(im.ImVec4(1.0, 0.0, 0.0, 1.0), 'ERROR: Screenshot higher than your screen, will be capped')
            y = screenSize.y
          end
        end
        --]]

        -- this is the same math as in the c++ side
        local maxSize = math.max(x, y) * math.sqrt(s)
        if x > y then
          y = y * (maxSize / x)
          x = maxSize
        else
          x = x * (maxSize / y)
          y = maxSize
        end
        x = math.floor(x)
        y = math.floor(y)

        im.TextUnformatted('Final resolution: ' .. tostring(x) .. ' x ' .. tostring(y))
        im.TextUnformatted('Megapixel = ' .. string.format('%0.2f', x * y / 1000000))
        local rawSize = x * y * 3 -- RGB = 3 byte
        im.TextUnformatted('Raw image size = ' .. (bytes_to_string(rawSize)))
        if workConfig.outputFormat == 'png' then
          im.TextUnformatted('estimated png file size = ' .. (bytes_to_string(rawSize * 0.5)))
        elseif workConfig.outputFormat == 'jpg' then
          im.TextUnformatted('estimated jpg file size = ' .. (bytes_to_string(rawSize * 0.14)))
        end

        im.EndTabItem()
      end
      if im.BeginTabItem('Vehicle') then
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

        if im.BeginChild1("modelsChild", im.ImVec2(0, 0), true) then
          if vehList then
            for _,v in ipairs(vehList) do
              im.Selectable2(v[1],v[2])
              im.SameLine(200)
              im.TextUnformatted(v[3])
            end
          end
        end
        im.EndChild()
        im.EndTabItem()
      end
      if im.BeginTabItem('Level') then
        im.EndTabItem()
      end
      if im.BeginTabItem('Review/Run') then
        if not isRunning then
          im.TextUnformatted("Ready")
        else --running
          if forceQuit then
            im.TextUnformatted("Will stop")
          else
            im.TextUnformatted("Running")
          end
        end

        im.EndTabItem()
      end
    end
    im.EndTabBar()

    if isRunning then im.EndDisabled() end
  end
  im.End()
end

local function onExtensionLoaded()
  guiModule.initialize(gui)
  populateVehGui()
  settings.setValue('GraphicDynReflectionEnabled', false)
end

local function onExtensionUnloaded()
  log('I', '', "module unloaded")
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

local function onSerialize()
  return { windowOpen = windowOpen[0] }
end

local function onDeserialized(data)
  if data.windowOpen ~= nil then
    windowOpen[0] = data.windowOpen
  end
end

M.onPreRender = onPreRender
M.onInit = onInit
M.onUpdate = onUpdate
M.onClientStartMission = onClientStartMission
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.openWindow = openWindow

M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.stop = stop
M.redo = redo

return M
