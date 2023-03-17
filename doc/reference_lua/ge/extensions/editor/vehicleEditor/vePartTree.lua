-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local imguiUtils = require('ui/imguiUtils')
local jbeamIO = require('jbeam/io')
local jsonAST = require('json-ast')
local im = ui_imgui

local jbeamTableSchema = require('jbeam/tableSchema')
local nodeTransformer = require('editor/vehicleEditor/api/nodeTransformer')

local wndName = 'Part Tree'

local ast
local astFilename

local colorKey = im.ImVec4(0.95, 0.84, 0.06, 1)
local colorValue = im.ImVec4(0.31, 0.73, 1, 1)
local colorElement = im.ImVec4(0.85, 0.39, 0.63, 1)
local colorMeta = im.ImVec4(0.7, 0.7, 0.7, 1)

local viewRawData = im.BoolPtr(false)

local ddNodeCol = ColorF(1,0,1,1)
local ddNodeColVirtual = ColorF(0,0,1,0.2)
local ddBeamCol = ColorF(0,1,0,1)
local ddBeamColSel = ColorF(1,0,0,1)
local ddBeamColVirtual = ColorF(0,0,1,0.2)

local textCol = ColorF(1,1,1,1)
local textBgCol = ColorI(0,0,0,192)

local nodeHoveredRenderRadius = 0.04
local nodeSelectedRenderRadius = 0.03
local nodeRenderRadius = 0.02
local nodeCollisionRadius = 0.035

local beamRenderRadius = 0.0025
local beamHoveredRenderRadius = 0.01
local beamCollisionRadius = 0.01

local function _clearAstNodeHighlights()
  table.clear(vEditor.selectedASTNodeMap)
end

local function _highlightAstNode(nodeIdx)
  vEditor.selectedASTNodeMap[nodeIdx] = true
  for _, ni in ipairs(ast.transient.hierarchy[nodeIdx] or {}) do
    _highlightAstNode(ni)
  end
  vEditor.scrollToNode = true
end

local function _unhighlightAstNode(nodeIdx)
  vEditor.selectedASTNodeMap[nodeIdx] = nil
  for _, ni in ipairs(ast.transient.hierarchy[nodeIdx] or {}) do
    _unhighlightAstNode(ni)
  end
end

local function _clearNodeSelection(node)
  if type(node) == 'table' then
    node.__selected = nil
    for k, v in pairs(node) do
      _clearNodeSelection(v)
    end
  end
end

local function _selectAndHighlightNode(node)
  if type(node) == 'table' then
    node.__selected = true
    if node.__astNodeIdx then
      _highlightAstNode(node.__astNodeIdx)
    end
    for k, v in pairs(node) do
      _selectAndHighlightNode(v)
    end
  end
end

local function _deselectAndUnhighlightNode(node)
  if type(node) == 'table' then
    node.__selected = nil
    if node.__astNodeIdx then
      _unhighlightAstNode(node.__astNodeIdx)
    end
    for k, v in pairs(node) do
      _deselectAndUnhighlightNode(v)
    end
  end
end

local function _selectNode(node)
  if type(node) == 'table' then
    node.__selected = true
    for k, v in pairs(node) do
      _selectNode(v)
    end
  end
end

local function _setNodeHidden(node, hidden)
  if type(node) == 'table' then
    node.__hidden = hidden
    for _, n in pairs(node) do
      _setNodeHidden(n, hidden)
    end
  end
end

local brokenNodes = {}

local function getNodefromAllParts(nodeId)
  if not nodeId then return end
  if brokenNodes[nodeId] then return end
  local ioCtx = vEditor.vehData.ioCtx
  local partsList = jbeamIO.getAvailableParts(ioCtx)
  --local part = ast.transient.luaData[vEditor.selectedPart]
  --if not part.slotType then return end
  for partName, _ in pairs(partsList) do
    local part, jbeamFilename = jbeamIO.getPart(ioCtx, partName)

    --log('I', '', 'processing file: ' .. tostring(jbeamFilename))
    jbeamTableSchema.process(part, true)

    if type(part.nodes) == 'table' then
      local node = part.nodes[nodeId]
      if node then
        if type(node.posX) == 'number' and type(node.posY) == 'number' and type(node.posZ) == 'number' then
          node.pos = vec3(node.posX, node.posY, node.posZ)
          node.posX = nil
          node.posY = nil
          node.posZ = nil
        end
        node.__virtual = true
        return node
      end
    end
  end
  log('W', '', 'Node not found in any part: ' .. tostring(nodeId))
  brokenNodes[nodeId] = true
end

local function _renderNode(node, nodeDefaultOpen, _nodeLabel)
  --im.TableNextRow()
  im.TableSetColumnIndex(0)
  local label = _nodeLabel or tostring(node)
  if type(node) == 'table' then
    local flags = 0 -- im.TreeNodeFlags_SpanFullWidth
    if nodeDefaultOpen then flags = bit.bor(flags, im.TreeNodeFlags_DefaultOpen) end
    local open = im.TreeNodeEx1('##treeData' .. tostring(node), flags)
    im.SameLine()
    im.Dummy(im.ImVec2(8, 1))
    im.SameLine()

    if node.__selected then
      im.PushStyleColor2(im.Col_Header, im.ImColorByRGB(0, 0, 255, 80).Value)
      im.PushStyleColor2(im.Col_HeaderHovered, im.ImColorByRGB(80, 0, 255, 100).Value)
      im.PushStyleColor2(im.Col_HeaderActive, im.ImColorByRGB(0, 80, 255, 180).Value)
    end
    local clicked = im.Selectable1(label .. '##treeSelData' .. tostring(node), node.__selected, 0)
    if node.__selected then
      im.PopStyleColor(3)
    end

    if clicked then
      if node.__selected then
        node.__selected = nil
        _clearNodeSelection(ast.transient.luaData)
      else
        -- highlight this node and all its children
        _clearAstNodeHighlights()
        if node.__astNodeIdx then
          _highlightAstNode(node.__astNodeIdx)
        end
        if not im.GetIO().KeyCtrl then
          _clearNodeSelection(ast.transient.luaData)
        end
        _selectNode(node)
      end
    end

    im.TableSetColumnIndex(2)
    if editor.uiIconImageButton(node.__hidden and editor.icons.visibility_off or editor.icons.visibility, im.ImVec2(16,16)) then
      if not node.__hidden then
        node.__hidden = true
      else
        node.__hidden =  nil
      end
      _setNodeHidden(node, node.__hidden)
    end
    im.SameLine()
    im.Dummy(im.ImVec2(3, 1))
    im.SameLine()
    if editor.uiIconImageButton(vEditor.propertyTableEditTarget == node and editor.icons.send or editor.icons.mode_edit, im.ImVec2(16,16)) then
      editor.showWindow('Part Properties')
      vEditor.propertyTableEditTarget = node
      --print('editing ... ' .. dumps(node))
    end
    if node.__astNodeIdx then
      im.SameLine()
      im.Dummy(im.ImVec2(3, 1))
      im.SameLine()
      if editor.uiIconImageButton(node.__selected and editor.icons.filter_none or editor.icons.select_all, im.ImVec2(16,16)) then
        -- highlight this node and all its children
        _clearAstNodeHighlights()
        _highlightAstNode(node.__astNodeIdx)
        if not im.GetIO().KeyCtrl then
          _clearNodeSelection(ast.transient.luaData)
        end
        _selectNode(node)
      end
    end
    if open then
      for k, v in pairs(node) do
        if k ~= '__astNodeIdx' and k ~= '__selected' and k ~= '__hidden' and k ~= 'maxIDs' and k ~= 'validTables' and k ~= '__schemaProcessed' then
          if type(v) == 'table' then
            im.TableNextRow()
            im.PushStyleColor2(im.Col_Text, colorValue)
            _renderNode(v, false, tostring(k))
            im.PopStyleColor()
          else
            im.TableNextRow()
            im.TableSetColumnIndex(1)
            im.PushStyleColor2(im.Col_Text, colorKey)
            im.TextUnformatted(tostring(k))
            im.PopStyleColor()

            im.PushStyleColor2(im.Col_Text, colorMeta)
            im.SameLine()
            im.TextUnformatted(': ')
            im.PopStyleColor()

            im.SameLine()

            im.PushStyleColor2(im.Col_Text, colorElement)
            im.TextUnformatted(tostring(v))
            im.PopStyleColor()
          end
        end
      end
      im.TreePop()
    end
  else
    im.TableSetColumnIndex(1)
    --im.TreeNodeEx1(label .. '##treeData' .. tostring(node), bit.bor(im.TreeNodeFlags_SpanFullWidth, im.TreeNodeFlags_Leaf, im.TreeNodeFlags_NoTreePushOnOpen, im.TreeNodeFlags_Bullet))
    im.PushStyleColor2(im.Col_Text, colorElement)
    im.TextUnformatted(label)
    im.PopStyleColor()
  end
end

local function getClosestObjectToCamera(cameraPos, hitObjects)
  if next(hitObjects) == nil then return nil end

  local chosenObjData = hitObjects[1]
  if #hitObjects > 1 then
    -- If multiple hit objects, use closest one to camera

    local minDist = (chosenObjData.pos - cameraPos):length()

    for k, objData in ipairs(hitObjects) do
      if k >= 2 then
        local dist = (objData.pos - cameraPos):length()

        if dist < minDist then
          minDist = dist
          chosenObjData = objData
        end
      end
    end
  end

  return chosenObjData
end

local function setLinePointFromXnorm(outVec, p0, p1, xnorm)
  outVec:set(p0.x + (p1.x-p0.x) * xnorm, p0.y + (p1.y-p0.y) * xnorm, p0.z + (p1.z-p0.z) * xnorm)
end

local tempBeamCenterPoses = {}
local tempLinePoint1 = vec3()
local tempLinePoint2 = vec3()

local function renderPickTransformNodes(part, imguiNotHovered, rayDir, rayStartPos, rayEndPos)
  local transformingNodes = false
  if next(vEditor.selectedNodes) ~= nil then
    transformingNodes = nodeTransformer.transformNodes()
  end

  local hitNodes = {}
  local pickedNodes = {}

  -- Generate lookup table for pickedNodes index based on node name
  for k,v in ipairs(vEditor.selectedNodes) do
    pickedNodes[v.name] = k
  end

  -- Render and pick the nodes
  for _, node in pairs(part.nodes) do
    if type(node) == 'table' then
      local nodeName = node.name
      local nodePos = node.pos

      -- -1 means not picked
      local keyInPickedNodes = pickedNodes[nodeName] or -1

      if node.__hidden ~= true then
        if keyInPickedNodes ~= -1 then
          debugDrawer:drawSphere(nodePos, nodeSelectedRenderRadius, ddBeamColSel)
          debugDrawer:drawTextAdvanced(nodePos, nodeName, textCol, true, false, textBgCol)
        else
          if node.__virtual then
            debugDrawer:drawSphere(nodePos, nodeRenderRadius, ddNodeColVirtual)
          else
            debugDrawer:drawSphere(nodePos, nodeRenderRadius, ddNodeCol)
          end
        end

        -- Only pick nodes if not hovering IMGUI windows
        --if vEditor.mode == vEditor.MODE_PICKING_NODE and imguiNotHovered then
        if imguiNotHovered then
          local dist, _ = intersectsRay_Sphere(rayStartPos, rayDir, nodePos, nodeCollisionRadius)

          if dist and dist < 100 then -- if mouse over node
            table.insert(hitNodes, {node = node, pos = nodePos, keyInPickedNodes = keyInPickedNodes})
          end
        end
      end
    end
  end

  --if vEditor.mode == vEditor.MODE_PICKING_NODE and imguiNotHovered then
  if imguiNotHovered then
    -- Find closest node to camera
    local chosenNodeData = getClosestObjectToCamera(rayStartPos, hitNodes)

    if chosenNodeData then
      local chosenNodeName = chosenNodeData.node.name
      local chosenNodePos = chosenNodeData.pos
      local chosenNodeKeyInPickedNodes = chosenNodeData.keyInPickedNodes

      if im.IsMouseClicked(0) then
        if editor.keyModifiers.shift then
          -- If already picked then unpick it, otherwise pick it
          if chosenNodeKeyInPickedNodes ~= -1 then
            table.remove(vEditor.selectedNodes, chosenNodeKeyInPickedNodes)
            _deselectAndUnhighlightNode(chosenNodeData.node)
          else
            table.insert(vEditor.selectedNodes, chosenNodeData.node)
            _selectAndHighlightNode(chosenNodeData.node)
          end
        else
          for _, node in ipairs(vEditor.selectedNodes) do
            _deselectAndUnhighlightNode(node)
          end
          table.clear(vEditor.selectedNodes)

          table.insert(vEditor.selectedNodes, chosenNodeData.node)
          _selectAndHighlightNode(chosenNodeData.node)
        end
      else
        -- Highlight node
        debugDrawer:drawSphere(chosenNodePos, nodeHoveredRenderRadius, ddBeamColSel)
        if chosenNodeKeyInPickedNodes == -1 then
          debugDrawer:drawTextAdvanced(chosenNodePos, chosenNodeName, textCol, true, false, textBgCol)
        end
      end
    else
      if not transformingNodes and im.IsMouseClicked(0) and not editor.keyModifiers.shift then
        for _, node in ipairs(vEditor.selectedNodes) do
          _deselectAndUnhighlightNode(node)
        end
        table.clear(vEditor.selectedNodes)
      end
    end
  end

  return next(hitNodes) ~= nil
end

local function renderPickTransformBeams(hitNodes, part, imguiNotHovered, rayDir, rayStartPos, rayEndPos)
  local hitBeams = {}
  local pickedBeams = {}

  -- Generate lookup table for pickedBeams index based on beam name
  for k, beam in ipairs(vEditor.selectedBeams) do
    local id = beam['id1:'] .. beam['id2:']
    pickedBeams[id] = k
  end

  -- Render and pick the beams
  for key, beam in pairs(part.beams) do
    if type(beam) == 'table' then
      local id = beam['id1:'] .. beam['id2:']

      -- -1 means not picked
      local keyInPickedBeams = pickedBeams[id] or -1

      if beam.__hidden ~= true then
        local node1 = part.nodes[beam['id1:']]
        local node2 = part.nodes[beam['id2:']]
        if node1 and node2 then
          local p1 = node1.pos
          local p2 = node2.pos
          if beam.__selected then
            debugDrawer:drawLine(p1, p2, ddBeamColSel)

            local beamCenterPos = tempBeamCenterPoses[key]
            if not tempBeamCenterPoses[key] then
              tempBeamCenterPoses[key] = vec3()
              beamCenterPos = tempBeamCenterPoses[key]
            end
            beamCenterPos:setSub2(p2, p1)
            beamCenterPos:setScaled(0.5)
            beamCenterPos:setAdd(p1)
            local text = string.format("%s - %s", node1.name or node1.cid, node2.name or node2.cid)
            debugDrawer:drawTextAdvanced(beamCenterPos, text, textCol, true, false, textBgCol, false, false)
          else
            if beam.__virtual then
              debugDrawer:drawLine(p1, p2, ddBeamColVirtual)
            else
              debugDrawer:drawLine(p1, p2, ddBeamCol)
            end
          end

          --if vEditor.mode == vEditor.MODE_PICKING_BEAM and imguiNotHovered then
          if not hitNodes and imguiNotHovered then
            local xnorm1, xnorm2 = closestLinePoints(rayStartPos, rayEndPos, p1, p2)
            if xnorm2 >= 0 and xnorm2 <= 1 then
              --local minSqPointDis = linePointFromXnorm(rayStartPos, rayEndPos, xnorm1):squaredDistance(linePointFromXnorm(beamPos1, beamPos2, clamp(xnorm2, 0, 1)))
              setLinePointFromXnorm(tempLinePoint1, rayStartPos, rayEndPos, xnorm1)
              setLinePointFromXnorm(tempLinePoint2, p1, p2, clamp(xnorm2, 0, 1))

              local minSqPointDis = tempLinePoint1:squaredDistance(tempLinePoint2)

              if minSqPointDis < beamCollisionRadius * beamCollisionRadius then
                --local beamCenterPos = (beamPos2 - beamPos1) * 0.5 + beamPos1

                local beamCenterPos = tempBeamCenterPoses[key]

                if not tempBeamCenterPoses[key] then
                  tempBeamCenterPoses[key] = vec3()
                  beamCenterPos = tempBeamCenterPoses[key]
                end

                beamCenterPos:setSub2(p2, p1)
                beamCenterPos:setScaled(0.5)
                beamCenterPos:setAdd(p1)

                table.insert(hitBeams, {beam = beam, node1 = node1, node2 = node2, pos = beamCenterPos, pos1 = p1, pos2 = p2, keyInPickedBeams = keyInPickedBeams})
              end
            end
          end

        else
          local nodeId = beam['id1:']
          if nodeId and not part.nodes[nodeId] and not brokenNodes[nodeId] then
            --dump{'node1 not in part: ', nodeId}
            part.nodes[nodeId] = getNodefromAllParts(nodeId)
            if part.nodes[nodeId] then
              part.nodes[nodeId].fixed = true
            end
            beam.__virtual = true
          end
          nodeId = beam['id2:']
          if nodeId and not part.nodes[nodeId] and not brokenNodes[nodeId] then
            --dump{'node2 not in part: ', nodeId}
            part.nodes[nodeId] = getNodefromAllParts(nodeId)
            if part.nodes[nodeId] then
              part.nodes[nodeId].fixed = true
            end
            beam.__virtual = true
          end
        end
      end
    end
  end

  --if vEditor.mode == vEditor.MODE_PICKING_BEAM and imguiNotHovered then
  if imguiNotHovered then
    -- Find closest beam to camera
    local chosenBeamData = getClosestObjectToCamera(rayStartPos, hitBeams)
    if chosenBeamData then
      local chosenBeamPos1 = chosenBeamData.pos1
      local chosenBeamPos2 = chosenBeamData.pos2
      local chosenBeamCenterPos = chosenBeamData.pos
      local chosenBeamNode1 = chosenBeamData.node1
      local chosenBeamNode2 = chosenBeamData.node2
      local chosenBeamKeyInPickedBeams = chosenBeamData.keyInPickedBeams

      if im.IsMouseClicked(0) then
        if editor.keyModifiers.shift then
          -- If already picked then unpick it, otherwise pick it
          if chosenBeamKeyInPickedBeams ~= -1 then
            table.remove(vEditor.selectedBeams, chosenBeamKeyInPickedBeams)
            _deselectAndUnhighlightNode(chosenBeamData.beam)
          else
            table.insert(vEditor.selectedBeams, chosenBeamData.beam)
            _selectAndHighlightNode(chosenBeamData.beam)
          end
        else
          for _, beam in ipairs(vEditor.selectedBeams) do
            _deselectAndUnhighlightNode(beam)
          end
          table.clear(vEditor.selectedBeams)

          table.insert(vEditor.selectedBeams, chosenBeamData.beam)
          _selectAndHighlightNode(chosenBeamData.beam)
        end
      else
        -- Highlight beam
        local text = string.format("%s - %s", chosenBeamNode1.name or chosenBeamNode1.cid, chosenBeamNode2.name or chosenBeamNode2.cid)

        debugDrawer:drawCylinder(chosenBeamPos1, chosenBeamPos2, beamHoveredRenderRadius, ddBeamColSel)
        if chosenBeamKeyInPickedBeams == -1 then
          debugDrawer:drawTextAdvanced(chosenBeamCenterPos, text, textCol, true, false, textBgCol, false, false)
        end
      end
    else
      if im.IsMouseClicked(0) and not editor.keyModifiers.shift then
        for _, beam in ipairs(vEditor.selectedBeams) do
          _deselectAndUnhighlightNode(beam)
        end
        table.clear(vEditor.selectedBeams)
      end
    end
  end
end

local function renderPickTransformJBeams()
  local imguiNotHovered = not im.IsAnyItemHovered() and not im.IsWindowHovered(im.HoveredFlags_AnyWindow)
  local ray = getCameraMouseRay()
  local rayDir = ray.dir
  local rayStartPos = ray.pos
  local rayEndPos = rayStartPos + rayDir * 100

  -- TODO: improve, this is just a hack ;)
  local part = ast.transient.luaData[vEditor.selectedPart]
  if type(part) == 'table' and type(part.nodes) == 'table' then
    local hitNodes = renderPickTransformNodes(part, imguiNotHovered, rayDir, rayStartPos, rayEndPos)

    if type(part.beams) == 'table' then
      renderPickTransformBeams(hitNodes, part, imguiNotHovered, rayDir, rayStartPos, rayEndPos)
    end
  end
end

local tableFlags = bit.bor(im.TableFlags_BordersV, im.TableFlags_BordersOuterH, im.TableFlags_RowBg, im.TableFlags_NoBordersInBody, im.TableFlags_Resizable)

local function onEditorGui()
  if not vEditor.vehicle or not vEditor.vehData or not vEditor.selectedPart then return end

  local partName = vEditor.selectedPart
  local ioCtx = vEditor.vehData.ioCtx
  local success, result = pcall(function() return {jbeamIO.getPart(ioCtx, partName)} end)
  if not success then return end
  local part = result[1]
  local jbeamFilename = result[2]

  if not (jbeamFilename and part) then return end

  if editor.beginWindow(wndName, wndName) then
    im.Checkbox("Raw Data", viewRawData)
    local veh = be:getPlayerVehicle(0)
    if veh and ast and ast.transient.luaData then
      im.SameLine()
      if im.SmallButton('Sync with AST') then
        --jsonAST.syncASTfromData(ast)
      end
      im.SameLine()
      if im.SmallButton('Spawn') then
        local playerVehicle = extensions.core_vehicle_manager.getPlayerVehicleData()
        if playerVehicle then
          local vehicleConfig = playerVehicle.config or {}
          vehicleConfig.mainPartName = vEditor.selectedPart

          local pos = veh:getInitialNodePosition(veh:getRefNodeId())

          --veh:setPositionRotation(pos.x, pos.y, pos.z, 0,0,0,1) -- > bad > physics reset
          --veh:respawn(serialize(vehicleConfig)) -- > bad > not resetting the pos/rot
          veh.partConfig = serialize(vehicleConfig)
          veh:spawnObjectWithPosRot(pos.x, pos.y, pos.z, 0,0,0,1, true)
        end
      end
    end
    if not ast or not vEditor.ast or jbeamFilename ~= astFilename then

      local str = readFile(jbeamFilename)
      if not str then
        log('E', '', 'Unable to read file: ' .. tostring(jbeamFilename))
        return
      end
      ast = jsonAST.parse(str, true)
      vEditor.ast = ast
      --print('reloading ... ')

      vEditor.selectedASTNodeMap = {}

      astFilename = jbeamFilename
      vEditor.astFilename = astFilename
    end

    if ast then
      im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 2))
      im.PushFont2(1) -- 1= monospace? PushFont3("cairo_semibold_large")

      local dataProvider = ast.transient.luaData
      if viewRawData[0] then
        dataProvider = ast.transient.luaDataRaw
      end
      if dataProvider then
        local part = dataProvider[vEditor.selectedPart]
        if part then


          if im.BeginTable('##partsTree', 3, tableFlags) then
            im.TableSetupColumn('', im.TableColumnFlags_NoHide);
            im.TableSetupColumn('', im.TableColumnFlags_NoHide);
            im.TableSetupColumn('', im.TableColumnFlags_WidthFixed, 55);
            im.TableHeadersRow();
            _renderNode(part, true, vEditor.selectedPart)
          end
          im.EndTable()

        end
      end

      im.PopFont()
      im.PopStyleVar()

      -- render all nodes if possible
      if ast.transient.luaData then
        renderPickTransformJBeams()
      end
    end
  end

  if im.BeginPopup('part_tree_ctx_menu') then
    if im.MenuItem1("Open location in file explorer") then
      Engine.Platform.exploreFolder(tostring(rightClickedPart[3]))
    end
    im.EndPopup()
  end

  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,400))
end

local function onFileChanged(filename, type)
  -- FIXME: prevent saving code from triggering this D:
  if filename == astFilename then
    ast = nil
    vEditor.ast = nil
  end
end

M.onEditorGui = onEditorGui
M.open = open
M.onEditorInitialized = onEditorInitialized
M.onFileChanged = onFileChanged

return M