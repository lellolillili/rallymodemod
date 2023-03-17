-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor
local allRoads = {}
local roadSplines = {}

local function updateRoadVertices(road)
  if not road then log("E","updateRoadVertices", "road is nil") end
  if editor.getPreference("roadTemplates.general.loadTemplates") then
    local points = {}
    for pointIndex = 0, road:getEdgeCount() - 1 do
      table.insert(points, road:getMiddleEdgePosition(pointIndex))
    end
    roadSplines[road:getID()] = points
  end
  allRoads[road:getID()] = true
end

local function resetRoadList()
  allRoads = {}
  roadSplines = {}
end

local function removeRoadFromList(id)
  allRoads[id] = nil
  roadSplines[id] = nil
end

--- Add a new road node to a road object.
-- @param roadObjectId the road object id
-- @param nodeInfo the node info table, fields:
-- *position* - node position
-- *width* - node width
-- *index* - node index to insert node into. Use U32_MAX to insert at the end.
-- @returns new node id
local function addRoadNode(roadObjectId, nodeInfo)
  local decalRoad = scenetree.findObjectById(roadObjectId)
  local res = decalRoad:insertNode(nodeInfo.pos, nodeInfo.width, nodeInfo.index)
  updateRoadVertices(decalRoad)
  editor.setDirty()
  return res
end

local function setNodeWidth(object, nodeID, width)
  object:setNodeWidth(nodeID, width)
  editor.setDirty()
end

local function setNodeDepth(object, nodeID, depth)
  object:setNodeDepth(nodeID, depth)
  editor.setDirty()
end

local function setNodePosition(object, nodeID, position)
  object:setNodePosition(nodeID, position)
  editor.setDirty()
end

--- Create a new road object.
-- @param nodes list of nodes to create the road with, fields per node:
-- *pos* - position of the node
-- *width* - width of the node
-- @param roadInfo dictionary with the fields that should be set for the new road
-- @returns road object id
local function createRoad(nodes, roadInfo)
  local road = createObject("DecalRoad")
  road:setField("improvedSpline", 0, "true")
  road:setField("material", 0, "BlankWhite")
  if not core_terrain.getTerrain() then
    road:setField("overObjects", 0, "true")
  end
  road:registerObject("")
  updateRoadVertices(road)
  if roadInfo then
    editor.pasteFields(roadInfo, road:getID(), false)
  end
  scenetree.MissionGroup:add(road)

  for index, node in ipairs(nodes) do
    addRoadNode(road:getID(), {pos = node.pos, width = node.width, index = index-1})
  end
  return road:getID()
end

--- Delete the road object specified by its id.
-- @param roadObjectId the road object id
local function deleteRoad(roadObjectId)
  local road = scenetree.findObjectById(roadObjectId)

  if road then
    -- Delete child roads
    local childIDs = road:getField("childRoads", "")
    if childIDs ~= "" then
      for id in string.gmatch(childIDs, "%d+") do
        deleteRoad(tonumber(id))
        removeRoadFromList(tonumber(id))
      end
    end
    -- Delete old decorations
    local decorationIDs = road:getField("decorationIDs", "")
    if decorationIDs then
      for decoID in string.gmatch(decorationIDs, "%d+") do
        scenetree.findObjectById(tonumber(decoID)):deleteObject()
      end
    end
  end

  editor.deleteObject(roadObjectId)
  removeRoadFromList(roadObjectId)
  editor.setDirty()
end

--- Delete a road node by its id.
-- @param roadObjectId the road object id
-- @param nodeId the node id
local function deleteRoadNode(roadObjectId, nodeID)
  local road = scenetree.findObjectById(roadObjectId)
  road:deleteNode(nodeID)
  updateRoadVertices(road)
  editor.setDirty()
end

local function getNodes(object)
  local result = {}
  for i = 0, object:getNodeCount()-1 do
    local node = {pos = object:getNodePosition(i), width = object:getNodeWidth(i)}
    if object.getNodeDepth then
      node.depth = object:getNodeDepth(i)
    end
    if object.getNodeNormal then
      node.normal = object:getNodeNormal(i)
    end
    table.insert(result, node)
  end
  return result
end

local function addMeshNode(meshObjectId, nodeInfo)
  local mesh = scenetree.findObjectById(meshObjectId)
  local res = mesh:insertNode(nodeInfo.pos, nodeInfo.width, nodeInfo.depth, nodeInfo.normal, nodeInfo.index)
  editor.setDirty()
  return res
end

local function deleteMeshNode(mesh, nodeID)
  mesh:deleteNode(nodeID)
  editor.setDirty()
end

local function createMesh(type, nodes, fields)
  -- Create new mesh
  local mesh = createObject(type)

  if type == "River" then
    mesh:setField("rippleDir", 0, "0.000000 1.000000")
    mesh:setField("rippleDir", 1, "0.707000 0.707000")
    mesh:setField("rippleDir", 2, "0.500000 0.860000")

    mesh:setField("rippleSpeed", 0, "-0.065")
    mesh:setField("rippleSpeed", 1, "0.09")
    mesh:setField("rippleSpeed", 2, "0.04")

    mesh:setField("rippleTexScale", 0, "7.140000 7.140000")
    mesh:setField("rippleTexScale", 1, "6.250000 12.500000")
    mesh:setField("rippleTexScale", 2, "50.000000 50.000000")

    mesh:setField("waveDir", 0, "0.000000 1.000000")
    mesh:setField("waveDir", 1, "0.707000 0.707000")
    mesh:setField("waveDir", 2, "0.500000 0.860000")

    mesh:setField("waveSpeed", 0, "1")
    mesh:setField("waveSpeed", 1, "1")
    mesh:setField("waveSpeed", 2, "1")

    mesh:setField("baseColor", 0, "45 108 171 255")
    mesh:setField("rippleTex", 0, "core/art/water/ripple.dds")
    mesh:setField("foamTex", 0, "core/art/water/foam.dds")
    mesh:setField("cubemap", 0, "DefaultSkyCubemap")
    mesh:setField("depthGradientTex", 0, "core/art/water/depthcolor_ramp.png")
  end

  editor.pasteFields(fields, mesh:getID(), false)

  mesh:registerObject(Sim.getUniqueName("New" .. type))
  scenetree.MissionGroup:add(mesh)

  if nodes[1] then
    mesh:setPosition(nodes[1].pos)
  end

  for index, node in ipairs(nodes) do
    addMeshNode(mesh:getID(), {pos = node.pos, width = node.width, depth = node.depth, normal = node.normal, index = index-1})
  end

  return mesh:getID()
end

local function deleteMesh(meshObjectId)
  editor.deleteObject(meshObjectId)
  editor.setDirty()
end

local function getAllRoads()
  return allRoads
end

local function getAllSplines()
  return roadSplines
end

local function initializeLevelRoadsVertices()
  resetRoadList()

  -- Initialize the road vertices
  for _, name in ipairs(scenetree.findClassObjects('DecalRoad')) do
    local road = scenetree.findObject(name)
    if not road then --this will happen if one name will begin with numbers
      log("E","", "Invalid DecalRoad name "..dumps(name).." Please rename it.")
    else
      updateRoadVertices(road)
    end
  end
end

local function regenerateAllDecalRoads()
  for id, _ in pairs(allRoads) do
    local road = scenetree.findObjectById(id)
    if road then
      road:regenerate()
    end
  end
end

local function initialize(editorInstance)
  editor = editorInstance
  editor.createRoad = createRoad
  editor.deleteRoad = deleteRoad
  editor.getNodes = getNodes
  editor.addRoadNode = addRoadNode
  editor.setNodeWidth = setNodeWidth
  editor.setNodeDepth = setNodeDepth
  editor.setNodePosition = setNodePosition
  editor.deleteRoadNode = deleteRoadNode
  editor.createMesh = createMesh
  editor.deleteMesh = deleteMesh
  editor.addMeshNode = addMeshNode
  editor.deleteMeshNode = deleteMeshNode
  editor.getAllRoads = getAllRoads
  editor.getAllSplines = getAllSplines
  editor.resetRoadList = resetRoadList
  editor.regenerateAllDecalRoads = regenerateAllDecalRoads
  editor.updateRoadVertices = updateRoadVertices
  editor.initializeLevelRoadsVertices = initializeLevelRoadsVertices
end

local M = {}
M.initialize = initialize

return M