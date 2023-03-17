-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = "weather.lua"
--table of values that need to be changed over time
local values = {}
local presets = {}
--weather condition when starting weather switching
local formerValues = {}
--diff values between starting condition and desired weather conditions
local diff = {}

local timer = 0
local switchWeatherTimer = 0
local switch = false

local selectedWeatherPreset = nil

local function getCurrentWeatherPreset()
  return selectedWeatherPreset
end

--setter functions
local function setPoint2F(former, diff)
  -- log('I', logTag, "weather.lua:setPoint2F()")
  return Point2F(
    former[1] + diff[1] * timer / switchWeatherTimer,
    former[2] + diff[2] * timer / switchWeatherTimer
  )
end

local function setVec3(former, diff)
  -- log('I', logTag, "weather.lua:setVec3()")
  return vec3(
    former[1] + diff[1] * timer / switchWeatherTimer,
    former[2] + diff[2] * timer / switchWeatherTimer,
    former[3] + diff[3] * timer / switchWeatherTimer
  )
end

local function setPoint4F(former, diff)
  -- log('I', logTag, "weather.lua:setPoint4F()")
  return Point4F(
    former[1] + diff[1] * timer / switchWeatherTimer,
    former[2] + diff[2] * timer / switchWeatherTimer,
    former[3] + diff[3] * timer / switchWeatherTimer,
    former[4] + diff[4] * timer / switchWeatherTimer
  )
end

local function setColor4F(former, diff)
  -- log('I', logTag, "weather.lua:setColor4F()")
  return Point4F(
    former[1] + diff[1] * timer / switchWeatherTimer,
    former[2] + diff[2] * timer / switchWeatherTimer,
    former[3] + diff[3] * timer / switchWeatherTimer,
    former[4] + diff[4] * timer / switchWeatherTimer
  )
end

local function setNumber(former, diff)
  -- log('I', logTag, "weather.lua:setNumber()")
  return former + diff * timer / switchWeatherTimer
end

local function getFormerValues(presetName)
  formerValues = {}
  local p = deepcopy(presets[presetName])

  if not p then
    log('E', 'weather', 'Weather preset not found: ' .. tostring(presetName))
    return
  end

  for objClassStr, attribTable in pairs(p) do
    local objs = getObjectsByClass(objClassStr)

    if objs == nil then
      log('E', 'weather', 'object class not found: ' .. tostring(objClassStr))
      goto continue
    else
      formerValues[objClassStr] = {}
      for _, obj in pairs(objs) do
        local id = obj:getId()
        formerValues[objClassStr][id] = {}
        local fields =  obj:getFields()
        for attrName, attrValue in pairs(attribTable) do
          formerValues[objClassStr][id][attrName] = {}
          if fields[attrName].type == 'int' or fields[attrName].type == 'float' and type(attrValue) == 'number' then
            formerValues[objClassStr][id][attrName]['value'] = obj[attrName]
            formerValues[objClassStr][id][attrName]['setter'] = setNumber
          elseif fields[attrName].type == 'ColorF' and type(attrValue) == 'table' and #attrValue == 4 then
            formerValues[objClassStr][id][attrName]['value'] = stringToTable(obj:getField(attrName, ' '))
            for k,v in pairs(formerValues[objClassStr][id][attrName]['value']) do
              formerValues[objClassStr][id][attrName]['value'][k] = tonumber(v)
            end
            formerValues[objClassStr][id][attrName]['setter'] = setColor4F
          elseif fields[attrName].type == 'Point4F' and type(attrValue) == 'table' and #attrValue == 4 then
            formerValues[objClassStr][id][attrName]['value'] = stringToTable(obj:getField(attrName, ' '))
            for k,v in pairs(formerValues[objClassStr][id][attrName]['value']) do
              formerValues[objClassStr][id][attrName]['value'][k] = tonumber(v)
            end
            formerValues[objClassStr][id][attrName]['setter'] = setPoint4F
          elseif (fields[attrName].type == 'Point3F' or fields[attrName].type == 'vec3') and type(attrValue) == 'table' and #attrValue == 3 then
            formerValues[objClassStr][id][attrName]['value'] = stringToTable(obj:getField(attrName, ' '))
            for k,v in pairs(formerValues[objClassStr][id][attrName]['value']) do
              formerValues[objClassStr][id][attrName]['value'][k] = tonumber(v)
            end
            formerValues[objClassStr][id][attrName]['setter'] = setVec3
          elseif type(attrValue) == 'string' then
            formerValues[objClassStr][id][attrName] = obj[attrName]
          else
            log('E', logTag, "Type of attribute " .. attrName .. " not defined yet.")
            formerValues[objClassStr][id][attrName] = obj[attrName]
          end
        end
      end
    end
    ::continue::
  end
end

local function diffTable(ta, tb)
  local t = {}
  for k,v in pairs(ta) do
    t[k] = v - tb[k]
  end
  return t
end

local function getDiff(presetName)
  diff = {}
  local p = presets[presetName]

  for objClassStr, objs in pairs(formerValues) do
    diff[objClassStr] = {}
    for id, obj in pairs(objs) do
      diff[objClassStr][id] = {}
      for attrName, attrVal in pairs(obj) do
        if type(attrVal.value) == 'number' and p[objClassStr][attrName] ~= nil then
          diff[objClassStr][id][attrName] = (p[objClassStr][attrName] - attrVal.value)
        elseif type(attrVal.value) == 'table' and p[objClassStr][attrName] ~= nil then
          diff[objClassStr][id][attrName] = diffTable(p[objClassStr][attrName], attrVal.value)
        end
      end
    end
  end
end

local function getValues()
  values = {}

  for objName, objVal in pairs(formerValues) do
    local objects = getObjectsByClass(objName)
    values[objName] = {}
    for k,object in pairs(objects) do
      values[objName][object:getId()] = object
    end
  end
end

local function multiplyTable( tbl, factor )
  for k,v in pairs(tbl) do
    tbl[k] = tbl[k] * factor
  end
  -- dump(tbl)
end

local function updateWeather()
  if diff and formerValues then
    for objClassStr, obs in pairs(formerValues) do
      for id, o in pairs(obs) do
        for attrName, attrVal in pairs(o) do
          values[objClassStr][id][attrName] = formerValues[objClassStr][id][attrName]['setter'](formerValues[objClassStr][id][attrName]['value'], diff[objClassStr][id][attrName])
        end
      end
    end
    core_environment.setFogDensity(core_environment.getFogDensity())
  end
end

local function switchWeather(presetName, t)
  local p = presets[presetName]
  if not p then
    log('I', logTag, "Preset does not exist")
    return
  end

  selectedWeatherPreset = presetName

  getFormerValues(presetName)
  getDiff(presetName)
  getValues()

  if not t then
    switchWeatherTimer = 15
  else
    switchWeatherTimer = t
  end

  if switch == false then switch = true end

  timer = 0
end

local function activate(presetName)
  -- dump(presets)
  local p = presets[presetName]
  if not p then
    log('E', 'weather', 'Weather preset not found: ' .. tostring(presetName))
    return
  end

  selectedWeatherPreset = presetName

  for objClassStr, attribTable in pairs(p) do
    if type(objClassStr) ~= 'string' or type(attribTable) ~= 'table' then
      log('E', 'weather', 'object class or attrib table invalid: ' .. tostring(objClassStr))
      goto continue
    end

    local objs = getObjectsByClass(objClassStr)
    if objs == nil then
      log('E', 'weather', 'object class not found: ' .. tostring(objClassStr))
    else
      for _, obj in pairs(objs) do
        for attrName, attrValue in pairs(attribTable) do
          local fields = obj:getFields()
          if type(fields[attrName]) ~= 'table' then
            log('E', 'weather', 'object attribute invalid: class = ' .. tostring(objClassStr) .. ', attribute = ' .. tostring(attrName))
            goto continue
          end

          local val = nil
          if type(attrValue) == fields[attrName].type then
            val = attrValue
          elseif (fields[attrName].type == 'filename' or fields[attrName].type == 'annotation') and type(attrValue) == 'string' then
            val = attrValue
          elseif (fields[attrName].type == 'float' or fields[attrName].type == 'int') and type(attrValue) == 'number' then
            val = attrValue
          elseif fields[attrName].type == 'bool' and type(attrValue) == 'boolean' then
            val = attrValue
          elseif fields[attrName].type == 'ColorF' and type(attrValue) == 'table' and #attrValue == 4 then
            val = Point4F(attrValue[1], attrValue[2], attrValue[3], attrValue[4])
          elseif fields[attrName].type == 'Point4F' and type(attrValue) == 'table' and #attrValue == 4 then
            val = Point4F(attrValue[1], attrValue[2], attrValue[3], attrValue[4])
          elseif (fields[attrName].type == 'Point3F' or fields[attrName].type == 'vec3') and type(attrValue) == 'table' and #attrValue == 3 then
            val = vec3(attrValue[1], attrValue[2], attrValue[3])
          end

          if val == nil then
            log('E', 'weather',  'invalid attribute: ' .. tostring(obj.name or '(no name)') .. ' [' .. objClassStr .. '].' .. tostring(attrName) .. ' = ' .. tostring(attrValue))
          else
            log('D', 'weather',  ' * ' .. tostring(obj.name or '(no name)') .. ' [' .. objClassStr .. '].' .. tostring(attrName) .. ' = ' .. dumps(attrValue) .. ' / ' .. tostring(val))
            obj[attrName] = val
          end

          if objClassStr == "LevelInfo" then
            obj:postApply()
          end
        end
      end
    end
    ::continue::
  end
  -- TODO:
  -- materials: specularity change, darken the colors
end

local function onPreRender(dt)
  if switch == true then
    timer = timer + dt
    updateWeather()
    if timer > switchWeatherTimer then
      switch = false
      timer = 0
    end
  end
end

-- loads one preset
local function loadPreset(filename)
  local filePresets = jsonReadFile(filename)
  --log('D', 'weather', "Weather preset loaded: " .. tostring(filename) .. ": "..dumps(filePresets))
  if tableIsEmpty(filePresets) then
    log('E', 'weather', 'preset invalid: ' .. tostring(filename))
    return
  end
  tableMerge(presets, filePresets)
end

-- loads the global weather files and then the local weather of the level if existing
local function loadPresets()
  local levelPath = getMissionFilename() -- /levels/small_island/info.json
  if type(levelPath) ~= 'string' or string.len(levelPath) == 0 then return end

  -- global weather presets - all weather files saved in /art/weather/
  local globalFiles = FS:findFiles('art/weather/', '*.json', -1, true, false) -- {"art/weather/defaults.json"}
  for _, v in pairs(globalFiles) do
    loadPreset(v)
  end

  -- level specific weather presets - all weather files saved in the level's weather folder e.g. \levels\driver_training/weather/
  -- are overriding global presets
  local levelDir, filename, ext = path.split(levelPath)
  local levelFiles = FS:findFiles(levelDir..'/weather/', '*.json', -1, true, false) -- {"levels/driver_training/weather/weather.json"}
  for _, v in pairs(levelFiles) do
    loadPreset(v)
  end
end

local function getPresets()
  local p = {}
  for k,v in pairs(presets) do
    table.insert(p,k)
  end
  return p
end

local function onExtensionLoaded()
  --log('I', 'weather', "module loaded")
  formerValues = {}
  diff = {}

  timer = 0
  switchWeatherTimer = 0
  switch = false

  selectedWeatherPreset = nil

  loadPresets()
end

local function onClientPostStartMission(levelPath)
  profilerPushEvent('loadWeather')
  --log('I', 'weather', "map loaded: " .. tostring(mission))
  loadPresets()
  profilerPopEvent() -- loadWeather
end

local function dumpWeatherPresets()
  dump(presets)
end

-- public interface below
M.onExtensionLoaded = onExtensionLoaded
M.onClientPostStartMission = onClientPostStartMission
--M.loadPresets = loadPresets
M.activate = activate
M.switchWeather = switchWeather
M.getPresets = getPresets
M.onPreRender = onPreRender
M.dumpWeather = dumpWeatherPresets
M.getCurrentWeatherPreset = getCurrentWeatherPreset

return M
