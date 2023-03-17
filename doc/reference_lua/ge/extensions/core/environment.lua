-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local min = math.min
local max = math.max

local M = {}
--[[
envState
  TimeOfDay
    time
    play
    speed
  Weather
    fog
    cloudcover
    rain
      ground model
      material: specular
      ambient color
--]]
M.groundModels = {}
M.loadedGroundModelFiles = {}

local envObjectIdCache = {}

local gm_filename = 'art/groundmodels.json'
local simSpeed = 1
local init_env={}
local myTexture = {}
local tempCurve = {}

local temperatureK = 0.0

local function getObject(className)
  if envObjectIdCache[className] then
    if envObjectIdCache[className] == 0 then return nil end
    return scenetree.findObjectById(envObjectIdCache[className])
  end
  envObjectIdCache[className] = 0
  local objNames = scenetree.findClassObjects(className)
  if objNames and not tableIsEmpty(objNames) then
    local obj = scenetree.findObject(objNames[1])
    if obj then
      envObjectIdCache[className] = obj:getID()
      return obj
    end
  end

  return nil
end

-- TODO: Prevent the game from crashing if no filePath is present
local colorTmp = ColorI(0,0,0,0)
local function transformTime2Colors(filePath, time)
  if not filePath or filePath == "" then return nil end
  local gradientFile = tostring(filePath)
  if gradientFile == "" then return nil end

  if not myTexture[gradientFile] then
    myTexture[gradientFile] = GBitmap()
    if not myTexture[gradientFile]:loadFile(gradientFile) then
      log("E", "transformTime2Colors", "fail to load "..dumps(gradientFile))
      return nil
    end
  end

  if (gradientFile ~= "") and myTexture[gradientFile] then
    local width = myTexture[gradientFile]:getWidth() --starts from 0

    -- picks a color in the texture file, according to the current TimeOfDay
    local index
    index = time*(width-1)

    myTexture[gradientFile]:getColor(index, 0, colorTmp)

    -- Convert ColorI to Point4F
    return Point4F(colorTmp.r / 255, colorTmp.g / 255, colorTmp.b / 255, colorTmp.a / 255)
  end
  return nil
end

local function setColors(time)
  local skyObj = getObject("scattersky")
  if skyObj then
    local colorize = transformTime2Colors(skyObj.colorizeGradientFile, time)
    if colorize then skyObj.colorize = colorize end

    local sunScale = transformTime2Colors(skyObj.sunScaleGradientFile, time)
    if sunScale then skyObj.sunScale = sunScale end

    local ambientScale = transformTime2Colors(skyObj.ambientScaleGradientFile, time)
    if ambientScale then skyObj.ambientScale = ambientScale end

    local fogScale = transformTime2Colors(skyObj.fogScaleGradientFile, time)
    if fogScale then skyObj.fogScale = fogScale end

    local nightColor = transformTime2Colors(skyObj.nightGradientFile, time)
    if nightColor then skyObj.nightColor = nightColor end

    local nightFogColor = transformTime2Colors(skyObj.nightFogGradientFile, time)
    if nightFogColor then skyObj.nightFogColor = nightFogColor end

    --skyObj.shadowsoftness = 1
    --skyObj.flarescale = 0
    --skyObj.sunsize = 1
  end
end

-------------------------------------------------------------
----------------------- TimeofDay ---------------------------
-------------------------------------------------------------

local function setTimeOfDay(timeOfDay)
  local timeObj = getObject("TimeOfDay")

  if timeObj and timeOfDay.time then
    timeObj.time = timeOfDay.time
    setColors(timeObj.time)
    timeObj.play = timeOfDay.play

    timeObj.dayScale = timeOfDay.dayScale
    timeObj.nightScale = timeOfDay.nightScale
    timeObj.dayLength = timeOfDay.dayLength
    timeObj.azimuthOverride = timeOfDay.azimuthOverride
  end
end

local timeOfDay = {}
local function getTimeOfDay()
  local timeObj = getObject("TimeOfDay")
  if timeObj then
    timeOfDay.time = timeObj.time
    timeOfDay.play = timeObj.play
    timeOfDay.dayScale = timeObj.dayScale
    timeOfDay.azimuthOverride = timeObj.azimuthOverride
    timeOfDay.nightScale = timeObj.nightScale
    timeOfDay.dayLength = timeObj.dayLength
    timeOfDay.startTime = timeObj.startTime
    return timeOfDay
  end
end

local function cycleTimeOfDay(controlLights)
  local v = getTimeOfDay()
  local t = v.time
  local lights = 2
  if t < 0.2 then
    t = 0.23
  elseif t >= 0.5 then
    t = 0.05
    lights = 0
  else
    t = 0.5
  end
  if controlLights then
    be:queueAllObjectLua('electrics.setLightsState('..lights..')')
  end
  v.time = t
  setTimeOfDay(v)
end

-------------------------------------------------------------
----------------------- ScatterSky --------------------------
-------------------------------------------------------------

local function getShadowDistance()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return scatterSkyObj.shadowDistance
  end
end

local function setShadowDistance(shadowDistance)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and shadowDistance then
    scatterSkyObj.shadowDistance = shadowDistance
  end
end

local function getShadowSoftness()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return scatterSkyObj.shadowSoftness
  end
end

local function setShadowSoftness(shadowSoftness)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and shadowSoftness then
    scatterSkyObj.shadowSoftness = shadowSoftness
  end
end

local function getShadowLogWeight()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return scatterSkyObj.logWeight
  end
end

local function setShadowLogWeight(logWeight)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and logWeight then
    scatterSkyObj.logWeight = logWeight
  end
end

local function getSkyBrightness()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return scatterSkyObj.skyBrightness
  end
end

local function setSkyBrightness(skyBrightness)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and skyBrightness then
    scatterSkyObj.skyBrightness = skyBrightness
  end
end

local function getColorizeGradientFile()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return tostring(scatterSkyObj.colorizeGradientFile)
  end
end

local function setColorizeGradientFile(colorizeGradientFile)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and colorizeGradientFile then
    scatterSkyObj.colorizeGradientFile = String(colorizeGradientFile)
  end
end

local function getSunScaleGradientFile()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return tostring(scatterSkyObj.sunScaleGradientFile)
  end
end

local function setSunScaleGradientFile(sunScaleGradientFile)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and sunScaleGradientFile then
    scatterSkyObj.sunScaleGradientFile = String(sunScaleGradientFile)
  end
end

local function getAmbientScaleGradientFile()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return tostring(scatterSkyObj.ambientScaleGradientFile)
  end
end

local function setAmbientScaleGradientFile(ambientScaleGradientFile)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and ambientScaleGradientFile then
    scatterSkyObj.ambientScaleGradientFile = String(ambientScaleGradientFile)
  end
end

local function getFogScaleGradientFile()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return tostring(scatterSkyObj.fogScaleGradientFile)
  end
end

local function setFogScaleGradientFile(fogScaleGradientFile)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and fogScaleGradientFile then
    scatterSkyObj.fogScaleGradientFile = String(fogScaleGradientFile)
  end
end

local function getNightGradientFile()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return tostring(scatterSkyObj.nightGradientFile)
  end
end

local function setNightGradientFile(nightGradientFile)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and nightGradientFile then
    scatterSkyObj.nightGradientFile = String(nightGradientFile)
  end
end

local function getNightFogGradientFile()
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj then
    return tostring(scatterSkyObj.nightFogGradientFile)
  end
end

local function setNightFogGradientFile(nightFogGradientFile)
  local scatterSkyObj = getObject("ScatterSky")
  if scatterSkyObj and nightFogGradientFile then
    scatterSkyObj.nightFogGradientFile = String(nightFogGradientFile)
  end
end

-------------------------------------------------------------
------------------------- Clouds ----------------------------
-------------------------------------------------------------

-- Old functions below, only works for the first cloud object in the scene

local function setWindSpeed(windSpeed)
  local cloudObj = getObject("CloudLayer")
  if cloudObj and windSpeed then
    cloudObj.windSpeed = windSpeed
    cloudObj:postApply()
  end
end

local function getWindSpeed()
  local cloudObj = getObject("CloudLayer")
  local windSpeed
  if cloudObj then
    windSpeed = cloudObj.windSpeed
  end
  return windSpeed
end

local function setCloudCover(cloud)
  local cloudObj = getObject("CloudLayer")
  if cloudObj and cloud then
    cloudObj.coverage = cloud
    cloudObj:postApply()
  end
end

local function getCloudCover()
  local cloudObj = getObject("CloudLayer")
  local cloud
  if cloudObj then
    cloud = cloudObj.coverage
  end
  return cloud
end

-- Cloud per ID functions below

local function getCloudCoverByID(objectID)
  local cloudObj = scenetree.findObjectById(objectID)
  local cloud
  if cloudObj then
    cloud = cloudObj.coverage
  end
  return cloud
end

local function setCloudCoverByID(objectID, coverage)
  local cloudObj = scenetree.findObjectById(objectID)
  local cloud
  if cloudObj and coverage then
    cloudObj.coverage = coverage
    cloudObj:postApply()
  end
end

local function getCloudExposureByID(objectID)
  local cloudObj = scenetree.findObjectById(objectID)
  local exposure
  if cloudObj then
    exposure = cloudObj.exposure
  end
  return exposure
end

local function setCloudExposureByID(objectID, exposure)
  local cloudObj = scenetree.findObjectById(objectID)
  local cloud
  if cloudObj and exposure then
    cloudObj.exposure = exposure
    cloudObj:postApply()
  end
end

local function getCloudWindByID(objectID)
  local cloudObj = scenetree.findObjectById(objectID)
  local windSpeed
  if cloudObj then
    windSpeed = cloudObj.windSpeed
  end
  return windSpeed
end

local function setCloudWindByID(objectID, windSpeed)
  local cloudObj = scenetree.findObjectById(objectID)
  local cloud
  if cloudObj and windSpeed then
    cloudObj.windSpeed = windSpeed
    cloudObj:postApply()
  end
end


local function getCloudHeightByID(objectID)
  local cloudObj = scenetree.findObjectById(objectID)
  local height
  if cloudObj then
    height = cloudObj.height
  end
  return height
end

local function setCloudHeightByID(objectID, height)
  local cloudObj = scenetree.findObjectById(objectID)
  local cloud
  if cloudObj and height then
    cloudObj.height = height
    cloudObj:postApply()
  end
end


-------------------------------------------------------------
----------------------- LevelInfo ---------------------------
-------------------------------------------------------------

local function setFogDensity(fog)
  local fogObj = getObject("LevelInfo")
  if fogObj and fog then
    fogObj.fogDensity = fog
    fogObj:postApply()
  end
end

local function getFogDensity()
  local fogObj = getObject("LevelInfo")
  local fog = 0.0
  if fogObj then
    fog = fogObj.fogDensity
  end
  return fog
end

local function setFogDensityOffset(fogOffset)
  local fogObj = getObject("LevelInfo")
  if fogObj and fogOffset then
    fogObj.fogDensityOffset = fogOffset
    fogObj:postApply()
  end
end

local function getFogDensityOffset()
  local fogObj = getObject("LevelInfo")
  local fogOffset = 0.0
  if fogObj then
    fogOffset = fogObj.fogDensityOffset
  end
  return fogOffset
end

local function setFogAtmosphereHeight(fogHeight)
  local fogObj = getObject("LevelInfo")
  if fogObj and fogHeight then
    fogObj.FogAtmosphereHeight = fogHeight
    fogObj:postApply()
  end
end

local function getFogAtmosphereHeight()
  local fogObj = getObject("LevelInfo")
  local fogHeight = 0.0
  if fogObj then
    fogHeight = fogObj.FogAtmosphereHeight
  end
  return fogHeight
end

local function setGravity(grav)
  if not grav then return end
  -- important: let the level known about the change
  -- otherwise the spawning of objects will have the wrong gravity
  if scenetree.theLevelInfo then
    scenetree.theLevelInfo.gravity = grav
  end
  be:queueAllObjectLua("obj:setGravity("..grav..")")
end

local function getGravity()
  if scenetree.theLevelInfo then
    return scenetree.theLevelInfo.gravity
  end
  return -9.81; -- fallback
end

-------------------------------------------------------------
--------------------- Precipitation -------------------------
-------------------------------------------------------------

local function setPrecipitation(rainDrops)
  local rainObj = getObject("Precipitation")
  if rainObj and rainDrops then
    rainObj.numOfDrops = rainDrops
  end
end

local function getPrecipitation()
  local rainObj = getObject("Precipitation")
  local rainDrops
  if rainObj then
    rainDrops = rainObj.numOfDrops
  end
  return rainDrops
end

local function getTemperatureK()
  return temperatureK
end


-------------------------------------------------------------
local function getState()
  local res = {}
  local timeObj = getTimeOfDay()
  if timeObj then
    res.time = timeObj.time
    res.startTime = timeObj.startTime
    res.play = timeObj.play
    res.dayScale = timeObj.dayScale
    res.nightScale = timeObj.nightScale
  end

  local windSpeed = getWindSpeed()
  res.windSpeed = windSpeed

  local cloudCover = getCloudCover()
  res.cloudCover = cloudCover
  res.fogDensity = getFogDensity() * 1000

  local numOfDrops = getPrecipitation()
  res.numOfDrops = numOfDrops
  res.gravity = getGravity()
  res.temperatureC = getTemperatureK() - 273.15

  if next(res) == nil then
    return nil
  end
  return res
end

local function setState(state)
  if state then
    local timeObj = {time = state.time, play = state.play, dayScale = state.dayScale, nightScale = state.nightScale}
    setTimeOfDay(timeObj)
    setWindSpeed(state.windSpeed)
    setCloudCover(state.cloudCover)
    if state.fogDensity then
      setFogDensity(state.fogDensity / 1000) -- sliders do not work with tiny values, so we use big values and divide them here
    end
    setPrecipitation(state.numOfDrops)
    setGravity(state.gravity)
  end
end

local function dumpGroundModels()
  local gmCount = be:getGroundModelCount()
  local gms = {}
  for i = 0, gmCount do
    local gm = be:getGroundModelByID(i)
    if gm.data then
      gm = gm.data
      gms[gm.name or i] = {
      id = i,
      roughnessCoefficient = gm.roughnessCoefficient,
      defaultDepth = gm.defaultDepth,
      staticFrictionCoefficient = gm.staticFrictionCoefficient,
      slidingFrictionCoefficient = gm.slidingFrictionCoefficient,
      hydrodynamicFriction = gm.hydrodynamicFriction or gm.hydrodnamicFriction,
      stribeckVelocity = gm.stribeckVelocity,
      strength = gm.strength,
      collisiontype = gm.collisiontype,
      fluidDensity = gm.fluidDensity,
      flowConsistencyIndex = gm.flowConsistencyIndex,
      flowBehaviorIndex = gm.flowBehaviorIndex or gm.flowBehaviourIndex, -- omg ...
      dragAnisotropy = gm.dragAnisotropy,
      skidMarks = gm.skidMarks,
      shearStrength = gm.shearStrength
      }
    end
  end
  jsonWriteFile('groundmodels_dump.json', gms, true)
end

local function submitGroundModel(k, v)
  local particles = require("particles")
  local materials = particles.getMaterialsParticlesTable()

  local gm = ground_model()
  local names = v.aliases or {}
  table.insert(names, k)

  local knownAttributes = {aliases=1, roughnessCoefficient=1, staticFrictionCoefficient=1, slidingFrictionCoefficient=1, hydrodynamicFriction=1, stribeckVelocity=1, strength=1, collisiontype=1, fluidDensity=1, flowConsistencyIndex=1, flowBehaviorIndex=1, dragAnisotropy=1, skidMarks=1, defaultDepth=1, shearStrength = 1}
  local knownProblems = {hydrodnamicFriction='hydrodynamicFriction', flowBehaviourIndex='flowBehaviorIndex'}
  for j, _ in pairs(v) do
    if knownProblems[j] then
      log('E', 'groundmodels', 'Please fix your grounmodel up: ' .. tostring(j) .. ' should be instead: ' .. knownProblems[j])
    elseif not knownAttributes[j] then
      log('E', 'groundmodels', 'Unknown ground model attribute: ' .. tostring(j) .. ' - IGNORED')
    end
  end

  gm.roughnessCoefficient = v.roughnessCoefficient or 0
  gm.defaultDepth = v.defaultDepth or 0
  gm.staticFrictionCoefficient = v.staticFrictionCoefficient or 1
  gm.slidingFrictionCoefficient = v.slidingFrictionCoefficient or 0.7
  gm.hydrodynamicFriction = v.hydrodynamicFriction or v.hydrodnamicFriction or 0.01
  gm.stribeckVelocity = v.stribeckVelocity or 6
  gm.strength = v.strength or 1
  gm.collisiontype = 0
  if type(v.collisiontype) == 'string' then
    gm.collisiontype = particles.getMaterialIDByName(materials, v.collisiontype)
    --print(v.collisiontype .. ' -> ' .. tostring(gm.collisiontype))
  end
  gm.fluidDensity = v.fluidDensity or 200
  gm.flowConsistencyIndex = v.flowConsistencyIndex or 10000
  gm.flowBehaviorIndex = v.flowBehaviorIndex or v.flowBehaviourIndex or 0.5 -- omg ...
  gm.dragAnisotropy = v.dragAnisotropy or 0
  gm.skidMarks = v.skidMarks or false
  gm.shearStrength = v.shearStrength or 0

  for _, name in ipairs(names) do
    local newName = string.upper(name)

    M.groundModels[newName] = {cdata = gm, isAlias = false, parent = 'none'}

    if newName ~= k then
      M.groundModels[newName].isAlias = true
      M.groundModels[newName].parent = k
    end

    be:setGroundModel(newName, gm)
    --print("****** setting groundmodel: " .. tostring(newName))
    -- save them in lua so we could work with them later
  end
end

local function loadGroundModelFile(filename)
  local gms = jsonReadFile(filename)
  if not gms then
    log('E', 'ge.environment.reloadGroundModels', 'unable to load main ground models file: ' .. filename);
    return {}
  end

  -- convert the keys to uppercase
  local newGms = {}
  for k, v in pairs(gms) do
    if string.len(k) > 31 then
      local newk = string.sub(k, 1, 30)
      log('E', 'ge.environment.reloadGroundModels', 'Ground model name too long: "' .. tostring(k) .. '" is longer than the supported 31 characters. It will be cut to "' .. tostring(newk) .. '")')
      k = newk
    end
    newGms[string.upper(k)] = v
  end
  gms = newGms

  if filename == gm_filename then
    if gms['ASPHALT'] == nil then
      log('E', 'ge.environment.reloadGroundModels', 'Ground model "ASPHALT" was not found in: ' .. tostring(gm_filename))
    end
  end

  table.insert(M.loadedGroundModelFiles, filename)

  return gms
end

local function loadGroundModels(gms)
  -- this enforces asphalt being the first always
  if gms['ASPHALT'] then
    submitGroundModel('ASPHALT', gms['ASPHALT'])
  end

  local sortedGmNames = {}
  for k, v in pairs(gms) do
    if k ~= 'ASPHALT' then
      table.insert(sortedGmNames, k)
    end
  end
  table.sort(sortedGmNames)

  -- submit all other ground models afterwards in alphabetical order
  for _, name in ipairs(sortedGmNames) do
    submitGroundModel(name, gms[name])
  end
end

local function reloadGroundModels(levelPath)
  if not be then return end

  profilerPushEvent('reloadGroundModels')

  --log('D', 'ge.environment.reloadGroundModels', 'reloading all ground models ...')
  be:resetGroundModels()
  M.groundModels = {}
  M.loadedGroundModelFiles = {}

  -- load the common groundmodels first
  local allGroundModels = loadGroundModelFile(gm_filename)

  -- then load level groundmaps
  levelPath = levelPath or getMissionFilename()
  if levelPath and string.len(levelPath) > 0 then
    local levelDir, filename, ext = path.split(levelPath, "(.-)([^/]-([^%.]*))$")
    local files = FS:findFiles(levelDir..'/groundModels/', '*.json', -1, true, false)

    -- filter paths to only return filename without extension
    for _,fn in pairs(files) do
      tableMerge(allGroundModels, loadGroundModelFile(fn));
    end
  end

  loadGroundModels(allGroundModels)

  profilerPopEvent() -- reloadGroundModels
end

local function reset()
  local levelInfo = getObject("LevelInfo")
  if levelInfo then
    tempCurve = levelInfo:getTemperatureCurveC()
  end
  guihooks.trigger("EnvironmentStateUpdate", getState())
  reloadGroundModels()
end

local function reset_init()
  setState(init_env)
end

local function onClientPreStartMission(levelPath)
  local levelInfo = getObject("LevelInfo")
  if levelInfo then
    tempCurve = levelInfo:getTemperatureCurveC()
  end
  reloadGroundModels(levelPath)
end

local function onClientPostStartMission(levelPath)
  --print("onClientPreStartMission: " .. tostring(levelPath))
  envObjectIdCache = {}
  init_env=getState()
  --init_env.time = init_env.startTime --TOD:onAdd is already doing that
  setState(init_env) --necesary to "fix" some maps that have the sky changed
end

-- having this function, enables writing groundmodels that are getting reloaded dynamically in the game
local function onFilesChanged(files)
  for _,v in pairs(files) do
    local filename = v.filename
    if filename and filename:find('.json') then
      filename = string.upper(filename)
      for _, f in pairs(M.loadedGroundModelFiles) do
        if string.upper(f) == filename then
          log('D', 'environment', 'ground model changed dynamically, reloading collision')
          -- in this case we want to make sure everything uses the new properties
          -- do not put this in reset as it would be called twice
          reset()
          be:reloadCollision()
          return
        end
      end
    end
  end
end

local function setTemperatureK(tempK)
  be:setSeaLevelTemperatureK(tempK)
  temperatureK = tempK
end

local function sendState()
  guihooks.trigger("EnvironmentStateUpdate", getState())
end

local function invertLerp(from,to,value)
  value = min(max(from, value),to)
  return (value - from) / (to-from)
end

local function onUpdate()
  local levelInfo = getObject("LevelInfo")
  if not levelInfo or not be then return end

  if levelInfo:isEditorDirty() then
    tempCurve = levelInfo:getTemperatureCurveC()
  end
  if #tempCurve < 2 then return end

  local tod = getTimeOfDay()
  if not tod or not tod.time then
    setTemperatureK( tempCurve[1][2] + 273.15 )
    return
  end

  local tempC = 15
  local t = max(tempCurve[1][1], min(tempCurve[#tempCurve][1], tod.time))
  for i, v in ipairs(tempCurve) do
    if v[1] > t or i == #tempCurve then
      local factor = invertLerp(tempCurve[i-1][1], v[1], t)
      tempC = lerp(tempCurve[i-1][2], v[2], clamp(factor,0,1))
      break
    end
  end

  setTemperatureK( tempC + 273.15 )

  -- Calculate colors when time is playing
  if tod and tod.play == true then
    setColors(tod.time)
  end
end

local function onClientStartMission(levelPath)
  local levelInfo = getObject("LevelInfo")
  if levelInfo then
    tempCurve = levelInfo:getTemperatureCurveC()
  end

  envObjectIdCache = {}

  local tod = getTimeOfDay()
  if tod then
    setColors(tod.time)
  end
end

local function onEditorEnabled(enabled)
  if not enabled then
    envObjectIdCache = {}
  end
end

local function onClientEndMission()
  for k,v in pairs(myTexture) do
    myTexture[k] = nil
  end
  --Stop time of day object when we unload a level
  local timeObj = getObject("TimeOfDay")
  if timeObj then
    timeObj.play = false
    timeObj.animate = false
  end
  reset()
end

------------------------------------------
-- For ui interface environment property
M.setState = setState
M.requestState = sendState
M.reset = reset
M.getState = getState
M.reset_init = reset_init
----------------------------------------------
-- TimeofDay
M.setTimeOfDay = setTimeOfDay
M.getTimeOfDay = getTimeOfDay
M.cycleTimeOfDay = cycleTimeOfDay
-- ScatterSky
M.getShadowDistance = getShadowDistance
M.setShadowDistance = setShadowDistance
M.getShadowSoftness = getShadowSoftness
M.setShadowSoftness = setShadowSoftness
M.getShadowLogWeight = getShadowLogWeight
M.setShadowLogWeight = setShadowLogWeight
M.getSkyBrightness = getSkyBrightness
M.setSkyBrightness = setSkyBrightness
M.getColorizeGradientFile = getColorizeGradientFile
M.setColorizeGradientFile = setColorizeGradientFile
M.getSunScaleGradientFile = getSunScaleGradientFile
M.setSunScaleGradientFile = setSunScaleGradientFile
M.getAmbientScaleGradientFile = getAmbientScaleGradientFile
M.setAmbientScaleGradientFile = setAmbientScaleGradientFile
M.getFogScaleGradientFile = getFogScaleGradientFile
M.setFogScaleGradientFile = setFogScaleGradientFile
M.getNightGradientFile = getNightGradientFile
M.setNightGradientFile = setNightGradientFile
M.getNightFogGradientFile = getNightFogGradientFile
M.setNightFogGradientFile = setNightFogGradientFile
-- Clouds
M.setWindSpeed = setWindSpeed
M.getWindSpeed = getWindSpeed
M.setCloudCover = setCloudCover
M.getCloudCover = getCloudCover
M.getCloudCoverByID = getCloudCoverByID
M.setCloudCoverByID = setCloudCoverByID
M.getCloudExposureByID = getCloudExposureByID
M.setCloudExposureByID = setCloudExposureByID
M.getCloudWindByID = getCloudWindByID
M.setCloudWindByID = setCloudWindByID
M.getCloudHeightByID = getCloudHeightByID
M.setCloudHeightByID = setCloudHeightByID
-- LevelInfo
M.setFogDensity = setFogDensity
M.getFogDensity = getFogDensity
M.setFogDensityOffset = setFogDensityOffset
M.getFogDensityOffset = getFogDensityOffset
M.setFogAtmosphereHeight = setFogAtmosphereHeight
M.getFogAtmosphereHeight = getFogAtmosphereHeight
M.setGravity = setGravity
M.getGravity = getGravity
-- Precipitation
M.setPrecipitation = setPrecipitation
M.getPrecipitation = getPrecipitation
-- Other
M.getTemperatureK = getTemperatureK
M.reloadGroundModels = reloadGroundModels
M.onClientPreStartMission = onClientPreStartMission
M.onClientPostStartMission = onClientPostStartMission
M.onInit = reset
M.onFilesChanged = onFilesChanged
M.onUpdate = onUpdate
M.onClientStartMission = onClientStartMission
M.onClientEndMission = onClientEndMission
M.onEditorEnabled = onEditorEnabled
M.dumpGroundModels = dumpGroundModels

return M
