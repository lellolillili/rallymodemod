-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local modes = {'waypoint','navgraphCapsule', 'manualCapsules'}
local missingKeynode = {name = "Missing!", pos = vec3(), radius = 0, mode = "Missing!"}



function C:init(path, name, forceId)
  self.path = path
  self.id = forceId or path:getNextUniqueIdentifier()
  self.name = name or "Segment " .. self.id
  self.mode = 'waypoint'
  self.from = -1
  self.to = -1
  self.sortOrder = 999999
  self._drawMode = 'faded'
  self.capsulePoints = {}
end

function C:getBeNavpath()
  if self:getFrom().mode == 'navgraph' and self:getTo().mode == 'navgraph' then
    return true
  else
    return false
  end
end


function C:getFrom() return self.path.pathnodes.objects[self.from] end
function C:getTo() return self.path.pathnodes.objects[self.to]  end
function C:setFrom(from)
  self.from = from
  self:checkMode()
end
function C:setTo(to)
  self.to = to
  self:checkMode()
end

function C:checkMode()
  -- waypoint mode is always OK.
  if self.mode == 'waypoint' then return end
  if self.mode == 'navpath' then
    if self:getBeNavpath() then
      self:fillNavpath()
    else
      self:setMode('waypoint')
    end
  end
end

function C:setMode(mode)
  self.mode = mode
  if mode == 'waypoint' then
    table.clear(self.capsulePoints)
  end
  if mode == 'navpath' then
    self:fillNavpath()
  end


end

function C:fillNavpath()
  table.clear(self.capsulePoints)
  local path = map.getPath(self:getFrom().navgraphName, self:getTo().navgraphName)
  if path and #path > 2 then
    for j = 2, #path-1 do
      local node = map.getMap().nodes[path[j]]
      table.insert(self.capsulePoints, {pos = vec3(node.pos), radius = node.radius, name = path[j], _generated = true})
    end
  end
end

function C:addCapsule(pos, radius, name, index)
  table.insert(self.capsulePoints,index or (#self.capsulePoints+1),{pos = vec3(pos), radius = radius, name = name})
end

function C:removeCapsule(index)
  table.remove(self.capsulePoints, index)
end

function C:getCapsuleCount() return #self.capsulePoints + 2 end
function C:getCapsuleNode(i)
  if i == 1 then
    return self:getFrom()
  elseif i == self:getCapsuleCount() then
    return self:getTo()
  else
    return self.capsulePoints[i-1]
  end
end
function C:capsuleContains(point, id)
  local a = self:getCapsuleNode(id)
  local b = self:getCapsuleNode(id+1)
  if not a or not b then return end
  local xnorm, distance = point:xnormDistanceToLineSegment(a.pos,b.pos)
  local maxDistance = lerp(a.radius, b.radius, clamp(xnorm,0,1))
  if distance < maxDistance then
    return true
  end
end

function C:contains(point, state)
  if self.mode == 'waypoint' then
    -- for waypoint mode, we are always inside if we are currently in this segment.
    -- otherwise, we are inside if we are actually inside the from node.
    local isPrev = false
    for _, id in ipairs(state.currentSegments) do
      if id == self.id then
        isPrev = true
      end
    end
    if isPrev then
      return true
    else
      return self:getFrom():intersectCorners(state.previousCorners, state.currentCorners)
    end
  elseif self.mode == 'capsules' or self.mode == 'navpath' then
    local inside = false
    local cc = self:getCapsuleCount()-1
    local capsuleIndex
    for i = 1, cc do
      inside = inside or self:capsuleContains(point, i)
      if inside then
        capsuleIndex = i
        break
      end
    end
    return inside, 0
  else
    return false
  end
end

function C:finished(point, state)
  return self:getTo():intersectCorners(state.previousCorners, state.currentCorners)
end


function C:onSerialize()
  local capsules = {}
  for _, c in ipairs(self.capsulePoints) do
    table.insert(capsules,{ name = c.name, radius = c.radius, pos = c.pos:toTable()})
  end
  local ret = {
    name = self.name,
    mode = self.mode,
    from = self.from,
    to = self.to,
    oldId = self.id,
    capsules = capsules
  }
  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.name = data.name
  table.clear(self.capsulePoints)
  if oldIdMap then
    self.from = oldIdMap[data.from]
    self.to = oldIdMap[data.to]
  else
    self.from = data.from
    self.to = data.to
  end
  self:setMode(data.mode)
  for _, c in ipairs(data.capsules or {}) do
    self:addCapsule(c.pos, c.radius, c.name)
  end
end

function C:drawDebug(drawMode)
  if not self:isValid() then return end
  drawMode = drawMode or self._drawMode
  if drawMode == 'none' then return end
  local clr = rainbowColor(#self.path.segments.sorted, (self.sortOrder-1), 1)
  if drawMode == 'highlight' then clr = {1,1,1,1} end
  if drawMode == 'faded' then clr = {1,1,1,0.25} end
  local shapeAlpha = (drawMode == 'highlight') and 0.75 or 0.25
  if self.mode == 'waypoint' or drawMode == 'highlight' then
    debugDrawer:drawSquarePrism(
      self:getFrom().pos,
      self:getTo().pos,
      Point2F(2,4),
      Point2F(0,0),
      ColorF(clr[1],clr[2],clr[3],shapeAlpha))
  end

  local alpha = (drawMode == 'normal') and 0.5 or 1
  local textPos = vec3()
  if self.mode == 'waypoint' then
    textPos = (self:getFrom().pos+self:getTo().pos)/2
  else
    local a = self:getCapsuleNode(clamp(math.ceil(self:getCapsuleCount()/2),1,self:getCapsuleCount())).pos
    local b = self:getCapsuleNode(clamp(math.floor(self:getCapsuleCount()/2),1,self:getCapsuleCount())).pos
    textPos = (a+b)/2
  end
  if drawMode ~= 'faded' then
    debugDrawer:drawTextAdvanced(textPos,
      String(self.name),
      ColorF(1,1,1,alpha),true, false,
      ColorI(0,0,0,alpha*255))
  end


  if self.mode ~= 'waypoint' then
    for i = 1, self:getCapsuleCount()-1 do
      local a, b
      a = self:getCapsuleNode(i)
      b = self:getCapsuleNode(i+1)

      local ab = (a.pos-b.pos):normalized()
      ab = vec3(ab.y, -ab.x, 0):normalized()
      debugDrawer:drawSquarePrism(
        vec3(a.pos+ab*a.radius),
        vec3(b.pos+ab*b.radius),
        Point2F(2,0.1),
        Point2F(2,0.1),
        ColorF(clr[1],clr[2],clr[3],shapeAlpha/2))
      debugDrawer:drawSquarePrism(
        vec3(a.pos-ab*a.radius),
        vec3(b.pos-ab*b.radius),
        Point2F(2,0.1),
        Point2F(2,0.1),
        ColorF(clr[1],clr[2],clr[3],shapeAlpha/2))
      if i > 0 then
        debugDrawer:drawSphere(a.pos, a.radius,
        ColorF(clr[1],clr[2],clr[3],shapeAlpha/2))
      end
    end
  end

end


function C:isValid()
  return not (self.path.pathnodes.objects[self.from].missing or self.path.pathnodes.objects[self.to].missing or self.from == self.to)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end