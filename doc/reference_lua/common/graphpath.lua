--[[
Copyright (c) 2012 Hello!Game, 2015 BeamNG GmbH

Permission is hereby granted, free of charge, to any person obtaining a copy
of newinst software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is furnished
to do so, subject to the following conditions:

The above copyright notice and newinst permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]

----------------------------------------------------------------
-- example :
--[[
gp = newGraphpath()
gp:edge("a", "b", 7)
gp:edge("a", "c", 9)
gp:edge("a", "f", 14)
gp:edge("b", "d", 15)
gp:edge("b", "c", 10)
gp:edge("c", "d", 11)
gp:edge("c", "f", 2)
gp:edge("d", "e", 6)
gp:edge("e", "f", 9)

print( table.concat( gp:getPath("a","e"), "->") )
]]

require('mathlib')
local bit = require "bit"

local tableInsert, min, max, random, rshift = table.insert, math.min, math.max, math.random, bit.rshift

local M = {}

local minheap = {}
minheap.__index = minheap

local function newMinheap()
  return setmetatable({length = 0, vals = {}}, minheap)
end

function minheap:peekKey()
  return self[1]
end

function minheap:empty()
  return self.length == 0
end

function minheap:clear()
  table.clear(self.vals)
  self.length = 0
end

function minheap:insert(k, v)
  local vals = self.vals
  -- float the new key up from the bottom of the heap
  local child_index = self.length + 1 -- array index of the new child node to be added to heap
  self.length = child_index -- update the central heap length record

  while child_index > 1 do
    local parent_index = rshift(child_index, 1)
    local parent_key = self[parent_index]
    if k >= parent_key then
      break
    else
      self[child_index], vals[child_index] = parent_key, vals[parent_index]
      child_index = parent_index
    end
  end

  self[child_index], vals[child_index] = k, v
end

function minheap:pop()
  if self.length <= 0 then return end
  local vals = self.vals
  local result_key, result_val = self[1], vals[1]  -- get top value
  local heapLength = self.length
  local last_key, last_val = self[heapLength], vals[heapLength]
  heapLength = heapLength - 1
  local child_index = 2
  local parent_index = 1

  while child_index <= heapLength do
    local next_child = child_index + 1
    if next_child <= heapLength and self[next_child] < self[child_index] then
      child_index = next_child
    end
    local child_key = self[child_index]
    if last_key < child_key then
      break
    else
      self[parent_index], vals[parent_index] = child_key, vals[child_index]
      parent_index = child_index
      child_index = child_index + child_index
    end
  end

  self.length = heapLength
  self[parent_index], vals[parent_index] = last_key, last_val
  return result_key, result_val
end

-----------------------------------------------------------------

local Graphpath = {}
Graphpath.__index = Graphpath

local function newGraphpath()
  return setmetatable({graph = {}, positions = {}, radius = {}}, Graphpath)
end

function Graphpath:export(edgeCount)
  local i, edgeData = 0, table.new((edgeCount or 0) * 3, 0)
  for node, connectedNodes in pairs(self.graph) do
    for connectedNode, edge in pairs(connectedNodes) do
      if node > connectedNode then
        i = i + 3
        edgeData[i-2], edgeData[i-1], edgeData[i] = node, connectedNode, edge
      end
    end
  end
  return {edges = edgeData, positions = self.positions, radius = self.radius}
end

function Graphpath:import(graphData)
  local graph = self.graph
  local edges = graphData.edges

  for i = 1, #edges, 3 do
    if graph[edges[i]] == nil then graph[edges[i]] = {} end
    graph[edges[i]][edges[i+1]] = edges[i+2]

    if graph[edges[i+1]] == nil then graph[edges[i+1]] = {} end
    graph[edges[i+1]][edges[i]] = edges[i+2]
  end

  self.positions = graphData.positions
  self.radius = graphData.radius
end

function Graphpath:clear()
  self.graph = {}
end

function Graphpath:edge(sp, ep, dist)
  if self.graph[sp] == nil then
    self.graph[sp] = {}
  end

  self.graph[sp][ep] = {dist or 1}

  if self.graph[ep] == nil then
    self.graph[ep] = {}
  end
end

function Graphpath:uniEdge(inNode, outNode, dist, drivability, speedLimit)
  dist = dist or 1
  if self.graph[inNode] == nil then
    self.graph[inNode] = {}
  end

  local data = {len = dist, drivability = drivability, inNode = inNode, speedLimit = speedLimit} -- sp is the inNode of the edge

  self.graph[inNode][outNode] = data

  if self.graph[outNode] == nil then
    self.graph[outNode] = {}
  end

  self.graph[outNode][inNode] = data
end

function Graphpath:bidiEdge(sp, ep, dist, drivability, speedLimit)
  dist = dist or 1
  if self.graph[sp] == nil then
    self.graph[sp] = {}
  end

  local data = {len = dist, drivability = drivability, inNode = nil, speedLimit = speedLimit} -- no inNode means edge is bidirectional

  self.graph[sp][ep] = data

  if self.graph[ep] == nil then
    self.graph[ep] = {}
  end

  self.graph[ep][sp] = data
end

function Graphpath:setPointPosition(p, pos)
  self.positions[p] = pos
end

function Graphpath:setPointPositionRadius(p, pos, radius)
  self.positions[p] = pos
  self.radius[p] = radius
end

function Graphpath:setNodeRadius(node, radius)
  self.radius[node] = radius
end

local function invertPath(goal, road)
  local path = table.new(20, 0)
  local e = 0
  while goal do -- unroll path from goal to source
    e = e + 1
    path[e] = goal
    goal = road[goal]
  end

  for s = 1, e * 0.5 do -- reverse order to get source to goal
    path[s], path[e] = path[e], path[s]
    e = e - 1
  end

  return path
end

do
  local graph, index, S, nodeData, allSCC

  local function strongConnect(node)
    -- Set the depth index for node to the smallest unused index
    index = index + 1
    nodeData[node] = {index = index, lowlink = index, onStack = true}
    tableInsert(S, node)

    -- Consider succesors of node
    for adjNode, value in pairs(graph[node]) do
      if value.drivability == 1 then
        if nodeData[adjNode] == nil then -- adjNode is a descendant of 'node' in the search tree
          strongConnect(adjNode)
          nodeData[node].lowlink = min(nodeData[node].lowlink, nodeData[adjNode].lowlink)
        elseif nodeData[adjNode].onStack then -- adjNode is not a descendant of 'node' in the search tree
          nodeData[node].lowlink = min(nodeData[node].lowlink, nodeData[adjNode].index)
        end
      end
    end

    -- generate an scc (smallest possible scc is one node), i.e. in a directed accyclic graph each node constitutes an scc
    if nodeData[node].lowlink == nodeData[node].index then
      local currentSCC = {}
      local currentSCCLen = 0
      repeat
        local w = table.remove(S)
        nodeData[w].onStack = false
        currentSCC[w] = true
        currentSCCLen = currentSCCLen + 1
      until node == w
      currentSCC[0] = currentSCCLen
      tableInsert(allSCC, currentSCC)
    end
  end

  function Graphpath:scc(v)
    --[[ https://en.wikipedia.org/wiki/Tarjan%27s_strongly_connected_components_algorithm
    calculates the strongly connected components (scc) of the map graph.
    If v is provided, it only calculates the scc containing / is reachable from v.
    Returns an array of dicts ('allSCC') --]]

    graph = self.graph
    if v and graph[v] == nil then return {} end

    index, S, nodeData, allSCC = 0, {}, {}, {}

    if v then -- get only the scc containing/reachable from v
      strongConnect(v)
    else -- get all scc of the map graph
      for node, _ in pairs(graph) do
        if nodeData[node] == nil then
          strongConnect(node)
        end
      end
    end
    return allSCC
  end
end

function Graphpath:getPath(start, goal, dirMult)
  local graph = self.graph
  if graph[start] == nil or graph[goal] == nil then return {} end

  local dirCoeff = {[true] = dirMult or 1, [false] = 1}

  local cost, node = 0, start
  local minParent = {[node] = false}
  local queued = {}
  local road = {} -- predecessor subgraph

  local q = newMinheap()
  repeat
    if road[node] == nil then
      road[node] = minParent[node]
      if node == goal then break end
      for child, data in pairs(graph[node]) do
        if road[child] == nil then -- if the shortest path to child has not already been found
          local currentChildCost = queued[child] -- lowest value with which child has entered the que
          local newChildCost = cost + data.len * dirCoeff[data.inNode == child]
          if not currentChildCost or newChildCost < currentChildCost then
            q:insert(newChildCost, child)
            minParent[child] = node
            queued[child] = newChildCost
          end
        end
      end
    end
    cost, node = q:pop()
  until not cost

  return invertPath(goal, road)
end

function Graphpath:getPointNodePath(start, target, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wZ)
  -- Shortest path between a point and a node or vice versa.
  -- start/target: either start or target should be a node name, the other a vec3 point
  -- cutOffDrivability: penalize roads with drivability <= cutOffDrivability
  -- dirMult: penalty to be applied to an edge designated oneWay if it is traversed in opposite direction (should be larger than 1 typically >= 1e3-1e4).
  --          If equal to nil or 1 then it means no penalty.
  -- penaltyAboveCutoff: penalty multiplier for roads above the drivability cutoff
  -- penaltyBelowCutoff: penalty multiplier for roads below the drivability cutoff
  -- wZ: number. When higher than 1 distance minimization is biased to minimizing z diamension more so than x, y.

  local graph = self.graph
  local invert
  if start.x then
    start, target = target, start
    invert = true
  end
  if graph[start] == nil or target == nil then return {} end

  wZ = wZ or 4
  cutOffDrivability = cutOffDrivability or 0
  penaltyAboveCutoff = penaltyAboveCutoff or 1
  penaltyBelowCutoff = penaltyBelowCutoff or 10000

  local dirCoeff = {[true] = dirMult or 1, [false] = 1}
  local drivCoeff = {[true] = penaltyAboveCutoff, [false] = penaltyBelowCutoff}

  local positions = self.positions
  local cost, node = 0, start
  local minParent = {[node] = false}
  local minCost = {[node] = cost}
  local road = {}

  local targetMinCost = math.huge
  local targetMinCostLink
  local tmpVec = vec3()
  local nodeToTargetVec = vec3()

  local q = newMinheap()
  repeat
    if road[node] == nil then
      road[node] = minParent[node] -- t[2] is the predecessor of node in the shortest path to node
      if node == target then break end

      local p1 = positions[node]
      nodeToTargetVec:setSub2(target, p1)
      local pathCost = cost + square(square(nodeToTargetVec.x) + square(nodeToTargetVec.y) + square(wZ * nodeToTargetVec.z))
      if pathCost < targetMinCost then
        q:insert(pathCost, target)
        targetMinCost = pathCost
        minParent[target] = node
        targetMinCostLink = nil
      end

      local parent = road[node]
      for child, data in pairs(graph[node]) do
        local edgeCost
        local outNode = invert and node or child
        if road[child] == nil then -- if the shortest path to child has not already been found
          edgeCost = data.len * dirCoeff[data.inNode == outNode] * drivCoeff[data.drivability > cutOffDrivability]
          pathCost = cost + edgeCost
          local childMinCost = minCost[child]
          if not childMinCost or pathCost < childMinCost then
            q:insert(pathCost, child)
            minCost[child] = pathCost
            minParent[child] = node
          end
        end
        if cost < targetMinCost and child ~= parent then
          tmpVec:setSub2(positions[child], p1) -- edgeVec
          local xnorm = min(1, max(0, tmpVec:dot(nodeToTargetVec) / (tmpVec:squaredLength() + 1e-30)))
          if xnorm > 0 and xnorm < 1 then
            tmpVec:setScaled(-xnorm)
            tmpVec:setAdd(nodeToTargetVec) -- distToEdgeVec
            pathCost = cost + (edgeCost or data.len * dirCoeff[data.inNode == outNode] * drivCoeff[data.drivability > cutOffDrivability]) * xnorm +
                      square(square(tmpVec.x) + square(tmpVec.y) + square(wZ * tmpVec.z))
            if pathCost < targetMinCost then
              q:insert(pathCost, target)
              targetMinCost = pathCost
              minParent[target] = node
              targetMinCostLink = child
            end
          end
        end
      end
    end

    cost, node = q:pop()
  until not cost

  local path = {targetMinCostLink} -- last path node has to be added ad hoc
  local e = #path
  target = road[node] -- if all is well, node here should be the targetPos
  while target do
    e = e + 1
    path[e] = target
    target = road[target]
  end

  if not invert then
    for i = 1, e * 0.5 do -- reverse order to get source to target
      path[i], path[e] = path[e], path[i]
      e = e - 1
    end
  end

  return path
end

function Graphpath:getPointToPointPath(startPos, iter, targetPos, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wZ)
  -- startPos: path source position
  -- startPosLinks: graph nodes closest (by some measure) to startPos to be used as links to it
  -- targetPos: target position (vec3)
  -- cutOffDrivability: penalize roads with drivability <= cutOffDrivability
  -- dirMult: penalty to be applied to an edge designated oneWay if it is traversed in opposite direction (should be larger than 1 typically >= 1e3-1e4).
  --          If equal to nil or 1 then it means no penalty.
  -- penaltyAboveCutoff: penalty multiplier for roads above the drivability cutoff
  -- penaltyBelowCutoff: penalty multiplier for roads below the drivability cutoff
  -- wZ: number (typically >= 1). When higher than 1 the destination node of optimum path will be biased towards minimizing height difference to targetPos.
  if startPos == nil or targetPos == nil or startPos == targetPos then return {} end

  local nextNode, nextCost, nextXnorm = iter() -- get the closest neighboor
  if nextNode == nil then return {} end

  local minCost = table.new(0, 32)
  minCost[nextNode] = nextCost
  local xnorms = table.new(0, 32)
  xnorms[nextNode] = nextXnorm
  local minParent = table.new(0, 32)
  minParent[nextNode] = false

  local node, cost = nextNode, nextCost
  nextNode, nextCost, nextXnorm = iter()
  if nextNode == nil then return {} end

  local graph = self.graph
  local positions = self.positions

  wZ = wZ or 1
  cutOffDrivability = cutOffDrivability or 0
  penaltyAboveCutoff = penaltyAboveCutoff or 1
  penaltyBelowCutoff = penaltyBelowCutoff or 10000

  local dirCoeff = {[true] = dirMult or 1, [false] = 1}
  local drivCoeff = {[true] = penaltyAboveCutoff, [false] = penaltyBelowCutoff}

  local road = table.new(0, 32) -- initialize shortest paths linked list
  local targetMinCost, targetMinCostLink = math.huge, nil
  local p1, tmpVec, nodeToTargetVec = vec3(), vec3(), vec3()

  local tmpNode = table.new(0, 2)
  local tmpEdge1Data = table.new(0, 3)
  local tmpEdge2Data = table.new(0, 3)

  local q = newMinheap() -- initialize que

  while cost do
    if road[node] == nil then
      road[node] = minParent[node]
      if node == targetPos then break end

      local graphNode
      if not graph[node] then
        local n1id, n2id = node[1], node[2]
        local edgeData = graph[n1id][n2id]
        local dist, driv, inNode = edgeData.len, edgeData.drivability, edgeData.inNode
        local xnorm = xnorms[node]

        table.clear(tmpNode)

        tmpEdge1Data.len = dist * xnorm
        tmpEdge1Data.drivability = driv
        tmpEdge1Data.inNode = (inNode == n2id and node) or inNode
        tmpNode[n1id] = tmpEdge1Data

        tmpEdge2Data.len = dist * (1 - xnorm)
        tmpEdge2Data.drivability = driv
        tmpEdge2Data.inNode = (inNode == n1id and node) or inNode
        tmpNode[n2id] = tmpEdge2Data

        graphNode = tmpNode
        p1:setLerp(positions[n1id], positions[n2id], xnorm)
      else
        graphNode = graph[node]
        p1:set(positions[node])
      end

      nodeToTargetVec:setSub2(targetPos, p1)
      local pathCost = cost + square(square(nodeToTargetVec.x) + square(nodeToTargetVec.y) + square(wZ * nodeToTargetVec.z))
      if pathCost < targetMinCost then
        q:insert(pathCost, targetPos)
        targetMinCost = pathCost
        minParent[targetPos] = node
        targetMinCostLink = nil
      end

      local parent = road[node]
      for child, edgeData in pairs(graphNode) do
        local edgeCost
        if road[child] == nil then -- if the shortest path to child has not already been found
          edgeCost = edgeData.len * dirCoeff[edgeData.inNode == child] * drivCoeff[edgeData.drivability > cutOffDrivability]
          local pathCost = cost + edgeCost
          local childMinCost = minCost[child]
          if not childMinCost or pathCost < childMinCost then
            q:insert(pathCost, child)
            minCost[child] = pathCost
            minParent[child] = node
          end
        end
        if cost < targetMinCost and child ~= parent then
          tmpVec:setSub2(positions[child], p1) -- edgeVec
          local xnorm = min(1, max(0, tmpVec:dot(nodeToTargetVec) / (tmpVec:squaredLength() + 1e-30)))
          if xnorm > 0 and xnorm < 1 then
            tmpVec:setScaled(-xnorm)
            tmpVec:setAdd(nodeToTargetVec) -- distToEdgeVec
            pathCost = cost + (edgeCost or edgeData.len * dirCoeff[edgeData.inNode == child] * drivCoeff[edgeData.drivability > cutOffDrivability]) * xnorm +
                      square(square(tmpVec.x) + square(tmpVec.y) + square(wZ * tmpVec.z))
            if pathCost < targetMinCost then
              q:insert(pathCost, targetPos)
              targetMinCost = pathCost
              minParent[targetPos] = node
              targetMinCostLink = child
            end
          end
        end
      end
    end

    if (q:peekKey() or math.huge) <= (nextCost or math.huge) then
      cost, node = q:pop()
    else
      minCost[nextNode] = nextCost
      xnorms[nextNode] = nextXnorm
      minParent[nextNode] = false
      node, cost = nextNode, nextCost
      nextNode, nextCost, nextXnorm = iter()
    end
  end

  local path = {targetMinCostLink} -- last path node has to be added ad hoc
  local e = #path
  local target = road[node] -- if all is well, node here should be the targetPos
  while target do
    e = e + 1
    path[e] = target
    target = road[target]
  end

  -- add the starNode link to the path if it is not there
  if graph[path[e]] == nil then
    local tmp1 = path[e][1]
    local tmp2 = path[e][2]
    path[e] = nil
    e = e - 1
    if path[e] == tmp1 and path[e-1] ~= tmp2 then
      e = e + 1
      path[e] = tmp2
    elseif path[e] == tmp2 and path[e-1] ~= tmp1 then
      e = e + 1
      path[e] = tmp1
    end
  end

  for i = 1, e * 0.5 do -- reverse order to get source to target
    path[i], path[e] = path[e], path[i]
    e = e - 1
  end

  return path
end

function Graphpath:getPathT(start, mePos, pathLenLim, illegalDirPenalty, initDir)
  -- Produces an optimum path away from node 'start' to a distance of ~ 'pathLenLim' from 'mePos', with a moderate bias to edge coliniarity
  -- Some randomness is achieved through a small augmentation of the pathLenLim value.
  local graph = self.graph
  if graph[start] == nil then return {} end

  local dirCoeff = {[true] = illegalDirPenalty or 1, [false] = 1}

  pathLenLim = square(pathLenLim * (1 + math.random() * 0.15)) -- augment pathLenLim by a random amount up to 15% the initial value

  local positions = self.positions
  local cost, node = 0, start
  local minParent = {[node] = false}
  local queued = {}
  local road = {} -- predessesor of node in the shortest path to node
  local curSegDir = vec3(initDir)
  local nextSegDir = vec3()

  local q = newMinheap()
  repeat
    if road[node] == nil then
      local parent = minParent[node]
      road[node] = parent
      local nodePos = positions[node]
      if parent then
        if mePos:squaredDistance(nodePos) >= pathLenLim then break end
        curSegDir:setSub2(nodePos, positions[parent])
        curSegDir:normalize()
      end
      for child, edgeData in pairs(graph[node]) do
        if road[child] == nil then
          nextSegDir:setSub2(positions[child], nodePos)
          nextSegDir:normalize()
          local t = 0.5 * (1 + nextSegDir:dot(curSegDir))
          local newChildCost = cost + edgeData.len * dirCoeff[edgeData.inNode == child] + (10 / (t + 0.001) - 9.995)
          local currentChildCost = queued[child]
          if currentChildCost == nil or currentChildCost > newChildCost then
            q:insert(newChildCost, child)
            minParent[child] = node
            queued[child] = newChildCost
          end
        end
      end
    end
    local newNode
    cost, newNode = q:pop()
    node = newNode or node -- just in case newNode is nil
  until not cost -- que is empty

  return invertPath(node, road)
end

function Graphpath:getFilteredPath(start, goal, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff)
  local graph = self.graph
  if graph[start] == nil or graph[goal] == nil then return {} end

  cutOffDrivability = cutOffDrivability or 0
  penaltyAboveCutoff = penaltyAboveCutoff or 1
  penaltyBelowCutoff = penaltyBelowCutoff or 10000

  local drivCoeff = {[true] = penaltyAboveCutoff, [false] = penaltyBelowCutoff}
  local dirCoeff = {[true] = dirMult or 1, [false] = 1}

  local cost, node = 0, start
  local minParent = {[node] = false}
  local road = {} -- predecessor subgraph
  local queued = {}

  local q = newMinheap()
  repeat
    if road[node] == nil then
      road[node] = minParent[node]
      if node == goal then break end
      for child, data in pairs(graph[node]) do
        if road[child] == nil then
          local currentChildCost = queued[child]
          local newChildCost = cost + data.len * dirCoeff[data.inNode == child] * drivCoeff[data.drivability > cutOffDrivability]
          if currentChildCost == nil or currentChildCost > newChildCost then
            q:insert(newChildCost, child)
            minParent[child] = node
            queued[child] = newChildCost
          end
        end
      end
    end
    cost, node = q:pop()
  until not cost

  return invertPath(goal, road)
end

function Graphpath:spanMap(source, nodeBehind, target, edgeDict, dirMult)
  local graph = self.graph
  if graph[source] == nil or graph[target] == nil then return {} end

  dirMult = dirMult or 1
  local dirCoeff = {[true] = dirMult, [false] = 1}

  local q = newMinheap()
  local cost, t = 0, {source, false}
  local road = {} -- predecessor subgraph
  local queued = {}

  repeat
    local node = t[1]
    if road[node] == nil then
      road[node] = t[2]
      if node == target then break end
      for child, data in pairs(graph[node]) do
        if road[child] == nil then
          local currentChildCost = queued[child]
          local newChildCost = cost + data.len * dirCoeff[data.inNode == child] * (edgeDict[node..'\0'..child] or 1e20) * ((node == source and child == nodeBehind and 300) or 1)
          if currentChildCost == nil or currentChildCost > newChildCost then
            q:insert(newChildCost, {child, node})
            queued[child] = newChildCost
          end
        end
      end
    end
    cost, t = q:pop()
  until not cost

  return invertPath(target, road)
end

function Graphpath:getPathAwayFrom(start, goal, mePos, stayAwayPos, dirMult)
  local graph = self.graph
  if graph[start] == nil or graph[goal] == nil then return {} end

  dirMult = dirMult or 1
  local dirCoeff = {[true] = dirMult, [false] = 1}

  local positions = self.positions
  local q = newMinheap()
  local cost, t = 0, {start, false}
  local road = {} -- predecessor subgraph
  local queued = {}

  repeat
    local node = t[1]
    if road[node] == nil then
      road[node] = t[2]
      if node == goal then break end
      for child, data in pairs(graph[node]) do
        if road[child] == nil then
          local currentChildCost = queued[child]
          local childPos = positions[child]
          local newChildCost = cost + data.len * dirCoeff[data.inNode == child] * mePos:squaredDistance(childPos) / (stayAwayPos:squaredDistance(childPos) + 1e-30)
          if currentChildCost == nil or currentChildCost > newChildCost then
            q:insert(newChildCost, {child, node})
            queued[child] = newChildCost
          end
        end
      end
    end
    cost, t = q:pop()
  until not cost

  return invertPath(goal, road)
end

function Graphpath:getMaxNodeAround(start, radius, dir)
  local graph = self.graph
  if graph[start] == nil then return nil end

  local graphpos = self.positions
  local startpos = graphpos[start]
  local stackP = 1
  local stack = {start}
  local visited = {}
  local maxFoundNode = start
  local maxFoundScore = 0

  repeat
    local node = stack[stackP]
    stack[stackP] = nil
    stackP = stackP - 1

    local nodeStartVec = graphpos[node] - startpos
    local posNodeDist = nodeStartVec:squaredLength()
    local posNodeScore = dir and nodeStartVec:dot(dir) or posNodeDist

    if posNodeScore > maxFoundScore then
      maxFoundScore = posNodeScore
      maxFoundNode = node
    end

    if posNodeDist < radius * radius then
      for child, _ in pairs(graph[node]) do
        if visited[child] == nil then
          visited[child] = 1
          stackP = stackP + 1
          stack[stackP] = child
        end
      end
    end
  until stackP <= 0

  return maxFoundNode
end

function Graphpath:getBranchNodesAround(start, radius)
  local graph = self.graph
  if graph[start] == nil then return nil end

  local graphpos = self.positions
  local startpos = graphpos[start]
  local stackP = 1
  local stack = {start}
  local visited = {}
  local branches = {}

  repeat
    local node = stack[stackP]
    stack[stackP] = nil
    stackP = stackP - 1

    local posNodeDist = graphpos[node]:squaredDistance(startpos)

    if posNodeDist < radius * radius then
      local childCount = 0
      for child, _ in pairs(graph[node]) do
        if visited[child] == nil then
          visited[child] = 1
          stackP = stackP + 1
          stack[stackP] = child
          childCount = childCount + 1
        end
      end

      if childCount >= 2 then
        table.insert(branches, node)
      end
    end
  until stackP <= 0

  return branches
end

function Graphpath:getChasePath(nodeBehind, nodeAhead, targetNodeBehind, targetNodeAhead, mePos, meVel, targetPos, targetVel, dirMult) -- smart chase path processing
  local graphpos = self.positions

  local wp1pos, wp2pos = graphpos[nodeBehind], graphpos[nodeAhead]
  local twp1pos, twp2pos = graphpos[targetNodeBehind] - targetVel, graphpos[targetNodeAhead] + targetVel -- positions with extra velocity based distance
  -- the extra distance is used to determine if the target has crossed into a parallel segment
  local meToTarget = (targetPos + targetVel:normalized()) - mePos -- target point is slightly ahead of original pos
  local meDotTarget = meToTarget:dot(targetVel)
  local wpAhead = meToTarget:dot(wp1pos - mePos) > meToTarget:dot(wp2pos - mePos) and nodeBehind or nodeAhead -- best wp that goes to target wp
  local twpAhead = wpAhead == targetNodeBehind and targetNodeBehind or targetNodeAhead -- check if best wp matches target wp
  if meDotTarget > 0 and targetNodeAhead == nodeBehind then targetNodeAhead = nodeAhead end

  local path = self:getPath(wpAhead, twpAhead, dirMult)

  if meVel:squaredLength() >= 9 and meDotTarget >= 9 and meVel:dot(graphpos[path[1]] - mePos) < 0 then -- simply pick waypoint ahead if driving same as player
    path = {nodeAhead}
  end

  local xnorm = mePos:xnormOnLine(twp1pos, twp2pos)
  if path[3] and xnorm > 0 and xnorm < 1 and meVel:normalized():dot(targetVel:normalized()) > 0.7 and meVel:dot(graphpos[path[2]] - mePos) < 0 then
    -- vehicle is parallel to target segment & matching the target orientation, but the path would do a u-turn behind the target
    -- this makes the vehicle cut across directly to the target waypoint; can be useful for highway offramps and parallel road segments
    path = {twpAhead} -- go directly to target wp ahead
  end

  return path
end

local fleeDirScoreCoeff = {[false] = 1, [true] = 0.8}
function Graphpath:getFleePath(startNode, initialDir, chasePos, pathLenLimit, rndDirCoef, rndDistCoef)
  local graph = self.graph
  if graph[startNode] == nil then return nil end

  pathLenLimit = pathLenLimit or 100
  rndDirCoef = rndDirCoef or 0
  rndDistCoef = min(rndDistCoef or 0.05, 1)
  local graphpos = self.positions
  local visited = {startNode = 0.2}
  local path = {startNode}
  local pathLen = 0

  local prevNode = startNode
  local prevDir = vec3(initialDir)
  local rnd2 = rndDirCoef * 2
  local chaseAIdist = graphpos[prevNode]:squaredDistance(chasePos) * 0.1

  repeat
    local maxScore = -math.huge
    local maxNode = -1
    local maxVec
    local maxLen

    local rDistCoef = min(1, pathLen * rndDistCoef)

    -- randomize dir
    prevDir:set(
      prevDir.x + (random() * rnd2 - rndDirCoef) * rDistCoef,
      prevDir.y + (random() * rnd2 - rndDirCoef) * rDistCoef,
      0)

    local prevPos = graphpos[prevNode]
    local chaseCoef = min(0.5, rndDistCoef * chaseAIdist)

    for child, link in pairs(graph[prevNode]) do
      local childPos = graphpos[child]
      local pathVec = childPos - prevPos
      local pathVecLen = pathVec:length()
      local driveability = link.drivability
      local vis = visited[child] or 1
      local posNodeScore = vis * fleeDirScoreCoeff[link.inNode == child] * driveability * (3 + pathVec:dot(prevDir) / max(pathVecLen, 1)) * max(0, 3 + (chasePos - childPos):normalized():dot(prevDir) * chaseCoef)
      visited[child] = vis * 0.2
      if posNodeScore >= maxScore then
        maxNode = child
        maxScore = posNodeScore
        maxVec = pathVec
        maxLen = pathVecLen
      end
    end

    if maxNode == -1 then
      break
    end

    prevNode = maxNode
    prevDir = maxVec / (maxLen + 1e-30)
    pathLen = pathLen + maxLen
    table.insert(path, maxNode)

  until pathLen > pathLenLimit

  return path
end

local dirScoreCoeff = {[true] = 0.1, [false] = 1}
function Graphpath:getRandomPathG(startNode, initialDir, pathLenLimit, rndDirCoef, rndDistCoef, oneway)
  local graph = self.graph
  if graph[startNode] == nil then return nil end

  pathLenLimit = pathLenLimit or 100
  rndDirCoef = rndDirCoef or 0
  rndDistCoef = min(rndDistCoef or 0.05, 1e30)
  local graphpos = self.positions
  local visited = {startNode = 0.2}
  local path = {startNode}
  local pathLen = 0

  if oneway == nil then oneway = true end

  local prevNode = startNode
  local ropePos = graphpos[prevNode] - initialDir * 15

  dirScoreCoeff[true] = oneway == false and 1 or 0.1

  repeat
    local maxScore = -math.huge
    local maxNode = -1
    local maxVec
    local maxLen

    local curPos = graphpos[prevNode]
    local prevDir = curPos - ropePos
    local prevDirLen = prevDir:length()
    prevDir = prevDir / (prevDirLen + 1e-30)
    ropePos = curPos - prevDir * min(prevDirLen, 15)

    -- randomize dir
    local rDistDirCoef = min(1, pathLen * rndDistCoef) * rndDirCoef
    prevDir:set(
      prevDir.x + (random() * 2 - 1) * rDistDirCoef,
      prevDir.y + (random() * 2 - 1) * rDistDirCoef,
      0)

    prevDir:normalize()

    for child, link in pairs(graph[prevNode]) do
      local pathVec = graphpos[child] - curPos
      local pathVecLen = pathVec:length()
      local vis = visited[child] or 1
      local posNodeScore = vis * dirScoreCoeff[link.inNode == child] * link.drivability * (2 + pathVec:dot(prevDir) / max(pathVecLen, 1))
      visited[child] = vis * 0.2
      if posNodeScore >= maxScore then
        maxNode = child
        maxScore = posNodeScore
        maxLen = pathVecLen
        maxVec = pathVec
      end
    end

    if maxNode == -1 then
      break
    end

    if maxVec:dot(prevDir) <= 0 then
      ropePos = curPos
    end
    prevNode = maxNode
    pathLen = pathLen + maxLen
    table.insert(path, maxNode)

  until pathLen > pathLenLimit

  return path
end

-- produces a random path with a bias towards edge coliniarity
function Graphpath:getRandomPath(nodeAhead, nodeBehind, dirMult)
  local graph = self.graph
  if graph[nodeAhead] == nil or graph[nodeBehind] == nil then return {} end

  dirMult = dirMult or 1
  local dirCoeff = {[true] = dirMult, [false] = 1}

  local positions = self.positions

  local q = newMinheap()
  local cost, t = 0, {nodeAhead, false}
  local road = {} -- predecessor subgraph
  local queued = {}
  local node
  local choiceSet = {}
  local costSum = 0
  local pathLength = {[nodeBehind] = 0}

  repeat
    if road[t[1]] == nil then
      node = t[1]
      local parent = t[2] or nodeBehind
      road[node] = t[2]
      pathLength[node] = pathLength[parent] + (positions[node] - positions[parent]):length()
      if pathLength[node] <= 300 or not t[2] then
        local nodePos = positions[node]
        local edgeDirVec = (positions[parent] - nodePos):normalized()
        for child, data in pairs(graph[node]) do
          if road[child] == nil then
            local childCurrCost = queued[child]
            local penalty = 1 + 10 * square(max(0, edgeDirVec:dot((positions[child] - nodePos):normalized()) - 0.2))
            local childNewCost = cost + penalty * data.len * dirCoeff[data.inNode == child] * ((node == nodeAhead and child == nodeBehind) and 1e4 or 1)
            if childCurrCost == nil or childCurrCost > childNewCost then
              queued[child] = childNewCost
              q:insert(childNewCost, {child, node})
            end
          end
        end
      else
        tableInsert(choiceSet, {node, square(1/cost)})
        costSum = costSum + square(1/cost)
        if #choiceSet == 5 then
          break
        end
      end
    end
    cost, t = q:pop()
  until not cost

  local randNum = costSum * math.random()
  local runningSum = 0

  for i = 1, #choiceSet do
    local newRunningSum = choiceSet[i][2] + runningSum
    if runningSum <= randNum and randNum <= newRunningSum then
      node = choiceSet[i][1]
      break
    end
    runningSum = newRunningSum
  end

  return invertPath(node, road)
end

-- public interface
M.newMinheap = newMinheap
M.newGraphpath = newGraphpath
return M
