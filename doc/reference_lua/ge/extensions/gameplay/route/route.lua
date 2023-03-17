-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local onPathDist = 15

function C:init()
  self.path = {}
  self.dirMult = 1e3
end

function C:setRouteParams(cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wD, wZ)
  self.cutOffDrivability = cutOffDrivability
  self.dirMult = dirMult or 1e3
  self.penaltyAboveCutoff = penaltyAboveCutoff
  self.penaltyBelowCutoff = penaltyBelowCutoff
  self.wD = wD
  self.wZ = wZ
  --log("I","",dumps("setRouteParams", cutOffDrivability, dirMult, penaltyAboveCutoff, penaltyBelowCutoff, wD, wZ))
end

local function fixStartEnd(p, a, b)
  profilerPushEvent("Route - fixStartEnd")
  local xnorm = p.pos:xnormOnLine(a.pos, b.pos)
  if xnorm > 0 then
    a.pos = lerp(a.pos, b.pos, xnorm)
    a.wp = nil
  end

  a.distToTarget = (a.pos-b.pos):length() + (b.distToTarget or 0)

  profilerPopEvent()
end

function C:setupPath(fromPos, toPos)
  self:setupPathMulti({fromPos, toPos})
end

function C:setupPathMultiNavgraphNames(names)
  local positions = {}
  for i, name in ipairs(names) do
    positions[i] = map.getMap().nodes[name].pos
  end
  return self:setupPathMulti(positions)
end

function C:setupPathMulti(positions)
  profilerPushEvent("Route - setupPathMulti")
  table.clear(self.path)
  table.insert(self.path, {pos = positions[1], wp = nil})
  for i = 1, #positions-1 do
    local from, to = positions[i], positions[i+1]
    profilerPushEvent("Route - get point to point")
    local path = map.getPointToPointPath(from, to, self.cutOffDrivability, self.dirMult, self.penaltyAboveCutoff, self.penaltyBelowCutoff, self.wD, self.wZ)
    profilerPopEvent()
    local lastIdx = #self.path
    for i, p in ipairs(path) do
      table.insert(self.path, {pos = map.getMap().nodes[p].pos, wp = p, linkCount = map.getNodeLinkCount(p)})
    end
    table.insert(self.path, {pos = to, wp = nil, fixed = true})
    if #self.path >= 3 and #path >= 2 then
      fixStartEnd(self.path[lastIdx], self.path[lastIdx+1], self.path[lastIdx+2])
    end
    if #self.path >= 3 and #path >= 2 then
      fixStartEnd(self.path[#self.path], self.path[#self.path-1], self.path[#self.path-2])
    end
  end

  -- merge too-close nodes into one and preserve fields wp and fixed
  local closeDist = 1
  local newPath = {self.path[1]}
  local last = self.path[1]
  for i = 2, #self.path do
    local cur = self.path[i]
    local dist = (cur.pos-last.pos):length()
    if dist <= closeDist then
      -- merge
      last.wp = last.wp or cur.wp
      last.fixed = last.fixed or cur.fixed
    else
      -- skip
      last = cur
      table.insert(newPath,cur)
    end
  end
  self.path = newPath

  if #self.path >= 3 then
    fixStartEnd(self.path[1], self.path[2], self.path[3])
    --merge first two nodes if already on path
    if (self.path[1].pos - self.path[2].pos):length() < onPathDist then
      table.remove(self.path,1)
    end
  end
  if #self.path >= 3 then
    fixStartEnd(self.path[#self.path], self.path[#self.path-1], self.path[#self.path-2])
  end
  local dist = 0
  for i = #self.path, 2, -1 do
    self.path[i].distToTarget = dist
    dist = dist + (self.path[i].pos - self.path[i-1].pos):length()
  end
  self.path[1].distToTarget = dist

  profilerPopEvent()
end

function C:clear()
  table.clear(self.path)
end

function C:recalculateRoute(startPos)
  profilerPushEvent("Route - recalculateRoute")
  local fixedWps = {}
  table.insert(fixedWps, startPos)
  for _, wp in ipairs(self.path) do
    if wp.fixed then table.insert(fixedWps, wp.pos) end
  end
  self:setupPathMulti(fixedWps)
  profilerPopEvent()
end

--local offPathDist = 25
function C:getPositionOffset(currentPos)
  profilerPushEvent("Route - getPositionOffset")
  local dist = 0
  -- go through all segments and check where we are on that line
  local minDistance, totalMinDist = math.huge, math.huge
  local lowIdx = 0
  for i = 1, math.min(#self.path-1) do
    local aPos, bPos = self.path[i].pos, self.path[i+1].pos
    local dist = currentPos:distanceToLineSegment(aPos, bPos)
    totalMinDist = math.min(totalMinDist, dist)
    if dist > minDistance then break end
    if dist < onPathDist then
      minDistance = dist
      lowIdx = i
    end
  end
  profilerPopEvent()
  return lowIdx, totalMinDist
end

function C:shortenPath(idx)
  profilerPushEvent("Route - shortenPath")
  for i = 2, idx do
    table.remove(self.path, 1)
  end
  profilerPopEvent()
end

function C:trackVehicle(veh) return self:updatePathForPos(veh:getPosition()) end
function C:trackCamera() return self:updatePathForPos(getCameraPosition()) end
function C:trackPosition(pos) return self:updatePathForPos(pos) end

function C:updatePathForPos(pos)
  profilerPushEvent("Route - updatePathForPos")
  -- are we there yet? no path or only one element remaining?
  if not next(self.path) or #self.path < 2 then
    self.done = true
    profilerPopEvent()
    return
  end

  -- did we pass any of the first positions, moving forward on the track?
  local idx, minDistance = self:getPositionOffset(pos)

  if idx == 0 and minDistance >= onPathDist then
    -- re-do route
    self:recalculateRoute(pos)
  elseif idx >= 2 then
    -- if we passed the first segment, truncate path accordingly
    self:shortenPath(idx)
  end
  fixStartEnd({pos = pos}, self.path[1], self.path[2])

  profilerPopEvent()


  return idx, minDistance
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end