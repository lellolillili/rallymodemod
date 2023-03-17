-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {"editor_veMain"}

M.menuEntry = "Debug/Engine Audio" -- what the menu item will be

local im = extensions.ui_imgui
local wndName = "Engine Audio Debug"

local selectedEngineSound = im.IntPtr(0)

local mainGain = im.FloatPtr(0)
local onLoadGain = im.FloatPtr(0)
local offLoadGain = im.FloatPtr(0)

local lowShelfFreq = im.FloatPtr(0)
local lowShelfGain = im.FloatPtr(0)
local highShelfFreq = im.FloatPtr(0)
local highShelfGain = im.FloatPtr(0)

local eqLowGain = im.FloatPtr(0)
local eqLowFreq = im.FloatPtr(0)
local eqLowWidth = im.FloatPtr(0)

local eqHighGain = im.FloatPtr(0)
local eqHighFreq = im.FloatPtr(0)
local eqHighWidth = im.FloatPtr(0)

local eqFundamentalGain = im.FloatPtr(0)
local muffling = im.FloatPtr(0)
local fundamentalFreqCylCount = im.IntPtr(0)

local showExhaustDirection = im.BoolPtr(true)

local selectedEngineData

local fmodtable = {20.0, 40.0, 80.0, 160.0, 330.0, 660.0, 1300.0, 2700.0, 5400.0, 11000.0, 22000.0} --Hz values
local function hzToFMODHz(hzValue)
  local range = #fmodtable - 1
  hzValue = math.max(fmodtable[1], math.min(hzValue, fmodtable[#fmodtable])) --clamp hzValue to min/max possible values
  for i = range, 1, -1 do --iterate all fmod hz entries starting at the top
    if fmodtable[i] <= hzValue then --if we found an fmod hz value smaller than our target, set that as our range
      range = i
      break
    end
  end
  return 100 * ((range - 1) + ((hzValue - fmodtable[range]) / (fmodtable[range + 1] - fmodtable[range])))
end

local reverseFmodTable = {0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000}
local function FMODHzToHz(fmodHzValue)
  local range = #reverseFmodTable - 1
  fmodHzValue = math.max(reverseFmodTable[1], math.min(fmodHzValue, reverseFmodTable[#reverseFmodTable]))
  for i = range, 1, -1 do
    if reverseFmodTable[i] <= fmodHzValue then
      range = i
      break
    end
  end

  return ((((fmodHzValue / 100) - (range - 1)) * (fmodtable[range + 1] - fmodtable[range])) + fmodtable[range])
end

local function updateVehicleData()
  if vEditor and vEditor.vehicle then
    vEditor.engine = {}
    vEditor.vehicle:queueLuaCommand([[
      local data, names = sounds.getEngineSoundData();
      data = serialize(data);
      names = serialize(names);
      obj:queueGameEngineLua(string.format('vEditor.engine.engineSoundData = %s; vEditor.engine.engineNameStrings = %s', data, names))]])
  end
end

local changed = true
local function onEditorGui(dt)
  if not vEditor or not vEditor.vehicle then return end
  if not vEditor.engine or not vEditor.engine.engineSoundData then
    updateVehicleData()
    return
  end
  selectedEngineData = vEditor.engine.engineSoundData[selectedEngineSound[0]]
  -- window
  if editor.beginWindow(wndName, wndName) then
    im.Text("Sound Selection")
    im.Indent()
    local engineNameStringArray = im.ArrayCharPtrByTbl(vEditor.engine.engineNameStrings)
    if im.Combo1("Engine/Sound", selectedEngineSound, engineNameStringArray) then
      changed = true;
    end
    im.Unindent()
    im.Separator()

    if selectedEngineData then
      mainGain[0] = selectedEngineData.data.params.main_gain
      onLoadGain[0] = selectedEngineData.data.params.onLoadGain
      offLoadGain[0] = selectedEngineData.data.params.offLoadGain

      lowShelfFreq[0] = FMODHzToHz(selectedEngineData.data.params.eq_a_freq)
      lowShelfGain[0] = selectedEngineData.data.params.eq_a_gain or 0
      eqLowGain[0] = selectedEngineData.data.params.eq_c_gain
      eqLowFreq[0] = FMODHzToHz(selectedEngineData.data.params.eq_c_freq)
      eqLowWidth[0] = selectedEngineData.data.params.eq_c_reso

      eqHighGain[0] = selectedEngineData.data.params.eq_d_gain
      eqHighFreq[0] = FMODHzToHz(selectedEngineData.data.params.eq_d_freq)
      eqHighWidth[0] = selectedEngineData.data.params.eq_d_reso
      highShelfFreq[0] = FMODHzToHz(selectedEngineData.data.params.eq_b_freq)
      highShelfGain[0] = selectedEngineData.data.params.eq_b_gain or 0

      eqFundamentalGain[0] = selectedEngineData.data.params.eq_e_gain
      fundamentalFreqCylCount[0] = (selectedEngineData.data.params.fundamentalFrequencyRPMCoef or 0) * 120 + 0.5
      muffling[0] = selectedEngineData.data.params.muffled or 1

      im.Text("General")
      im.Indent()
      changed = im.DragFloat("mainGain", mainGain, 1, -30, 10) or changed
      changed = im.DragFloat("muffling", muffling, 0.01, 0, 1) or changed
      im.Unindent()
      im.Separator()

      im.Text("On/Off-Load")
      im.Indent()
      changed = im.DragFloat("onLoadGain", onLoadGain, 0.01, -0, 1) or changed
      changed = im.DragFloat("offLoadGain", offLoadGain, 0.01, 0, 1) or changed
      im.Unindent()
      im.Separator()

      im.Text("High/Low Shelf")
      im.Indent()
      changed = im.DragFloat("lowShelfFreq", lowShelfFreq, 100, 20, 20000) or changed
      changed = im.DragFloat("lowShelfGain", lowShelfGain, 1, -30, 30) or changed
      changed = im.DragFloat("highShelfFreq", highShelfFreq, 100, 20, 20000) or changed
      changed = im.DragFloat("highShelfGain", highShelfGain, 1, -30, 30) or changed
      im.Unindent()
      im.Separator()

      im.Text("EQ Low")
      im.Indent()
      changed = im.DragFloat("eqLowGain", eqLowGain, 1, -30, 30) or changed
      changed = im.DragFloat("eqLowFreq", eqLowFreq, 100, 20, 20000) or changed
      changed = im.DragFloat("eqLowWidth", eqLowWidth, 0.01, 0, 1) or changed
      im.Unindent()
      im.Separator()

      im.Text("EQ High")
      im.Indent()
      changed = im.DragFloat("eqHighGain", eqHighGain, 1, -30, 30) or changed
      changed = im.DragFloat("eqHighFreq", eqHighFreq, 100, 20, 20000) or changed
      changed = im.DragFloat("eqHighWidth", eqHighWidth, 0.01, 0, 1) or changed
      im.Unindent()
      im.Separator()

      im.Text("Fundamental Frequency")
      im.Indent()
      changed = im.DragFloat("eqFundamentalGain", eqFundamentalGain, 1, -30, 30) or changed
      changed = im.SliderInt("fundamentalFrequencyCylinderCount", fundamentalFreqCylCount, 0, 32) or changed
      im.Unindent()
      im.Separator()
      changed = im.Checkbox("Show exhaust direction", showExhaustDirection) or changed
      im.Separator()

      local exportData = im.Button("Copy to Clipboard", im.ImVec2(150, 25))

      local params = {
        base_gain = mainGain[0],
        gainOffset = 0,
        gainOffsetRevLimiter = 0,
        mufflingOffsetRevLimiter = 0,
        eq_a_freq = hzToFMODHz(lowShelfFreq[0]),
        eq_a_gain = lowShelfGain[0],
        eq_b_freq = hzToFMODHz(highShelfFreq[0]),
        eq_b_gain = highShelfGain[0],
        eq_c_freq = hzToFMODHz(eqLowFreq[0]),
        eq_c_gain = eqLowGain[0],
        eq_c_reso = eqLowWidth[0],
        eq_d_freq = hzToFMODHz(eqHighFreq[0]),
        eq_d_gain = eqHighGain[0],
        eq_d_reso = eqHighWidth[0],
        eq_e_gain = eqFundamentalGain[0],
        onLoadGain = onLoadGain[0],
        offLoadGain = offLoadGain[0],
        base_muffled = muffling[0],
        mufflingOffset = 0,
        fundamentalFrequencyRPMCoef = fundamentalFreqCylCount[0] / 120
      }

      if exportData then
        local data = {
          mainGain = mainGain[0],
          muffling = muffling[0],
          onLoadGain = onLoadGain[0],
          offLoadGain = offLoadGain[0],
          lowShelfFreq = lowShelfFreq[0],
          lowShelfGain = lowShelfGain[0],
          highShelfFreq = highShelfFreq[0],
          highShelfGain = highShelfGain[0],
          eqLowGain = eqLowGain[0],
          eqLowFreq = eqLowFreq[0],
          eqLowWidth = eqLowWidth[0],
          eqHighGain = eqHighGain[0],
          eqHighFreq = eqHighFreq[0],
          eqHighWidth = eqHighWidth[0],
          eqFundamentalGain = eqFundamentalGain[0],
          fundamentalFrequencyCylinderCount = fundamentalFreqCylCount[0]
        }
        local dataString = jsonEncodePretty(data)
        dataString = dataString:sub(3, dataString:len() - 2)
        setClipboard(dataString)
      end

      im.SameLine()
      local reset = im.Button("Reset All to 0", im.ImVec2(150, 25))
      if reset then
        params = {
          base_gain = 0,
          gainOffset = 0,
          gainOffsetRevLimiter = 0,
          mufflingOffsetRevLimiter = 0,
          eq_a_freq = hzToFMODHz(20),
          eq_a_gain = 0,
          eq_b_freq = hzToFMODHz(10000),
          eq_b_gain = 0,
          eq_c_freq = hzToFMODHz(500),
          eq_c_gain = 0,
          eq_c_reso = 0,
          eq_d_freq = hzToFMODHz(2000),
          eq_d_gain = 0,
          eq_d_reso = 0,
          eq_e_gain = 1,
          onLoadGain = 1,
          offLoadGain = 1,
          base_muffled = 1,
          mufflingOffset = 0
        }

        changed = true
      end

      if changed then
        vEditor.vehicle:queueLuaCommand([[
          local engines = powertrain.getDevicesByCategory("engine");
          local engine = engines[]] .. selectedEngineData.engineIndex .. [[];
          engine:setEngineSoundParameterList(]] .. selectedEngineData.data.soundID .. "," .. serialize(params) .. ",\"" ..
                                              selectedEngineData.reference .. [[");

          local data, names = sounds.getEngineSoundData();
          data = serialize(data);
          names = serialize(names);
          obj:queueGameEngineLua(string.format('vEditor.engine.engineSoundData = %s; vEditor.engine.engineNameStrings = %s', data, names))]])
          vEditor.vehicle:showEngineDirection(selectedEngineData.data.soundID, showExhaustDirection[0])
        changed = false
      end
    end
  elseif selectedEngineData then
    vEditor.vehicle:showEngineDirection(selectedEngineData.data.soundID, false)
  end
  editor.endWindow()
end

-- helper function to open the window
local function open()
  editor.showWindow(wndName)
  changed = true
end

-- called when the extension is loaded (might be invisible still)
local function onExtensionLoaded()
  updateVehicleData()
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,200))
  editor.addWindowMenuItem(wndName, open, {groupMenuName = 'Audio'})
end

local function onVehicleSwitched(oldVehicle, newVehicle, player)
  if editor and editor.isEditorActive and editor.isEditorActive() then
    updateVehicleData()
  end
end

local function onEditorDeactivated()
  if vEditor and vEditor.vehicle and selectedEngineData then
    vEditor.vehicle:showEngineDirection(selectedEngineData.data.soundID, false)
  end
end

local function onEditorActivated()
  updateVehicleData()
end

-- public interface
M.onExtensionLoaded = onExtensionLoaded
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onDebugDrawActive = onDebugDrawActive
M.onVehicleSwitched = onVehicleSwitched
M.onEditorDeactivated = onEditorDeactivated
M.onEditorActivated = onEditorActivated

M.open = open

return M
