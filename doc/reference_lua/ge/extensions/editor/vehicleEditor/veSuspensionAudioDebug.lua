-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a tiny example imgui app to be integrated within the vehicle editor. Please copy and rename it before modifying it.

local M = {}
M.dependencies = {"editor_veMain"}
M.menuEntry = "Debug/Suspension Audio"

local im = extensions.ui_imgui
local imguiUtils = require("ui/imguiUtils")
local wndName = "Suspension Audio Debug"

local counter = 1

local filter = {"Front Left", "Front Right", "Rear Left", "Rear Right"}
local beamSounds = {}

-- main drawing function
local function onEditorGui()
  if not vEditor.vdata or not vEditor.vehicle then return end
  -- window
  if editor.beginWindow(wndName, wndName) then
    vEditor.vehicle:queueLuaCommand('obj:queueGameEngineLua("vEditor.beamSounds =" .. serialize(sounds.getBeamSounds()))')

    if vEditor.beamSounds then
      for bi, snd in ipairs(vEditor.beamSounds) do
        if not snd.beamPos then
          if vEditor.vdata.beams[snd.beam] then
            if vEditor.vdata.nodes[vEditor.vdata.beams[snd.beam].id1] then
              snd.beamPos = vEditor.vdata.nodes[vEditor.vdata.beams[snd.beam].id1].pos
              if snd.beamPos.y < 0 then
                snd.position = "Front "
              else
                snd.position = "Rear "
              end

              if snd.beamPos.x < 0 then
                snd.position = snd.position .. "Right"
              else
                snd.position = snd.position .. "Left"
              end
            end
          end
        end

        if not beamSounds[bi] then beamSounds[bi] = {} end
        if not beamSounds[bi].volumeTbl then
          beamSounds[bi].volumeTbl = {}
          for i = 1, 200 do
            beamSounds[bi].volumeTbl[i] = 0
          end
        else
          beamSounds[bi].volumeTbl[counter] = snd.volume
        end

        if not beamSounds[bi].pitchTbl then
          beamSounds[bi].pitchTbl = {}
          for i = 1, 200 do
            beamSounds[bi].pitchTbl[i] = 0
          end
        else
          beamSounds[bi].pitchTbl[counter] = snd.pitch
        end

        if not beamSounds[bi].impulseTbl then
          beamSounds[bi].impulseTbl = {}
          for i = 1, 200 do
            beamSounds[bi].impulseTbl[i] = 0
          end
        else
          beamSounds[bi].impulseTbl[counter] = snd.impulse
        end
      end


      im.Columns(2, "AudioTable")
      for i, v in pairs(filter) do
        for bi, val in ipairs(vEditor.beamSounds) do
          if v == val.position then
            im.Text("Position: ")
            im.SameLine()
            im.Text(tostring(val.position))
            if val.volume then
              im.Text("Stress Impulse")
              im.SameLine()
              imguiUtils.SampleFloatDisplay('impulse' ..i, val.impulse, 0.05, 3)
              local impulseArr = im.TableToArrayFloat(beamSounds[bi].impulseTbl)--not actually stress, things are named poorly in sounds.lua
              im.PlotLines1("", impulseArr, im.GetLengthArrayFloat(impulseArr), counter, "maxStress: " ..tostring(val.maxStress), 0, val.maxStress, im.ImVec2(400, 80))
              im.Text("Pitch")
              im.SameLine()
              imguiUtils.SampleFloatDisplay('pitch' ..i, val.pitch, 0.05, 3)
              local pitchArr = im.TableToArrayFloat(beamSounds[bi].pitchTbl)
              im.PlotLines1("", pitchArr, im.GetLengthArrayFloat(pitchArr), counter, "pitchFactor: " ..tostring(val.pitchFactor), 0, val.pitchFactor, im.ImVec2(400, 80))
              im.Text("Volume")
              im.SameLine()
              imguiUtils.SampleFloatDisplay('volume' ..i, val.volume, 0.05, 3)
              local volumeArr = im.TableToArrayFloat(beamSounds[bi].volumeTbl)
              im.PlotLines1("", volumeArr, im.GetLengthArrayFloat(volumeArr), counter, "volumeFactor: " ..tostring(val.volumeFactor), 0, 1, im.ImVec2(400, 80))
            end
            im.NextColumn()
          end
        end
      end
      im.Columns(1)

      counter = counter + 1
      if counter > 200 then
        counter = 1
      end
    end
  end
  editor.endWindow()
end

-- helper function to open the window
local function open()
  editor.showWindow(wndName)
end

-- called when the extension is loaded (might be invisible still)
local function onExtensionLoaded()
end

-- called when the extension is unloaded
local function onExtensionUnloaded()
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,200))
  editor.addWindowMenuItem(wndName, open, {groupMenuName = 'Audio'})
end

local function onVehicleSwitched(oldVehicle, newVehicle, player)
  beamSounds = {}
  counter = 1
end

-- public interface
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onVehicleSwitched = onVehicleSwitched

M.open = open

return M
