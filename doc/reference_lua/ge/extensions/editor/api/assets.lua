-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor
local dragDropAsset = {}

--- Function that gets invoked when a payload has been successfully dropped on a drag and drop target.
-- @param dragDropId the drag and drop id. An arbitrary id that is created by the user. Drag and drop targets only accept payloads from drag and drop sources with the same dragDropId.
-- @param data payload of the drag and drop action. The actual data that gets transferred from a drag and drop source to a drag and drop target.
-- @param callback callback function.
local function dragDropSource(dragDropId, data, callback)
  if ui_imgui.BeginDragDropSource(ui_imgui.DragDropFlags_SourceAllowNullID) then
    if not dragDropAsset.data then dragDropAsset.data = ffi.new('char[2048]', data) end
    if callback and not dragDropAsset.callback then dragDropAsset.callback = callback end
    ui_imgui.SetDragDropPayload(dragDropId, dragDropAsset.data, ffi.sizeof'char[2048]', ui_imgui.Cond_Once);
    ui_imgui.Text(data)
    ui_imgui.EndDragDropSource()
  end
end

--- Drag and drop targets only accept payloads from drag and drop sources with the same dragDropId.
-- @param dragDropId the drag and drop id. An arbitrary id that is created by the user.
local function dragDropTarget(dragDropId)
  if ui_imgui.BeginDragDropTarget() then
    local payload = ui_imgui.AcceptDragDropPayload(dragDropId)
    if payload~=nil then
      assert(payload.DataSize == ffi.sizeof"char[2048]")
      local str = ffi.string(ffi.cast("char*",payload.Data))
      if dragDropAsset.callback then dragDropAsset.callback(str) end
      dragDropAsset = {}
    end
    ui_imgui.EndDragDropTarget()
  end
end

--- Initialize the module.
local function initialize(editorInstance)
  editor = editorInstance
  editor.dragDropAsset = dragDropAsset
  editor.dragDropSource = dragDropSource
  editor.dragDropTarget = dragDropTarget
end

local M = {}
M.initialize = initialize

return M