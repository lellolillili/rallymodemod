-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local turn90 = quatFromEuler(0,0,math.pi/2)
local obstacleTypes = {}
local shapeNames = {
  sharp1 = 'levels/GridMap/art/shapes/misc/gm_sharp_angle.dae',
  sharp2 = 'levels/GridMap/art/shapes/misc/gm_sharp_vert.dae',
  obstacle1 = 'levels/GridMap/art/shapes/misc/gm_rock_02.dae',
  obstacle2 = 'levels/GridMap/art/shapes/misc/gm_rock_03.dae',
}

local proceduralPrimitives = require('util/trackBuilder/proceduralPrimitives')
local procShapeNames = {
  'ring', 'cube','cylinder','cone'
}

for name,_ in pairs(shapeNames) do obstacleTypes[#obstacleTypes+1] = name end
local objects = {}
for _,oType in ipairs(obstacleTypes) do objects[oType] = {} end

local function getAdjustedPosRotWidth(o, piece)
  local pos, rot, width
  if not piece.points or #piece.points == 0 or o.offset == 1 then
    pos = piece.markerInfo.position
    rot = piece.markerInfo.rot
    width = piece.markerInfo.width
  elseif o.offset == 0 then
    pos = piece.points[1].position + vec3(0,0,piece.points[1].zOffset)
    rot = piece.points[1].finalRot
    width = piece.points[1].width
  else
    local targetLen = lerp(piece.startLength, piece.endLength, clamp(o.offset, 0, 1))
    for i = 1, #piece.points do
      if piece.points[i].length <= targetLen then
        pos = piece.points[i].position + vec3(0,0,piece.points[i].zOffset)
        rot = piece.points[i].finalRot
        width = piece.points[i].width
     end
    end
  end
  return pos, rot, width
end

local function addObject(obstacleType)
  local obj =  createObject('TSStatic')
  obj:setField('shapeName', 0, shapeNames[obstacleType])
  obj:setPosition(vec3(0,0,0))
  obj.scale = vec3(1,1,1)
  obj:setField('rotation', 0, '0 0 1 0')
  obj.canSave = false
  obj:registerObject(obstacleType.."Obstacle"..#objects[obstacleType])
  objects[obstacleType][#objects[obstacleType]+1] = obj
end

local function expandTruncateList(obstacleType, length)
  local list = objects[obstacleType]
  while #list < length do
    addObject(obstacleType)
  end
  for i = length+1, #list do
    local m = #list
    list[m].scale = vec3(0,0,0)
    list[m]:delete()
    list[m] = nil
  end
  return
end

local function placeProceduralObstacles(segment)
  -- count procedural obstacles.
  if not segment.obstaclesChanged then return end
  local procCount = 0
  segment.procObstacleIndexes = {}
  if segment.obstacles then
    for i,o in ipairs(segment.obstacles) do
      if shapeNames[o.value..o.variant] == nil then
        procCount = procCount+1
        segment.procObstacleIndexes[#segment.procObstacleIndexes+1] = i
      end
    end
  end
  if segment.procObstacles == nil then
    segment.procObstacles = {}
  end
  -- create procMeshes as needed
  while #segment.procObstacles < procCount do
    local proc = createObject("ProceduralMesh")
    proc:registerObject('procObstacle'..segment.index..'x'..#segment.procObstacles)
    proc.canSave = false
    scenetree.MissionGroup:add(proc.obj)
    segment.procObstacles[#segment.procObstacles+1] = proc
  end
  -- remove ProcMeshes as needed
  for i = procCount+1, #segment.procObstacles do
    local m = #segment.procObstacles
    segment.procObstacles[m]:delete()
    segment.procObstacles[m] = nil
  end
  if procCount > 0 then
    -- create actual obstacles
    procCount = 0
    for _,o in ipairs(segment.obstacles) do
      if shapeNames[o.value..o.variant] == nil then
        procCount = procCount + 1
        local proc = segment.procObstacles[procCount]
        local mesh = nil
        if o.value == 'ring' then
          mesh = proceduralPrimitives.createRing(math.abs(o.scale.x),math.abs(o.scale.y),o.material)
        elseif o.value == 'cube' then
          mesh = proceduralPrimitives.createCube(o.scale,o.material,o.variant)
        elseif o.value == 'cylinder' then
          mesh = proceduralPrimitives.createCylinder(o.scale.x, o.scale.y,o.material)
        elseif o.value == 'cone' then
          mesh = proceduralPrimitives.createCone(o.scale.x, o.scale.y,o.material)
        elseif o.value == 'bump' then
          mesh = proceduralPrimitives.createBump(o.scale.x, o.scale.y, o.scale.z, o.extra.x, o.extra.y,o.material)
        elseif o.value == 'ramp' then
          mesh = proceduralPrimitives.createRamp(o.scale.x, o.scale.y, o.scale.z, o.extra.x, o.extra.y, o.extra.z, o.material)
        end
        proc:createMesh({{mesh}})
        local pos, rot, width = getAdjustedPosRotWidth(o,segment)
        proc:setPosition((pos + rot:__mul(o.position + vec3(width/2 * (o.anchor-1),0,0))))
        local quat = (turn90:__mul(o.rotation:__mul(rot))):toTorqueQuat()
        proc:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
        proc.scale = vec3(1,1,1)
      end
    end
    segment.obstaclesChanged = false
  end
end

local function placeObstacles(track)
  local data = {}
  for _,oType in ipairs(obstacleTypes) do data[oType] = {} end
  for _,piece in ipairs(track) do
    if piece.obstacles then
      for _,o in ipairs(piece.obstacles) do
        if shapeNames[o.value..o.variant] ~= nil then
          local pos, rot, width = getAdjustedPosRotWidth(o,piece)

          local name = o.value .. o.variant
          --dump(refPoint)
          data[name][#data[name]+1] = {
            obstacleType = name,
            position = pos + rot:__mul(o.position + vec3(width/2 * (o.anchor-1),0,0)),
            rotation = turn90:__mul(o.rotation:__mul(rot)),
            scale = vec3(o.scale.y,o.scale.x,o.scale.z),
            material = o.material
          }
        end
      end
    end
  end

  for name,list in pairs(data) do
    expandTruncateList(name,#list)
    for i,o in ipairs(list) do
      objects[name][i]:setPosition(o.position)
      objects[name][i].scale = o.scale
      local quat = o.rotation:toTorqueQuat()
      objects[name][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
    end
  end
  for _,segment in ipairs(track) do
    placeProceduralObstacles(segment)
  end
end

local function clearReferences()
  for _,oType in ipairs(obstacleTypes) do objects[oType] = {} end
end

M.clearReferences = clearReferences
M.placeObstacles = placeObstacles
M.placeProceduralObstacles = placeProceduralObstacles

return M