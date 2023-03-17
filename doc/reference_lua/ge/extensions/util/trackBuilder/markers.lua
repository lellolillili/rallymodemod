-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local names = {"bank","height","width","checkpoint","leftWall","rightWall", "ceilingMesh"--[["centerMesh","leftMesh","rightMesh"]]}
local markers = {}
-- this holds the indizes of the pieces which markers have been changed.
local markerChanges = {}


--creates a banking marker at the specified position with the correct rotation.
local function addBankMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/track_editor_marker.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(0.1, 5, 2.5)
  marker:setField('rotation', 0, '0 0 1 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 0 0 1')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("bankMarker"..#list)

  list[#list+1] = marker
end

--creates a height marker.
local function addHeightMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/track_editor_marker.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(2, 2, 20)
  marker:setField('rotation', 0, '1 0 0 180')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '0 0 1 1')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("heightMarker"..#list)

  list[#list+1] = marker
end

--creates two width markers
local function addWidthMarker(list)
  --create and store marker 1
  local index = #list
  local markerRight =  createObject('TSStatic')
  markerRight:setField('shapeName', 0, "art/shapes/interface/checkpoint_marker_sphere.dae")
  markerRight:setPosition(vec3(0,0,0))
  markerRight.scale = vec3(2,2,2)
  markerRight:setField('rotation', 0, '0 0 1 0')
  markerRight.useInstanceRenderData = true
  markerRight:setField('instanceColor', 0, '0 1 0 1')
  markerRight:setField('collisionType', 0, "Collision Mesh")
  markerRight:setField('decalType', 0, "Collision Mesh")
  markerRight:setField('playAmbient', 0, "1")
  markerRight:setField('allowPlayerStep', 0, "1")
  markerRight:setField('canSave', 0, "0")
  markerRight:setField('canSaveDynamicFields', 0, "1")
  markerRight:setField('renderNormals', 0, "0")
  markerRight:setField('meshCulling', 0, "0")
  markerRight:setField('originSort', 0, "0")
  markerRight:setField('forceDetail', 0, "-1")
  markerRight.canSave = false
  markerRight:registerObject("widthMarker"..index)
  list[index+1] = markerRight

  local markerLeft =  createObject('TSStatic')
  markerLeft:setField('shapeName', 0, "art/shapes/interface/checkpoint_marker_sphere.dae")
  markerLeft:setPosition(vec3(0,0,0))
  markerLeft.scale = vec3(2,2,2)
  markerLeft:setField('rotation', 0, '0 0 1 0')
  markerLeft.useInstanceRenderData = true
  markerLeft:setField('instanceColor', 0, '0 1 0 1')
  markerLeft:setField('collisionType', 0, "Collision Mesh")
  markerLeft:setField('decalType', 0, "Collision Mesh")
  markerLeft:setField('playAmbient', 0, "1")
  markerLeft:setField('allowPlayerStep', 0, "1")
  markerLeft:setField('canSave', 0, "0")
  markerLeft:setField('canSaveDynamicFields', 0, "1")
  markerLeft:setField('renderNormals', 0, "0")
  markerLeft:setField('meshCulling', 0, "0")
  markerLeft:setField('originSort', 0, "0")
  markerLeft:setField('forceDetail', 0, "-1")
  markerLeft.canSave = false
  markerLeft:registerObject("widthMarker"..index..'b')
  list[index+2] = markerLeft
end

--creates a banking marker at the specified position with the correct rotation.
local function addCenterMeshMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/track_editor_marker.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(3, 0.1, 3)
  marker:setField('rotation', 0, '0 0 1 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 0 1 0.66')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("centerMeshMarker"..#list)

  list[#list+1] = marker
end

--creates a banking marker at the specified position with the correct rotation.
local function addLeftMeshMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/track_editor_marker.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(2.25, 0.1, 2.25)
  marker:setField('rotation', 0, '0 0 1 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 0 1 0.66')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("leftMeshMarker"..#list)

  list[#list+1] = marker
end

--creates a banking marker at the specified position with the correct rotation.
local function addRightMeshMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/track_editor_marker.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(2.25, 0.1, 2.25)
  marker:setField('rotation', 0, '0 0 1 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 0 1 0.66')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("rightMeshMarker"..#list)

  list[#list+1] = marker
end

--creates a banking marker at the specified position with the correct rotation.
local function addCheckpointMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/checkpoint_marker_sphere.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(3, 0.1, 3)
  marker:setField('rotation', 0, '0 0 1 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 1 1 0.4')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("checkPointMarker"..#list)

  list[#list+1] = marker
end

--creates a banking marker at the specified position with the correct rotation.
local function addRightWallMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/track_editor_marker.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(2.25, 0.1, 2.25)
  marker:setField('rotation', 0, '0 0 1 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 0.5 0 0.66')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("rightWallMarker"..#list)

  list[#list+1] = marker
end

--creates a banking marker at the specified position with the correct rotation.
local function addLeftWallMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/track_editor_marker.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(2.25, 0.1, 2.25)
  marker:setField('rotation', 0, '0 0 1 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 0.5 0 0.66')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("leftWallMarker"..#list)

  list[#list+1] = marker
end

--creates a banking marker at the specified position with the correct rotation.
local function addCeilingMeshMarker(list)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, "art/shapes/interface/track_editor_marker.dae")
  marker:setPosition(vec3(0,0,0))
  marker.scale = vec3(1.5, 0.1, 5)
  marker:setField('rotation', 0, '0 0 1 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 0.65 0 0.66')
  marker:setField('collisionType', 0, "Collision Mesh")
  marker:setField('decalType', 0, "Collision Mesh")
  marker:setField('playAmbient', 0, "1")
  marker:setField('allowPlayerStep', 0, "1")
  marker:setField('canSave', 0, "0")
  marker:setField('canSaveDynamicFields', 0, "1")
  marker:setField('renderNormals', 0, "0")
  marker:setField('meshCulling', 0, "0")
  marker:setField('originSort', 0, "0")
  marker:setField('forceDetail', 0, "-1")
  marker.canSave = false
  marker:registerObject("ceilingMeshMarker"..#list)

  list[#list+1] = marker
end

-- mini function to get all indizes of the track which contain a specific field
local function nodeGetter(name,allNodes)
  local list = {}
  for s = 1, #allNodes do
    for i = 1, #allNodes[s] do
      if allNodes[s][i][name] ~= nil then
        list[#list+1] = allNodes[s][i]
      end
    end
  end
  return list
end

-- mini function to fill the list with enough objects and hide unneccesary objects
local function expandTruncateList(list, length, addFunction)
  while #list < length do
    addFunction(list)
  end
  for i = length+1, #list do
    local m = #list
    list[m].scale = vec3(0,0,0)
    list[m] = nil
  end
  return
end

local function transformBankMarkers(nodes)
  expandTruncateList(markers['bank'],#nodes,addBankMarker)
  for i, node in ipairs(nodes) do
    local rot = node.markerInfo.rot
    -- transform quat into the format that torque uses
    local quat = rot:toTorqueQuat()

    markers['bank'][i].scale =  vec3(0.1, 5, 2.5)
    markers['bank'][i]:setPosition(node.markerInfo.position)
    markers['bank'][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  end
end

local function transformHeightMarkers(nodes)
  expandTruncateList(markers['height'],#nodes,addHeightMarker)
  for i, node in ipairs(nodes) do
    markers['height'][i]:setPosition((node.markerInfo.position + vec3(0,0,-1)))
    markers['height'][i]:setScale(vec3(1,1, node.markerInfo.position.z -1))
  end
end

local function transformWidthMarkers(nodes)
  expandTruncateList(markers['width'],#nodes*2,addWidthMarker)
  for i, node in ipairs(nodes) do
    local right = node.markerInfo.rot:__mul(vec3( node.width.value/2, 0, 0))
    local left =  node.markerInfo.rot:__mul(vec3(-node.width.value/2, 0, 0))

    markers['width'][i*2-1]:setPosition((node.markerInfo.position + right ))
    markers['width'][i*2-1].scale = vec3(2,2,2)

    markers['width'][i*2]:setPosition((node.markerInfo.position + left))
    markers['width'][i*2].scale = vec3(2,2,2)
  end
end

local function transformCenterMeshMarkers(nodes)
  expandTruncateList(markers['centerMesh'],#nodes,addCenterMeshMarker)
  for i, node in ipairs(nodes) do
    local rot = node.markerInfo.rot
    -- transform quat into the format that torque uses
    local quat = rot:toTorqueQuat()
    local down = node.markerInfo.rot:__mul(vec3( 0, 0, -1))
    markers['centerMesh'][i].scale =  vec3(2,0.1,2)
    markers['centerMesh'][i]:setPosition((node.markerInfo.position + down))
    markers['centerMesh'][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  end
end

local function transformLeftMeshMarkers(nodes)
  expandTruncateList(markers['leftMesh'],#nodes,addLeftMeshMarker)
  for i, node in ipairs(nodes) do
    local rot = node.markerInfo.rot
    local quat = rot:toTorqueQuat()
    local downLeft = node.markerInfo.rot:__mul(vec3( -node.markerInfo.width/2-1, 0, -1))
    markers['leftMesh'][i].scale =  vec3(2,0.1,2)
    markers['leftMesh'][i]:setPosition((node.markerInfo.position + downLeft))
    markers['leftMesh'][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  end
end

local function transformRightMeshMarkers(nodes)
  expandTruncateList(markers['rightMesh'],#nodes,addRightMeshMarker)
  for i, node in ipairs(nodes) do
    local rot = node.markerInfo.rot
    local quat = rot:toTorqueQuat()
    local downRight = node.markerInfo.rot:__mul(vec3( node.markerInfo.width/2+1, 0, -1))
    markers['rightMesh'][i].scale =  vec3(2,0.1,2)
    markers['rightMesh'][i]:setPosition((node.markerInfo.position + downRight))
    markers['rightMesh'][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  end
end

local function transformCheckpointMarkers(nodes)
  expandTruncateList(markers['checkpoint'],#nodes,addCheckpointMarker)
  for i, node in ipairs(nodes) do
    local rot = node.markerInfo.rot
    -- transform quat into the format that torque uses
    local quat = rot:toTorqueQuat()
    local off = rot:__mul(vec3(node.checkpointPosition.x, node.checkpointPosition.y, node.checkpointPosition.z))
    markers['checkpoint'][i].scale =  vec3(node.checkpointSize,node.checkpointSize, node.checkpointSize)
    markers['checkpoint'][i]:setPosition((node.markerInfo.position + off))
    markers['checkpoint'][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  end
end

local function transformLeftWallMarkers(nodes)
  expandTruncateList(markers['leftWall'],#nodes,addLeftWallMarker)
  for i, node in ipairs(nodes) do
    local rot = node.markerInfo.rot
    local quat = rot:toTorqueQuat()
    local downLeft = node.markerInfo.rot:__mul(vec3( -node.markerInfo.width/2-1.5, 0, 0))
    markers['leftWall'][i].scale =  vec3(1,0.1,3)
    markers['leftWall'][i]:setPosition((node.markerInfo.position + downLeft))
    markers['leftWall'][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  end
end

local function transformRightWallMarkers(nodes)
  expandTruncateList(markers['rightWall'],#nodes,addRightWallMarker)
  for i, node in ipairs(nodes) do
    local rot = node.markerInfo.rot
    local quat = rot:toTorqueQuat()
    local downRight = node.markerInfo.rot:__mul(vec3( node.markerInfo.width/2+1.5, 0, 0))
    markers['rightWall'][i].scale =  vec3(1,0.1,3)
    markers['rightWall'][i]:setPosition((node.markerInfo.position + downRight))
    markers['rightWall'][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  end
end

local function transformCeilingMeshMarkers(nodes)
  expandTruncateList(markers['ceilingMesh'],#nodes,addCeilingMeshMarker)
  for i, node in ipairs(nodes) do
    local rot = node.markerInfo.rot
    local quat = rot:toTorqueQuat()
    local upCenter = node.markerInfo.rot:__mul(vec3( 0, 0, node.ceilingMesh.value))
    markers['ceilingMesh'][i].scale =  vec3(1,0.1,3)
    markers['ceilingMesh'][i]:setPosition((node.markerInfo.position + upCenter))
    markers['ceilingMesh'][i]:setField('rotation', 0, quat.x .. ' ' ..quat.y..' '..quat.z..' '..quat.w)
  end
end

-----------------------------
-- Interpolation functions --
-----------------------------

local function step(t)
  return 0,0
end

local function linear(t)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return 1,t
  else
    return t*1 , 1
  end
end

local function pow2(t)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return 1,2*t
  else
    return t*t*1 , 2*t*1
  end
end

local function pow3(t)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return 1,3*t
  else
    return t*t*t*1 , 3*t*t*1
  end
end

local function pow4(t)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return 1,4*t
  else
    return t*t*t*t*1 , 4*t*t*t*1
  end
end

-- smooth slope interpolation, goes from 0/0 to 1/delta, having horizontal slope at 0 and 1
local function smoothSlope(t)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return 1,0
  else
    return (3-2*t)*1*t*t , (6-6*t)*1*t
  end
end

-- smoother slope interpolation, goes from 0/0 to 1/delta, having horizontal slope at 0 and 1
local function smootherSlope(t)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return 1,0
  else
    return 1*t*t*t*(t*(t*6-15)+10) , 1*30*(t-1)*(t-1)*t*t
  end
end
M.step = step
M.linear = linear
M.pow4 = pow4
M.pow3 = pow3
M.pow2 = pow2
M.smoothSlope = smoothSlope
M.smootherSlope = smootherSlope

local function interpolateBank(t,a,b,point, length)
  local interpolated = b.inverted and 1-M[b.interpolation](1-t) or M[b.interpolation](t)
  point.bank = a.value * (1-interpolated) + b.value * interpolated
end

local function interpolateWidth(t,a,b,point, length)
  local interpolated = b.inverted and 1-M[b.interpolation](1-t) or M[b.interpolation](t)

  point.width = a.value * (1-interpolated) + b.value * interpolated + 0.005
  point.width = point.width - point.width % 0.01
end

local function interpolateHeight(t,a,b,point, length)
  local offset, slope
  local delta = b.value-a.value

  if b.inverted then
    offset, slope = M[b.interpolation](1-t)
    offset = 1 - offset
  else
   offset, slope = M[b.interpolation](t)
  end
  offset = offset * delta + a.value
  point.zOffset = offset
  if t == 0 and a.customSlope then
    point.pitch = a.customSlope / 180 * math.pi
  elseif t == 1 and b.customSlope then
    point.pitch = b.customSlope / 180 * math.pi
  else
    point.pitch = -(math.atan2(length,slope*delta)- math.pi/2)
  end
end

local function interpolateLeftWall(t,a,b,point, length)

  if not a.active then return end
  local interpolated = b.inverted and 1-M[b.interpolation](1-t) or M[b.interpolation](t)
  point.leftWallHeight = a.value * (1-interpolated) + b.value * interpolated
end

local function interpolateRightWall(t,a,b,point, length)
  if not a.active then return end
  local interpolated = b.inverted and 1-M[b.interpolation](1-t) or M[b.interpolation](t)
  point.rightWallHeight = a.value * (1-interpolated) + b.value * interpolated
end

local function interpolateCeilingMesh(t,a,b,point, length)
  if not a.active then return end
  local interpolated = b.inverted and 1-M[b.interpolation](1-t) or M[b.interpolation](t)
  point.ceilingMeshHeight = a.value * (1-interpolated) + b.value * interpolated
end


local function changeMeshInfo(segment, type, field, value)
  if segment.meshInfo[type][field] ~= value then
    segment.meshInfo[type][field] = value
    segment.refreshMesh = true
  end
end



local function markerInfoWallSet(cur, nex, nameOfField, previousValue)
  local prevActive = (previousValue and previousValue.active) or false
  changeMeshInfo(cur, nameOfField, 'active', prevActive)
  if not nex then
    changeMeshInfo(cur, nameOfField, 'endCap', true)
  else
    if cur[nameOfField] ~= nil then
      if cur[nameOfField].active ~= prevActive then
        if prevActive then
          changeMeshInfo(cur, nameOfField, 'endCap', true)
          changeMeshInfo(nex, nameOfField, 'startCap', false)
        else
          changeMeshInfo(nex, nameOfField, 'startCap', true)
          changeMeshInfo(cur, nameOfField, 'endCap', false)
        end
      end
    else
      changeMeshInfo(cur, nameOfField, 'endCap', false)
      changeMeshInfo(nex, nameOfField, 'startCap', false)
    end
  end

end


local function markerInfoSet(cur, nex, nameOfField, previousValue)
  changeMeshInfo(cur, nameOfField, 'value', previousValue.value)
  if not nex then
    changeMeshInfo(cur, nameOfField, 'endCap', true)
  else
    if cur[nameOfField] ~= nil then
      changeMeshInfo(nex, nameOfField, 'value', cur[nameOfField].value)
      if cur[nameOfField].value ~= previousValue.value then
        changeMeshInfo(cur, nameOfField, 'endCap', true)
        changeMeshInfo(nex, nameOfField, 'startCap', true)
      else
        changeMeshInfo(nex, nameOfField, 'endCap', true)
        changeMeshInfo(cur, nameOfField, 'startCap', true)
      end
    else
      changeMeshInfo(cur, nameOfField, 'endCap', false)
      changeMeshInfo(nex, nameOfField, 'startCap', false)
    end
  end

end


local function interpolateCheckpoint(segment)
  if segment.checkpoint == nil then
    segment.hasCheckPoint = nil
    segment.checkpointSize = nil
    segment.checkpointPosition = nil
  else
    segment.hasCheckPoint = true
    segment.checkpointSize = segment.checkpoint.size
    segment.checkpointPosition = segment.checkpoint.position
  end
end

local function wallCaps(nameOfField, segments, closed)
  -- additional cap stuff for walls and ceiling
  if segments[1][nameOfField] == nil then return end

  local firstSegment = segments[1]
  local lastSegment = nil
  for i = #segments-1, 1, -1 do
    if lastSegment == nil and segments[i][nameOfField] then
      lastSegment = segments[i]
    end
  end
  if not lastSegment or lastSegment.index == 1 then return end

  local same = lastSegment[nameOfField].active and firstSegment[nameOfField].active
  if same then return end
  if lastSegment[nameOfField].active then
    changeMeshInfo(lastSegment, nameOfField, 'endCap', true)
  else
    changeMeshInfo(segments[2], nameOfField, 'startCap', true)
  end

end

for _,name in ipairs(names) do markers[name] = {} markerChanges[name] = {} end
local types = {
  bank = {
    interpolation = 'points',
    interpolateField = interpolateBank,
    transformMarkers = transformBankMarkers,
    caps = nil
  },
  height = {
    interpolation = 'points',
    interpolateField = interpolateHeight,
    transformMarkers = transformHeightMarkers,
    caps = nil
  },
  width = {
    interpolation = 'points',
    interpolateField = interpolateWidth,
    transformMarkers = transformWidthMarkers,
    caps = nil
  },
  leftWall = {
    interpolation = 'both',
    interpolateField = interpolateLeftWall,
    segmentFunction = markerInfoWallSet,
    transformMarkers = transformLeftWallMarkers,
    caps = wallCaps
  },
  rightWall = {
    interpolation = 'both',
    interpolateField = interpolateRightWall,
    segmentFunction = markerInfoWallSet,
    transformMarkers = transformRightWallMarkers,
    caps = wallCaps
  },
  ceilingMesh = {
    interpolation = 'both',
    interpolateField = interpolateCeilingMesh,
    segmentFunction = markerInfoWallSet,
    transformMarkers = transformCeilingMeshMarkers,
    caps = wallCaps
  },

  centerMesh = {
    interpolation = 'segments',
    segmentFunction = markerInfoSet,
    transformMarkers = transformCenterMeshMarkers
  },
  leftMesh = {
    interpolation = 'segments',
    segmentFunction = markerInfoSet,
    transformMarkers = transformLeftMeshMarkers
  },
  rightMesh = {
    interpolation = 'segments',
    segmentFunction = markerInfoSet,
    transformMarkers = transformRightMeshMarkers
  },
  checkpoint = {
    interpolation = 'single',
    segmentSingleFunction = interpolateCheckpoint,
    transformMarkers = transformCheckpointMarkers,
    caps = nil
  }
}




local function interpolateOverPoints(nameOfField,track)
  local startIndex, endIndex
  local startValue, endValue
  local startLength, endLength
  local doChange
  -- go through all the pieces and set start/end fields.
  -- calculate actual interpolation when a new field occurs
  local changed = {}
  for i = 1, #track do
    if track[i][nameOfField] ~= nil or i == #track then
      if startValue == nil then
        startValue = track[i][nameOfField]
        startLength = track[i].endLength
        startIndex = i
      else
        if not track[i][nameOfField] then
          endValue = startValue
          endLength = track[i].endLength
          endIndex = i
        else
          endValue = track[i][nameOfField]
          endLength = track[i].endLength
          endIndex = i
        end

        -- only interpolate if one of the segments between start and end is actually contained in the markerChanges table
        if #markerChanges[nameOfField] > 0 then
          doChange = false
          for changeIndex = endIndex, startIndex, -1 do
            if tableContains(markerChanges[nameOfField], changeIndex) then
              doChange = true
            end
          end
          if doChange then
            --dump("Found Values for " .. nameOfField .. ": " .. startValue .. " to " .. endValue .. " ("..startIndex .. " - " .. endIndex..")" .. "["..startLength .. " - " .. endLength .."]")
            if startIndex == 1 then startIndex = 0 end
            for changeIndex = endIndex, startIndex+1, -1 do
              M.interpolatePointsOfSegment(track[changeIndex],startValue,endValue,startLength,endLength, nameOfField)
              changed[changeIndex] = true
            end
          end
        end
        if i < #track then
          startValue = track[i][nameOfField]
          startLength = track[i].endLength
          startIndex = i
        end
      end
    end
    -- fresh pieces, which have been added to the end of the track, should be also updated and receive the values of the last value that has been found
    if not changed[i] and track[i].fresh and startValue  then
      --dump("track " .. i .. " is fresh..." .. nameOfField .. " / " .. " / " .. startLength)
      --dump(startValue)
      M.interpolatePointsOfSegment(track[i],startValue,nil,startLength,nil, nameOfField)
    end
  end
end



local function interpolateOverSegments(nameOfField,track)
  local previousValue, currentValue, check
  local previousIndex = 1
  local currentIndex = 1
  -- go through all the pieces and set start/end fields.
  -- calculate actual interpolation when a new field occurs
  local found = false

  if track[1][nameOfField] ~= nil then
    previousValue = track[1][nameOfField]
  end
  for i = 1, #track do

    if not found and track[i][nameOfField] ~= nil then found = true end
    if found then
      types[nameOfField].segmentFunction(track[i],track[i+1],nameOfField, previousValue)
      if i ~= track and track[i][nameOfField] ~= nil then
        previousValue = track[i][nameOfField]
      end
    end
  end
  --types[nameOfField].segmentFunction(track[#track],nil,nameOfField, previousValue)
  --if currentIndex ~= #track then
  --  types[nameOfField].segmentFunction(track,currentIndex, #track,nameOfField,currentValue, nil)
  --end
end

local function interpolateSingle(nameOfField, track)
  for _,index in ipairs(markerChanges[nameOfField]) do
    if track[index] ~= nil then
      types[nameOfField].segmentSingleFunction(track[index])
    end
  end
end




-- interpolates the segments with given name of field to interpolate and an interpolation function.
local function interpolate(nameOfField, track)
  if types[nameOfField].interpolation == 'points' or types[nameOfField].interpolation == 'both' then
    M.interpolateOverPoints(nameOfField,track)
  end
  if types[nameOfField].interpolation == 'segments' or types[nameOfField].interpolation == 'both'then
    M.interpolateOverSegments(nameOfField,track)
  end
  if types[nameOfField].interpolation == 'single' then
    M.interpolateSingle(nameOfField,track)
  end
  -- clear markerChanges for this field
  markerChanges[nameOfField] = {}
end


local function compareSimpleCaps(first,second,nameOfField)
  -- both have a mesh. set caps if they are different
  if not first.noPoints and not second.noPoints then
    local firstCap = first.meshInfo[nameOfField].endCap
    local secondCap = second.meshInfo[nameOfField].startCap
    local setCaps = first[nameOfField] ~= second[nameOfField]

    if firstCap ~= setCaps then
      first.meshInfo[nameOfField].endCap = setCaps
      first.refreshMesh = true
    end

    if secondCap ~= setCaps then
      second.meshInfo[nameOfField].startCap = setCaps
      second.refreshMesh = true
    end

  elseif first.noPoints and second.noPoints then
    return
  elseif first.noPoints then
    if not second.startCap then
      second.meshInfo[nameOfField].startCap = true
      second.refreshMesh = true
    end
  elseif second.noPoints then
    if not first.endCap then
      first.meshInfo[nameOfField].endCap = true
      first.refreshMesh = true
    end
  end
end

local function simpleCaps(nameOfField, segments, closed)
  for i = 2,#segments-1 do
    compareSimpleCaps(segments[i],segments[i+1],nameOfField)
  end
  if closed then
    --dump("closed")
    compareSimpleCaps(segments[#segments],segments[2],nameOfField)
  end
end

local function compareWallCeilingCaps(first,second,nameOfField)
  -- both have a mesh. set caps if they are different
  if not first.noPoints and not second.noPoints then
    local firstCap = first.meshInfo[nameOfField].endCap
    local secondCap = second.meshInfo[nameOfField].startCap
    local setCaps = first.meshInfo[nameOfField].active ~= second.meshInfo[nameOfField].active

    if firstCap ~= setCaps then
      first.meshInfo[nameOfField].endCap = setCaps
      first.refreshMesh = true
    end

    if secondCap ~= setCaps then
      second.meshInfo[nameOfField].startCap = setCaps
      second.refreshMesh = true
    end

  elseif first.noPoints and second.noPoints then
    return
  elseif first.noPoints then
    if not second.startCap then
      second.meshInfo[nameOfField].startCap = true
      second.refreshMesh = true
    end
  elseif second.noPoints then
    if not first.endCap then
      first.meshInfo[nameOfField].endCap = true
      first.refreshMesh = true
    end
  end
end

local function wallCeilingCaps(nameOfField,segments,closed)
  for i = 2,#segments-1 do
    compareWallCeilingCaps(segments[i],segments[i+1],nameOfField)
  end
  if closed then
  --  dump("Closed wall")
   -- dump(segments[#segments].meshInfo)
   -- dump(segments[2].meshInfo)
    compareWallCeilingCaps(segments[#segments],segments[2],nameOfField)
  end
end

local function caps(segments, closed)
  simpleCaps('centerMesh',segments,closed)
  simpleCaps('leftMesh',segments,closed)
  simpleCaps('rightMesh',segments,closed)
  wallCeilingCaps('leftWall',segments,closed)
  wallCeilingCaps('rightWall',segments,closed)
  wallCeilingCaps('ceilingMesh',segments,closed)
end

-- interpolation function for one segment
local function interpolatePointsOfSegment(segment, startValue, endValue, startLength, endLength, nameOfField)
  -- interpolate points if points are available
  if segment.points ~= nil then
    -- if the same value on start and finish, we dont need to calculate the fraction of the lengths and just use 1
    if startValue == endValue or (not endLength and not endValue) then
      for _,p in ipairs(segment.points) do
        M.interpolateField(nameOfField,0,startValue,startValue,p,1)
      end
      M.interpolateField(nameOfField,0, startValue, startValue, segment.markerInfo,1)
    else
      -- otherwise, calculate fraction of distances and then interpolate
      for _,p in ipairs(segment.points) do
        local t = (p.length - startLength) / (endLength - startLength)
        M.interpolateField(nameOfField,t, startValue, endValue, p, endLength - startLength)
      end
      M.interpolateField(nameOfField,
        (segment.endLength - startLength) / (endLength - startLength)
        , startValue, endValue, segment.markerInfo, endLength - startLength)
    end
    segment.refreshMesh = true
  else
    -- if there are no points, we still need to calculate the markerInfo values
    if startValue == endValue or endLength == startLength then
      M.interpolateField(nameOfField,0, endValue, endValue, segment.markerInfo,1)
    elseif (not endLength and not endValue) then
      M.interpolateField(nameOfField,0, startValue, startValue, segment.markerInfo,1)
    else
      M.interpolateField(nameOfField,
        (segment.endLength - startLength) / (endLength - startLength)
        , startValue, endValue, segment.markerInfo, endLength - startLength)
    end
    if not types[nameOfField].interpolatePoints then
      segment.refreshMesh = true
    end
  end
end





local function interpolateField(name,t,a,b,point,length)
  types[name].interpolateField(t,a,b,point,length)
end

local function transformMarkers(name,allNodes)
  if types[name].transformMarkers == nil then return end
  local nodes = nodeGetter(name, allNodes)
  types[name].transformMarkers(nodes)
end

local function hideMarkers(name)
  for i = 1,#markers[name] do
    if markers[name][i] ~= nil then
      markers[name][i].scale = vec3(0,0,0)
    end
  end
end

local function clearMarkers(name)
  for i = 1,#markers[name] do
    if markers[name][i] ~= nil then
      markers[name][i]:delete()
      markers[name][i] = nil
    end
  end
end

local function addMarkerChange(name, index)
  if markerChanges[name] == nil then
    markerChanges[name] = {}
  end
  markerChanges[name][#markerChanges[name]+1] = index
  --dump('added makrer change for ' .. name .. ' on ' .. index)
end

local function unloadAll()
  for _,name in ipairs(names) do markers[name] = {} end
end

M.interpolate = interpolate
M.interpolatePointsOfSegment = interpolatePointsOfSegment

M.interpolateOverSegments = interpolateOverSegments
M.interpolateOverPoints = interpolateOverPoints
M.interpolateSingle = interpolateSingle

M.interpolateField = interpolateField
M.transformMarkers = transformMarkers
M.hideMarkers = hideMarkers
M.clearMarkers = clearMarkers
M.addMarkerChange = addMarkerChange
M.unloadAll = unloadAll
M.caps = caps
M.names = names
return M