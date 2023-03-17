-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Closest Road'

C.description = [[Finds closest road of the NavGraph for a position.]]
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'vec3', name = 'pos', description = "The Position that should be checked." },
  { dir = 'out', type = 'string', name = 'name_a', description = "Name of the first node." },
  { dir = 'out', type = 'vec3', name = 'pos_a', description = "Position of the first node." },
  { dir = 'out', type = 'number', name = 'roadId_a', hidden = true, description = "Name of the first nodes road (if existing)." },
  { dir = 'out', type = 'number', name = 'roadIdx_a', hidden = true, description = "Index of the first nodes node on the road (if existing)." },
  { dir = 'out', type = 'string', name = 'name_b', description = "Name of the second node." },
  { dir = 'out', type = 'vec3', name = 'pos_b', description = "Position of the second node."},
  { dir = 'out', type = 'number', name = 'roadId_b',hidden=true,  description = "Name of the second nodes road (if existing)."},
  { dir = 'out', type = 'number', name = 'roadIdx_b',hidden=true,  description = "Index of the second nodes node on the road (if existing)."},
  { dir = 'out', type = 'number', name = 'dist', description = "Distance to the road."},
  { dir = 'out', type = 'number', name = 'width', description = "Width of the road at the closest intersection.", hidden=true},
  { dir = 'out', type = 'number', name = 'speedLimit', description = "speed limit of the road you're on in m/s", hidden=true},
  { dir = 'out', type = 'vec3', name = 'projectedPoint', description = "The position projected onto the road segment", hidden=true},

}

C.color = ui_flowgraph_editor.nodeColors.default

function C:init(mgr)
end


function C:_executionStarted()
  self.oldPos = nil
  map.load()
end

function C:findDecalroad(name)
  if not scenetree[name] then
      -- this assumes that decalroads do not end with a number...
      local index, length = string.find(name, "DecalRoad")
      if index == 1 then
        local short = string.sub(name,length+1,string.len(name))
        local underscoreIndex = string.find(short,"_")
        if underscoreIndex and underscoreIndex >= 0 then
          local rdId = tonumber(string.sub(short,1,underscoreIndex-1))
          if not idId then
            local obj = scenetree.findObject(string.sub(short,1,underscoreIndex-1))
            if obj then
              rdId = obj:getId()
            end
          end
          local rdIdx = tonumber(string.sub(short,underscoreIndex+1,string.len(short)))
          return rdId, rdIdx
        end
    end
  else
    return -1, -1
  end
end


function C:work()
  if not self.pinIn.pos.value then return end

  if not self.oldPos or self.oldPos ~= self.pinIn.pos.value then
    self.oldPos = self.pinIn.pos.value
    local name_a,name_b,distance = map.findClosestRoad(vec3(self.oldPos))

    if not name_a or not name_b or not distance then return end

    local a = map.getMap().nodes[name_a]
    local b = map.getMap().nodes[name_b]

    local xnorm = clamp(vec3(self.oldPos):xnormOnLine(a.pos, b.pos), 0, 1)
    -- if we are closer to point b, swap it around
    if xnorm > 0.5 then
      name_a, name_b = name_b, name_a
      a = map.getMap().nodes[name_a]
      b = map.getMap().nodes[name_b]
      xnorm = 1-xnorm
    end

    -- this gets the link between the two or nothing
    local link = a.links[name_b] or b.links[name_a] or {}

    self.pinOut.name_a.value = name_a
    self.pinOut.name_b.value = name_b

    self.pinOut.pos_a.value = a.pos:toTable()
    -- if no object of this name, it might be a compound name.
    local aId, aIdx = self:findDecalroad(name_a)
    self.pinOut.roadId_a.value = aId
    self.pinOut.roadIdx_a.value = aIdx

    self.pinOut.pos_b.value = b.pos:toTable()
    local bId, bIdx = self:findDecalroad(name_b)
    self.pinOut.roadId_b.value = bId
    self.pinOut.roadIdx_b.value = bIdx

    self.pinOut.dist.value = (vec3(self.oldPos)-vec3(lerp(a.pos,b.pos, xnorm))):length()
    self.pinOut.speedLimit.value = link.speedLimit or 0

    self.pinOut.projectedPoint.value = lerp(a.pos,b.pos, xnorm):toTable()
    self.pinOut.width.value = lerp(a.radius,b.radius,xnorm)
  end
end

return _flowgraph_createNode(C)
