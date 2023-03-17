-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

function C:init()


  self.vehId = {}
  self.state = 'disabled'
  self.timer = 0
  self.events = {}
  self.pickup = {}
  self.locations = {}
  self.roundtripDistance = 0
  self.locationIndex = 0

  -- fail parameters
  self.maxDamage = 5000
  self.stoppedTimer = 0
  self.stoppedMaxDuration = 10
  self.locationRewardFactor = 0.5
end

function C:getCurrentRewardFactor()
  if not self.locations or #self.locations == 0 then return 0 end
  return ((self.locationIndex-1)/#self.locations) * self.locationRewardFactor

end

local function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
  return tbl
end

function C:selectLocations(tag, count)
  -- load sites
  local locations = {}
  local lCount = 0
  for _, loc in pairs(self.sites.locations.objects) do
    if loc.customFields.tags[tag] then
      table.insert(locations, loc)
      lCount = lCount+1
    end
  end

  local selected = {}
  if lCount > count then
    shuffle(locations)
  end
  for i = 1, count do
    table.insert(selected, locations[i])
  end
  if position then
    table.sort(locations, function(a,b)
      return (self.pickup.pos-a.pos):length() < (self.pickup.pos-b.pos):length()
    end)
  end
  return selected
end

function  C:calculateRoundtrip()
  local positions = {}
  table.insert(positions, {self.pickup.pos, self.locations[1].pos})
  for i = 1, #self.locations-1 do
    table.insert(positions, {self.locations[i].pos ,self.locations[i+1].pos})
  end
  table.insert(positions, {self.locations[#self.locations].pos, self.pickup.pos})

  local distance = 0
  for _, pair in ipairs(positions) do
    local name_a,_,distance_a = map.findClosestRoad(pair[1])
    local name_b,_,distance_b = map.findClosestRoad(pair[2])
    if name_a and name_b then
      local path = map.getPath(name_a, name_b)
      local d = 0
      for i = 1, #path-1 do
        local a,b = path[i],path[i+1]
        a,b = map.getMap().nodes[a].pos, map.getMap().nodes[b].pos
        d = d + (a-b):length()
      end
      d = d + distance_a + distance_b
      distance = distance + d
    end
  end

  return distance
end


function C:setTimeParameters(baseTime, timePerKm)
  self.baseTime = baseTime
  self.timePerKm = timePerKm
end

function C:setup(sites, pickupPos, pickupRadius, tag, count)
  self.sites = sites
  self.pickup = {pos = vec3(pickupPos), radius = pickupRadius}
  self.locations = self:selectLocations(tag, count)
  self.roundtripDistance = self:calculateRoundtrip()
  self.timer = self.baseTime + self.timePerKm * self.roundtripDistance/1000
  self.state = 'start'
end

function C:startDelivery()
  self.state = 'active'
  self.locationIndex = 1
end

function C:proceedDelivery()
  self.events.proceedDelivery = true
  self.locationIndex = self.locationIndex+1
  if self.locationIndex > #self.locations then
    self.state = 'return'
    return true
  end
  return false
end

function C:update(dt)
  if self.state == 'disabled' then return end
  --self:clearEvents()

  if self.state == 'active' then
    self:checkFail(dt)
  end
end

function C:clearEvents()
  self.events = {}
end

function C:checkFail(dt)
  local veh = scenetree.findObjectById(self.vehId)
  local vData = map.objects[self.vehId]
  if not vData then
    dump("No vData?!")
    return nil
  end
  local fail = nil

  if vData.damage > self.maxDamage then
    fail = 'damage'
  end

  if not self.isPartiallyInsideLocationOneFrame then
    self.timer = self.timer - dt
    if self.timer < 0 then
      fail = 'time'
    end
  end
  self.isPartiallyInsideLocationOneFrame = false

  if fail then
    self.state = 'failed'
    self.failReason = fail
  end

end

function C:getCurrentLocation()
  if self.state ~= 'active' then return end
  return self.locations[self.locationIndex]
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end