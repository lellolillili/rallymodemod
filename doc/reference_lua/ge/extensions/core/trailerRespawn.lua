-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = 'trailerRespawn'

local enabled = true
local trailerReg = {}
local couplerOffset = {}

local function onSerialize()
  local data = {}
  data.trailerReg = trailerReg
  data.couplerOffset = couplerOffset
  data.enabled = enabled
  return data
end

local function onDeserialized(data)
  trailerReg = data.trailerReg
  couplerOffset = data.couplerOffset
  enabled = data.enabled
  M.setEnabled(enabled)
end

local function resetData()
  trailerReg = {}
  couplerOffset = {}
  enabled = true
  M.setEnabled(enabled)
end

local function getTrailerData()
  return trailerReg
end

--return true if create a loop
local function checkRedundancy(trailerId, forbiddenId)
  if trailerReg[trailerId] and trailerReg[trailerId]~= -1 then
    if trailerReg[trailerId].trailerId == forbiddenId then
      return true
    else
      return checkRedundancy(trailerReg[trailerId].trailerId, forbiddenId)
    end
  end
  return false
end

local function onCouplerAttached(objId1, objId2, nodeId, obj2nodeId)
  if objId1 == objId2 then --[[log("E", logTag, "same vehicle ID");]] return end
  if couplerOffset[objId1] == nil or couplerOffset[objId1][nodeId] == nil or couplerOffset[objId2] == nil or couplerOffset[objId2][obj2nodeId] == nil then
    -- log("I", logTag, "Coupler Id not found, probably nodegrabber")
    --log("I", logTag, dumps(couplerOffset[objId1]) .. " | ".. dumps(couplerOffset[objId1][nodeId]) .. " | ".. dumps(couplerOffset[objId2]) .. " | ".. dumps(couplerOffset[objId2][obj2nodeId] ) )
    return
  end

  local obj2 = be:getObjectByID(objId2)
  local obj2Model = core_vehicles.getModel(obj2:getField('JBeam','0')).model
  if obj2Model.Type == "Trailer" then
    log("D", logTag, tostring(objId1).." registered trailer "..tostring(objId2).."  node = "..tostring(nodeId).."  trailernode = "..tostring(obj2nodeId))
    if checkRedundancy(objId2, objId1) then
      log("E", logTag, "Tried to register a loop")
      return
    end
    trailerReg[objId1] = {trailerId=objId2, trailerNode=obj2nodeId, node=nodeId}
  else
    log("D", logTag, tostring(objId2).." registered trailer "..tostring(objId1).."  node = "..tostring(obj2nodeId).."  trailernode = "..tostring(nodeId))
    if checkRedundancy(objId1,objId2) then
      log("E", logTag, "Tried to register a loop")
      return
    end
    trailerReg[objId2] = {trailerId=objId1, trailerNode=nodeId, node=obj2nodeId}
  end
end

local function onCouplerDetach(objId1, nodeId)
  --log("D", logTag, tostring(objId1).." onCouplerDetached "..tostring(nodeId))
  if trailerReg[objId1] and trailerReg[objId1] ~= -1 then
    log("D", logTag, "Unregistered "..tostring(objId1))
    trailerReg[objId1] = -1
    return
  end

  for vId,tId in pairs(trailerReg) do
    if tId ~= -1 and tId.trailerId == objId1 then
      log("D", logTag, "Unregistered "..tostring(objId1))
      trailerReg[vId] = -1
      return
    end
  end
end

local couplerTags = {
  tow_hitch = 1,
  fifthwheel = 2
}

local function onVehicleActiveChanged(vehId, active)
  -- sets the vehicle's trailer visibility state to match the owner
  if trailerReg[vehId] and trailerReg[vehId] ~= -1 then
    be:getObjectByID(trailerReg[vehId].trailerId):setActive(active and 1 or 0)
    log("D", logTag, "Trailer "..tostring(trailerReg[vehId].trailerId).." active state set to "..tostring(active))

    if active then
      local tmp = couplerOffset[trailerReg[vehId].trailerId][trailerReg[vehId].trailerNode]
      spawn.placeTrailer(vehId, couplerOffset[vehId][trailerReg[vehId].node], trailerReg[vehId].trailerId, tmp)
    end
  end
end

local function onVehicleSpawned(vehId)
  -- log("E", logTag, tostring(vehId))

  if couplerOffset[vehId] then
    couplerOffset[vehId] = nil
  end

  if trailerReg[vehId] then
    log("D", logTag, "Unregistered vehicle "..tostring(vehId).."; trailer was ".. (type(trailerReg[vehId]) == "table" and tostring(trailerReg[vehId].trailerId) or trailerReg[vehId]))
    trailerReg[vehId] = nil
  end

  for vId,tId in pairs(trailerReg) do
    if tId ~= -1 and tId.trailerId == vehId then
      log("D", logTag, "Unregistered trailer "..tostring(vehId).."; vehicle was "..tostring(vId))
      trailerReg[vId] = -1
    end
  end

  local veh = be:getObjectByID(vehId)
  --veh:queueLuaCommand('beamstate.getCouplerOffset("if core_trailerRespawn then core_trailerRespawn.addCouplerOffset(%s,%s) end")')
  for tag, _ in pairs(couplerTags) do
    core_vehicleBridge.requestValue(veh, function(ret) M.addCouplerOffset(vehId, ret.result, tag) end, 'couplerOffset', tag)
  end
end

local function onVehicleResetted(vehId)
  -- log("D", logTag, tostring(vehId).."   "..dumps(trailerReg[vehId]) )
  if trailerReg[vehId] and trailerReg[vehId] ~= -1 then
    -- log("I", logTag, "veh COUPLER "..tostring(trailerReg[vehId].node).."   "..tostring(couplerOffset[vehId][trailerReg[vehId].node]) )
    local tmp = couplerOffset[trailerReg[vehId].trailerId][trailerReg[vehId].trailerNode]
    --if tmp.y > 0 then tmp.y = -tmp.y end
    -- log("I", logTag, "trailer coupler "..tostring(trailerReg[vehId].trailerId).."   "..tostring(tmp) )
    spawn.placeTrailer(vehId, couplerOffset[vehId][trailerReg[vehId].node], trailerReg[vehId].trailerId, tmp)
  end
end

local function onVehicleDestroyed(vehId)
  -- log("I","trailerRespawn.onVehicleDestroyed", tostring(vehId))
  if couplerOffset[vehId] then
    couplerOffset[vehId] = nil
  end

  if trailerReg[vehId] then
    log("D", logTag, "Unregistered vehicle "..tostring(vehId).."; trailer was "..(type(trailerReg[vehId]) == "table" and tostring(trailerReg[vehId].trailerId) or trailerReg[vehId]))
    trailerReg[vehId] = nil
    return
  end

  for vId,tId in pairs(trailerReg) do
    if tId ~= -1 and tId.trailerId == vehId then
      log("D", logTag, "Unregistered trailer "..tostring(vehId).."; vehicle was "..tostring(vId))
      trailerReg[vId] = -1
      return
    end
  end
end

local function addCouplerOffset(vId, data, tag)
  --log("E", logTag, "Vehicle "..tostring(vId).." couplers data"..dumps(data))
  couplerOffset[vId] = couplerOffset[vId] or {}
  for id, off in pairs(data) do
    couplerOffset[vId][id] = vec3(off)
  end
end

local function debugUpdate(dt, dtSim)
  if M.debugEnabled == false then return end

  -- highlight all coupling nodes

  for vID,c in pairs(couplerOffset) do
    local veh = be:getObjectByID(vID)
    if veh then
      local pos = veh:getPosition()
      for ci,cpos in pairs(c) do
        debugDrawer:drawSphere( (pos+cpos), 0.05, ColorF(1, 0, 0, 1))
        debugDrawer:drawTextAdvanced( (pos+cpos), String(tostring(vID.."@"..ci)), ColorF(0.2, 0, 0, 1), true, false, ColorI(255,255,255,255) )
        -- print(tostring(vID).." = "..tostring((pos+cpos)))
      end
    else
      --log("E", logTag, "Vehicle "..tostring(vID).." invalid !!!!")
    end
  end
end

local function setEnabled(enabled) -- automatically or manually enables or disables the trailer respawn system
  if enabled then
    M.onCouplerAttached = onCouplerAttached
    M.onCouplerDetach = onCouplerDetach
    M.onVehicleResetted = onVehicleResetted
  else
    M.onCouplerAttached = nop
    M.onCouplerDetach = nop
    M.onVehicleResetted = nop
  end
end

M.setEnabled = setEnabled
M.getTrailerData = getTrailerData
M.addCouplerOffset = addCouplerOffset

M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onCouplerAttached = onCouplerAttached
M.onCouplerDetach = onCouplerDetach
M.onVehicleActiveChanged = onVehicleActiveChanged
M.onVehicleSpawned = onVehicleSpawned
M.onVehicleResetted = onVehicleResetted
M.onVehicleDestroyed = onVehicleDestroyed

M.debugEnabled = false
-- M.onPreRender = debugUpdate
M.resetData = resetData

return M