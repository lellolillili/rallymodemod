-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 50 -- low first, high later

function C:init()
  self.prefabs = {}
  self.sortedIds = {}
  self.flags = {}
  self:clear()
end

function C:clear()
  table.clear(self.prefabs)
  table.clear(self.flags)
  table.clear(self.sortedIds)
end

function C:afterTrigger()
  if self.flags.reloadCollisionOnAfterTrigger then
    self.flags.reloadCollisionOnAfterTrigger = false
    be:reloadCollision()
  end
  if self.flags.rebuildNavgraphOnAfterTrigger then
    self.flags.rebuildNavgraphOnAfterTrigger = false
    map.reset()
  end
end

local function findObjectsRecursive(obj, list, slf)
  if (obj:isSubClassOf("SimSet") or obj:isSubClassOf("SimGroup") or obj:isSubClassOf("Prefab")) and obj.size then
    for i = 0, obj:size() - 1 do
      local child = obj:at(i)
      findObjectsRecursive(child, list, slf)
    end
  end

  local cn = obj:getClassName()
  list[cn] = list[cn] or {}
  table.insert(list[cn],obj:getId())

  if slf.mgr.activity then
    if obj:getName() ~= "" and obj:getName() ~= nil then
      log("W","","Prefab Object "..dumps(obj:getName()).." uses Name field instead of InternalName field. This can cause prefabs to not be loaded properly. Please set Name to empty and use InternalName.")
    end
  end

end

local function findAllObjects(obj, slf)
  local objectsByType = {}
  findObjectsRecursive(obj, objectsByType, slf)
  return objectsByType
end


   -- find out if any colliders are contained.
local function containsColliders(data)
  local contains = false
  for _, id in ipairs(data.allChildrenIds['TSStatic'] or {}) do
    if not contains then
      local static = scenetree.findObjectById(id)
      if static then
        contains = static:getField('collisionType','') ~= "None"
      end
    end
  end

  return contains
end

function C:originalVehicleTransforms(data)
  local transforms = {}
  for _, id in ipairs(data.allChildrenIds['BeamNGVehicle'] or {}) do
    local veh = scenetree.findObjectById(id)
    if veh then
      veh = Sim.upcast(veh)
      transforms[id] = {
        pos = veh:getPosition(),
        rot = quat(veh:getRotation()),
        up = veh:getDirectionVectorUp()
      }
      self.mgr.modules.vehicle:addVehicle(veh)
    end
  end
  return transforms
end

local function requiresNavgraphReload(data)
  local requires = false

  for _, id in ipairs(data.allChildrenIds['BeamNGWaypoint'] or {}) do
    if not requires then
      local wp = scenetree.findObjectById(id)
      if wp and not wp.excludeFromMap then
        requires = true
      end
    end
  end

  if not requires then
    for _, id in ipairs(data.allChildrenIds['DecalRoad'] or {}) do
      if not requires then
        local dr = scenetree.findObjectById(id)
        if dr and dr.drivability > 0 then
          requires = true
        end
      end
    end
  end

  return requires
end

function C:getPrefab(id)
  return self.prefabs[id] or {}
end

function C:spawnPrefab(fileName)
  print("Spawning " .. fileName)
  local pos = vec3(0,0,0)

  local file, succ = self.mgr:getRelativeAbsolutePath({fileName, fileName .. '.prefab.json'})
  local name = generateObjectNameForClass('Prefab', "prefab_")
  local scenetreeObject = spawnPrefab(name , file, pos.x .. " " .. pos.y .. " " .. pos.z, "0 0 1", "1 1 1", false)
  scenetreeObject.canSave = false
  scenetree.MissionGroup:add(scenetreeObject)

  self:addPrefab(scenetreeObject:getID())
  return scenetreeObject:getID()
end

function C:addPrefab(id, moreData)
  local data = {
    id = id
  }
  for k, v in pairs(moreData or {}) do data[k] = v end
  local obj = scenetree.findObjectById(id)
  data.allChildrenIds = findAllObjects(obj, self)
  data.containsColliders = containsColliders(data)
  data.originalVehicleTransforms = self:originalVehicleTransforms(data)
  data.requiresNavgraphReload = requiresNavgraphReload(data)

  self.prefabs[data.id] = data
  table.insert(self.sortedIds, data.id)

  if data.containsColliders then
    if self.mgr.modules.isLoadingLevel then
      if not self.flags.reloadCollisionOnLevelLoading then
        self.mgr.modules.level:delayOrInstantFunction(function()
          log("D","","Reloading Collision from prefabModule because prefabs(s) contained collision.")
          be:reloadCollision()
        end)
        self.flags.reloadCollisionOnLevelLoading = true
      end
    else
      self.flags.reloadCollisionOnAfterTrigger = true
    end
  end

  if data.requiresNavgraphReload then
    if self.mgr.modules.isLoadingLevel then
      if not self.flags.rebuildNavgraphOnLevelLoading then
        self.mgr.modules.level:delayOrInstantFunction(function()
          log("D","","Reloading map because prefab(s) contained navgraph waypoints/data")
          map.reset()
        end)
        self.flags.rebuildNavgraphOnLevelLoading = true
      end
    else
      self.flags.rebuildNavgraphOnAfterTrigger = true
    end
  end

end

function C:restoreVehiclePositions(id)
  local data = self.prefabs[id]
  if data then
    for vid, val in pairs(data.originalVehicleTransforms or {}) do
      if scenetree.findObjectById(vid) then
        vehicleSetPositionRotation(vid, val.pos.x, val.pos.y, val.pos.z,  val.rot.x, val.rot.y, val.rot.z, val.rot.w)
      end
    end
  end
end

function C:getVehicleIdsForPrefab(id)
  local data = self.prefabs[id]
  local ret = {}
  if data then
    ret = tableKeysSorted(data.originalVehicleTransforms or {})
  end
  return ret
end

function C:unpackPrefabAndDelete(id, obj)
  local vehicleTransforms = {}
  for k, _ in pairs(self.prefabs[id].originalVehicleTransforms) do
    local veh = scenetree.findObjectById(k)
    if veh then
      -- get current position and rotation
      vehicleTransforms[k] = {pos = veh:getPosition(), rot = quat(0, 0, 1, 0) * quatFromDir(veh:getDirectionVector(), veh:getDirectionVectorUp())}
    end
  end
  local group = obj:explode()
  obj:delete()
  for k, v in pairs(vehicleTransforms) do
    --dump("Extracting object: " .. i)
    local veh = scenetree.findObjectById(k)
    if veh then
      scenetree.MissionGroup:add(veh)
      veh:setPosRot(v.pos.x, v.pos.y, v.pos.z, v.rot.x, v.rot.y, v.rot.z, v.rot.w)
    end
  end
  group:delete()
  -- remove all children of new group except
end

function C:setUnpackVehiclesBeforeDeletion(id, set)
  if self.prefabs[id] then
    self.prefabs[id].unpackVehiclesBeforeDeletion = set
  end
end

function C:executionStopped()
  local reloadCollision = false
  for _, id in ipairs(self.sortedIds) do
    local data = self.prefabs[id]
    if not data.dontDelete then
      local obj = scenetree.findObjectById(id)
      print("data.unpackVehiclesBeforeDeletion ->" .. dumps(data.unpackVehiclesBeforeDeletion))
      if obj then
        if data.unpackVehiclesBeforeDeletion then
          self:unpackPrefabAndDelete(id, obj)
        else
          if editor and editor.onRemoveSceneTreeObjects then
            editor.onRemoveSceneTreeObjects({id})
          end
          obj:delete()
        end
      end
      reloadCollision = reloadCollision or data.containsColliders
    end
  end
  if reloadCollision then
    be:reloadCollision()
  end
  self:clear()
end

return _flowgraph_createModule(C)