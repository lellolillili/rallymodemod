-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local _uid = 0 -- do not use ever
local quadtree = require('quadtree')
function C:getNextUniqueIdentifier()
  _uid = _uid + 1
  return _uid
end

function C:init(name)
  self.name = name or "Sites"
  self.description = "Description of these Sites. Contains Locations and Zones."
  self.id = self:getNextUniqueIdentifier()
  self.locations = require('/lua/ge/extensions/gameplay/util/sortedList')("locations", self, require('/lua/ge/extensions/gameplay/sites/location'))
  self.zones = require('/lua/ge/extensions/gameplay/util/sortedList')("zones", self, require('/lua/ge/extensions/gameplay/sites/zone'))
  self.parkingSpots = require('/lua/ge/extensions/gameplay/util/sortedList')("parkingSpots", self, require('/lua/ge/extensions/gameplay/sites/parkingSpot'))
end

---- Debug and Serialization
function C:drawDebug()
  self.locations:drawDebug()
  self.zones:drawDebug()
  self.parkingSpots:drawDebug()
end

function C:onSerialize()
  local ret = {
    name = self.name,
    description = self.description,
    locations = self.locations:onSerialize(),
    zones = self.zones:onSerialize(),
    parkingSpots = self.parkingSpots:onSerialize(),
    dir = self.dir,
    filename = self.filename
  }
  return ret
end

function C:onDeserialized(data, oldIdMap)
  if not data then return end
  self.name = data.name or ""
  self.description = string.gsub(data.description or "", "\\n", "\n")
  self.locations:clear()
  self.zones:clear()
  oldIdMap = oldIdMap or {}
  self.locations:onDeserialized(data.locations, oldIdMap)
  self.zones:onDeserialized(data.zones, oldIdMap)
  self.parkingSpots:onDeserialized(data.parkingSpots, oldIdMap)
  self.filename = data.filename
  self.dir = data.dir
end

function C:finalizeSites()

  -- check for multiSpots to generate
  for _, ps in ipairs(self.parkingSpots.sorted) do
    if ps.isMultiSpot and not ps.isProcedural then
      ps:generateMultiSpots(self.parkingSpots)
    end
  end

  self.locations:buildNamesDir()
  self.zones:buildNamesDir()
  self.parkingSpots:buildNamesDir()

  self.tags = {}
  self.sortedTags = {}
  self.tagsToZones = {}
  self.tagsToLocations = {}
  self.quadtreeLocations = quadtree.newQuadtree()
  self.quadtreeZones = quadtree.newQuadtree()
  self.quadtreeParkingSpots = quadtree.newQuadtree()

  for _, zone in ipairs(self.zones.sorted) do
    zone.locations = {}
    zone.parkingSpots = {}
    for _, t in ipairs(zone.customFields.sortedTags) do
      self.tags[t] = 1
      if not self.tagsToZones[t] then self.tagsToZones[t] = {} end
      table.insert(self.tagsToZones[t], zone)
    end
    self.quadtreeZones:preLoad(zone.id, zone.aabb.xMin, zone.aabb.yMin, zone.aabb.xMax, zone.aabb.yMax)
  end

  for _, loc in ipairs(self.locations.sorted) do
    loc.zones = {}
    for _, t in ipairs(loc.customFields.sortedTags) do
      self.tags[t] = 1
      if not self.tagsToLocations[t] then self.tagsToLocations[t] = {} end
      table.insert(self.tagsToLocations[t], loc)
    end
    for _, zone in ipairs(self.zones.sorted) do
      if zone:containsPoint2D(loc.pos) then
        table.insert(zone.locations, loc)
        table.insert(loc.zones, zone)
      end
    end
    self.quadtreeLocations:preLoad(loc.id, loc.pos.x, loc.pos.y, loc.pos.x, loc.pos.y)
  end

  for _, ps in ipairs(self.parkingSpots.sorted) do
    ps.zones = {}
    for _, zone in ipairs(self.zones.sorted) do
      if zone:containsPoint2D(ps.pos) then
        table.insert(zone.parkingSpots, ps)
        table.insert(ps.zones, zone)
      end
    end
    self.quadtreeParkingSpots:preLoad(ps.id, ps.pos.x, ps.pos.y, ps.pos.x, ps.pos.y)
  end

  for k, _ in pairs(self.tags) do
    table.insert(self.sortedTags, k)
  end
  table.sort(self.sortedTags)

  self.quadtreeZones:build()
  self.quadtreeLocations:build()
  self.quadtreeParkingSpots:build()
  self._finalized = (self._finalized or 0)+1
  if self._finalized > 1 then
    --log("W","","Finalized too often: "..self._finalized)
    --print(debug.tracesimple())
  end

end

-- gets a list of all locations within a min/max distance around a position.
function C:getRadialLocations(pos, minRadius, maxRadius)
  -- local prof = hptimer()
  local minRadiusSquared = minRadius*minRadius
  local maxRadiusSquared = maxRadius*maxRadius
  local ret = {}
  local d = -1
  local loc = nil
  for id in self.quadtreeLocations:query(pos.x-maxRadius, pos.y-maxRadius, pos.x+maxRadius, pos.y+maxRadius) do
    loc = self.locations.objects[id]
    d = pos:squaredDistance(loc.pos)
    if d >= minRadiusSquared and d <= maxRadiusSquared then
      table.insert(ret, {loc = loc, squaredDistance = d})
    end
  end
  --local time = prof:stop()
  return ret
end

-- gets a list of all parking spots within a min/max distance around a position.
function C:getRadialParkingSpots(pos, minRadius, maxRadius)
  -- local prof = hptimer()
  local minRadiusSquared = minRadius*minRadius
  local maxRadiusSquared = maxRadius*maxRadius
  local ret = {}
  local d = -1
  local ps = nil
  for id in self.quadtreeParkingSpots:query(pos.x-maxRadius, pos.y-maxRadius, pos.x+maxRadius, pos.y+maxRadius) do
    ps = self.parkingSpots.objects[id]
    d = pos:squaredDistance(ps.pos)
    if d >= minRadiusSquared and d <= maxRadiusSquared then
      table.insert(ret, {ps = ps, squaredDistance = d})
    end
  end
  --local time = prof:stop()
  return ret
end

function C:getClosestParkingSpot(pos)
  local res
  local squaredDistance = math.huge
  local radius = 1

  repeat
    for id in self.quadtreeParkingSpots:query(pos.x - radius, pos.y - radius, pos.x + radius, pos.y + radius) do
      local ps = self.parkingSpots.objects[id]
      local currSqDist = pos:squaredDistance(ps.pos)
      if currSqDist < squaredDistance then
        res = ps
        squaredDistance = currSqDist
      end
    end

    radius = radius * 2
  until res or radius > 1024

  return res, squaredDistance
end

function C:getZonesForPosition(pos)
  local zones = {}
  for id in self.quadtreeZones:queryNotNested(pos.x, pos.y, pos.x, pos.y) do
    local zone = self.zones.objects[id]
    if zone:containsPoint2D(pos) then
      table.insert(zones, zone)
    end
  end
  return zones
end

function C:getTagsForZonesAtPosition(pos)
  local tags = {}
  local sortedTags = {}
  for id in self.quadtreeZones:query(pos.x, pos.y, pos.x, pos.y) do
    local zone = self.zones.objects[id]
    if zone:containsPoint2D(pos) then
      for t, _ in pairs(zone.customFields.tags) do
        tags[t] = 1
      end
    end
  end
  for t, _ in pairs(tags) do
    table.insert(sortedTags, t)
  end
  table.sort(sortedTags)
  return tags, sortedTags
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end