-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local M = {}

local settings = nil
local settingByKey = {}
local settingKeys = {}

-- sets up a table to quickly look up each settings parameters.
local function recursiveSetupSettings(sets)
  for _, s in ipairs(sets) do
    table.insert(settingKeys, s.tsVar)
    if s.tsVar then
      for k, v in pairs(s) do
        if k ~= 'settings' then
          if not settingByKey[s.tsVar] then settingByKey[s.tsVar] = {} end
          settingByKey[s.tsVar][k] = v
        end
      end
    end
    if type(s.settings) == 'table' then
      recursiveSetupSettings(s.settings)
    end
  end
end

-- gets a settings object with all the current settings
local function getSettings(force)
  if force then
    settings = nil
    settingByKey = nil
  end
  if settings == nil then
    settings = {}
    settingByKey = {}
    local rendererComponentFiles = FS:findFiles("/renderer/components/", "*.rendercomponent.json", -1, false, false)
    for _, filename in ipairs(rendererComponentFiles) do
      local data = jsonReadFile(filename)
      if data then
        settings[data.name] = data
        recursiveSetupSettings(data.settings or {})
      else
        log("E", "", "unable to read json file: " .. tostring(filename))
      end
    end
  end
  return settings
end

local function setSetting(name, value)
  if not settings then getSettings() end
  -- replace this by better lua code at some point
  if not settingByKey[name] then return end
  local t = settingByKey[name].type
  if t == 'bool' then
    -- bools can have the shaderobject
    local numBool = value and 1 or 0
    TorqueScriptLua.setVar(name, numBool)
    if settingByKey[name].shaderObject then
      local obj = scenetree.findObject(settingByKey[name].shaderObject)
      if obj then
        obj = Sim.upcast(obj)
        if numBool ~= 0 then
          obj.obj:enable()
        else
          obj.obj:disable()
        end
      else
        log('E', '', 'Unable to find shader object: ' .. tostring(settingByKey[name].shaderObject))
      end
    end
  elseif t == nil then
    -- no type means numeric value
    TorqueScriptLua.setVar(name, tonumber(value))
  else
    -- otherwise use litela value
    TorqueScriptLua.setVar(name, value)
  end
end

-- returns a KV-list of all current settings.
local function getCurrentSettings()
  if not settings then getSettings() end
  local current = {}
  for _, key in ipairs(settingKeys) do
    current[key] = TorqueScriptLua.getVar(key)
    if settingByKey[key].type == 'bool' then current[key] = current[key] == "1" end
    if settingByKey[key].type == nil    then current[key] = tonumber(current[key]) end
  end
  return current
end

-- get available color corrections files
local function getColorCorrections()
  local result = {}
  for i,file in ipairs(FS:findFiles('art/postfx', '*.png', 0, false, false)) do
    table.insert(result, {filename=file})
  end
  return result
end

-- lets you set a list of all settings at once.
local function setMultiSettings(keyvars)
  for key, var in pairs(keyvars or {}) do
    setSetting(key, var)
  end

  require("client/postFx/dof").updateDOFSettings()
end

M.getSettings = getSettings
M.setSetting = setSetting
M.getColorCorrections = getColorCorrections
M.getCurrentSettings = getCurrentSettings
M.setMultiSettings = setMultiSettings
return M