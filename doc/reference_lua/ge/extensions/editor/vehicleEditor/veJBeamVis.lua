-- This Source Code Form is subject to the terms of the bCDDL, var. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
--M.menuEntry = "JBeam Debug/JBeam Visualizer"
local im = extensions.ui_imgui
local ffi = require("ffi")
local dbgdraw = require('utils/debugDraw')
local imguiUtils = require('ui/imguiUtils')
local wndName = "JBeam Visualizer"

local nodesEnabled = im.BoolPtr(false)
local nodesIDsEnabled = im.BoolPtr(false)
local beamsEnabled = im.BoolPtr(false)
local trisEnabled = im.BoolPtr(false)

local function renderJBeams()
  if not core_vehicle_manager.getPlayerVehicleData() then return end

  local vdata = core_vehicle_manager.getPlayerVehicleData().vdata

  -- Draw Nodes
  if nodesEnabled[0] then
    for _, node in pairs(vdata.nodes) do
      --local pos = v.pos
      local pos = vEditor.vehicleNodesPos[node.cid]
      dbgdraw.Sphere(pos.x, pos.y, pos.z, 0.035, 0.75,1,0,1)
      if nodesIDsEnabled[0] then
        local name = node.name or node.cid

        debugDrawer:drawText(vec3(pos), name, ColorF(0, 0, 0, 1))
      end
    end
  end

  -- Draw Beams
  if beamsEnabled[0] then
    for _, beam in pairs(vdata.beams) do
      local pos1 = vEditor.vehicleNodesPos[beam.id1]
      local pos2 = vEditor.vehicleNodesPos[beam.id2]

      dbgdraw.Cylinder(pos1.x, pos1.y, pos1.z, pos2.x, pos2.y, pos2.z, 0.005, 0, 1, 0, 1)
    end
  end

  -- Draw Triangles
  if trisEnabled[0] then
    for _, tri in pairs(vdata.triangles) do
      local pos1 = vEditor.vehicleNodesPos[tri.id1]
      local pos2 = vEditor.vehicleNodesPos[tri.id2]
      local pos3 = vEditor.vehicleNodesPos[tri.id3]

      debugDrawer:setSolidTriCulling(false)
      debugDrawer:drawTriSolid(vec3(pos1.x, pos1.y, pos1.z), vec3(pos2.x, pos2.y, pos2.z), vec3(pos3.x, pos3.y, pos3.z), ColorI(0, 255, 255, 100))
    end
  end
end

local function onEditorGui()
  if not vEditor.vehicle then return end
  if editor.beginWindow(wndName, wndName) then
    local windowSize = im.GetWindowSize()
    local padding = im.GetStyle().WindowPadding.x * 2
    local height = (windowSize.y - 140) / 3
    local width = windowSize.x - padding

    im.Checkbox("Nodes##jbeamVisCheckbox", nodesEnabled)
    im.SameLine()
    im.Checkbox("Nodes IDs##jbeamVisCheckbox", nodesIDsEnabled)

    im.Checkbox("Beams##jbeamVisCheckbox", beamsEnabled)
    im.Checkbox("Triangles##jbeamVisCheckbox", trisEnabled)

    renderJBeams()
  end
  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(200,200))
end

M.open = open

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M