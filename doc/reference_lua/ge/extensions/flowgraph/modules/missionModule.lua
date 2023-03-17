-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.dependencies = {'gameplay_walk','core_environment'}
C.moduleOrder = -100 -- low first, high later
function C:init()
  self:clear()
end

function C:clear()
  self.hasStashedVehicles = false
  self.originalPlayerVehicleId = nil
  self.stashedVehicles = {}
  self.stashParams = {}
end

function C:stashWithParams(params)
  if self.hasStashedVehicles then log("E","","Already has stashed vehicles!") return end
  self.stashParams = params or {}
  self:stash()
end

function C:prepareStash()
  local toStash = {}
  for _, name in ipairs(scenetree.findClassObjects("BeamNGVehicle")) do
    local obj = scenetree.findObject(name)
    if obj and obj:getActive() then
      toStash[obj:getId()] = true
    end
  end

  local playerVehicleId = be:getPlayerVehicleID(0) or nil
  self.originalPlayerVehicleId = playerVehicleId
  if self.stashParams.keepPlayer then
    if playerVehicleId then
      toStash[playerVehicleId] = nil
    end
  end


  -- if traffic is enabled, check keepTraffic parameter.
  if gameplay_traffic.getState() == 'on' then
    if self.stashParams.keepTraffic or self.mgr.activity.setupModules.traffic.enabled then
      -- remove all traffic & parked vehicles
      for _, id in ipairs(gameplay_traffic.getTrafficList()) do
        toStash[id] = nil
      end
      for _, id in ipairs(gameplay_parking.getParkedCarsList()) do
        toStash[id] = nil
      end
    else
      self.storedTrafficData, self.storedParkingData = gameplay_traffic.freezeState()
      log("I","","Now stashing all traffic vehicles")
      -- dont put the traffic vehicles in the stash, because traffic system takes care of that!
      --for _, id in ipairs(self.storedTrafficData.vehIds) do
        --toStash[id] = nil
      --end
    end
  end

  toStash = tableKeys(toStash)
  table.sort(toStash)
  return toStash
end

function C:stash()
  local ids = self:prepareStash()
  for _, id in ipairs(ids) do
    if self.stashedVehicles[id] then
      log("W","","Trying to stash already stashed vehicle: " ..id)
    else
      log("D","","Trying to stash vehicle for Flowgraph: " ..id)
      if be:getObjectByID(id) then
        be:getObjectByID(id):setActive(0)
        self.stashedVehicles[id] = true
      end
    end
  end
  self.hasStashedVehicles = true
end

function C:unstashAll()
  local sortedIds = tableKeys(self.stashedVehicles)
  table.sort(sortedIds)
  for _, id in ipairs(sortedIds) do
    log("D","","Trying to unstash vehicle for Flowgraph: " ..id)
    if be:getObjectByID(id) then
      be:getObjectByID(id):setActive(1)
      -- unfreeze all
      core_vehicleBridge.executeAction(be:getObjectByID(id),'setFreeze', false)
    end
  end
  self.stashedVehicles = {}

  if self.storedTrafficData then
    self.mgr.modules.traffic.keepTrafficState = true -- tells the traffic module temporarily to not stop the traffic system
    gameplay_traffic.unfreezeState(self.storedTrafficData, self.storedParkingData)
    self.storedTrafficData, self.storedParkingData = nil, nil
  end
  self.hasStashedVehicles = false
end

function C:removeStashedPlayerVehicle()
  self.mgr:logEvent("Removing stashed player vehicle","I", "The stashed player vehicle will no longer be reactivated at the end of the project.")
  if self.originalPlayerVehicleId then
    local veh = be:getObjectByID(self.originalPlayerVehicleId)
    if veh then
      if editor and editor.onRemoveSceneTreeObjects then
        editor.onRemoveSceneTreeObjects({self.originalPlayerVehicleId})
      end
      veh:delete()
    end
  end
  self.originalPlayerVehicleId = nil
end

function C:executionStopped()
  self:unstashAll()
  local pv = be:getPlayerVehicle(0)
  if self.originalPlayerVehicleId then
    pv = be:getObjectByID(self.originalPlayerVehicleId) or pv
  end

  if pv then
    gameplay_walk.getInVehicle(pv)
    commands.setGameCamera()
    -- auto unfreeze player vehicle
    core_vehicleBridge.executeAction(pv,'setFreeze', false)
    self.originalPlayerVehicleId = nil
  end
  bullettime.setInstant(1)
  if self.storedTod and self.todChanged then
    core_environment.setTimeOfDay(self.storedTod)
    self.storedTod = nil
  end
  self.todChanged = nil
  guihooks.trigger('hotlappingReevaluateControlsEnabled')

  local mission = self.mgr.activity
  if mission and mission.restoreStartingInfoSetup then
    local info = mission._startingInfo
    if info then
      if info.startedFromVehicle then
        local veh = scenetree.findObjectById(info.vehId)
        if veh then
          spawn.safeTeleport(veh,info.vehPos, info.vehRot)
        end
      end
      if info.startedFromCamera then
        setCameraPosRot(
          info.camPos.x, info.camPos.y, info.camPos.z,
          info.camRot.x, info.camRot.y, info.camRot.z, info.camRot.w)
      end
    end
    mission._startingInfo = nil
  end
end

function C:onClear()
end

function C:executionStarted()
  self.todChanged = nil
  self.storedTod = deepcopy(core_environment.getTimeOfDay())
  guihooks.trigger('hotlappingReevaluateControlsEnabled')
end


return _flowgraph_createModule(C)