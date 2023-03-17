-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui
local toolWindowName = "Vehicle Bridge Test"
local vehId = 0
local key = "ignition"
local result = {}

local function onEditorGui()
  if editor.beginWindow(toolWindowName,toolWindowName, im.WindowFlags_MenuBar) then
    local idInput = im.IntPtr(vehId)
    if im.InputInt("Vehicle Id", idInput) then
      vehId = idInput[0]
    end
    if im.BeginCombo("Select Vehicle...", vehId.."") then
      for i, vname in ipairs(scenetree.findClassObjects('BeamNGVehicle')) do
        if im.Selectable1(vname.."##"..i) then
          vehId = scenetree.findObject(vname):getID()
        end
      end
      im.EndCombo()
    end

    local keyInput = im.ArrayChar(128, key)
    if im.InputText("Key", keyInput) then
      key = ffi.string(keyInput)
    end

    if im.Button("Get Value!") then
      core_vehicleBridge.requestValue(scenetree.findObjectById(vehId),function(...) editor_vehicleBridgeTest.callback(...) end, key)
      result = "Waiting for Reply..."
    end
    im.Text(dumps(result))
    editor.endWindow()
  end
end

local function onWindowMenuItem() editor.showWindow(toolWindowName) end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(400,600))
  editor.addWindowMenuItem(toolWindowName, onWindowMenuItem, {groupMenuName = 'Experimental'})
  extensions.load("core_vehicleBridge")
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui

M.callback = function(...) result = {...} end

return M