-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"ui_imgui"}

local showUI = nil
local tempFloat = nil
local data = {1, 1, 1, 1}
local needUpdate = false

local function dataToString(data)
  return string.format("%s %s %s %s", data[1], data[2], data[3], data[4])
end

local function stringToData(colorString)
  if not colorString then return end
  local result = { }
  for i,v in ipairs(stringToTable(colorString, '%s')) do
    result[i] = tonumber(v)
  end
  return result
end

local function sliderUI(id, array, index)
  tempFloat[0] = data[index]
  if(ui_imgui.SliderFloat(id..'##'..tostring(array), tempFloat, 0, 1)) then
    data[index] = tempFloat[0]
    needUpdate = true
  end
end

local function updateData(veh, index)
  if(needUpdate) then
    needUpdate = false
    veh:setField('metallicPaintData', index, dataToString(data))
  end
end

local function onUpdate()
  if not showUI[0] then return end

  local imgui = ui_imgui
  local veh = be:getPlayerVehicle(0)
  if not veh then return end

  imgui.Begin('Metallic paint', showUI, imgui.WindowFlags_AlwaysAutoResize)
    if imgui.CollapsingHeader1("Paint 0", imgui.TreeNodeFlags_DefaultOpen) then
      data = stringToData(veh:getField('metallicPaintData', 0))
      sliderUI('Metallic', 0, 2)
      sliderUI('Roughness', 0, 1)
      sliderUI('Coat', 0, 3)
      sliderUI('Coat roughness', 0, 4)
      updateData(veh, 0)
    end

    if imgui.CollapsingHeader1("Paint 1", imgui.TreeNodeFlags_DefaultOpen) then
      data = stringToData(veh:getField('metallicPaintData', 1))
      sliderUI('Metallic', 1, 2)
      sliderUI('Roughness', 1, 1)
      sliderUI('Coat', 1, 3)
      sliderUI('Coat roughness', 1, 4)
      updateData(veh, 1)
    end

    if imgui.CollapsingHeader1("Paint 2", imgui.TreeNodeFlags_DefaultOpen) then
      data = stringToData(veh:getField('metallicPaintData', 2))
      sliderUI('Metallic', 2, 2)
      sliderUI('Roughness', 2, 1)
      sliderUI('Coat', 2, 3)
      sliderUI('Coat roughness', 2, 4)
      updateData(veh, 2)
    end
  imgui.End()
end

local function openUI()
  showUI[0] = true
end

local function onExtensionLoaded()
  if showUI == nil then
    showUI = ui_imgui.BoolPtr(false)
  end
  if not tempFloat then
    tempFloat = ui_imgui.FloatPtr(0)
  end
end

local function changeData(change, index)
  local playerVehicle = be:getPlayerVehicle(0)
  data = stringToData(playerVehicle:getField('metallicPaintData', 0))
  data[index] = change
  playerVehicle:setField('metallicPaintData', 0, dataToString(data))
end

M.show = openUI
M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.changeData = changeData

return M