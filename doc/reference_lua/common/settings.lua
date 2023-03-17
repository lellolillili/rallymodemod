-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.path = '/settings/'
M.pathDefaults = M.path..'defaults.json'
M.pathDeprecated = M.path..'deprecated.json'
M.pathSteamdeck = M.path..'steamdeck.json'
M.pathLocal = M.path..'settings.json'
M.pathCloud = M.path..'cloud/settings.json'
M.pathTorquescript = M.path..'game-settings.cs'

M.defaults = jsonReadFile(M.pathDefaults) or {}
M.deprecated = jsonReadFile(M.pathDeprecated) or {}

-- check if a setting has been deprecated or replaced, and return the new version when possible
local function upgradeSetting(setting)
  if setting == nil then
    log('E', '', "Cannot parse null setting")
    return
  end
  if M.defaults[setting] == nil then
    if M.deprecated[setting] == nil then
      if vmType == 'game' then
        log('W', '', "Unrecognized setting name \""..setting.."\" (not defined in defaults file: "..dumps(M.pathDefaults)..")")
      end
      return
    end

    if M.deprecated[setting]["replacement"] ~= nil then
      if vmType == 'game' then
        log('D', '', "Replacing deprecated setting "..setting.." with new setting "..M.deprecated[setting]["replacement"]);
      end
      return upgradeSetting(M.deprecated[setting]["replacement"])
    end
    if M.deprecated[setting]["obsolete"] == true then
      if vmType == 'game' then
        log('D', '', "Ignoring deprecated setting: "..setting)
      end
      return
    end
    log('E', '', "Couldn't process deprecated setting "..setting..": "..dumps(M.deprecated[setting]))
    return
  end
  return setting
end

-- takes care of updating renamed settings, deprecated settings, etc
local function upgradeSettings(settings)
  local result = {}
  for originalSetting,v in pairs(settings) do
    local setting = upgradeSetting(originalSetting)
    if setting then
      result[setting] = v
    else
      result[originalSetting] = v
    end
  end
  return result
end

-- enforce some options if we are running on steamdeck
if runningOnSteamDeck then -- set by C++
  local steamdeckValues = jsonReadFile(M.pathSteamdeck) or {}
  steamdeckValues = upgradeSettings(steamdeckValues)
  for k,v in pairs(steamdeckValues) do
    local definition = M.defaults[k]
    if definition then
      definition[2] = v
    else
      log("E", "", string.format("Unable to apply a steamdeck setting '%s'=%s that is not defined in the defaults file: '%s'", k, dumps(v), M.pathDefaults))
    end
  end
end

-- precompute default values
M.defaultValues = {}
for k,v in pairs(M.defaults) do
  M.defaultValues[k] = v[2]
end

local valuesCache = nil
local function getValues()
  if not valuesCache then
    local values = deepcopy(M.defaultValues)
    local cloudValues = jsonReadFile(M.pathCloud) or {}
    local localValues = jsonReadFile(M.pathLocal) or {}

    values = upgradeSettings(values)
    cloudValues = upgradeSettings(cloudValues)
    localValues = upgradeSettings(localValues)

    tableMerge(values, cloudValues)
    tableMerge(values, localValues)
    if CppSettings then
      for k,value in pairs(values) do
        if CppSettings[k] ~= nil then
          -- we have C++ type information
          if type(CppSettings[k]) ~= type(value) then
            log("E", "", string.format("Unable to parse setting '%s': it should be a %s, but is a %s. The ignored value is: %s", k, type(CppSettings[k]), type(value), dumps(value)))
            values[k] = nil
          end
        end
      end
    end
    valuesCache = values
  end
  return valuesCache
end

-- will return 'defaultValue' when the value does not exist or is nil
local function getValue(key, defaultValue)
  local value = getValues()[key]
  if value == nil then
    return defaultValue
  end
  return value
end

local function invalidateCache()
  valuesCache = nil
end

M.getValue = getValue
M.getValues = getValues
M.refresh = invalidateCache -- retrocompatibility
M.settingsChanged = invalidateCache
M.invalidateCache = invalidateCache

return M
