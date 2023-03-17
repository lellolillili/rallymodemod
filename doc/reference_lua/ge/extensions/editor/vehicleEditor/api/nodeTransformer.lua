-- This Source Code Form is subject to the terms of the bCDDL, var. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local lastPickedNodesPos = {}
local deltaPos = vec3(0,0,0)

local axisArrows = {
  startPos = vec3()
}

local dragging = false

local function setNodesPositionOffset(deltaPos)
  for _,node in ipairs(vEditor.selectedNodes) do
    node.pos = deltaPos + lastPickedNodesPos[node.name]
  end
end

local function gizmoBeginDrag()
  dragging = true

  for _,node in pairs(vEditor.selectedNodes) do
    lastPickedNodesPos[node.name] = node.pos
  end

  axisArrows.startPos = vec3(editor.getAxisGizmoTransform():inverse():getColumn(3))
end

local function gizmoDragging()
  dragging = true

  -- Delta pos in local coordinates
  local pos = vec3(editor.getAxisGizmoTransform():inverse():getColumn(3))
  deltaPos:set(-(pos - axisArrows.startPos))

  setNodesPositionOffset(deltaPos)
end

local function gizmoEndDrag()
  dragging = false
  deltaPos:set(0,0,0)
end


local function transformNodes()
  local axesArrowPos = vec3(0,0,0)

  -- Center transforming axes arrows on node selection
  for _, node in pairs(vEditor.selectedNodes) do
    axesArrowPos:setAdd(node.pos)
  end

  axesArrowPos:setScaled(1 / #vEditor.selectedNodes)

  if not dragging then
    worldEditorCppApi.setAxisGizmoRenderPlane(false)
    worldEditorCppApi.setAxisGizmoRenderPlaneHashes(false)
    worldEditorCppApi.setAxisGizmoRenderMoveGrid(false)

    editor.setAxisGizmoAlignment(editor.AxisGizmoAlignment_Local)
    local transform = QuatF(0, 0, 0, 1):getMatrix()
    transform:setPosition(axesArrowPos)
    editor.setAxisGizmoTransform(transform)
  end

  dragging = false

  editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoDragging)
  editor.drawAxisGizmo()

  return dragging
end

M.transformNodes = transformNodes

return M