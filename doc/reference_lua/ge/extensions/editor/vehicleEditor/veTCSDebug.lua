-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.menuEntry = "Debug/TCS" -- what the menu item will be

local im = extensions.ui_imgui

local throttleFactors = {}
local allWheelSlips = {}
local brakeFactors = {}
local wheelSlips = {}
local slipThresholds = {}
local dataPointCount = 600
local colors1 = {{52, 177, 255, 255}, {167, 255, 0, 255}, {255, 0, 120, 255}, {255, 119, 0, 255}}
local colors2 = {{255, 255, 0, 255}, {52, 177, 255, 255}, {167, 255, 0, 255}, {255, 0, 120, 255}, {255, 119, 0, 255}}
local colors3 = {{52, 177, 255, 255}, {167, 255, 0, 255}, {255, 0, 120, 255}, {255, 119, 0, 255}}
local colors4 = {{52, 177, 205, 255}, {167, 205, 0, 255}, {205, 0, 120, 255}, {205, 119, 0, 255}}
local didInit = false
local defaultWindowSize = im.ImVec2(600, 400)

local function getTextColor(colorTable)
  return im.ImVec4(colorTable[1] / 255, colorTable[2] / 255, colorTable[3] / 255, colorTable[4] / 255)
end

local function getGraphColor(colorTable)
  return im.ImColorByRGB(colorTable[1], colorTable[2], colorTable[3], colorTable[4])
end

local function onEditorGui(dt)
if not vEditor.vehicle then return end
  if editor.beginWindow("TCS Debug", "TCS Debug") then
    vEditor.vehicle:queueLuaCommand([[
      local escControllers = controller.getControllersByType("esc")
      local tcsData = (#escControllers >= 1) and escControllers[1].debugData.tcs or nil
      obj:queueGameEngineLua("vEditor.tcsData = " .. serialize(tcsData))]])
    if vEditor.tcsData then
      if not didInit then
        for k, _ in pairs(vEditor.tcsData.wheelBrakeFactors) do
          brakeFactors[k] = {}
          for _ = 1, dataPointCount do
            table.insert(brakeFactors[k], 0)
          end
        end

        for k, _ in pairs(vEditor.tcsData.wheelSlips) do
          wheelSlips[k] = {}
          for _ = 1, dataPointCount do
            table.insert(wheelSlips[k], 0)
          end
        end

        for k, _ in pairs(vEditor.tcsData.throttleFactors) do
          throttleFactors[k] = {}
          for _ = 1, dataPointCount do
            table.insert(throttleFactors[k], 0)
          end
        end

        for k, _ in pairs(vEditor.tcsData.allWheelSlips) do
          allWheelSlips[k] = {}
          for _ = 1, dataPointCount do
            table.insert(allWheelSlips[k], 0)
          end
        end

        didInit = true
      end

      table.remove(slipThresholds, 1)
      for _, v in pairs(brakeFactors) do
        table.remove(v, 1)
      end
      for _, v in pairs(wheelSlips) do
        table.remove(v, 1)
      end

      table.insert(slipThresholds, vEditor.tcsData.slipThreshold)
      local graph1Names = {}
      local graph1Tables = {}
      local graphColors1 = {}
      local textColors1 = {}
      local count = 1
      for k, v in pairs(vEditor.tcsData.wheelBrakeFactors) do
        table.insert(brakeFactors[k], v)
        table.insert(graph1Tables, brakeFactors[k])
        table.insert(graph1Names, k)
        local color = colors1[count]
        table.insert(graphColors1, getGraphColor(color))
        textColors1[k] = getTextColor(color)
        count = count + 1
      end

      count = 1
      for k, _ in pairs(brakeFactors) do
        if count > 1 then
          im.SameLine()
        end
        im.TextColored(textColors1[k], k)
        count = count + 1
      end

      local windowSize = im.GetWindowSize()
      local padding = im.GetStyle().WindowPadding.x * 2
      local height = (windowSize.y - 140) / 3
      local width = windowSize.x - padding

      im.PlotMultiLines("", #graph1Tables, graph1Names, graphColors1, graph1Tables, dataPointCount, "", -0.25, 1, im.ImVec2(width, height))

      local graph2Tables = {slipThresholds}
      local graph2Names = {"Slip Threshold"}
      local graphColors2 = {getGraphColor(colors2[1])}
      local textColors2 = {slipThreshold = getTextColor(colors2[1])}
      count = 2
      for k, v in pairs(vEditor.tcsData.wheelSlips) do
        table.insert(wheelSlips[k], v)
        table.insert(graph2Tables, wheelSlips[k])
        table.insert(graph2Names, k)
        local color = colors2[count]
        table.insert(graphColors2, getGraphColor(color))
        textColors2[k] = getTextColor(color)
        count = count + 1
      end

      im.TextColored(textColors2.slipThreshold, graph2Names[1])
      im.SameLine()

      for k, _ in pairs(wheelSlips) do
        im.SameLine()
        im.TextColored(textColors2[k], k)
      end

      im.PlotMultiLines("", #graph2Tables, graph2Names, graphColors2, graph2Tables, dataPointCount, "", 0, 0.5, im.ImVec2(width, height))

      for _, v in pairs(throttleFactors) do
        table.remove(v, 1)
      end
      for _, v in pairs(allWheelSlips) do
        table.remove(v, 1)
      end

      local graph3Tables = {}
      local graph3Names = {}
      local graphColors3 = {}
      local textColors3 = {}
      count = 1
      for k, v in pairs(vEditor.tcsData.throttleFactors) do
        table.insert(throttleFactors[k], v)
        table.insert(graph3Tables, throttleFactors[k])
        table.insert(graph3Names, k)
        local color = colors3[count]
        table.insert(graphColors3, getGraphColor(color))
        textColors3[k] = getTextColor(color)
        count = count + 1
      end

      count = 1
      for k, _ in pairs(throttleFactors) do
        if count > 1 then
          im.SameLine()
        end
        im.TextColored(textColors3[k], k)
        count = count + 1
      end

      count = 1
      for k, v in pairs(vEditor.tcsData.allWheelSlips) do
        table.insert(allWheelSlips[k], v)
        table.insert(graph3Tables, allWheelSlips[k])
        table.insert(graph3Names, k)
        local color = colors4[count]
        table.insert(graphColors3, getGraphColor(color))
        textColors3[k] = getTextColor(color)
        count = count + 1
      end

      count = 1
      for k, _ in pairs(allWheelSlips) do
        if count > 1 then
          im.SameLine()
        end
        im.TextColored(textColors3[k], k)
        count = count + 1
      end

      im.PlotMultiLines("", #graph3Tables, graph3Names, graphColors3, graph3Tables, dataPointCount, "", 0, 1, im.ImVec2(width, height))
    end
  end

  editor.endWindow()
end

-- helper function to open the window
local function open()
  editor.showWindow("TCS Debug")
end

-- called when the extension is loaded (might be invisible still)
local function onExtensionLoaded()
  for _ = 1, dataPointCount do
    table.insert(slipThresholds, 0)
  end
end

-- called when the extension is unloaded
local function onExtensionUnloaded()
end

local function onEditorInitialized()
  editor.registerWindow("TCS Debug", defaultWindowSize)
end


-- public interface
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onEditorInitialized = onEditorInitialized

M.onEditorGui = onEditorGui

M.open = open

return M
