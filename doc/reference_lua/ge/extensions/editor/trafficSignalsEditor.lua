-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui

local logTag = "editor_trafficSignals"
local editWindowName = "Traffic Signals"
local editModeName = "signalsEditMode"

local intersections, controllers = {}, {}
local interIdx, ctrlIdx, nodeIdx, signalIdx = 1, 1, 1, 1
local selectedNodeIdx, selectedObject, oldPos
local interName, ctrlName = im.ArrayChar(256, ""), im.ArrayChar(256, "")
local colorBase, colorNode, colorGuide, colorNoNode = ColorF(1, 1, 1, 0.4), ColorF(1, 1, 0.25, 0.4), ColorF(0.25, 1, 0.25, 0.4), ColorF(1, 0.25, 0.25, 0.4)
local colorWarning, colorError = im.ImVec4(1, 1, 0, 1), im.ImVec4(1, 0, 0, 1)
local defaultSignalType = "lightsBasic"
local tabFlags = {}
local lastUsed = {prototype = defaultSignalType}
local signalObjects = {}
local signalObjectFlags = {}
local timedTexts = {}
local signalMetadata
local trafficSignals

local mousePos = vec3(0, 0, 0)
local vecUp = vec3(0, 0, 1)
local vecY = vec3(0, 1, 0)
local intersectionRadius = 1.5
local signalNodeRadius = 0.25

local mapNodes, mapGp, currNode, currSignalObj
local firstLoad, running = true, false

local function getControllerIndex(name) -- returns the index of the named controller
  if not name then return end
  for i, v in ipairs(controllers) do
    if v.name == name then return i end
  end
  return
end

local function closestRoadData(pos)
  local n1, n2, dist = map.findClosestRoad(pos)
  if not n1 then
    return {}
  else
    if mapNodes[n2].pos:squaredDistance(pos) < mapNodes[n1].pos:squaredDistance(pos) then
      n1, n2 = n2, n1
    end
    return {n1 = n1, n2 = n2, pos = mapNodes[n1].pos, radius = mapNodes[n1].radius}
  end
end

local function staticRayCast()
  local rayCastHit
  if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end
  local rayCast = cameraMouseRayCast()
  if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end

  if rayCast then rayCastHit = vec3(rayCast.pos) end
  return rayCastHit
end

local function updateGizmoPos()
  local data = intersections[interIdx]
  if data then
    local pos = (selectedNodeIdx and data.signalNodes[selectedNodeIdx]) and data.signalNodes[selectedNodeIdx].pos or data.pos
    local nodeTransform = MatrixF(true)
    nodeTransform:setPosition(pos)
    editor.setAxisGizmoTransform(nodeTransform)
  end
end

local function setRunState(val)
  if val then
    trafficSignals.setupSignals({intersections = intersections, controllers = controllers, metadata = signalMetadata})
    trafficSignals.setDebugLevel(2)
    running = true
  else
    trafficSignals.setActive(false)
    trafficSignals.setDebugLevel(0)
    running = false
  end
end

local function formatData()
  local intersectionsList, controllersList = {}, {}

  for _, v in ipairs(intersections) do
    table.insert(intersectionsList, v:onSerialize())
  end
  for _, v in ipairs(controllers) do
    table.insert(controllersList, v:onSerialize())
  end
  return {intersections = intersectionsList, controllers = controllersList}
end

local function loadData(data)
  intersections, controllers = {}, {}
  interIdx, ctrlIdx, nodeIdx, signalIdx = 1, 1, 1, 1

  if data then
    for k, v in ipairs(data.intersections) do
      local o = trafficSignals.newIntersection()
      o:onDeserialized(v)
      table.insert(intersections, o)
    end
    for k, v in ipairs(data.controllers) do
      local o = trafficSignals.newSignalController()
      o:onDeserialized(v)
      table.insert(controllers, o)
    end
  end

  if intersections[interIdx] then
    interName = im.ArrayChar(256, intersections[interIdx].name)
  end
  if controllers[ctrlIdx] then
    ctrlName = im.ArrayChar(256, controllers[ctrlIdx].name)
  end
end

local function saveFile()
  local fileName = getMissionFilename()
  if fileName and fileName ~= "" then
    fileName = path.split(fileName).."signals.json"
    local json = jsonReadFile(fileName)
    if not json then json = {} end

    local allData = formatData()
    json.intersections, json.controllers = allData.intersections, allData.controllers
    jsonWriteFile(fileName, json, true)
    timedTexts.save = {"Signals saved!", 3}
  end
end

local function loadFile()
  local fileName = getMissionFilename()
  if fileName and fileName ~= "" then
    fileName = path.split(fileName).."signals.json"
    loadData(jsonReadFile(fileName))
  end
end

local function createIntersectionActionUndo(data)
  table.remove(intersections, data.deleteIdx or #intersections)
  interIdx = math.max(1, interIdx - 1)
  local name = intersections[interIdx] and intersections[interIdx].name or ""
  interName = im.ArrayChar(256, name)
end

local function createIntersectionActionRedo(data)
  table.insert(intersections, trafficSignals.newIntersection())
  interIdx = #intersections
  intersections[interIdx]:onDeserialized(data)
  if not intersections[interIdx].name then intersections[interIdx].name = "intersection"..#intersections end
  interName = im.ArrayChar(256, intersections[interIdx].name)
  signalObjects = {}
end

local function moveIntersectionActionUndo(data)
  intersections[interIdx].pos = vec3(data.oldPos)
  intersections[interIdx].mapNode = closestRoadData(data.oldPos).n1
  updateGizmoPos()
end

local function moveIntersectionActionRedo(data)
  intersections[interIdx].pos = vec3(data.newPos)
  intersections[interIdx].mapNode = closestRoadData(data.newPos).n1
  updateGizmoPos()
end

local function createSignalNodeActionUndo(data)
  intersections[interIdx]:deleteSignalNode(nodeIdx)
  nodeIdx = math.max(1, nodeIdx - 1)
end

local function createSignalNodeActionRedo(data)
  intersections[interIdx]:addSignalNode(data)
  nodeIdx = #intersections[interIdx].signalNodes
end

local function moveSignalNodeActionUndo(data)
  intersections[interIdx].signalNodes[selectedNodeIdx].pos = vec3(data.oldPos)
  intersections[interIdx].signalNodes[selectedNodeIdx].mapNode = closestRoadData(data.oldPos).n1
  updateGizmoPos()
end

local function moveSignalNodeActionRedo(data)
  intersections[interIdx].signalNodes[selectedNodeIdx].pos = vec3(data.newPos)
  intersections[interIdx].signalNodes[selectedNodeIdx].mapNode = closestRoadData(data.newPos).n1
  updateGizmoPos()
end

local function createControllerActionUndo(data)
  table.remove(controllers, data.deleteIdx or #controllers)
  ctrlIdx = math.max(1, ctrlIdx - 1)
  local name = controllers[ctrlIdx] and controllers[ctrlIdx].name or ""
  ctrlName = im.ArrayChar(256, name)
end

local function createControllerActionRedo(data)
  table.insert(controllers, trafficSignals.newSignalController())
  ctrlIdx = #controllers
  controllers[ctrlIdx]:onDeserialized(data)
  if not controllers[ctrlIdx].name then controllers[ctrlIdx].name = "controller"..#controllers end
  ctrlName = im.ArrayChar(256, controllers[ctrlIdx].name)
end

local function createSignalActionUndo(data)
  controllers[ctrlIdx]:deleteSignal(signalIdx)
  signalIdx = math.max(1, signalIdx - 1)
end

local function createSignalActionRedo(data)
  controllers[ctrlIdx]:addSignal(data)
  signalIdx = #controllers[ctrlIdx].signals
end

local function reloadAllDataActionUndo(data)
  loadData(data.old)
  setRunState(false)
end

local function reloadAllDataActionRedo(data)
  loadData(data.new)
  setRunState(false)
end

local function gizmoBeginDrag()
  local data = intersections[interIdx]
  if data then
    oldPos = (selectedNodeIdx and data.signalNodes[selectedNodeIdx]) and vec3(data.signalNodes[selectedNodeIdx].pos) or vec3(data.pos)
  end
end

local function gizmoEndDrag()
  local data = intersections[interIdx]
  if data then
    local act = {oldPos = oldPos, newPos = vec3(editor.getAxisGizmoTransform():getColumn(3))}
    if selectedNodeIdx and data.signalNodes[selectedNodeIdx] then
      editor.history:commitAction("Position Intersection Signal Node", act, moveSignalNodeActionUndo, moveSignalNodeActionRedo)
    else
      editor.history:commitAction("Position Intersection", act, moveIntersectionActionUndo, moveIntersectionActionRedo)
    end
  end
end

local function gizmoMidDrag()
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    local data = intersections[interIdx]
    if data then
      if selectedNodeIdx and data.signalNodes[selectedNodeIdx] then
        data.signalNodes[selectedNodeIdx].pos = vec3(editor.getAxisGizmoTransform():getColumn(3))
      else
        data.pos = vec3(editor.getAxisGizmoTransform():getColumn(3))
      end
    end
  end
end

local function tabIntersections()
  im.BeginChild1("intersections", im.ImVec2(150 * im.uiscale[0], 0), im.WindowFlags_ChildWindow)
  for i, v in ipairs(intersections) do
    if im.Selectable1(v.name, interIdx == i) then
      interName = im.ArrayChar(256, v.name)
      interIdx = i
      nodeIdx = 1
      selectedNodeIdx = nil
      signalObjects = {}
      updateGizmoPos()
    end
  end
  im.Separator()

  im.Selectable1("New...##intersection", false)
  im.tooltip("Shift-Click in the world to create a new intersection point.")
  im.EndChild()
  im.SameLine()

  im.BeginChild1("intersectionData", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
  if not im.IsWindowHovered(im.HoveredFlags_AnyWindow) and editor.keyModifiers.shift and mousePos then
    debugDrawer:drawTextAdvanced(mousePos, "Create Intersection", ColorF(1, 1, 1, 1), true, false, ColorI(0, 0, 0, 255))

    if im.IsMouseClicked(0) then
      local point = closestRoadData(mousePos)
      editor.history:commitAction("Create Intersection", {pos = vec3(mousePos), radius = 2, node = point.n1, controllerName = lastUsed.controllerName}, createIntersectionActionUndo, createIntersectionActionRedo)
    end
  end

  if intersections[interIdx] then
    local edited = im.BoolPtr(false)
    editor.uiInputText("Name##intersection", interName, nil, nil, nil, nil, edited)
    if edited then
      -- TODO: validate name here
      intersections[interIdx].name = ffi.string(interName)
    end
    im.SameLine()
    if im.Button("Delete##intersection") then
      local act = intersections[interIdx]:onSerialize()
      act.node = intersections[interIdx].mapNode
      act.deleteIdx = interIdx
      editor.history:commitAction("Delete Intersection", act, createIntersectionActionRedo, createIntersectionActionUndo)
    end
  end

  local data = intersections[interIdx]
  if data then
    local interPos = im.ArrayFloat(3)
    interPos[0], interPos[1], interPos[2] = data.pos.x, data.pos.y, data.pos.z
    if im.InputFloat3("Position##interPos", interPos, "%0."..editor.getPreference("ui.general.floatDigitCount").."f", im.InputTextFlags_EnterReturnsTrue) then
      local act = {oldPos = vec3(data.pos), newPos = vec3(interPos[0], interPos[1], interPos[2])}
      editor.history:commitAction("Position Intersection", act, moveIntersectionActionUndo, moveIntersectionActionRedo)
    end
    if im.Button("Down to Terrain##interPos") and core_terrain.getTerrain() then
      local act = {oldPos = vec3(data.pos), newPos = vec3(interPos[0], interPos[1], core_terrain.getTerrainHeight(vec3(data.pos)))}
      editor.history:commitAction("Position Intersection", act, moveIntersectionActionUndo, moveIntersectionActionRedo)
    end

    local name = data.controllerName or "(None)"
    if im.BeginCombo("Controller##intersection", name) then
      for _, v in ipairs(controllers) do
        if im.Selectable1(v.name, v.name == name) then
          data.controllerName = v.name
          lastUsed.controllerName = v.name
        end
      end
      im.EndCombo()
    end

    if data.controllerName then
      if im.Button("Edit##intersectionCtrl") then
        local idx = getControllerIndex(data.controllerName)
        if idx then
          ctrlName = im.ArrayChar(256, controllers[idx].name)
          ctrlIdx = idx
          tabFlags = {im.flags(im.TabItemFlags_None), im.flags(im.TabItemFlags_SetSelected)}
        end
      end
      im.SameLine()
    end
    if im.Button("Use Default##intersectionCtrl") then
      if not getControllerIndex("default") then
        editor.history:commitAction("Create Controller", trafficSignals.defaultSignalController(), createControllerActionUndo, createControllerActionRedo)
      end
      data.controllerName = "default"
    end
    im.SameLine()
    if im.Button("Create New##intersectionCtrl") then
      editor.history:commitAction("Create Controller", {name = data.name}, createControllerActionUndo, createControllerActionRedo)
      local idx = #controllers
      data.controllerName = controllers[idx].name
      ctrlIdx = idx
      tabFlags = {im.flags(im.TabItemFlags_None), im.flags(im.TabItemFlags_SetSelected)}
    end

    if not data.mapNode then
      data.mapNode = closestRoadData(data.pos).n1
      if not data.mapNode then
        im.TextColored(colorWarning, "Warning, could not find closest road node!")
      end
    end

    im.Dummy(im.ImVec2(0, 5))
    im.Separator()
    im.TextUnformatted("Signal Nodes")

    if im.Button("Add##signalNode") then
      local nPos
      local dist = data.mapNode and math.max(5, mapNodes[data.mapNode].radius) or 5
      if data.mapNode then
        local node = mapGp.graph[data.mapNode] -- automatically attempt to place child nodes
        if node then
          local sortedSignalNodes = tableKeysSorted(node)
          local idx = #data.signalNodes + 1
          local childVec = sortedSignalNodes[idx] and (mapGp.positions[sortedSignalNodes[idx]] - data.pos):normalized() or vecY
          nPos = data.pos + childVec * (dist + 0.5)
        end
      end
      if not nPos then
        nPos = data.pos + vecY * (dist + 0.5)
      end
      local act = {pos = vec3(nPos)}
      editor.history:commitAction("Create Intersection Signal Node", act, createSignalNodeActionUndo, createSignalNodeActionRedo)
    end
    im.tooltip("Create a signal node with a stop position and signal phase number.")
    im.SameLine()
    if im.Button("Delete##signalNode") then
      if data.signalNodes[nodeIdx] then
        local act = {pos = vec3(data.signalNodes[nodeIdx].pos), signalIdx = data.signalNodes[nodeIdx].signalIdx}
        editor.history:commitAction("Delete Intersection Signal Node", act, createSignalNodeActionRedo, createSignalNodeActionUndo)
      end
    end
    if data.signalNodes[nodeIdx] then
      im.SameLine()
      im.TextUnformatted("Node #"..nodeIdx)
    end

    if data.signalNodes[1] then
      local dataCount = #data.signalNodes
      im.BeginChild1("Node List", im.ImVec2(0, 32 * im.uiscale[0]), im.WindowFlags_ChildWindow)
      im.Columns(dataCount + 1, "Node Cols", false)
      for i, v in ipairs(data.signalNodes) do
        im.SetColumnWidth(i - 1, clamp(30, 2, 40 - dataCount))
        if im.Selectable1(tostring(i), nodeIdx == i) then
          nodeIdx = i
          selectedNodeIdx = i
          updateGizmoPos()
          signalObjectFlags = {}
        end
        im.NextColumn()
      end
      im.Columns(1)
      im.EndChild()
    end

    for _, v in ipairs(data.signalNodes) do
      if not v.mapNode then
        v.mapNode = closestRoadData(v.pos).n1
      end
    end

    local sNode = data.signalNodes[nodeIdx]

    if sNode then
      local nodePos = im.ArrayFloat(3)
      nodePos[0], nodePos[1], nodePos[2] = sNode.pos.x, sNode.pos.y, sNode.pos.z
      if im.InputFloat3("Position##nodePos", nodePos, "%0."..editor.getPreference("ui.general.floatDigitCount").."f", im.InputTextFlags_EnterReturnsTrue) then
        local act = {oldPos = vec3(sNode.pos), newPos = vec3(nodePos[0], nodePos[1], nodePos[2])}
        editor.history:commitAction("Position Intersection Signal Node", act, moveSignalNodeActionUndo, moveSignalNodeActionRedo)
      end
      if im.Button("Down to Terrain##nodePos") and core_terrain.getTerrain() then
        selectedNodeIdx = nodeIdx
        local act = {oldPos = vec3(sNode.pos), newPos = vec3(nodePos[0], nodePos[1], core_terrain.getTerrainHeight(vec3(sNode.pos)))}
        editor.history:commitAction("Position Intersection Signal Node", act, moveSignalNodeActionUndo, moveSignalNodeActionRedo)
      end

      if not sNode.mapNode then
        im.TextColored(colorWarning, "Warning, could not find closest road node!")
      end

      local signalStr = "Phase #"
      local ctrl = getControllerIndex(data.controllerName)
      if not ctrl then
        signalStr = "(Controller Not Found)"
      elseif not controllers[ctrl].signals[1] then
        signalStr = "(None)"
      else
        signalStr = signalStr..sNode.signalIdx
      end

      local comboStr = signalStr
      if im.BeginCombo("Controller Phase##signalNode", comboStr) then
        if ctrl then
          ctrl = controllers[ctrl]
          for i, v in ipairs(ctrl.signals) do
            if im.Selectable1("Phase #"..i.." - "..signalMetadata.types[v.prototype].name, signalStr..i == signalStr..sNode.signalIdx) then
              sNode.signalIdx = i
            end
          end
        end
        im.EndCombo()
      end
    end

    im.Dummy(im.ImVec2(0, 5))
    im.Separator()
    im.TextUnformatted("Signal Objects")

    local str = signalObjects[1] and "Refresh" or "Find Objects"
    if im.Button(str.."##signalObjects") then
      signalObjects = trafficSignals.getSignalObjects(data.name)
      signalObjectFlags.objectsNotFound = not signalObjects[1] and true or false
    end
    im.tooltip("Search for world objects that have the dynamic field [intersection] that matches this intersection name.")

    im.SameLine()

    if not signalObjectFlags.selectObjects then
      if im.Button("Select Objects##signalObjects") then
        signalObjectFlags.selectObjects = true
        editor.selectEditMode(editor.editModes["objectSelect"])
      end
      im.tooltip("Switch to object selection mode to select signal objects.")
    else
      local count = tableSize(editor.selection.object)
      str = "Apply Data to Selection ("..count
      str = str..")"
      if im.Button(str.."##signalObjects") then
        if count > 0 then
          for _, id in ipairs(editor.selection.object) do
            editor.setDynamicFieldValue(id, "intersection", data.name)
            editor.setDynamicFieldValue(id, "phaseNum", data.signalNodes[nodeIdx].signalIdx)
          end
          editor.selectEditMode(editor.editModes[editModeName])
          editor.selection.object = nil
          signalObjects = trafficSignals.getSignalObjects(data.name)
          signalObjectFlags.selectObjects = false
          timedTexts.applyFields = {"Updated "..count.." objects: [intersection] = "..data.name..", [phaseNum] = "..data.signalNodes[nodeIdx].signalIdx.." .", 6}
        end
      end
      im.tooltip("Apply the dynamic fields [intersection] and [phaseNum] to this object.")
      im.SameLine()

      if im.Button("Cancel##signalObjects") then
        signalObjectFlags.selectObjects = false
        editor.selectEditMode(editor.editModes[editModeName])
        editor.selection.object = nil
      end
    end
    if timedTexts.applyFields then
      im.TextColored(colorWarning, timedTexts.applyFields[1])
    end

    if signalObjectFlags.objectsNotFound then
      im.TextUnformatted("No matching objects found.")
    end
    if signalObjects[1] then
      if signalObjectFlags.objectsNotFound then signalObjectFlags.objectsNotFound = false end
      im.TextUnformatted(#signalObjects.." matching objects found.")
      im.SameLine()
      if im.Button("View Selection##signalObjects") then
        if selectedObject then editor.fitViewToSelection() end
      end

      im.BeginChild1("signalObjects", im.ImVec2(im.GetContentRegionAvailWidth(), 150 * im.uiscale[0]), im.WindowFlags_ChildWindow)
      for _, v in ipairs(signalObjects) do
        local obj = scenetree.findObjectById(v)
        if obj then
          local sigNum = obj.signalNum and tonumber(obj.signalNum) or tonumber(obj.phaseNum)
          local sigText = sigNum and "(phase #"..sigNum..")" or "(no phase)"
          local line = "ID: "..v.." "..sigText

          if im.Selectable1(line, selectedObject == v) then
            editor.selectObjects({v})
            selectedObject = v
          end
          if not sigNum then
            im.tooltip("Object dynamic field [phaseNum] has no number value.")
          end
        end
      end
      im.EndChild()
    end

    if mousePos and editor.isViewportHovered() and im.IsMouseClicked(0) and not editor.isAxisGizmoHovered() and not editor.keyModifiers.shift then
      selectedNodeIdx = nil
      for i, v in ipairs(data.signalNodes) do
        if mousePos:squaredDistance(v.pos) <= signalNodeRadius + 0.3 then
          nodeIdx = i
          selectedNodeIdx = i
        end
      end
      if not selectedNodeIdx then
        for i, v in ipairs(intersections) do
          if mousePos:squaredDistance(v.pos) <= intersectionRadius + 0.3 then
            interIdx = i
            interName = im.ArrayChar(256, intersections[interIdx].name)
          end
        end
      end
      updateGizmoPos()
    end
    editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoMidDrag)
    editor.drawAxisGizmo()
  end
  im.EndChild()
end

local function tabControllers()
  im.BeginChild1("controllers", im.ImVec2(150 * im.uiscale[0], 0), im.WindowFlags_ChildWindow)

  for i, v in ipairs(controllers) do
    if im.Selectable1(v.name, ctrlIdx == i) then
      ctrlName = im.ArrayChar(256, v.name)
      ctrlIdx = i
      signalIdx = 1
    end
  end
  im.Separator()
  if im.Selectable1("Create...##controller", false) then
    editor.history:commitAction("Create Controller", {}, createControllerActionUndo, createControllerActionRedo)
  end
  im.EndChild()
  im.SameLine()

  im.BeginChild1("controllerData", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
  if controllers[ctrlIdx] then
    local edited = im.BoolPtr(false)
    editor.uiInputText("Name##controller", ctrlName, nil, nil, nil, nil, edited)
    if edited then
      -- TODO: validate name here
      controllers[ctrlIdx].name = ffi.string(ctrlName)
    end
    im.SameLine()
    if im.Button("Delete##controller") then
      local act = controllers[ctrlIdx]:onSerialize()
      act.deleteIdx = ctrlIdx
      editor.history:commitAction("Delete Controller", act, createControllerActionRedo, createControllerActionUndo)
    end
  end

  local data = controllers[ctrlIdx]
  if data then
    local var = im.IntPtr(data.signalStartIdx)
    im.PushItemWidth(100 * im.uiscale[0])
    im.InputInt("Initial Signal##controller", var, 1)
    im.PopItemWidth()
    data.signalStartIdx = math.max(1, var[0])

    var = im.IntPtr(data.lightStartIdx)
    im.PushItemWidth(100 * im.uiscale[0])
    im.InputInt("Initial Light##controller", var, 1)
    im.PopItemWidth()
    data.lightStartIdx = math.max(1, var[0])

    var = im.FloatPtr(data.startTime)
    im.PushItemWidth(100 * im.uiscale[0])
    im.InputFloat("Initial Time##controller", var, 1, nil, "%.2f")
    im.PopItemWidth()
    data.startTime = math.max(0, var[0])

    var = im.BoolPtr(data.skipStart)
    if im.Checkbox("Start Disabled##controller", var) then
      data.skipStart = var[0]
    end
    im.tooltip("Start this signal controller in the off state.")

    var = im.BoolPtr(data.customTimings)
    if im.Checkbox("Enable Custom Timings", var) then
      data.customTimings = var[0]
    end
    im.tooltip("Enable custom timing values for this signal controller.")

    im.Dummy(im.ImVec2(0, 5))
    im.Separator()
    im.TextUnformatted("Signal Phases")

    if im.Button("Add##signal") then
      editor.history:commitAction("Create Controller Signal", {signalType = lastUsed.prototype}, createSignalActionUndo, createSignalActionRedo)
    end
    im.tooltip("Create a signal phase that controls one or more directions of traffic flow.")
    im.SameLine()
    if im.Button("Delete##signal") then
      if data.signals[signalIdx] then
        local act = {lightDefaultIdx = data.signals[signalIdx].lightDefaultIdx, timings = deepcopy(data.signals[signalIdx].timings), action = data.signals[signalIdx].action, signalType = lastUsed.prototype}
        editor.history:commitAction("Delete Controller Signal", act, createSignalActionRedo, createSignalActionUndo)
      end
    end

    if data.signals[signalIdx] then
      im.SameLine()
      im.TextUnformatted("Phase #"..tostring(signalIdx))
    end

    if data.signals[1] then
      local dataCount = #data.signals
      im.BeginChild1("Signal List", im.ImVec2(0, 32 * im.uiscale[0]), im.WindowFlags_ChildWindow)
      im.Columns(dataCount + 1, "Signal Cols", false)
      for i, v in ipairs(data.signals) do
        im.SetColumnWidth(i - 1, clamp(30, 2, 40 - dataCount))
        if im.Selectable1(tostring(i), signalIdx == i) then
          signalIdx = i
        end
        im.NextColumn()
      end
      im.Columns(1)
      im.EndChild()
    end

    local signal = data.signals[signalIdx]
    if signal then
      if im.BeginCombo("Signal Type##signal", signalMetadata.types[signal.prototype].name) then
        local sortedSignalTypes = tableKeys(signalMetadata.types)
        table.sort(sortedSignalTypes)
        for _, v in ipairs(sortedSignalTypes) do
          if im.Selectable1(signalMetadata.types[v].name, v == signal.prototype) then
            signal.prototype = v
            lastUsed.prototype = v
            signal.lightDefaultIdx = signalMetadata.types[v].defaultIdx
            signal.timings = deepcopy(signalMetadata.types[v].timings)
          end
        end
        im.EndCombo()
      end

      im.Dummy(im.ImVec2(0, 5))
      im.TextUnformatted("Timings")

      if signal.timings then
        if data.customTimings then -- individual timings for each state (if enabled)
          for _, v in ipairs(signal.timings) do
            var = im.FloatPtr(v.duration)
            im.PushItemWidth(100 * im.uiscale[0])
            im.InputFloat(v.type.."##signal", var, 0.5, nil, "%.2f")
            im.PopItemWidth()
            v.duration = math.max(0.01, var[0])
          end
        else
          im.TextUnformatted("Signal timings will be set automatically.")
        end
      else
        im.TextUnformatted("No timings exist for this signal.")
      end
    end
  end
  im.EndChild()
end

local function tabSimulation()
  local inter = intersections[interIdx]
  if intersections[1] and controllers[1] then
    if not running then
      if im.Button("Play") then
        setRunState(true)
      end
    else
      if im.Button("Stop") then
        setRunState(false)
      end
    end

    if running then
      local debugData = trafficSignals.getValues()
      if debugData.nextTime then
        im.TextUnformatted("Current time / event time: "..tostring(string.format("%.2f", debugData.timer)).." / "..tostring(string.format("%.2f", debugData.nextTime)))
      end

      im.Dummy(im.ImVec2(0, 5))
      im.Separator()
      im.TextUnformatted("User Controls")

      im.PushItemWidth(200 * im.uiscale[0])
      if im.BeginCombo("Intersections##simulation", inter.name) then
        for i, v in ipairs(intersections) do
          if im.Selectable1(v.name, v.name == inter.name) then
            interIdx = i
          end
        end
        im.EndCombo()
      end
      im.PopItemWidth()

      local interObj = inter and core_trafficSignals.getIntersections()[inter.name] -- this one is the live copy, not in editor
      if interObj and interObj.control then
        local var = im.BoolPtr(interObj.control.skipTimer)
        if im.Checkbox("Ignore Timer##controller", var) then
          interObj.control:ignoreTimer(var[0])
        end
        im.tooltip("Disable automatic signal timings.")

        if im.Button("Advance") then
          interObj.control:advance()
        end
        im.tooltip("Advance to the next light state.")
      end
    end
  else
    im.TextUnformatted("Intersection and signal controller need to exist before running simulation.")
    running = false
  end
end

local function drawShapes()
  for i, data in ipairs(intersections) do
    if not running then
      local shapeColor = colorBase
      if interIdx == i then
        shapeColor = colorNode
        if not data.mapNode then shapeColor = colorNoNode end
      end

      if data.pos then
        local str = data.controllerName and " ("..data.controllerName..")" or ""
        debugDrawer:drawSphere(data.pos, intersectionRadius, shapeColor)
        debugDrawer:drawText(data.pos, String(data.name..str), ColorF(0, 0, 0, 1))

        if interIdx == i then
          for j, sNode in ipairs(intersections[interIdx].signalNodes) do
            if sNode.pos then
              shapeColor = j == nodeIdx and colorNode or colorBase
              if not sNode.mapNode then shapeColor = colorNoNode end
              local topPos = sNode.pos + vecUp * 7.5
              local c = rainbowColor(10, ((sNode.signalIdx or 0) * 7) % 10, 1)
              local capColor = ColorF(c[1], c[2], c[3], 0.6)
              debugDrawer:drawCylinder(sNode.pos, topPos, signalNodeRadius, shapeColor)
              debugDrawer:drawCylinder(topPos, topPos + vec3(0, 0, 0.5), signalNodeRadius, capColor)
              debugDrawer:drawText(sNode.pos, String("phase #"..sNode.signalIdx), ColorF(0, 0, 0, 1))

              if nodeIdx == j then
                debugDrawer:drawSquarePrism(data.pos, sNode.pos, Point2F(0.5, 0), Point2F(0.5, 2), colorGuide)
              end
            end
          end
        end
      end
    end
  end
end

local function onEditorGui(dt)
  if editor.beginWindow(editModeName, editWindowName, im.WindowFlags_MenuBar) then
    if firstLoad then
      editor.selectEditMode(editor.editModes[editModeName])

      mapNodes = map.getMap().nodes
      mapGp = map.getGraphpath()
      trafficSignals = extensions.core_trafficSignals
      signalMetadata = signalMetadata or trafficSignals.getSignalMetadata()

      if not intersections[1] and not controllers[1] then
        loadFile() -- loads default intersections & signals data from map
      end
      firstLoad = false
    end

    mousePos = staticRayCast()

    im.BeginMenuBar()
    if im.BeginMenu("File") then
      if im.MenuItem1("Load") then
        local act = {old = deepcopy(formatData())}
        loadFile()
        act.new = deepcopy(formatData())
        editor.history:commitAction("Reload Traffic Signals Editor Data", act, reloadAllDataActionUndo, reloadAllDataActionRedo)
      end
      if im.MenuItem1("Save") then
        saveFile()
      end
      if im.MenuItem1("Clear") then
        -- maybe add a modal popup here?
        local act = {old = deepcopy(formatData())}
        editor.history:commitAction("Reload Traffic Signals Editor Data", act, reloadAllDataActionUndo, reloadAllDataActionRedo)
      end
      im.EndMenu()
    end

    if timedTexts.save then
      im.SameLine()
      im.TextColored(colorWarning, timedTexts.save[1])
    end
    im.EndMenuBar()

    if im.BeginTabBar("Signal Tools") then
      if im.BeginTabItem("Intersections", nil, tabFlags[1]) then
        tabIntersections()
        im.EndTabItem()
      end
      if im.BeginTabItem("Controllers", nil, tabFlags[2]) then
        tabControllers()
        im.EndTabItem()
      end
      if im.BeginTabItem("Simulation", nil, tabFlags[3]) then
        tabSimulation()
        im.EndTabItem()
      end
      im.EndTabBar()
    end
    table.clear(tabFlags)

    drawShapes()
  end

  for k, v in pairs(timedTexts) do
    if v[2] then
      v[2] = v[2] - dt
      if v[2] <= 0 then timedTexts[k] = nil end
    end
  end

  editor.endWindow()
end

local function onActivate()
  editor.clearObjectSelection()
end

local function onSerialize()
  local intersectionsData, controllersData = {}, {}

  for _, v in ipairs(intersections) do
    table.insert(intersectionsData, v:onSerialize())
  end
  for _, v in ipairs(controllers) do
    table.insert(controllersData, v:onSerialize())
  end
  local data = {
    intersections = intersectionsData,
    controllers = controllersData,
  }
  return data
end

local function onDeserialized(data)
  trafficSignals = extensions.core_trafficSignals

  for _, v in ipairs(data.intersections) do
    local o = trafficSignals.newIntersection()
    o:onDeserialized(v)
    table.insert(intersections, o)
  end
  for _, v in ipairs(data.controllers) do
    local o = trafficSignals.newSignalController()
    o:onDeserialized(v)
    table.insert(controllers, o)
  end
  if intersections[1] then
    interName = im.ArrayChar(256, intersections[1].name)
  end
  if controllers[1] then
    ctrlName = im.ArrayChar(256, controllers[1].name)
  end
end

local function onWindowMenuItem()
  firstLoad = true
  editor.clearObjectSelection()
  editor.showWindow(editModeName)
end

local function onEditorInitialized()
  editor.registerWindow(editModeName, im.ImVec2(560, 520))
  editor.editModes[editModeName] = {
    displayName = editWindowName,
    onActivate = onActivate,
    auxShortcuts = {}
  }
  editor.editModes[editModeName].auxShortcuts[bit.bor(editor.AuxControl_LMB, editor.AuxControl_Shift)] = "Create Intersection"
  editor.editModes[editModeName].auxShortcuts[editor.AuxControl_LMB] = "Select"
  editor.addWindowMenuItem(editWindowName, onWindowMenuItem, {groupMenuName = "Gameplay"})
end

M.onEditorInitialized = onEditorInitialized
M.onWindowMenuItem = onWindowMenuItem
M.onEditorGui = onEditorGui
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M