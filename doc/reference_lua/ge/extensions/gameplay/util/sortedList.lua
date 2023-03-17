-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This is a list that contains objects with a numerical "id" and "name".
-- There's tables with lookup by id, sorted by id, lookup by name.
local C = {}

-- This creates objects.
function C:init(name, parent, objectConstructor)
  self.objectConstructor = objectConstructor
  self.name = name
  self.parent = parent
  self:clear()
end

-- These functions can be set to "add" code to the creation and removal of objects.
C.postClear = nop
C.postRemove = nop
C.postCreate = nop

function C:clear()
  self.objects = {}
  setmetatable(self.objects, {
    __index = function() return {name = "Missing!", missing = true, id = -1} end
  })
  self.sorted = {}
  self.byName = {}
  self.postClear()
end

function C:create(name, forceId)
  local obj = self.objectConstructor(self.parent, name, forceId)
  obj.isProcedural = false
  self.objects[obj.id] = obj
  self:sort()
  self.postCreate(obj)
  return obj
end

function C:remove(obj)
  if type(obj) == 'number' then
    obj = self.objects[obj]
  end
  self.objects[obj.id] = nil
  self:sort()
  self.postRemove()
end

function C:sort()
  table.clear(self.sorted)
  for _, o in pairs(self.objects) do
    table.insert(self.sorted, o)
  end
  table.sort(self.sorted, function(a,b) return a.sortOrder<b.sortOrder end)
  for i, o in ipairs(self.sorted) do
    o.sortOrder = i
  end
end

function C:move(id, dir)
  local a = self.objects[id]
  if not a then return end
  local b = self.sorted[a.sortOrder + dir]
  if not b then return end
  local t = a.sortOrder
  a.sortOrder = b.sortOrder
  b.sortOrder = t
  table.sort(self.sorted, function(a,b) return a.sortOrder<b.sortOrder end)
end

function C:buildNamesDir()
  table.clear(self.byName)
  for _, zone in ipairs(self.sorted) do
    if not self.byName[zone.name] then
      self.byName[zone.name] = zone
    end
  end
end

function C:drawDebug()
  for _,o in ipairs(self.sorted) do
    o:drawDebug()
  end
end

function C:onSerialize(parent)
  local ret = {}
  for i, o in ipairs(self.sorted) do
    if not o.isProcedural then
      table.insert(ret, o:onSerialize())
    end
  end
  return ret
end
function C:onDeserialized(data, oldIdMap)
  self:clear()
  for _, d in ipairs(data or {}) do
    local o = self:create(d.name)
    o:onDeserialized(d, oldIdMap)
    oldIdMap[tonumber(d.oldId)] = o.id
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end