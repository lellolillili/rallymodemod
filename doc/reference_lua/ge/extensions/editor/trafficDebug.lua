-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui
local toolWindowName = "Traffic Debug"

local trafficRef, poolsRef, debugMode

-- ui stuff
local drawTab = nop
local selectedVehicle = nil
local selectedPool = nil
local selectedPoolVehicle = nil

-- colors
local colors = {
  white = im.ImVec4(1, 1, 1, 1),
  red = im.ImVec4(1, 0, 0, 1),
  yellow = im.ImVec4(1, 1, 0.5, 1),
  grey = im.ImVec4(0.5, 0.5, 0.5, 1)
}

-- debug stuff
local logs = {}
local maxLogsPerVeh = 100
local resetLogsAtRespawn = im.BoolPtr(false)

local function appendLog(id, data) -- inserts an entry into the log table
  if not logs[id] then logs[id] = {} end
  table.insert(logs[id], {Engine.Platform.getRuntime(), data.name, data.data and data.data.reason})
end

local function doBulletTextInfo(key, value) -- validates and displays a bullet point line of text
  local f = type(value) == "number" and "%0.2f" or "%s"
  if type(value) ~= "number" or type(value) ~= "string" then value = tostring(value) end
  im.BulletText(string.format(key..": "..f, value))
end

local function drawGeneralTab()
  local debugModeVar = im.BoolPtr(debugMode)
  if im.Checkbox("General traffic debug", debugModeVar) then
    if debugModeVar[0] then
      for id, veh in pairs(trafficRef) do
        veh.debugLine = true
        veh.debugText = true
      end
    end

    gameplay_traffic.debugMode = debugModeVar[0]
  end

  im.Separator()

  im.Columns(2)
  im.SetColumnWidth(0, 250)

  im.TextUnformatted("Amount of all traffic (including players)")
  im.NextColumn()
  im.TextUnformatted(tostring(tableSize(trafficRef)))
  im.NextColumn()

  im.Text("Amount of AI traffic vehicles")
  im.NextColumn()
  im.TextUnformatted(tostring(gameplay_traffic.getNumOfTraffic()))
  im.NextColumn()

  im.Text("Amount of active AI traffic vehicles")
  im.NextColumn()
  im.TextUnformatted(tostring(gameplay_traffic.getNumOfTraffic(true)))
  im.NextColumn()

  im.Text("Amount of police vehicles")
  im.NextColumn()
  im.TextUnformatted(tostring(tableSize(gameplay_police.getPoliceVehicles())))
  im.NextColumn()

  im.Columns(1)
end

local function drawVehiclesTab()
  im.BeginChild1("Vehicles##trafficDebug", im.ImVec2(180 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)
  for _, id in ipairs(tableKeysSorted(trafficRef)) do
    local veh = trafficRef[id]
    local txtColor = colors.white
    if veh.state == "fadeIn" then
      txtColor = colors.red
    elseif not be:getObjectByID(id):getActive() then
      txtColor = colors.grey
    elseif veh.isPlayerControlled then
      txtColor = colors.yellow
    end

    im.PushStyleColor2(im.Col_Text, txtColor)
    if im.Selectable1("["..id.."] "..veh.model.key, veh == selectedVehicle) then
      selectedVehicle = veh
    end
    im.PopStyleColor()
  end
  im.EndChild()

  im.SameLine()

  im.BeginChild1("Current Vehicle##trafficDebug", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
  if selectedVehicle then
    local obj = be:getObjectByID(selectedVehicle.id)
    im.Text("Information")

    im.BulletText("Model: "..selectedVehicle.model.name)
    im.BulletText("State: "..selectedVehicle.state)
    im.BulletText("Role: "..selectedVehicle.role.name)
    im.BulletText("Action: "..selectedVehicle.role.actionName)
    im.Dummy(im.ImVec2(0, 5))

    if im.TreeNode1("General Info") then
      for _, key in ipairs({"damage", "crashDamage", "speed", "distCam", "respawnCount", "camVisible", "isAi", "isPlayerControlled"}) do
        doBulletTextInfo(key, selectedVehicle[key])
      end
      im.TreePop()
    end

    if im.TreeNode1("Respawn Info") then
      for _, key in ipairs({"spawnValue", "spawnDirBias", "sightStrength", "sightDirValue", "finalRadius", "readyValue"}) do
        doBulletTextInfo(key, selectedVehicle.respawn[key])
      end
      im.TreePop()
    end

    if im.TreeNode1("Pursuit Info") then
      local pursuit = selectedVehicle.pursuit
      for _, key in ipairs({"mode", "score", "offensesCount", "uniqueOffensesCount"}) do
        doBulletTextInfo(key, pursuit[key])
      end

      local timers = pursuit.timers
      for _, key in ipairs({"main", "arrest", "evade", "arrestValue", "evadeValue"}) do
        doBulletTextInfo(key, timers[key])
      end
      im.TreePop()
    end

    if im.TreeNode1("Role Info") then
      local role = selectedVehicle.role
      for _, key in ipairs({"actionTimer", "targetId", "targetNear", "targetVisible"}) do
        doBulletTextInfo(key, role[key])
      end
      im.BulletText("flags: "..table.concat(tableKeysSorted(role.flags), ", "))

      im.TreePop()
    end

    if im.TreeNode1("Personality Info") then
      for k, v in pairs(selectedVehicle.role.driver.personality) do
        doBulletTextInfo(k, v)
      end
      im.TreePop()
    end

    im.Separator()

    im.Text("Actions")

    local enableRespawn = im.BoolPtr(selectedVehicle.enableRespawn)
    if im.Checkbox("Enable respawning", enableRespawn) then
      selectedVehicle.enableRespawn = enableRespawn[0]
    end
    im.tooltip("Enables or disables the vehicle respawning by itself if out of sight.")

    local enableEntering = im.BoolPtr(obj.playerUsable == nil or obj.playerUsable == true)
    if im.Checkbox("Enable entering", enableEntering) then
      obj.playerUsable = enableEntering[0]
    end
    im.tooltip("Enables or disables the player switching to or entering the vehicle.")

    local drawLine = im.BoolPtr(selectedVehicle.debugLine)
    if im.Checkbox("Draw debug line", drawLine) then
      selectedVehicle.debugLine = drawLine[0]
    end

    local drawText = im.BoolPtr(selectedVehicle.debugText)
    if im.Checkbox("Draw debug text", drawText) then
      selectedVehicle.debugText = drawText[0]
    end

    if im.Button("Dump Data") then
      dump(selectedVehicle)
    end
    im.tooltip("Displays vehicle data in the developer console (press [~]).")

    if im.Button("Force Respawn") then
      gameplay_traffic.forceTeleport(selectedVehicle.id)
    end

    if im.Button("Refresh Vehicle") then
      selectedVehicle:onRefresh()
    end

    if im.Button("Reset Vehicle") then
      local obj = be:getObjectByID(selectedVehicle.id)
      obj:queueLuaCommand("recovery.recoverInPlace()")
      selectedVehicle:onRefresh()
    end

    im.Separator()

    im.Text("Logs")

    im.BeginChild1("Action Logs##trafficDebug", im.ImVec2(im.GetWindowContentRegionWidth(), 200), true, im.WindowFlags_None)
    if logs[selectedVehicle.id] then
      for i, v in ipairs(logs[selectedVehicle.id]) do
        if(i > maxLogsPerVeh) then table.remove(logs[selectedVehicle.id], 1) end
        local str = string.format("%0.3f | %s", v[1], v[2])
        if v[3] then
          str = str.." ("..v[3]..")"
        end
        im.Text(str)
      end
    end
    im.EndChild()

    im.Checkbox("Clear logs on respawn", resetLogsAtRespawn)
  end
  im.EndChild()
end

local function drawPoolOptionsModal(poolId)
  if im.BeginPopupModal("Pool Options", nil, im.WindowFlags_AlwaysAutoResize) then
    im.BeginChild1("Pool Options Child", im.ImVec2(300 * im.uiscale[0], 150), im.WindowFlags_HorizontalScrollbar)
    local isInfinite = selectedPool.maxActiveVehs == math.huge
    local maxActiveVehs = isInfinite and im.IntPtr(1e6) or im.IntPtr(selectedPool.maxActiveVehs)

    if isInfinite then im.BeginDisabled() end
    if im.SliderInt("Max active vehicles", maxActiveVehs, 0, 32) then
      selectedPool:setMaxActiveVehs(maxActiveVehs[0])
    end
    if isInfinite then im.EndDisabled() end

    local isInfinitePtr = im.BoolPtr(isInfinite)
    if im.Checkbox("Unlimited amount", isInfinitePtr) then
      if isInfinitePtr[0] then
        selectedPool:setMaxActiveVehs(math.huge)
      else
        selectedPool:setMaxActiveVehs(maxActiveVehs[0])
      end
    end

    im.Separator()
    if im.Button("Done") then
      im.CloseCurrentPopup()
    end

    im.EndChild()
    im.EndPopup()
  end
end

local function drawAddVehicleToPoolModal(poolId)
  if im.BeginPopupModal("Manage Veh Pool", nil, im.WindowFlags_AlwaysAutoResize) then
    im.BeginChild1("Veh Pool Add Vehicles", im.ImVec2(300 * im.uiscale[0], 250), im.WindowFlags_HorizontalScrollbar)
    im.Text("Add a vehicle to pool")
    im.Separator()
    for id, veh in pairs(trafficRef) do
      if not core_vehiclePoolingManager.getPoolOfVeh(id) then
        if im.Button("["..id.."] "..veh.model.key) then
          selectedPool:insertVeh(id)
        end
      else
        im.Text("Vehicle id ["..id.."] already in a pool")
      end
    end
    im.EndChild()
    im.SameLine()

    im.BeginChild1("Veh Pool Remove Vehicles", im.ImVec2(300 * im.uiscale[0], 250), im.WindowFlags_HorizontalScrollbar)
    im.Text("Remove a vehicle from pool")
    im.Separator()
    for _, id in ipairs(selectedPool:getVehs()) do
      local veh = trafficRef[id]
      if veh then
        if im.Button("["..id.."] "..veh.model.key) then
          selectedPool:removeVeh(id)
        end
      end
    end

    im.EndChild()
    if im.Button("Done", im.ImVec2(120, 0)) then im.CloseCurrentPopup() end
    im.EndPopup()
  end
end

local function drawPoolingTab()
  if not core_vehiclePoolingManager then
    im.Text("Vehicle pooling not loaded")
    return
  end

  local childrenHeight = 350

  if not next(poolsRef) then
    poolsRef = core_vehiclePoolingManager.getAllPools()
  end

  im.BeginChild1("Pools##trafficDebug", im.ImVec2(300 * im.uiscale[0], childrenHeight), im.WindowFlags_HorizontalScrollbar)
  im.Text("Available pools: ")
  im.Separator()
  for id, v in pairs(poolsRef) do
    if im.Selectable1("Pool ID: "..id, v == selectedPool, nil, im.ImVec2(80, 20)) then
      selectedPool = v
    end

    if selectedPool and selectedPool.id == id then
      im.SameLine()
      if im.Button("Options##vehPool"..id) then
        im.OpenPopup("Pool Options")
      end
      drawPoolOptionsModal(id)
      im.SameLine()
      if im.Button("Remove##vehPool"..id) then
        selectedPoolVehicle = nil
        selectedPool:deletePool()
        selectedPool = nil
      end
    end
  end

  im.Dummy(im.ImVec2(0, 5))
  if im.Button("Create New Pool") then
    core_vehiclePoolingManager.createPool()
  end
  im.EndChild()

  im.SameLine()

  im.BeginChild1("Pool Vehicles##trafficDebug", im.ImVec2(300 * im.uiscale[0], childrenHeight), im.WindowFlags_HorizontalScrollbar)
  im.Text("Vehicles in selected pool: ")
  im.Separator()
  if selectedPool then
    for _, id in ipairs(selectedPool:getVehs()) do
      local obj = be:getObjectByID(id)
      local state = selectedPool.allVehs[id] == 1 and "active" or "inactive"
      if im.Selectable1("["..id.."] "..obj.jbeam.." ("..state..")", selectedPoolVehicle == id, nil, im.ImVec2(160, 20)) then
        selectedPoolVehicle = id
      end

      if selectedPoolVehicle == id then
        im.SameLine()
        if state == "active" then
          if im.Button("Deactivate##veh"..id) then
            selectedPool:setVeh(id, false)
          end
        else
          if im.Button("Activate##veh"..id) then
            selectedPool:setVeh(id, true)
          end
        end
      end
    end
    im.Dummy(im.ImVec2(0, 5))
    if im.Button("Manage Vehicles") then
      im.OpenPopup("Manage Veh Pool")
    end
    drawAddVehicleToPoolModal(selectedPool.id)

    if im.Button("Activate All") then
      selectedPool:setAllVehs(true)
    end
    if im.Button("Deactivate All") then
      selectedPool:setAllVehs(false)
    end

    if not selectedPool.inactiveVehs[1] then im.BeginDisabled() end
    if im.Button("Cycle") then
      selectedPool:cycle(selectedPoolVehicle)
    end
    if not selectedPool.inactiveVehs[1] then im.EndDisabled() end
  else
    im.Text("No pool selected")
  end
  im.EndChild()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorDeactivated()
  gameplay_traffic.debugMode = false
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(400, 600))
  editor.addWindowMenuItem(toolWindowName, onWindowMenuItem, {groupMenuName = "Experimental"})
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, toolWindowName) then
    if not gameplay_traffic or gameplay_traffic.getState() ~= "on" then
      im.Text("Traffic not loaded!")
      return
    end

    if not trafficRef then -- turn on debug mode initially
      gameplay_traffic.debugMode = true
    end
    trafficRef = gameplay_traffic.getTrafficData()
    poolsRef = core_vehiclePoolingManager.getAllPools()
    debugMode = gameplay_traffic.debugMode

    if im.BeginTabBar("modes") then
      for _, v in ipairs({{"General", drawGeneralTab}, {"Vehicles", drawVehiclesTab}, {"Pooling", drawPoolingTab}}) do
        if im.BeginTabItem(v[1], nil) then
          drawTab = v[2] -- sets drawTab function reference
          im.EndTabItem()
        end
      end

      im.EndTabBar()
    end

    drawTab()
  end
end

local function onTrafficAction(id, data)
  appendLog(id, data)
end

--[[Callbacks]]--
local function onVehicleResetted(id)
  if resetLogsAtRespawn[0] then
    logs[id] = nil
  end
end

M.onEditorDeactivated = onEditorDeactivated
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onVehicleResetted = onVehicleResetted
M.onTrafficAction = onTrafficAction

return M