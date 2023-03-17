-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.menuEntry = "Debug/General Data"
local im = extensions.ui_imgui
local imguiUtils = require('ui/imguiUtils')
local wndName = "General Data"

local function formatVec3(x, y, z)
  local formatStringX = (sign(x) ~= -1 and " " or "") .. "%.4f"
  local formatStringY = (sign(y) ~= -1 and " " or "") .. "%.4f"
  local formatStringZ = (sign(z) ~= -1 and " " or "") .. "%.4f"
  return string.format(formatStringX .. ", " .. formatStringY .. ", " .. formatStringZ, x, y, z)
end

local function onEditorGui()
  if not vEditor.vehicle then return end
  if editor.beginWindow(wndName, wndName) then
    vEditor.vehicle:queueLuaCommand([[
      local data = {}
      data.heading = vec3(obj:getDirectionVector())
      data.pos = vec3(obj:getPosition())
      data.vel = vec3(obj:getVelocity())
      data.rot = vec3(obj:getRotation())
      data.roll, data.pitch, data.yaw = obj:getRollPitchYaw()
      data.sensors = {}
      data.sensors.gx2 = sensors.gx2
      data.sensors.gy2 = sensors.gy2
      data.sensors.gz2 = sensors.gz2
      data.airflowSpeed = obj:getAirflowSpeed()
      data.groundSpeed = obj:getGroundSpeed()
      data.envTemperature = obj:getEnvTemperature()
      data.envPressure = obj:getEnvPressure()
      data.airDensity = obj:getAirDensity()
      data.damage = beamstate.damage
      obj:queueGameEngineLua("vEditor.generalData =" .. serialize(data))]])

    if vEditor.generalData then
      im.TextColored(im.ImVec4(0.0, 1.0, 0.0, 1.0),"Vehicle General Data")
      im.Columns(2, "Data")
      im.SetColumnWidth(0, 200)
      im.SetColumnWidth(1, 1000)
      local heading = vEditor.generalData.heading
      local pos = vEditor.generalData.pos
      local vel = vEditor.generalData.vel
      local rot = vEditor.generalData.rot
      local roll = vEditor.generalData.roll
      local pitch = vEditor.generalData.pitch
      local yaw = vEditor.generalData.yaw
      local sensors = vEditor.generalData.sensors
      imguiUtils.cell("Position (m)", formatVec3(pos.x, pos.y, pos.z))
      im.Separator()
      imguiUtils.cell("Rotation", formatVec3(rot.x, rot.y, rot.z))
      im.Separator()
      imguiUtils.cell('Heading', formatVec3(heading.x, heading.y, heading.z))
      im.Separator()
      imguiUtils.cell('Roll/Pitch/Yaw', formatVec3(roll, pitch, yaw))
      im.Separator()
      imguiUtils.cell("Velocity (m/s)", formatVec3(vel.x, vel.y, vel.z))
      im.Separator()
      imguiUtils.cell("Accel (m/s^2)", formatVec3(sensors.gx2, sensors.gy2, sensors.gz2))
      im.Separator()
      imguiUtils.cell("Speed (m/s)", string.format("%.4f", vel:length()))
      im.Separator()
      imguiUtils.cell('Airspeed (m/s)', string.format("%.4f", vEditor.generalData.airflowSpeed))
      im.Separator()
      imguiUtils.cell('Groundspeed (m/s)', string.format("%.4f", vEditor.generalData.groundSpeed))
      im.Separator()
      imguiUtils.cell('Air Temp (C)', string.format("%.4f", vEditor.generalData.envTemperature - 273.15))
      im.Separator()
      imguiUtils.cell('Air Pressure (kPa)', string.format("%.4f", vEditor.generalData.envPressure * 0.001))
      im.Separator()
      imguiUtils.cell('Air Density (kg/m^3)', string.format("%.4f", vEditor.generalData.airDensity))
      im.Separator()
      imguiUtils.cell("Vehicle Damage ($)" ,string.format("%.2f", vEditor.generalData.damage))
      im.Columns(1)
      im.Separator()
    else
      im.Text("No vehicle data")
    end
  end
  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(700,400))
end

M.open = open

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M