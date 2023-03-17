-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local roadRiverGui = extensions.editor_roadRiverGui
local im = ui_imgui
local editModeName

local u_32_max_int = 4294967295
local upVector = vec3(0,0,1)
local whiteF = ColorF(1.0,1.0,1.0,1.0)
local blackI = ColorI(0, 0, 0, 128)
local renderDistance = 200
local renderDistanceClose = 50

local selectedNode = nil
local lastSelectedNode = nil
local hoveredNode = nil
local hoveredMeshID = nil
local selectedMeshId = nil

local selectedNodes = {}

local tempNodeIndex = nil

local mouseButtonHeldOnNode = false
local oldNodeWidth = nil

-- Params for setting width of node by dragging the mouse after creating it
local cursorOldPosition2D = im.ImVec2(0,0)

local fieldsCopy = nil

local nodeTransform = MatrixF(true)

local heightOffset

local originalWidths
local originalDepths
local originalNormals
local originalPositions
local originalGizmoPos

local function selectNodesRange(first, last)
  selectedNodes = {}
  for i = first, last do
    selectedNodes[i] = true
  end
end

local function onSelectAll()
  if selectedMeshId then
    local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
    if selectedMesh then
      selectNodesRange(0, selectedMesh:getNodeCount()-1)
    end
  end
end

local function updateGizmoPos()
  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
  if selectedMesh and selectedMesh:getNodeCount() > 0 then
    if selectedNode then
      -- One selected node
      if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
        nodeTransform = selectedMesh:getNodeTransform(selectedNode)
      else
        nodeTransform:setPosition(selectedMesh:getNodePosition(selectedNode))
      end
    elseif tableSize(selectedNodes) > 1 then
      -- Multiple selected nodes
      local averagePos = vec3(0,0,0)
      for index,_ in pairs(selectedNodes) do
        averagePos = averagePos + selectedMesh:getNodePosition(index)
      end
      averagePos = averagePos / tableSize(selectedNodes)
      nodeTransform:setPosition(averagePos)
    end

    editor.setAxisGizmoTransform(nodeTransform)
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
  updateGizmoPos()
end

-- Paste Fields
local function pasteActionUndo(actionData)
  editor.pasteFields(actionData.oldFields, actionData.meshID)
end

local function pasteActionRedo(actionData)
  editor.pasteFields(actionData.newFields, actionData.meshID)
end

local function pasteFieldsAM()
  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
  if selectedMesh and fieldsCopy then
    editor.history:commitAction("PasteMeshFields", {oldFields = editor.copyFields(selectedMeshId), newFields = deepcopy(fieldsCopy), meshID = selectedMeshId}, pasteActionUndo, pasteActionRedo)
  end
end


-- Set all Nodes Width
local function setAllNodesWidthActionUndo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for index, oldWidth in pairs(actionData.oldWidths) do
    editor.setNodeWidth(mesh, index, oldWidth)
  end
end

local function setAllNodesWidthActionRedo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for index, _ in pairs(actionData.oldWidths) do
    editor.setNodeWidth(mesh, index, actionData.newWidth)
  end
end


-- Set all Nodes Depth
local function setAllNodesDepthActionUndo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for index, oldDepth in pairs(actionData.oldDepths) do
    editor.setNodeDepth(mesh, index, oldDepth)
  end
end

local function setAllNodesDepthActionRedo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for index, _ in pairs(actionData.oldDepths) do
    editor.setNodeDepth(mesh, index, actionData.newDepth)
  end
end


-- Set Node Width/Depth
local function setNodeWidthDepthActionUndo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for _, nodeID in ipairs(actionData.nodeIDs) do
    editor.setNodeWidth(mesh, nodeID, actionData.oldWidths[nodeID])
    editor.setNodeDepth(mesh, nodeID, actionData.oldDepths[nodeID])
  end
end

local function setNodeWidthDepthActionRedo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for _, nodeID in ipairs(actionData.nodeIDs) do
    editor.setNodeWidth(mesh, nodeID, actionData.newWidths[nodeID])
    editor.setNodeDepth(mesh, nodeID, actionData.newDepths[nodeID])
  end
end


-- Position Node
local function positionNodeActionUndo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for _, nodeID in ipairs(actionData.nodeIDs) do
    editor.setNodePosition(mesh, nodeID, actionData.oldPositions[nodeID])
  end
  if editor.editMode and (editor.editMode.displayName == editModeName) then
    updateGizmoPos()
  end
end

local function positionNodeActionRedo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for _, nodeID in ipairs(actionData.nodeIDs) do
    editor.setNodePosition(mesh, nodeID, actionData.newPositions[nodeID])
  end
  if editor.editMode and (editor.editMode.displayName == editModeName) then
    updateGizmoPos()
  end
end


-- Rotate Node
local function rotateNodeActionUndo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for _, nodeID in ipairs(actionData.nodeIDs) do
    mesh:setNodeNormal(nodeID, actionData.oldNormals[nodeID])
    editor.setNodePosition(mesh, nodeID, actionData.oldPositions[nodeID])
  end
end

local function rotateNodeActionRedo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for _, nodeID in ipairs(actionData.nodeIDs) do
    mesh:setNodeNormal(nodeID, actionData.newNormals[nodeID])
    editor.setNodePosition(mesh, nodeID, actionData.newPositions[nodeID])
  end
end


-- Insert Node
local function insertNodeActionUndo(actionData)
  local mesh = scenetree.findObjectById(actionData.meshID)
  for index = #actionData.nodeInfos, 1, -1 do
    editor.deleteMeshNode(mesh, actionData.nodeInfos[index].index)
  end
end

local function insertNodeActionRedo(actionData)
  local firstID
  for _, nodeInfo in ipairs(actionData.nodeInfos) do
    local id = editor.addMeshNode(actionData.meshID, nodeInfo)
    firstID = firstID or id
  end
  return firstID
end

local function insertNode(mesh, position, width, depth, normal, index)
  local nodeInfo = {pos = position, width = width, depth = depth, normal = normal, index = index}
  return editor.addMeshNode(mesh:getID(), nodeInfo)
end

-- Delete Node
local deleteNodeActionUndo = insertNodeActionRedo
local deleteNodeActionRedo = insertNodeActionUndo


-- Create Mesh
local function createMeshActionUndo(actionData)
  editor.deleteMesh(actionData.meshID)
end

local function createMeshActionRedo(actionData)
  SimObject.setForcedId(actionData.meshID)
  editor.createMesh(M.type, actionData.nodes, actionData.meshInfo)
  editor.selectObjectById(actionData.meshID)
end

-- Delete Mesh
local deleteMeshActionUndo = createMeshActionRedo
local deleteMeshActionRedo = createMeshActionUndo

local function onDeleteSelection()
  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
  if selectedMesh then
    if (not tableIsEmpty(selectedNodes)) and selectedMesh:getNodeCount() > 2 then
      local nodeInfos = {}
      for id, nodeInfo in ipairs(editor.getNodes(selectedMesh)) do
        if selectedNodes[id-1] then
          nodeInfo.index = id-1
          table.insert(nodeInfos, nodeInfo)
        end
      end
      editor.history:commitAction("DeleteMeshNode", {meshID = selectedMeshId, nodeInfos = nodeInfos}, deleteNodeActionUndo, deleteNodeActionRedo)
    else
      editor.history:commitAction("DeleteMesh", {nodes = editor.getNodes(selectedMesh), meshInfo = editor.copyFields(selectedMeshId), meshID = selectedMeshId}, deleteMeshActionUndo, deleteMeshActionRedo)
    end
    selectNode(nil)
  end
end

-- Split Mesh
local function splitMeshActionUndo(actionData)
  local originalMesh = scenetree.findObjectById(actionData.originalMeshID)
  editor.deleteMeshNode(originalMesh, originalMesh:getNodeCount() - 1)

  local newMesh = scenetree.findObjectById(actionData.newMeshID)
  local nodes = editor.getNodes(newMesh)

  -- Loop through all the nodes
  for id, node in ipairs(nodes) do
    insertNode(originalMesh, node.pos, node.width, node.depth, node.normal, u_32_max_int)
  end

  editor.deleteMesh(actionData.newMeshID)
end

local function splitMeshActionRedo(actionData)
  local originalMesh = scenetree.findObjectById(actionData.originalMeshID)
  local newMeshNodes = {}
  local nodes = editor.getNodes(originalMesh)

  -- Loop through all the nodes
  for id, node in ipairs(nodes) do
    if (id - 1) == actionData.nodeID then
      table.insert(newMeshNodes, node)
    elseif (id - 1) > actionData.nodeID then
      table.insert(newMeshNodes, node)
      editor.deleteMeshNode(originalMesh, actionData.nodeID + 1)
    end
  end

  if actionData.newMeshID then
    SimObject.setForcedId(actionData.newMeshID)
  end
  actionData.newMeshID = editor.createMesh(M.type, newMeshNodes, editor.copyFields(originalMesh:getID()))
  return actionData.newMeshID
end

local function splitMesh(mesh, nodeID)
  local nodes = editor.getNodes(mesh)

  if nodeID == 0 or nodeID == table.getn(nodes) - 1 then
    editor.logError("Can't split at the end of a mesh.")
    return
  end

  editor.history:commitAction("SplitMesh", {originalMeshID = mesh:getID(), nodeID = nodeID}, splitMeshActionUndo, splitMeshActionRedo)
end


local editingPos = false
local nodePosition = im.ArrayFloat(3)

local editingWidth = false
local nodeWidth = im.FloatPtr(0)

local editingDepth = false
local nodeDepth = im.FloatPtr(0)

local nodeHeightRelative = im.FloatPtr(0)

local positionSliderEditEnded = im.BoolPtr(false)
local widthSliderEditEnded = im.BoolPtr(false)
local depthSliderEditEnded = im.BoolPtr(false)
local heightSliderEditEnded = im.BoolPtr(false)

local function onEditorInspectorHeaderGui(inspectorInfo)
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end
  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
  if selectedMesh and (not tableIsEmpty(selectedNodes)) and selectedMesh:getNodeCount() > 0 then
    im.BeginChild1("node", im.ImVec2(0, 150), true)
    im.Text("Node Properties")

    if selectedNode then
      -- Create the field for node position
      if not editingPos then
        local pos = selectedMesh:getNodePosition(selectedNode)
        nodePosition[0] = pos.x
        nodePosition[1] = pos.y
        nodePosition[2] = pos.z
      end

      if editor.uiDragFloat3("Node Position", nodePosition, 0.2, -1000000000, 100000000, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", 1, positionSliderEditEnded) then
        editingPos = true
      end
      if positionSliderEditEnded[0] then
        editor.history:commitAction("PositionMeshNode", {meshID = selectedMeshId, nodeIDs = {selectedNode}, oldPositions = {[selectedNode] = selectedMesh:getNodePosition(selectedNode)}, newPositions = {[selectedNode] = vec3(nodePosition[0], nodePosition[1], nodePosition[2])}}, positionNodeActionUndo, positionNodeActionRedo)
        editingPos = false
      end
    end

    -- Create the field for node width
    if not editingWidth then
      if selectedNode then
        nodeWidth[0] = selectedMesh:getNodeWidth(selectedNode)
      else
        local displayedWidth
        for index,_ in pairs(selectedNodes) do
          local width = selectedMesh:getNodeWidth(index)
          if not displayedWidth then displayedWidth = width end
          if displayedWidth ~= width then
            displayedWidth = 0
            break
          end
        end
        nodeWidth[0] = displayedWidth
      end
    end

    if editor.uiInputFloat("Node Width", nodeWidth, 0.1, 1.0, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", nil, widthSliderEditEnded) then
      editingWidth = true
    end
    if widthSliderEditEnded[0] then
      local oldWidths = {}
      for index,_ in pairs(selectedNodes) do
        oldWidths[index] = selectedMesh:getNodeWidth(index)
        editor.setNodeWidth(selectedMesh, index, nodeWidth[0])
      end
      if not tableIsEmpty(oldWidths) then
        editor.history:commitAction("SetAllMeshNodesWidth", {meshID = selectedMeshId, oldWidths = oldWidths, newWidth = nodeWidth[0]}, setAllNodesWidthActionUndo, setAllNodesWidthActionRedo)
      end
      editingWidth = false
    end

    -- Create the field for node depth
    if not editingDepth then
      if selectedNode then
        nodeDepth[0] = selectedMesh:getNodeDepth(selectedNode)
      else
        local displayedDepth
        for index,_ in pairs(selectedNodes) do
          local depth = selectedMesh:getNodeDepth(index)
          if not displayedDepth then displayedDepth = depth end
          if displayedDepth ~= depth then
            displayedDepth = 0
            break
          end
        end
        nodeDepth[0] = displayedDepth
      end
    end

    if editor.uiInputFloat("Node Depth", nodeDepth, 0.1, 1.0, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", nil, depthSliderEditEnded) then
      editingDepth = true
    end
    if depthSliderEditEnded[0] then
      local oldDepths = {}
      for index,_ in pairs(selectedNodes) do
        oldDepths[index] = selectedMesh:getNodeDepth(index)
        editor.setNodeDepth(selectedMesh, index, nodeDepth[0])
      end
      if not tableIsEmpty(oldDepths) then
        editor.history:commitAction("SetAllMeshNodesDepth", {meshID = selectedMeshId, oldDepths = oldDepths, newDepth = nodeDepth[0]}, setAllNodesDepthActionUndo, setAllNodesDepthActionRedo)
      end
      editingDepth = false
    end

    if M.type == "River" and selectedNode and selectedNode > 0 then
      local selectedNodePos = selectedMesh:getNodePosition(selectedNode)
      local prevNodeHeight = selectedMesh:getNodePosition(selectedNode-1).z
      nodeHeightRelative[0] = selectedNodePos.z - prevNodeHeight
      editor.uiInputFloat("Node Height Relative", nodeHeightRelative, 0.1, 1.0, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", nil, heightSliderEditEnded)

      if heightSliderEditEnded[0] then
        editor.history:commitAction("PositionMeshNode", {meshID = selectedMeshId, nodeIDs = {selectedNode}, oldPositions = {[selectedNode] = selectedNodePos}, newPositions = {[selectedNode] = vec3(selectedNodePos.x, selectedNodePos.y, prevNodeHeight + nodeHeightRelative[0])}}, positionNodeActionUndo, positionNodeActionRedo)
      end
    end

    if selectedNode then
      if im.Button("Split " .. M.niceName, im.ImVec2(0,0)) then
        splitMesh(selectedMesh, selectedNode)
      end
    end
    im.EndChild()
  end
end

local addedNewNode = false
local function gizmoBeginDrag()
  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_World then
    nodeTransform = MatrixF(true)
  end

  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
  if selectedMesh and editor.keyModifiers.shift and tableSize(selectedNodes) == 1 and selectedNode and (selectedNode == 0 or selectedNode == selectedMesh:getNodeCount() - 1) then
    local nodeInfo = editor.getNodes(selectedMesh)[selectedNode + 1]
    local newNodeIndex = 1
    if selectedNode == selectedMesh:getNodeCount() - 1 then
      newNodeIndex = u_32_max_int
      selectedNodes = {}
      selectedNodes[selectedMesh:getNodeCount()] = true
      selectedNode = selectedMesh:getNodeCount()
    end
    nodeInfo.index = newNodeIndex
    editor.addMeshNode(selectedMeshId, nodeInfo)
    addedNewNode = true
  end

  originalGizmoPos = editor.getAxisGizmoTransform():getColumn(3)
  originalWidths = {}
  originalDepths = {}
  originalNormals = {}
  originalPositions = {}
  if selectedMesh then
    for id, _ in pairs(selectedNodes) do
      originalWidths[id] = selectedMesh:getNodeWidth(id)
      originalDepths[id] = selectedMesh:getNodeDepth(id)
      originalNormals[id] = selectedMesh:getNodeNormal(id)
      originalPositions[id] = selectedMesh:getNodePosition(id)
    end
  end
end

local function rotateAround(mesh, nodeID, euler, rotationPoint)
  local rot = quatFromEuler(euler.x, euler.y, euler.z)

  -- Rotate the decals
  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local and tableSize(selectedInstances) == 1 then
    local gizmoTransform = editor.getAxisGizmoTransform()
    local rotation = gizmoTransform:toQuatF()
    mesh:setNodeNormal(nodeID, quat(rotation):__mul(upVector))
  else
    local gizmoRot = rot
    local newNormal = gizmoRot:__mul(originalNormals[nodeID])
    mesh:setNodeNormal(nodeID, newNormal)
  end

  -- Rotate the positions
  local point = originalPositions[nodeID]
  point = point - rotationPoint
  point = rot * point
  point = point + rotationPoint
  editor.setNodePosition(mesh, nodeID, point)
end

local origin = vec3(0,0,0)
local function gizmoDragging()
  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
  if not selectedMesh then return end
  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    for id, _ in pairs(selectedNodes) do
      local position = originalPositions[id] + (editor.getAxisGizmoTransform():getColumn(3) - originalGizmoPos)
      editor.setNodePosition(selectedMesh, id, position)
    end

  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    local euler = editor.getAxisGizmoTransform():toQuatF():toEuler()
    for id, _ in pairs(selectedNodes) do
      rotateAround(selectedMesh, id, euler, editor.getAxisGizmoTransform():getColumn(3))
    end

  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
    for id, _ in pairs(selectedNodes) do
      editor.setNodeWidth(selectedMesh, id, originalWidths[id] + (editor.getAxisGizmoScale().x - 1))
      editor.setNodeDepth(selectedMesh, id, originalDepths[id] + (editor.getAxisGizmoScale().z - 1))
    end
  end
end

local function gizmoEndDrag()
  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
  if selectedMesh then
    local nodeIDs = {}
    local newPositions = {}
    local newNormals = {}
    local newWidths = {}
    local newDepths = {}
    for id, _ in pairs(selectedNodes) do
      table.insert(nodeIDs, id)
      newPositions[id] = selectedMesh:getNodePosition(id)
      newNormals[id] = selectedMesh:getNodeNormal(id)
      newWidths[id] = selectedMesh:getNodeWidth(id)
      newDepths[id] = selectedMesh:getNodeDepth(id)
    end
    if addedNewNode then
      local nodeInfo = {pos = selectedMesh:getNodePosition(selectedNode), width = selectedMesh:getNodeWidth(selectedNode), depth = selectedMesh:getNodeDepth(selectedNode), normal = selectedMesh:getNodeNormal(selectedNode), index = selectedNode}
      editor.history:commitAction("InsertMeshNode", {meshID = selectedMeshId, nodeInfos = {nodeInfo}}, insertNodeActionUndo, insertNodeActionRedo, true)
      addedNewNode = false
    elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
      editor.history:commitAction("PositionMeshNode", {meshID = selectedMeshId, nodeIDs = nodeIDs, oldPositions = originalPositions, newPositions = newPositions}, positionNodeActionUndo, positionNodeActionRedo)
    elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
      editor.history:commitAction("RotateMeshNode", {meshID = selectedMeshId, nodeIDs = nodeIDs, oldNormals = originalNormals, newNormals = newNormals, oldPositions = originalPositions, newPositions = newPositions}, rotateNodeActionUndo, rotateNodeActionRedo)
    elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
      editor.history:commitAction("SetMeshNodeWidthDepth", {meshID = selectedMeshId, nodeIDs = nodeIDs, oldWidths = originalWidths, oldDepths = originalDepths, newWidths = newWidths, newDepths = newDepths}, setNodeWidthDepthActionUndo, setNodeWidthDepthActionRedo)
    end
  end

  originalWidths = nil
  originalDepths = nil
  originalNormals = nil
  originalPositions = nil
  originalGizmoPos = nil
  updateGizmoPos()
end

local function showNodes(mesh)
  local nodes = editor.getNodes(mesh)
  local camPos = getCameraPosition()

  for index, node in ipairs(nodes) do
    local pos = node.pos
    if editor.getPreference(M.preferencesName .. ".general.dragWidth") and index - 1 == tempNodeIndex then
      if mesh:getNodeCount() == 1 then
        debugDrawer:drawSphere(pos, mesh:getNodeWidth(0)/2, roadRiverGui.highlightColors.nodeTransparent,false)
      end
      debugDrawer:drawTextAdvanced(pos, String(M.niceName .. " Width: " .. string.format("%.2f", mesh:getNodeWidth(tempNodeIndex)) .. ". Change width by dragging."), whiteF, true, false, blackI)
    end

    local sphereRadius = (getCameraPosition() - pos):length() * roadRiverGui.nodeSizeFactor
    if selectedNodes[(index-1)] and mesh:getID() == selectedMeshId then
      editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoDragging)
      editor.drawAxisGizmo()
      debugDrawer:drawSphere(pos, sphereRadius, roadRiverGui.highlightColors.selectedNode,false)
    elseif hoveredNode == (index-1) and mesh:getID() == hoveredMeshID then
      debugDrawer:drawSphere(pos, sphereRadius, roadRiverGui.highlightColors.hoveredNode,false)
    else
      debugDrawer:drawSphere(pos, sphereRadius, roadRiverGui.highlightColors.node,false)
    end

    if M.type == "River" then
      if index < mesh:getNodeCount() then
        local nextNodePos = nodes[index + 1].pos
        local middlePos = (pos + nextNodePos) / 2
        debugDrawer:drawTextAdvanced(middlePos, String(string.format("%.2f m", nextNodePos.z - pos.z)), whiteF, true, false, blackI)

        if camPos:distance(middlePos) < renderDistance then
          local forward = (nextNodePos - middlePos):normalized()
          local p1 = middlePos + forward * 1
          local p2 = middlePos - forward * 1 + forward:cross(upVector) * 1
          local p3 = middlePos - forward * 1 - forward:cross(upVector) * 1
          debugDrawer:drawLine(p1, p2, roadRiverGui.highlightColors.selected, false)
          debugDrawer:drawLine(p2, p3, roadRiverGui.highlightColors.selected, false)
          debugDrawer:drawLine(p3, p1, roadRiverGui.highlightColors.selected, false)
        end
      end
    end
  end
end

local function toColorI(colorF)
  return ColorI(colorF.r * 255, colorF.g * 255, colorF.b * 255, colorF.a * 255)
end

local function showMesh(mesh, meshColor)
  -- Only show nodes of selected mesh
  if mesh:getID() == selectedMeshId then
    showNodes(mesh)
  end

  local camPos = getCameraPosition()
  local segmentLength = mesh.segmentLength or 10

  debugDrawer:setSolidTriCulling(false)
  for index = 0, mesh:getEdgeCount() - 1 do
    local topLeft1 = mesh:getTopLeftEdgePosition(index)
    local topMiddle1 = mesh:getTopMiddleEdgePosition(index)
    local topRight1 = mesh:getTopRightEdgePosition(index)
    local bottomLeft1 = mesh:getBottomLeftEdgePosition(index)
    local bottomRight1 = mesh:getBottomRightEdgePosition(index)
    local debugDrawDetail = 1
    local camDist = camPos:distance(topLeft1)
    if camDist < renderDistance then
      debugDrawDetail = 2
      if camDist < renderDistanceClose or segmentLength >= 10 then
        debugDrawDetail = 3
      end
    end

    if index < mesh:getEdgeCount() - 1 then
      -- Base lines
      debugDrawer:drawLine(topLeft1, mesh:getTopLeftEdgePosition(index+1), meshColor,false)
      debugDrawer:drawLine(topMiddle1, mesh:getTopMiddleEdgePosition(index+1), meshColor,false)
      debugDrawer:drawLine(topRight1, mesh:getTopRightEdgePosition(index+1), meshColor,false)

      if debugDrawDetail >= 2 and M.type == "River" then
        if debugDrawDetail == 3 or (index % round(10 / segmentLength)) == 0 then
          debugDrawer:drawLine(bottomLeft1, mesh:getBottomLeftEdgePosition(index+1), meshColor,false)
          debugDrawer:drawLine(bottomRight1, mesh:getBottomRightEdgePosition(index+1), meshColor,false)
        end
      end
    end

    if debugDrawDetail >= 2 then
      if debugDrawDetail == 3 or (index % round(10 / segmentLength)) == 0 then
        debugDrawer:drawLine(topLeft1, topRight1, meshColor,false)

        if M.type == "River" then
          debugDrawer:drawLine(topLeft1, bottomLeft1, meshColor,false)
          debugDrawer:drawLine(bottomLeft1, bottomRight1, meshColor,false)
          debugDrawer:drawLine(bottomRight1, topRight1, meshColor,false)
        end
      end
    end
  end
end

local function finishMesh()
  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)
  if selectedMesh then
    editor.deleteMeshNode(selectedMesh, tempNodeIndex)

    if tempNodeIndex == 0 and selectedNode then
      selectNode(selectedNode - 1)
    end
  end

  tempNodeIndex = nil
  mouseButtonHeldOnNode = false

  if selectedMesh and selectedMesh:getNodeCount() <= 1 then
    editor.deleteMesh(selectedMeshId)
    editor.clearObjectSelection()
  end
end

local function raycastHitMesh(rayCastInfo, mesh)
  if rayCastInfo then
    return rayCastInfo.object:getID() == mesh:getID()
  end
  return false
end

local function onUpdate()
  hoveredMeshID = nil
  hoveredNode = nil
  local camPos = getCameraPosition()

  local selectedMesh = selectedMeshId and scenetree.findObjectById(selectedMeshId)

  if not selectedMesh then
    selectNode(nil)
  end

  -- Mouse Cursor Handling
  if not editor.keyModifiers.alt and not mouseButtonHeldOnNode and not im.IsWindowHovered(im.HoveredFlags_AnyWindow) and not im.IsAnyItemHovered() then
    if selectedMesh then
      -- Check if a node is hovered over
      local ray = getCameraMouseRay()
      local rayDir = ray.dir
      local minNodeDist = u_32_max_int
      for i, node in ipairs(editor.getNodes(selectedMesh)) do
        local distNodeToCam = (node.pos - camPos):length()
        if distNodeToCam < minNodeDist then
          local nodeRayDistance = (node.pos - camPos):cross(rayDir):length() / rayDir:length()
          local sphereRadius = (camPos - node.pos):length() * roadRiverGui.nodeSizeFactor
          if nodeRayDistance <= sphereRadius then
            hoveredNode = i - 1
            hoveredMeshID = selectedMeshId
            minNodeDist = distNodeToCam
          end
        end
      end
    end
  end

  if selectedMesh then selectedMesh:disableCollision() end
  local rayCastNoMesh = cameraMouseRayCast(false)
  if selectedMesh then selectedMesh:enableCollision() end

  local meshRayCastRes
  if rayCastNoMesh and rayCastNoMesh.pos then
    local focusPointNoMesh = rayCastNoMesh.pos

    meshRayCastRes = cameraMouseRayCast(false)
    -- Check if water object is a mesh
    if meshRayCastRes and meshRayCastRes.object:getClassName() ~= M.type then
      meshRayCastRes = nil
    end
    local focusPointMesh = meshRayCastRes and meshRayCastRes.pos or nil
    local cursorColor = roadRiverGui.highlightColors.cursor

    if editor.keyModifiers.alt then
      -- Hovers somewhere else than the selected mesh
      if selectedMesh and not tempNodeIndex and not raycastHitMesh(meshRayCastRes, selectedMesh) then
        if selectedNode and selectedNode == 0 and selectedMesh:getNodeCount() > 1 then
          -- Add Node at the beginning
          tempNodeIndex = insertNode(selectedMesh, focusPointNoMesh, selectedMesh:getNodeWidth(selectedNode), selectedMesh:getNodeDepth(selectedNode), upVector, 0)
          selectNode(1)
        else
          tempNodeIndex = insertNode(selectedMesh, focusPointNoMesh, selectedMesh:getNodeWidth(selectedMesh:getNodeCount()-1), selectedMesh:getNodeDepth(selectedMesh:getNodeCount()-1), upVector, u_32_max_int)
        end
      end
      cursorColor = roadRiverGui.highlightColors.createModeCursor
    end

    -- Debug cursor
    --[[if not im.IsMouseDown(1) then
      debugDrawer:drawSphere(focusPoint, 0.5, cursorColor)
    end]]

    -- Highlight hovered mesh
    if not editor.keyModifiers.alt and not mouseButtonHeldOnNode and not im.IsWindowHovered(im.HoveredFlags_AnyWindow) and not im.IsAnyItemHovered() then
      -- Set the hoveredMesh
      if meshRayCastRes or hoveredNode then
        local hoveredMesh = hoveredNode and selectedMesh or meshRayCastRes.object
        hoveredMeshID = hoveredMesh:getID()
        if hoveredMesh:getID() ~= selectedMeshId then
          showMesh(hoveredMesh, roadRiverGui.highlightColors.hover)
        end
      end
    end

    if editor.keyModifiers.alt and not tempNodeIndex then
      if selectedMesh and focusPointMesh then
        debugDrawer:drawSphere(focusPointMesh, (camPos - focusPointMesh):length() / 40, roadRiverGui.highlightColors.node,false)
        debugDrawer:drawTextAdvanced(focusPointMesh, "Insert node here.", ColorF(1.0,1.0,1.0,1), true, false, blackI)
      else
        debugDrawer:drawSphere(focusPointNoMesh, editor.getPreference(M.preferencesName .. ".general.defaultWidth")/2, roadRiverGui.highlightColors.nodeTransparent, false)
        debugDrawer:drawTextAdvanced(focusPointNoMesh, String(M.niceName .. " Width: " .. string.format("%.2f", editor.getPreference(M.preferencesName .. ".general.defaultWidth")) .. (editor.getPreference(M.preferencesName .. ".general.dragWidth") and ". Change width by dragging." or "")), ColorF(1.0,1.0,1.0,1), true, false, blackI)
      end
    end

    -- Mouse button has been released
    if mouseButtonHeldOnNode and im.IsMouseReleased(0) then
      mouseButtonHeldOnNode = false
      cursorOldPosition2D = im.ImVec2(0,0)
      if editor.keyModifiers.alt then
        -- Add new node to selectedMesh
        selectNode(tempNodeIndex)
        tempNodeIndex = nil
        if selectedMesh then
          if selectedMesh:getNodeCount() > 2 then
            -- Undo action for placed node
            local nodeInfo = {pos = selectedMesh:getNodePosition(selectedNode), width = selectedMesh:getNodeWidth(selectedNode), depth = selectedMesh:getNodeDepth(selectedNode), normal = selectedMesh:getNodeNormal(selectedNode), index = selectedNode}
            editor.history:commitAction("InsertMeshNode", {meshID = selectedMeshId, nodeInfos = {nodeInfo}}, insertNodeActionUndo, insertNodeActionRedo, true)
          elseif selectedMesh:getNodeCount() == 2 then
            -- Undo whole mesh for 2 nodes
            local meshInfo = {nodes = editor.getNodes(selectedMesh), meshInfo = editor.copyFields(selectedMeshId), meshID = selectedMeshId}
            editor.history:commitAction("CreateMesh", meshInfo, createMeshActionUndo, createMeshActionRedo, true)
            editor.selectObjectById(meshInfo.meshID)
            selectedMesh = scenetree.findObjectById(meshInfo.meshID)
          end
        end
      end
    end

    -- The mouse button is down
    if mouseButtonHeldOnNode and im.IsMouseDown(0) then

      -- Set the width of the node by dragging
      if selectedMesh and editor.keyModifiers.alt and editor.getPreference(M.preferencesName .. ".general.dragWidth") then
        local cursorPos = im.GetMousePos()
        local width = math.max(oldNodeWidth + (cursorPos.x - cursorOldPosition2D.x) / 10.0, 0)
        editor.setNodeWidth(selectedMesh, tempNodeIndex, width)
      end
    end

    -- Mouse click on map
    if im.IsMouseClicked(0) and not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow)) then
      if editor.keyModifiers.alt then
      -- Clicked while in create mode
        if selectedMesh then
          local nodeIdx = selectedMesh:collideRay(getCameraPosition(), (focusPointNoMesh - getCameraPosition()))

          -- Clicked into the selected mesh
          if not tempNodeIndex and nodeIdx ~= -1 then
            -- Interpolate width of two adjacent nodes
            local w0 = selectedMesh:getNodeWidth(nodeIdx)
            local w1 = selectedMesh:getNodeWidth(nodeIdx + 1)
            local avgWidth = (w0 + w1) * 0.5

            -- Interpolate depth of two adjacent nodes
            local d0 = selectedMesh:getNodeDepth(nodeIdx)
            local d1 = selectedMesh:getNodeDepth(nodeIdx + 1)
            local avgDepth = (d0 + d1) * 0.5

            -- Interpolate normals of two adjacent nodes
            local n0 = selectedMesh:getNodeNormal(nodeIdx)
            local n1 = selectedMesh:getNodeNormal(nodeIdx + 1)
            local avgNormal = (n0 + n1)
            avgNormal:normalize()

            local nodeInfo = {pos = focusPointMesh, width = avgWidth, depth = avgDepth, normal = avgNormal, index = nodeIdx + 1}
            editor.history:commitAction("InsertMeshNode", {meshID = selectedMeshId, nodeInfos = {nodeInfo}}, insertNodeActionUndo, insertNodeActionRedo)
            selectNode(nodeIdx + 1)

          elseif tempNodeIndex then
            -- Clicked outside of the selected mesh
            mouseButtonHeldOnNode = true
            oldNodeWidth = selectedMesh:getNodeWidth(tempNodeIndex)
            cursorOldPosition2D = im.GetMousePos()
          end

        --Create new mesh
        else
          if not tempNodeIndex then
            -- Create new mesh
            local newMeshID = editor.createMesh(M.type, {{pos = focusPointNoMesh + heightOffset, width = editor.getPreference(M.preferencesName .. ".general.defaultWidth"), depth = editor.getPreference(M.preferencesName .. ".general.defaultDepth"), normal = upVector}}, {})
            if fieldsCopy then
              editor.pasteFields(fieldsCopy, newMeshID)
            end
            editor.selectObjectById(newMeshID)
            selectedMesh = scenetree.findObjectById(newMeshID)
          end

          -- If the mouse button is held down, change the width of the created node
          mouseButtonHeldOnNode = true
          cursorOldPosition2D = im.GetMousePos()
          tempNodeIndex = tempNodeIndex and tempNodeIndex or 0
          oldNodeWidth = selectedMesh:getNodeWidth(tempNodeIndex)
        end
      end
    end

    -- Position temporary node to show where the next one will be
    if selectedMesh and editor.keyModifiers.alt and tempNodeIndex and not mouseButtonHeldOnNode then
      editor.setNodePosition(selectedMesh, tempNodeIndex, (focusPointNoMesh + heightOffset))
    end
  end

  if im.IsMouseClicked(0) and not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow)) then
    if not editor.keyModifiers.alt then
      if not editor.isAxisGizmoHovered() then
        if hoveredMeshID and not tempNodeIndex then
          -- Clicked on a hovered mesh
          if not selectedMesh or selectedMeshId ~= hoveredMeshID then
            -- Add mesh to selection
            editor.selectObjectById(hoveredMeshID)
          end

          -- Check if a node was clicked
          if hoveredNode then
            selectNode(hoveredNode)
            mouseButtonHeldOnNode = true
          else
            selectNode(nil)
          end
        elseif selectedMeshId then
          selectNode(nil)
          editor.clearObjectSelection()
        end
      end
    end
  end

  -- Highlight selected meshes
  if selectedMesh then
    showMesh(selectedMesh, roadRiverGui.highlightColors.selected)
  end

  if tempNodeIndex and not editor.keyModifiers.alt then
    finishMesh()
  end
end


-- These methods are for the action map to call
local function copySettingsAM()
  if selectedMeshId then
    fieldsCopy = editor.copyFields(selectedMeshId)
  end
end

local function defaultWidthSlider()
  local defaultWidthPtr = im.FloatPtr(editor.getPreference(M.preferencesName .. ".general.defaultWidth"))
  if im.InputFloat("##Default Width", defaultWidthPtr, 0.1, 0.5) then
    editor.setPreference(M.preferencesName .. ".general.defaultWidth", defaultWidthPtr[0])
  end
end

local function defaultDepthSlider()
  local defaultDepthPtr = im.FloatPtr(editor.getPreference(M.preferencesName .. ".general.defaultDepth"))
  if im.InputFloat("##Default Depth", defaultDepthPtr, 0.1, 0.5) then
    editor.setPreference(M.preferencesName .. ".general.defaultDepth", defaultDepthPtr[0])
  end
end

local function onToolbar()
  im.Text("Default Width")
  im.SameLine()
  im.PushItemWidth(im.uiscale[0] * 150)
  defaultWidthSlider()
  im.SameLine()

  im.Text("Default Depth")
  im.SameLine()
  im.PushItemWidth(im.uiscale[0] * 150)
  defaultDepthSlider()
end

local function onEditorPreferenceValueChanged(path, value)
  if path == M.preferencesName .. ".general.defaultHeight" then heightOffset = vec3(0, 0, value) end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory(M.preferencesName, string.sentenceCase(M.preferencesName))
  prefsRegistry:registerSubCategory(M.preferencesName, "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {defaultWidth = {"float", 10, "", nil, 0.1}},
    {defaultDepth = {"float", 5, "", nil, 0.1}},
    {defaultHeight = {"float", 2, "", nil, 0.1}},
    {dragWidth = {"bool", false, "Change the width of newly placed nodes by clicking and dragging the mouse cursor."}}
  })
end

local function onEditorInspectorFieldChanged(selectedIds, fieldName, fieldValue, arrayIndex)
  if (fieldName == "segmentLength" or fieldName == "subdivideLength") then
    for _, id in ipairs(selectedIds) do
      local object = scenetree.findObjectById(id)
      if object:getClassName() == M.type then
        object:regenerate()
      end
    end
  end
end

local function onEditorAxisGizmoAligmentChanged()
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end
  updateGizmoPos()
end

local function onEditorObjectSelectionChanged()
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end
  local newSelectedMesh = editor.findFirstSelectedByType(M.type)
  selectedMeshId = newSelectedMesh and newSelectedMesh:getID()
end

local function onActivate()
  editModeName = "Edit " .. M.type
  onEditorObjectSelectionChanged()
end

M.onEditorInspectorHeaderGui_ = onEditorInspectorHeaderGui
M.onEditorRegisterPreferences_ = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged_ = onEditorPreferenceValueChanged
M.onEditorInspectorFieldChanged_ = onEditorInspectorFieldChanged
M.onEditorAxisGizmoAligmentChanged_ = onEditorAxisGizmoAligmentChanged
M.onEditorObjectSelectionChanged_ = onEditorObjectSelectionChanged
M.onUpdate_ = onUpdate
M.onToolbar_ = onToolbar
M.onActivate_ = onActivate

M.copySettingsAM = copySettingsAM
M.pasteFieldsAM = pasteFieldsAM
M.onDeleteSelection = onDeleteSelection
M.onSelectAll = onSelectAll

return M