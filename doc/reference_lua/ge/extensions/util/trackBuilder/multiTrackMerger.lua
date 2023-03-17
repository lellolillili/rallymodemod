-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local basicCenters, basicBorders

local function smoothSlope(t)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return 1,0
  else
    return (3-2*t)*1*t*t , (6-6*t)*1*t
  end
end

local function getBezierPoints(p0,p1,p2,p3)
  local bezierPoints = {}

  -- calculate number of points
  local numPoints = 16

  -- cap number of points with 300 and make it to integer
  if numPoints > 300 then
    numPoints = 300
  end
  numPoints = numPoints - numPoints % 1

  for i = 0, numPoints do
    local t = i / numPoints

    -- calculate the weights for each point.
    local t0 = math.pow(1 - t, 3)
    local t1 = 3 * (t - 2 * t * t + t * t * t)
    local t2 = 3 * (t * t - t * t * t)
    local t3 = t * t * t

    -- calculate the weights for the first derivative.
    local d0 = -3 * (1 - t) * (1 - t)
    local d1 = (3 * (1 - t) * (1 - t) - 6 * (1 - t) * t)
    local d2 = (6 * (1 - t) * t - 3 * t * t)
    local d3 = 3 * t * t

    -- calculate the angle of the spline directly from the first derivative
    local hdg = math.atan2(d0 * p0.y + d1 * p1.y + d2 * p2.y + d3 * p3.y, d0 * p0.x + d1 * p1.x + d2 * p2.x + d3 * p3.x)

    -- these fields will only be set for points that directly correspond to an original control point.
    -- quality of 4 means that only every 4th point will be in the mesh etc
    local quality = {}
    for q = 1, 4 do
      quality[q] = i % q == 0
    end

    -- fill in the fields.
    bezierPoints[i + 1] = {
      position = t0 * p0 + t1 * p1 + t2 * p2 + t3 * p3,
      rot = quatFromEuler(math.pi, 0, 0):__mul(quatFromEuler(0, 0, -hdg - math.pi / 2)),
      quality = quality
    }
    debugDrawer:drawSphere(bezierPoints[i+1].position, 0.2, ColorF(1, 1, 0, 1))
  end
  -- measure points
  local totalDist = 0
  bezierPoints[1].dist = 0

  for i= 1, #bezierPoints-1 do
    totalDist = totalDist + bezierPoints[i].position:distance(bezierPoints[i+1].position)
    bezierPoints[i+1].dist = totalDist
  end

  return bezierPoints
end

-- This function calculates the rotated and scaled vertices, normals and uv X values for this subspline.
local function calculatePointCoordinateSystem(point)
  local LUTindex, vertexLUT, nx, ny, nz
  --segment.shape = "square"
  nx = point.finalRot:__mul(vec3(1,0,0))
  ny = point.finalRot:__mul(vec3(0,1,0))
  nz = point.finalRot:__mul(vec3(0,0,1))
  return {
    nx = nx,
    ny = ny,
    nz = nz
  }
end

local function bezierEdge(a, b, center)
  local aDist = a.position:distance(center)*0.75
  local bDist = b.position:distance(center)*0.75
  --aDist = a.position:distance(b.position) * 0.33
  --bDist = aDist
  local edge = {
    p0 = a.position,
    p1 = a.position + a.orientation.ny * aDist,
    p2 = b.position + b.orientation.ny * bDist,
    p3 = b.position
  }
  edge.bezierPoints = getBezierPoints(edge.p0,edge.p1,edge.p2,edge.p3)
  -- interpolate basic markers

  for i = 2, #edge.bezierPoints-1 do
    local pre = edge.bezierPoints[i-1]
    local cur = edge.bezierPoints[i  ]
    local nex = edge.bezierPoints[i+1]
    cur.pitch = -(math.atan2(nex.dist-pre.dist,nex.position.z-pre.position.z)- math.pi/2)
  end
  edge.bezierPoints[1].pitch = a.pitch
  edge.bezierPoints[#edge.bezierPoints].pitch = -b.pitch

  local totalDist = edge.bezierPoints[#edge.bezierPoints].dist
  for i,p in ipairs(edge.bezierPoints) do
    local t = p.dist / totalDist
    local interpolated = smoothSlope(t)
    p.bank = a.bank * (1-interpolated) + -b.bank * interpolated
    p.width = a.width * (1-interpolated) + b.width * interpolated + 0.005
    p.width = p.width - p.width % 0.01

    local offset, slope
    local delta = b.height-a.height
    offset, slope = smoothSlope(t)
    offset = offset * delta + a.height

    p.finalRot = quatFromEuler(
          p.pitch,
          -(p.bank / 180) * math.pi + math.pi,
        0)
        :__mul(p.rot)
    p.quality = {true,true,true,true}
    p.uvY = p.dist
  end

  for _, point in ipairs(edge.bezierPoints) do
    point.orientation = calculatePointCoordinateSystem(point)
    debugDrawer:drawLine(point.position,(point.position + point.orientation.nx), ColorF(1,0,0,1))
    debugDrawer:drawLine(point.position,(point.position + point.orientation.ny), ColorF(0,1,0,1))
    debugDrawer:drawLine(point.position,(point.position + point.orientation.nz), ColorF(0,0,1,1))
  end

  return edge
end

local function makePlateMesh(leftEdge, rightEdge, center, mat, bottom)
  local A,B = {},{}
  local sideLength = math.ceil(#rightEdge/2)
  for i = 1,sideLength do
    A[i] = leftEdge[math.ceil(#rightEdge) - (i -1)]
    B[i] = rightEdge[i]
  end

  local verts = {}
  local normals = {}
  local uvs = {}
  local faces = {}
  local p = vec3()

  local off = -0.2
  if bottom then
    off = -1.15
  end

  for i = 1, sideLength do
    verts[#verts+1] = {
      x = A[i].position.x + A[i].orientation.nz.x * off,
      y = A[i].position.y + A[i].orientation.nz.y * off,
      z = A[i].position.z + A[i].orientation.nz.z * off
    }
    verts[#verts+1] = {
      x = B[i].position.x + B[i].orientation.nz.x * off,
      y = B[i].position.y + B[i].orientation.nz.y * off,
      z = B[i].position.z + B[i].orientation.nz.z * off
    }
    normals[#normals+1] = {x = A[i].orientation.nz.x, y = A[i].orientation.nz.y, z = A[i].orientation.nz.z }
    normals[#normals+1] = {x = B[i].orientation.nz.x, y = B[i].orientation.nz.y, z = B[i].orientation.nz.z }

    uvs[#uvs+1] = {u = A[i].position.x/4, v = A[i].position.y/4 }
    uvs[#uvs+1] = {u = B[i].position.x/4, v = B[i].position.y/4 }
    local t = 2*(i-1)
    if i >= 2 then
      faces[#faces+1] = {v = t,   u = t,   n = t  }
      faces[#faces+1] = {v = t+1, u = t+1, n = t+1}
      faces[#faces+1] = {v = t-1, u = t-1, n = t-1}
    end
    if i >= 3 then
      faces[#faces+1] = {v = t,   u = t,   n = t  }
      faces[#faces+1] = {v = t-1, u = t-1, n = t-1}
      faces[#faces+1] = {v = t-2, u = t-2, n = t-2}
    end
  end

  verts[#verts+1] = {
    x = center.point.x + center.normal.x * off,
    y = center.point.y + center.normal.y * off,
    z = center.point.z + center.normal.z * off
  }
  normals[#normals+1] = {x = center.normal.x, y = center.normal.y, z = center.normal.z }
  uvs[#uvs+1] = {u = center.point.x/4, v = center.point.y/4 }
  local t = #verts-1
  faces[#faces+1] = {v = t,   u = t,   n = t  }
  faces[#faces+1] = {v = t-1, u = t-1, n = t-1}
  faces[#faces+1] = {v = t-2, u = t-2, n = t-2}

  if bottom then
    -- flip faces
    local i,j = 1,#faces
    while i<j do
      faces[i],faces[j] = faces[j],faces[i]
      i = i + 1
      j = j - 1
    end
    for i=1, #normals do
      normals[i] = { x = -normals[i].x, y = -normals[i].y, z = -normals[i].z }
  end

  end

  return {
    verts = verts,
    normals = normals,
    faces = faces,
    uvs = uvs,
    material = mat
  }

end

local function getCenterMesh(edges, mat)
  local bezierCount = #edges[1].bezierPoints
  local center = vec3()
  local normal = vec3()
  for _,e in ipairs(edges) do center = center+e.bezierPoints[math.ceil(bezierCount/2)].position normal = normal+e.bezierPoints[math.ceil(bezierCount/2)].orientation.nz  end
  center = center / (#edges)
  normal = normal:normalized()
  local meshes = {}
  for i = 1, #edges-1 do
    meshes[#meshes+1] = makePlateMesh(edges[i].bezierPoints,edges[i+1].bezierPoints,{point = center, normal = normal}, mat)
    meshes[#meshes+1] = makePlateMesh(edges[i].bezierPoints,edges[i+1].bezierPoints,{point = center, normal = normal}, mat, true)
  end
  meshes[#meshes+1] = makePlateMesh(edges[#edges].bezierPoints,edges[1].bezierPoints,{point = center, normal = normal}, mat)
  meshes[#meshes+1] = makePlateMesh(edges[#edges].bezierPoints,edges[1].bezierPoints,{point = center, normal = normal}, mat, true)
  return meshes
end

local function getBezierPlane(segments, centerMat, borderMat, borderMesh)
  -- get relevant points
  local points = {}
  local center = vec3()
  for i,s in ipairs(segments) do
    local p
    if not s.reverse then
      p = s.segment.points[#s.segment.points]
      points[i] = {
        orientation = p.orientation,
        position = p.position + vec3(0,0,p.zOffset),
        rotation = p.rot,
        width = p.width,
        bank = p.bank,
        height = p.position.z,
        pitch = p.pitch
      }
    else
      p = s.segment.points[1]
      points[i] = {
        orientation = {
          nx = -p.orientation.nx,
          ny = -p.orientation.ny,
          nz =  p.orientation.nz,
        },
        position = p.position + vec3(0,0,p.zOffset),
        rotation = p.rot,
        width = p.width,
        bank = -p.bank,
        height = p.position.z,
        pitch = -p.pitch
      }
    end
    center = center + points[i].position
  end
  center = center * 1/#segments

  for _,p in ipairs(points) do
    debugDrawer:drawSphere(p.position, 1, ColorF(1, 0, 0, 1))
  end
  debugDrawer:drawSphere(center, 1, ColorF(0, 1, 0, 1))
  local edges = {}
  for i = 1, #points-1 do
    edges[i] = bezierEdge(points[i],points[i+1],center)
  end
  edges[#points] = bezierEdge(points[#points],points[1], center)

  local meshes  = {{}}
  for i, edge in ipairs(edges) do
    -- make pseudo segment out of edge
    local pSegment = {
      quality = 1,
      centerMesh = "halfRegular",
      rightMesh = borderMesh,
      points = edge.bezierPoints,
      meshInfo={centerMesh={startCap = false, endCap = false},
        rightMesh={
          startCap = (segments[i].reverse and segments[i].segment.leftMesh or segments[i].segment.rightMesh) ~= borderMesh,
          endCap = (segments[((i)%#segments)+1].reverse and segments[((i)%#segments)+1].segment.rightMesh or segments[((i)%#segments)+1].segment.leftMesh) ~= borderMesh
        }
      },
      submeshCount = 1,
      submeshIndexes = {},
      materialInfo = {centerMesh = centerMat, rightMesh = borderMat}
    }
    meshes[1][#meshes[1]+1] = basicCenters.getMeshes(pSegment)[1]
    meshes[1][#meshes[1]+1] = basicBorders.getMeshes(pSegment)[2]

  end
  if #segments > 2 then
    for i, m in ipairs(getCenterMesh(edges, centerMat)) do
      meshes[1][#meshes[1]+1] = m
    end
  end

  local splineObject = createObject("ProceduralMesh")
  splineObject:setPosition(vec3(0,0,0))
  splineObject.canSave = false
  local name = "procMerger"
  for _, seg in ipairs(segments) do
    name = name.."-"..(seg.reverse and 'r' or '')..seg.index.."x"..seg.sub
  end
  --dump(#meshes[1])
  splineObject:registerObject(name)
  meshes[2] = meshes[1]
  meshes[3] = meshes[1]
  scenetree.MissionGroup:add(splineObject.obj)
  --globObj = splineObject
  splineObject:createMesh(meshes)

  return splineObject
end

local function setMaterials(intersection, centerMat, borderMat)
  for i = 1, #intersection.segments do
    if centerMat then
      intersection.obj:setMaterial(2*(i-1), centerMat) -- centers
      if #intersection.segments > 2 then
        intersection.obj:setMaterial(2*(#intersection.segments)-1 + i, centerMat) -- filling
      end
    end
    if borderMat then
      intersection.obj:setMaterial(2*(i-1)+1, borderMat) -- border
    end
  end
end

local function mergeMultiTrack(segments, centerMat, borderMat, borderMesh)

  local obj = getBezierPlane(segments,centerMat or 'track_editor_A_center', borderMat or 'track_editor_A_border', borderMesh or 'regular')


  return obj
end

local function setReferences(list)
  basicCenters = list.basicCenters
  basicBorders = list.basicBorders
end
M.mergeMultiTrack = mergeMultiTrack
M.setReferences = setReferences
M.setMaterials = setMaterials
return M