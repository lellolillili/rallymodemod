-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'splineTrack'
-- general settings for the position and shape of the mesh.

--local meshesRaw = require('util/trackBuilder/meshes')
local basicCenters = require('util/trackBuilder/basicCenters')
local basicBorders = require('util/trackBuilder/basicBorders')
local borderWall =   require('util/trackBuilder/borderWallMesh')
local ceilingMesh =  require('util/trackBuilder/ceilingMesh')

-- This is the main function which will create the mesh road along the control points.
local function materialize(segment)
  M.calculatePointCoordinateSystem(segment)

  -- Calculate the mesh info for this part and store it. Low quality track has no extra LOD.
  segment.submeshIndexes = {}
  segment.submeshCount = 0
  segment.meshes = {}
-- force disabling of caps

  segment.meshes[1] = M.compileMeshInfo(segment)
  segment.meshes[2] = segment.meshes[1]
  segment.meshes[3] = segment.meshes[1]
  segment.submeshCount = nil
 -- serializeJsonToFile("trackMesh",segment.meshes, true)
  --serializeJsonToFile("trackMeshSmall",segment.meshes, false)

  if not segment.mesh then
    local splineObject = createObject("ProceduralMesh")
    splineObject:setPosition(vec3(0,0,0))
    splineObject.canSave = false
    splineObject:registerObject('procMesh'..segment.subTrackIndex..'-'..segment.index)

    scenetree.MissionGroup:add(splineObject.obj)
    splineObject:createMesh(segment.meshes)
    segment.mesh = splineObject
  else
    segment.mesh:createMesh(segment.meshes)
  end
  segment.meshes = nil

end

local function clearShapes()
  basicCenters.clearShapes()
end



-- This function calculates the rotated and scaled vertices, normals and uv X values for this subspline.
local function calculatePointCoordinateSystem(segment)
  local LUTindex, vertexLUT, nx, ny, nz
  --segment.shape = "square"
  for _,controlPoint in ipairs(segment.points) do
    if controlPoint.quality[segment.quality] then
      nx = M.rotateVectorByQuat(vec3(1,0,0),controlPoint.finalRot)
      ny = M.rotateVectorByQuat(vec3(0,1,0),controlPoint.finalRot)
      nz = M.rotateVectorByQuat(vec3(0,0,1),controlPoint.finalRot)
      controlPoint.orientation = {
        nx = nx,
        ny = ny,
        nz = nz
      }
    end
  end
end



-- This function compiles the vertices, normals etc. so that it can be sent to the engine side and create the actual mesh.
-- Also creates caps on the front and or end of the spline if needed.
local function compileMeshInfo(segment, lod)
  local meshes = {}
  for _,m in pairs(basicBorders.getMeshes(segment))    do meshes[#meshes+1] = m end
  for _,m in pairs(basicCenters.getMeshes(segment))    do meshes[#meshes+1] = m end
  for _,m in pairs(borderWall.getMeshes(segment))      do meshes[#meshes+1] = m end
  for _,m in pairs(ceilingMesh.getMeshes(segment))     do meshes[#meshes+1] = m end

  return meshes

end

-------------------------------
-- helper and mini functions --
-------------------------------

-- Rotates a vector by a given quat.
local function rotateVectorByQuat(v, q)
  return q:__mul(v)
end
local function getReferences()
  return {basicCenters = basicCenters, basicBorders = basicBorders}
end
M.calculatePointCoordinateSystem = calculatePointCoordinateSystem
M.settings = settings
M.materialize = materialize
M.compileMeshInfo = compileMeshInfo
M.rotateVectorByQuat = rotateVectorByQuat
M.clearShapes = clearShapes
M.settings = settings
M.getReferences = getReferences
return M