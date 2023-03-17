-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"editor_veMain"}

M.menuEntry = "Debug/Aero Debug" -- what the menu item will be

local im = extensions.ui_imgui
local imguiUtils = require('ui/imguiUtils')
local wndName = "Vehicle Aero Debug"

local init = false

local wheelNameStringArray = nil

-- FL, FR, RL, RR
local wheelNamePtrs = {im.IntPtr(-1), im.IntPtr(-1), im.IntPtr(-1), im.IntPtr(-1)}

local function formatVec3(x, y, z)
  local formatStringX = (sign(x) ~= -1 and " " or "") .. "%.2f"
  local formatStringY = (sign(y) ~= -1 and " " or "") .. "%.2f"
  local formatStringZ = (sign(z) ~= -1 and " " or "") .. "%.2f"
  return string.format(formatStringX .. ", " .. formatStringY .. ", " .. formatStringZ, x, y, z)
end

local function setWheels()
  local wheelNameFL = vEditor.aeroData.wheelNameStrings[wheelNamePtrs[1][0]+1]
  local wheelNameFR = vEditor.aeroData.wheelNameStrings[wheelNamePtrs[2][0]+1]
  local wheelNameRL = vEditor.aeroData.wheelNameStrings[wheelNamePtrs[3][0]+1]
  local wheelNameRR = vEditor.aeroData.wheelNameStrings[wheelNamePtrs[4][0]+1]

  if wheelNameFL and wheelNameFR and wheelNameRL and wheelNameRR then
    vEditor.vehicle:queueLuaCommand('aeroDebug.setWheelNames("' .. wheelNameFL .. '","' .. wheelNameFR .. '","' .. wheelNameRL .. '","' .. wheelNameRR .. '")')
  end
end

local function tryAutoFillWheelNames()
  -- Try automatically filling wheel names
  local wheelNames = {["FL"] = 1, ["FR"] = 2, ["RL"] = 3, ["RR"] = 4}

  local success = true

  for k,v in pairs(vEditor.aeroData.wheelNameStrings) do
    local key = wheelNames[v]
    if key then
      wheelNamePtrs[key][0] = k - 1
    else
      success = false
      break
    end
  end

  if success then
    setWheels()
  end
end

local function onEditorGui(dt)
  if not vEditor or not vEditor.vehicle then return end

  -- window
  local wind = vec3(0,0,0)
  if editor.beginWindow(wndName, wndName) then

    if not vEditor.aeroData or (vEditor.aeroData and not (vEditor.aeroData.wheelNameStrings and vEditor.aeroData.totalAeroForce)) then
      vEditor.vehicle:queueLuaCommand('extensions.aeroDebug.enable()')
    end

    vEditor.vehicle:queueLuaCommand('obj:queueGameEngineLua("vEditor.aeroData =" .. serialize(extensions.aeroDebug.getAeroData()))')

    -- Check if aerodata exists and if aero data is meant for current vehicle
    if vEditor.aeroData and vEditor.vehicle:getID() == vEditor.aeroData.vehID and vEditor.aeroData.wheelNameStrings and vEditor.aeroData.totalAeroForce then
      if not init then
        wheelNameStringArray = im.ArrayCharPtrByTbl(vEditor.aeroData.wheelNameStrings)

        tryAutoFillWheelNames()

        init = true
      end

      im.TextColored(im.ImVec4(0.0, 1.0, 0.0, 1.0),"Vehicle Aero Forces")
      im.Columns(2, "Data")
      im.SetColumnWidth(0, 200)
      im.SetColumnWidth(1, 1000)
      local totalAeroForce = vEditor.aeroData.totalAeroForce
      local totalAeroForceVeh = vEditor.aeroData.totalAeroForceVehicle
      local totalAeroTorque = vEditor.aeroData.totalAeroTorque
      local totalAeroTorqueVeh = vEditor.aeroData.totalAeroTorqueVehicle
      im.Separator()
      imguiUtils.cell("Total Aero Force(N) (world)", formatVec3(totalAeroForce.x, totalAeroForce.y, totalAeroForce.z))
      im.Separator()
      imguiUtils.cell("Total Aero Force (N) (vehicle)", formatVec3(totalAeroForceVeh.x, totalAeroForceVeh.y, totalAeroForceVeh.z))
      im.Separator()
      imguiUtils.cell("Total Aero Torque (N) (world)", formatVec3(totalAeroTorque.x, totalAeroTorque.y, totalAeroTorque.z))
      im.Separator()
      imguiUtils.cell("Total Aero Torque (N) (vehicle)", formatVec3(totalAeroTorqueVeh.x, totalAeroTorqueVeh.y, totalAeroTorqueVeh.z))
      im.Separator()
      im.Columns(1, "Data")
      im.PushItemWidth(100)
      im.TextColored(im.ImVec4(0.0, 1.0, 0.0, 1.0),"Axle Configuration")

      im.Combo1("FL Wheel Name", wheelNamePtrs[1], wheelNameStringArray)
      im.SameLine()
      im.Combo1("FR Wheel Name", wheelNamePtrs[2], wheelNameStringArray)
      im.Combo1("RL Wheel Name", wheelNamePtrs[3], wheelNameStringArray)
      im.SameLine()
      im.Combo1("RR Wheel Name", wheelNamePtrs[4], wheelNameStringArray)

      if im.Button("Set Wheels", im.ImVec2(150, 25)) then
        setWheels()
      end

      im.TextColored(im.ImVec4(0.0, 1.0, 0.0, 1.0),"Axle Aero Forces")
      im.Columns(2, "Data")
      im.SetColumnWidth(0, 200)
      im.SetColumnWidth(1, 1000)
      local rearDownForce = vEditor.aeroData.rearDownForce
      local frontDownForce = vEditor.aeroData.frontDownForce
      local percentFront = vEditor.aeroData.percentFront
      local percentRear = vEditor.aeroData.percentRear
      im.Separator()
      imguiUtils.cell("Front Axle Downforce (N)", string.format("%.2f", frontDownForce))
      im.Separator()
      imguiUtils.cell("Rear Axle Downforce (N)", string.format("%.2f", rearDownForce))
      im.Separator()
      imguiUtils.cell('Front Axle Downforce (%%)', string.format("%.2f", percentFront))
      im.Separator()
      imguiUtils.cell('Rear Axle Downforce (%%)', string.format("%.2f", percentRear))
      im.Separator()

      --if im.SliderFloat("wind", wind, -100, 100) then
      --  vEditor.vehicle:queueLuaCommand('obj:setWind("' .. wind .. '", "' .. wind.y .. '", "' .. wind.z .. '" )')
      --end
    end
  end
  editor.endWindow()
end

-- helper function to open the window
local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,500))
end

-- Disable aeroDebug on old vehicle
local function onVehicleSwitched(oldVehicle, newVehicle, player)
  local oldVeh = be:getObjectByID(oldVehicle)
  if oldVeh then
    oldVeh:queueLuaCommand('extensions.aeroDebug.disable()')
  end

  vEditor.aeroData = nil
  init = false
end

local function onEditorDeactivated()
  if vEditor and vEditor.vehicle then
    vEditor.vehicle:queueLuaCommand('extensions.aeroDebug.disable()')
  end
end

local function onEditorActivated()
end

-- public interface
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onVehicleSwitched = onVehicleSwitched
M.onEditorDeactivated = onEditorDeactivated
M.onEditorActivated = onEditorActivated

M.open = open

return M
