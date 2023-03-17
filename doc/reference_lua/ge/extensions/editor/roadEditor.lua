-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_roadEditor'
local actionMapName = "RoadEditor"
local editModeName = "Edit Road"
local roadRiverGui = extensions.editor_roadRiverGui
local im = ui_imgui
local roadTemplatesActive = false

local u_32_max_int = 4294967295
local xVector = vec3(1,0,0)
local yVector = vec3(0,1,0)
local zVector = vec3(0,0,1)

local selectedNode = nil
local lastSelectedNode = nil
local hoveredNode = nil
local hoveredRoadID = nil
local lastHoveredRoadID = nil
local selectedRoadId = nil

local selectedNodes = {}

local hoveredRoadsIDs = {}
local hoveredRoadsIndex = 1

local tempNodeIndex = nil

local mouseButtonHeldOnNode = false
local oldNodeWidth = nil

local templateDialogOpen = im.BoolPtr(false)

-- Params for setting width of node by dragging the mouse after creating it
local dragMouseStartPos = vec3(0,0,0)

local useTemplate = im.BoolPtr(false)

local fieldsCopy = nil
local nodesCopy = nil

local lastMousePos = im.ImVec2(0,0)
local roadMaterialTagString = "RoadAndPath"
local roadNotSelectableErrorWindowName = "roadNotSelectableErrorWindowName"
local roadNotSelectableErrorWindowTitle = "Road Select Error"

local function showAIModeText()
  local vm = GFXDevice.getVideoMode()
  local w, h = vm.width, vm.height
  local windowAspectRatio = w/h

  local pos = getCameraPosition()
  local q = quat(getCameraQuat())
  local dist = 10
  local fovRadians = (getCameraFovRad() or 60)
  local x, y, z = q * xVector, q * yVector, q * zVector

  local center = pos + y*dist
  local height =  (math.tan(fovRadians/2) * dist)
  local width = (height * windowAspectRatio)

  local textPos = center - x*width/3 + z*height/3
  textPos = textPos + x*0.05 - z*0.05
  debugDrawer:drawTextAdvanced(textPos, String("Only AI roads selectable"), ColorF(0,0,0,1), false, false, ColorI(0,0,0,255), false, false)
end

local function indexOf(list, value)
  for index, v in ipairs(list) do
    if value == v then
      return index
    end
  end
  return nil
end

local function selectNodesRange(first, last)
  selectedNodes = {}
  for i = first, last do
    selectedNodes[i] = true
  end
end

local function onSelectAll()
  if selectedRoadId then
    local road = scenetree.findObjectById(selectedRoadId)
    if not road then return end
    selectNodesRange(0, road:getNodeCount()-1)
  end
end

local function selectNode(id)
  if tableIsEmpty(selectedNodes) then lastSelectedNode = nil end
  if id == nil then
    selectedNodes = {}
    selectedNode = nil
    return
  end
  if editor.keyModifiers.ctrl then
    if selectedNodes[id] then
      selectedNodes[id] = nil
    else
      selectedNodes[id] = true
    end
  elseif editor.keyModifiers.shift then
    if lastSelectedNode then
      selectNodesRange(math.min(lastSelectedNode, id), math.max(lastSelectedNode, id))
    else
      selectedNodes[id] = true
    end
  else
    selectedNodes = {}
    selectedNodes[id] = true
  end

  if tableSize(selectedNodes) == 1 then
    selectedNode = id
  else
    selectedNode = nil
  end

  if selectedNode then lastSelectedNode = selectedNode end
end

local function deleteNode(road, nodeID)
  editor.deleteRoadNode(road:getID(), nodeID)
  editor_roadUtils.reloadDecorations(road)
  editor_roadUtils.reloadDecals(road)
  editor_roadUtils.updateChildRoads(road, nodeID)
end

local function setNodeWidth(road, nodeID, width, safeStartWidth)
  editor.setNodeWidth(road, nodeID, width)
  editor.updateRoadVertices(road)
end

-- Paste Fields
local function pasteActionUndo(actionData)
  editor.pasteFields(actionData.oldFields, actionData.roadId)
end

local function pasteActionRedo(actionData)
  editor.pasteFields(actionData.newFields, actionData.roadId)
end

local function pasteFieldsAM()
  if selectedRoadId and fieldsCopy then
    editor.history:commitAction("PasteRoad", {oldFields = editor.copyFields(selectedRoadId), newFields = deepcopy(fieldsCopy), roadId = selectedRoadId}, pasteActionUndo, pasteActionRedo)
  end
end

-- Set all Nodes Width
local function setNodesWidthActionUndo(actionData)
  local road = scenetree.findObjectById(actionData.roadID)
  for index, oldWidth in pairs(actionData.oldWidths) do
    editor.setNodeWidth(road, index, oldWidth)
  end
end

local function setNodesWidthActionRedo(actionData)
  local road = scenetree.findObjectById(actionData.roadID)
  for index, _ in pairs(actionData.oldWidths) do
    editor.setNodeWidth(road, index, actionData.newWidth)
  end
end

-- Position Node
local function positionNodeActionUndo(actionData)
  local road = scenetree.findObjectById(actionData.roadID)
  editor.setNodePosition(road, actionData.nodeID, actionData.oldPosition)
end

local function positionNodeActionRedo(actionData)
  local road = scenetree.findObjectById(actionData.roadID)
  editor.setNodePosition(road, actionData.nodeID, actionData.newPosition)
end

local dragStartPosition
local function setNodePosition(road, nodeID, position, safeStartPos)
  if safeStartPos then
    dragStartPosition = dragStartPosition and dragStartPosition or road:getNodePosition(nodeID)
  end
  editor.setNodePosition(road, nodeID, position)
  editor.updateRoadVertices(road)
end

-- Insert Node
local function insertNodeActionUndo(actionData)
  local road = scenetree.findObjectById(actionData.roadID)
  -- Loop the nodes from back to front
  for i = #actionData.nodeInfos, 1, -1 do
    deleteNode(road, actionData.nodeInfos[i].index)
  end
end

local function insertNodeActionRedo(actionData)
  for _, nodeInfo in ipairs(actionData.nodeInfos) do
    editor.addRoadNode(actionData.roadID, nodeInfo)
  end
end

local function insertNode(road, position, width, index, withUndo)
  local nodeInfo = {pos = position, width = width, index = index}
  if withUndo then
    return editor.history:commitAction("InsertRoadNode", {roadID = road:getID(), nodeInfos = {nodeInfo}}, insertNodeActionUndo, insertNodeActionRedo)
  else
    return editor.addRoadNode(road:getID(), nodeInfo)
  end
end

-- Delete Node
local deleteNodeActionUndo = insertNodeActionRedo
local deleteNodeActionRedo = insertNodeActionUndo

-- Create Road
local function createRoadActionUndo(actionData)
  editor.deleteRoad(actionData.roadID)
  editor.clearObjectSelection()
end

local function createRoadActionRedo(actionData)
  if actionData.roadID then
    SimObject.setForcedId(actionData.roadID)
  end
  actionData.roadID = editor.createRoad(actionData.nodes, actionData.roadInfo)
  editor.selectObjectById(actionData.roadID)
end

-- Delete Road
local deleteRoadActionUndo = createRoadActionRedo
local deleteRoadActionRedo = createRoadActionUndo

-- Split Road
local function splitRoadActionUndo(actionData)
  local originalRoad = scenetree.findObjectById(actionData.originalRoadID)
  deleteNode(originalRoad, originalRoad:getNodeCount() - 1)
  local newRoad = scenetree.findObjectById(actionData.newRoadID)
  -- Loop through all the nodes
  for _, node in ipairs(editor.getNodes(newRoad)) do
    insertNode(originalRoad, node.pos, node.width, u_32_max_int)
  end
  editor.deleteRoad(actionData.newRoadID)
end

local function splitRoadActionRedo(actionData)
  local originalRoad = scenetree.findObjectById(actionData.originalRoadID)
  local newRoadNodes = {}

  -- Loop through all the nodes
  for id, node in ipairs(editor.getNodes(originalRoad)) do
    if (id - 1) == actionData.nodeID then
      table.insert(newRoadNodes, node)
    elseif (id - 1) > actionData.nodeID then
      table.insert(newRoadNodes, node)
      deleteNode(originalRoad, actionData.nodeID + 1)
    end
  end

  if actionData.newRoadID then
    SimObject.setForcedId(actionData.newRoadID)
  end
  actionData.newRoadID = editor.createRoad(newRoadNodes, editor.copyFields(originalRoad:getID()))
  return actionData.newRoadID
end

local function splitRoad(road, nodeID)
  if nodeID == 0 or nodeID == road:getNodeCount()- 1 then
    editor.logError("Can't split at the end of a road.")
    return
  end

  -- Split the road and return the id of the new road
  editor.history:commitAction("SplitRoad",
    {originalRoadID = road:getID(), newRoadID = newRoadID, nodeID = nodeID}, splitRoadActionUndo, splitRoadActionRedo)
end

local function setAsDefault(decalRoadId)
end

local function templateDialog()
  --TODO: convert to editor.beginWindow/endWindow
  if templateDialogOpen[0] then
    im.Begin("Templates", templateDialogOpen, 0)
      for i=1, #editor_roadUtils.getMaterials() do
        im.PushID1(string.format('template_%d', i))
        if im.ImageButton(editor_roadUtils.getMaterials()[i].texId, im.ImVec2(128, 128), im.ImVec2Zero, im.ImVec2One, 1, im.ImColorByRGB(0,0,0,255).Value, im.ImColorByRGB(255,255,255,255).Value) then
          templateDialogOpen[0] = false
          editor.setDynamicFieldValue(selectedRoadId, "template", editor_roadUtils.getRoadTemplateFiles()[i])
          editor_roadUtils.reloadTemplates()
        end
        if im.IsItemHovered() then
          im.BeginTooltip()
          im.PushTextWrapPos(im.GetFontSize() * 35.0)
          im.TextUnformatted(string.format("%d x %d", editor_roadUtils.getMaterials()[i].size.x, editor_roadUtils.getMaterials()[i].size.y ))
          im.TextUnformatted(string.format("%s", editor_roadUtils.getRoadTemplateFiles()[i] ))
          im.PopTextWrapPos()
          im.EndTooltip()
        end
        im.PopID()
        if i%4 ~= 0 then im.SameLine() end
      end
    im.End()
  end
end

local editingPos = false
local nodePosition = im.ArrayFloat(3)

local editingWidth = false
local nodeWidth = im.FloatPtr(0)

local widthSliderEditEnded = im.BoolPtr(false)

local function onEditorInspectorHeaderGui(inspectorInfo)
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end

  if selectedRoadId then
    local selectedRoad = scenetree.findObjectById(selectedRoadId)
    if selectedRoad then
      useTemplate[0] = (selectedRoad:getField("useTemplate", "") == "true")
      if roadTemplatesActive then
        im.SameLine()
        if im.Checkbox("Use Template", useTemplate) then
          editor.setDynamicFieldValue(selectedRoad:getID(), "useTemplate", tostring(useTemplate[0]))
        end
      end

      -- The button to open the template window with
      if useTemplate[0] then
        local materialName = selectedRoad:getField("Material", "")
        local matIndex = indexOf(editor_roadUtils.getMaterialNames(), materialName)
        local texID = 0
        if matIndex then
          if im.ImageButton(editor_roadUtils.getMaterials()[matIndex].texId, im.ImVec2(128, 128), im.ImVec2Zero, im.ImVec2One, 1, im.ImColorByRGB(0,0,0,255).Value, im.ImColorByRGB(255,255,255,255).Value) then
            templateDialogOpen[0] = true
          end
        else
          if im.Button("Change Template") then
            templateDialogOpen[0] = true
          end
        end
      end

      templateDialog()

      im.Text(string.format("Road Length: %0." .. editor.getPreference("ui.general.floatDigitCount") .. "f m", selectedRoad:getField("debugRoadLength", "")))

      -- Display node properties of selected node
      if (not tableIsEmpty(selectedNodes)) and selectedRoad:getNodeCount() > 0 then
        im.BeginChild1("node", im.ImVec2(0, 130), true)
        im.Text("Node Properties")

        local positionSliderEditEnded = im.BoolPtr(false)
        if selectedNode then

          -- Create the field for node position
          if not editingPos then
            local pos = selectedRoad:getNodePosition(selectedNode)
            nodePosition[0] = pos.x
            nodePosition[1] = pos.y
            nodePosition[2] = pos.z
          end

          if editor.uiDragFloat3("Node Position", nodePosition, 0.2, -1000000000, 100000000, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", 1, positionSliderEditEnded) then
            editingPos = true
          end
          if positionSliderEditEnded[0] then
            editor.history:commitAction("PositionRoadNode", {roadID = selectedRoadId, nodeID = selectedNode, oldPosition = selectedRoad:getNodePosition(selectedNode), newPosition = vec3(nodePosition[0], nodePosition[1], nodePosition[2])}, positionNodeActionUndo, positionNodeActionRedo)
            dragStartPosition = nil
            editingPos = false
          end
        end

        -- Create the field for node width
        if not editingWidth then
          if selectedNode then
            nodeWidth[0] = selectedRoad:getNodeWidth(selectedNode)
          else
            local displayedWidth
            for index,_ in pairs(selectedNodes) do
              local width = selectedRoad:getNodeWidth(index)
              if not displayedWidth then displayedWidth = width end
              if displayedWidth ~= width then
                displayedWidth = 0
                break
              end
            end
            nodeWidth[0] = displayedWidth
          end
        end
        widthSliderEditEnded[0] = false
        if editor.uiInputFloat("Node Width", nodeWidth, 0.1, 1.0, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", nil, widthSliderEditEnded) then
          editingWidth = true
        end

        if widthSliderEditEnded[0] then
          local oldWidths = {}
          for index,_ in pairs(selectedNodes) do
            oldWidths[index] = selectedRoad:getNodeWidth(index)
            setNodeWidth(selectedRoad, index, nodeWidth[0])
          end
          if not tableIsEmpty(oldWidths) then
            editor.history:commitAction("SetRoadNodesWidth", {roadID = selectedRoadId, oldWidths = oldWidths, newWidth = nodeWidth[0]}, setNodesWidthActionUndo, setNodesWidthActionRedo)
          end
          editingWidth = false
        end

        if positionSliderEditEnded[0] or widthSliderEditEnded[0] then
          editor_roadUtils.updateChildRoads(selectedRoad)
          editor_roadUtils.reloadDecorations(selectedRoad)
          editor_roadUtils.reloadDecals(selectedRoad)
        end

        if selectedNode then
          if im.Button("Split Road", im.ImVec2(0,0)) then
            splitRoad(selectedRoad, selectedNode)
          end
        end
        im.EndChild()
      end
    end
  end
end

local function showNodes(road)
  for index, node in ipairs(editor.getNodes(road)) do
    local pos = node.pos
    if editor.getPreference("roadEditor.general.dragWidth") and index - 1 == tempNodeIndex then
      if road:getNodeCount() == 1 then
        debugDrawer:drawSphere(pos, road:getNodeWidth(0)/2, roadRiverGui.highlightColors.nodeTransparent, false)
      end
      debugDrawer:drawTextAdvanced(pos, String("Road Width: " .. string.format("%.2f", road:getNodeWidth(tempNodeIndex)) .. ". Change width by dragging."), ColorF(1.0,1.0,1.0,1), true, false, ColorI(0, 0, 0, 128))
    end

    local sphereRadius = (getCameraPosition() - pos):length() * roadRiverGui.nodeSizeFactor
    if selectedNodes[(index - 1)] and road:getID() == selectedRoadId then
      debugDrawer:drawSphere(pos, sphereRadius, roadRiverGui.highlightColors.selectedNode, false)
    elseif hoveredNode == (index - 1) and road:getID() == hoveredRoadID then
      debugDrawer:drawSphere(pos, sphereRadius, roadRiverGui.highlightColors.hoveredNode, false)
    else
      debugDrawer:drawSphere(pos, sphereRadius, roadRiverGui.highlightColors.node, false)
    end
  end
end

local function showRoad(road, roadColor)
  local edgeCount = road:getEdgeCount()

  -- Loop through the points and draw the lines
  for index = 0, edgeCount - 1 do
    local currentLeftEdge = road:getLeftEdgePosition(index)
    local currentMiddleEdge = road:getMiddleEdgePosition(index)
    local currentRightEdge = road:getRightEdgePosition(index)

    debugDrawer:drawLine(currentLeftEdge, currentMiddleEdge, roadColor, false)
    debugDrawer:drawLine(currentMiddleEdge, currentRightEdge, roadColor, false)

    if index < edgeCount - 1 then
      debugDrawer:drawLine(currentLeftEdge, road:getLeftEdgePosition(index+1), roadColor, false)
      debugDrawer:drawLine(currentMiddleEdge, road:getMiddleEdgePosition(index+1), roadColor, false)
      debugDrawer:drawLine(currentRightEdge, road:getRightEdgePosition(index+1), roadColor, false)
    end
  end

  -- Only show nodes of selected road
  if selectedRoadId and road:getID() == selectedRoadId then
    local selectedRoad = scenetree.findObjectById(selectedRoadId)
    if selectedRoad then
      showNodes(selectedRoad)
    end
  end
end

local function finishRoad()
  local selectedRoad
  if selectedRoadId then
    selectedRoad = scenetree.findObjectById(selectedRoadId)
  end
  if selectedRoad and tempNodeIndex then
    deleteNode(selectedRoad, tempNodeIndex)
  end
  selectNode(nil)
  tempNodeIndex = nil
  mouseButtonHeldOnNode = false

  if selectedRoad and selectedRoad:getNodeCount() <= 1 then
    editor.deleteRoad(selectedRoadId)
    editor.clearObjectSelection()
  end
end

local function tempNodeIntersectsRoad(focusPoint)
  if not tempNodeIndex or not selectedRoadId then return false end
  local selectedRoad = scenetree.findObjectById(selectedRoadId)
  local intersectionIndex = selectedRoad:containsPoint(focusPoint)
  if intersectionIndex == -1 then return false end
  if tempNodeIndex == 0 then
    return intersectionIndex ~= 0
  else
    return intersectionIndex ~= (selectedRoad:getNodeCount() - 2)
  end
end


local function onUpdate()
  local rayCastHit
  if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end
  local rayCast = cameraMouseRayCast()
  if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end

  if rayCast then rayCastHit = rayCast.pos end
  local mousePos = im.GetMousePos()

  local mouseMoved = true
  if mousePos.x == lastMousePos.x and mousePos.y == lastMousePos.y then
    mouseMoved = false
  end
  lastMousePos = mousePos

  hoveredNode = nil
  hoveredRoadID = nil
  local camPos = getCameraPosition()

  if not selectedRoadId then
    templateDialogOpen[0] = false
    selectNode(nil)
  end

  local selectedRoad
  if selectedRoadId then
    selectedRoad = scenetree.findObjectById(selectedRoadId)
  end

  local checkNonselectedRoads = true
  local roadIsHovered = false
  if not editor.keyModifiers.alt and not mouseButtonHeldOnNode and not im.IsWindowHovered(im.HoveredFlags_AnyWindow) and not im.IsAnyItemHovered() then
    -- Check the selected road first
    if selectedRoad then
      -- Check if a node is hovered over
      local ray = getCameraMouseRay()
      local rayDir = ray.dir
      local minNodeDist = u_32_max_int
      for i, node in ipairs(editor.getNodes(selectedRoad)) do
        local distNodeToCam = (node.pos - camPos):length()
        if distNodeToCam < minNodeDist then
          local nodeRayDistance = (node.pos - camPos):cross(rayDir):length() / rayDir:length()
          local sphereRadius = (camPos - node.pos):length() * roadRiverGui.nodeSizeFactor
          if nodeRayDistance <= sphereRadius then
            hoveredNode = i - 1
            hoveredRoadID = selectedRoadId
            roadIsHovered = true
            checkNonselectedRoads = false
            minNodeDist = distNodeToCam
          end
        end
      end
    end
  end

  -- Mouse Cursor Handling
  if rayCastHit then
    local focusPoint = rayCastHit
    local focusPointP3F = focusPoint
    local cursorColor = roadRiverGui.highlightColors.cursor

    if editor.keyModifiers.alt then
      -- Hovers somewhere else than the selected road
      if selectedRoad and not tempNodeIndex and selectedRoad:containsPoint(focusPointP3F) ~= selectedNode then
        if selectedNode then
          if selectedNode == 0 and selectedRoad:getNodeCount() > 1 then
            -- Add Node at the beginning
            tempNodeIndex = insertNode(selectedRoad, focusPoint, selectedRoad:getNodeWidth(selectedNode), 0)
            selectNode(tempNodeIndex + 1)

          elseif selectedNode == selectedRoad:getNodeCount() - 1 then
            -- Add Node at the end
            tempNodeIndex = insertNode(selectedRoad, focusPoint, selectedRoad:getNodeWidth(selectedRoad:getNodeCount()-1), u_32_max_int)
            selectNode(tempNodeIndex - 1)
          end
        end
      end
      cursorColor = roadRiverGui.highlightColors.createModeCursor
    end

    -- Debug cursor
    --[[if not im.IsMouseDown(1) then
      debugDrawer:drawSphere(focusPoint, 0.5, cursorColor)
    end]]

    -- Highlight hovered road
    local hoveredRoadsIDsCopy = hoveredRoadsIDs
    hoveredRoadsIDs = {}
    if not editor.keyModifiers.alt and not mouseButtonHeldOnNode and not im.IsWindowHovered(im.HoveredFlags_AnyWindow) and not im.IsAnyItemHovered() then

      -- Check the selected road first
      if selectedRoad then
        if selectedRoad:containsPoint(focusPointP3F) ~= -1 then
          roadIsHovered = true
          checkNonselectedRoads = false
        end

        if roadIsHovered then
          table.insert(hoveredRoadsIDs, selectedRoadId)
        end
      end

      -- Then check the other roads
      if checkNonselectedRoads then
        local aiRoadsSelectable = editor.getPreference("roadEditor.general.aiRoadsSelectable")
        local nonAiRoadsSelectable = editor.getPreference("roadEditor.general.nonAiRoadsSelectable")
        for roadID, _ in pairs(editor.getAllRoads()) do
          local road = scenetree.findObjectById(roadID)
          if road and not road:isHidden() and (not selectedRoadId or roadID ~= selectedRoadId) then
            if (road.drivability > 0 and aiRoadsSelectable) or (road.drivability <= 0 and nonAiRoadsSelectable) then
              if road:containsPoint(focusPointP3F) ~= -1 then
                table.insert(hoveredRoadsIDs, roadID)
              end
            end
          end
        end
      end

      -- If the selected road is one of the hovered roads, always choose it
      local selectedRoadIndex = selectedRoadId and indexOf(hoveredRoadsIDs, selectedRoadId) or nil
      if selectedRoadIndex then
        hoveredRoadsIndex = selectedRoadIndex

      -- If the set of hovered roads has changed, use the last hovered road if possible, or else number 1
      elseif not setEqual(hoveredRoadsIDs, hoveredRoadsIDsCopy) then
        local oldIndex = indexOf(hoveredRoadsIDs, lastHoveredRoadID)
        if oldIndex then
          hoveredRoadsIndex = oldIndex
        else
          hoveredRoadsIndex = 1
        end
      end

      -- Set the hoveredRoad with the hoveredRoadsIndex
      hoveredRoadID = hoveredRoadsIDs[hoveredRoadsIndex]

      -- Color the hovered roads
      for _, roadID in ipairs(hoveredRoadsIDs) do
        if roadID == selectedRoadId then
          -- This gets colored later
          break
        elseif roadID == hoveredRoadID then
          local road = scenetree.findObjectById(roadID)
          if road then
            showRoad(road, Prefab.getPrefabByChild(road) and roadRiverGui.highlightColors.hoverSelectNotAllowed or roadRiverGui.highlightColors.hover)
          end
        else
          local road = scenetree.findObjectById(roadID)
          if road then
            showRoad(road, Prefab.getPrefabByChild(road) and roadRiverGui.highlightColors.lightHoverSelectNotAllowed or roadRiverGui.highlightColors.lightHover)
          end
        end
      end
    end

    if editor.keyModifiers.alt and not tempNodeIndex then
      if selectedRoad and selectedRoad:containsPoint(focusPointP3F) ~= -1 then
        debugDrawer:drawSphere(focusPointP3F, (camPos - focusPoint):length() / 40, roadRiverGui.highlightColors.node, false)
        debugDrawer:drawTextAdvanced(focusPointP3F, "Insert node here.", ColorF(1.0,1.0,1.0,1), true, false, ColorI(0, 0, 0, 128))
      else
        debugDrawer:drawSphere(focusPointP3F, editor.getPreference("roadEditor.general.defaultWidth") / 2, roadRiverGui.highlightColors.nodeTransparent, false)
        debugDrawer:drawTextAdvanced(focusPointP3F, String("Road Width: " .. string.format("%.2f", editor.getPreference("roadEditor.general.defaultWidth")) .. (editor.getPreference("roadEditor.general.dragWidth") and ". Change width by dragging." or "")), ColorF(1.0,1.0,1.0,1), true, false, ColorI(0, 0, 0, 128))
      end
    end

    -- Mouse button has been released
    if mouseButtonHeldOnNode and im.IsMouseReleased(0) then
      if editor.keyModifiers.alt then
        -- Add new node to selectedRoad
        selectNode(tempNodeIndex)
        tempNodeIndex = nil

        if selectedRoad:getNodeCount() > 2 then
          -- Undo action for placed node
          local nodeInfo = {pos = selectedRoad:getNodePosition(selectedNode), width = selectedRoad:getNodeWidth(selectedNode), index = selectedNode}
          editor.history:commitAction("InsertRoadNode", {roadID = selectedRoadId, nodeInfos = {nodeInfo}}, insertNodeActionUndo, insertNodeActionRedo, true)
        elseif selectedRoad:getNodeCount() == 2 then
          -- Undo whole road for 2 nodes
          local roadInfo = {nodes = editor.getNodes(selectedRoad), roadInfo = editor.copyFields(selectedRoadId), roadID = selectedRoadId}
          editor.history:commitAction("CreateRoad", roadInfo, createRoadActionUndo, createRoadActionRedo, true)
          editor.selectObjectById(roadInfo.roadID)
          selectedRoad = scenetree.findObjectById(roadInfo.roadID)
        end
        editor.setPreference("roadEditor.general.defaultWidth", selectedRoad:getNodeWidth(selectedNode))

      elseif (not dragMouseStartPos) and selectedNode then
        editor.history:commitAction("PositionRoadNode", {roadID = selectedRoadId, nodeID = selectedNode, oldPosition = dragStartPosition, newPosition = selectedRoad:getNodePosition(selectedNode)}, positionNodeActionUndo, positionNodeActionRedo)
        if roadTemplatesActive and selectedRoad then
          editor_roadUtils.updateChildRoads(selectedRoad)
          editor_roadUtils.reloadDecorations(selectedRoad)
          editor_roadUtils.reloadDecals(selectedRoad)
        end
      end

      mouseButtonHeldOnNode = false
      dragMouseStartPos = nil
      dragStartPosition = nil
    end

    -- The mouse button is down
    if mouseButtonHeldOnNode and im.IsMouseDown(0) and mouseMoved then
      local cursorPosImVec = im.GetMousePos()
      local cursorPos = vec3(cursorPosImVec.x, cursorPosImVec.y, 0)

      -- Set the width of the node by dragging
      if editor.keyModifiers.alt then
        if editor.getPreference("roadEditor.general.dragWidth") then
          local width = math.max(oldNodeWidth + (cursorPos.x - dragMouseStartPos.x) / 10.0, 0)
          setNodeWidth(selectedRoad, tempNodeIndex, width)
        end

      -- Put the grabbed node on the position of the cursor
      else
        if not selectedNode then
          mouseButtonHeldOnNode = false
          dragMouseStartPos = nil
          dragStartPosition = nil
        -- Dont move the node if it is close enough to the old position
        elseif not (dragMouseStartPos and (dragMouseStartPos - cursorPos):length() <= 5) then
          setNodePosition(selectedRoad, selectedNode, focusPoint, true)
          dragMouseStartPos = nil
        end
      end
    end

    -- Create temporary node to show where the next one will be
    if editor.keyModifiers.alt and tempNodeIndex and not mouseButtonHeldOnNode and mouseMoved then
      setNodePosition(selectedRoad, tempNodeIndex, focusPoint)
    end

    -- Mouse click on map
    if im.IsMouseClicked(0) and not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow)) then
      if editor.keyModifiers.alt then
        -- Clicked while in create mode
        local startNewRoad = true

        if selectedRoad then
          local nodeIdx = selectedRoad:containsPoint(focusPoint)

          -- Clicked into the selected road next to the selected node
          if nodeIdx ~= -1 and not tempNodeIndex then

            -- Interpolate width of two adjacent nodes
            local w0 = selectedRoad:getNodeWidth(nodeIdx)
            local w1 = selectedRoad:getNodeWidth(nodeIdx + 1)
            local avgWidth = (w0 + w1) * 0.5

            insertNode(selectedRoad, focusPoint, avgWidth, nodeIdx + 1, true)
            selectNode(nodeIdx + 1)
            startNewRoad = false

          elseif tempNodeIndex then
            -- Clicked outside of the selected road
            mouseButtonHeldOnNode = true
            oldNodeWidth = selectedRoad:getNodeWidth(tempNodeIndex)
          end
        end

        if startNewRoad then
          -- Create new road
          if not tempNodeIndex then
            -- Create new road
            local newRoadID = editor.createRoad({{pos = focusPoint, width = editor.getPreference("roadEditor.general.defaultWidth")}}, {})
            if fieldsCopy then
              editor.pasteFields(fieldsCopy, newRoadID)
            end
            editor.selectObjectById(newRoadID)
            selectedRoad = scenetree.findObjectById(newRoadID)
          end

          -- If the mouse button is held down, change the width of the created node
          mouseButtonHeldOnNode = true
          tempNodeIndex = tempNodeIndex and tempNodeIndex or 0
          oldNodeWidth = selectedRoad:getNodeWidth(tempNodeIndex)
        end
      end
    end

    if tempNodeIndex and (not editor.keyModifiers.alt) then
      finishRoad()
    end
  end

  if im.IsMouseClicked(0) and not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow) or editor_inspector.comboMenuOpen) then
    dragMouseStartPos = vec3(im.GetMousePos().x, im.GetMousePos().y, 0)
    if not editor.keyModifiers.alt then
      -- Clicked on a hovered road
      if hoveredRoadID and not tempNodeIndex then
        if not selectedRoadId or selectedRoadId ~= hoveredRoadID then
          local roadObj = scenetree.findObjectById(hoveredRoadID)
          if(not Prefab.getPrefabByChild(roadObj)) then
            -- Add road to selection
            editor.selectObjectById(hoveredRoadID)
            selectedRoad = roadObj
          else
            editor.openModalWindow(roadNotSelectableErrorWindowName)
          end
        end
        -- Check if a node was clicked
        selectNode(hoveredNode)
        if hoveredNode then
          mouseButtonHeldOnNode = true
        end
      elseif selectedRoadId then
        selectNode(nil)
        editor.clearObjectSelection()
      end
    end
  end

  -- Highlight selected roads
  if selectedRoadId and selectedRoad then
    showRoad(selectedRoad, roadRiverGui.highlightColors.selected)

    if selectedRoad.drivability > 0 then
      -- Draw an arrow representing the navgraph direction
      local edgeCount = selectedRoad:getEdgeCount()
      if edgeCount > 1 then
        local i1 = selectedRoad.flipDirection and edgeCount - 1 or 0
        local i2 = selectedRoad.flipDirection and edgeCount - 2 or 1
        local pos = selectedRoad:getMiddleEdgePosition(i1)
        local dir = (selectedRoad:getMiddleEdgePosition(i2) - pos):normalized()
        debugDrawer:drawSquarePrism(pos, pos + dir * 1.5, Point2F(0.5, 0.75), Point2F(0.5, 0), roadRiverGui.highlightColors.selectedNode)
      end
    end
  end
  lastHoveredRoadID = hoveredRoadID
end


local function onExtensionLoaded()
  log('D', logTag, "initialized")
end


local function onPreRender()
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end
end


local function onActivate()
  log('I', logTag, "onActivate")
  roadTemplatesActive = editor.getPreference("roadTemplates.general.loadTemplates")
  editor.initializeLevelRoadsVertices()
  M.onEditorObjectSelectionChanged()
end

local function onDeactivate()
  finishRoad()
end

-- These methods are for the action map to call
local function copySettingsAM()
  local selectedRoad
  if selectedRoadId then
    selectedRoad = scenetree.findObjectById(selectedRoadId)
  end

  if selectedRoad then
    fieldsCopy = editor.copyFields(selectedRoadId)
    local nodeWidthsTotal = 0
    for _, nodeInfo in ipairs(editor.getNodes(selectedRoad)) do
      nodeWidthsTotal = nodeWidthsTotal + nodeInfo.width
    end
    local averageNodeWidth = nodeWidthsTotal / tableSize(editor.getNodes(selectedRoad))
    editor.setPreference("roadEditor.general.defaultWidth", averageNodeWidth)
  end
end

local function onDeleteSelection()
  local selectedRoad
  if selectedRoadId then
    selectedRoad = scenetree.findObjectById(selectedRoadId)
  end

  if selectedRoad then
    if (not tableIsEmpty(selectedNodes)) and selectedRoad:getNodeCount() > 2 then
      local nodeInfos = {}
      for id, nodeInfo in ipairs(editor.getNodes(selectedRoad)) do
        if selectedNodes[id-1] then
          nodeInfo.index = id-1
          table.insert(nodeInfos, nodeInfo)
        end
      end
      editor.history:commitAction("DeleteRoadNode", {roadID = selectedRoadId, nodeInfos = nodeInfos}, deleteNodeActionUndo, deleteNodeActionRedo)
    else
      editor.history:commitAction("DeleteRoad", {nodes = editor.getNodes(selectedRoad), roadInfo = editor.copyFields(selectedRoadId), roadID = selectedRoadId}, deleteRoadActionUndo, deleteRoadActionRedo)
    end
    selectNode(nil)
  end
end

local function cycleHoveredRoadsAM(value)
  local numberOfHoveredRoads = table.getn(hoveredRoadsIDs)
  if numberOfHoveredRoads == 0 then return end
  if value == 1 then
    hoveredRoadsIndex = ((hoveredRoadsIndex % numberOfHoveredRoads) + 1)
  elseif value == 0 then
    hoveredRoadsIndex = (((hoveredRoadsIndex - 2) % numberOfHoveredRoads) + 1)
  end
end

local function defaultWidthSlider()
  local defaultWidthPtr = im.FloatPtr(editor.getPreference("roadEditor.general.defaultWidth"))
  if im.InputFloat("##Default Width", defaultWidthPtr, 0.1, 0.5, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f") then
    editor.setPreference("roadEditor.general.defaultWidth", defaultWidthPtr[0])
  end
end

local function onToolbar()
  im.Text("Default Width")
  im.SameLine()
  im.PushItemWidth(im.uiscale[0] * 130)
  defaultWidthSlider()

  im.SameLine()
  local aiRoadsPtr = im.BoolPtr(editor.getPreference("roadEditor.general.aiRoadsSelectable"))
  if im.Checkbox("AI roads selectable", aiRoadsPtr) then
    editor.setPreference("roadEditor.general.aiRoadsSelectable", aiRoadsPtr[0])
  end
  im.tooltip("Make roads that are used by AI hoverable and clickable")

  im.SameLine()
  local nonAiRoadsPtr = im.BoolPtr(editor.getPreference("roadEditor.general.nonAiRoadsSelectable"))
  if im.Checkbox("non-AI roads selectable", nonAiRoadsPtr) then
    editor.setPreference("roadEditor.general.nonAiRoadsSelectable", nonAiRoadsPtr[0])
  end
  im.tooltip("Make roads that are not used by AI hoverable and clickable")

  if editor.beginModalWindow(roadNotSelectableErrorWindowName, roadNotSelectableErrorWindowTitle, im.WindowFlags_AlwaysAutoResize + im.WindowFlags_NoScrollbar) then
    im.Text("Cannot select Road!")
    im.TextColored(im.ImVec4(1, 1, 0, 1), "Select and edit not allowed when road is inside packed prefab!")
    if im.Button("OK") then
      editor.closeModalWindow(roadNotSelectableErrorWindowName)
    end
  end
  editor.endModalWindow()
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("roadEditor")
  prefsRegistry:registerSubCategory("roadEditor", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {defaultWidth = {"float", 10}},
    {dragWidth = {"bool", false, "Change the width of newly placed nodes by clicking and dragging the mouse cursor."}},
    {aiRoadsSelectable = {"bool", true, "Controls whether ai roads should be selectable in the decal road editor"}},
    {nonAiRoadsSelectable = {"bool", true, "Controls whether non-ai roads should be selectable in the decal road editor"}},
    -- hidden
    {columnSizes = {"table", {29, 53, 300, 145, 97, 280}, "", nil, nil, nil, true}}
  })
end

local function onDuplicate()
  if not editor.isViewportFocused() then return end
  local selectedRoad
  if selectedRoadId then
    selectedRoad = scenetree.findObjectById(selectedRoadId)
  end
  if selectedRoad then
    editor.history:commitAction("CreateRoad", {nodes = editor.getNodes(selectedRoad), roadInfo = editor.copyFields(selectedRoadId)}, createRoadActionUndo, createRoadActionRedo)
  end
end

local function onEditorObjectSelectionChanged()
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end
  local newSelectedRoad = editor.findFirstSelectedByType("DecalRoad")
  if tempNodeIndex and selectedRoadId and (not newSelectedRoad or (selectedRoadId ~= newSelectedRoad:getID())) then
    finishRoad()
  end
  selectedRoadId = newSelectedRoad and newSelectedRoad:getID()
end

local function customDecalRoadMaterialsFilter(materialSet)
  local retSet = {}
  for i = 0, materialSet:size() - 1 do
    local material = materialSet:at(i)
    for tagId = 0, 2 do
      local tag = material:getField("materialTag", tostring(tagId))
      if string.lower(tag) == string.lower(roadMaterialTagString) then
        table.insert(retSet, material)
      end
    end
  end
  return retSet
end

local function onEditorInitialized()
  editor.editModes.roadEditMode =
  {
    displayName = editModeName,
    onActivate = onActivate,
    onDeactivate = onDeactivate,
    onDeleteSelection = onDeleteSelection,
    onUpdate = onUpdate,
    onToolbar = onToolbar,
    actionMap = actionMapName,
    onCopy = copySettingsAM,
    onPaste = pasteFieldsAM,
    onDuplicate = onDuplicate,
    onSelectAll = onSelectAll,
    icon = editor.icons.create_road_decal,
    iconTooltip = "Decal Road Editor",
    auxShortcuts = {},
    hideObjectIcons = true
  }

  editor.editModes.roadEditMode.auxShortcuts[bit.bor(editor.AuxControl_LMB, editor.AuxControl_Alt)] = "Create road / Add node"
  editor.editModes.roadEditMode.auxShortcuts[editor.AuxControl_Copy] = "Copy road properties"
  editor.editModes.roadEditMode.auxShortcuts[editor.AuxControl_Paste] = "Paste road properties"
  editor.editModes.roadEditMode.auxShortcuts[editor.AuxControl_Duplicate] = "Duplicate road"

  editor.registerCustomFieldInspectorFilter("DecalRoad", "Material", customDecalRoadMaterialsFilter)
  editor.registerModalWindow(roadNotSelectableErrorWindowName, im.ImVec2(600, 400))

  editor_roadUtils.reloadTemplates()
end

M.onPreRender = onPreRender
M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded
M.onEditorInspectorHeaderGui = onEditorInspectorHeaderGui
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorObjectSelectionChanged = onEditorObjectSelectionChanged

M.cycleHoveredRoadsAM = cycleHoveredRoadsAM

return M