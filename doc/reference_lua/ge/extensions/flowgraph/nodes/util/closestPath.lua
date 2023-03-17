-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

C.name = 'Navgraph Distance'

C.description = [[Finds the aproximate length between positions along the navgraph.]]
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'in', type = 'vec3', name = 'posA', description = "The Position that should be checked." },
  { dir = 'in', type = 'vec3', name = 'posB', description = "The Position that should be checked." },
  { dir = 'out', type = 'number', name = 'dist', description = "Distance to the road." },
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
  if not self.pinIn.posA.value or not self.pinIn.posB.value then return end

  if not self.oldPos or self.oldPos ~= self.pinIn.pos.value then

    local name_a,_,distance_a = map.findClosestRoad(vec3(self.pinIn.posA.value))
    local name_b,_,distance_b = map.findClosestRoad(vec3(self.pinIn.posB.value))
    if not name_a or not name_b then return end
    local path = map.getPath(name_a, name_b)
    local d = 0
    for i = 1, #path-1 do
      local a,b = path[i],path[i+1]
      a,b = map.getMap().nodes[a].pos, map.getMap().nodes[b].pos
      d = d + (a-b):length()
    end
    d = d + distance_a + distance_b
    self.pinOut.dist.value = d

  end
end

return _flowgraph_createNode(C)
