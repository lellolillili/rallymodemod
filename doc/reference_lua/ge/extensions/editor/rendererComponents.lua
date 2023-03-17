-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper for the level people, so they can mark things :)

local M = {}

local im = ui_imgui
local imUtils = require('ui/imguiUtils')
local rcAPI = require('util/renderComponentsAPI')
local postfxUtils = require('client/postFx/utils')
local settings = {}
local toolWindowName = "rendererComponents"

local types = {
  string = 1,
  float = 2,
  float3 = 3,
  float4 = 4,
  texture = 5,
  separator = 6
}

local HDRsettings = {
  ["Luminance"] = {
    objectName = "PostEffectLuminanceObject",
    order = 1,
    fields = {
      {
        identifier = "deltaRealTime",
        name = "Delta Real Time",
        description = "Delta Real Time",
        type = types.float,
        readonly = true,
        format = "%.3f",
      }
    }
  },
  ["Combine Pass"] = {
    objectName = "PostEffectCombinePassObject",
    order = 2,
    fields = {
      {
        identifier = "enabled",
        name = "Enabled",
        description = "Enabled",
        type = types.float,
        clampMin = 0,
        clampMax = 1,
        format = "%.0f"
      },
      {
        type = types.separator
      },
      {
        identifier = "bloomScale",
        name = "Bloom Scale",
        description = "Blends between the scene and the bloomed scene.",
        type = types.float,
        clampMin = 0,
        clampMax = 1,
        format = "%.2f"
      },
      {
        identifier = "enableBlueShift",
        name = "Blue Shift Enabled",
        description = "Blends between the scene and the blue shifted version of the scene for a cinematic desaturated night effect",
        type = types.float,
        clampMin = 0,
        clampMax = 1,
        format = "%.2f"
      },
      {
        identifier = "blueShiftLumVal",
        name = "Blue Shift Luminance Value",
        description = "Blue Shift Luminance Value",
        type = types.float,
        clampMin = 0,
        clampMax = 1,
        format = "%.2f"
      },
      {
        identifier = "blueShiftColor",
        name = "Blue Shift Color",
        description = "Blue Shift Color",
        type = types.float3
      },

      {
        identifier = "colorCorrectionRampPath",
        name = "Color Correction Ramp Path",
        description = "Color Correction Ramp Path",
        type = types.texture
      },
      {
        identifier = "colorCorrectionStrength",
        name = "Color Correction Strength",
        description = "Color Correction Strength",
        type = types.float,
        clampMin = 0,
        clampMax = 1,
        format = "%.2f"
      },
      {
        identifier = "HSL",
        name = "HSL",
        description = "The blue shift color value.",
        type = types.float4,
      },
      {
        identifier = "maxAdaptedLum",
        name = "Max Adapted Lum Value",
        description = "Max Adapted Lum Value - If it's set to 1.0, auto exposure is disabled.",
        type = types.float,
        clampMin = 1,
        clampMax = 10,
        format = "%.2f"
      },
      {
        identifier = "middleGray",
        name = "Middle Gray",
        description = [[The tone mapping middle grey or exposure value used to adjust the overall "balance" of the image.]],
        type = types.float,
        clampMin = 0,
        clampMax = 1,
        format = "%.2f"
      },
      {
        identifier = "oneOverGamma",
        name = "One Over Gamma",
        description = "One Over Gamma = 1 / Gamma",
        type = types.float,
        format = "%.2f",
        readonly = true
      },
    }
  }
}

local lightraysSettings = {
  ["brightness"] = {
    default = 0.75,
    range = { 0, 2 }
  },
  ["enable"] = {
    default = true
  }
}

local tempBoolPtr = im.BoolPtr(true)
local tempFloatPtr = im.FloatPtr(0)
local tempFloatArr3 = ffi.new("float[3]", {0, 0, 0})
local tempFloatArr4 = ffi.new("float[4]", {0, 0, 0, 0})
local tempCharPtr = im.ArrayChar(256, "")

-- in string; out string
local function getTempFloat(value)
  if value then
    local res = tonumber(value)
    if res then
      tempFloatPtr[0] = res
    else
      editor.logError(logTag .. "Cannot parse float value '" .. value .. "'! Fallback to 0.")
      tempFloatPtr[0] = 0
    end
    return tempFloatPtr
  else
    return string.format('%f', tempFloatPtr[0])
  end
end

-- in string; out string
local function getTempFloatArray3(value)
  if value then
    local res = split(value, " ")
    local tblLength = #res

    if tblLength == 3 then
      tempFloatArr3[0] = tonumber(res[1])
      tempFloatArr3[1] = tonumber(res[2])
      tempFloatArr3[2] = tonumber(res[3])
    else
      editor.logError(logTag .. "Cannot parse color string '" .. value .. "'! Fallback to white.")
      tempFloatArr3[0] = 1.0
      tempFloatArr3[1] = 1.0
      tempFloatArr3[2] = 1.0
    end

    return tempFloatArr3
  else
    return string.format('%f %f %f', tempFloatArr3[0], tempFloatArr3[1], tempFloatArr3[2])
  end
end

-- in string; out string
local function getTempFloatArray4(value)
  if value then
    local res = split(value, " ")
    local tblLength = #res

    if tblLength == 4 then
      tempFloatArr4[0] = tonumber(res[1])
      tempFloatArr4[1] = tonumber(res[2])
      tempFloatArr4[2] = tonumber(res[3])
      tempFloatArr4[3] = tonumber(res[4])
    else
      editor.logError(logTag .. "Cannot parse color string '" .. value .. "'! Fallback to white.")
      tempFloatArr4[0] = 1.0
      tempFloatArr4[1] = 1.0
      tempFloatArr4[2] = 1.0
      tempFloatArr4[3] = 1.0
    end

    return tempFloatArr4
  else
    return string.format('%f %f %f %f', tempFloatArr4[0], tempFloatArr4[1], tempFloatArr4[2], tempFloatArr4[3])
  end
end

-- in string; out string
local function getTempCharPtr(value)
  if value then
    ffi.copy(tempCharPtr, value)
    return tempCharPtr
  else
    return ffi.string(tempCharPtr)
  end
end

local function widgetFloat(obj, field)
  local value = obj:getField(field.identifier, 0)
  if value then

    if field.readonly then
      if field.format then
        im.TextUnformatted(string.format(field.format, value))
      else
        im.TextUnformatted(value)
      end
    else
      im.PushItemWidth(im.GetContentRegionAvailWidth())
      if im.SliderFloat("##" .. field.identifier, getTempFloat(value), field.clampMin or 0, field.clampMax or 100, field.format or "%.3f") then
        obj:setField(field.identifier, 0, getTempFloat())
      end
      im.PopItemWidth()
    end
  end
  im.NextColumn()
end

local function widgetFloat3(obj, field)
  local value = obj:getField(field.identifier, 0)
  if value then
    if field.readonly then
      im.TextUnformatted(value)
    else
      im.PushItemWidth(im.GetContentRegionAvailWidth())
      if im.ColorEdit3("##" .. field.identifier, getTempFloatArray3(value), im.flags(im.ColorEditFlags_HDR, im.ColorEditFlags_Float)) then
        obj:setField(field.identifier, 0, getTempFloatArray3())
      end
      im.PopItemWidth()
    end
  end
  im.NextColumn()
end

local function widgetFloat4(obj, field)
  local value = obj:getField(field.identifier, 0)
  if value then
    if field.readonly then
      im.TextUnformatted(value)
    else
      im.PushItemWidth(im.GetContentRegionAvailWidth())
      if im.ColorEdit4("##" .. field.identifier, getTempFloatArray4(value), im.flags(im.ColorEditFlags_HDR, im.ColorEditFlags_Float)) then
        obj:setField(field.identifier, 0, getTempFloatArray4())
      end
      im.PopItemWidth()
    end
  end
  im.NextColumn()
end

local function widgetTexture(obj, field)
  local value = obj:getField(field.identifier, 0)
  if value then

    local function openFileDialog(dir)
      editor_fileDialog.openFile(
        function(data)
          obj:setField(field.identifier, 0, data.filepath)
        end,
        {{"Any files", "*"},{"Images",{".png", ".dds", ".jpg"}},{"PNG",".png"},{"JPG",{".jpg", ".jpeg"}},{"DDS",".dds"}},
        false,
        dir,
        true
      )
    end

    if editor.uiIconImageButton(
      editor.icons.folder,
      im.ImVec2(24, 24)
    ) then
      local dir = path.splitWithoutExt(value)
      openFileDialog(dir)
    end
    im.tooltip("Open file dialog")
    im.SameLine()

    tempBoolPtr[0] = false
    im.PushItemWidth(im.GetContentRegionAvailWidth() + (widthMod or 0))
    editor.uiInputText(
      "##" .. field.identifier,
      getTempCharPtr(value),
      nil,
      im.InputTextFlags_AutoSelectAll,
      nil,
      nil,
      tempBoolPtr
    )
    im.PopItemWidth()

    if tempBoolPtr[0] == true then
      obj:setField(field.identifier, 0, getTempCharPtr())
    end

  end
  im.NextColumn()
end

local sortFunc = function(a,b) return (HDRsettings[a].order or 100) < (HDRsettings[b].order or 100) end

local function renderPostFXGui()
  if im.CollapsingHeader1("Lighting", im.TreeNodeFlags_DefaultOpen) then
    local sortedHDRsettings = tableKeys(HDRsettings)
    table.sort(sortedHDRsettings, sortFunc)
    for _, pfxName in ipairs(sortedHDRsettings) do
      if im.TreeNode1(pfxName) then
        local data = HDRsettings[pfxName]
        local obj = scenetree.findObject(data.objectName)

        if obj and data.fields then
          im.Columns(2)
          for _, field in ipairs(data.fields) do
            if field.name then im.TextUnformatted(field.name) end
            if field.description then
              im.tooltip(field.description)
            end
            im.NextColumn()
            if field.type == types.float then
              widgetFloat(obj, field)
            elseif field.type == types.float3 then
              widgetFloat3(obj, field)
            elseif field.type == types.float4 then
              widgetFloat4(obj, field)
            elseif field.type == types.texture then
              widgetTexture(obj, field)
            elseif field.type == types.separator then
              im.Separator()
              im.NextColumn()
            else
              im.TextUnformatted('-type not implemented-')
            end
          end
          im.Columns(1)
        end
        im.TreePop()
      end
    end

    im.TextColored(editor.color.warning.Value, "Changes won't be saved. This is only for testing purposes.")
  end
end

local function renderSettingsGui(settingNode, path, level)
  level = level + 1
  for _, s in pairs(settingNode) do
    local newPath = path .. '/' .. tostring(s.name)
    local nodeType = s.type or 'sliderFloat'
    local changed = false

    if nodeType == 'sliderFloat' and s.range then
      if not s.cVal then
        local initialValue = s.default or s.range[1]
        if s.tsVar then
          --print(newPath .. ' = ' .. tostring(TorqueScriptLua.getVar(s.tsVar)) .. ' (' .. tostring(s.tsVar) .. ')')
          initialValue = tonumber(TorqueScriptLua.getVar(s.tsVar)) or 0
        end
        --print("initialValue = " .. tostring(initialValue))
        s.cVal = im.FloatPtr(initialValue)
      end
      if im.SliderFloat((s.title or s.name) .. '##' .. tostring(newPath), s.cVal, s.range[1], s.range[2]) then
        --print('value changed: ' .. tostring(newPath) .. ' = ' .. tostring(s.cVal[0]))
        if s.tsVar then
          rcAPI.setSetting(s.tsVar, s.cVal[0])
        end
        changed = true
      end
    elseif nodeType == 'bool' then
      if not s.cVal then
        local initialValue = s.default
        if s.tsVar then
          initialValue = tonumber(TorqueScriptLua.getVar(s.tsVar))
        end
        s.cVal = im.BoolPtr(initialValue ~= 0)
      end
      if im.Checkbox((s.title or s.name) .. '##' .. tostring(newPath), s.cVal) then
        --print('value changed: ' .. tostring(newPath) .. ' = ' .. tostring(s.cVal[0]))
        if s.tsVar then
          local val = 0
          if s.cVal[0] then val = 1 end
          rcAPI.setSetting(s.tsVar, val)
        end
        changed = true
      end
    elseif nodeType == 'combo' then
      if not s.cVal then
        local initialValue = s.default
        if s.tsVar then
          initialValue = tonumber(TorqueScriptLua.getVar(s.tsVar))
        end
        --print("initialValue = " .. tostring(initialValue))
        s.cVal = initialValue
        s.valMap = {}
        for ck, cv in pairs(s.values) do
          s.valMap[cv] = ck
        end
      end

      if im.BeginCombo((s.title or s.name) .. '##' .. tostring(newPath), s.valMap[s.cVal]) then
        for ck, cv in pairs(s.values) do
          local selected = s.values
          if im.Selectable1(ck, cv == s.cVal) then
            s.cVal = cv
            --print('value changed: ' .. tostring(newPath) .. ' = ' .. tostring(s.cVal))
            if s.tsVar then
              rcAPI.setSetting(s.tsVar, s.cVal)
            end
            changed = true
          end
        end
        im.EndCombo()
      end
    elseif nodeType == 'color' then
      if not s.cVal then
        local initialValue = s.default
        if s.tsVar then
          initialValue = split(TorqueScriptLua.getVar(s.tsVar), ' ')
        end
        s.cVal = ffi.new('float[4]', tonumber(initialValue[1]), tonumber(initialValue[2]), tonumber(initialValue[3]), tonumber(initialValue[4]))
      end

      if im.ColorEdit4((s.title or s.name) .. '##' .. tostring(newPath), s.cVal) then
        if s.tsVar then
          local tsValStr = tostring(s.cVal[0]) .. ' ' .. tostring(s.cVal[1]) .. ' ' .. tostring(s.cVal[2]) .. ' ' .. tostring(s.cVal[3])
          rcAPI.setSetting(s.tsVar, tsValStr)
        end
        changed = true
      end
    elseif type(s.settings) == 'table' then
      if level == 1 then
        if im.CollapsingHeader1(tostring(s.title or s.name)) then -- newPath
          renderSettingsGui(s.settings, newPath, level)
        end
      else
        if im.TreeNode1(tostring(s.title or s.name)) then -- newPath
          renderSettingsGui(s.settings, newPath, level)
          im.TreePop()
        end
      end
    else
      im.TextUnformatted("TODO: unknown type: " .. tostring(nodeType))
    end
  end
end

local DOFSettings = {
  ['enable'] = {
    default=false
  },
  ['enableDebugMode'] = {
    default=false
  },
  ['focusSettings'] = {
    blurMin = {
      range = {0, 1},
      default = 0,
    },
    blurMax = {
      range= {0, 1},
      default= 0,
    },
    blurCurveNear = {
      range= {1, 500},
      default= 0,
    },
    blurCurveFar = {
      range= {1, 500},
      default= 0,
    },
    focusRangeMin = {
      range= {0, 100},
      default= 0.01,
    },
    focusRangeMax = {
      range= {0, 1000},
      default= 0.01,
    }
  }
}


local function initialiseSettings()
  DOFSettings['enable'].default = TorqueScriptLua.getBoolVar("$DOFPostFx::Enable")
  DOFSettings['enable'].value = DOFSettings['enable'].default

  DOFSettings['enableDebugMode'].default = TorqueScriptLua.getBoolVar("$DOFPostFx::EnableDebugMode")
  DOFSettings['enableDebugMode'].value = DOFSettings['enableDebugMode'].default

  DOFSettings['focusSettings'].blurMin.default = tonumber(TorqueScriptLua.getVar("$DOFPostFx::BlurMin"))
  DOFSettings['focusSettings'].blurMin.value = DOFSettings['focusSettings'].blurMin.default

  DOFSettings['focusSettings'].blurMax.default = tonumber(TorqueScriptLua.getVar("$DOFPostFx::BlurMax"))
  DOFSettings['focusSettings'].blurMax.value = DOFSettings['focusSettings'].blurMax.default

  DOFSettings['focusSettings'].blurCurveNear.default = tonumber(TorqueScriptLua.getVar("$DOFPostFx::BlurCurveNear"))
  DOFSettings['focusSettings'].blurCurveNear.value = DOFSettings['focusSettings'].blurCurveNear.default

  DOFSettings['focusSettings'].blurCurveFar.default = tonumber(TorqueScriptLua.getVar("$DOFPostFx::BlurCurveFar"))
  DOFSettings['focusSettings'].blurCurveFar.value = DOFSettings['focusSettings'].blurCurveFar.default

  DOFSettings['focusSettings'].focusRangeMin.default = tonumber(TorqueScriptLua.getVar("$DOFPostFx::FocusRangeMin"))
  DOFSettings['focusSettings'].focusRangeMin.value = DOFSettings['focusSettings'].focusRangeMin.default

  DOFSettings['focusSettings'].focusRangeMax.default = tonumber(TorqueScriptLua.getVar("$DOFPostFx::FocusRangeMax"))
  DOFSettings['focusSettings'].focusRangeMax.value = DOFSettings['focusSettings'].focusRangeMax.default


  lightraysSettings['enable'].default = TorqueScriptLua.getBoolVar("$LightRayPostFX::Enable")
  lightraysSettings['enable'].value = lightraysSettings['enable'].default

  lightraysSettings['brightness'].default = tonumber(TorqueScriptLua.getVar("$LightRayPostFX::brightScalar"))
  lightraysSettings['brightness'].value = lightraysSettings['brightness'].default
end

local function renderBloomTab()
  im.Dummy(im.ImVec2(0, 5))
  if im.Checkbox('Debug##Lighting' .. tostring(newPath), tempBoolPtr) then
  end
  im.Dummy(im.ImVec2(0, 5))
  im.Separator()
  im.TextUnformatted("Brightness")
  im.Dummy(im.ImVec2(0, 5))
  local rangeMin = 0
  local rangeMax = 1
  im.TextUnformatted("Tone Mapping Contrast")
  im.SameLine()
  if im.SliderFloat("##lightingToneMappingBrightness", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.TextUnformatted("Key Value")
  im.SameLine()
  if im.SliderFloat("##lightingKeyValue", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.TextUnformatted("Minimum Luminance")
  im.SameLine()
  if im.SliderFloat("##lightingMinLuminance", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.TextUnformatted("White Cutoff")
  im.SameLine()
  if im.SliderFloat("##lightingWhiteCutoff", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.TextUnformatted("Brightness Adapted Rate")
  im.SameLine()
  if im.SliderFloat("##lightingBrightnessAdaptedRate", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.Dummy(im.ImVec2(0, 5))
  im.Separator()
  im.TextUnformatted("Bloom")
  im.Dummy(im.ImVec2(0, 5))
  if im.Checkbox('Enable Bloom##Bloom', tempBoolPtr) then
  end
  im.TextUnformatted("Bright Pass Threshold")
  im.SameLine()
  if im.SliderFloat("##lightingBrightPassThreshold", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.TextUnformatted("Blur Multiplier")
  im.SameLine()
  if im.SliderFloat("##lightingBlurMultiplier", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.TextUnformatted("Blur 'Mean' value")
  im.SameLine()
  if im.SliderFloat("##lightingBlurMeanvalue", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.TextUnformatted("Blur 'Std Mean' value")
  im.SameLine()
  if im.SliderFloat("##lightingBlurStdMeanvalue", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  im.Dummy(im.ImVec2(0, 5))
  im.Separator()
  im.TextUnformatted("Effects")
  im.Dummy(im.ImVec2(0, 5))
  if im.Checkbox('Enable Color Shift##Effects', tempBoolPtr) then
  end
  if im.SliderFloat("##lightingEffectsShift1", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  if im.SliderFloat("##lightingEffectsShift2", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
  if im.SliderFloat("##lightingEffectsShift3", getTempFloat(0), rangeMin, rangeMax, "%.3f") then
  end
end

local function renderDepthOfFieldTab()
  local DOFPostEffect = scenetree.findObject("DOFPostEffect")
  if not DOFPostEffect then
    return
  end

  DOFPostEffect = Sim.upcast(DOFPostEffect)

  im.Dummy(im.ImVec2(0, 5))
  tempBoolPtr[0] = DOFSettings['enable'].value
  if im.Checkbox('Enable##' .. tostring(newPath), tempBoolPtr) then
    DOFSettings['enable'].value = tempBoolPtr[0]
    TorqueScriptLua.setVar("$DOFPostEffect::Enable", DOFSettings['enable'].value)
    if tempBoolPtr[0] then
      DOFPostEffect.obj:enable()
    else
      DOFPostEffect.obj:disable()
    end
  end
  im.SameLine()
  tempBoolPtr[0] = DOFSettings['enableDebugMode'].value
  if im.Checkbox('Debug Viz##' .. tostring(newPath), tempBoolPtr) then
    DOFSettings['enableDebugMode'].value = tempBoolPtr[0]
    -- TorqueScriptLua.setVar("$PostFXManager::Settings::DOF::EnableDebugMode", DOFSettings['enableDebugMode'].value)
    TorqueScriptLua.setVar("$DOFPostFx::EnableDebugMode", DOFSettings['enableDebugMode'].value)
    DOFPostEffect.debugModeEnabled = DOFSettings['enableDebugMode'].value
  end
  im.Dummy(im.ImVec2(0, 5))
  im.Separator()
  im.TextUnformatted("Focus Settings")
  im.Dummy(im.ImVec2(0, 5))
  im.TextUnformatted("Near Blur")
  im.SameLine()
  local blurMin = DOFSettings['focusSettings'].blurMin
  tempFloatPtr[0] = blurMin.value or blurMin.default
  if im.SliderFloat("##dofFocusNearBlur", tempFloatPtr, blurMin.range[1], blurMin.range[2], "%.3f") then
    blurMin.value = tempFloatPtr[0]
    DOFPostEffect.nearBlurMax = blurMin.value
    TorqueScriptLua.setVar("$DOFPostFx::BlurMin", blurMin.value)
  end
  im.TextUnformatted("Far Blur")
  im.SameLine()
  local blurMax = DOFSettings['focusSettings'].blurMax
  tempFloatPtr[0] = blurMax.value or blurMax.default
  if im.SliderFloat("##dofFocusFarBlur", tempFloatPtr, blurMax.range[1], blurMax.range[2], "%.3f") then
    blurMax.value = tempFloatPtr[0]
    DOFPostEffect.farBlurMax = blurMax.value
    TorqueScriptLua.setVar("$DOFPostFx::BlurMax", blurMax.value)
  end
  im.TextUnformatted("Aperture")
  im.SameLine()
  local blurCurveFar = DOFSettings['focusSettings'].blurCurveFar
  tempFloatPtr[0] = blurCurveFar.value or blurCurveFar.default
  if im.SliderFloat("##dofFocusAperture", tempFloatPtr, blurCurveFar.range[1], blurCurveFar.range[2], "%.3f") then
     blurCurveFar.value = tempFloatPtr[0]
     DOFPostEffect.farSlope = blurCurveFar.value
     TorqueScriptLua.setVar("$DOFPostFx::BlurCurveFar", blurCurveFar.value)
  end
  im.TextUnformatted("Aperture Fine")
  im.SameLine()
  local focusRangeMin = DOFSettings['focusSettings'].focusRangeMin
  tempFloatPtr[0] = focusRangeMin.value or focusRangeMin.default
  if im.SliderFloat("##dofFocusApertureFine", tempFloatPtr, focusRangeMin.range[1], focusRangeMin.range[2], "%.3f") then
    focusRangeMin.value = tempFloatPtr[0]
    DOFPostEffect.minRange = focusRangeMin.value
    TorqueScriptLua.setVar("$DOFPostFx::FocusRangeMin", focusRangeMin.value)
  end
  im.TextUnformatted("Focus Distance")
  im.SameLine()
  local focusRangeMax = DOFSettings['focusSettings'].focusRangeMax
  tempFloatPtr[0] = focusRangeMax.value or focusRangeMax.default
  if im.SliderFloat("##dofFocusFocusDistance", tempFloatPtr, focusRangeMax.range[1], focusRangeMax.range[2], "%.3f") then
    focusRangeMax.value = tempFloatPtr[0]
    DOFPostEffect.maxRange = focusRangeMax.value
    TorqueScriptLua.setVar("$DOFPostFx::FocusRangeMax", focusRangeMax.value)
  end
  im.Dummy(im.ImVec2(0, 15))
  if im.Button("Reset to defaults") then
    postFxModule.loadPresetFile("core/scripts/client/postFx/presets/defaultPostfxPreset.postfx")
    postFxModule.applyDOFPreset()
    initialiseSettings()
  end
end

local function renderLightRaysTab()
  im.Dummy(im.ImVec2(0, 5))
  tempBoolPtr[0] = lightraysSettings['enable'].value
  if im.Checkbox('Enable##Lightrays', tempBoolPtr) then
    lightraysSettings['enable'].value = tempBoolPtr[0]
    TorqueScriptLua.setVar("$PostFXManager::PostFX::EnableLightRays", lightraysSettings['enable'].value)
    local lightRayPostFX = scenetree.findObject("LightRayPostFX")
    if lightRayPostFX then
      lightRayPostFX = Sim.upcast(lightRayPostFX)
      if lightraysSettings['enable'].value then
        lightRayPostFX.obj:enable()
      else
        lightRayPostFX.obj:disable()
      end
    end
  end

  im.Dummy(im.ImVec2(0, 5))
  local rangeMin = lightraysSettings['brightness'].range[1]
  local rangeMax = lightraysSettings['brightness'].range[2]
  tempFloatPtr[0] = lightraysSettings['brightness'].value
  im.TextUnformatted("Brightness")
  im.SameLine()
  if im.SliderFloat("##lightraysBrightness", tempFloatPtr, rangeMin, rangeMax, "%.3f") then
    lightraysSettings['brightness'].value = tempFloatPtr[0]
    TorqueScriptLua.setVar("$LightRayPostFX::brightScalar", lightraysSettings['brightness'].value)
  end
  im.Dummy(im.ImVec2(0, 15))
  if im.Button("Reset to defaults") then
    postFxModule.loadPresetFile("core/scripts/client/postFx/presets/defaultPostfxPreset.postfx")
    postFxModule.applyLightRaysPreset()
    initialiseSettings()
  end
end

local function renderHDRLightingTab()
  local sortedHDRsettings = tableKeys(HDRsettings)
  table.sort(sortedHDRsettings, sortFunc)
  for _, pfxName in ipairs(sortedHDRsettings) do
    if im.TreeNode1(pfxName) then
      local data = HDRsettings[pfxName]
      local obj = scenetree.findObject(data.objectName)

      if obj and data.fields then
        im.Columns(2)
        for _, field in ipairs(data.fields) do
          if field.name then im.TextUnformatted(field.name) end
          if field.description then
            im.tooltip(field.description)
          end
          im.NextColumn()
          if field.type == types.float then
            widgetFloat(obj, field)
          elseif field.type == types.float3 then
            widgetFloat3(obj, field)
          elseif field.type == types.float4 then
            widgetFloat4(obj, field)
          elseif field.type == types.texture then
            widgetTexture(obj, field)
          elseif field.type == types.separator then
            im.Separator()
            im.NextColumn()
          else
            im.TextUnformatted('-type not implemented-')
          end
        end
        im.Columns(1)
      end
      im.TreePop()
    end
  end

  im.TextColored(editor.color.warning.Value, "Changes won't be saved. This is only for testing purposes.")
end

local function buildPresetButtons()
  im.Columns(4)
  local buttonSize = im.ImVec2(im.GetContentRegionAvailWidth(), 42)
  if im.Button("Load Preset...", buttonSize) then
    postfxUtils.loadPresets()
  end
  im.NextColumn()
  if im.Button("Save Preset...", buttonSize) then
    postfxUtils.savePresets()
  end
  im.NextColumn()
  if im.Button("Revert", buttonSize) then
  end
  im.NextColumn()
  if im.Button("Save", buttonSize) then
  end
  im.Columns(1)
end

local function buildTabsFromSettings(settings)
  local tabNames = {}
  for _, s in pairs(settings) do
    local tabTitle = s.name or ""
    table.insert(tabNames, tabTitle)
  end
  table.sort(tabNames)

  if im.BeginTabBar("settings") then
    for _, tabName in pairs(tabNames) do
      local entry = settings[tabName]
      local title = entry.title or entry.name or ""
      if im.BeginTabItem(title, nil, im.TabItemFlags_None) then
        renderSettingsTab(entry, tabName)
        im.EndTabItem()
      end
    end
    im.EndTabBar()
  end
end

-- local function onEditorGui()
--   if editor.beginWindow(toolWindowName, "Renderer Components") then
--     renderSettingsGui(settings, "", 0)
--     im.Separator()
--     -- im.Separator()
--     -- im.Separator()
--     renderPostFXGui()
--   end
--   editor.endWindow()
-- end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Renderer Components", im.WindowFlags_MenuBar) then
    if im.BeginMenuBar() then
      if im.BeginMenu("File", imgui_true) then
        if im.MenuItem1("Load Preset...",nil,imgui_false,imgui_true) then
           postfxUtils.loadPresets()
        end
        if im.MenuItem1("Save Preset...",nil,imgui_false,imgui_true) then
          postfxUtils.savePresets()
        end
        im.EndMenu()
      end
      if im.MenuItem1("Reset All", nil, imgui_true) then
        postFxModule.loadPresetFile("core/scripts/client/postFx/presets/defaultPostfxPreset.postfx")
        postFxModule.settingsApplyFromPreset()
        initialiseSettings()
      end
      im.EndMenuBar()
    end
    im.Dummy(im.ImVec2(0, 10))

    if im.BeginTabBar("settings") then
      -- if im.BeginTabItem("Bloom", nil, im.TabItemFlags_None) then
      --   renderBloomTab()
      --   im.EndTabItem()
      -- end

      if im.BeginTabItem("Depth of Field", nil, im.TabItemFlags_None) then
        renderDepthOfFieldTab()
        im.EndTabItem()
      end

      if im.BeginTabItem("HDR", nil, im.TabItemFlags_None) then
        renderHDRLightingTab();
        im.EndTabItem()
      end


      if im.BeginTabItem("Light Rays", nil, im.TabItemFlags_None) then
        renderLightRaysTab()
        im.EndTabItem()
      end

      if im.BeginTabItem("Motion Blur", nil, im.TabItemFlags_None) then
        local mb = scenetree.PostFxMotionBlur
        if mb then
          tempBoolPtr[0] = mb and mb:isEnabled()
          if im.Checkbox('Enable##MotionBlur', tempBoolPtr) then
            mb:toggle()
          end

          tempFloatPtr[0] = mb.strength
          if im.SliderFloat("##MB", tempFloatPtr, 0.001, 3, "%.3f") then
            mb.strength = tempFloatPtr[0]
          end

          tempBoolPtr[0] = BeamNGVehicle.motionBlurAllVehiclesEnabled
          if im.Checkbox('Enable for vehicles##MotionBlur', tempBoolPtr) then
            BeamNGVehicle.motionBlurAllVehiclesEnabled = tempBoolPtr[0]
          end

          tempBoolPtr[0] = BeamNGVehicle.motionBlurPlayerVehiclesEnabled
          if im.Checkbox('Enable for player vehicles##MotionBlur', tempBoolPtr) then
            BeamNGVehicle.motionBlurPlayerVehiclesEnabled = tempBoolPtr[0]
          end
        end
        im.EndTabItem()
      end

      
      if im.BeginTabItem("Bloom", nil, im.TabItemFlags_None) then
        local mb = scenetree.PostEffectBloomObject
        if mb then
          tempBoolPtr[0] = mb and mb:isEnabled()
          if im.Checkbox('Enable##Bloom', tempBoolPtr) then
            mb:toggle()
          end

          tempFloatPtr[0] = mb.threshHold
          if im.SliderFloat("ThreshHold##Bloom", tempFloatPtr, 0.001, 5, "%.3f") then
            mb.threshHold = tempFloatPtr[0]
          end
          
          tempFloatPtr[0] = mb.knee
          if im.SliderFloat("Knee##Bloom", tempFloatPtr, 0.001, 5, "%.3f") then
            mb.knee = tempFloatPtr[0]
          end
        end
        im.EndTabItem()
      end

      im.EndTabBar()
    end

    editor.endWindow()
  end
end

local function onWindowMenuItem()
  settings = rcAPI.getSettings(true)
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(300, 500))
  editor.addWindowMenuItem("Renderer Components", onWindowMenuItem)
  settings = rcAPI.getSettings(true)
  postFxModule.backupCurrentSettings()
  initialiseSettings()
end

M.onEditorActivated = function()
  local DOFPostEffect = scenetree.findObject("DOFPostEffect")
  if DOFPostEffect then
    DOFPostEffect = Sim.upcast(DOFPostEffect)
    DOFPostEffect.debugModeEnabled = DOFSettings['enableDebugMode'].value
    if DOFSettings['enable'].value then
      DOFPostEffect.obj:enable()
    else
      DOFPostEffect.obj:disable()
    end
  end

  local lightRayPostFX = scenetree.findObject("LightRayPostFX")
  if lightRayPostFX then
    lightRayPostFX = Sim.upcast(lightRayPostFX)
    if lightraysSettings['enable'].value then
      lightRayPostFX.obj:enable()
    else
      lightRayPostFX.obj:disable()
    end
  end
end

-- public interface
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorEnabled = onEditorEnabled

return M