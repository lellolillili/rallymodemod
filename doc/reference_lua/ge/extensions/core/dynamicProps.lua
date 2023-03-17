-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'dynamicProp'
local forest

local quadtree = require('quadtree')

local up = vec3(0, 0, 1)
local _uid = 0
local cameraPos
local plPos
local underTheMap = vec3(0,0,-999)
local viewAngle = 110 --TODO : use FOV
local dynamicPropsObjs = {}
--############### UTILS FUNCTIONS ################

local function radToDeg(r)
  return (r * 180.0) / 3.14159265359;
end

local function getUniqueId()
  _uid = _uid + 1
  return _uid
end

--in order to make sure forest items are swaped when they are around the corner so we dont see them being swaped, we throw x offset rays
local rayOffset = 3 -- meters
local rayCount = 3 --odd number only
local function checkVisibility(pos) -- returns true if can see
  local targetVec = cameraPos - pos
  local left = targetVec:cross(up):normalized() * rayOffset
  local targetVecLen = targetVec:length()
  local iOffset = math.ceil(rayCount / 2)

  for i = 1, rayCount, 1 do
    dump(i - iOffset)
    dump(left)
    local actualPos = cameraPos + left * (i - iOffset)
    dump(actualPos)
    dump(pos)
    targetVec = actualPos - pos
    targetVecLen = targetVec:length()
    debugDrawer:drawLine(actualPos, actualPos + targetVecLen * targetVec:normalized(), ColorF(0,0,1,1))
    dump(targetVec)
    dump(targetVecLen)
    dump(castRayStatic(actualPos, targetVec:normalized(), targetVecLen))
    dump("==============")
    if castRayStatic(actualPos, targetVec:normalized(), targetVecLen) >= targetVecLen then return true end
  end
  dump("===============")
  return false
end


--############### DYNAMICPROPS OBJECT ################

local DynamicProps = {}

DynamicProps.__index = DynamicProps

function DynamicProps:__tostring()
  return "Pool name : "..self.name..". Forest item : "..self.forestItemName..". Prop Item : "..self.propName.."."
end

function DynamicProps:new(data)
  if not next(data) then
    log('E', logTag, "Can't create dynamic props with no parameters, at least specify which forest item has to be replaced and by which prop")
    return nil
  end

  local object = {}
  object.name = data.name or "DynamicPropsId" .. getUniqueId()
  object.forestItemName = data.forestItemName
  object.artifacts = data.artifacts or {}
  object.propName = data.propName
  object.poolSize = data.poolSize or 10
  object.spawnInViewRange = data.spawnInViewRange or 100
  object.spawnOffset = data.spawnOffset or vec3(0, 0, 0)

  object.props = {}

  object.locationsInfo = {}
  object.propAndItem = {} --When switching a forest item with a prop, need to link them together

  setmetatable(object, DynamicProps)
  return object
end

local function createDynamicProps(data)
  local obj = DynamicProps:new(data)
  obj:findForestItems()
  obj:spawnProps()
  be:reloadCollision(false, true)
  table.insert(dynamicPropsObjs, obj)
end

function DynamicProps:spawnProps()
  for i = 1, self.poolSize, 1 do
    local options = {vehicleName = self.propName .. i, licenseText = self.propName .. i}
    local spawningOptions = sanitizeVehicleSpawnOptions(self.propName, options)
    spawningOptions.autoEnterVehicle = false
    local vehId = core_vehicles.spawnNewVehicle(spawningOptions.model, spawningOptions):getId()

    be:getObjectByID(vehId):setActive(0)
    self.props[vehId] = false
  end
end

function DynamicProps:findForestItems()
  forest = scenetree.findObject("theForest")
  self.forestQt = quadtree.newQuadtree()
  if forest then
    local everyForestItems = forest:getData():getItems()
    local data
    for i = 1, #everyForestItems, 1 do
        data = everyForestItems[i]:getData()
        if data:getName() == self.forestItemName then
          local locationInfo = {
            forestItem = everyForestItems[i],
            switched = false,
            originPos = everyForestItems[i]:getPosition(),
            distance = math.huge,
            linkedPropId = nil,
            id = i}

          table.insert(self.locationsInfo, locationInfo)
          local fPos = locationInfo.forestItem:getPosition()
          self.forestQt:preLoad(locationInfo,fPos.x, fPos.y, fPos.x, fPos.y)
        end
    end
    self.forestQt:build()
  else
    log('I', logTag, "Forest object hasn't been found")
  end
end

function DynamicProps:getFirstPropAvailable()
  for id, value in pairs(self.props) do
    if not value then
      self.props[id] = true
      return id
    end
  end
  return nil
end

function DynamicProps:spawnProp(locationInfo, propId)
  local forestItem = locationInfo.forestItem
  local itemRot = forestItem:getTransform():toQuatF()

  forestItem:setPosition(underTheMap)
  forest:getData():updateItem(forestItem:getKey(), underTheMap, forestItem:getData(), forestItem:getTransform(), forestItem:getScale())
  be:getObjectByID(propId):setActive(1)
  --spawn.safeTeleport(scenetree.findObjectById(propId), (locationInfo.originPos + self.spawnOffset), quat(0, 0, 0, 0))
  local spawnPos = locationInfo.originPos + self.spawnOffset
  vehicleSetPositionRotation(propId, spawnPos.x, spawnPos.y, spawnPos.z, itemRot.x, itemRot.y, itemRot.z, itemRot.w)
  locationInfo.switched = true
  locationInfo.linkedPropId = propId
  dump("Spawning")
end

function DynamicProps:despawnProp(locationInfo)
  local forestItem = locationInfo.forestItem
  local veh = scenetree.findObjectById(locationInfo.linkedPropId)
  veh:resetBrokenFlexMesh()
  veh:setActive(0)
  locationInfo.switched = false
  locationInfo.distance = math.huge
  locationInfo.linkedPropId = nil
  forestItem:setPosition(locationInfo.originPos)
  forest:getData():updateItem(forestItem:getKey(), locationInfo.originPos, forestItem:getData(), forestItem:getTransform(), forestItem:getScale())
  dump("Despawning")
end

local locationInfo
function DynamicProps:onUpdate()

  --########### Detect in-sight forest props ##########

  local center = plPos
  local locationsInSight = {}
  for locationInfo in self.forestQt:queryNotNested(
    center.x - self.spawnInViewRange, center.y - self.spawnInViewRange,
    center.x + self.spawnInViewRange, center.y + self.spawnInViewRange) do

    --check fov, actual distance etc
    --local actualPosToCheck = locationInfo.switched and be:getObjectByID(locationInfo.linkedPropId):getPosition() or locationInfo.originPos
    --if checkVisibility(actualPosToCheck) then
      locationInfo.distance = locationInfo.originPos:distance(center)
      table.insert(locationsInSight, locationInfo)
    --end
  end

  table.sort(locationsInSight, function(a,b) return a.distance < b.distance end)

  --########## Shift Ids around, only logic ##########

  local spawnCount = math.min(self.poolSize, #locationsInSight)
  local toDespawnWithinView = #locationsInSight - spawnCount

  local propsToDespawn = {}
  for i = 1, #self.locationsInfo, 1 do
    locationInfo = self.locationsInfo[i]

    local isInSight = false
    for j = 1, #locationsInSight, 1 do
      if locationsInSight[j].id == locationInfo.id then
        isInSight = true
        break
      end
    end

    if locationInfo.switched and not isInSight then
      table.insert(propsToDespawn, locationInfo)
      self.props[locationInfo.linkedPropId] = false
    end
  end

  for i = 0, toDespawnWithinView - 1, 1 do
    locationInfo = locationsInSight[#locationsInSight - i]
    if locationInfo.switched then
      table.insert(propsToDespawn, locationInfo)
      self.props[locationInfo.linkedPropId] = false
    end
  end

  local propsToSpawn = {}
  for i = 1, spawnCount, 1 do
    locationInfo = locationsInSight[i]
    if not locationInfo.switched then
      local freeProp = self:getFirstPropAvailable()
      if freeProp then
        table.insert(propsToSpawn, {location = locationInfo, propId = freeProp})
      end
    end
  end


  --########## Actual actions ##########

  for i = 1, #propsToDespawn, 1 do
    self:despawnProp(propsToDespawn[i])
  end


  for i = 1, #propsToSpawn, 1 do
    self:spawnProp(propsToSpawn[i].location, propsToSpawn[i].propId)
  end
end

local tempCopy
function DynamicProps:unload()
  --first despawn every prop
  for i = 1, #self.locationsInfo, 1 do
    locationInfo = self.locationsInfo[i]
    if locationInfo.switched then
      self:despawnProp(locationInfo)
    end
  end

  -- then remove them
  local source
  for id, _ in pairs(self.props) do
    source = scenetree.findObjectById(id)
    if editor and editor.onRemoveSceneTreeObjects then
      editor.onRemoveSceneTreeObjects({source:getId()})
    end
    source:delete()
  end

  tempCopy[self] = nil
end

  --########## END OF OBJECTS FUNCTION ##########

local function onUpdate()
  cameraPos = getCameraPosition()
  plPos = be:getPlayerVehicle(0):getPosition()
  for i = 1, #dynamicPropsObjs, 1 do
    dynamicPropsObjs[i]:onUpdate()
  end
end

local function unloadAll()
  tempCopy = deepcopy(dynamicPropsObjs)
  for i = 1, #dynamicPropsObjs, 1 do
    dynamicPropsObjs[i]:unload()
  end
  dump(tempCopy)
  dynamicPropsObjs = deepcopy(tempCopy)
  be:reloadCollision(false, false)
end

local function westCoastPole()
  createDynamicProps({
    forestItemName = "pole_city1",
    propName = "streetlight",
    poolSize = 1,
    spawnInViewRange = 100,
    spawnOffset = vec3(0, 0, -0.22)
  })
end

local function westCoastBin()
  createDynamicProps({
    forestItemName = "postbox_blue",
    propName = "trashbin",
    poolSize = 9,
    spawnInViewRange = 150,
    spawnOffset = vec3(0, 0, 0)
  })
end

M.westCoastPole = westCoastPole
M.westCoastBin = westCoastBin

M.unloadAll = unloadAll
M.createDynamicProps = createDynamicProps
M.onUpdate = onUpdate


return M