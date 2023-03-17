-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = extensions.ui_imgui
local imguiUtils = require('ui/imguiUtils')


local function displayLivedataByType(deviceType, device)
  im.Columns(2, "devicelivetable") -- im.ColumnsFlags_NoResize)
  im.SetColumnWidth(0, 200)
  im.SetColumnWidth(1, 1000)
  if deviceType == 'combustionEngine' then
    im.Separator()
    im.Text("engineLoad")
    im.NextColumn()
    imguiUtils.SampleFloatDisplay('engineLoad' .. device.name, device.engineLoad, 0.8)
    im.NextColumn()
  --  imguiUtils.cell("engineLoad", tostring(device.engineLoad))
    imguiUtils.cell("forcedInductionCoef", tostring(device.forcedInductionCoef))
    imguiUtils.cell("intakeAirDensityCoef", tostring(device.intakeAirDensityCoef))
  end
  if deviceType == 'differential' then
    im.Separator()
    im.Text("diffAngle")
    im.NextColumn()
    imguiUtils.SampleFloatDisplay('diffAngle' .. device.name, device.diffAngle, 0.8)
    im.NextColumn()
    --imguiUtils.cell("diffAngle", tostring(device.diffAngle))
    im.Text("outputAV2")
    im.NextColumn()
    imguiUtils.SampleFloatDisplay('outputAV2'..tostring(device.name),device.outputAV2,0.8)
    im.NextColumn()
    im.Text("outputTorque2")
    im.NextColumn()
    imguiUtils.SampleFloatDisplay("outputTorque2"..tostring(device.name),device.outputTorque2,0.8)
    im.NextColumn()
  end
  if deviceType == 'shaft'then
    im.Separator()
    imguiUtils.cell("primaryOutputAVName", tostring(device.primaryOutputAVName))
    imguiUtils.cell("secondaryOutputAVName", tostring(device.secondaryOutputAVName))
    imguiUtils.cell("primaryOutputTorqueName", tostring(device.primaryOutputTorqueName))
    imguiUtils.cell("secondaryOutputTorqueName", tostring(device.secondaryOutputTorqueName))
  end
  if deviceType == 'manualGearbox' then
    im.Separator()
    for i=0,#device.gearDamages do
      imguiUtils.cell(tostring(i), tostring(device.gearDamages[i]))
    end
  end
  if deviceType == 'frictionClutch' then
    im.Separator()
    imguiUtils.cell("clutchAngle", tostring(device.clutchAngle))
    imguiUtils.cell("torqueDiff", tostring(device.torqueDiff))
    imguiUtils.cell("lockSpring", tostring(device.lockSpring))
    imguiUtils.cell("lockDamp", tostring(device.lockDamp))
    imguiUtils.cell("thermalEfficiency", tostring(device.thermalEfficiency))
  end
  if deviceType == 'torqueConverter' then
    im.Separator()
    imguiUtils.cell("lockupClutchAngle", tostring(device.lockupClutchAngle))
    im.Text("torqueDiff")
    im.NextColumn()
    imguiUtils.SampleFloatDisplay('torqueDiff' .. device.name, device.torqueDiff, 0.8)
    im.NextColumn()
    imguiUtils.cell("lockupClutchSpring", tostring(device.lockupClutchSpring))
    imguiUtils.cell("lockupClutchDamp", tostring(device.lockupClutchDamp))
  end
  if deviceType == 'automaticGearbox' then
    im.Separator()
    im.Text("parkClutchAngle")
    im.NextColumn()
    imguiUtils.SampleFloatDisplay('parkClutchAngle'..device.name,device.parkClutchAngle,0.8)
    im.NextColumn()
    imguiUtils.cell("oneWayTorqueSmoother", tostring(device.oneWayTorqueSmoother))
    imguiUtils.cell("parkLockSpring", tostring(device.parkLockSpring))
  end
  if deviceType == "cvtGearbox"then
    im.Separator()
    imguiUtils.cell("parkLockSpring", tostring(device.parkLockSpring))
    imguiUtils.cell("oneWayTorqueSmoother", tostring(device.oneWayTorqueSmoother))
  end
  if deviceType == "dctGearbox"then
    im.Separator()
    imguiUtils.cell("torqueDiff", tostring(device.torqueDiff))
    imguiUtils.cell("parkLockSpring", tostring(device.parkLockSpring))
    imguiUtils.cell("clutchAngle1", tostring(device.clutchAngle1))
    imguiUtils.cell("clutchAngle2", tostring(device.clutchAngle2))
    imguiUtils.cell("lockSpring1", tostring(device.lockSpring1))
    imguiUtils.cell("lockSpring2", tostring(device.lockSpring2))
    imguiUtils.cell("lockDamp1", tostring(device.lockDamp1))
    imguiUtils.cell("lockDamp2", tostring(device.lockDamp2))
    imguiUtils.cell("gearRatio1", tostring(device.gearRatio1))
    imguiUtils.cell("gearRatio2", tostring(device.gearRatio2))
  end
  im.Columns(1)
end

local function displayLivedata(device)
  im.Columns(2, "pwlivedata")
  im.SetColumnWidth(0, 200)
  im.SetColumnWidth(1, 1000)
  imguiUtils.cell("inputAV", tostring(device.inputAV))
  imguiUtils.cell("outputAV1", tostring(device.outputAV1))
  if device.outputAV2 then
    imguiUtils.cell("outputAV2", tostring(device.outputAV2))
  end
  imguiUtils.cell("outputTorque1", tostring(device.outputTorque1))
  if device.outputTorque2 then
    imguiUtils.cell("outputTorque2", tostring(device.outputTorque2))
  end
  imguiUtils.cell("isBroken", tostring(device.isBroken))
  imguiUtils.cell("mode", tostring(device.mode))
  imguiUtils.cell("virtualMassAV", tostring(device.virtualMassAV))
  imguiUtils.cell("isPhysicallyDisconnected", tostring(device.isPhysicallyDisconnected))
  imguiUtils.cell("gearRatio", tostring(device.gearRatio))
  imguiUtils.cell("cumulativeGearRatio", tostring(device.cumulativeGearRatio))
  imguiUtils.cell("cumulativeInertia", tostring(device.cumulativeInertia))
  im.Columns(1)

end

local function showJbeamData(deviceID)
  if im.TreeNodeEx1("All jbeam data",im.TreeNodeFlags_DefaultOpen) then
    imguiUtils.addRecursiveTreeTable(vEditor.vdata.powertrain[deviceID], '', false)
    im.TreePop()
  end
end

local function initialize(editorInstance)
  vEditor = editorInstance
end

M.displayLivedataByType = displayLivedataByType
M.displayLivedata = displayLivedata
M.showJbeamData = showJbeamData

M.initialize = initialize

return M
