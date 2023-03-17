-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local powerTrainUtils = require("editor/vehicleEditor/api/powerTrainUtils")
M.dependencies = {"editor_veMain"}

M.menuEntry = "Debug/Powertrain Inspector"
local wndName = "Powertrain"
local im = ui_imgui
local initialWindowSize = im.ImVec2(800, 800)
local deviceString
local devicePtr = im.IntPtr(0)
local deviceNames = {}

local function onEditorGui(dt)
  if editor.beginWindow(wndName, wndName) and vEditor.vehicle then
    vEditor.vehicle:queueLuaCommand([[
      obj:queueGameEngineLua("vEditor.powertrainDevices =" .. powertrain.serializeDevicesInfo())]])
    if vEditor.powertrainDevices and not tableIsEmpty(vEditor.powertrainDevices) then
      if not deviceString or vEditor.resetDeviceString then
        vEditor.resetDeviceString = false
        deviceString = ''
        deviceNames = {}

        local deviceNamesUnsorted = {}
        for _,device in ipairs(vEditor.powertrainDevices) do
          if device.name then
            deviceNamesUnsorted[device.name] = 0
          end
        end

        local keys = tableKeysSorted(deviceNamesUnsorted)
        for _,name in ipairs(keys) do
          table.insert(deviceNames, name)
          deviceString = deviceString .. name .. "\0"
        end
      end

      im.Combo2("Device Name", devicePtr, deviceString)
      for lpid = 0, #vEditor.vdata.powertrain - 1 do
        if deviceNames[devicePtr[0]+1] == vEditor.vdata.powertrain[lpid].name then
          powerTrainUtils.showJbeamData(lpid)
          im.Separator()
        end
      end
      for _, device in ipairs(vEditor.powertrainDevices) do
        if device.name == deviceNames[devicePtr[0]+1] then
          if im.TreeNodeEx1("Live Data", im.TreeNodeFlags_DefaultOpen) then
            powerTrainUtils.displayLivedata(device)
            powerTrainUtils.displayLivedataByType(device.type, device)
            im.TreePop()
          end
        end
      end
    end
  end
  editor.endWindow()
end

local function onSerialize()
  return {
    devicePtr = devicePtr[0]
  }
end

local function onDeserialize(data)
  devicePtr[0] = data.devicePtr
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, initialWindowSize)
end

local function requestDeviceStringUpdate()
  if vEditor.vehicle then
    vEditor.powertrainDevices = nil
    vEditor.vehicle:queueLuaCommand('obj:queueGameEngineLua("vEditor.resetDeviceString = true")')
  end
end

local function onVehicleSwitched(oldVehicle, newVehicle, player)
  if editor and editor.isEditorActive and editor.isEditorActive() then
    requestDeviceStringUpdate()
  end
end

local function onEditorActivated()
  requestDeviceStringUpdate()
end

M.onEditorGui = onEditorGui
M.open = open
M.onSerialize = onSerialize
M.onDeserialize = onDeserialize
M.onEditorInitialized = onEditorInitialized
M.onVehicleSwitched = onVehicleSwitched
M.onEditorActivated = onEditorActivated

return M