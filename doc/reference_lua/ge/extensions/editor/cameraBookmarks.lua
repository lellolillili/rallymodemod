-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_cameraBookmarks'
local ffi = require("ffi")
local imgui = ui_imgui
local toolWindowName = "cameraBookmarks"
local newBookmarkName = imgui.ArrayChar(1000)

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Camera Bookmarks") then
    imgui.Text("New bookmark name:")
    local addMark = imgui.InputText("##newBookmarkName", newBookmarkName, ffi.sizeof(newBookmarkName), imgui.InputTextFlags_EnterReturnsTrue)
    imgui.SameLine()

    if imgui.Button("Add") then addMark = true end

    if addMark then
      local val = ffi.string(newBookmarkName)
      ffi.copy(newBookmarkName, "")
      editor.addCameraBookmark(val)
    end

    imgui.TextUnformatted("Clipboard: ")
    imgui.SameLine()

    if imgui.Button("Copy Location") then editor.copyCameraBookmarkToClipboard(editor.getCamera()) end

    imgui.SameLine()

    if imgui.Button("Paste Location") then editor.pasteCameraBookmarkFromClipboard() end

    imgui.BeginChild1("cameraBookmarksChild", imgui.ImVec2(0, 0), true)
    local bookmarks = editor.getCameraBookmarks()

    if bookmarks then
      local deleteId = 0
      for i = 1, bookmarks:size() do
        local bookmark = bookmarks:at(i - 1)
        imgui.PushID4(i)
        if imgui.Button("Go To") then editor.jumpToCameraBookmark(bookmark:getID()) end
        imgui.SameLine()
        if imgui.Button("Copy") then editor.copyCameraBookmarkToClipboard(bookmark) end
        imgui.SameLine()
        if imgui.Button("Delete") then deleteId = bookmark:getID() end
        imgui.SameLine()
        imgui.TextUnformatted(bookmark:getInternalName())
        imgui.PopID()
      end
      if deleteId ~= 0 then editor.deleteCameraBookmark(deleteId) end
    end
    imgui.EndChild()
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onExtensionLoaded()
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, imgui.ImVec2(500,500))
  editor.addWindowMenuItem("Camera Bookmarks", onWindowMenuItem)
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onExtensionLoaded = onExtensionLoaded

return M