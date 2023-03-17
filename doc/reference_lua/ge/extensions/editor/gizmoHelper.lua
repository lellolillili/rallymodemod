-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local gizmoDrawn = false
local gizmoDrawnLastFrame = false

local function onEditorGui()
  if not gizmoDrawn and gizmoDrawnLastFrame then
    worldEditorCppApi.setAxisGizmoSelectedElement(-1)
  end
  gizmoDrawnLastFrame = gizmoDrawn
  gizmoDrawn = false
end

local function gizmoDrawCalled()
  gizmoDrawn = true
end

local function isGizmoVisible()
  return gizmoDrawnLastFrame == true
end

M.onEditorGui = onEditorGui
M.gizmoDrawCalled = gizmoDrawCalled
M.isGizmoVisible = isGizmoVisible

return M