-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = -150 -- low first, high later
C.dependencies = {'gameplay_walk'}
C.hooks = {'onCouplerAttached', 'onCouplerDetached','onBusUpdate'}
function C:init()
  self.vehicles = {}
  self.sortedIds = {}
  self.couplings = {}
  self.unReadyIds = {}
  self:clear()
end

function C:clear()
  table.clear(self.vehicles)
  table.clear(self.sortedIds)
  table.clear(self.couplings)
end

function C:getSpawnedVehicles()
  return deepcopy(self.sortedIds)
end

-- call this to add a vehicle that is not spawned by FG, but should still be tracked
function C:addForeignVehicle(veh, moreData)
  moreData = moreData or {}
  moreData.dontDelete = true
  self:addVehicle(veh, moreData)
end

function C:addVehicle(veh, moreData)
  if veh and self.vehicles[veh:getId()] then
    log("D","","Already tracking vehicle " .. veh:getId())
    return
  end
  local data = {
    id = veh:getId(),
    ready = veh:isReady(),
    internalName = veh:getInternalName() or '',
    couplerOffset = {},

  }
  veh.canSave = false
  for k, v in pairs(moreData or {}) do data[k] = v end
  self.vehicles[data.id] = data
  table.insert(self.sortedIds, data.id)
  table.sort(self.sortedIds)
  self.couplings[data.id] = {}
  if data.ready then
    self:readyUpVehicle(data.id)
  end

end

function C:getVehicle(id)
  return self.vehicles[id] or {}
end

function C:getVehicleIdByInternalName(name)
  for id, data in pairs(self.vehicles) do
    if data.internalName == name then
      return id
    end
  end
  return -1
end

function C:getVehiclesIdByInternalNameMatch(name)
  local ret = {}
  for id, data in pairs(self.vehicles) do
    if string.find(data.internalName, name) then
      table.insert(ret, id)
    end
  end
  return ret
end

function C:onUpdate()
  for _, id in ipairs(self.sortedIds) do
    local data = self.vehicles[id]
    -- is the vehicle ready yet?
    if not data.ready then
      local veh = scenetree.findObjectById(id)
      if veh then
        data.ready = veh:isReady()
        if data.ready then
          self:readyUpVehicle(id)
        end
      end
    end
  end
end

local couplerTags = {
  tow_hitch = 1,
  fifthwheel = 2
}

function C:readyUpVehicle(id)
  local data = self.vehicles[id]
  local veh = scenetree.findObjectById(id)
  data.ready = true
  if veh and not data.ignoreReadyUp then
    -- delay mapMgr stuff if needed
    local setup = function()
      veh:queueLuaCommand('mapmgr.enableTracking()')
      veh:queueLuaCommand('mapmgr.requestMap()')
    end
    self.mgr.modules.level:delayOrInstantFunction(setup)
    -- instantly get the couple offsets
    --veh:queueLuaCommand('beamstate.getCouplerOffset("core_flowgraphManager.getManagerByID('..self.mgr.id..').modules.vehicle:addCouplerOffset(%s,%s)")')
    for tag, _ in pairs(couplerTags) do
      core_vehicleBridge.requestValue(veh,
        function(ret)
          core_flowgraphManager.getManagerByID(self.mgr.id).modules.vehicle:addCouplerOffset(id, ret.result, tag)
        end
        , 'couplerOffset', tag)
    end

    --core_vehicleBridge.requestValue(veh,function(...) dump(...) end, 'couplerOffset', 'tow_hitch')
    -- instantly get the damage tracker
    --veh:queueLuaCommand('damageTracker.registerDamageUpdateCallback(function(a,b) obj:queueGameEngineLua("core_flowgraphManager.getManagerByID('..self.mgr.id..'):broadcastCall(\'onVehiclePartDamageTracker\',"..obj:getId()..","..dumps(a)..","..dumps(b)..")") end)')
  end
end

function C:addCouplerOffset(id, off, tag)
  local data = self.vehicles[id]
  if data then

    for _,d in pairs(off) do
      table.insert(data.couplerOffset, {v = vec3(d), n = _, tag = tag})
    end
    table.sort(data.couplerOffset, function(a,b) if a.tag == b.tag then return a.n < b.n else return couplerTags[a.tag] < couplerTags[b.tag] end end)

    if #data.couplerOffset > 1 then
      log("I","","Vehicle " .. id .. " has more than one tow hitch! This might cause problems. " .. dumps(data.couplerOffset))
    end
  end
end

function C:executionStarted()
  self._storedWalkBlacklist = gameplay_walk.getBlacklist()
end

function C:storeFuelAmount(id)
  print("Storing fuel...")
  local fun = function(ret)
    if self.vehicles[id] then
      self.vehicles[id].storedEnergyStorage = ret[1]
    else
      log("W","","Vehicle with id " .. id .." is not managed by vehicle moduel. call addForeignVehicle first.")
    end
  end
  local veh = scenetree.findObjectById(id)
  if veh then
    core_vehicleBridge.requestValue(veh, fun, 'energyStorage')
  end
end

function C:setKeepVehicle(id, keep)
  if self.vehicles[id] then
    self.vehicles[id].dontDelete = keep
    local prefab = Prefab.getPrefabByChild(scenetree.findObjectById(id))
    --print("preabid: " .. prefab:getID())
    if prefab then
      self.mgr.modules.prefab:setUnpackVehiclesBeforeDeletion(prefab:getID(), true)
    end
    -- move object out of it's group (if inside a prefab or so, so it wont get deleted)
    -- this is now handled by prefab module
    --[[
    local veh = scenetree.findObjectById(id)
    if veh then
      local parentId = tonumber(veh:getField("parentGroup", 0))
      local parent = scenetree.findObjectById(parentId)
      if parent then
        parent:remove(veh)
      end
      scenetree.MissionGroup:add(veh)
    end
    ]]
  end
end

-- this function will remove all vehicles, except if marked to not delete.
function C:executionStopped()
  for _, id in ipairs(self.sortedIds) do
    local data = self.vehicles[id]
    if not data.dontDelete then
      local obj = scenetree.findObjectById(id)
      if obj then
        if editor and editor.onRemoveSceneTreeObjects then
          editor.onRemoveSceneTreeObjects({id})
        end
        obj:delete()
      end
    else
      -- restore fuel if needed
      local veh = scenetree.findObjectById(id)
      for _, tank in ipairs(self.vehicles[id].storedEnergyStorage or {}) do
        core_vehicleBridge.executeAction(veh, 'setEnergyStorageEnergy', tank.name, tank.currentEnergy)
      end
    end
  end
  if self._storedWalkBlacklist then
    gameplay_walk.clearBlacklist()
    for id, blocked in pairs(self._storedWalkBlacklist) do
      if blocked then
        gameplay_walk.addVehicleToBlacklist(id)
      end
    end
    self._storedWalkBlacklist = nil
  end
  self:clear()
end

function C:onCouplerAttached(objId1, objId2, nodeId, obj2nodeId)
  self.couplings[objId1][objId2] = true
  self.couplings[objId2][objId1] = true
end
function C:onCouplerDetached(objId1, objId2, nodeId, obj2nodeId)
  self.couplings[objId1][objId2] = nil
  self.couplings[objId2][objId1] = nil
end

function C:isCoupled(id) return next(self.couplings[id]) end
function C:isCoupledTo(id, other) return self.couplings[id][other] end


function C:requestBusData(id)
  if not id then return end
  local veh = scenetree.findObjectById(id)
  if veh then
 --   veh:queueLuaCommand("controller.onGameplayEvent('bus_onTriggerTick',{id = "..id.."})")
  end
end

function C:updateBusDisplayData(id, data)
  if not id then return end
  local veh = scenetree.findObjectById(id)
  if veh then
    veh:queueLuaCommand("controller.onGameplayEvent('bus_onRouteChange'," .. serialize(data) .. ")")
  end
end

function C:registerBusChangeNotification(id)
  local veh = scenetree.findObjectById(id)
  if veh then
    core_vehicleBridge.registerValueChangeNotification(veh, "kneel")
    core_vehicleBridge.registerValueChangeNotification(veh, "dooropen")
  end
end

function C:isBusKneel(id) return core_vehicleBridge.getCachedVehicleData(id, 'kneel') == 1 end
function C:isBusDoorOpen(id) return core_vehicleBridge.getCachedVehicleData(id, 'dooropen') == 1 end

function C:requestBusStop(id, data)
  local veh = scenetree.findObjectById(id)
  if veh then
    veh:queueLuaCommand("controller.onGameplayEvent('SetStopRequest'," .. serialize(data) .. ")")
  end
end

function C:isBus(id)
  if not id then return end
  -- all of these values are already cached in other systems.
  local vDetails = core_vehicles.getVehicleDetails(id)
  if not vDetails or not vDetails.model then return false end
  return vDetails.model['Body Style'] == 'Bus'
end

return _flowgraph_createModule(C)