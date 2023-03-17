-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local ffi = require('ffi')

local coconut = nil

local M = {}
local logTag = 'editor_camera_transform'

local toolWindowName = 'cameraTransform'

local im = ui_imgui

local camTransfrom = im.ArrayChar(512)

local function onEditorGui()

  if editor.beginWindow(toolWindowName, "Camera Transform") then
    if im.Button("Get Camera Transform") then
      ffi.copy(camTransfrom, commands.getCameraTransformJson())
    end
    im.SameLine()
    if im.Button("GoTo") then
      commands.setFreeCameraTransformJson(ffi.string(camTransfrom))
    end
    im.TextUnformatted("Camera Transform")

    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if im.InputText("Camera Transform", camTransfrom) then
    end
    im.PopItemWidth()
    if im.Button("Copy") then
      im.SetClipboardText(ffi.string(camTransfrom))
    end

  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorActivated()

end

local function onEditorDeactivated()

end

local function onEditorInitialized()
  editor.addWindowMenuItem("Camera Transform", onWindowMenuItem)
  editor.registerWindow(toolWindowName, im.ImVec2(600, 200))
end

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorActivated = onEditorActivated
M.onEditorDeactivated = onEditorDeactivated

return M