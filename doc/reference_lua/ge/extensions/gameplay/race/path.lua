-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:getNextUniqueIdentifier()
  self._uid = self._uid + 1
  return self._uid
end

local idFields = {'startNode','endNode','defaultStartPosition', 'reverseStartPosition','rollingStartPosition','rollingReverseStartPosition'}
local prefabFields = {"prefabs","forwardPrefabs","reversePrefabs"}
function C:init(name)
  self._uid = 0
  self.name = "Path"
  self.description = "Description"
  self.authors = "Anonymous"
  self.date = os.time()
  self.difficulty = 24

  for _, f in ipairs(idFields) do
    self[f] = -1
  end
  for _, p in ipairs(prefabFields) do
    self[p] = {}
  end

  self.id = self:getNextUniqueIdentifier()
  self.pathnodes = require('/lua/ge/extensions/gameplay/util/sortedList')("pathnodes", self, require('/lua/ge/extensions/gameplay/race/pathnode'))
  self.segments = require('/lua/ge/extensions/gameplay/util/sortedList')("segments", self, require('/lua/ge/extensions/gameplay/race/segment'))
  self.startPositions = require('/lua/ge/extensions/gameplay/util/sortedList')("startPositions", self, require('/lua/ge/extensions/gameplay/race/startPosition'))

  self.pacenotes = require('/lua/ge/extensions/gameplay/util/sortedList')("pacenotes", self, require('/lua/ge/extensions/gameplay/race/pacenote'))

  self.pathnodes.postCreate = function(o)
    if self.startNode == -1 then
      self.startNode = o.id
    end
  end
  self.startPositions.postCreate = function(o)
    if self.defaultStartPosition == -1 then
      self.defaultStartPosition = o.id
    end
  end
  self.defaultLaps = 1
  self.config = {}

  self.hideMission = false
end


-- this creates an automatic configuration.
-- It takes the first (= lowest ID) pathnode and creates a path from there, using segments.
-- assumes there is only one "first" segment.
function C:autoConfig()
  local config = {}
  local startNode = self.pathnodes.objects[self.startNode]
  if startNode.missing then
    self.config = {}
    return
  end

  config.startNode = startNode.id
  -- use the first segment that starts with startNode as start.
  config.startSegments = self:findSegments(startNode.id, nil)
  config.finalSegments = {}

  -- for every segment, find it's natual successors and predecessors
  config.graph = {}
  config.branching = false
  config.closed = false
  for i, seg in pairs(self.segments.objects) do
    if seg:isValid() then
      local succ = self:findSegments(seg.to, nil)
      local pred = self:findSegments(nil, seg.from)
      local lastInLap = (#succ == 0) or (seg.to == self.startNode)

      config.graph[i] = {
        id = i,
        lastInLap = lastInLap,
        successors = succ,
        predecessors = pred,
        targetNode = reverse and seg.from or seg.to,
        nextVisibleSegments = {},
        overNextVisibleSegments = {},
        overNextCrossesFinish = false,
      }
      if #succ > 1 then
        config.branching = true
      end
      if seg.to == self.startNode then
        config.closed = true
      end
      if lastInLap then
        table.insert(config.finalSegments,i)
      end
    end
  end

  -- for every segment, follow the graph backwards and "color" all segments
  for _, elem in pairs(config.graph) do
    local tn = self.pathnodes.objects[elem.targetNode]
    if tn.visible then
      -- flag for if we crossed the finish line (needed for final lap / overnext markers)
      local crossedFinishLine = false
      -- color this segment itself
      table.insert(elem.nextVisibleSegments, elem.id)
      -- gather all predecessors into working list
      local open = {}
      local done = {}
      for _, p in ipairs(elem.predecessors) do
        table.insert(open, config.graph[p])
      end
      -- while we still have a working list, color it and add those predecessors to working list
      while next(open) do
        local cur = open[1]
        -- if that segment is already done or has a visible node, ignore it
        if not done[cur.id] and not self.pathnodes.objects[cur.targetNode].visible then
          -- color segment
          table.insert(cur.nextVisibleSegments, elem.id)
          -- add all predecessors we have node done yet
          for _, p in ipairs(cur.predecessors) do
            if not done[p] then
              table.insert(open, config.graph[p])
            end
          end
        end
        -- done this element, remove from working list
        done[cur.id] = true
        table.remove(open, 1)
      end
    end
  end

  -- now do a similar thing to get the overNextVisibleNodes,
  for _, elem in pairs(config.graph) do
    for _, nvs in ipairs(elem.nextVisibleSegments) do
      for _, succ in ipairs(config.graph[nvs].successors) do
        -- add all nextVisibleSegments of the successors of the initial nextVisibleSegments into overNextVisibleSegments.
        for _, n in ipairs(config.graph[succ].nextVisibleSegments) do
          table.insert(elem.overNextVisibleSegments, n)
        end
      end
      -- if the nextVisibleSegment is the finish line, store it
      if config.graph[nvs].lastInLap then
        elem.overNextCrossesFinish = true
      end
    end
  end

  -- if we are not branching, get the "linear" track
  config.linearSegments = {}
  if not config.branching then
    local done = false
    local last = config.startSegments[1]
    -- index for linear path
    local CPIndex = 1
    table.insert(config.linearSegments, startNode.id)
    if last then
      table.insert(config.linearSegments, config.graph[last].targetNode )
      while not done do
        config.graph[last].linearCPIndex = CPIndex
        CPIndex = CPIndex +1
        local nextId = config.graph[last].overNextVisibleSegments[1]
        if not nextId then
          done = true
        else
          table.insert(config.linearSegments, config.graph[nextId].targetNode)
          if nextId == config.startSegments[1] then done = true end
          last = nextId
        end
      end
    end
  end

  -- find the final WP
  config.startSegments = self:findSegments(startNode.id, nil)

  -- find pacenotes for each segment
  config.segmentToPacenotes = {}
  for id, seg in pairs(self.segments.objects) do
    config.segmentToPacenotes[id] = {}
    for _, pn in ipairs(self.pacenotes.sorted) do
      if self.segments.objects[pn.segment].missing or pn.segment == id then
        table.insert(config.segmentToPacenotes[id], pn.id)
      end
    end
  end

  self.config = config
end

function C:findSegments(from, to)
  local ret = {}
  for _, seg in ipairs(self.segments.sorted) do
    if seg:isValid() then
      local add = true
      if from and seg.from ~= from then
        add = false
      end
      if to and seg.to ~= to then
        add = false
      end
      if add then
        table.insert(ret, seg.id)
      end
    end
  end
  return ret
end

---- Debug and Serialization

function C:drawDebug()
  self.pathnodes:drawDebug()
  self.segments:drawDebug()
  self.startPositions:drawDebug()
  self.pacenotes:drawDebug()
end

local route = require('/lua/ge/extensions/gameplay/route/route')()
function C:drawAiRouteDebug()
  self:autoConfig()
  self:getAiPath()
  local positions = {vec3(self.pathnodes.objects[self.startNode].pos)}
  for i, name in ipairs(self.aiPath) do
    positions[i+1] = map.getMap().nodes[name].pos
  end

  route:setupPathMulti(positions)
  for i, e in ipairs(route.path) do
    local clr = rainbowColor(#route.path, i, 1)
    debugDrawer:drawSphere(vec3(e.pos), 1, ColorF(clr[1], clr[2], clr[3], 0.6))
    if e.wp then
      --debugDrawer:drawTextAdvanced(e.pos, String(e.wp), ColorF(1,1,1,1), true, false, ColorI(0,0,0,192))
    end
    if i > 1 then
      --debugDrawer:drawLine(vec3(e.pos), vec3(route.path[i-1].pos), )
      debugDrawer:drawSquarePrism(
        vec3(e.pos), vec3(route.path[i-1].pos),
        Point2F(2,0.5),
        Point2F(2,0.5),
        ColorF(clr[1], clr[2], clr[3], 0.4))
    end
  end
end

function C:getAiPath(verbose)
  self.aiPath = {}
  local currentSegment = self.config.graph[self.config.startSegments[1]]
  while currentSegment ~= nil do
    if #currentSegment.successors > 1 then -- no AI path for branches
      if verbose then log('E', 'race', 'Branched paths can not be used for AI path!') end
      self.aiPath = {}
      return self.aiPath
    end

    local nodePos = vec3(self.pathnodes.objects[currentSegment.targetNode].pos)
    local name_a, name_b, distance = map.findClosestRoad(nodePos)
    if not name_a then -- no AI path due to no navgraph node
      if verbose then log('E', 'race', 'Unable to find road node for AI path!') end
      self.aiPath = {}
      return self.aiPath
    end

    local a, b = map.getMap().nodes[name_a], map.getMap().nodes[name_b]
    if clamp(nodePos:xnormOnLine(a.pos, b.pos), 0, 1) > 0.5 then -- if we are closer to point b, swap it around
      name_a, name_b = name_b, name_a
    end

    table.insert(self.aiPath, name_a)
    if currentSegment.lastInLap then return self.aiPath end
    currentSegment = self.config.graph[currentSegment.successors[1]]
  end
  return self.aiPath
end

function C:findStartPositionByName(name)
  for _, sp in ipairs(self.startPositions.sorted) do
    if sp.name == name then
      return sp
    end
  end
  return nil
end

function C:onSerialize()
  local ret = {
    name = self.name,
    description = self.description,
    authors = self.authors,
    difficulty = self.difficulty,
    date = os.time() ,
    defaultLaps = self.defaultLaps,
    pathnodes = self.pathnodes:onSerialize(),
    segments = self.segments:onSerialize(),
    pacenotes = self.pacenotes:onSerialize(),
    startNode = self.startNode,
    endNode = self.endNode,
    startPositions = self.startPositions:onSerialize(),
    classification = self:classify(),
    prefabs = self.prefabs,
    forwardPrefabs = self.forwardPrefabs,
    reversePrefabs = self.reversePrefabs,
    hideMission = self.hideMission
  }

  for _, f in ipairs(idFields) do
    ret[f] = self[f]
  end
  for _, p in ipairs(prefabFields) do
    ret[p] = self[p]
  end

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  self.name = data.name or ""
  self.description = string.gsub(data.description or "", "\\n", "\n")
  self.authors = data.authors or "Anonymous"
  self.difficulty = data.difficulty or 0
  self.date = data.date or nil
  self.defaultLaps = data.defaultLaps or 1
  self.pathnodes:clear()
  self.segments:clear()
  self.startPositions:clear()
  local oldIdMap = {}
  self.startPositions:onDeserialized(data.startPositions, oldIdMap)
  self.pathnodes:onDeserialized(data.pathnodes, oldIdMap)
  self.segments:onDeserialized(data.segments, oldIdMap)
  self.pacenotes:onDeserialized(data.pacenotes, oldIdMap)
  for _, f in ipairs(idFields) do
    self[f] = oldIdMap[data[f]] or -1
  end
  for _, p in ipairs(prefabFields) do
    self[p] = data[p] or {}
  end
  if data.hideMission ~= nil then
    self.hideMission = data.hideMission
  end
end

function C:copy()
  local cpy = require('/lua/ge/extensions/gameplay/race/path')('Copy of ' .. self.name)
  cpy.onDeserialized(self.onSerialize())
  return cpy
end

-- switches start/endNode, all segments and direction of pathnodes. startPositions are not changed.
function C:reverse()
  if self.endNode ~= -1 then
    self.startNode, self.endNode = self.endNode, self.startNode
  end
  for _, s in pairs(self.segments.objects) do
    s.from, s.to = s.to, s.from
  end
  self.isReversed = not self.isReversed
end

function C:fromLapConfig(lapConfig, closed)
  local path = self
  path:init("New Race")
  local nodeToId = {}

  -- parse all branches and all cps from the config to get all CP infos
  for _, cp in ipairs(lapConfig) do
    if not nodeToId[cp] then
      local pn = path.pathnodes:create(cp)
      local info = extensions.scenario_scenarios.getScenario().nodes[cp]
      pn.pos = vec3(info.pos)
      pn.radius = info.radius
      pn:setNormal(info.rot)
      nodeToId[cp] = pn.id
    end
  end
  local order = deepcopy(lapConfig)
  if closed then
    table.insert(order, order[1])
  end

  for i = 1, #order-1 do
    local seg = path.segments:create("Seg " .. i.."/"..(i+1))
    seg:setFrom(nodeToId[order[i]])
    seg:setTo(nodeToId[order[i+1]])
  end
end

function C:fromCheckpointList(list, closed)
  local path = self
  path:init("New Race")
  local nodeToId = {}

  -- parse all branches and all cps from the config to get all CP infos
  for _, cp in ipairs(list) do
    if cp then
      local name = cp:getName()
      if name == "" or name == nil then name = cp:getInternalName() end
      local pn = path.pathnodes:create(name)
      local rot = nil
      if cp:getField('directionalWaypoint',0) == '1' then
        pn:setNormal(quat(cp:getRotation())*vec3(1,0,0))
      else
        pn:setNormal(nil)
      end
      pn.pos = vec3(cp:getPosition())
      local scl = cp:getScale()
      pn.radius = math.max(scl.x, scl.y, scl.z)

      nodeToId[cp:getID()] = pn.id
    end
  end
  local order = deepcopy(list)
  if closed then
    table.insert(order, order[1])
  end

  for i = 1, #order-1 do
    local seg = path.segments:create("Seg " .. i.."/"..(i+1))
    seg:setFrom(nodeToId[order[i]:getID()])
    seg:setTo(nodeToId[order[i+1]:getID()])
  end
end


local autoPrefabs = {
  prefabs = '',
  reversePrefabs = '_reverse',
  forwardPrefabs = '_forward'
}
local prefabExt = {'.prefab', '.prefab.json'}
function C:fromTrack(trackInfo, usePrefabs)
  local path = self
  path:init("New Race")
  path.hideMission = trackInfo.hideMission or false
  local nodeToId = {}

  local spawnedPrefabs = {}

  if usePrefabs then
    local merged = {}
    for _, p in ipairs(trackInfo.prefabs or {}) do table.insert(merged, p) end
    for _, p in ipairs(trackInfo.forwardPrefabs or {}) do table.insert(merged, p) end
    for _, p in ipairs(trackInfo.reversePrefabs or {}) do table.insert(merged, p) end

    -- add automatic prefabs only if they exist
    for list, suf in pairs(autoPrefabs) do
      for _, ext in ipairs(prefabExt) do
        local file = trackInfo.directory..trackInfo.trackName..suf..ext
        if FS:fileExists(file) then
          table.insert(merged, file)
        end
      end
    end
    for _, p in ipairs(merged) do
      local name  = generateObjectNameForClass('Prefab',"fromTrackPrefab_")
      local scenetreeObject = spawnPrefab(name , p, "0 0 0", "0 0 1", "1 1 1")
      table.insert(spawnedPrefabs, scenetreeObject)
    end
  end

  self.prefabs = trackInfo.prefabs or {}
  self.forwardPrefabs = trackInfo.forwardPrefabs or {}
  self.reversePrefabs = trackInfo.reversePrefabs or {}

  for _, fcp in ipairs({{'startLineCheckpoint','startNode'},{'finishLineCheckpoint','endNode'}}) do
    if trackInfo[fcp[1]] then
      local cp = trackInfo[fcp[1]]
      if not nodeToId[cp] then
        local pn = path.pathnodes:create(cp)
        local wp = scenetree.findObject(cp)
        if wp then
          local rot = nil
          if wp:getField('directionalWaypoint',0) == '1' then
             rot = quat(wp:getRotation())*vec3(1,0,0)
          end
          pn.pos = vec3(wp:getPosition())
          pn.radius = getSceneWaypointRadius(wp)
          pn:setNormal(rot)
          nodeToId[cp] = pn.id
          path[fcp[2]] = pn.id
        else
          log("E","","Could not find node for conversion from track! " .. dumps(cp))
            for _, p in ipairs(spawnedPrefabs) do
              p:delete()
            end
          return
        end
      end
    end
  end
  -- parse all branches and all cps from the config to get all CP infos
  --dumpz(trackInfo.originalInfo.lapConfig,1)
  for idx, cp in ipairs(trackInfo.originalInfo.lapConfig) do
    if not nodeToId[idx] then
      local pn = path.pathnodes:create(cp)
      local wp = scenetree.findObject(cp)
      if wp then
        local rot = nil
        if wp:getField('directionalWaypoint',0) == '1' then
           rot = quat(wp:getRotation())*vec3(1,0,0)
        end
        pn.pos = vec3(wp:getPosition())
        pn.radius = getSceneWaypointRadius(wp)
        pn:setNormal(rot)
        nodeToId[idx] = pn.id
      else
        log("E","","Could not find node for conversion from track! " .. dumps(cp))
          for _, p in ipairs(spawnedPrefabs) do
            p:delete()
          end
        return
      end
    end
  end
  --dumpz(self.pathnodes.objects, 2)
  local order = {}
  for i, _ in ipairs(trackInfo.originalInfo.lapConfig) do
    table.insert(order, i)
  end
  if trackInfo.closed then
    table.insert(order, trackInfo.finishLineCheckpoint)
    table.insert(order, 1)
  else
    if trackInfo.startLineCheckpoint then
      table.insert(order, 1, trackInfo.startLineCheckpoint)
    end
    table.insert(order, trackInfo.finishLineCheckpoint)
  end

  for i = 1, #order-1 do
    local seg = path.segments:create("Seg " .. i.."/"..(i+1))
    seg:setFrom(nodeToId[order[i]])
    seg:setTo(nodeToId[order[i+1]])
  end
  -- copy various simple fields
  if trackInfo.originalInfo then
    for _, field in ipairs({'authors','date','description','difficulty','forwardPrefabs','name','prefabs','reversePrefabs'}) do
      if trackInfo.originalInfo[field] ~= nil then
        path[field] = deepcopy(trackInfo.originalInfo[field])
      end
    end
  end
  path.defaultLaps = trackInfo.lapCount or 1

  --copy start positions if possible
  for _, spInfo in ipairs({{'standing','defaultStartPosition'}, {'standingReverse','reverseStartPosition'}, {'rolling','rollingStartPosition'}, {'rollingReverse','rollingReverseStartPosition'}}) do
    local spawnObj = scenetree.findObject(trackInfo.spawnSpheres[spInfo[1]])
    if spawnObj ~= nil then
      local rot = quat(spawnObj:getRotation())* quat(0,0,1,0)
      local x, y, z = rot * vec3(1,0,0), rot * vec3(0,1,0), rot * vec3(0,0,1)
      local pos = vec3(vec3(spawnObj:getPosition()) + y*1)
      pos:set(pos.x, pos.y, pos.z)
      local sp = path.startPositions:create(spInfo[2])
      sp.pos = pos
      sp.rot = rot
      path[spInfo[2]] = sp.id
    end
  end


  for _, p in ipairs(spawnedPrefabs) do
    p:delete()
  end
  --jsonWriteFile("testTT.json",{track = trackInfo, data = self:onSerialize()}, true)
  return true
end

function C:classify()
  self:autoConfig()
  local issues = {}
  local reversible = not self.startPositions.objects[self.reverseStartPosition].missing
  local allowRollingStart = not self.startPositions.objects[self.rollingStartPosition].missing
  if reversible then
    allowRollingStart = allowRollingStart and not self.startPositions.objects[self.rollingReverseStartPosition].missing
  end
  local closed = self.config.closed
  if not closed then
    reversible = reversible and not self.pathnodes.objects[self.endNode].missing
  end
  local branching = self.config.branching

  return {
    allowRollingStart = allowRollingStart,
    reversible = reversible,
    closed = closed,
    branching = branching
  }

end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end