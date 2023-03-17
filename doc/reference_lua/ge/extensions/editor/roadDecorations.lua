-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function findOffsetPoint(spline, length, distance, left)
  local prevPoint = vec3(spline[1])
  local nextPoint = vec3(spline[2])
  local edgeIdx = 0
  if nextPoint then
    -- TODO debuggen edgIdx
    for i = 3, #spline do
      local covered = (nextPoint - prevPoint):length()
      local nextLength = length - covered
      if nextLength < 0 then
        break
      else
        edgeIdx = i - 2
        length = length - covered
        prevPoint = nextPoint
        nextPoint = spline[i]
        if nextPoint == nil then
          return nil
        end
      end
    end

    local lineLength = (nextPoint - prevPoint):length()
    local proportion = length / lineLength
    if proportion > 1 then
      return nil
    end

    local edgePos = (nextPoint - prevPoint) * proportion
    edgePos = prevPoint + edgePos

    local flatDir = (nextPoint - prevPoint)
    if left then
      flatDir = (prevPoint - nextPoint)
    else
      flatDir = (nextPoint - prevPoint)
    end
    flatDir.z = 0
    flatDir = flatDir:normalized()

    local offset = vec3(flatDir.y, -flatDir.x, 0)
    offset = offset * distance
    local point = edgePos + offset
    point.z = edgePos.z

    local rotation = quatFromDir(flatDir)

    -- edgeIdx uses c++ indexing
    return {point = point, rotation = rotation, edgePos = edgePos, edgeIdx = edgeIdx}
  end
end

local function findOppositePoint(rightPoint, rightEdgePosition, roadNormal)
  local offset, rightPosition, rotation

  rightPosition = rightPoint['point']
  rotation = rightPoint['rotation']
  rotation = rightPoint['rotation'] * quatFromDir(vec3(0, -1, 0))

  offset = rightEdgePosition - rightPosition
  offset = offset + offset
  offset = offset + roadNormal

  return {point = rightPosition + offset, rotation = rotation}
end

local function placeDecoration(group, roadName, idx, shapeName, pos, rot)
  local objName = split(shapeName, '/')
  objName = objName[#objName]
  objName = string.format('decoration.%s.%s.%s', roadName, objName, idx)

  local height = core_terrain.getTerrainHeight(vec3(pos.x, pos.y, pos.z))
  if height then
    pos.z = height
  end

  local decoration = createObject('TSStatic')
  decoration:setPosRot(pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, rot.w)
  decoration:setField('shapeName', 0, shapeName)
  decoration:setField('collisionType', 0, 'Collision Mesh')
  decoration:registerObject(objName)
  decoration.scale = vec3(1, 1, 1)
  decoration.canSave = true

  group:addObject(decoration.obj)
  return decoration
end

--[[
Parameters:
  - roadName: The unique name of the DecalRoad to decorate
  - shapeName: Path to the shape file to decorate with
  - distance: Offset to the side of the road
  - period: Interval with which to place objects -- "Every x metres"
  - rotation: Direction vector by which to offset rotation. Props are already rotated to be facing parallel to the road
  - zOff: Vertical offset of the props. Props are placed at the height of the decalroad's closest node with the given offset added
  - align: boolean flag that dis/-enables objects always being placed along the same length of the road
Returns:
  A lua table of all objects created

Example call:
  decorateProps(9459, "levels/driver_training/art/shapes/objects/reflector.dae", 2, 25, nil, 0, true)
  Places a reflector 2 metres off the side of the road every 25 metres with no rotation and no z offset such
  that left and right are on the same length of the road.
--]]
M.decorateProps = function(roadName, shapeName, distance, period, rotation, zOff, align)
  local road = scenetree.findObject(roadName)
  local props = {}
  if road then
    local segCount = road:getEdgeCount()
    local rightEdge = {}
    local leftEdge = {}
    for i = 0, segCount - 1 do
      local left = vec3(road:getLeftEdgePosition(i))
      local right = vec3(road:getRightEdgePosition(i))
      table.insert(leftEdge, left)
      table.insert(rightEdge, right)
    end

    local groupName = string.format('decorations.%d', tostring(roadName))
    local group = scenetree.findObject(groupName)

    if group then
      local groupCounter = 1
      while group do
        groupCounter = groupCounter + 1
        group = scenetree.findObject(groupName .. groupCounter)
      end
      groupName = groupName .. groupCounter
    end

    group = createObject('SimGroup')
    group:registerObject(groupName)
    scenetree.MissionGroup:addObject(group.obj)

    local current = 0
    local idx = 1
    while true do
      local right = findOffsetPoint(rightEdge, current, distance, false)
      local left
      if align and right ~= nil then
        local edgeIdx = right['edgeIdx'] + 1
        left = findOppositePoint(right, right['edgePos'], leftEdge[edgeIdx] - rightEdge[edgeIdx])
      else
        left = findOffsetPoint(leftEdge, current, distance, true)
      end

      if right == nil or left == nil then
        break
      end

      if rotation then
        right['rotation'] = right['rotation'] * rotation
        left['rotation'] = left['rotation'] * rotation
      end

      local zOffset = vec3(0,0,zOff)

      local prop
      prop = placeDecoration(group, roadName, idx, shapeName, right['point'] + zOffset, right['rotation'])
      table.insert(props, prop)
      idx = idx + 1
      prop = placeDecoration(group, roadName, idx, shapeName, left['point'] + zOffset, left['rotation'])
      table.insert(props, prop)
      idx = idx + 1

      current = current + period
    end
    return group:getID()
  end
  return nil
end

M.findOffsetPoint = findOffsetPoint

return M
