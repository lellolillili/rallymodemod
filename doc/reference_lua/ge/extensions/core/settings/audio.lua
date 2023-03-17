-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function createAudioProviderDevice()
  --log( 'D', 'settings.audio', 'createAudioProviderDevice' )
  -- validate options
  local devices = Engine.Audio.getInfo()
  local providerOK = false

  local audioProviderName = TorqueScriptLua.getVar( '$pref::SFX::providerName' )
  for n, p in pairs(devices) do
    if n == audioProviderName then
      providerOK = true
      break
    end
  end

  if not providerOK then
    log( 'E', 'settings.audio', 'incorrect audio provider: "' .. tostring(audioProviderName) .. '": ' .. dumps(devices) )

    local firstProviderName = ''
    for n, d in pairs(devices) do
      if n ~= 'Null' then
        firstProviderName = n
        break
      end
    end

    audioProviderName = firstProviderName
    if devices[firstProviderName] then
      TorqueScriptLua.setVar( '$pref::SFX::providerName', audioProviderName )
      log( 'W', 'settings.audio', 'set provider to ' .. tostring(audioProviderName))
    end
  end

  local useHardware = Engine.Audio.getCanUseHardware()
  if TorqueScript.eval( 'sfxCreateDevice($pref::SFX::providerName, '..tostring(useHardware)..', -1);' ) == '0' then
    audioProviderName = TorqueScriptLua.getVar( '$pref::SFX::providerName' )
    log( 'E', 'createAudioProviderDevice', 'Unable to create SFX device: '..audioProviderName..' '..useHardware );
  end
end

local audioOptions = nil
local function buildOptionHelpers()
  local o = {}

  -- SettingsAudioProvider
  o.AudioProvider = {
    get = function() return TorqueScriptLua.getVar('$pref::SFX::providerName') end,
    set = function ( value )
      TorqueScriptLua.setVar( '$pref::SFX::providerName', value )
      createAudioProviderDevice()
    end,
    getModes = function()
      local keys = {}
      local values = {}
      local added = {}

      local deviceList = be:sfxGetAvailableDevices()
      local entries = string.match( deviceList, '(.*)\n')
      entries = split( entries, '\n' )
      for k, v in ipairs(entries) do
        local record = split( v, '\t')
        --dump(record)
        local provider = record[1]
        if provider ~= '' and not provider:upper():find('NULL') and not added[provider] then
          table.insert(keys, provider)
          table.insert(values, provider)
          added[provider] = true
        end
      end
      return {keys=keys, values=values}
    end
  }

  -- SettingsAudioMasterVol
  o.AudioMasterVol = {
    get = function()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelMaster'))
    end,
    set = function(value)
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelMaster', value)
    end
  }

  -- SettingsAudioPowerVol
  o.AudioPowerVol = {
    get = function()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelPower'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelPower', value)
    end
  }

  -- SettingsAudioForcedInductionVol
  o.AudioForcedInductionVol = {
    get = function()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelForcedInduction'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelForcedInduction', value)
    end
  }

  -- SettingsAudioTransmissionVol
  o.AudioTransmissionVol = {
    get = function()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelTransmission'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelTransmission', value)
    end
  }

  -- SettingsAudioSuspensionVol
  o.AudioSuspensionVol = {
    get = function()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelSuspension'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelSuspension', value)
    end
  }

  -- AudioSurfaceVol
  o.AudioSurfaceVol = {
    get = function ()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelSurface'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelSurface', value)
    end
  }

  -- AudioCollisionVol
  o.AudioCollisionVol = {
    get = function ()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelCollision'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelCollision', value)
    end
  }

  -- AudioAeroVol
  o.AudioAeroVol = {
    get = function ()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelAero'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelAero', value)
    end
  }

  -- AudioEnvironmentVol
  o.AudioEnvironmentVol = {
    get = function ()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelEnvironment'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelEnvironment', value)
    end
  }

  -- AudioMusicVol
  o.AudioMusicVol = {
    get = function ()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelMusic'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelMusic', value)
    end
  }

  -- SettingsAudioUiVol
  o.AudioUiVol = {
    get = function ()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelUi'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelUi', value)
    end
  }

  -- AudioOtherVol
  o.AudioOtherVol = {
    get = function ()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelOther'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelOther', value)
    end
  }

  -- AudioLfeVol
  o.AudioLfeVol = {
    get = function ()
      return tonumber(TorqueScriptLua.getVar('$pref::SFX::AudioChannelLfe'))
    end,
    set = function ( value )
      value = clamp(value, 0.0, 1.0)
      Engine.Audio.setChannelVolume('AudioChannelLfe', value)
    end
  }

  -- AudioEnableStereoHeadphones
  o.AudioEnableStereoHeadphones = {
    enabled = false,
    get = function()
      return o.AudioEnableStereoHeadphones.enabled
    end,
    set = function( enabled )
      if o.AudioEnableStereoHeadphones.enabled ~= enabled then
        TorqueScriptLua.setVar('$pref::SFX::enableHeadphonesMode', enabled)
        o.AudioEnableStereoHeadphones.enabled = enabled
        core_audio.triggerBankHotloading()
        if o.AudioMasterVol then o.AudioMasterVol.set(o.AudioMasterVol.get() or 0) end
        if o.AudioInterfaceVol then o.AudioInterfaceVol.set(o.AudioInterfaceVol.get() or 0) end
        if o.AudioUiVol then o.AudioUiVol.set(o.AudioUiVol.get() or 0) end
        if o.AudioAmbienceVol then o.AudioAmbienceVol.set(o.AudioAmbienceVol.get() or 0) end
        if o.AudioMusicVol then o.AudioMusicVol.set(o.AudioMusicVol.get() or 0) end
      end
    end
  }

  audioOptions = o
  return o
end

local function restoreDefaults()
  audioOptions.AudioMasterVol.set(1.0)
  audioOptions.AudioPowerVol.set(0.8)
  audioOptions.AudioForcedInductionVol.set(0.8)
  audioOptions.AudioTransmissionVol.set(0.8)
  audioOptions.AudioSuspensionVol.set(0.8)
  audioOptions.AudioSurfaceVol.set(0.8)
  audioOptions.AudioCollisionVol.set(0.8)
  audioOptions.AudioAeroVol.set(0.8)
  audioOptions.AudioEnvironmentVol.set(0.8)
  audioOptions.AudioMusicVol.set(0.8)
  audioOptions.AudioUiVol.set(0.8)
  audioOptions.AudioOtherVol.set(0.8)
  audioOptions.AudioLfeVol.set(0.5)

  settings.refreshTSState(true)
  settings.notifyUI()
  settings.requestSave()
end

local function onFirstUpdateSettings(data)
  createAudioProviderDevice()
end

M.getOptions = function() return audioOptions end
M.restoreDefaults = restoreDefaults
M.buildOptionHelpers = buildOptionHelpers
M.onFirstUpdateSettings = onFirstUpdateSettings
return M
