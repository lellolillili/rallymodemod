-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = "vehiclePooling"

local _uid = 0
local pools = {}
local VehPool = {}

M.logErrors = false

VehPool.__index = VehPool

-- Vehicle pool main components:
-- activeVehs = array of active (visible) vehicles, by id
-- inactiveVehs = array of inactive (invisible) vehicles, by id
-- allVehs = dict of all vehicles, by id (active state = 1, inactive state = 0)
-- total = cached total amount of vehicles in pool
-- maxActiveVehs = limit of active vehicles

-- active and inactive tables are arrays, to preserve insert / remove order

local function getUniqueId()
  _uid = _uid + 1
  return _uid
end

function VehPool:__tostring()
  return "["..self.id.."] active: {"..table.concat(self.activeVehs, ", ").."}"..", inactive: {"..table.concat(self.inactiveVehs, ", ").."}"
end

function VehPool:new(data)
  data = data or {}
  local object = {}

  object.id = data.id or getUniqueId()
  object.name = data.name or "pool" .. object.id
  object.activeVehs = data.activeVehs or {}
  object.inactiveVehs = data.inactiveVehs or {}
  object.maxActiveVehs = data.maxActiveVehs or math.huge

  setmetatable(object, VehPool)
  object = self:finalize(object)
  return object
end

function VehPool:onSerialize()
  local data = {}
  data.id = self.id
  data.name = self.name
  data.activeVehs = self.activeVehs
  data.inactiveVehs = self.inactiveVehs
  data.allVehs = self.allVehs
  data.total = self.total
  data.maxActiveVehs = self.maxActiveVehs

  return data
end

function VehPool:onDeserialized(data)
  if not data then return end
  for k, v in pairs(data) do
    self[k] = v
  end
end

function VehPool:finalize(object)
  object.allVehs = {}
  object.total = 0
  for _, v in ipairs(object.activeVehs) do
    object.allVehs[v] = 1
    object.total = object.total + 1
  end
  for _, v in ipairs(object.inactiveVehs) do
    object.allVehs[v] = 0
    object.total = object.total + 1
  end

  local valid = false
  while not valid do -- id validation
    valid = true
    for id, _ in pairs(pools) do
      if id == object.id then
        object.id = getUniqueId()
        valid = false
      end
    end
  end

  return object
end

function VehPool:deletePool(keepVehicles)
  if not keepVehicles then
    for k, v in pairs(self.inactiveVehs) do
      local obj = be:getObjectByID(v)
      if obj then obj:delete() end
    end
  end
  pools[self.id] = nil
  extensions.hook("onVehiclePoolRemoved", self.id)
end

-- inactivates passed vehicle, activates one and returns it
function VehPool:cycle(vehId1, vehId2)
  -- vehId1 and vehId2 are optional, otherwise the first table entry is used
  vehId1 = vehId1 or self.activeVehs[1]
  vehId2 = vehId2 or self.inactiveVehs[1]
  if not vehId1 or not vehId2 or not self.allVehs[vehId1] or not self.allVehs[vehId2] then return false end

  self.maxActiveVehs = self.maxActiveVehs + 1 -- TEMP hack
  self:setVeh(vehId1, false)
  self:setVeh(vehId2, true)
  self.maxActiveVehs = self.maxActiveVehs - 1
  return vehId1, vehId2
end

-- sets a vehicle as inactive from this pool and activates one from another pool
function VehPool:crossCycle(otherPool, vehId1, vehId2)
  if not otherPool or self.id == otherPool.id then return self:cycle(vehId1, vehId2) end

  vehId1 = vehId1 or self.activeVehs[1]
  vehId2 = vehId2 or otherPool.inactiveVehs[1]
  if not vehId1 or not vehId2 or not self.allVehs[vehId1] or not self.allVehs[vehId2] then return false end

  self:setVeh(vehId1, false)
  otherPool:setVeh(vehId2, true)
  return vehId1, vehId2
end

-- returns true if successfully inserted the new active vehicle
function VehPool:tryInsertActiveVeh(vehId, forceInsert)
  if #self.activeVehs == self.maxActiveVehs then
    if forceInsert then
      self.maxActiveVehs = self.maxActiveVehs + 1
    else
      if M.logErrors then log("W", logTag, "Trying to activate a vehicle but the amount of maximum active vehicles has been reached") end
      return false
    end
  end

  return true
end

-- returns true if successful insert
function VehPool:insertVeh(vehId, forceInsert)
  local obj = be:getObjectByID(vehId)
  if not obj then return false end
  if self.allVehs[vehId] then
    if M.logErrors then log("W", logTag, "The vehicle with id: " .. vehId .. " is already inserted in this pool") end
    return false
  end

  local state
  if obj:getActive() then
    state = self:tryInsertActiveVeh(vehId, forceInsert) and "activeVehs" or "inactiveVehs"
  else
    state = "inactiveVehs"
  end
  if state then
    table.insert(self[state], vehId)
    self.allVehs[vehId] = state == "activeVehs" and 1 or 0
    self.total = self.total + 1
    obj:setActive(state == "activeVehs" and 1 or 0) -- triggers VehPool:_setVeh
  end

  return state and true or false
end

-- returns true if successful removal
function VehPool:removeVeh(vehId)
  if not self.allVehs[vehId] then return false end

  local result = arrayFindValueIndex(self.activeVehs, vehId)
  local state
  if result then
    state = "activeVehs"
  else
    result = arrayFindValueIndex(self.inactiveVehs, vehId)
    if result then
      state = "inactiveVehs"
    end
  end
  if state then
    table.remove(self[state], result)
    self.allVehs[vehId] = nil
    self.total = self.total - 1
  end

  return state and true or false
end

--returns true if activated/deactivated at least one vehicle
function VehPool:setAllVehs(activate)
  -- tables are temporarily copied due to asynchronous change of vehicle active state
  if activate then
    if not self.inactiveVehs[1] then return false end

    local difference = self.maxActiveVehs - #self.activeVehs
    for _, v in ipairs(deepcopy(self.inactiveVehs)) do
      if difference <= 0 then break end
      difference = difference - 1
      self:setVeh(v, true)
    end
    return true
  else
    if not self.activeVehs[1] then return false end
    for _, v in ipairs(deepcopy(self.activeVehs)) do
      self:setVeh(v, false)
    end
    return true
  end
end

-- internal active state manager, do not call this
function VehPool:_setVeh(vehId, activate)
  if not self.allVehs[vehId] then return end

  if (activate and self.allVehs[vehId] == 1) or (not activate and self.allVehs[vehId] == 0) then
    log("W", logTag, "Vehicle with id ".. vehId .. " is already " .. (activate and "activated" or "deactivated"))
    return
  end

  if activate then
    table.remove(self.inactiveVehs, arrayFindValueIndex(self.inactiveVehs, vehId))
    table.insert(self.activeVehs, vehId)
    self.allVehs[vehId] = 1
  else
    table.remove(self.activeVehs, arrayFindValueIndex(self.activeVehs, vehId))
    table.insert(self.inactiveVehs, vehId)
    self.allVehs[vehId] = 0
  end
end

-- returns true if successful toggle
-- forceInsert is used when the maxActiveVeh is reached, if yes it will increase the limit
function VehPool:setVeh(vehId, activate, forceInsert)
  if not self.allVehs[vehId] then return false end

  if (activate and self.allVehs[vehId] == 1) or (not activate and self.allVehs[vehId] == 0) then
    log("W", logTag, "Vehicle with id ".. vehId .. " is already " .. (activate and "activated" or "deactivated"))
    return false
  end

  if activate then
    if self:tryInsertActiveVeh(vehId, forceInsert) then
      be:getObjectByID(vehId):setActive(1)
    else
      return false
    end
  else
    be:getObjectByID(vehId):setActive(0)
  end

  return true
end

-- sets the maximum amount of active vehicles allowed
function VehPool:setMaxActiveVehs(amount)
  amount = math.max(0, amount or 1)
  self.maxActiveVehs = amount
  if amount == math.huge then return end

  local difference = #self.activeVehs - amount

  if difference > 0 then -- remove some active vehicles
    for i, v in ipairs(deepcopy(self.activeVehs)) do
      if i <= difference then
        self:setVeh(v, false) -- making sure we still have active cars to deactivate
      end
    end
  end
end

-- activates or deactivates vehicles with respect to their distance to the target position and max distance
function VehPool:activateByDistanceTo(pos, dist)
  if not pos then return end
  dist = dist or 300

  for i, state in ipairs({"activeVehs", "inactiveVehs"}) do
    for _, v in ipairs(deepcopy(self[state])) do
      local obj = be:getObjectByID(v)
      if obj then
        if i == 1 and obj:getPosition():squaredDistance(pos) > square(dist) then
          self:setVeh(v, false)
        end
        if i == 2 and obj:getPosition():squaredDistance(pos) <= square(dist) then
          self:setVeh(v, true)
        end
      end
    end
  end
end

function VehPool:getVehs()
  return arrayConcat(deepcopy(self.activeVehs), self.inactiveVehs)
end

--[[ Manager ]]--

local function createPool(data)
  local pool = VehPool:new(data)
  pools[pool.id] = pool
  extensions.hook("onVehiclePoolAdded", pool.id)
  return pool
end

local function deletePool(id)
  pools[id] = nil
end

local function getPool(name)
  if not name then return end
  for _, pool in pairs(pools) do
    if pool.name == name then return pool end
  end
end

local function getPoolOfVeh(vehId)
  for id, pool in pairs(pools) do
    if pool.allVehs[vehId] then
      return pool, pool.allVehs[vehId] == 1
    end
  end
end

local function getPoolById(id)
  return id and pools[id]
end

local function getAllPools()
  return pools
end

local function deleteAllPools()
  for _, pool in pairs(pools) do
    pool:deletePool()
  end
  pools = {}
end

local function onVehicleActiveChanged(vehId, active)
  for _, pool in pairs(pools) do
    pool:_setVeh(vehId, active)
  end
end

local function onVehicleDestroyed(vehId)
  for _, pool in pairs(pools) do
    pool:removeVeh(vehId)
  end
end

local function onClientEndMission()
  deleteAllPools()
end

local function onSerialize()
  local data = {}
  for _, pool in pairs(pools) do
    table.insert(data, pool:onSerialize())
  end

  return data
end

local function onDeserialized(data)
  for _, v in ipairs(data) do
    local pool = createPool()
    pool:onDeserialized(v)
  end
end

M.createPool = createPool
M.deletePool = deletePool
M.getPool = getPool
M.getPoolById = getPoolById
M.getPoolOfVeh = getPoolOfVeh
M.getAllPools = getAllPools
M.deleteAllPools = deleteAllPools

M.onVehicleActiveChanged = onVehicleActiveChanged
M.onVehicleDestroyed = onVehicleDestroyed
M.onClientEndMission = onClientEndMission
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M