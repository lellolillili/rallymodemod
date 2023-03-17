-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local graphpath = require('graphpath')
local quadtree = require('quadtree')
local kdTreeBox2D = require('kdtreebox2d')

-- cache frequently used functions from other modules in upvalues
local min, max, abs, sqrt, huge = math.min, math.max, math.abs, math.sqrt, math.huge
local tableInsert, tableClear = table.insert, table.clear
local stringMatch, stringFind, stringSub = string.match, string.find, string.sub
local pointBBox = quadtree.pointBBox

local M = {}

M.objects = {}
local objectsCache = {}
M.objectNames = {}

local mapFilename = ''
local map = {nodes = {}}
local loadedMap = false
local objectsReset = true
local maxRadius = nil
local rules = nil
local isEditorEnabled
local visualLog = {}
local gp = nil
local edgeKdTree = nil
local nodeKdTree = nil
local manualWaypoints
local buildSerial = -1

local singleEventTimer = {}
singleEventTimer.__index = singleEventTimer

local emptyTable = setmetatable({}, {__newindex = function(t, key, val) log('E', 'map', 'Tried to insert new elements into map.objects') end})

local vecX = vec3(1,0,0)
local vecY = vec3(0,1,0)
local vecUp = vec3(0,0,1)

local serializedMap

-- enforces rerendering the loading screen if required
local function _updateProgress()
  LoadingManager:triggerUpdate()
end

local function newSingleEventTimer()
  local data = {waitDt = -1, update = nop, eventFun = nop}
  setmetatable(data, singleEventTimer)
  return data
end

function singleEventTimer:update(dt)
  local waitDt = max(0, self.waitDt - dt)
  self.waitDt = waitDt
  if waitDt == 0 then
    self.update = nop
    self.eventFun(unpack(self.params))
  end
end

function singleEventTimer:callAfter(dt, eventFun, ...)
  self.waitDt = dt
  self.eventFun = eventFun
  self.params = {...}
  self.update = singleEventTimer.update
end

local delayedLoad = newSingleEventTimer()

local function visLog(type, pos, msg)
  tableInsert(visualLog, {type = type, pos = pos, msg = msg})
end

local function nameNode(prefix, idx)
  local nodeName = prefix..idx
  if map.nodes[nodeName] then
    nodeName = nodeName.."_"
    local postfix = 1
    while map.nodes[nodeName..postfix] do
      postfix = postfix + 1
    end
    nodeName = nodeName..postfix
  end
  return nodeName
end

local function setRoadRules()
  rules = {rightHandDrive = false, turnOnRed = false} -- default road rules
  local fileName = getMissionFilename()
  if not fileName or fileName == '' then return end
  local _, _, ext = path.split(fileName)
  if ext == 'mis' then return end

  local info = jsonReadFile(fileName)
  if info and info.roadRules then
    rules = tableMerge(rules, info.roadRules)
  end
end

local function getRoadRules()
  return rules
end

local function isOneWay(lanes)
  return not lanes:find('-') or not lanes:find('+')
end

local function flipLanes(str, di)
  di = di or 2
  local res = ''
  for i = str:len(), 1, -di do
    res = res..str:sub(i-di+1, i):gsub('[-+]', function(a) return a == '-' and '+' or '-' end)
  end
  return res
end

local function createSpeedLimits(metric)
  local list = metric and {30, 50, 60, 80, 100, 120, huge} or {20, 35, 40, 50, 60, 70, huge} -- common speed limits
  local unit = metric and 3.6 or 2.24
  local baseValue = 19.444 -- 70 km/h

  gameplay_city.loadSites()

  for nid, n in pairs(map.nodes) do
    local zonesByPrio, highestPrio = gameplay_city.getZonesByPrioForPosition(n.pos)

    for lid, d in pairs(n.links) do
      if not d.speedLimit then
        local speedLimit = huge
        local useZoneSpeed = false

        -- zone speed limit
        for _, zone in ipairs(zonesByPrio[highestPrio]) do
          local zoneSpeed = zone.customFields:get('speedLimit')
          zoneSpeed = tonumber(zoneSpeed)
          if zoneSpeed then
            speedLimit = zoneSpeed
            useZoneSpeed = zone.customFields.tags.staticSpeedLimit -- if false, use the auto speed limit to compare and set the ideal speed limit for the road
          end
        end

        -- auto speed limit
        if not useZoneSpeed then
          local radius = (n.radius + map.nodes[lid].radius) * 0.5
          local highway = d.oneWay and 2 or 1
          local autoSpeed = baseValue * clamp(((radius * highway + 5) / 8) * d.drivability, 0.4, 2)

          for i, speed in ipairs(list) do
            speed = speed / unit
            if speed > autoSpeed then
              autoSpeed = i == 1 and speed or list[i - 1] / unit -- round down to previous speed in list
              speedLimit = min(speedLimit, autoSpeed)
              break
            end
          end
        end

        d.speedLimit = speedLimit
      end
    end
  end
end

local function surfaceNormal(p, r)
  --   p3
  --     \
  --      \ r
  --       \     r
  --        p - - - - p1     | - > y
  --       /                 v
  --      / r                x
  --     /
  --   p2

  r = r or 2
  local hr = 1.2 * r -- controls inclination angle up to (at least) which result is correct (arctan(1.2) ~ 50deg)

  local p1 = hr * vecUp
  p1:setAdd(p)
  p1.y = p1.y + r

  local p2 = (-1.5 * r) * vecY -- -(1 + cos(60)) * r
  p2:setAdd(p1)
  local p3 = vec3(p2)
  p2.x = p2.x + 0.8660254037844386 * r -- sin(60) * r
  p3.x = p3.x - 0.8660254037844386 * r

  p1.z = be:getSurfaceHeightBelow(p1)
  p2.z = be:getSurfaceHeightBelow(p2)
  p3.z = be:getSurfaceHeightBelow(p3)

  -- in what follows p3 becomes the normal vector
  if min(p1.z, p2.z, p3.z) < p.z - hr then
    p3:set(vecUp)
  else
    p2:setSub(p3)
    p1:setSub(p3)
    p3:set(p2.y * p1.z - p2.z * p1.y, p2.z * p1.x - p2.x * p1.z, p2.x * p1.y - p2.y * p1.x) -- p2 x p1
    p3:normalize()
  end

  return p3
end

local function loadJsonDecalMap()
  local mapNodes = map.nodes

  -- load BeamNG Waypoint data
  manualWaypoints = {}
  for _, nodeName in ipairs(scenetree.findClassObjects('BeamNGWaypoint')) do
    local o = scenetree.findObject(nodeName)
    if o and (not o.excludeFromMap) and mapNodes[nodeName] == nil then
      local radius = getSceneWaypointRadius(o)
      local pos = o:getPosition()
      manualWaypoints[nodeName] = {pos = vec3(pos), radius = radius}
      mapNodes[nodeName] = {pos = vec3(pos), radius = radius, links = {}, manual = 1}
    end
  end

  _updateProgress()

  -- load DecalRoad data
  local nodePos, nodeSqRad, stack, tmpPos = {}, {}, {}, vec3()
  for _, decalRoadName in ipairs(scenetree.findClassObjects('DecalRoad')) do
    local road = scenetree.findObject(decalRoadName)
    if road and road.drivability > 0 then
      local edgeCount = road:getEdgeCount()
      local nodeCount = road:getNodeCount()
      if max(edgeCount, nodeCount) > 1 then
        local prefix = (tonumber(decalRoadName) and 'DecalRoad'..decalRoadName..'_') or decalRoadName
        local drivability = road.drivability
        local hiddenInNavi = road.hiddenInNavi
        local roadType = road.gatedRoad and 'private' or road.type -- TODO: deprecate gatedRoad if we get more road types?
        local oneWay = road.oneWay or false
        local speedLimit = road.speedLimit
        local flipDirection = road.flipDirection or false

        if speedLimit then
          speedLimit = tonumber(speedLimit)
          if speedLimit <= 0 then
            speedLimit = nil -- auto calculate the speed limit
          end
        end

        local lanes -- string encoding for lanes (currently: dir, type)
        if road.processLanes then
          if oneWay then
            lanes = ('+a'):rep(max(1, road.lanesLeft + road.lanesRight))
          else
            lanes = ('-a'):rep(road.lanesLeft or 0)..('+a'):rep(road.lanesRight or 0) -- max(1, road.lanesLeft), max(1, road.lanesRight)
          end
        end

        if edgeCount > nodeCount and road.useSubdivisions then -- use decalRoad edge (subdivision) data to generate AI path
          local segCount = edgeCount - 1

          -- for the logic of what follows see: https://web.archive.org/web/20200802051601/https://geomalgorithms.com/a16-_decimate-1.html
          nodePos[1] = vec3(road:getMiddleEdgePosition(0))
          nodeSqRad[1] = nodePos[1]:squaredDistance(road:getLeftEdgePosition(0))
          local warningCount = 0
          if nodeSqRad[1] > 900 then warningCount = warningCount + 1 end
          local count = 1
          for i = 1, segCount-1 do
            tmpPos:set(road:getMiddleEdgePosition(i))
            local radius = tmpPos:squaredDistance(road:getLeftEdgePosition(i))
            if radius > 900 then warningCount = warningCount + 1 end
            if tmpPos:squaredDistance(nodePos[count]) >= 4 * min(nodeSqRad[count], radius) then
              count = count + 1
              nodePos[count] = vec3(tmpPos)
              nodeSqRad[count] = radius
            end
          end
          count = count + 1
          nodePos[count] = vec3(road:getMiddleEdgePosition(segCount))
          nodeSqRad[count] = nodePos[count]:squaredDistance(road:getLeftEdgePosition(segCount))
          if nodeSqRad[count] > 900 then warningCount = warningCount + 1 end
          if warningCount > 0 then log('W', "map", "Road "..prefix.." centerline to edge distance exceeding 30m on "..warningCount.." counts.") end

          local startPointIdx, endPointIdx = 1, count
          local startPoint = nodePos[1]

          count = 1
          local nodeName = nameNode(prefix, count)
          mapNodes[nodeName] = {pos = startPoint, radius = sqrt(nodeSqRad[1]), links = {}}
          local prevName = nodeName

          local ab, an = vec3(), vec3()
          repeat
            local dMax, idxMax = 0, nil
            ab:setSub2(startPoint, nodePos[endPointIdx])
            local abInvSqLen = 1 / max(ab:squaredLength(), 1e-30)
            for i = startPointIdx+1, endPointIdx-1 do
              an:setSub2(startPoint, nodePos[i])
              local sqDist = an:squaredDistance(ab * min(max(ab:dot(an) * abInvSqLen, 0), 1))
              if sqDist > dMax then
                dMax = sqDist
                idxMax = i
              end
            end

            if idxMax and dMax > max(0.0065 * nodeSqRad[idxMax], 0.04) then
              tableInsert(stack, endPointIdx)
              endPointIdx = idxMax
            else
              count = count + 1
              startPointIdx = endPointIdx
              startPoint = nodePos[startPointIdx]
              endPointIdx = table.remove(stack)

              nodeName = nameNode(prefix, count)

              local data = {drivability = drivability,
                            hiddenInNavi = hiddenInNavi,
                            oneWay = oneWay,
                            lanes = lanes,
                            speedLimit = speedLimit,
                            inNode = flipDirection and nodeName or prevName,
                            type = roadType}

              mapNodes[nodeName] = {pos = startPoint, radius = sqrt(nodeSqRad[startPointIdx]), links = {[prevName] = data}}
              mapNodes[prevName].links[nodeName] = data
              prevName = nodeName
            end
          until not endPointIdx
        else -- use decalRoad node data to generate AI path
          local prevName
          for i = 0, nodeCount - 1 do
            local nodeName = nameNode(prefix, i+1)
            mapNodes[nodeName] = {pos = vec3(road:getNodePosition(i)), radius = road:getNodeWidth(i)*0.5, links = {}}
            if prevName then
              local data = {drivability = drivability,
                            hiddenInNavi = hiddenInNavi,
                            oneWay = oneWay,
                            lanes = lanes,
                            speedLimit = speedLimit,
                            inNode = flipDirection and nodeName or prevName,
                            type = roadType}

              mapNodes[prevName].links[nodeName] = data
              mapNodes[nodeName].links[prevName] = data
            end
            prevName = nodeName
          end
        end
      end
    end
    tableClear(nodePos)
    tableClear(nodeSqRad)
    tableClear(stack)
  end
  nodePos, nodeSqRad, stack, tmpPos = nil, nil, nil, nil

  _updateProgress()

  -- load manual road segments
  local levelDir, filename, ext = path.split(getMissionFilename())
  if not levelDir then return end
  mapFilename = levelDir .. 'map.json'
  --log('D', 'map', 'loading map.json: '.. mapFilename)
  local content = readFile(mapFilename)
  if content == nil then
    --log('D', 'map', 'map system disabled due to missing/unreadable file: '.. mapFilename)
    return
  end

  _updateProgress()

  local state, jsonMap = pcall(json.decode, content)
  if state == false then
    log('W', 'map', 'unable to parse file: '.. mapFilename)
    return
  end

  if not jsonMap or not jsonMap.segments then
    log('W', 'map', 'map file is empty or invalid: '.. dumps(mapFilename))
    return
  end

  for _, v in pairs(jsonMap.segments) do
    if type(v.nodes) == 'string' then
      local nodeList = {}
      local nargs = split(v.nodes, ',')
      for _, nv in ipairs(nargs) do
        local nargs2 = split(nv, '-')
        if #nargs2 == 1 then
          tableInsert(nodeList, trim(nargs2[1]))
        elseif #nargs2 == 2 then
          local prefix1 = stringMatch(nargs2[1], "[^%d]+")
          local num1 = stringMatch(nargs2[1], "[%d]+")
          local prefix2 = stringMatch(nargs2[2], "[^%d]+")
          local num2 = stringMatch(nargs2[2], "[%d]+")
          if prefix1 ~= prefix2 then
            log('E', 'map', "segment format issue: not the same prefix: ".. tostring(nargs2[1]) .. " and " .. tostring(nargs2[2]) .. " > discarding nodes. Please fix")
          end
          for k = num1, num2 do
            tableInsert(nodeList, prefix1 .. tostring(k))
          end
        end
        v.nodes = nodeList
      end
    end

    local drivability = max(0, v.drivability or 1)
    local hiddenInNavi = v.hiddenInNavi
    local roadType = v.gatedRoad and 'private' or v.type
    local speedLimit = v.speedLimit
    local flipDirection = v.flipDirection or false
    local oneWay = v.oneWay or false

    local lanes
    if v.processLanes then
      local lanesLeft = v.lanesLeft or 0
      local lanesRight = v.lanesRight or 0
      if oneWay then
        lanes = ('+a'):rep(max(1, lanesLeft + lanesRight))
      else
        lanes = ('-a'):rep(max(1, lanesLeft))..('+a'):rep(max(1, lanesRight))
      end
    end

    for i = 2, #v.nodes do
      local wp1 = v.nodes[i-1]
      local wp2 = v.nodes[i]
      if mapNodes[wp1] == nil then log('E', 'map', "waypoint p1 not found: "..tostring(wp1)); break; end
      if mapNodes[wp2] == nil then log('E', 'map', "waypoint p2 not found: "..tostring(wp2)); break; end
      local data = {drivability = drivability,
                    hiddenInNavi = hiddenInNavi,
                    oneWay = oneWay,
                    lanes = lanes,
                    speedLimit = speedLimit,
                    inNode = flipDirection and wp2 or wp1,
                    type = roadType}
      mapNodes[wp1].links[wp2] = data
      mapNodes[wp2].links[wp1] = data
    end
  end

  _updateProgress()
end

local function is2SegMergeValid(middleNode, d1, d2)
  if d1.lanes and d2.lanes then
    if d1.inNode == d2.inNode or (d1.inNode ~= middleNode and d2.inNode ~= middleNode) then -- reverse the string of one of the edges and compare to the other
      return d1.lanes == flipLanes(d2.lanes, 2)
    else
      return d1.lanes == d2.lanes
    end
  elseif not d1.lanes and not d2.lanes then
    if d1.oneWay == d2.oneWay then
      return (d1.oneWay == false) or (not (d1.inNode == d2.inNode or (d1.inNode ~= middleNode and d2.inNode ~= middleNode)))
    else
      return false
    end
  else
    return false
  end
end

local function is3SegMergeValid(middleNode, d1, d2, dchord)
  if is2SegMergeValid(middleNode, d1, d2) then
    if d1.lanes and dchord.lanes then
      if d1.inNode == dchord.inNode then
        return d1.lanes == dchord.lanes
      elseif d2.inNode == dchord.inNode then
        return d2.lanes == dchord.lanes
      else
        return false
      end
    elseif not d1.lanes and not dchord.lanes then
      if dchord.oneWay == d1.oneWay then
        return (dchord.oneWay == false) or (d1.inNode == dchord.inNode or d2.inNode == dchord.inNode)
      else
        return false
      end
    else
      return false
    end
  else
    return false
  end
end

local function mergeNodes(n1id, n2id)
  local mapNodes = map.nodes
  if mapNodes[n2id].manual then --> TODO: what if both are manual?
    n1id, n2id = n2id, n1id
  end

  local n1 = mapNodes[n1id]
  local n2 = mapNodes[n2id]
  n1.pos = (n1.pos + n2.pos) * 0.5
  n1.radius = (n1.radius + n2.radius) * 0.5

  n1.links[n2id] = nil
  n2.links[n1id] = nil

  -- remap neighbors
  for lnid, edgeData in pairs(n2.links) do
    -- what if lnid is already linked with n1id
    local ln = mapNodes[lnid]
    if ln then
      edgeData.inNode = (edgeData.inNode == n2id and n1id) or lnid
      ln.links[n2id] = nil
      ln.links[n1id] = edgeData
      n1.links[lnid] = edgeData
    end
  end

  mapNodes[n2id] = nil

  return n1id
end

local function dedupNodes()
  -- merge closeby nodes together
  local mapNodes = map.nodes

  local nodes = tableKeys(mapNodes)
  local nodeCount = #nodes
  table.sort(nodes)

  local q = quadtree.newQuadtree(nodeCount)
  for i = 1, nodeCount do
    local k = nodes[i]
    local v = mapNodes[k]
    q:preLoad(k, pointBBox(v.pos.x, v.pos.y, v.radius))
  end
  q:build()

  _updateProgress()

  for i = 1, nodeCount do
    local n1id = nodes[i]
    local n1 = mapNodes[n1id]
    if n1 then
      if next(n1.links) or n1.manual then
        for n2id in q:queryNotNested(pointBBox(n1.pos.x, n1.pos.y, n1.radius)) do -- give me the id of every node that overlaps this bounding box
          -- should we merge nodes if they are both manual?
          if n2id ~= n1id then
            local n2 = mapNodes[n2id]
            if n2 and n1.pos:squaredDistance(n2.pos) < square(min(n1.radius, n2.radius)) then -- center of the larger is within the radius of the smaller
              q:remove(n1id, n1.pos.x, n1.pos.y)
              q:remove(n2id, n2.pos.x, n2.pos.y)
              local nid = mergeNodes(n1id, n2id) -- create a new node (in place of the two being merged) and give me its name
              local n = mapNodes[nid]
              q:insert(nid, pointBBox(n.pos.x, n.pos.y, n.radius))

              if nid ~= n1id then break end
            end
          end
        end
      else
        visLog("error", n1.pos, "isolated node: "..tostring(n1id))
        q:remove(n1id, n1.pos.x, n1.pos.y)
        mapNodes[n1id] = nil
      end
    end
  end

  _updateProgress()
end

local function edgeList()
  -- Creates a list of all the edges in the graph -> {node1, node2, edgeData (by reference)}
  local edges = {}
  local noOfEdges = 0
  local nodeDegree = {} -- number of edges incident on each node
  for n1id, node in pairs(map.nodes) do
    local degree = 0
    for n2id, edgeData in pairs(node.links) do
      if n1id ~= n2id and map.nodes[n2id] then -- why is this check needed?
        degree = degree + 1
        if n2id > n1id then -- every edge gets in the array once
          tableInsert(edges, {n1id, n2id, edgeData})
          noOfEdges = noOfEdges + 1
        end
      end
    end
    nodeDegree[n1id] = degree
  end
  edges.count = noOfEdges

  _updateProgress()

  return edges, nodeDegree
end

local function resetLinksFromEdges(edges)
  local mapNodes = map.nodes
  for _, n in pairs(mapNodes) do
    tableClear(n.links)
  end

  _updateProgress()

  for _, edge in ipairs(edges) do
    mapNodes[edge[1]].links[edge[2]] = edge[3]
    mapNodes[edge[2]].links[edge[1]] = edge[3]
  end

  _updateProgress()

  for nid, n in pairs(mapNodes) do
    if n.manual == nil and next(n.links) == nil then
      mapNodes[nid] = nil
    end
  end

  _updateProgress()
end

local function resolveTJunction(edges, q_edges, nodeDegree, i, l1n1id, l1n2id)
  local mapNodes = map.nodes

  local n1 = mapNodes[l1n1id]
  local l1n1pos, l1n1rad = n1.pos, n1.radius
  local l1n2pos = mapNodes[l1n2id].pos

  local minXnorm = -huge
  local edge, l2Xnorm
  for l_id in q_edges:queryNotNested(pointBBox(l1n1pos.x, l1n1pos.y, l1n1rad)) do
    local l2n1id, l2n2id = edges[l_id][1], edges[l_id][2]
    if l1n1id ~= l2n1id and l1n1id ~= l2n2id and l1n2id ~= l2n1id and l1n2id ~= l2n2id then -- given we know that the degree of l1n1 == 1 and than it is connected to l1n2 do we need the first two checks?
      local pos1 = l1n1pos + (l1n2pos - l1n1pos):normalized() * n1.radius -- why do this?
      local l1xn, l2xn = closestLinePoints(pos1, l1n2pos, mapNodes[l2n1id].pos, mapNodes[l2n2id].pos)
      if l2xn >= 0 and l2xn <= 1 and l1xn <= 0 and l1xn > minXnorm then -- find largest negative xnorm
        edge, minXnorm, l2Xnorm = l_id, l1xn, l2xn -- edge here is the horizontal part of the T junction
      end
    end
  end

  if edge then
    local l2n1id = edges[edge][1]
    local l2n2id = edges[edge][2]
    local l2n1pos = mapNodes[l2n1id].pos
    local l2n2pos = mapNodes[l2n2id].pos
    local l2n1rad = mapNodes[l2n1id].radius
    local l2n2rad = mapNodes[l2n2id].radius
    local l2Prad = lerp(l2n1rad, l2n2rad, l2Xnorm)
    local tempVec = (linePointFromXnorm(l2n1pos, l2n2pos, l1n1pos:xnormOnLine(l2n1pos, l2n2pos)) - l1n1pos):normalized() * (l2Prad + l1n1rad)
    if l1n1pos:squaredDistanceToLine(l2n1pos, l2n2pos) < tempVec:z0():squaredLength() then -- square(l2Prad + l1n1rad) -- Why z0?
      q_edges:remove(edge, (l2n1pos.x + l2n2pos.x) * 0.5, (l2n1pos.y + l2n2pos.y) * 0.5)
      q_edges:remove(i, (l1n1pos.x + l1n2pos.x) * 0.5, (l1n1pos.y + l1n2pos.y) * 0.5)

      local l2Data = edges[edge][3]
      local l2inNode = l2Data.inNode

      -- change the already existing edge (l2) in the edge list to update the new "end node"
      edges[edge][2] = l1n1id
      l2Data.inNode = l2inNode == l2n1id and l2n1id or l1n1id

      -- add the other half of the split l2 edge in the edge list also preserving the l2 edge data
      tableInsert(edges, {l1n1id, l2n2id, {drivability = l2Data.drivability, hiddenInNavi = l2Data.hiddenInNavi, speedLimit = l2Data.speedLimit, oneWay = l2Data.oneWay, lanes = l2Data.lanes, inNode = l2inNode == l2n2id and l2n2id or l1n1id, type = l2Data.type}})
      edges.count = edges.count + 1

      -- consider creating a new edge rather than extending the already existing one, it might distort road widths.
      local t = linePointFromXnorm(l2n1pos, l2n2pos, l2Xnorm)
      mapNodes[l1n1id].pos = t
      local avgrad = l2Prad -- + l1n1rad) * 0.5
      mapNodes[l1n1id].radius = avgrad

      local t_x, t_y = t.x, t.y
      q_edges:insert(edge, quadtree.lineBBox(l2n1pos.x, l2n1pos.y, t_x, t_y, max(l2n1rad, avgrad)))
      q_edges:insert(edges.count, quadtree.lineBBox(l2n2pos.x, l2n2pos.y, t_x, t_y, max(l2n2rad, avgrad)))
      q_edges:insert(i, quadtree.lineBBox(l1n2pos.x, l1n2pos.y, t_x, t_y, max(mapNodes[l1n2id].radius, avgrad)))

      nodeDegree[l1n1id] = nodeDegree[l1n1id] + 2
    end
  end
end

local function resolveTJunctions(edges, nodeDegree, q_edges)
  local mapNodes = map.nodes
  local i = 1
  while i <= edges.count do -- the vertical edge in the T junction
    local l1n1id = edges[i][1]
    local l1n2id = edges[i][2]
    if nodeDegree[l1n1id] == 1 then
      resolveTJunction(edges, q_edges, nodeDegree, i, l1n1id, l1n2id)
    end
    if nodeDegree[l1n2id] == 1 then
      resolveTJunction(edges, q_edges, nodeDegree, i, l1n2id, l1n1id)
    end
    i = i + 1
  end

  _updateProgress()
end

local function resolveXJunctions(edges, nodeDegree, q_edges)
  -- Resolve X junctions
  local mapNodes = map.nodes
  local junctionid = 1
  local i = 1
  while i <= edges.count do
    local l1n1id = edges[i][1]
    local l1n2id = edges[i][2]
    local l1n1pos = mapNodes[l1n1id].pos
    local l1n2pos = mapNodes[l1n2id].pos
    local l1n1rad = mapNodes[l1n1id].radius
    local l1n2rad = mapNodes[l1n2id].radius
    for l_id in q_edges:queryNotNested(quadtree.lineBBox(l1n1pos.x, l1n1pos.y, l1n2pos.x, l1n2pos.y)) do
      local l2n1id = edges[l_id][1]
      local l2n2id = edges[l_id][2]
      if l1n1id ~= l2n1id and l1n1id ~= l2n2id and l1n2id ~= l2n1id and l1n2id ~= l2n2id then
        local l2n1pos = mapNodes[l2n1id].pos
        local l2n2pos = mapNodes[l2n2id].pos
        local l2n1rad = mapNodes[l2n1id].radius
        local l2n2rad = mapNodes[l2n2id].radius
        local l1xn, l2xn = closestLinePoints(l1n1pos, l1n2pos, l2n1pos, l2n2pos)
        if l1xn > 0 and l1xn < 1 and l2xn > 0 and l2xn < 1 then
          local t1 = linePointFromXnorm(l1n1pos, l1n2pos, l1xn)
          local t2 = linePointFromXnorm(l2n1pos, l2n2pos, l2xn)
          local l1Prad = lerp(l1n1rad, l1n2rad, l1xn)
          local l2Prad = lerp(l2n1rad, l2n2rad, l2xn)
          if t1:squaredDistance(t2) < square(min(l1Prad, l2Prad) * 0.5) then
            local xid = 'autojunction_'..junctionid
            junctionid = junctionid + 1
            local xid_pos = (t1 + t2) * 0.5
            mapNodes[xid] = {pos = xid_pos, radius = (l1Prad + l2Prad) * 0.5, links = {}}
            nodeDegree[xid] = 4

            q_edges:remove(i, (l1n1pos.x + l1n2pos.x) * 0.5, (l1n1pos.y + l1n2pos.y) * 0.5)
            q_edges:remove(l_id, (l2n1pos.x + l2n2pos.x) * 0.5, (l2n1pos.y + l2n2pos.y) * 0.5)

            local l1Data = edges[i][3]
            local l1inNode = l1Data.inNode

            edges[i][2] = xid
            l1Data.inNode = l1inNode == l1n1id and l1n1id or xid

            tableInsert(edges, {xid, l1n2id, {drivability = l1Data.drivability, hiddenInNavi = l1Data.hiddenInNavi, speedLimit = l1Data.speedLimit, oneWay = l1Data.oneWay, lanes = l1Data.lanes, inNode = l1inNode == l1n2id and l1n2id or xid, type = l1Data.type}})
            edges.count = edges.count + 1
            q_edges:insert(edges.count, quadtree.lineBBox(xid_pos.x, xid_pos.y, l1n2pos.x, l1n2pos.y))
            q_edges:insert(i, quadtree.lineBBox(xid_pos.x, xid_pos.y, l1n1pos.x, l1n1pos.y))

            local l2Data = edges[l_id][3]
            local l2inNode = l2Data.inNode

            edges[l_id][2] = xid
            l2Data.inNode = l2inNode == l2n1id and l2n1id or xid

            tableInsert(edges, {xid, l2n2id, {drivability = l2Data.drivability, hiddenInNavi = l2Data.hiddenInNavi, speedLimit = l2Data.speedLimit, oneWay = l2Data.oneWay, lanes = l2Data.lanes, inNode = l2inNode == l2n2id and l2n2id or xid, type = l2Data.type}})
            edges.count = edges.count + 1
            q_edges:insert(l_id, quadtree.lineBBox(xid_pos.x, xid_pos.y, l2n1pos.x, l2n1pos.y))
            q_edges:insert(edges.count, quadtree.lineBBox(xid_pos.x, xid_pos.y, l2n2pos.x, l2n2pos.y))
            -- TODO: shouldn't we have a i = i - 1 as in resolve T junctions
            break
          end
        end
      end
    end
    i = i + 1
  end

  _updateProgress()
end

local function mergeNodesToLines(edges, nodeDegree)
  -- Merge nodes to lines if they are closeby
  local mapNodes = map.nodes
  local q = quadtree.newQuadtree()
  for k, v in pairs(mapNodes) do
    q:preLoad(k, pointBBox(v.pos.x, v.pos.y, v.radius))
  end
  q:build()

  _updateProgress()

  local i = 1
  while i <= edges.count do
    local l1n1id = edges[i][1]
    local l1n2id = edges[i][2]
    local l1n1pos = mapNodes[l1n1id].pos
    local l1n2pos = mapNodes[l1n2id].pos
    local l1n1rad = mapNodes[l1n1id].radius
    local l1n2rad = mapNodes[l1n2id].radius
    for nid in q:queryNotNested(quadtree.lineBBox(l1n1pos.x, l1n1pos.y, l1n2pos.x, l1n2pos.y)) do
      if nid ~= l1n1id and nid ~= l1n2id then -- and not mapNodes[nid].links[l1n1id] and not mapNodes[nid].links[l1n2id]
        local n = mapNodes[nid]
        local xnorm = n.pos:xnormOnLine(l1n1pos, l1n2pos)
        if xnorm > 0 and xnorm < 1 then
          local lp = linePointFromXnorm(l1n1pos, l1n2pos, xnorm)
          local linePrad = lerp(l1n1rad, l1n2rad, xnorm)
          if n.pos:squaredDistance(lp) < square(min(linePrad, n.radius)) then

            if n.manual ~= 1 or nodeDegree[nid] > 0 then
              q:remove(nid, n.pos.x, n.pos.y)
              if nodeDegree[nid] == 1 then
                n.pos = lp
                n.radius = linePrad
              else
                n.pos = (n.pos + lp) * 0.5 -- here i might be introducing an angle in straight lines
                n.radius = (linePrad + n.radius) * 0.5
              end
              q:insert(nid, pointBBox(n.pos.x, n.pos.y, n.radius))
            end

            local l1Data = edges[i][3]
            local l1inNode = l1Data.inNode

            edges[i][2] = nid
            l1Data.inNode = (l1inNode == l1n1id) and l1n1id or nid

            tableInsert(edges, {nid, l1n2id, {drivability = l1Data.drivability, hiddenInNavi = l1Data.hiddenInNavi, speedLimit = l1Data.speedLimit, oneWay = l1Data.oneWay, lanes = l1Data.lanes, inNode = (l1inNode == l1n2id and l1n2id) or nid, type = l1Data.type}})
            edges.count = edges.count + 1
            nodeDegree[nid] = nodeDegree[nid] + 2
            i = i - 1 -- this is needed given we want to recheck edges[i]
            break
          end
        end
      end
    end
    i = i + 1
  end

  _updateProgress()
end

local function optimizeEdges()
  -- triangle n1id, nid, n2id
  -- deletes n1id, n2id segment
  for nid, n in pairs(map.nodes) do
    if n.manual == nil then -- why is this check needed? We are not removing any nodes here, only edges.
      local numLinks = tableSize(n.links)
      if numLinks == 2 then
        local n1id = next(n.links)
        local n2id = next(n.links, n1id)
        local n1 = map.nodes[n1id]
        local n2 = map.nodes[n2id]
        local dchord = n1.links[n2id]
        local d1 = n.links[n1id]
        local d2 = n.links[n2id]
        if (n1.links[n2id] ~= nil or n2.links[n1id] ~= nil) and is3SegMergeValid(nid, d1, d2, dchord) and (d1.type == d2.type and d2.type == dchord.type) then
          local xnorm, dist = n.pos:xnormSquaredDistanceToLineSegment(n1.pos, n2.pos)
          if xnorm >= 0 and xnorm <= 1 and dist <= square(n.radius + lerp(n1.radius, n2.radius, xnorm)) then -- we should maybe add something compairing dist to dchord length
            dist = sqrt(dist)
            local lnPoint = linePointFromXnorm(n1.pos, n2.pos, xnorm)
            local lnPointRadius = lerp(n1.radius, n2.radius, xnorm)
            local newRadius = max(n.radius, lnPointRadius, (dist + n.radius + lnPointRadius) * 0.5)
            n.pos = n.pos + (lnPoint - n.pos):normalized() * max(0, newRadius - n.radius) -- (dist - n.radius + max(n1.radius, n2.radius)) * 0.5
            n.radius = newRadius
            n.links[n1id].drivability = min(n.links[n1id].drivability, n1.links[n2id].drivability)
            n.links[n2id].drivability = min(n.links[n2id].drivability, n1.links[n2id].drivability)
            n.links[n1id].speedLimit = min(n.links[n1id].speedLimit, n1.links[n2id].speedLimit)
            n.links[n2id].speedLimit = min(n.links[n2id].speedLimit, n1.links[n2id].speedLimit)
            if not n1.links[n2id].hiddenInNavi then
              n.links[n1id].hiddenInNavi = nil
              n.links[n2id].hiddenInNavi = nil
            end
            n1.links[n2id] = nil
            n2.links[n1id] = nil
          end
        end
      end
    end
  end

  _updateProgress()
end

local function processPrivateRoads()
  for nid, n in pairs(map.nodes) do
    -- private road processing
    if tableSize(n.links) >= 3 then
      local privateCount, otherCount = 0, 0
      for lnid, d in pairs(n.links) do -- first, get any private links that exist from the current node
        if d.type == 'private' then
          privateCount = privateCount + 1
        else
          otherCount = otherCount + 1
        end
      end

      if privateCount >= 1 and otherCount >= 2 then -- at least one private link and at least two other links
        for lnid, d in pairs(n.links) do -- next, adjust the drivability of valid private links
          if d.type == 'private' then
            n.links[lnid].drivability = 0.01 -- sets drivability enough to deter pathfinding, but allow to pass through if needed
          end
        end
      end
    end
  end

  _updateProgress()
end

local function optimizeNodes()
  -- optimize paths and throw away nodes that are below a certain displacement
  -- n1id <-> nid (to delete) <-> n2id
  local optimizedNodes = 0
  local nodesToDelete = {}
  for nid, n in pairs(map.nodes) do
    if n.manual == nil and tableSize(n.links) == 2 then
      local n1id = next(n.links)
      local n2id = next(n.links, n1id)
      local n1 = map.nodes[n1id]
      local n2 = map.nodes[n2id]

      local d1 = n1.links[nid]
      local d2 = n2.links[nid]

      if is2SegMergeValid(nid, d1, d2) and (d1.type == d2.type) then
        local xnorm = n.pos:xnormOnLine(n1.pos, n2.pos)
        if xnorm > 0 and xnorm < 1 and n.pos:squaredDistance(linePointFromXnorm(n1.pos, n2.pos, xnorm)) < square(n.radius*0.05) and
        abs(n.radius - lerp(n1.radius, n2.radius, xnorm)) < (0.1 * n.radius) then
          d1.drivability = min(d1.drivability, d2.drivability)
          d1.speedLimit = min(d1.speedLimit, d2.speedLimit)
          d1.inNode = d1.inNode == nid and n2id or n1id
          if not (d1.hiddenInNavi and d2.hiddenInNavi) then
            d1.hiddenInNavi = nil
          end
          n1.links[nid] = nil
          n1.links[n2id] = d1
          n2.links[nid] = nil
          n2.links[n1id] = d1
          optimizedNodes = optimizedNodes + 1
          nodesToDelete[optimizedNodes] = nid
        end
      end
    end
  end

  _updateProgress()

  for i = 1, optimizedNodes do
    map.nodes[nodesToDelete[i]] = nil
  end

  --if optimizedNodes > 0 then
  --  log('D', 'map', "optimized nodes: " .. optimizedNodes .. " of " .. tableSize(map.nodes) .. " total nodes")
  --end

  _updateProgress()
end

local function validateMapData(singleSided)
  local noOfNodes = 0
  local noOfValidEdges = 0
  local noOfInvalidEdges = 0
  local noOfSingleSidedEdges = 0
  local nonManualIsolatedNodes = 0
  for n1id, n1 in pairs(map.nodes) do
    noOfNodes = noOfNodes + 1
    if not singleSided and not n1.manual and tableSize(n1.links) == 0 then
      nonManualIsolatedNodes = nonManualIsolatedNodes + 1
    end
    for n2id, data in pairs(n1.links) do
      if map.nodes[n1id].links[n2id] == map.nodes[n2id].links[n1id] then
        noOfValidEdges = noOfValidEdges + 1
      else
        if map.nodes[n1id].links[n2id] == nil or map.nodes[n2id].links[n1id] == nil then
          noOfSingleSidedEdges = noOfSingleSidedEdges + 1
        else
          noOfInvalidEdges = noOfInvalidEdges + 1
        end
      end
    end
  end

  if noOfValidEdges > 0 then
    log('W', 'map', "There are "..tonumber(noOfValidEdges).." valid edges")
  end
  if noOfInvalidEdges > 0 then
    log('W', 'map', "There are "..tonumber(noOfInvalidEdges).." invalid edges")
  end
  if noOfSingleSidedEdges > 0 then
    log('W', 'map', "There are "..tonumber(noOfSingleSidedEdges).." single sided edges")
  end
  if nonManualIsolatedNodes > 0 then
    log('W', 'map', "There are "..tonumber(nonManualIsolatedNodes).." non manual isolated nodes")
  end
end

local function generateVisLog()
  visualLog = {}
  for nid, n in pairs(map.nodes) do
    local linksize = tableSize(n.links)
    if linksize == 1 then
      visLog("warn", n.pos, "dead end:"..tostring(nid))
    elseif linksize == 0 then
      visLog("error", n.pos, "isolated node:"..tostring(nid))
    end
  end

  _updateProgress()
end

local function convertToSingleSided()
  local edgeCount, nodeCount = 0, 0
  for nid, n in pairs(map.nodes) do
    nodeCount = nodeCount + 1
    local newLinks = {}
    for lid, data in pairs(n.links) do
      if data.inNode == lid and map.nodes[lid] then -- lid > nid
        edgeCount = edgeCount + 1
        newLinks[lid] = data
      end
    end
    n.links = newLinks
    n.manual = nil
  end

  _updateProgress()

  return edgeCount, nodeCount
end

local function getNodeLinkCount(nId)
  if not gp or not gp.graph[nId] then return -1 end
  return tableSize(gp.graph[nId])
end

local function loadMap(customMapNodes)
  if not be then return end
  --log('A', "map.loadMap-calledby", debug.traceback())
  --local timer = hptimer()
  profilerPushEvent('aiMap')
  M.objects = {}
  M.objectNames = {}

  -- preserve map references
  local nodes = map.nodes
  tableClear(nodes)
  tableClear(map)
  map.nodes = nodes

  setRoadRules()

  if customMapNodes then
    map.nodes = customMapNodes
  else
    loadJsonDecalMap()

    createSpeedLimits(true)

    dedupNodes()

    local edges, nodeDegree = edgeList()

    -- Create a quadtree with map edges
    local q_edges = quadtree.newQuadtree(edges.count)
    for i = 1, edges.count do
      local n1 = map.nodes[edges[i][1]]
      local n2 = map.nodes[edges[i][2]]
      q_edges:preLoad(i, quadtree.lineBBox(n1.pos.x, n1.pos.y, n2.pos.x, n2.pos.y, max(n1.radius, n2.radius)))
    end
    q_edges:build()

    _updateProgress()

    resolveTJunctions(edges, nodeDegree, q_edges)

    resolveXJunctions(edges, nodeDegree, q_edges)

    q_edges = nil

    -- resetLinksFromEdges(edges) possibly needed here

    mergeNodesToLines(edges, nodeDegree)

    resetLinksFromEdges(edges)

    dedupNodes()

    optimizeEdges()
    processPrivateRoads()
    optimizeNodes()
  end

  --validateMapData(false) --> map data sanity check
  generateVisLog()
  local edgeCount, nodeCount = convertToSingleSided()
  --validateMapData(true) --> single sided map data sanity check

  local mapNodes = map.nodes

  local nodeDrivabilities = {}
  for k, n in pairs(mapNodes) do
    nodeDrivabilities[k] = be:getTerrainDrivability(n.pos, n.radius)
    if nodeDrivabilities[k] <= 0 then nodeDrivabilities[k] = 1 end -- guard against zero values in getTerrainDrivability (case in point: void ground model used in tunnel entrances)
  end

  -- build the graph and the tree
  maxRadius = 4 -- case there are no nodes in the map i.e. next(map.nodes) == nil avoids infinite loop in findClosestRoad()
  gp = graphpath.newGraphpath()
  edgeKdTree = kdTreeBox2D.new(edgeCount)
  nodeKdTree = kdTreeBox2D.new(nodeCount)
  local edgeTab = {'','\0',''}

  for nid, n in pairs(mapNodes) do -- edges are now single sided
    local nPos = n.pos
    local radius = n.radius
    gp:setPointPositionRadius(nid, nPos, radius)
    nodeKdTree:preLoad(nid, pointBBox(nPos.x, nPos.y, radius))
    maxRadius = max(maxRadius, radius)
    local nidDrivability = nodeDrivabilities[nid]
    for lid, data in pairs(n.links) do
      local lPos = mapNodes[lid].pos
      local edgeDrivability = min(1, max(1e-30, (nodeDrivabilities[lid] + nidDrivability) * 0.5 * data.drivability))
      if data.oneWay then
        local inNode = data.inNode
        local outNode = inNode == nid and lid or nid
        gp:uniEdge(inNode, outNode, nPos:distance(lPos) / edgeDrivability, data.drivability, data.speedLimit)
      else
        gp:bidiEdge(nid, lid, nPos:distance(lPos) / edgeDrivability, data.drivability, data.speedLimit)
      end
      edgeTab[1], edgeTab[3] = nid, lid
      edgeKdTree:preLoad(table.concat(edgeTab), quadtree.lineBBox(nPos.x, nPos.y, lPos.x, lPos.y, radius))
    end

    n.normal = surfaceNormal(nPos, radius * 0.5)
  end

  maxRadius = min(15, maxRadius)

  edgeKdTree:build()

  _updateProgress()

  nodeKdTree:build()

  _updateProgress()

  -- Find closest mapNode to a manualWaypoint not in the map and create Alias
  local nodeAliases = {}
  if not customMapNodes then
    for nodeName, v in pairs(manualWaypoints) do
      if mapNodes[nodeName] == nil or gp.graph[nodeName] == nil then
        local closestNode
        local minDist = huge
        local vPos = v.pos
        for item_id in nodeKdTree:queryNotNested(pointBBox(vPos.x, vPos.y, v.radius)) do
          if item_id ~= nodeName then -- what if the closest node is also an orphan?
            local dist = mapNodes[item_id].pos:squaredDistance(vPos)
            if dist < minDist then
              closestNode = item_id
              minDist = dist
            end
          end
        end
        nodeAliases[nodeName] = closestNode
      end
      manualWaypoints[nodeName] = 1
    end
  end
  map.nodeAliases = nodeAliases

  _updateProgress()

  buildSerial = (buildSerial or -1) + 1
  map.buildSerial = buildSerial

  --log('D', 'map', "generating roads took " .. string.format("%2.3f ms", timer:stopAndReset()))
  be:sendToMailbox("mapData", lpack.encodeBin(
    {
      nodeAliases = map.nodeAliases,
      maxRadius = maxRadius,
      graphData = gp:export(edgeCount),
      edgeKdTree = edgeKdTree:export(),
      rules = rules
    }
  ))

  if core_trafficSignals then core_trafficSignals.loadSignals() end
  guihooks.trigger("NavigationMapChanged", map)
  profilerPopEvent() -- aiMap

  _updateProgress()
  extensions.hook("onNavgraphReloaded")
end

-- this is also in vehicle/mapmgr.lua
local function findClosestRoad(pos)
  -- find road (edge) closest to "position" and return the nodes ids (closestRoadNode1, closestRoadNode2) of that edge and distance to it.
  if edgeKdTree == nil then return end
  local mapNodes = map.nodes
  local closestRoadNode1, closestRoadNode2, closestDist
  local searchRadius = maxRadius
  repeat
    closestDist = searchRadius * searchRadius
    for item_id in edgeKdTree:queryNotNested(pointBBox(pos.x, pos.y, searchRadius)) do
      local i = stringFind(item_id, '\0')
      local n1id = stringSub(item_id, 1, i-1)
      local n2id = stringSub(item_id, i+1, #item_id)
      local curDist = pos:squaredDistanceToLineSegment(mapNodes[n1id].pos, mapNodes[n2id].pos)
      if curDist < closestDist then
        closestDist = curDist
        closestRoadNode1 = n1id
        closestRoadNode2 = n2id
      end
    end
    searchRadius = searchRadius * 2
  until closestRoadNode1 or searchRadius > 200

  return closestRoadNode1, closestRoadNode2, sqrt(closestDist)
end

local function compare2nd(a,b)
  return a[2] < b[2]
end

local function getPath(start, target, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff)
  -- arguments:
  -- start: starting node
  -- target: target node
  -- cutOffDrivability: penalize roads with drivability <= cutOffDrivability
  -- dirMult: amount of penalty to impose to path if it does not respect road
  --          legal directions (should be larger than 1). If equal to nil or 1 then it means no penalty.
  -- penaltyAboveCutoff: penalty multiplier for roads above the drivability cutoff
  -- penaltyBelowCutoff: penalty multiplier for roads below the drivability cutoff
  if gp == nil then return {} end
  return gp:getFilteredPath(start, target, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff)
end

local function getPointNodePath(start, target, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wZ)
  -- Shortest path between a point and a node or vice versa.
  -- start/target: either start or target should be a node name, the other a vec3 point
  -- cutOffDrivability: penalize roads with drivability <= cutOffDrivability
  -- dirMult: amount of penalty for traversing edges in the 'illegal direction' (reasonable penalty values: 1e3-1e4). 1 = no penalty
  --          If equal to nil or 1 then it means no penalty.
  -- penaltyAboveCutoff: penalty multiplier for roads above the drivability cutoff
  -- penaltyBelowCutoff: penalty multiplier for roads below the drivability cutoff
  -- wZ: number. When higher than 1 distance minimization is biased to minimizing z diamension more so than x, y.

  if gp == nil then return {} end
  return gp:getPointNodePath(start, target, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wZ)
end

local function getNodesFromPathDist(path, dist)
  -- finds and returns nodes and an xnorm based on distance along path
  local mapNodes = map.nodes
  if not mapNodes or not path or not path[2] then return end
  local pathCount = #path
  dist = dist or huge

  for i = 1, pathCount - 1 do
    local n1, n2 = path[i], path[i + 1]
    if mapNodes[n1] and mapNodes[n2] then
      local length = mapNodes[n1].pos:distance(mapNodes[n2].pos)

      if dist > length then
        dist = dist - length
      else
        return n1, n2, clamp(dist / (length + 1e-30), 0, 1)
      end
    end
  end

  return path[pathCount - 1], path[pathCount], 1
end

local function getPathLen(path)
  -- returns the path length
  local mapNodes = map.nodes
  if not (mapNodes and path) then return 0 end
  local pathLen = 0
  for i = 2, #path do pathLen = pathLen + mapNodes[path[i]].pos:distance(mapNodes[path[i-1]].pos) end
  return pathLen
end

local function startPosLinks(position, wZ)
  --log('A','map', 'findClosestRoad called with '..position.x..','..position.y..','..position.z)
  wZ = wZ or 1 -- zbias
  local nodePositions = gp.positions
  local nodeRadius = gp.radius
  local costs = table.new(0, 32)
  local xnorms = table.new(0, 32)
  local seenEdges = table.new(0, 32)
  local j, names = 0, table.new(32, 0)
  local searchRadius = maxRadius * 5
  local tmpVec = vec3()
  local edgeVec = vec3()

  local sortComparator = function(n1, n2) return costs[n1] > costs[n2] end

  return function ()
    repeat
      if j > 0 then
        local name = names[j]
        names[j] = nil
        j = j - 1
        return name, costs[name], xnorms[name]
      else
        for item_id in edgeKdTree:queryNotNested(pointBBox(position.x, position.y, searchRadius)) do
          if not seenEdges[item_id] then
            seenEdges[item_id] = true
            local i = stringFind(item_id, '\0')
            local n1id = stringSub(item_id, 1, i-1)
            local n2id = stringSub(item_id, i+1, #item_id)
            local n1Pos = nodePositions[n1id]
            edgeVec:setSub2(nodePositions[n2id], n1Pos)
            tmpVec:setSub2(position, n1Pos) -- node1ToPosVec
            local xnorm = min(1, max(0, edgeVec:dot(tmpVec) / (edgeVec:squaredLength() + 1e-30)))
            local key
            if xnorm == 0 then
              key = n1id
            elseif xnorm == 1 then
              key = n2id
            else
              key = {n1id, n2id}
              xnorms[key] = xnorm -- we only need to store the xnorm if 1 < xnorm < 0
            end
            if not costs[key] then
              edgeVec:setScaled(xnorm)
              tmpVec:setSub(edgeVec) -- distVec
              tmpVec:setScaled(max(0, 1 - max(nodeRadius[n1id], nodeRadius[n2id]) / (tmpVec:length() + 1e-30)))
              costs[key] = square(square(tmpVec.x) + square(tmpVec.y) + square(wZ * tmpVec.z))
              j = j + 1
              names[j] = key
            end
          end
        end

        table.sort(names, sortComparator)

        searchRadius = searchRadius * 2
      end
    until searchRadius > 2000

    return nil, nil, nil
  end
end

local function getPointToPointPath(startPos, targetPos, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wD, wZ)
  -- startPos: path source position
  -- targetPos: target position (vec3)
  -- cutOffDrivability: penalize roads with drivability <= cutOffDrivability
  -- dirMult: amount of penalty to impose to path if it does not respect road legal directions (should be larger than 1 typically >= 10e4).
  --          If equal to nil or 1 then it means no penalty.
  -- penaltyAboveCutoff: penalty multiplier for roads above the drivability cutoff
  -- penaltyBelowCutoff: penalty multiplier for roads below the drivability cutoff
  -- wZ: number (typically >= 1). When higher than 1 destination node of optimum path will be biased towards minimizing height difference to targetPos.
  -- wD has been depricated (left here for backwards compatibility)

  if gp == nil then return {} end
  wZ = wZ or 4
  local iter = startPosLinks(startPos, wZ)
  return gp:getPointToPointPath(startPos, iter, targetPos, cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wZ)
end

local function saveSVG(filename)
  local svg = require('libs/EzSVG/EzSVG')

  local terrain = scenetree.findObject(scenetree.findClassObjects('TerrainBlock')[1])
  local terrainPosition = vec3(terrain:getPosition())

  local svgDoc = svg.Document(2048, 2048, svg.gray(255))
  local lines = svg.Group()

  local m = map
  if not m or not next(m.nodes) then return end
  -- draw edges
  for nid, n in pairs(m.nodes) do
    for lid, dif in pairs(n.links) do
      local p1 = n.pos - terrainPosition
      local p2 = m.nodes[lid].pos - terrainPosition

      -- TODO: add proper fading between some colors
      local typeColor = 'black'
      if dif < 0.9 and dif >= 0 then
        typeColor = svg.rgb(170, 68, 0) -- dirt road = brown
      end

      lines:add(svg.Polyline({2048 - p1.x, p1.y, 2048 - p2.x, p2.y}, {
        fill = 'none',
        stroke = typeColor,
        stroke_width = n.radius * 2,
        stroke_opacity=0.4,
      }))
    end
  end
  svgDoc:add(lines)

  -- draw nodes
  local nodes = svg.Group()
  for nid, n in pairs(m.nodes) do
    local p = n.pos - terrainPosition
    nodes:add(svg.Circle(2048 - p.x, p.y, n.radius, {
      fill = 'black',
      fill_opacity=0.4,
      stroke = 'none',
    }))
  end
  svgDoc:add(nodes)

  svgDoc:writeTo(filename or 'map.svg')
end

local function updateGFX(dtReal)
  be:sendToMailbox("objUpdate", lpack.encodeBin(M.objects))
  objectsReset = true

  delayedLoad:update(dtReal)
end

local function Mload()
  if loadedMap then return end
  loadedMap = true
  loadMap()
end

local function assureLoad()
  if not loadedMap then
    loadMap()
  end
  loadedMap = false
end

local function onMissionLoaded()
  loadedMap = false
end

local function onWaypoint(args)
  --print('onWaypoint')
  --dump(args)

  -- local aiData = {subjectName = args.subjectName, triggerName = args.triggerName, event = args.event, mode = args.mode}
  -- args.subject:queueLuaCommand('ai.onWaypoint(' .. serialize(aiData) .. ')')

  --[[
  --if args.triggerName
  local triggerName = string.match(args.triggerName, "(%a*)(%d+)")
  local triggerNum = string.match(args.triggerName, "(%d+)")

  local v = scenetree.findObject(args.subjectName)
  local nextTrigger = scenetree.findObject(triggerName .. (triggerNum + 1))
  if args.subject and nextTrigger then
    --local ppos = player:getPosition()
    local tpos = nextTrigger:getPosition()
    --print("player pos: " .. tostring(ppos))
    --print("trigger pos: " .. tostring(tpos))
    local l = 'ai.setTarget('..tostring(tpos)..')'
    --print(l)
    args.subject:queueLuaCommand(l)

  end
  ]]

  --guihooks.trigger('Message', {msg = 'Trigger "' .. args.triggerName .. '" : ' .. args.event, time = 1})
end

-- TODO: please fix these functions, so users can interactively add/remove/modify the waypoints in the editor and directly see changes.
local function onAddWaypoint(wp)
  --print("waypoint added: " .. tostring(wp))
  if isEditorEnabled then
    delayedLoad:callAfter(0.5, loadMap)
  end
end

local function onRemoveWaypoint(wp)
  --print("waypoint removed: " .. tostring(wp))
  if isEditorEnabled then
    delayedLoad:callAfter(0.5, loadMap)
  end
end

local function onModifiedWaypoint(wp)
  --print("waypoint modified: " .. tostring(wp))
  if isEditorEnabled then
    delayedLoad:callAfter(0.5, loadMap)
  end
end

local function onFilesChanged(files)
  for _,v in pairs(files) do
    if v.filename == mapFilename then
      log('D', 'map', "map.json changed, reloading map")
      loadMap()
      return
    end
  end
end

local function request(objId, objbuildSerial)
  if objbuildSerial ~= buildSerial then
    be:queueObjectLua(objId, string.format("mapmgr.setMap(%d)", buildSerial))

    if core_trafficSignals then -- this is set here to always get updated signal states
      local signalsDict = core_trafficSignals.getSignalsDict()
      if signalsDict then
        be:queueObjectLua(objId, string.format("mapmgr.setSignals(%q)", serialize(signalsDict)))
      end
    end
  end
end

local function updateDrivabilities(changeSet)
  -- changeSet format {nodeA1, nodeB1, drivability1, nodeA2, nodeB2, drivability2, ...}
  if #changeSet % 3 ~= 0 then return end

  local hasChanged = false
  for i = 1, #changeSet, 3 do
    local newDrivability = changeSet[i+2]
    local edge = gp.graph[changeSet[i]][changeSet[i+1]]
    if edge.drivability ~= newDrivability then
      edge.len = edge.len * max(1e-30, edge.drivability) / max(1e-30, newDrivability)
      edge.drivability = newDrivability
      hasChanged = true
    end
  end

  if hasChanged then -- send data if there is at least one change and one object
    serializedMap = nil -- old serialization no longer valid. Needed so that map is serialized anew if a new vehicles requests it
    if next(M.objects) then
      local serializedChangeSet = string.format("mapmgr.updateDrivabilities(%q)", lpack.encode(changeSet))
      for objId, _ in pairs(M.objects) do
        be:queueObjectLua(objId, serializedChangeSet)
      end
    end
  end
end

local function onSerialize()
  return {isEditorEnabled, buildSerial}
end

local function onDeserialize(s)
  isEditorEnabled, buildSerial = unpack(s)
  buildSerial = buildSerial or -1
end

local function setEditorState(enabled)
  isEditorEnabled = enabled
end

local function setState(newState)
  tableMerge(M, newState)
end

local function getState()
  for k, v in pairs(M.objectNames) do
    if type(k) == 'string' then
      if M.objects[v] then
        M.objects[v].name = k
      end
    end
  end
  for k, v in pairs(M.objects) do
    v.name = v.name or ''
    local vehicle = be:getObjectByID(k)
    v.licensePlate = vehicle and vehicle:getDynDataFieldbyName("licenseText", 0) or dumps(k)
  end
  return M
end

local function getMap()
  return map
end

local function getGraphpath()
  return gp
end

local function getManualWaypoints()
  return manualWaypoints
end

local function getTrackedObjects()
  return M.objects
end

-- recieves vehicle data from vehicles
local function objectData(objId, isactive, damage, states, objectCollisions)
  if objectsReset then
    tableClear(M.objects)
    objectsReset = false
  end
  local object = be:getObjectByID(objId)
  if object and M.objects[objId] == nil then
    local obj = objectsCache[objId] or {view = true, pos = vec3(), vel = vec3(), dirVec = vec3(), dirVecUp = vec3()}
    local uiState = object.uiState and tonumber(object.uiState)
    objectsCache[objId] = obj
    M.objects[objId] = obj

    obj.id = objId
    obj.active = isactive
    obj.damage = damage
    obj.states = states or emptyTable
    obj.uiState = uiState
    obj.objectCollisions = objectCollisions or emptyTable
    obj.pos:set(object:getPosition())
    obj.vel:set(object:getVelocity())
    obj.dirVec:set(object:getDirectionVector())
    obj.dirVecUp:set(object:getDirectionVectorUp())
  end
end

-- used to add explicit vehicle data
local function tempObjectData(objId, isactive, pos, vel, dirVec, dirVecUp, damage, objectCollisions)
  if objectsReset then
    tableClear(M.objects)
    objectsReset = false
  end

  local obj = objectsCache[objId] or {id = objId, view = true, active = isactive, pos = pos, vel = vel,
  dirVec = dirVec, dirVecUp = dirVecUp, damage = damage, objectCollisions = objectCollisions}
  objectsCache[objId] = obj
  M.objects[objId] = obj

  obj.id = objId
  obj.active = isactive
  obj.damage = damage
  obj.objectCollisions = objectCollisions or {}
  obj.pos:set(pos)
  obj.vel:set(vel)
  obj.dirVec:set(dirVec)
  obj.dirVecUp:set(dirVecUp)
end

local function setNameForId(name, id)
  M.objectNames[name] = id
end

local function isCrashAvoidable(objectID, pos, radius)
  -- check if position (pos) with dimension radius is safe to spawn given object (objectID) in motion

  local obj = be:getObjectByID(objectID)
  if not obj then return true end

  radius = radius or 7.5

  local relativePos = pos - vec3(obj:getSpawnWorldOOBB():getCenter())
  local relativePosLen = relativePos:length()
  local objVel = vec3(obj:getVelocity())
  local relativeSpeed = max(objVel:dot(relativePos / (relativePosLen + 1e-30)), 0)
  local ff = 0.5 * vecUp:dot(vec3(obj:getDirectionVectorUp())) -- frictionCoeff * Normal Force.
  local objDirVec = vec3(obj:getDirectionVector())
  local fw = vecUp:dot(sign(objVel:dot(objDirVec)) * objDirVec) -- road grade force

  -- Prevents division by zero gravity
  local gravity = core_environment.getGravity()
  gravity = max(0.1, abs(gravity)) * sign2(gravity)

  local a = max(0, -gravity * (ff + fw))
  return relativePosLen > relativeSpeed * relativeSpeed / (2 * a) + obj:getInitialLength() * 0.5 + radius
end

-- public interface
M.updateGFX = updateGFX
M.objectData = objectData
M.tempObjectData = tempObjectData
M.setNameForId = setNameForId
M.onWaypoint = onWaypoint
M.reset = loadMap
M.load = Mload
M.assureLoad = assureLoad
M.onMissionLoaded = onMissionLoaded
M.request = request
M.onAddWaypoint = onAddWaypoint
M.onRemoveWaypoint = onRemoveWaypoint
M.onModifiedWaypoint = onModifiedWaypoint
M.onFilesChanged = onFilesChanged
M.setState = setState
M.getState = getState
M.setEditorState = setEditorState
M.getMap = getMap
M.getGraphpath = getGraphpath
M.getRoadRules = getRoadRules
M.getManualWaypoints = getManualWaypoints
M.getTrackedObjects = getTrackedObjects
M.findClosestRoad = findClosestRoad
M.getPath = getPath
M.getNodesFromPathDist = getNodesFromPathDist
M.getPathLen = getPathLen
M.getPointNodePath = getPointNodePath
M.getPointToPointPath = getPointToPointPath
M.saveSVG = saveSVG
M.onSerialize = onSerialize
M.onDeserialize = onDeserialize
M.surfaceNormal = surfaceNormal
M.isCrashAvoidable = isCrashAvoidable
M.nameNode = nameNode
M.getNodeLinkCount = getNodeLinkCount
M.updateDrivabilities = updateDrivabilities

-- backward compatibility fixes below
setmetatable(M, {
  __index = function(tbl, key)
    if key == 'map' then
      if not M.warnedMapBackwardCompatibility then
        log('E', 'map', 'map.map API is deprecated. Please use map.getMap()')
        M.warnedMapBackwardCompatibility = true
      end
      return M.getMap()
    end
    return rawget(tbl, key)
  end
})

return M