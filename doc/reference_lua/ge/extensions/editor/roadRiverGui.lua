-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_roadRiverGui'
local im = ui_imgui

local createButtonPressed = false

local nodeSizeFactor = 0.012

local highlightColors = {
  hover = ColorF(0,0,1,1),
  lightHover = ColorF(0.6,0.6,1,1),

  hoverSelectNotAllowed = ColorF(1,0,0,1),
  lightHoverSelectNotAllowed = ColorF(1,0.6,0.6,1),

  selected = ColorF(1,1,1,1),
  darkSelected = ColorF(0.6,0.6,0.6,1),

  cursor = ColorF(0.5,0.5,0.5,1),
  createModeCursor = ColorF(0,1,0,1),

  selectedNode = ColorF(1,1,1,1),
  hoveredNode = ColorF(1,1,0,1),
  node = ColorF(1,0,0,1),
  nodeTransparent = ColorF(1,1,1,0.5)
}

local function editModeToolbar()
  local class = M.isRoad and "Road" or "River"
  local buttonColor = M.createMode and im.GetStyleColorVec4(im.Col_ButtonActive)
  if editor.uiIconImageButton(editor.icons.add_box, nil, nil, nil, buttonColor) then
    createButtonPressed = not createButtonPressed
  end
  -- this is for the tooltip of the toolbar button
  if im.IsItemHovered() then im.BeginTooltip() im.Text("Add " .. class .. "/Nodes") im.EndTooltip() end
  im.SameLine()
  M.createMode = createButtonPressed or editor.keyModifiers.alt
end

M.highlightColors = highlightColors
M.nodeSizeFactor = nodeSizeFactor
M.editModeToolbar = editModeToolbar

return M