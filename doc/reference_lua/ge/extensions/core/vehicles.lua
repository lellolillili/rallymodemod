-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local min, max, random = math.min, math.max, math.random
local pathDefaultConfig = "settings/default.pc"

local M = {}

--M.forceLicenceStr = 'BeamNG' -- enables to force a license plate text

M.defaultVehicleModel = string.match(beamng_appname, 'research') and 'etk800' or 'pickup'

local filtersWhiteList = { "Drivetrain", "Type", "Config Type", "Transmission", "Country", "Derby Class", "Performance Class",
 "Value", "Brand", "Body Style", "Source", "Weight", "Top Speed", "0-100 km/h", "0-60 mph", "Weight/Power", "Off-Road Score", "Years", 'Propulsion', 'Fuel Type', 'Induction Type' }

local range = {'Years'}
local beamStats = {}

-- agregates only, attribute stays the same
local convertToRange = { 'Value', 'Weight', 'Top Speed', '0-100 km/h', '0-60 mph', 'Weight/Power', "Off-Road Score" }

-- so the ui knows when to interpret the data as range
local finalRanges = {}
arrayConcat(finalRanges, range)
arrayConcat(finalRanges, convertToRange)

local displayInfo = {
  ranges = {
    all = finalRanges,
    real = range
  },
  units = {
    Weight = {type = 'weight', dec = 0},
    ['Top Speed'] = {type = 'speed', dec = 0},
    ['Torque'] = {type = 'torque', dec = 0},
    ['Power'] = {type = 'power', dec = 0},
    ['Weight/Power'] = {type = 'weightPower', dec = 2},
  },
  predefinedUnits = {
    ['0-60 mph'] = {unit = 's', type = 'speed', ifIs = 'mph', dec = 1},
    ['0-100 mph'] = {unit = 's', type = 'speed', ifIs = 'mph', dec = 1},
    ['0-200 mph'] = {unit = 's', type = 'speed', ifIs = 'mph', dec = 1},
    ['60-100 mph'] = {unit = 's', type = 'speed', ifIs = 'mph', dec = 1},
    ['0-100 km/h'] = {unit = 's', type = 'speed', ifIs = 'km/h', dec = 1},
    ['0-200 km/h'] = {unit = 's', type = 'speed', ifIs = 'km/h', dec = 1},
    ['0-300 km/h'] = {unit = 's', type = 'speed', ifIs = 'km/h', dec = 1},
    ['100-200 km/h'] = {unit = 's', type = 'speed', ifIs = 'km/h', dec = 1},
    ['100-0 km/h'] = {unit = 'm', type = 'length', ifIs = 'm', dec = 1},
    ['60-0 mph'] = {unit = 'ft', type = 'length', ifIs = 'ft', dec = 1}
  },
  dontShowInDetails = { 'Type', 'Config Type' },
  perfData = { '0-60 mph', '0-100 mph', '0-200 mph', '60-100 mph', '60-0 mph', '0-100 km/h', '0-200 km/h', '0-300 km/h', '100-200 km/h', '100-0 km/h', 'Braking G', 'Top Speed', 'Weight/Power', 'Off-Road Score', 'Propulsion', 'Fuel Type', 'Drivetrain', 'Transmission', 'Induction Type' },
  filterData = filtersWhiteList
}

-- TODO: Think about only operating on cache and not cache + local variable in function
local showStandalonePcs = settings.getValue('showStandalonePcs')
local SteamLicensePlateVehicleId
local cache = {}
local anyCacheFileModified = false

local function _parseVehicleNameBackwardCompatibility(vehicleName)
  -- try to read the name.cs
  local nameCS = "/vehicles/" .. vehicleName .. "/name.cs"
  local res = { configs = {} }
  local f = io.open(nameCS, "r")
  if f then
    for line in f:lines() do
      local key, value = line:match("^%%(%w+)%s-=%s-\"(.+)\";")
      if key ~= nil and key == "vehicleName" and value ~= nil then
        res.Name = value
      end
    end
    f:close()
  end

  -- get .pc files and fix them up for the new system
  local pcfiles = FS:findFiles("/vehicles/" .. vehicleName .. "/", "*.pc", 0, true, false)
  for _, fn in pairs(pcfiles) do
    local dir, filename, ext = path.split(fn)
    if dir and filename and ext and string.lower(ext) == "pc" then
      local pcfn = filename:sub(1, #filename - 3)
      res.configs[pcfn] = { Configuration = pcfn}
    end
  end

  -- no name fallback
  if res.Name == nil then
    res.Name = vehicleName
  end

  -- type fallback
  res.Type = "Car"
  return res
end

local function _fillAggregates(data, destination)
  for key, value in pairs(data) do
    if tableContains(range, key) then
      if not destination[key] then
        destination[key] = deepcopy(data[key])
      else
        destination[key].min = min(data[key].min, destination[key].min)
        destination[key].max = max(data[key].max, destination[key].max)
      end
    elseif tableContains(convertToRange, key) then
      if type(data[key]) == 'number' then
        if not destination[key] then
          destination[key] = {min = data[key], max = data[key]}
        end
        destination[key].min = min(data[key], destination[key].min)
        destination[key].max = max(data[key], destination[key].max)
      end
    elseif tableContains(filtersWhiteList, key) then
      if not destination[key] then
        destination[key] = {}
      end

      destination[key][value] = true
    end
  end
end

local function _mergeAggregates(data, destination)
  for key, value in pairs(data) do
    if tableContains(range, key) or tableContains(convertToRange, key) then
      if not destination[key] then
        destination[key] = deepcopy(data[key])
      else
        destination[key].min = min(data[key].min, destination[key].min)
        destination[key].max = max(data[key].max, destination[key].max)
      end
    elseif tableContains(filtersWhiteList, key) then
      if not destination[key] then
        destination[key] = deepcopy(data[key])
      else
        for key2, _ in pairs(value) do
          destination[key][key2] = true
        end
      end
    end
  end
end

-- gets all files related to vehicle info
local p
local function computeFilesCaches()
  local jfiles = FS:findFiles("/vehicles/", "info*.json\t*.pc\t*.png\t*.jpg", -1, true, true)
  if p then p:add("find") end
  local filesJson, filesPC, filesImages, filesParsed = {}, {}, {}, {}
  for _, filename in ipairs(jfiles) do
    if string.lower(filename:sub(-5)) == '.json' then
      table.insert(filesJson, filename)
    elseif string.lower(filename:sub(-3)) == '.pc' then
      table.insert(filesPC, filename)
    elseif string.lower(filename:sub(-4)) == '.png' or string.lower(filename:sub(-4)) == '.jpg' then
      filesImages[filename] = true
    else
      log('E', 'vehicles', 'Bug in vehicles.lua code (unrecognized file: '.. filename..')')
    end
  end
  if p then p:add("classify") end
  for _, fn in ipairs(filesJson) do
    local data = readFile(fn)
    if p then p:add("json read") end
    if data then
      data = jsonDecode(data)
      if p then p:add("json decode") end
      if not data then
        log('E', 'vehicles', 'unable to read info file, ignoring: '.. fn)
      else
        filesParsed[fn] = data
      end
    else
      log('E', 'vehicles', 'unable to read file, ignoring: '.. fn)
    end
    if p then p:add("json end") end
  end
  for _, fn in ipairs(filesPC) do
    local data = readFile(fn)
    if p then p:add("pc read") end
    if data then
      data = jsonDecode(data)
      if p then p:add("pc decode") end
      if not data then
        log('E', 'vehicles', 'unable to read PC file, ignoring: '.. fn)
      else
        filesParsed[fn] = data
      end
    else
      log('E', 'vehicles', 'unable to read file, ignoring: '.. fn)
    end
    if p then p:add("pc end") end
  end
  return filesJson, filesPC, filesImages, filesParsed
end

local filesJsonCache, filesPCCache, filesImagesCache, filesParsedCache
local function getFilesJson()
  if not filesJsonCache then filesJsonCache, filesPCCache, filesImagesCache, filesParsedCache = computeFilesCaches() end
  return filesJsonCache
end

local function getFilesPC()
  if not filesPCCache then filesJsonCache, filesPCCache, filesImagesCache, filesParsedCache = computeFilesCaches() end
  return filesPCCache
end

local function getFilesImages()
  if not filesImagesCache then filesJsonCache, filesPCCache, filesImagesCache, filesParsedCache = computeFilesCaches() end
  return filesImagesCache
end

local function getFilesParsed()
  if not filesParsedCache then filesJsonCache, filesPCCache, filesImagesCache, filesParsedCache = computeFilesCaches() end
  return filesParsedCache
end

-- returns all found model names
local modelsDataCache
local function getModelsData()
  if not modelsDataCache then
    local modelsData = {}

    local modelRegex  = "^/vehicles/([%w|_|%-|%s]+)/info[_]?(.*)%.json"
    local modelRegexPC  = "^/vehicles/([%w|_|%-|%s]+)/(.*)%.pc"
    local modelRegexDir  = "^/vehicles/([%w|_|%-|%s]+)"

    -- Get the models. They are the directories one level under vehicles folder
    for _, path in ipairs(getFilesJson()) do
      -- name of a file or directory can have alphanumerics, hyphens and underscores.
      local model, configName = string.match(path, modelRegex)
      if model then
        if not modelsData[model] then modelsData[model] = { info = {}, configs = {}} end
        modelsData[model]['info'][path] = configName
      else
        log("E", "", string.format("Unable to understand vehicle path %s (attempted regex was: %s)", dumps(path), dumps(modelRegex)))
      end
    end

    for _, path in ipairs(getFilesPC()) do
      local model, configName = string.match(path, modelRegexPC)
      if model then
        if not modelsData[model] then
          if showStandalonePcs then
            modelsData[model] = { info = {}, configs = {}}
          else
            log('W', '', 'standalone pc file without info file ignored: ' .. tostring(path))
          end
        end
        if modelsData[model] then
          local addIt = true
          if not showStandalonePcs then
            local infoFilename = "/vehicles/" .. model .. "/info_" .. configName .. ".json"
            if not modelsData[model]['info'][infoFilename] then
              --log('W', '', 'Vehicle config does not have an info file: ' .. tostring(path) .. '. Ignoring the file.')
              addIt = false
            end
          end
          if addIt then
            modelsData[model]['configs'][path] = configName
          end
        end
      else
        log('E', '', 'Malformed pc json: ' .. tostring(path))
      end
    end

    -- find any vehicles without configurations
    local vehicleDirs = FS:directoryList('/vehicles/', false, true)
    for _, path in ipairs(vehicleDirs) do
      local model = string.match(path, modelRegexDir)
      if model then
        if not modelsData[model] and model ~= 'common' then
          -- ok, we don't know about this vehicle, lets figure out if there are jbeam files in there
          local jbeamFiles = FS:findFiles(path .. '/', "*.jbeam", 0, false, false)
          if #jbeamFiles > 0 then
            -- ok, look if the mainpart is somewhere in there ...
            local mainPartFound = false
            for _, fn in ipairs(jbeamFiles) do
              local fileData = jsonReadFile(fn)
              if fileData then
                for partName, part in pairs(fileData) do
                  if part.slotType == 'main' then
                    mainPartFound = true
                    break
                  end
                end
                if mainPartFound then break end
              end
            end
            if not mainPartFound then
              log('W', '', 'Warning: vehicle folder does not contain a configuration or a valid main part: ' .. tostring(path))
            else
              log('W', '', 'Warning: vehicle folder containing main part but no info or config: ' .. tostring(path))
              -- adding the model anyways so the default configuration is spawn-able
              modelsData[model] = { info = {}, configs = {}}
            end
          else
            log('W', '', 'Warning: vehicle folder does not contain any jbeam files: ' .. tostring(path) .. '. Ignored.')
          end
        end
      else
        log("E", "", string.format("Unable to understand vehicle path %s (attempted regex was: %s)", dumps(path), dumps(modelRegexDir)))
      end
    end

    --dump(modelsData)
    modelsDataCache = modelsData
  end
  return modelsDataCache
end

local _cachedGamePath = FS:getGamePath()
local function _isOfficialContentVPathFast(vpath)
  return string.startswith(FS:getFileRealPath(vpath), _cachedGamePath)
end

local function getSourceAttr(path)
  if _isOfficialContentVPathFast(path) then
    return 'BeamNG - Official'
  elseif string.sub(path, -3) == '.pc' then
    return 'Custom'
  else
    return 'Mod'
  end
end

local function convertVehicleInfo(info)
  -- log('I', 'convert', 'Convert vehicle info: '..dump(info))
  local color = {x=0,y=0,z=0,w=0}
  local metallicData = {}
  local paints = {}
  for name, data in pairs(info.colors or {}) do
    if type(data) == 'string' then
      local colorTable = stringToTable(data)
      color.x = tonumber(colorTable[1])
      color.y = tonumber(colorTable[2])
      color.z = tonumber(colorTable[3])
      color.w = tonumber(colorTable[4])
      metallicData[1] = tonumber(colorTable[5])
      metallicData[2] = tonumber(colorTable[6])
      metallicData[3] = tonumber(colorTable[7])
      metallicData[4] = tonumber(colorTable[8])
      -- log('I','convert', name..' colorTable: '..dumps(colorTable)..' color: '..dumps(color)..' metallicData: '..dumps(metallicData))
      local paint = createVehiclePaint(color, metallicData)
      paints[name] = paint
    end
  end
  if not tableIsEmpty(paints) then
    info.paints = paints
    info.colors = nil
  end
  info.defaultPaintName1 = info.default_color
  info.default_color = nil

  info.defaultPaintName2 = info.default_color_2
  info.default_color_2 = nil

  info.defaultPaintName3 = info.default_color_3
  info.default_color_3 = nil
  return info
end

local function  _imageExistsDefault(...)
  for _, path in ipairs({...}) do
    if getFilesImages()[path] then
      return path
    end
  end
  return '/ui/images/appDefault.png'
end

local function _modelConfigsHelper(key, model, ignoreCache)
  --dump{'_modelConfigsHelper', key, model}
  if type(key) ~= 'string' then return nil end
  local vehFiles = getModelsData()[key]
  if not vehFiles then
    log('E', '', 'Vehicle not available: ' .. tostring(key))
    return nil
  end

  if cache[key].configs and not ignoreCache then
    return cache[key].configs
  end

  if not cache[key].configs then
    cache[key].configs = {}
  end

  local configs = {}

  for configFilename, configName in pairs(vehFiles.configs) do
    local contentSource = getSourceAttr(configFilename)
    local infoFilename = "/vehicles/" .. key .. "/info_" .. configName .. ".json"
    local readData = {}
    if vehFiles.info[infoFilename] and getFilesParsed()[infoFilename] then
      readData = getFilesParsed()[infoFilename]
    else
      if FS:fileExists(infoFilename) then
        log('E', 'vehicles', 'unable to read info file, ignoring: '.. infoFilename)
      end
      infoFilename = nil
    end

    if not readData and contentSource ~= 'Custom' then
      log('W', 'vehicles', 'unable to find info file: '.. infoFilename)
    end

    if readData.colors or readData.default_color or readData.default_color_2 or readData.default_color_3 then
      convertVehicleInfo(readData)
    end


    local configData = readData
    --configData.infoFilename = infoFilename
    --configData.pcFilename = configFilename

    configData.Source = contentSource

    if model.default_pc == nil then
      model.default_pc = configName
    end

    -- makes life easier
    configData.model_key = key
    configData.key = configName
    configData.aggregates = {}

    if not configData.Configuration then
      configData.Configuration = configName
    end
    configData.Name = model.Name .. " " .. configData.Configuration

    configData.preview = _imageExistsDefault('/vehicles/' .. key .. '/' .. configName .. '.png', '/vehicles/' .. key .. '/' .. configName .. '.jpg')

    if configData.defaultPaintName1 ~= nil and configData.defaultPaintName1 ~= '' then
      if not model.paints then
        model.paints = model.paints or {}
        log('E', 'vehicles', key..':'..configName..': cannot set default paint for model with no paints data.')
      end

      configData.defaultPaint = model.paints[configData.defaultPaintName1]
    end

    if configData.Value then --if we have a value number
      configData.Value = tonumber(configData.Value) or configData.Value --make sure it's actually a NUMBER and not a string
    end

    configData.is_default_config = (configName == model.default_pc)

    if readData then
      _fillAggregates(readData, configData.aggregates)
    end

    --configData.mod, configData.modFingerprint = extensions.core_modmanager.getModFromPath(configFilename, true) -- TODO: FIXME: SUPER SLOW

    configs[configName] = configData
  end

  return configs
end

-- get all info to one model
local function getModel(key)
  if type(key) ~= 'string' then return {} end
  if not getModelsData()[key] then
    log('E', '', 'Vehicle not available: ' .. tostring(key))
    return {}
  end

  if cache[key] then
    return cache[key]
  end

  local infoFilename = "/vehicles/"..key.."/info.json"
  local data = getFilesParsed()[infoFilename]
  if data and (data.colors or data.default_color or data.default_color_2 or data.default_color_3) then
    convertVehicleInfo(data)
  end

  local fixedVehicle = false
  if data == nil then
    data = _parseVehicleNameBackwardCompatibility(key)
    fixedVehicle = true
  end

  -- Patch up old vehicles for new System
  local missingInfoConfigs = nil
  if data.configs then
    missingInfoConfigs = data.configs
    for mConfigName, mConfig in pairs(missingInfoConfigs) do
      mConfig.is_default_config = false
      if not data.default_pc then
        data.default_pc = mConfigName
        mConfig.is_default_config = true
      end
      mConfig.aggregates = {}
      mConfig.Configuration = mConfigName
      mConfig.Name = data.Name .. ' ' .. mConfigName
      mConfig.key = mConfigName
      mConfig.model_key = key
      mConfig.preview = _imageExistsDefault('/vehicles/' .. key .. '/' .. mConfigName .. '.png', '/vehicles/' .. key .. '/' .. mConfigName .. '.jpg')
    end
    data.configs = nil
  end

  local model = {}
  if data then
    model = deepcopy(data)

    if not data.Type then
      model.Type = "Unknown"
      --log('E', 'vehicles', "model" .. dumps(model) .. "has type \"Unknown\"")
    end

    model.aggregates = {} -- values for filtering
  end

  -- get preview if it exists
  model.preview = _imageExistsDefault('/vehicles/' .. key .. '/default.png', '/vehicles/' .. key .. '/default.jpg')

  --model.infoFilename = infoFilename
  --model.pcFilename = ''

  model.logo = _imageExistsDefault('/vehicles/' .. key .. '/logo.png', '/vehicles/' .. key .. '/logo.jpg')

  if model.defaultPaintName1 then
    if model.paints then
      model.defaultPaint = model.paints[model.defaultPaintName1]
    end
  else
    model.defaultPaint = {}
    model.defaultPaintName1 = ""
  end

  model.key = key -- redundant but makes life easy

  -- figure out the mod this belongs to
  --model.mod, model.modFingerprint = extensions.core_modmanager.getModFromPath(infoFilename, true) -- TODO: FIXME: SUPER SLOW

  cache[key] = {}
  cache[key].model = model

  cache[key].configs = missingInfoConfigs or _modelConfigsHelper(key, model, ignoreCache)

  if cache[key].configs and tableSize(cache[key].configs) < 1 then
    cache[key].configs[key] = deepcopy(model)
    if cache[key].configs[key].model_key == nil then
      cache[key].configs[key].model_key = cache[key].configs[key].key
    end
    if cache[key].model.default_pc == nil then
      cache[key].model.default_pc = key
    end
  end

  if data then
    data.Source = getSourceAttr(infoFilename)

    if fixedVehicle then
      data.Source = 'Mod'
    end

    _fillAggregates(data, model.aggregates)
  end

  -- all configs should have the same aggregates as the base model
  -- the model should have all aggregates of the configs
  local aggHelper = {}
  for _, config in pairs(cache[key].configs) do
    _mergeAggregates(config.aggregates, aggHelper)
    -- I remember removing this in rev 40591 but i cannot tell why that was. The only difference now is that the merge function is "fixed" and never should overwrite values
    _mergeAggregates(cache[key].model.aggregates, config.aggregates)
  end
  _mergeAggregates(aggHelper, cache[key].model.aggregates)

  return cache[key]
end

-- returns the key of the current vehicle (of player one)
-- one could also use: playerVehicle:getJBeamFilename()
local function getVehicleDetails(id)
  local res = {}
  local vehicle = be:getObjectByID(id)
  if vehicle then
    res.key       = vehicle.JBeam
    res.pc_file   = vehicle.partConfig
    res.position  = vehicle:getPosition()
    res.color     = vehicle.color
  end

  local model = res.key and getModel(res.key) or {}
  local config = {}
  local default = res.pc_file == pathDefaultConfig
  if res.pc_file ~= nil then
    res.config_key = string.match(res.pc_file, "vehicles/".. res.key .."/(.*).pc")
    config = model.configs[res.config_key] or model.model
  end
  return {current = res, model = model.model, configs = config, userDefault = default}
end

-- returns the key of the current vehicle (of player one)
-- one could also use: playerVehicle:getJBeamFilename()
local function getCurrentVehicleDetails()
  return getVehicleDetails(be:getPlayerVehicleID(0))
end


local function createFilters(list)
  local filter = {}

  if list then
    for _, value in pairs(list) do
      for propName, propVal in pairs(value.aggregates) do
        if tableContains(finalRanges, propName) then
          if filter[propName] then
            filter[propName].min = min(value.aggregates[propName].min, filter[propName].min)
            filter[propName].max = max(value.aggregates[propName].max, filter[propName].max)
          else
            filter[propName] = deepcopy(value.aggregates[propName])
          end
        else
          if not filter[propName] then
            filter[propName] = {}
          end
          for key,_ in pairs(propVal) do
            filter[propName][key .. ''] = true
          end
        end
      end
    end
  end

  return filter
end

-- get the list of all available models
local function getModelList(array)
  local models = {}
  for modelName, _ in pairs(getModelsData()) do
    local model = getModel(modelName)
    if array then
      table.insert(models, model.model)
    else
      models[model.model.key] = model.model
    end
  end
  return {models = models, filters = createFilters(models), displayInfo = displayInfo}
end

-- get the list of all available configurations
local function getConfigList(array)
  local configList = {}
  for modelName, _ in pairs(getModelsData()) do
    local model = getModel(modelName)
    -- dump(model.configs)
    if model.configs and not tableIsEmpty(model.configs) then
      for _, config in pairs(model.configs) do
        if array then
          table.insert(configList, config)
        else
          -- dump(config)
          configList[config.model_key .. '_' .. config.key] = config
        end
      end
    end
  end
  return {configs = configList, filters = createFilters(configList), displayInfo = displayInfo}
end

-- get the list of all available vehicles for ui
local function notifyUI()
  p = LuaProfiler("Vehicle Selector menu")
  p:start()
  local modelList, configList = {}, {}
  for modelName, _ in pairs(getModelsData()) do
    p:add("model begin")
    local model = getModel(modelName)
    p:add("model get")
    table.insert(modelList, model.model)
    p:add("model insert")
    for _, config in pairs(model.configs or {}) do
      table.insert(configList, config)
    end
    p:add("model configs")
  end

  if career_career.isCareerActive() and gameplay_garageMode.getGarageMenuState() == "myCars" then
    local vehicles = career_modules_inventory.vehicles
    configList = {}
    for id, vehicle in pairs(vehicles) do
      -- configList
      local configInfo = {}
      configInfo.Name = id .. " - " .. (vehicle.niceName or vehicle.model)
      configInfo.model_key = vehicle.model
      configInfo.preview = "/vehicles/" .. vehicle.model .. "/default.jpg"
      configInfo.is_default_config = true
      configInfo.key = nil
      configInfo.aggregates = {Source = {
        ["Career"] = true
      },
      Type = {
        Car = true
      }}
      configInfo.Source = "Career"
      configInfo.spawnFunction = "career_modules_inventory.enterVehicle(" .. id .. ")"
      table.insert(configList, configInfo)
    end
  end

  guihooks.trigger('sendVehicleList', {models = modelList, configs = configList, filters = createFilters(modelList), displayInfo = displayInfo})
  p:add("CEF request")
end

local function notifyUIEnd()
  if p then p:add("CEF side") end
  if p then p:finish() end
  p = nil
end

local function getVehicleList()
  local models = getModelList(true).models
  local vehicles = {}
  for i,m in pairs(models) do
    local vehicle = getModel(m.key)
    if vehicle ~= nil then
      table.insert(vehicles, vehicle)
    end
  end
  return {vehicles = vehicles, filters = createFilters(models)}
end

local function finalizeSpawn(options)
  local firstVehicle = be:getObjectCount() == 0
  if firstVehicle then
    local player = 0
    be:enterNextVehicle(player, 0) -- enter any vehicle
  end

  local vehicle = be:getPlayerVehicle(0)
  if vehicle then
    if options.licenseText then
      vehicle:setDynDataFieldbyName("licenseText", 0, options.licenseText)
    end

    if options.vehicleName then
      vehicle:setField('name', '', options.vehicleName)
    end

    if be:getObjectCount() > 1 then
      if vehicle:getField('JBeam','0') ~= "unicycle" then
        ui_message("ui.hints.switchVehicle", 10, "spawn")
      end
    end
  end
end

local function spawnNewVehicle(model, opt)
  local options = sanitizeVehicleSpawnOptions(model, opt)
  local veh = spawn.spawnVehicle(model, options.config, options.pos, options.rot, options)
  finalizeSpawn(options)
  return veh
end

local function replaceCurrentVehicle(model, opt)
  opt.model = model
  local playerVeh = be:getPlayerVehicle(0)
  opt.licenseText = playerVeh.licenseText -- copy the current license text
  local options = sanitizeVehicleSpawnOptions(model, opt)
  if options.cling == nil then
    options.cling = true
  end
  spawn.setVehicleObject(playerVeh, options)
  finalizeSpawn(options)
  return playerVeh
end

local function removeCurrent()
  local vehicle = be:getPlayerVehicle(0)
  if vehicle then
    vehicle:delete()
    if be:getEnterableObjectCount() == 0 then
      commands.setFreeCamera() -- reuse current vehicle camera position for free camera, before removing vehicle
    end
  end
end

local function replaceVehicle(model, opt)
  local current = be:getPlayerVehicle(0)
  -- when no vehicle is spawned, spawn a new one instead
  if not current then
    return spawnNewVehicle(model, opt)
  else -- spawn new vehicle in place and remove current
    opt.model = model
    opt.pos = current:getPosition()
    opt.vehicleName = current:getField('name', '')
    current:setDynDataFieldbyName("autoEnterVehicle", 0, "false")
    local vehicle = replaceCurrentVehicle(model, opt)
    vehicle:setDynDataFieldbyName("autoEnterVehicle", 0, "true")
    be:enterVehicle(0, vehicle)
    extensions.hook("onVehicleReplaced",vehicle:getID())
    return vehicle
  end
end

local function removeAllExceptCurrent()
  local vid = be:getPlayerVehicleID(0)
  for i = be:getObjectCount()-1, 0, -1 do
    local veh = be:getObject(i)
    if veh:getId() ~= vid then
      veh:delete()
    end
  end
end

local function cloneCurrent()
  local veh = be:getPlayerVehicle(0)
  if not veh then
    log('E', 'vehicles', 'unable to clone vehicle: player 0 vehicle not found')
    return false
  end

  -- we get the current vehicles parameters and feed it into the spawning function
  local metallicPaintData = veh:getMetallicPaintData()
  local options = {
    model  = veh.JBeam,
    config = veh.partConfig,
    paint  = createVehiclePaint(veh.color, metallicPaintData[1]),
    paint2 = createVehiclePaint(veh.colorPalette0, metallicPaintData[2]),
    paint3 = createVehiclePaint(veh.colorPalette1, metallicPaintData[3])
  }

  spawnNewVehicle(veh.JBeam, options)
end

local function removeAll()
  local vehicle = be:getPlayerVehicle(0)
  if vehicle then
    commands.setFreeCamera() -- reuse current vehicle camera position for free camera, before removing vehicles
  end
  for i = be:getObjectCount()-1, 0, -1 do
    be:getObject(i):delete()
  end
end

local function clearCache()
  anyCacheFileModified = false
  filesJsonCache = nil
  filesPCCache = nil
  filesImagesCache = nil
  filesParsedCache = nil
  table.clear(cache)
  modelsDataCache = nil
end

local function onFileChanged(filename, type)
  if string.find(filename, '/vehicles/') == 1 or string.find(filename, '/mods/') == 1 then
    local fLower = string.lower(filename)
    if string.sub(fLower, -5) == '.json'
    or string.sub(fLower, -6) == '.jbeam'
    or string.sub(fLower, -3) == '.pc'
    or string.sub(fLower, -4) == '.jpg'
    or string.sub(fLower, -4) == '.png' then
      anyCacheFileModified = true
    end
  end
end

local function onFileChangedEnd()
  if anyCacheFileModified then
    clearCache()
  end
end

local function onSettingsChanged()
  local showStandalonePcsNew = settings.getValue('showStandalonePcs')
  if showStandalonePcsNew ~= showStandalonePcs  then
    clearCache()
    showStandalonePcs = showStandalonePcsNew
  end
end

local function generateLicenceText(designData,veh)
  local T = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'}
  if not designData then
    --default_gen
    return T[random(1, #T)] .. T[random(1, #T)] .. T[random(1, #T)] ..'-'..random(0, 9)..random(0, 9)..random(0, 9)..random(0, 9)
  else
    if not designData.gen or not designData.gen.pattern then
      return generateLicenceText() --go back to default
    end

    local formattxt = veh:getDynDataFieldbyName("licenseFormats", 0)
    local formats = {}
    if formattxt and string.len(formattxt) >0 then
      formats = jsonDecode(formattxt )
    else
      formats = {"30-15"}
    end
    for _,v in ipairs(formats)do
      if designData.format[v] and designData.format[v].gen then
        if designData.format[v].gen.pattern then
          designData.gen.pattern = designData.format[v].gen.pattern
        end
        if designData.format[v].gen.patternData then
          tableMerge(designData.gen.patternData, designData.format[v].gen.patternData )
        end
      end
    end

    if not designData.gen.patternData then
      designData.gen.patternData = {}
    end

    local strtmp = designData.gen.pattern
    if type(strtmp) == "table" then
      strtmp = strtmp[random(1, #strtmp)]
    end
    designData.gen.patternData.c = function() return T[random(1, #T)] end
    designData.gen.patternData.D = function() return random(1, 9) end
    designData.gen.patternData.d = function() return random(0, 9) end
    designData.gen.patternData.vid = function() if veh then return veh:getId() else return 0 end end
    designData.gen.patternData.vname = function() if veh then return veh:getJBeamFilename() else return "" end end

    for k,fn in pairs(designData.gen.patternData) do
      if type(fn) == "table" then
        local tmpfn = function() return fn[random(1, #fn)]  end --return one random for each use instead of same
        strtmp = string.gsub(strtmp, "%%"..k, tmpfn)
      else
        strtmp = string.gsub(strtmp, "%%"..k, fn)
      end
    end
    strtmp = string.gsub(strtmp, "%%%%", "%%")
    return strtmp

    -- return string.gsub(designData.gen.pattern, "%%([^%%])", designData.gen.patternData)
  end
end

local function makeVehicleLicenseText(veh, designPath)
  if forceLicenceStr then
    return forceLicenceStr
  end

  if FS:fileExists("settings/cloud/forceLicencePlate.txt") then
    local content = readFile("settings/cloud/forceLicencePlate.txt")
    if content ~= nil then
      log("D","makeVehicleLicenseText","forced to used LicencePlate.txt = '"..tostring(content).."'")
      return content
    end
  end

  veh = veh or be:getPlayerVehicle(0)
  if type(veh) == 'number' then
    veh = be:getObjectByID(veh)
  end
  if not veh then return '' end

  local txt = veh:getDynDataFieldbyName("licenseText", 0)
  if txt and txt:len() > 0 then
    return txt
  end

  local design = nil
  if designPath then
    design = jsonReadFile(designPath)
  end

  if settings.getValue('useSteamName') and veh.autoEnterVehicle and SteamLicensePlateVehicleId == nil and Steam and Steam.isWorking and Steam.accountLoggedIn then
    SteamLicensePlateVehicleId = veh:getId()
    txt = Steam.playerName
    --print("steam username: " .. Steam.playerName)
    txt = txt:gsub('"', "'") -- replace " with '
    -- more cleaning up required?
  elseif not design or not design.data or not design.version or (design.version and design.version == 1) then
    txt = generateLicenceText()
  elseif design.version and design.version > 1 then
    txt = generateLicenceText(design.data or nil, veh)
  end

  return txt
end

local function regenerateVehicleLicenseText(veh)
  local generated_txt = ""
  if veh then
    local current_txt = veh:getDynDataFieldbyName("licenseText", 0)
    veh:setDynDataFieldbyName("licenseText", 0, "")
    local designPath = veh:getDynDataFieldbyName("licenseDesign", 0) or ''
    generated_txt = makeVehicleLicenseText(veh, designPath)
    veh:setDynDataFieldbyName("licenseText", 0, current_txt)
  end
  return generated_txt
end

local function getVehicleLicenseText(veh)
  local licenseText = ""
  if veh then
    licenseText = veh:getDynDataFieldbyName("licenseText", 0)
  end
  return licenseText
end

-- nil values are equal last values
local function setPlateText(txt, vehId, designPath, formats)
  local veh = nil
  if vehId then
    veh = be:getObjectByID(vehId)
  else
    veh = be:getPlayerVehicle(0)
  end
  if not veh then return end
  if not formats then
    local formattxt = veh:getDynDataFieldbyName("licenseFormats", 0)
    if formattxt and string.len(formattxt) >0 then
      formats = jsonDecode(formattxt )
    else
      formats = {"30-15"}
    end
  end

  if not designPath then
    designPath = veh:getDynDataFieldbyName("licenseDesign", 0) or ''
  end

  local design
  if designPath and designPath~="" and FS:fileExists(designPath) then
    design = jsonReadFile(designPath)
  end
  -- dump(design)
  if not design or not design.data then
    if designPath:len() > 0 then
      log('E', 'setPlateText', "License plate "..designPath.." not existing")
    end
    local levelName = core_levels.getLevelName(getMissionFilename())
    if levelName then
      -- log('E', 'setPlateText', "levelName = "..tostring(levelName))
      designPath =  'vehicles/common/licenseplates/'..levelName..'/licensePlate-default.json'
      if FS:fileExists(designPath) then
        design = jsonReadFile(designPath)
      end
    end
  end

  if not design or not design.data then
    designPath = 'vehicles/common/licenseplates/default/licensePlate-default.json'
    design = jsonReadFile(designPath)
  end

  if not txt then
    txt = makeVehicleLicenseText(veh, designPath)
  end

  local currentFormat = veh:getDynDataFieldbyName("licenseFormats", 0)
  local currentDesign = veh:getDynDataFieldbyName("licenseDesign", 0)
  local currentText = veh:getDynDataFieldbyName("licenseText", 0)

  if (currentFormat == formats and designPath == currentDesign and txt == currentText) then return end;

  veh:setDynDataFieldbyName("licenseFormats", 0, jsonEncode(formats))
  veh:setDynDataFieldbyName("licenseDesign", 0, designPath)
  veh:setDynDataFieldbyName("licenseText", 0, txt)

  ----adding licenseplate html generator and characterlayout to Json file

  if design then
    local designData = nil
    if design.version == 1 then
      local dtmp = {}; dtmp.data={};dtmp.data.format={}
      dtmp.data.format["30-15"] = design.data
      design = dtmp;
    end
    for _,curFormat in pairs(formats) do
      designData={}; designData.data=design.data.format[curFormat]
      local textureTagPrefix = "@licenseplate-default"
      if curFormat ~= "30-15" then
        textureTagPrefix = string.format("@licenseplate-%s", curFormat)
      end
      if not designData.data then
        log("W", "setPlateText", "license plate format not found '"..tostring(curFormat).."' in style '"..tostring(designPath).."'")
        local defaultDesignFallBackPath = 'vehicles/common/licenseplates/default/licensePlate-default-'..curFormat..'.json'
        if FS:fileExists(defaultDesignFallBackPath) then
          local defaultDesign = jsonReadFile(defaultDesignFallBackPath)
          if defaultDesign then
            designData.data = defaultDesign.data.format[curFormat]
            log("I", "setPlateText", "license plate fallback used '"..tostring(defaultDesignFallBackPath).."'")
          else
            log('E',tostring(defaultDesignFallBackPath) , 'Json error')
            goto continue
          end
        else
          log('E', "setPlateText", '[NO TEXTURE] No fallback for this licence plate format. Please create a default file here : "'..tostring(defaultDesignFallBackPath)..'"')
          goto continue
        end
      end
      if designData.data.characterLayout then
        if FS:fileExists(designData.data.characterLayout) then
          designData.data.characterLayout = jsonReadFile(designData.data.characterLayout)
        else
          log('E',tostring(designData.data.characterLayout) , ' File not existing')
        end
      else
        designData.data.characterLayout= "vehicles/common/licenseplates/default/platefont.json"
        designData.data.characterLayout= jsonReadFile(designData.data.characterLayout)
      end

      if designData.data.generator then
        if FS:fileExists(designData.data.generator) then
          designData.data.generator = "local://local/" .. designData.data.generator
        else
          log('E',tostring(designData.data.generator) , ' File not existing')
        end
      else
        designData.data.generator = "local://local/vehicles/common/licenseplates/default/licenseplate-default.html"
      end

      designData.data.format = curFormat
      -- log('D', "setPlateText", "cef tex :"..tostring(curFormat).. "   gen="..tostring(designData.data.generator) .. "prefix="..tostring(textureTagPrefix) )
      veh:createUITexture(textureTagPrefix, designData.data.generator, designData.data.size.x, designData.data.size.y, UI_TEXTURE_USAGE_AUTOMATIC, 1) --UI_TEXTURE_USAGE_MANUAL
      veh:queueJSUITexture(textureTagPrefix, 'init("diffuse","' .. txt .. '", '.. jsonEncode(designData) .. ');')

      veh:createUITexture(textureTagPrefix.."-normal", designData.data.generator, designData.data.size.x, designData.data.size.y, UI_TEXTURE_USAGE_AUTOMATIC, 1)
      veh:queueJSUITexture(textureTagPrefix.."-normal", 'init("bump","' .. txt .. '", '.. jsonEncode(designData) .. ');')

      veh:createUITexture(textureTagPrefix.."-specular", designData.data.generator, designData.data.size.x, designData.data.size.y, UI_TEXTURE_USAGE_AUTOMATIC, 1)
      veh:queueJSUITexture(textureTagPrefix.."-specular", 'init("specular","' .. txt .. '", '.. jsonEncode(designData) .. ');')
      ::continue::
    end
  end
end

local function loadDefaultPickup()
  local modelName = M.defaultVehicleModel
  log('D', 'main', "Loading the default vehicle " .. modelName)

  local vehicleInfo = jsonReadFile('vehicles/' .. modelName .. '/info.json')
  if not vehicleInfo then
    log('E', 'main', "No info.json for default pickup found.")
    return
  end

  if vehicleInfo.colors or vehicleInfo.default_color or vehicleInfo.default_color2 or vehicleInfo.default_color_3 then
    convertVehicleInfo(vehicleInfo)
  end

  local defaultPC = vehicleInfo.default_pc
  local paint = vehicleInfo.paints and vehicleInfo.paints[vehicleInfo.defaultPaintName1]
  paint = validateVehiclePaint(paint)
  local color = string.format("%s %s %s %s", paint.baseColor[1], paint.baseColor[2], paint.baseColor[3], paint.baseColor[4])
  local metallicPaintData = vehicleMetallicPaintString(paint.metallic, paint.roughness, paint.clearcoat, paint.clearcoatRoughness)
  TorqueScriptLua.setVar( '$beamngVehicle', modelName)
  TorqueScriptLua.setVar( '$beamngVehicleColor', color)
  TorqueScriptLua.setVar( '$beamngVehicleMetallicPaintData', metallicPaintData)
  TorqueScriptLua.setVar( '$beamngVehicleConfig', 'vehicles/' .. modelName .. '/' .. defaultPC .. '.pc' )
end

local function loadCustomVehicle(modelName, data)
  TorqueScriptLua.setVar( '$beamngVehicle', modelName)
  TorqueScriptLua.setVar( '$beamngVehicleConfig', data.config)
end

--check if there is default vehicle or not
--if not then use the defaultVehicleModel
local function loadDefaultVehicle()
  log('D', 'main', 'Loading default vehicle')
  local myveh = TorqueScriptLua.getVar('$beamngVehicleArgs')
  if myveh ~= ""  then
    TorqueScriptLua.setVar( '$beamngVehicle', myveh )
    local mycolor = getVehicleColor()
    log('I', 'main', 'myColor = '..dumps(mycolor))
    TorqueScriptLua.setVar( '$beamngVehicleColor', mycolor )
    return
  end

  local data = jsonReadFile(pathDefaultConfig)
  if data then
    if data.model then
      local dir = FS:directoryExists('vehicles')
      if dir then
        if #FS:findFiles('/vehicles/'..data.model..'/', '*.jbeam', 1, false, false) > 0 then
          TorqueScriptLua.setVar( '$beamngVehicle', data.model ) -- Set the model
          TorqueScriptLua.setVar( '$beamngVehicleConfig', pathDefaultConfig ) -- Set the parts and color
          TorqueScriptLua.setVar( '$beamngVehicleLicenseName', data.licenseName and data.licenseName or "") -- Set the license plate
          return
        else
          log('E', 'main', "Model of default vehicle doesnt exist. Loading default pickup")
          loadDefaultPickup()
          return
        end
      end
    else
      log('E', 'main', "The chosen default vehicle in "..dumps(pathDefaultConfig).." is broken. You can either delete "..dumps(pathDefaultConfig).." or set a new default vehicle.")
    end
  end
  loadDefaultPickup() -- If there is no pathDefaultConfig file, load the default pickup
end

local function loadMaybeVehicle(maybeVehicle)
  if maybeVehicle == nil then
    loadDefaultVehicle()
    return true
  elseif maybeVehicle == false then
    -- do nothing
    return true
  elseif type(maybeVehicle) == "table" then
    loadCustomVehicle(unpack(maybeVehicle))
    return true
  else
    return false
  end
end

local function spawnDefault()
  local vehicle = be:getPlayerVehicle(0)
  if FS:fileExists(pathDefaultConfig) then
    local data = jsonReadFile(pathDefaultConfig)
    if vehicle then
      replaceVehicle(data.model, {config = pathDefaultConfig, licenseText = data.licenseName})
    else
      spawnNewVehicle(data.model, {config = pathDefaultConfig, licenseText = data.licenseName})
    end
  else
    if vehicle then
      replaceVehicle(M.defaultVehicleModel, {})
    else
      spawnNewVehicle(M.defaultVehicleModel)
    end
  end
end

local function onVehicleDestroyed(vid)
  if SteamLicensePlateVehicleId == vid then
    SteamLicensePlateVehicleId = nil
  end
end

local function reloadVehicle(playerId)
  local veh = be:getPlayerVehicle(playerId)
  if veh and SteamLicensePlateVehicleId == veh:getId() then
    SteamLicensePlateVehicleId = nil
  end
end

local function changeMeshVisibility(delta)
  local vehicle = be:getPlayerVehicle(0)
  if vehicle then
    local alpha = clamp(vehicle:getMeshAlpha("") + delta, 0, 1)

    vehicle:setMeshAlpha(alpha, "", false)
    vehicle:setSpawnMeshAlpha(alpha)
  end
end

local function setMeshVisibility(alpha)
  local vehicle = be:getPlayerVehicle(0)
  if vehicle then
    alpha = clamp(alpha, 0, 1)

    vehicle:setMeshAlpha(alpha, "", false)
    vehicle:setSpawnMeshAlpha(alpha)
  end
end

--public interface
M.getCurrentVehicleDetails = getCurrentVehicleDetails
M.getVehicleDetails = getVehicleDetails

M.getModel = getModel
M.requestList = notifyUI
M.requestListEnd = notifyUIEnd
M.getModelList = getModelList
M.getConfigList = getConfigList

M.replaceVehicle = replaceVehicle
M.spawnNewVehicle = spawnNewVehicle
M.removeCurrent = removeCurrent
M.cloneCurrent = cloneCurrent
M.removeAll = removeAll
M.removeAllExceptCurrent = removeAllExceptCurrent
M.removeAllWithProperty = removeAllWithProperty
M.clearCache = clearCache


-- used to delete the cached data
M.onFileChanged = onFileChanged
M.onFileChangedEnd = onFileChangedEnd
M.onSettingsChanged = onSettingsChanged

-- License plate
M.setPlateText = setPlateText
M.getVehicleLicenseText = getVehicleLicenseText
M.makeVehicleLicenseText = makeVehicleLicenseText
M.regenerateVehicleLicenseText = regenerateVehicleLicenseText

M.reloadVehicle = reloadVehicle

-- Default Vehicle
M.loadDefaultVehicle  = loadDefaultVehicle
M.loadCustomVehicle   = loadCustomVehicle
M.spawnDefault        = spawnDefault
M.loadMaybeVehicle    = loadMaybeVehicle

M.onVehicleDestroyed = onVehicleDestroyed

-- ui2
M.getVehicleList = getVehicleList

M.changeMeshVisibility = changeMeshVisibility
M.setMeshVisibility = setMeshVisibility

M.convertVehicleInfo = convertVehicleInfo

return M
