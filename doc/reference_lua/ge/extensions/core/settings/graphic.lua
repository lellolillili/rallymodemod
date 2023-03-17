-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = "settings_graphic"

-- local/default variables for settings
local CEF_UI_maxSizeHeight = "1080"

local GraphicsQualityGroup  = require('core/settings/graphicsQualityGroup')
local lightingQualityGroup  = GraphicsQualityGroup('core/settings/lightingQuality', 'Lighting Quality')
local shaderQualityGroup    = GraphicsQualityGroup('core/settings/shaderQuality', 'Shader Quality')
local textureQualityGroup   = GraphicsQualityGroup('core/settings/textureQuality', 'Texture Quality')
local meshQualityGroup      = GraphicsQualityGroup('core/settings/meshQuality', 'Mesh Quality')

local overallQualityPresets = jsonReadFile("lua/ge/extensions/core/settings/settingsPresets.json")

local graphicsOptions = nil

local function videoModeFromString( videoModeStr )
  local canvas = scenetree.findObject("Canvas")

  if not canvas then
    return
  end

  local vm = { width = 0, height = 0, displayMode = "", bitDepth = 0, refreshRate = 0, antialiasLevel = 0}
  local entries = split( videoModeStr, ' ')
  local count = tableSize(entries)
  if count == 6 then
    if tonumber( entries[1] ) then vm.width = tonumber( entries[1] ) end
    if tonumber( entries[2] ) then vm.height = tonumber( entries[2] ) end
    if tonumber( entries[4] ) then vm.bitDepth = tonumber( entries[4] ) end
    if tonumber( entries[5] ) then vm.refreshRate = tonumber( entries[5] ) end
    if tonumber( entries[6] ) then vm.antialiasLevel = tonumber( entries[6] ) end

    vm.displayMode = entries[3]
  end

  return vm
end

local function getDefault()
  local data = {}
  local vm = videoModeFromString(TorqueScriptLua.call('getDesktopVideoMode'))
  data.GraphicDisplayResolutions = vm.width .. ' ' .. vm.height
  data.GraphicDisplayRefreshRate = vm.refreshRate
  return data
end

local restartDialogShowed = {}
local function openNeedRestartDialog(reason)
  if not restartDialogShowed[reason] then
    restartDialogShowed[reason] = true
    TorqueScriptLua.call( 'MessageBoxOK', 'This change requires that the game be restarted', 'This change requires that the game be restarted' )
  end
end

local function getAspectRatio( w, h )
  if tonumber(w) and tonumber(h) then
    local aspects = {{w=3,h=2}, {w=4,h=3}, {w=5,h=4}, {w=16,h=9}, {w=16,h=10}, {w=21,h=9}}
    local smallest
    local smallestDiff = math.huge
    local ratio = w /h
    for i=1,#aspects do
      local data = aspects[i]
      local diff = math.abs(ratio - (data.w / data.h))
      if diff < smallestDiff then
        smallestDiff = diff
        smallest = data
      end
    end
    return '('..smallest.w..':'..smallest.h..')'
  end

  return ''
end

local function getGPU()
  local gpu = TorqueScriptLua.getVar( '$pref::Video::gpu' )
  local adapters = GFXInit.getAdapters()
  for _,adapter in ipairs(adapters) do
    if gpu ~= '' and adapter.gpu == gpu then return gpu end
    if gpu == '' and adapter.gpu ~= '' then return adapter.gpu end
  end

  gpu = adapters[1].gpu
  TorqueScriptLua.setVar( '$pref::Video::gpu', gpu )
  return gpu
end

local function getGFX()
  local gfx = TorqueScriptLua.getVar( '$pref::Video::displayDevice' )
  local adapters = GFXInit.getAdapters()
  for _,adapter in ipairs(adapters) do
    if gfx ~= '' and adapter.gfx == gfx then return gfx end
    if gfx == '' and adapter.gfx ~= '' then  return adapter.gfx end
  end

  gfx = adapters[1].gfx
  TorqueScriptLua.setVar( '$pref::Video::displayDevice', gfx )
  return gfx
end

local function buildOptionHelpers()
  local o = {}

  -- Settings GraphicDisplayModes
  o.GraphicDisplayModes = {
    displayMode = "Window",
    get = function ()
      return o.GraphicDisplayModes.displayMode
    end,
    set = function ( value )
      o.GraphicDisplayModes.displayMode = value
    end,
    getModes = function()
      return {keys={"Borderless", "Fullscreen", "Window"},
      values={"ui.options.graphics.displayMode.borderless", "ui.options.graphics.displayMode.fullScreen", "ui.options.graphics.displayMode.window"}}
    end,
    isFullscreen = function()
      return o.GraphicDisplayModes.displayMode == "Fullscreen"
    end,
    isWindow = function()
      return o.GraphicDisplayModes.displayMode == "Window"
    end,
    isBorderless = function()
      return o.GraphicDisplayModes.displayMode == "Borderless"
    end,
    sanitize = function(shouldLog)
      local current = o.GraphicDisplayModes.get()
      local modes = o.GraphicDisplayModes.getModes()
      for _,v in ipairs(modes.keys) do
        if current == v then
          if shouldLog then log('D', 'graphic',"Sanitizing display mode - "..tostring(current)..": Passed.") end
          return
        end
      end
      if shouldLog then log('D', 'graphic',"Sanitizing display mode - "..tostring(current)..": Failed. Patching to display mode 'Window'") end
      o.GraphicDisplayModes.set('Window')
    end
  }

  -- Settings GraphicResolutions
  o.GraphicDisplayResolutions = {
    width = 0,
    height = 0,
    SelectHighestForDisplay = function (displayName)
      local desktopMode = GFXDevice.getDesktopMode()
      local videoModeList = GFXDevice.getDisplayVideoModes(displayName:gsub("/","\\"))
      local bestVm = {width=0, height=0}
      for _,vm in ipairs(videoModeList) do
        if vm.width == bestVm.width then
          if vm.height <= desktopMode.height and vm.height > bestVm.height then
            bestVm.height = vm.height
          end
        else
          if vm.width <= desktopMode.width and vm.width > bestVm.width then
            bestVm.width = vm.width
          end
        end
      end

      o.GraphicDisplayResolutions.width = bestVm.width
      o.GraphicDisplayResolutions.height = bestVm.height
    end,
    getWidthHeight = function ()
      if o.GraphicDisplayResolutions.width == 0 or o.GraphicDisplayResolutions.height == 0 then
        o.GraphicDisplayResolutions.get()
      end
      return o.GraphicDisplayResolutions.width, o.GraphicDisplayResolutions.height
    end,
    get = function ()
      if o.GraphicDisplayResolutions.width == 0 or o.GraphicDisplayResolutions.height == 0 then
        local videoMode = GFXDevice.getDesktopMode()
        o.GraphicDisplayResolutions.width = videoMode.width or 1280
        o.GraphicDisplayResolutions.height = videoMode.height or 720
      end
      return o.GraphicDisplayResolutions.width .. ' ' .. o.GraphicDisplayResolutions.height
    end,
    set = function ( value )
      o.GraphicDisplayResolutions.width, o.GraphicDisplayResolutions.height = value:match(' *(%d*) +(%d*)')
      o.GraphicDisplayResolutions.width = tonumber(o.GraphicDisplayResolutions.width) or 1280
      o.GraphicDisplayResolutions.height = tonumber(o.GraphicDisplayResolutions.height) or 720
    end,
    getModes = function()
      local keys = {}
      local values = {}
      local addedRes = {}

      local getKey = function(vm)
        return vm.width ..' '.. vm.height
      end

      local getValue = function(vm)
        return vm.width..' x '..vm.height..' '..getAspectRatio(vm.width, vm.height)
      end

      local videoModeList = GFXDevice.getDisplayVideoModes(o.GraphicDisplayDriver.get():gsub("/","\\"))
      table.sort(videoModeList, function(a, b)
                                if a.width == b.width then
                                  return a.height > b.height
                                end
                                return a.width > b.width
                              end
                              )

      for k, vm in ipairs(videoModeList) do
        local key = getKey(vm)
        if addedRes[key] == nil and vm.height > 400 then
          addedRes[key] = 1
          table.insert(keys, key)
          table.insert(values, getValue(vm) )
        end
      end
      return {keys=keys, values=values}
    end,
    sanitize = function(shouldLog)
      local current = o.GraphicDisplayResolutions.get()
      local displayMode = o.GraphicDisplayModes.get()
      if displayMode == 'Window' then
        if shouldLog then log('D', 'graphic',"Sanitizing display resolution for Window mode - "..tostring(current)..": Passed.") end
        return
      end
      local modes = o.GraphicDisplayResolutions.getModes()
      for _,v in ipairs(modes.keys) do
        if current == v then
          if shouldLog then log('D', 'graphic',"Sanitizing display resolution - "..tostring(current)..": Passed.") end
          return
        end
      end
      local canvas = scenetree.findObject("Canvas")
      local desktopMode = GFXDevice.getDesktopMode() or {width = 1280, height = 720}
      local newMode = tostring(desktopMode.width)..' '..tostring(desktopMode.height)
      if shouldLog then log('D', 'graphic',"Sanitizing display resolution - "..tostring(current)..": Failed. Patching to "..newMode) end
      o.GraphicDisplayResolutions.set(newMode)
    end,
    init = function ( value )
      o.GraphicDisplayResolutions.width, o.GraphicDisplayResolutions.height = value:match(' *(%d*) +(%d*)')
      o.GraphicDisplayResolutions.width = tonumber(o.GraphicDisplayResolutions.width) or 1280
      o.GraphicDisplayResolutions.height = tonumber(o.GraphicDisplayResolutions.height) or 720
    end,
  }

  -- Settings GraphicDisplayRefreshRates
  o.GraphicDisplayRefreshRates = {
    hertz = 0,
    get = function ()
      if o.GraphicDisplayRefreshRates.hertz == 0 then
        local refreshRates = o.GraphicDisplayRefreshRates.getModes()
        local found = false
        for _,v in ipairs(refreshRates.keys) do
          if o.GraphicDisplayRefreshRates.hertz == v then
            found = true
            break
          end
        end
        if not found then
          local desktopRes = getDesktopVideoMode()
          o.GraphicDisplayRefreshRates.hertz = refreshRates.keys[1] or desktopRes.refreshRate or 60
        end
      end
      return o.GraphicDisplayRefreshRates.hertz
    end,
    set = function ( value )
      local displayMode = o.GraphicDisplayModes.get()
      if displayMode == 'Window' then return end
      if value then
        o.GraphicDisplayRefreshRates.hertz = tonumber(value)
      end
    end,
    getModes = function()
      local keys = {}
      local values = {}
      local addedRes = {}

      local resolutionWidth, resolutionHeight = o.GraphicDisplayResolutions.getWidthHeight()
      local videoModeList = GFXDevice.getDisplayVideoModes(o.GraphicDisplayDriver.get():gsub("/","\\"))
      for k, vm in ipairs(videoModeList) do
        if vm.width == resolutionWidth and vm.height == resolutionHeight then
          local key = vm.refreshRate
          if addedRes[key] == nil and vm.height > 400 then
            addedRes[key] = 1
            table.insert(keys, key)
          end
        end
      end
      table.sort(keys, function(a, b) return a > b end)
      for i=1,#keys do
        table.insert(values, keys[i]..'Hz')
      end
      return {keys=keys, values=values}
    end,
    sanitize = function(shouldLog)
      local current = o.GraphicDisplayRefreshRates.get()
      local displayMode = o.GraphicDisplayModes.get()
      if displayMode == 'Window' then return end
      local modes = o.GraphicDisplayRefreshRates.getModes()
      for _,v in ipairs(modes.keys) do
        if current == v then
          if shouldLog then log('D', 'graphic', "Sanitizing refresh rate - "..tostring(current)..": Passed.") end
          return
        end
      end
      if shouldLog then log('D', 'graphic',"Sanitizing refresh rate - "..tostring(current)..": Failed. Patching to "..tostring(modes.keys[1]).." hertz") end
      o.GraphicDisplayRefreshRates.set(modes.keys[1])
    end
  }

  -- SettingsGraphicDisplayDriver
  o.GraphicDisplayDriver = {
    adapter = nil,
    get = function ()
      if not o.GraphicDisplayDriver.adapter then
        local adapters = GFXInit.getAdapters()
        o.GraphicDisplayDriver.adapter = adapters[1]
      end

      return o.GraphicDisplayDriver.adapter.output:gsub("\\","/")
    end,
    set = function ( value )
      value = value and value:gsub("/","\\") or ""
      local adapters = GFXInit.getAdapters()
      for i, a in ipairs(adapters) do
        if a.output == value then
          o.GraphicDisplayDriver.adapter = a
          return
        end
      end
    end,
    getModes = function()
      local keys = {}
      local values = {}
      local currentGPU = getGPU()
      local currentGFX = getGFX()
      local adapters = GFXInit.getAdapters()
      for k, a in ipairs(adapters) do
        if a.gpu == currentGPU and a.gfx == currentGFX then
          a.output = a.output:gsub("\\","/")
          table.insert(keys, a.output)
          table.insert(values, a.monitor)
        end
      end
      return {keys=keys, values=values}
    end,
    sanitize = function(shouldLog)
      local current = o.GraphicDisplayDriver.get()
      local modes = o.GraphicDisplayDriver.getModes()
      for _,v in pairs(modes.keys) do
        if current == v then
          if shouldLog then log('D', 'graphic',"Sanitizing display - "..tostring(current)..": Passed.") end
          return
        end
      end
      if shouldLog then log('D', 'graphic',"Sanitizing display - "..tostring(current)..": Failed. Patching to display '"..tostring(modes.keys[1]).."'") end
      o.GraphicDisplayDriver.adapter = o.GraphicDisplayDriver.set(modes.keys[1])
    end
  }

  o.GraphicGPU = {
    get = function ()
      return getGPU()
    end,
    set = function ( value )
      local currentGPU = getGPU()
      TorqueScriptLua.setVar( '$pref::Video::gpu', value )
      local newGPU = getGPU()

      if currentGPU ~= newGPU then
        local adapters = GFXInit.getAdapters()
        for k, a in ipairs(adapters) do
          if a.gpu == newGPU then
            a.output = a.output:gsub("/","\\")
            GFXDevice.setDisplayDevice(newGPU)
            return
          end
        end
        openNeedRestartDialog("GraphicGPU")
      end
    end,
    getModes = function()
      local keys = {}
      local values = {}
      local gpus = {}
      local adapters = GFXInit.getAdapters()
      for k, a in ipairs(adapters) do
        if not gpus[a.gpu] then
          table.insert(keys, a.gpu)
          table.insert(values, a.gpu)
          gpus[a.gpu] = true
        end
      end
      return {keys=keys, values=values}
    end
  }

  o.WindowPlacement = {
    placement = "",
    get = function ()
      if o.WindowPlacement.placement == "" then
        local canvas = scenetree.findObject("Canvas")
        o.WindowPlacement.placement =  canvas and canvas:getPlacement() or ""
      end
      return o.WindowPlacement.placement
    end,
    set = function ( value )
      o.WindowPlacement.placement = value
    end,
    init = function ( value )
      o.WindowPlacement.placement = value
    end,
  }

  o.uiUpscaling = {
    get = function()
      return CEF_UI_maxSizeHeight
    end,

    set = function(value)
      CEF_UI_maxSizeHeight = value
      if value ~= TorqueScriptLua.getVar('$CEF_UI::maxSizeHeight') then
        TorqueScriptLua.setVar('$CEF_UI::maxSizeHeight', value)
      end
    end,
    getModes = function()
      return {keys={'1440', '1080', '720', '0'}, values={'2560 x 1440', '1920 x 1080', '1280 x 720', 'Disabled'}}
    end
  }

  o.vulkanEnabled = {
    get = function ()
      return Engine.getVulkanEnabled()
    end,
    set = function ( value )
      Engine.setVulkanEnabled(value)
    end
  }
  o.FPSLimiter = {
    get = function ()
      return Engine.getFPSLimiter()
    end,
    set = function ( value )
      Engine.setFPSLimiter(value)
    end
  }
  o.FPSLimiterEnabled = {
    get = function ()
      return Engine.getFPSLimiterEnabled()
    end,
    set = function ( value )
      Engine.setFPSLimiterEnabled(value)
    end
  }
  o.SleepInBackground = {
    get = function ()
      return Engine.getSleepInBackground()
    end,
    set = function ( value )
      Engine.setSleepInBackground(value)
    end
  }

  -- SettingsGraphicSync
  o.vsync = {
    get = function ()
      local v = tonumber( TorqueScriptLua.getVar('$video::vsync') )
      return v == true or (type(v)=="number" and v > 0)
    end,
    set = function ( value )
      local boolValue = value == true or (type(value)=="number" and value > 0)
      TorqueScriptLua.setVar( '$video::vsync', boolValue )
    end,
    getModes = function()
      return {keys={false, true}, values={'Off', 'On'}}
    end
  }

  o.GraphicAntialiasType = {
    get = function ()
      local value = settings.getValue('GraphicAntialiasType')
      -- log('I','','get GraphicAntialiasType = '..tostring(value))
      return value
    end,
    set = function ( value )
      -- log('I','','setting GraphicAntialiasType = '..tostring(value))
      local smaaPostEffect = scenetree.findObject("SMAA_PostEffect")
      local fxaaPostEffect = scenetree.findObject("FXAA_PostEffect")
      if value == "fxaa" then
        if smaaPostEffect then smaaPostEffect:disable() end
        if fxaaPostEffect then fxaaPostEffect:enable() end
      elseif value == "smaa" then
        if fxaaPostEffect then fxaaPostEffect:disable() end
        if smaaPostEffect then smaaPostEffect:enable() end
      end
      settings.setValue('GraphicAntialiasType', value)
    end,
    getModes = function ()
      return {keys={'smaa', 'fxaa'}, values={'SMAA', 'FXAA'}}
    end
  }

  -- SettingsGraphicAntialias
  o.GraphicAntialias = {
    get = function ()
      return settings.getValue('GraphicAntialias')
    end,
    set = function ( value )
      local SMAA_PostEffect = scenetree.findObject("SMAA_PostEffect")
      if not SMAA_PostEffect then return end
      local FXAA_PostEffect = scenetree.findObject("FXAA_PostEffect")
      if not FXAA_PostEffect then return end
      if tonumber(value) == 0 then
        SMAA_PostEffect:disable()
        FXAA_PostEffect:disable()
      else
        local antialiasType = settings.getValue('GraphicAntialiasType')
        if antialiasType == 'fxaa' then
          FXAA_PostEffect:enable()
        else
          SMAA_PostEffect:enable()
        end
      end
      settings.setValue('GraphicAntialias', value)
    end,
    getModes = function()
      return {keys={"0", "1", "2", "4"}, values={"Off", "x1", "x2", "x4"}}
    end
  }

  -- SettingsGraphicAnisotropic
  o.GraphicAnisotropic = {
    get = function ()
      return tonumber( TorqueScriptLua.getVar( '$pref::Video::defaultAnisotropy' ) )
    end,
    set = function ( value )
      TorqueScriptLua.setVar( '$pref::Video::defaultAnisotropy', value )
    end,
    getModes = function()
      return {keys={"0", "4", "8", "16"}, values={"Off", "x4", "x8", "x16"}}
    end
  }

  -- SettingsGraphicOverallQuality
  o.GraphicOverallQuality = {
    presetKeys = {},
    qualityLevel = '3',
    get = function (value)
      return o.GraphicOverallQuality.qualityLevel
    end,
    set = function (value)
      -- log('I','graphic',' setting GraphicOverallQuality = '..tostring(value))
      if type(value) == 'string' and tonumber(value) then
        value = tonumber(value)
      end
      if type(value) == 'number' then
        local upgrade_old_id_to_name = {'Custom', 'Lowest', 'Low', 'Normal', 'High', 'Ultra'}
        value = upgrade_old_id_to_name[clamp(value + 1, 1, #upgrade_old_id_to_name)]
      end

      o.GraphicOverallQuality.qualityLevel = tostring(value)
      local levelData = overallQualityPresets[value]
      -- log('I','','Overall quality to be applied is '..value..' : '..dumps(levelData))
      for k,v in pairs(levelData) do
        o[k].set(v)
      end
    end,
    getModes = function()
      return {keys={'Custom', 'Lowest', 'Low', 'Normal', 'High', 'Ultra'}, values={'ui.options.graphics.Custom', 'ui.options.graphics.Lowest', 'ui.options.graphics.Low', 'ui.options.graphics.Normal', 'ui.options.graphics.High', 'ui.options.graphics.Ultra'}}
    end,
    init = function ()
      local temp = {}
      for index, group in pairs(overallQualityPresets) do
        for key, presetValue in pairs(group) do
          temp[key] = true
        end
      end
      presetKeys = {}
      for k,v in pairs(temp) do
        table.insert(presetKeys, k)
      end
      -- log('I','','building preset keys: '..dumps(presetKeys))
    end,
    onSettingsChanged = function ()
      -- log('I','','onSettingsChanged called.....')
      local matchedGroupIndex = nil
      for index, group in pairs(overallQualityPresets) do
        -- log('I','','  Checking group: '..tostring(index))
        local matchFound = true
        for _, presetKey in ipairs(presetKeys) do
          local current = o[presetKey].get()
          local presetValue = group[presetKey]
          -- log('I','','      Key: '..presetKey..':  preset = '..tostring(presetValue)..'  current = '..tostring(current))
          if tostring(presetValue) ~= tostring(current) then
            matchFound = false
            break
          end
        end
        if matchFound then
          matchedGroupIndex = index
        end
        -- log('I','','  ---------------- End of: '..index..' match found = '..tostring(matchFound)..'---------------------------')
      end
      -- log('I','','Matched Group Index: '..tostring(matchedGroupIndex))
      if matchedGroupIndex == nil then
        -- log('I','','                              Setting quality to Custom')
        o.GraphicOverallQuality.set(0) -- custom
        return
      end
    end
  }

  -- SettingsGraphicMeshQuality
  o.GraphicMeshQuality = {
    qualityLevel = "Normal",

    get = function ()
      return o.GraphicMeshQuality.qualityLevel
    end,

    set = function ( value )
      if type(value) == 'string' and tonumber(value) then
        value = tonumber(value)
      end
      if type(value) == 'number' then
        local upgrade_old_id_to_name = {'Lowest', 'Low', 'Normal', 'High'}
        value = upgrade_old_id_to_name[clamp(value + 1, 1, #upgrade_old_id_to_name)]
      end

      meshQualityGroup:applyLevel(value)
      o.GraphicMeshQuality.qualityLevel = value
    end,

    getModes = function()
      return {keys={'High', 'Normal', 'Low', 'Lowest'}, values={'ui.options.graphics.High', 'ui.options.graphics.Normal', 'ui.options.graphics.Low', 'ui.options.graphics.Lowest'}}
    end
  }

  -- SettingsGraphicTextureQuality
  o.GraphicTextureQuality = {
    qualityLevel = "Normal",

    get = function ()
      return o.GraphicTextureQuality.qualityLevel
    end,

    set = function ( value )
      if type(value) == 'string' and tonumber(value) then
        value = tonumber(value)
      end
      if type(value) == 'number' then
        local upgrade_old_id_to_name = {'Lowest', 'Low', 'Normal', 'High'}
        value = upgrade_old_id_to_name[clamp(value + 1, 1, #upgrade_old_id_to_name)]
      end

      textureQualityGroup:applyLevel(value)
      o.GraphicTextureQuality.qualityLevel = value
    end,

    getModes = function()
      return {keys={'High', 'Normal', 'Low', 'Lowest'}, values={'ui.options.graphics.High', 'ui.options.graphics.Normal', 'ui.options.graphics.Low', 'ui.options.graphics.Lowest'}}
    end
  }

  -- SettingsGraphicLightingQuality
  o.GraphicLightingQuality = {
    qualityLevel = "Normal",

    get = function ()
      return o.GraphicLightingQuality.qualityLevel
    end,

    set = function ( value )
      if type(value) == 'string' and tonumber(value) then
        value = tonumber(value)
      end
      if type(value) == 'number' then
        local upgrade_old_id_to_name = {'Lowest', 'Low', 'Normal', 'High', 'Ultra'}
        value = upgrade_old_id_to_name[clamp(value + 1, 1, #upgrade_old_id_to_name)]
      end

      lightingQualityGroup:applyLevel(value)
      o.GraphicLightingQuality.qualityLevel = value
    end,

    getModes = function()
      return {keys={'Ultra', 'High', 'Normal', 'Low', 'Lowest'}, values={'ui.options.graphics.Ultra', 'ui.options.graphics.High', 'ui.options.graphics.Normal', 'ui.options.graphics.Low', 'ui.options.graphics.Lowest'}}
    end
  }

  -- SettingsGraphicShaderQuality
  o.GraphicShaderQuality = {
    qualityLevel = "Normal",

    get = function ()
      return o.GraphicShaderQuality.qualityLevel
    end,

    set = function ( value )
      if type(value) == 'string' and tonumber(value) then
        value = tonumber(value)
      end
      if type(value) == 'number' then
        local upgrade_old_id_to_name = {'Lowest', 'Low', 'Normal', 'High'}
        value = upgrade_old_id_to_name[clamp(value + 1, 1, #upgrade_old_id_to_name)]
      end
      shaderQualityGroup:applyLevel(value)
      o.GraphicShaderQuality.qualityLevel = value
    end,

    getModes = function()
      return {keys={'High', 'Normal', 'Low', 'Lowest'}, values={'ui.options.graphics.High', 'ui.options.graphics.Normal', 'ui.options.graphics.Low', 'ui.options.graphics.Lowest'}}
    end
  }

  -- SettingsGraphicPostfxQuality
  o.GraphicPostfxQuality = {
    qualityLevel = "2",
    get = function ()
      return o.GraphicPostfxQuality.qualityLevel
    end,
    set = function ( value )
      -- log('I','graphic','GraphicPostfxQuality = '..tostring(value))
      value = tostring(value)

      if type(value) == 'string' and tonumber(value) then
        value = tonumber(value)
      end
      if type(value) == 'number' then
        if value == -1 then value = 'Custom' end
        if value == 0  then value = 'Lowest' end
        if value == 1  then value = 'Low' end
        if value == 2  then value = 'Normal' end
        if value == 3  then value = 'High' end
      end

      o.GraphicPostfxQuality.qualityLevel = value
      local preset = '$PostFXManager::normalPreset'
      if value == '3' then
        preset = '$PostFXManager::highPreset'
      elseif value == '2' then
        preset = '$PostFXManager::normalPreset'
      elseif value == '1' then
        preset = '$PostFXManager::lowPreset'
      elseif value == '0' then
        preset = '$PostFXManager::lowestPreset'
      else
        return
      end

      local presetFilename = TorqueScriptLua.getVar(preset)
      postFxModule.loadPresetFile(presetFilename)
      postFxModule.settingsApplyFromPreset()
    end,
    getModes = function()
      return {keys={'High', 'Normal', 'Low', 'Lowest', 'Custom'}, values={'ui.options.graphics.High', 'ui.options.graphics.Normal', 'ui.options.graphics.Low', 'ui.options.graphics.Lowest', 'ui.options.graphics.Custom'}}
    end
  }

  -- GraphicDynReflectionEnabled
  o.GraphicDynReflectionEnabled = {
    get = function ()
      return TorqueScriptLua.getVar( '$pref::BeamNGVehicle::dynamicReflection::enabled' ) ~= "0"
    end,
    set = function ( value )
      TorqueScriptLua.setVar( '$pref::BeamNGVehicle::dynamicReflection::enabled', value )
    end
  }

  -- GraphicDynReflectionFacesPerupdate
  o.GraphicDynReflectionFacesPerupdate = {
    get = function ()
      return tonumber( TorqueScriptLua.getVar( '$pref::BeamNGVehicle::dynamicReflection::facesPerUpdate' ) )
    end,
    set = function ( value )
      TorqueScriptLua.setVar( '$pref::BeamNGVehicle::dynamicReflection::facesPerUpdate', value )
    end
  }

  -- GraphicDynReflectionDetail
  o.GraphicDynReflectionDetail = {
    get = function ()
      return tonumber( TorqueScriptLua.getVar( '$pref::BeamNGVehicle::dynamicReflection::detail' ) )
    end,
    set = function ( value )
      TorqueScriptLua.setVar( '$pref::BeamNGVehicle::dynamicReflection::detail', value )
    end
  }

  -- GraphicDynReflectionDistance
  o.GraphicDynReflectionDistance = {
    get = function ()
      return tonumber( TorqueScriptLua.getVar( '$pref::BeamNGVehicle::dynamicReflection::distance' ) )
    end,
    set = function ( value )
      TorqueScriptLua.setVar( '$pref::BeamNGVehicle::dynamicReflection::distance', value )
    end
  }

  -- GraphicDynReflectionTexsize
  o.GraphicDynReflectionTexsize = {
    get = function ()
      local value = math.log(tonumber( TorqueScriptLua.getVar( '$pref::BeamNGVehicle::dynamicReflection::textureSize' ) ) )/math.log( 2 )
      return value - 7
    end,
    set = function ( value )
      value = math.pow(2, value + 7)
      TorqueScriptLua.setVar( '$pref::BeamNGVehicle::dynamicReflection::textureSize', value )
    end
  }

  -- SettingsPostFXDOFGeneralEnabled
  o.PostFXDOFGeneralEnabled = {
    get = function ()
      local DOFPostEffect = scenetree.findObject("DOFPostEffect")
      if not DOFPostEffect then return end
      return DOFPostEffect:isEnabled() ~= false
    end,
    set = function ( value )
      TorqueScriptLua.setVar( '$DOFPostFx::Enable', value )
      local DOFPostEffect = scenetree.findObject("DOFPostEffect")
      if not DOFPostEffect then return end
      if value then
        DOFPostEffect:enable()
      else
        DOFPostEffect:disable()
      end
    end
  }

  -- SettingsPostFXBloomGeneralEnabled
  o.PostFXBloomGeneralEnabled = {
    get = function ()
      return settings.getValue("PostFXBloomGeneralEnabled")
    end,
    set = function ( value )
      settings.setValue("PostFXBloomGeneralEnabled", value)
      local postFX = scenetree.findObject("PostEffectBloomObject")
      if not postFX then return end
      if value then
        postFX:enable()
      else
        postFX:disable()
      end
    end
  }

  -- SettingsPostFXLightRaysEnabled
  o.PostFXLightRaysEnabled = {
    get = function ()
      local LightRayPostFX = scenetree.findObject("LightRayPostFX")
      if not LightRayPostFX then return end
      return LightRayPostFX:isEnabled() ~= false
    end,
    set = function ( value )
      --print("*************LightRayPostFX 2 set")
      local LightRayPostFX = scenetree.findObject("LightRayPostFX")
      if not LightRayPostFX then return end
      TorqueScriptLua.setVar( '$LightRayPostFX::Enable', value )
      if value then
        LightRayPostFX:enable()
      else
        LightRayPostFX:disable()
      end
    end
  }

  -- SettingsPostFXMotionBlurEnabled
  o.PostFXMotionBlurEnabled = {
    get = function ()
      return settings.getValue("PostFXMotionBlurEnabled")
    end,
    set = function ( value )
      settings.setValue("PostFXMotionBlurEnabled", value)
      local fx = scenetree.findObject("PostFxMotionBlur")
      if not fx then return end
      if value then
        fx:enable()
      else
        fx:disable()
      end
    end
  }

  -- SettingsPostFXMotionBlurStrength
  o.PostFXMotionBlurStrength = {
    get = function ()
      return settings.getValue("PostFXMotionBlurStrength")
    end,
    set = function ( value )
      settings.setValue("PostFXMotionBlurStrength", value)
      if scenetree.PostFxMotionBlur then
        scenetree.PostFxMotionBlur.strength = value
      end
    end
  }

  -- PostFXMotionBlurPlayerVehicle
  o.PostFXMotionBlurPlayerVehicle = {
    get = function ()
      return settings.getValue("PostFXMotionBlurPlayerVehicle")
    end,
    set = function ( value )
      settings.setValue("PostFXMotionBlurPlayerVehicle", value)
      BeamNGVehicle.motionBlurPlayerVehiclesEnabled = value
    end
  }

  -- SettingsPostFXSSAOGeneralEnabled
  o.PostFXSSAOGeneralEnabled = {
    get = function ()
      local SSAOPostFx = scenetree.findObject("SSAOPostFx")
      if not SSAOPostFx then return end
      return SSAOPostFx:isEnabled() ~= false
    end,
    set = function ( value )
      --print("********PostFXSSAOGeneralEnabled 2 set") --not tested
      TorqueScriptLua.setVar( '$SSAOPostFx::Enable', value )
      local SSAOPostFx = scenetree.findObject("SSAOPostFx")
      if not SSAOPostFx then return end
      if value then
        SSAOPostFx:enable()
      else
        SSAOPostFx:disable()
      end
    end
  }

  -- SettingsGraphicGrassDensity
  o.GraphicGrassDensity = {
    get = function ()
      return tonumber( TorqueScriptLua.getVar( '$pref::GroundCover::densityScale' ))
    end,
    set = function ( value )
      TorqueScriptLua.setVar( '$pref::GroundCover::densityScale', value )
    end
  }

  -- SettingsGraphicMaxDecalCount
  o.GraphicMaxDecalCount = {
    get = function ()
      return tonumber( TorqueScriptLua.getVar( '$pref::TS::maxDecalCount' ))
    end,
    set = function ( value )
      TorqueScriptLua.setVar( '$pref::TS::maxDecalCount', value )
    end
  }

  -- SettingsGraphicDisableShadows
  o.GraphicDisableShadows = {
    get = function ()
      local levelStr = getConsoleVariable( '$pref::Shadows::disable' )
      if levelStr == "" then
        levelStr = "0"
      end
      return (levelStr)
    end,
    set = function ( value )
      value = tostring(value)
      setConsoleVariable( '$pref::Shadows::disable', value)
    end,
    getModes = function()
      return {keys={'2', '1', '0'}, values={'None', 'Partial', 'All'}}
    end
  }

  graphicsOptions = o

  return o
end

local function onInitSettings(data)
  if false then Engine.vulkanEnabled = data.vulkanEnabled end -- we have decided to not allow enabling vulkan via settings for now. see also graphics.partial.html
  for k,v in pairs(data) do
    if graphicsOptions[k] and type(graphicsOptions[k].init) == 'function' then
      graphicsOptions[k].init(v)
    end
  end
end

local function onFirstUpdateSettings()
  --log('I', 'graphic', 'onFirstUpdateSettings called.....')
  local canvas = scenetree.findObject("Canvas")
  if not canvas then return end

  if TorqueScriptLua.getVar( '$forceFullscreen' ) == "1" then
    local data = getDefault()
    data.GraphicFullscreen = true
    for k, v in pairs(data) do
      settings.setValue(k, v)
    end
  end

  log('D', 'graphic', 'Available Video Modes : '..dumps(graphicsOptions.GraphicDisplayResolutions.getModes().keys))

  canvas:showWindow()
end

local function applyGraphicsState()
  if M.triggered_manual_save then
    log('E','graphic','Detected Saving in progress....ignoring redundant call')
    return
  end

  M.triggered_manual_save = true

  -- save the changes
  settings.requestSave()

  -- set canvas mode
  local canvas = scenetree.findObject("Canvas")

  if not canvas then
    return
  end

  local resolutionWidth, resolutionHeight = graphicsOptions.GraphicDisplayResolutions.getWidthHeight()
  local refreshRate = graphicsOptions.GraphicDisplayRefreshRates.get()

  local displayDriver = graphicsOptions.GraphicDisplayDriver.get()
  displayDriver = displayDriver:gsub("/","\\")
  GFXDevice.setDisplayDevice(displayDriver)

  log('D','graphic','Applying graphic settings: '..tostring(displayDriver)..', '..graphicsOptions.GraphicDisplayModes.get()..', '..tostring(resolutionWidth)..' x '..tostring(resolutionHeight)..' '..tostring(refreshRate)..' Hz')

  local videoMode = {}
  videoMode.width = resolutionWidth
  videoMode.height = resolutionHeight
  videoMode.refreshRate = refreshRate
  videoMode.displayMode = graphicsOptions.GraphicDisplayModes.get()
  GFXDevice.setVideoMode( videoMode )

  if graphicsOptions.GraphicDisplayModes.isWindow() then
    local desiredwindowPlacement = graphicsOptions.WindowPlacement.get()
    canvas:restorePlacement(desiredwindowPlacement)
  end

  if settings.getValue('GraphicTripleMonitorEnabled') then
    local borderFovDeg = settings.getValue('GraphicTripleMonitorBordersFovDeg')
    local centerFovDeg = settings.getValue('GraphicTripleMonitorCenterFovDeg')
    local leftFovDeg = settings.getValue('GraphicTripleMonitorLeftFovDeg')
    local rightFovDeg = settings.getValue('GraphicTripleMonitorRightFovDeg')
    Engine.setRenderMode(((leftFovDeg > 0) or (rightFovDeg > 0)) and "MultiMonitor" or "SingleMonitor", math.rad(centerFovDeg), math.rad(leftFovDeg), math.rad(rightFovDeg), math.rad(borderFovDeg))
  else
    Engine.setRenderMode("SingleMonitor", 0, 0, 0, 0)
  end

  M.triggered_manual_save = false
  M.appliedChanges = true
end

local function refreshGraphicsState(newState)
  local settingState = ""
  if newState.GraphicDisplayDriver then settingState = newState.GraphicDisplayDriver..', ' end
  if newState.GraphicDisplayModes then settingState = settingState..newState.GraphicDisplayModes..', ' end
  if newState.GraphicDisplayResolutions then settingState = settingState..newState.GraphicDisplayResolutions..', ' end
  if newState.GraphicDisplayRefreshRates then settingState = settingState..newState.GraphicDisplayRefreshRates..' Hz, ' end
  if newState.WindowPlacement then settingState = settingState..newState.WindowPlacement end
  -- log('D','graphics', 'Refreshing graphics settings: '..settingState)

  -- Do not move from here. Has to be done first due to its instant save of settings
  -- other options only save when we call applyGraphicsState, so we do not want the new states for
  -- those saved indirectly
  if newState.WindowPlacement and newState.WindowPlacement ~= M.current_windowPlacement then
    if graphicsOptions.WindowPlacement and type(graphicsOptions.WindowPlacement.set) == 'function' then
      graphicsOptions.WindowPlacement.set(newState.WindowPlacement)
      -- Window placement needs to save immediately due to things like pressing Ctrl + L which
      -- will recreate LUA VM thereby causing the Window to be placed in the old place saved in settings
      -- instead of the new one just made by the user, if the user does not close the game, the change is not saved
      -- so we save immediately to prevent that
      settings.refreshTSState(true)
      settings.requestSave()
    end
  end

  local shouldLogSanitizeMessage = false
  if newState.GraphicDisplayDriver and newState.GraphicDisplayDriver ~= M.selected_displayDriver then
    -- dump(tostring(M.selected_displayDriver) .. '  is now  '.. newState.GraphicDisplayDriver)
    if graphicsOptions.GraphicDisplayDriver and type(graphicsOptions.GraphicDisplayDriver.set) == 'function' then
      graphicsOptions.GraphicDisplayDriver.set(newState.GraphicDisplayDriver)
      graphicsOptions.GraphicDisplayResolutions.SelectHighestForDisplay(newState.GraphicDisplayDriver)
    end
  end

  if newState.GraphicDisplayModes and newState.GraphicDisplayModes ~= M.selected_displayMode then
    -- dump(tostring(M.selected_displayMode) .. '  is now  '.. newState.GraphicDisplayModes)
    if graphicsOptions.GraphicDisplayModes and type(graphicsOptions.GraphicDisplayModes.set) == 'function' then
      graphicsOptions.GraphicDisplayModes.set(newState.GraphicDisplayModes)
      shouldLogSanitizeMessage = true
    end
  end

  if newState.GraphicDisplayResolutions and newState.GraphicDisplayResolutions ~= M.selected_resolution then
    -- dump(tostring(M.selected_resolution) .. '  is now  '.. newState.GraphicDisplayResolutions)
    if graphicsOptions.GraphicDisplayResolutions and type(graphicsOptions.GraphicDisplayResolutions.set) == 'function' then
      graphicsOptions.GraphicDisplayResolutions.set(newState.GraphicDisplayResolutions)
      shouldLogSanitizeMessage = true
    end
  end

  -- Update the refresh rate after refreshing the resolution. Refresh rate set depends on the selected resolution
  if newState.GraphicDisplayRefreshRates and newState.GraphicDisplayRefreshRates ~= M.selected_refreshRate then
    -- dump(tostring(M.selected_refreshRate) .. '  is now  '.. newState.GraphicDisplayRefreshRates)
    if graphicsOptions.GraphicDisplayRefreshRates and type(graphicsOptions.GraphicDisplayRefreshRates.set) == 'function' then
      graphicsOptions.GraphicDisplayRefreshRates.set(newState.GraphicDisplayRefreshRates)
    end
  end

  if graphicsOptions.GraphicDisplayModes and graphicsOptions.GraphicDisplayModes.isBorderless() then
    graphicsOptions.GraphicDisplayResolutions.SelectHighestForDisplay(graphicsOptions.GraphicDisplayDriver.get())
  end

  if graphicsOptions.GraphicDisplayDriver then graphicsOptions.GraphicDisplayDriver.sanitize(shouldLogSanitizeMessage) end
  if graphicsOptions.GraphicDisplayModes then graphicsOptions.GraphicDisplayModes.sanitize(shouldLogSanitizeMessage) end
  if graphicsOptions.GraphicDisplayResolutions then graphicsOptions.GraphicDisplayResolutions.sanitize(shouldLogSanitizeMessage) end
  if graphicsOptions.GraphicDisplayRefreshRates then graphicsOptions.GraphicDisplayRefreshRates.sanitize(shouldLogSanitizeMessage) end

  -- Update the states and also allow the other options to refresh internal state
  M.selected_displayMode    = graphicsOptions.GraphicDisplayModes and graphicsOptions.GraphicDisplayModes.get() or ""
  M.selected_displayDriver  = graphicsOptions.GraphicDisplayDriver and graphicsOptions.GraphicDisplayDriver.get() or ""
  M.selected_resolution     = graphicsOptions.GraphicDisplayResolutions and graphicsOptions.GraphicDisplayResolutions.get() or ""
  M.selected_refreshRate    = graphicsOptions.GraphicDisplayRefreshRates and graphicsOptions.GraphicDisplayRefreshRates.get() or ""
  M.current_windowPlacement = graphicsOptions.WindowPlacement and graphicsOptions.WindowPlacement.get() or ""

  settings.refreshTSState(true)
  -- let UI and Lua know
  settings.notifyUI()
end

local function onUiChangedState(toState, fromState)
  if toState == 'menu.options.graphics' then
    M.selected_displayMode = settings.getValue('GraphicDisplayModes', "Window")
    M.selected_displayDriver = settings.getValue('GraphicDisplayDriver', "")
    M.selected_resolution = settings.getValue('GraphicDisplayResolutions', "0 0")
    M.selected_refreshRate = settings.getValue('GraphicDisplayRefreshRates', 0)
    M.current_windowPlacement = settings.getValue('WindowPlacement', " ")
  elseif fromState == 'menu.options.graphics' then
    if not M.appliedChanges then
      refreshGraphicsState({GraphicDisplayModes = M.selected_displayMode, GraphicDisplayResolutions = M.selected_resolution, GraphicDisplayRefreshRates = M.selected_refreshRate})
    end

    M.appliedChanges = false
  end
end

local function load(newState)
  refreshGraphicsState(newState)
  applyGraphicsState()
end

local function openMonitorConfiguration()
end

local function autoDetectApplyGraphicsQuality()
  --
  -- TODO(AK) 15/08/2021: RE-Enable after Porting TS startup to LUA
  --                      RE-Enable after Porting TS startup to LUA
  --                      RE-Enable after Porting TS startup to LUA
  --                      RE-Enable after Porting TS startup to LUA
  --                      RE-Enable after Porting TS startup to LUA
  --                      RE-Enable after Porting TS startup to LUA
  --                      RE-Enable after Porting TS startup to LUA
  --

  -- TorqueScriptLua.setVar('$pref::Video::autoDetect', false)
  -- local shaderVer = getPixelShaderVersion()
  -- local intel = string.find(string.upper(getDisplayDeviceInformation()), "INTEL") ~= nil
  -- local videoMem = GFXDevice.getVideoMemoryMB()

  -- if videoMem == 0 then
  --     log('E','graphic', "Unable to detect available video memory. Applying 'Normal' quality.");
  --     videoMem = 500
  -- end

  -- if videoMem > 1000 then
  --   graphicsOptions.GraphicMeshQuality.set("High")
  --   graphicsOptions.GraphicTextureQuality.set("High")
  --   graphicsOptions.GraphicLightingQuality.set("High")
  --   graphicsOptions.GraphicShaderQuality.set("High")
  --   TorqueScriptLua.call('PostFXManager::settingsApplyHighPreset')
  --   graphicsOptions.GraphicPostfxQuality.set(3)
  -- elseif videoMem >= 500 then
  --   graphicsOptions.GraphicMeshQuality.set("Normal")
  --   graphicsOptions.GraphicTextureQuality.set("Normal")
  --   graphicsOptions.GraphicLightingQuality.set("Normal")
  --   graphicsOptions.GraphicShaderQuality.set("Normal")
  --   TorqueScriptLua.call('PostFXManager::settingsApplyNormalPreset')
  --   graphicsOptions.GraphicPostfxQuality.set(2)
  -- elseif videoMem > 250 then
  --   graphicsOptions.GraphicMeshQuality.set("Low")
  --   graphicsOptions.GraphicTextureQuality.set("Low")
  --   graphicsOptions.GraphicLightingQuality.set("Low")
  --   graphicsOptions.GraphicShaderQuality.set("Low")
  --   TorqueScriptLua.call('PostFXManager::settingsApplyLowPreset')
  --   graphicsOptions.GraphicPostfxQuality.set(1)
  -- else
  --   graphicsOptions.GraphicMeshQuality.set("Lowest")
  --   graphicsOptions.GraphicTextureQuality.set("Lowest")
  --   graphicsOptions.GraphicLightingQuality.set("Lowest")
  --   graphicsOptions.GraphicShaderQuality.set("Lowest")
  --   TorqueScriptLua.call('PostFXManager::settingsApplyLowestPreset')
  --   graphicsOptions.GraphicPostfxQuality.set(0)
  -- end
end

local function toggleFullscreen()
  local canvas = scenetree.findObject("Canvas")

  if canvas then
    canvas:toggleFullscreen()
  end
end

M.getOptions = function(optionName)
  return optionName and graphicsOptions[optionName] or graphicsOptions
end

M.onSettingsChanged = function()
  graphicsOptions.GraphicOverallQuality.onSettingsChanged()
end
M.load = load
M.buildOptionHelpers = buildOptionHelpers
M.onInitSettings = onInitSettings
M.onFirstUpdateSettings = onFirstUpdateSettings
M.refreshGraphicsState = refreshGraphicsState
M.applyGraphicsState = applyGraphicsState
M.onUiChangedState = onUiChangedState
M.openMonitorConfiguration = openMonitorConfiguration
M.autoDetectApplyGraphicsQuality = autoDetectApplyGraphicsQuality
M.toggleFullscreen = toggleFullscreen
M.getOverallQualityPresets = function() return overallQualityPresets end
return M
