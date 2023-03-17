-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local im = ui_imgui

local wndName = "Beam Visualization Modes"

M.menuEntry = "JBeam Debug/Beam Visualization"
M.dependencies = {"editor_veMain"}

local state = nil

local beamVisMode = im.IntPtr(0)
local beamVisModes = nil

local dragIntRangeValMin = im.IntPtr(0)
local dragIntRangeValMax = im.IntPtr(10)

local dragFloatRangeValMin = im.FloatPtr(0.0)
local dragFloatRangeValMax = im.FloatPtr(10.0)

local showInfinity = im.BoolPtr(false)

local tempArr = {}

local function onBDebugUpdate(newState)
  state = newState

  for _,v in pairs(state.vehicle.beamVisModes) do
    table.insert(tempArr, v.name)
  end

  beamVisModes = im.ArrayCharPtrByTbl(tempArr)
  table.clear(tempArr)
end

local function requestBDebugState()
  vEditor.vehicle:queueLuaCommand("bdebug.requestState()")
end

local function setBDebugState()
  vEditor.vehicle:queueLuaCommand("bdebug.setState(" .. serialize(state) .. ")")
end

-- Get latest state from bdebug.lua, get user input, and post them to bdebug.lua
-- Do not use past local results or result of user input for further processing right away (only use latest state from bdebug.lua to do so)
local function onEditorGui()
  if not vEditor.vehicle then return end

  if editor.beginWindow(wndName, wndName) then
    local dirty = false -- flag to indicate if any user input has been made

    if state then
      local currentModeID = state.vehicle.beamVisMode
      local currentModeData = state.vehicle.beamVisModes[currentModeID]

      beamVisMode[0] = currentModeID - 1

      im.TextColored(im.ImVec4(0.3, 0.9, 0.2, 1.0),"Beams Properties ")
      im.SameLine()

      if im.Combo1("", beamVisMode, beamVisModes) then
        -- Change beam mode

        state.vehicle.beamVisMode = beamVisMode[0] + 1
        dirty = true
      end

      if currentModeID ~= 1 and currentModeData.usesRange then
        local rangeMinCap = currentModeData.rangeMinCap or 0
        local rangeMaxCap = currentModeData.rangeMaxCap or 0

        local rangeSpeed = (rangeMaxCap - rangeMinCap) / 750

        if currentModeData.usesFloat then
          dragFloatRangeValMin[0] = currentModeData.rangeMin or dragFloatRangeValMin[0]
          dragFloatRangeValMax[0] = currentModeData.rangeMax or dragFloatRangeValMax[0]

          if im.DragFloatRange2("Range ##", dragFloatRangeValMin, dragFloatRangeValMax, rangeSpeed, rangeMinCap, rangeMaxCap, "Min: %.3f ", "Max: %.3f ") then
            -- Set new range values in bdebug.lua

            currentModeData.rangeMin = dragFloatRangeValMin[0]
            currentModeData.rangeMax = dragFloatRangeValMax[0]
            dirty = true
          end
        else
          dragIntRangeValMin[0] = currentModeData.rangeMin or dragIntRangeValMin[0]
          dragIntRangeValMax[0] = currentModeData.rangeMax or dragIntRangeValMax[0]

          if im.DragIntRange2("Range ##", dragIntRangeValMin, dragIntRangeValMax, rangeSpeed, rangeMinCap, rangeMaxCap, "Min: %d ", "Max: %d ") then
            -- Set new range values in bdebug.lua

            currentModeData.rangeMin = dragIntRangeValMin[0]
            currentModeData.rangeMax = dragIntRangeValMax[0]
            dirty = true
          end
        end

        showInfinity[0] = currentModeData.showInfinity or false

        if im.Checkbox("Include Infinity Values (FLT_MAX)", showInfinity) then
          currentModeData.showInfinity = showInfinity[0]
          dirty = true
        end
      end
    else
      requestBDebugState()
    end

    if dirty then
      setBDebugState()
    end
  end

  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorToolWindowShow(window)
  if window == wndName and vEditor.vehicle then
    requestBDebugState()
  end
end

local function onEditorToolWindowHide(closedWindow)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,200))
end


M.onBDebugUpdate = onBDebugUpdate
M.onEditorGui = onEditorGui
M.open = open
M.onEditorToolWindowShow = onEditorToolWindowShow
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onEditorInitialized = onEditorInitialized

return M

