-- This Source Code Form is subject to the terms of the bCDDL, var. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = extensions.ui_imgui
local wndName = "Lights Debug"
local wndOpen = false
M.menuEntry = "JBeam Debug/Lights Debug"

local zeroVec = vec3(0,0,0)

local blankColor = ColorF(0,0,0,0)
local yellowColor = ColorF(1,1,0,1)
local whiteColor = ColorF(1,1,1,1)
local blackColorSemiTransparent255 = ColorI(0,0,0,192)
local whiteColor255 = ColorI(255,255,255,255)

local arrowHeadVec = vec3(0,0.075,0)

local q1 = quatFromEuler(0, 0, math.pi * 11/12)
local q2 = quatFromEuler(0, 0, -math.pi * 11/12)
local q3 = quatFromEuler(0, math.pi / 2, 0)

local spotLightDebugEnabled = im.BoolPtr(true)
local pointLightDebugEnabled = im.BoolPtr(true)
local zTestEnabled = im.BoolPtr(false)
local displayNames = im.BoolPtr(true)
local displayAsUnitVectors = im.BoolPtr(false)

local function onVehicleEditorRenderJBeams(dtReal, dtSim, dtRaw)
  local spotLightDebugEnabledVal = spotLightDebugEnabled[0]
  local pointLightDebugEnabledVal = pointLightDebugEnabled[0]

  if not (vEditor.vehicle and vEditor.vdata and wndOpen and (spotLightDebugEnabledVal or pointLightDebugEnabledVal)) then return end

  debugDrawer:setSolidTriCulling(false)

  for i = 0, tableSizeC(vEditor.vdata.props) - 1 do
    local prop = vEditor.vdata.props[i]

    debugDrawer:drawLine(zeroVec, zeroVec, blankColor) -- workaround for bug
    if prop.mesh == "SPOTLIGHT" and spotLightDebugEnabledVal then
      local propObj = vEditor.vehicle:getProp(prop.pid)

      local propFunc = prop.func
      local lightRange = displayAsUnitVectors[0] and 1 or prop.lightRange
      local lightCol = ColorF(prop.lightColor.r / 255, prop.lightColor.g / 255, prop.lightColor.b / 255, 1)
      local lightCol255 = ColorI(prop.lightColor.r, prop.lightColor.g, prop.lightColor.b, 255)

      local worldMat = propObj:getLiveTransformWorld()

      local lightPos = worldMat:getColumn(3) + vEditor.vehiclePos
      local qDir = quat(worldMat:toQuatF())
      local dirVec = qDir * vec3(0, lightRange, 0)

      debugDrawer:drawSphere(lightPos, 0.04, lightCol, not zTestEnabled[0])
      debugDrawer:drawLine(lightPos, lightPos + dirVec, lightCol, not zTestEnabled[0])

      -- two arrow heads so can be viewed from any angle
      debugDrawer:drawTriSolid(
        lightPos + dirVec,
        lightPos + q1 * qDir * arrowHeadVec + dirVec,
        lightPos + q2 * qDir * arrowHeadVec + dirVec,
        lightCol255,
        not zTestEnabled[0]
      )
      debugDrawer:drawTriSolid(
        lightPos + dirVec,
        lightPos + q1 * q3 * qDir * arrowHeadVec + dirVec,
        lightPos + q2 * q3 * qDir * arrowHeadVec + dirVec,
        lightCol255,
        not zTestEnabled[0]
      )

      if displayNames[0] then
        local offset = displayAsUnitVectors[0] and dirVec or dirVec * 0.1

        debugDrawer:drawTextAdvanced(lightPos + offset, propFunc .. " (SL)", whiteColor, true, false, blackColorSemiTransparent255)
      end

      --[[
      local plight = propObj:getLight()

      local innerAngle = 0
      local outerAngle = 10
      local brightness = 10
      local range = prop.lightRange
      local color = ColorF(1, 0, 0, 0)
      local attenuation = vec3(0, 1, 1)
      if prop.lightAttenuation then attenuation = vec3(prop.lightAttenuation) end
      local castShadows = prop.lightCastShadows

      plight:setLightArgs(innerAngle, outerAngle, brightness, range, color, attenuation, castShadows)
      ]]--

    elseif prop.mesh == "POINTLIGHT" and pointLightDebugEnabledVal then
      local propObj = vEditor.vehicle:getProp(prop.pid)

      local propFunc = prop.func
      local lightRange = prop.lightRange
      local lightCol1 = ColorF(prop.lightColor.r / 255, prop.lightColor.g / 255, prop.lightColor.b / 255, 1.0)
      local lightCol2 = ColorF(prop.lightColor.r / 255, prop.lightColor.g / 255, prop.lightColor.b / 255, 0.1)

      local worldMat = propObj:getLiveTransformWorld()

      local lightPos = worldMat:getColumn(3) + vEditor.vehiclePos

      debugDrawer:drawSphere(lightPos, 0.04, lightCol1, not zTestEnabled[0])
      debugDrawer:drawSphere(lightPos, lightRange, lightCol2)

      if displayNames[0] then
        debugDrawer:drawTextAdvanced(lightPos, propFunc .. " (PL)", whiteColor, true, false, blackColorSemiTransparent255)
      end
    end

  end

  --debugDrawer:setSolidTriCulling(true)
end

local function onEditorGui()
  if not vEditor.vehicle then return end
  if editor.beginWindow(wndName, wndName) then
    wndOpen = true
    im.Checkbox("Spotlight Debug (SL)", spotLightDebugEnabled)
    im.Checkbox("Pointlight Debug (PL)", pointLightDebugEnabled)
    im.Checkbox("X-Ray Mode", zTestEnabled)
    im.Checkbox("Display Names", displayNames)
    im.Checkbox("Unit Vectors", displayAsUnitVectors)
  else
    wndOpen = false
  end
  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(200,200))
end

M.open = open

M.onVehicleEditorRenderJBeams = onVehicleEditorRenderJBeams
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M