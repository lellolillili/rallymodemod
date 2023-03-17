-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.impl = require("settings")
local options = {
  uiUnitLength = {modes={keys={'metric','imperial'}, values={'ui.unit.metric', 'ui.unit.imperial'}}},
  uiUnitTemperature = {modes={keys={'c', 'f', 'k'}, values={'ui.unit.c', 'ui.unit.f', 'ui.unit.k'}}},
  uiUnitWeight = {modes={keys={'lb', 'kg'}, values={'ui.unit.lb', 'ui.unit.kg'}}},
  uiUnitConsumptionRate = {modes={keys={'metric', 'imperial'}, values={'ui.unit.ltr100', 'ui.unit.mpg'}}},
  uiUnitTorque = {modes={keys={'metric', 'imperial'}, values={'ui.unit.nm', 'ui.unit.lbft'}}},
  uiUnitEnergy = {modes={keys={'metric', 'imperial'}, values={'ui.unit.j', 'ui.unit.ftlb'}}},
  uiUnitDate = {modes={keys={'ger', 'uk', 'us'}, values={'DD.MM.YYYY', 'DD/MM/YYYY', 'MM/DD/YYYY'}}},
  uiUnitPower = {modes={keys={'hp', 'bhp', 'kw'}, values={'ui.unit.hp', 'ui.unit.bhp', 'ui.unit.kw'}}},
  uiUnitVolume = {modes={keys={'l', 'gal'}, values={'ui.unit.l', 'ui.unit.gal'}}},
  uiUnitPressure = {modes={keys={'inHg', 'bar', 'psi', 'kPa'}, values={'ui.unit.inHg', 'ui.unit.bar', 'ui.unit.psi', 'ui.unit.kPa'}}},

  uiUpscaling = {modes={keys={'disabled', '720', '1080', '1440'}, values={'Disabled', '1280 x 720', '1920 x 1080', '2560 x 1440'}}},
  onlineFeatures = {modes={keys={'enable', 'disable'}, values={'ui.common.enable', 'ui.common.disable'}}},
  telemetry = {modes={keys={'enable', 'disable'}, values={'ui.common.enable', 'ui.common.disable'}}},
  defaultGearboxBehavior = {modes={keys={'arcade', 'realistic'}, values={'ui.common.arcade', 'ui.common.realistic'}}},
  absBehavior = {modes={keys={'realistic', 'off', 'arcade'}, values={'ui.common.ABSrealistic', 'ui.common.ABSoff', 'ui.common.ABSarcade'}}},
  escBehavior = {modes={keys={'arcade', 'realistic', 'off'}, values={'ui.common.arcade', 'ui.common.realistic', 'ui.common.off'}}},
  spawnVehicleIgnitionLevel = {modes={keys={0, 1, 2, 3}, values={'ui.common.vehicleOff', 'ui.common.vehicleAccessoryOn', 'ui.common.vehicleOn', 'ui.common.vehicleRunning'}}},
  trafficSetup = {modes={keys={'smart', 'smartConfigs', 'random', 'randomConfigs', 'simple'}, values={'ui.common.smart', 'ui.common.smartConfigs', 'ui.common.random', 'ui.common.randomConfigs', 'ui.common.simpleVehicles'}}},
  communityTranslations = {modes={keys={'enable', 'disable'}, values={'ui.common.enable', 'ui.common.disable'}}},
  showMissionMarkers = {set = function(s) extensions.hook("showMissionMarkersToggled", s) end},
  AudioMaxVoices = { modes={keys={512, 384, 256, 128}, values={'ui.options.audio.Ultra', 'ui.options.audio.High', 'ui.options.audio.Normal', 'ui.options.audio.Low'}} },
}

local values = deepcopy(M.impl.defaultValues)
local lastSavedTime = 0

local function notifyUI()
  guihooks.trigger('SettingsChanged', {values = values, options = options})
end

local function deprecateTSFeatureFlags()
  removeConsoleVariable("$pref::Video::canvasSize");
  removeConsoleVariable("$pref::Video::mode");
end

local alreadySaving = false
local function save()
  if M.loadingSettingsInProgress then
    --log("W", "", "This call to save() settings is being ignored, because it is flagged as a recursive call via 'M.loadingSettingsInProgress'. This should not happen, please review callstack below:")
    --print(debug.tracesimple())
    return
  end

  if alreadySaving then
    --log("W", "", "This call to save() settings is being ignored, because it is flagged as a recursive call via 'alreadySaving'. This should not happen, please review callstack below:")
    --print(debug.tracesimple())
    return
  end
  lastSavedTime = os.clock()
  alreadySaving = true

  -- save options
  local localValues = {}
  local cloudValues = {}
  for k, v in pairs(values) do
    if values[k] == M.impl.defaultValues[k] then -- TODO do a deep table compare instead
      -- already the default, don't save it
    else
      if     (M.impl.defaults[k] or {})[1] == "local"    then
        localValues[k] = values[k]
      elseif (M.impl.defaults[k] or {})[1] == "cloud"   then
        cloudValues[k] = values[k]
      elseif (M.impl.defaults[k] or {})[1] == "discard" then
        -- don't save anywhere
      else
        localValues[k] = values[k]
      end
    end
  end
  FS:directoryCreate(M.impl.path)
  jsonWriteFile(M.impl.pathLocal, localValues, true)
  jsonWriteFile(M.impl.pathCloud, cloudValues, true)

  deprecateTSFeatureFlags()
  TorqueScript.eval(string.format('export("$pref::*", "%s" , False);', settings.impl.pathTorquescript))

  -- let UI and Lua know
  notifyUI()
  commands.onSettingsChanged()
  core_settings_graphic.onSettingsChanged()
  extensions.hook('onSettingsChanged')
  be:queueAllObjectLua('onSettingsChanged()')
  alreadySaving = false
end

local function refreshTSState(withValue)
  if withValue then
    for k,o in pairs(options) do
      if type(o.get) == 'function' then
        values[k] = o.get()
      end
    end
  end
  for k,o in pairs(options) do
    if type(o.getModes) == 'function' then
      o.modes = o.getModes()
    end
  end
end

local appliedLanguage = ""
local function refreshLanguages()
  -- 0) ask c++ what language is active right now, so we can see if it changed later
  local oldLanguage = Lua:getSelectedLanguage()

  if (appliedLanguage ~= "" and oldLanguage ~= "" and appliedLanguage == oldLanguage) then
    if (values.userLanguage == appliedLanguage) then
      -- log('D','','       no language change requried.')
      return
    end
  else
    log('D','','refreshLanguages(): oldLanguage = '..dumps(oldLanguage)..'  appliedLanguage = '..dumps(appliedLanguage)..' userLanguage = '..dumps(values.userLanguage))
    log('D','','       switching language.')
  end

  local languageMap = require('utils/languageMap') -- load locally, so we don't have it hanging around in memory all the time

  -- 1) set new language
  Lua.userLanguage = values.userLanguage
  -- 2) ask C++ for the correct language
  Lua:reloadLanguages()
  -- 3) get the language that c++ chose
  values.userLanguageSelected = Lua:getSelectedLanguage()
  values.userLanguageSelectedLong = languageMap.resolve(values.userLanguageSelected)
  -- ui language is the same
  values.uiLanguage = values.userLanguageSelected
  --print(' * userLanguageSelected: ' .. tostring(values.userLanguageSelected) .. ' [' .. tostring(values.userLanguageSelectedLong) .. ']')

  -- info things for the UI, not used in the decision process
  -- list available languages
  options.userLanguagesAvailable = {}
  table.insert(options.userLanguagesAvailable, {key="", name="Automatic", isOfficial=true}) -- the empty ('') language will be auto - it'll use the OS/steam lang
  local locales = FS:findFiles('/locales/', '*.json', -1, true, false)

  for _, l in pairs(locales) do
    local key = string.match(l, 'locales/([^\\.]+).json')

    table.insert(options.userLanguagesAvailable, {key=key, name = languageMap.resolve(key), isOfficial=isOfficialContentVPath(l)})
  end
  --print(' * languagesAvailable: ' .. dumps(options.userLanguagesAvailable))

  -- detailed info, only for the user
  values.languageOS = Lua:getOSLanguage()
  values.languageOSLong = languageMap.resolve(values.languageOS)
  --print(' * languageOS: ' .. tostring(values.languageOS) .. ' [' .. tostring(values.languageOSLong) .. ']')
  values.languageProvider = Lua:getSteamLanguage()
  values.languageProviderLong = Steam and Steam.language or ""
  --print(' * languageProvider: ' .. tostring(values.languageProvider) .. ' [' .. tostring(values.languageProviderLong) .. ']')

  -- was the language changed?
  local languageChanged = Lua:getSelectedLanguage() ~= oldLanguage
  if values.userLanguage ~= Lua:getSelectedLanguage() then
    -- the system chose another one, set back to automatic
    languageChanged = true
    values.userLanguage = ''
  end
  appliedLanguage = Lua:getSelectedLanguage()
  --print(' - languageChanged >> ' .. tostring(languageChanged) .. ' | "' .. tostring(Lua:getSelectedLanguage()) .. '" ~= ' .. tostring(oldLanguage))

  -- send the new state to the UI
  if languageChanged or M.newTranslationsAvailable then
    notifyUI()
    if ui_imgui and ui_imgui.ctx ~= nil then
      for index=0, ui_imgui.IoFontsGetCount() - 1 do
        if string.startswith(ffi.string(ui_imgui.IoFontsGetName(index)), translateLanguage("ui.fonts.filename", "segoeui.ttf")) then
          log("D", "", "set font: " .. ffi.string(ui_imgui.IoFontsGetName(index)))
          ui_imgui.SetDefaultFont(index)
          break
        end
      end
    end
  end
end

local function setState(newState, ignoreCache)
  if newState == nil then return end
  local isChanged = false

  -- Graphics quality groups that have preset values for groups of graphic settings
  local graphicQualityGroups = {'GraphicOverallQuality', 'GraphicMeshQuality', 'GraphicTextureQuality', 'GraphicLightingQuality', 'GraphicShaderQuality','GraphicPostfxQuality'}

  local sortedKeys = {}
  for k,_ in pairs(newState) do
    if not tableContains(graphicQualityGroups, k) then
      table.insert(sortedKeys, k)
    end
  end

  table.sort(sortedKeys)

  -- Apply Graphics Quality states first because these control other settings that the user may have changed to create a custom setting
  for _,qualityKey in ipairs(graphicQualityGroups) do
    local value = newState[qualityKey]
    if value then
      isChanged = M.setValue(qualityKey, value, ignoreCache) or isChanged
    end
  end

  for _, k in ipairs(sortedKeys) do
    local s = newState[k]
    isChanged = M.setValue(k, s, ignoreCache) or isChanged
  end

  if not isChanged and not ignoreCache then return end

  -- get valid state from TS
  refreshTSState(true)

  if not M.loadingSettingsInProgress then
    save()
  else
    --log("W", "", "This call from setState to save() settings is not even attempted, because it is flagged via 'M.loadingSettingsInProgress' as a recursive call. This should not happen, please review callstack below:")
    --print(debug.tracesimple())
  end

  -- we can update the dynamic collision state on the fly
  if values.disableDynamicCollision ~= nil then
    be:setDynamicCollisionEnabled(not values.disableDynamicCollision)
  end

  local extLoaded = extensions.isExtensionLoaded('ui_extApp')
  if values.externalUI2 and not extLoaded then
    extensions.load('ui_extApp')
  elseif not values.externalUI2 and extLoaded then
    extensions.unload('ui_extApp')
  end

  refreshLanguages()
end

local delayWriteTimer = 0
local function settingsTick(dtReal, dtSim, dtRaw)
  -- log('I','','settingsTick running... delayWriteTimer = '..tostring(delayWriteTimer)..'  dtReal = '..tostring(dtReal)..'  dtRaw = '..tostring(dtRaw))
  delayWriteTimer = delayWriteTimer - math.min(dtReal, 0.05) -- 20 fps = 0.05 sec
  if delayWriteTimer < 0 then
    save()
    delayWriteTimer = 0
    M.settingsTick = nop
  end
end

local function requestSave()
  delayWriteTimer = 0.5
  M.settingsTick = settingsTick
end

local settingInProgress = {}
local function setValue(key, value, ignoreCache)
  if settingInProgress[key] then
    --log("W", "", "This call to setValue() settings is being ignored, because it is flagged as a recursive call via 'M.settingInProgress["..dumps(key).."]'. This should not happen, please review callstack below:")
    --print(debug.tracesimple())
    return
  end

  settingInProgress[key] = true

  -- log('I','settings','setValue called  key = '..tostring(key)..'  value = '..tostring(value))
  -- apply to memory right now
  local stateDirty = false
  if ignoreCache or values[key] == nil or (tostring(s) ~= tostring(values[key])) then
    stateDirty = true
    values[key] = value
    if options[key] and type(options[key].set) == 'function' then
      options[key].set(value)
    end
  end

  settingInProgress[key] = false

  -- delay writing to disk
  if stateDirty and not M.loadingSettingsInProgress then
   M.requestSave()
  end

  return stateDirty
end

local function getValue(key, defaultValue)
  if values[key] == nil then
    return defaultValue
  end
  return values[key]
end

local function loadSettingValues()
  M.impl.invalidateCache()
  local data = M.impl.getValues()

  if data.userColorPresets then
    data.userColorPresets = data.userColorPresets:gsub("'", '"') -- replace ' with "
    local ok, userColorPresets = pcall(json.decode, data.userColorPresets)
    if ok then
      local emptyMetallicData = {}
      local paints = {}
      for _, colorString in ipairs(userColorPresets)do
        local color = stringToTable(colorString)
        local paint = createVehiclePaint({x=color[1], y=color[2], z=color[3], w=color[4]}, emptyMetallicData)
        table.insert(paints, paint)
      end
      data.userPaintPresets = jsonEncode(paints)
      data.userColorPresets = nil
    else
      --pcall puts the error message in the 2nd return value
      log('W', '', "Couldn't decode json for userColorPresets: "..dumps(userColorPresets))
      log('W', '', "JSON data: "..dumps(data.userColorPresets))
    end
  end

  return data
end

local function load(ignoreCache)
  M.loadingSettingsInProgress = true
  -- ensure translation.zip is mounted before reloading the languages
  local translationsFilename = '/mods/translations.zip'
  if FS:fileExists(translationsFilename) and not FS:isMounted(translationsFilename) then
    FS:mount(translationsFilename)
  end

  refreshTSState(true)
  local newState = deepcopy(values)
  local data = loadSettingValues()
  tableMerge(newState, data)

  setState(newState, ignoreCache)
  core_settings_graphic.load(newState)

  if CppSettings.lastError ~= "" then
    -- any CppSettings error is logged before any console exists, so can be overlooked easily. We log it again here, for greater visibility
    log("E", "", "Last detected C++ settings error: "..CppSettings.lastError)
    log("E", "", "Please fix the issue, and then restart the program so the correct values are used by the C++ engine")
    guihooks.trigger("toastrMsg", {type="error", title="CppSettings error", msg=CppSettings.lastError})
  end
  M.loadingSettingsInProgress = false
end

local function initSettings(reason)
 -- fix the options up and combine the keys and values into the dict
  for k,v in pairs(options) do
    if v.keys and v.values and not v.dict then
      v.dict = {}
      for i = 0, tableSizeC(v.keys) - 1 do
        v.dict[v.keys[i]] = v.values[i]
      end
    end
  end

  -- build option helpers
  extensions.load({"core_settings_graphic","core_settings_audio"})
  tableMerge(options, core_settings_graphic.buildOptionHelpers())
  tableMerge(options, core_settings_audio.buildOptionHelpers())
  -- add C++ propagation wherever possible
  for k,v in pairs(M.impl.defaults) do
    if CppSettings[k] ~= nil then -- check if C++ side cares about this setting
      options[k] = options[k] or {}
      if options[k].set == nil then
        -- no setter is defined, add one that propagates the value to C++ side
        options[k].set = function(value)
          if type(CppSettings[k]) == type(value) then
            CppSettings[k] = value
          else
            log("E", "", string.format("Unable to parse setting '%s': it should be a %s, but is a %s. The ignored value is: %s", k, type(CppSettings[k]), type(value), dumps(value)))
          end
        end
      else
        -- a setter was already defined, cannot add a setter to propagate value to C++ side
        log("E", "", string.format("Unable to propagate setting '%s' to C++ side, since it already has a custom setter in LUA side: this is likely a conflict of intentions that requires bugfixing", k))
      end
    end
  end

  -- load the persistency file at least
  local data = loadSettingValues()
  tableMerge(values, data)

  core_settings_graphic.onInitSettings(values)
end

local function finalizeInit()
  -- force application of all settings the first time, since init() has not correctly applied all of them
  -- we could make init() call load(), but that would fail because it's still too early, and some stuff is not initialized yet
  load(true)
  core_settings_graphic.onFirstUpdateSettings()
  core_settings_audio.onFirstUpdateSettings()

  local techLicense = ResearchVerifier.isTechLicenseVerified()

  if not techLicense and values.onlineFeatures == 'enable' and values.telemetry == 'enable' then
    extensions.load('telemetry/gameTelemetry')
    telemetry_gameTelemetry.startTelemetry()
  end
end

local function onFilesChanged(files)
  if alreadySaving then
    return
  end

  local settingFileChanged = false
  for _,v in pairs(files) do
    if (v.filename == M.impl.pathLocal or v.filename == M.impl.pathCloud) and (os.clock()-lastSavedTime) > 5 then
      settingFileChanged = true
      break
    end
  end
  if settingFileChanged then
    load(false)
  end
end

M.exit = function ()
  save()
end

M.finalizeInit = finalizeInit
M.onFilesChanged = onFilesChanged
M.notifyUI = notifyUI
M.requestState = notifyUI -- retrocompatibility
M.refreshTSState = refreshTSState
M.requestSave = requestSave
M.setState = setState
M.setValue = setValue
M.getValue = getValue
M.save = requestSave
M.load = load
M.initSettings = initSettings
M.settingsTick = nop
return M
