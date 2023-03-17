-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local LUTDetail = 10
local uvHeight= 0.2

local shapes = {
  regular = {
    crossPoints = {
     { point = vec3( 0,     0, -1  ), uv = 0.25 },
     { point = vec3(-1.1,   0, -0.4), uv = 0.52 },
     { point = vec3(-1.1,   0, 0.5 ), uv = 0.71 },
     { point = vec3(-0.95,  0, 0.6 ), uv = 0.75 },
     { point = vec3(-0.725, 0, 0.5 ), uv = 0.80 },
     { point = vec3(-0.5,   0, 0.2 ), uv = 0.88 },
     { point = vec3( 0,     0, 0   ), uv = 1    }
    },
    cap = {
      {1,6,7},
      {1,2,6},
      {2,3,6},
      {3,4,5},
      {3,5,6}
    },
    faces = {{1,2,3,4,5,6,7}},
    material = materialNames
  },

  bevel = {
    crossPoints = {
     { point = vec3(math.cos(-1.0*math.pi/2 )*0.5, 0, -0.5+math.sin(-1.0*math.pi/2 )*0.5), uv = 0.5 },
     { point = vec3(math.cos(-1.4*math.pi/2 )*0.5, 0, -0.5+math.sin(-1.4*math.pi/2 )*0.5), uv = 0.6 },
     { point = vec3(math.cos(-1.8*math.pi/2 )*0.5, 0, -0.5+math.sin(-1.8*math.pi/2 )*0.5), uv = 0.7 },
     { point = vec3(math.cos(-2.2*math.pi/2 )*0.5, 0, -0.5+math.sin(-2.2*math.pi/2 )*0.5), uv = 0.8 },
     { point = vec3(math.cos(-2.6*math.pi/2 )*0.5, 0, -0.5+math.sin(-2.6*math.pi/2 )*0.5), uv = 0.9 },
     { point = vec3(math.cos(-3.0*math.pi/2 )*0.5, 0, -0.5+math.sin(-3.0*math.pi/2 )*0.5), uv = 1.0 },
      },
    cap = {{1,2,3},{1,3,4},{1,4,6},{4,5,6}},
    faces = {{1,2,3,4,5,6}},
    material = materialNames
  },

  smoothedRect = {
    crossPoints = {
     { point = vec3(0, 0, -1), uv = 00 },
     { point = vec3(-0.02,0, -0.98), uv = 0.02 },
     { point = vec3(-0.02,0, -0.96), uv = 0.04 },
     { point = vec3(-0.02,0, -0.04), uv = 0.96 },
     { point = vec3(-0.02,0,-0.02), uv = 0.98},
     { point = vec3(0, 0, 0), uv = 1.0 },
      },
    cap = {{1,2,6},{2,5,6}},
    faces = {{1,2,3,4,5,6}},
    material = materialNames
  },

  racetrack = {
    crossPoints = {
     { point = vec3( 0,    0, -1  ), uv = 0.001},
     { point = vec3(-15,   0, -1  ), uv = 0.002},
     { point = vec3(-15,   0, 1.3 ), uv = 0.005},
     { point = vec3(-14,   0, 1.3 ), uv = 0.01 },
     { point = vec3(-14,   0, 0.0 ), uv = 0.13 },
     { point = vec3(-1.54, 0, 0.0 ), uv = 0.87 },
     { point = vec3(-1.5,  0, 0.07), uv = 0.92 },
     { point = vec3(-0.04, 0, 0.04), uv = 0.98 },
     { point = vec3( 0,    0, 0   ), uv = 1    }
    },
    cap = {
      {1, 8, 9},
      {1, 7, 8},
      {1, 6, 7},
      {1, 5, 6},
      {1, 2, 5},
      {5, 2, 3},
      {5, 3, 4}
    },
    faces = {{1,2,3,4,5,6,7,8,9}},
    material = materialNames
  },

  smallDiagonal = {
    crossPoints = {
     { point = vec3(0,0,-1), uv = 0.5 },
     { point = vec3(-0.5,0,-1), uv = 0.6, sharp = true},
     { point = vec3(-1,0,-0.66), uv = 0.7, sharp = true },
     { point = vec3(-1,0,0.33), uv = 0.8, sharp = true },
     { point = vec3(-0.5,0,0.33), uv = 0.9, sharp = true },
     { point = vec3(0,0,0), uv = 1 },
      },
    cap = {{1,2,5},{1,5,6},{2,3,4},{2,4,5}},
    faces = {{1,2,3,4,5,6}},
    material = materialNames
  },

  bigDiagonal = {
    crossPoints = {
     { point = vec3(0 ,0,-1), uv = 0 },
     { point = vec3(-1,0,-1), uv = 0.2, sharp = true },
     { point = vec3(-2,0,-0.33), uv = 0.4, sharp = true },
     { point = vec3(-2,0,0.66), uv = 0.6, sharp = true },
     { point = vec3(-1,0,0.66), uv = 0.8, sharp = true },
     { point = vec3(0,0,0), uv = 1 },
      },
    cap = {{1,2,5},{1,5,6},{2,3,4},{2,4,5}},
    faces = {{1,2,3,4,5,6}},
    material = materialNames
  },

  wideBevel = {
    crossPoints = {
     { point = vec3(0   , 0, -1), uv = 0 },
     { point = vec3(-3  , 0, -1), uv = 0.4 },
     { point = vec3(-3  , 0, 0), uv = 1-6/12 , sharp = true},
     { point = vec3(-2.5, 0, 0.5-0.66*0.66*0.5), uv = 1-5/12 },
     { point = vec3(-2  , 0, 0.5-0.33*0.33*0.5), uv = 1-4/12 },
     { point = vec3(-1.5, 0, 0.5), uv = 1-3/12 },
     { point = vec3(-1  , 0, 0.5-0.33*0.33*0.5), uv = 1-2/12 },
     { point = vec3(-0.5, 0, 0.5-0.66*0.66*0.5), uv = 1-1/12 },
     { point = vec3(0   , 0, 0), uv = 1 },
      },
    cap = {{1,2,3},{1,3,9},{3,6,9},{3,4,5},{3,5,6},{6,7,8},{6,8,9}},
    faces = {{1,2,3,4,5,6,7,8,9}},
    material = materialNames
  },

  highBevel = {
    crossPoints = {
     { point = vec3(0   , 0, -1), uv = 0 },
     { point = vec3(-1.5  , 0, -1), uv = 0.4 },
     { point = vec3(-1.5  , 0, 0), uv = 1-6/12 , sharp = true},
     { point = vec3(-1.25, 0, 1.5-0.66*0.66*1.5), uv = 1-5/12 },
     { point = vec3(-1  , 0, 1.5-0.33*0.33*1.5), uv = 1-4/12 },
     { point = vec3(-0.75, 0, 1.5), uv = 1-3/12 },
     { point = vec3(-0.5  , 0, 1.5-0.33*0.33*1.5), uv = 1-2/12 },
     { point = vec3(-0.25, 0, 1.5-0.66*0.66*1.5), uv = 1-1/12 },
     { point = vec3(0   , 0, 0), uv = 1 },
      },
    cap = {{1,2,3},{1,3,9},{3,6,9},{3,4,5},{3,5,6},{6,7,8},{6,8,9}},
    faces = {{1,2,3,4,5,6,7,8,9}},
    material = materialNames
  },

  rail = {
    crossPoints = {
     { point = vec3(math.cos(-0.00 * math.pi )*-0.20, 0, 0.5+math.sin(-0.00 * math.pi )*-0.20), uv = 0.8 },
     { point = vec3(math.cos(-0.25 * math.pi )*-0.20, 0, 0.5+math.sin(-0.25 * math.pi )*-0.20), uv = 0.85 },
     { point = vec3(math.cos(-0.50 * math.pi )*-0.20, 0, 0.5+math.sin(-0.50 * math.pi )*-0.20), uv = 0.9 },
     { point = vec3(math.cos(-0.75 * math.pi )*-0.20, 0, 0.5+math.sin(-0.75 * math.pi )*-0.20), uv = 0.95 },
     { point = vec3(math.cos(-1.00 * math.pi )*-0.20, 0, 0.5+math.sin(-1.00 * math.pi )*-0.20), uv = 1.0 },
     { point = vec3(math.cos(-1.25 * math.pi )*-0.20, 0, 0.5+math.sin(-1.25 * math.pi )*-0.20), uv = 1.05 },
     { point = vec3(math.cos(-1.50 * math.pi )*-0.20, 0, 0.5+math.sin(-1.50 * math.pi )*-0.20), uv = 1.1 },
     { point = vec3(math.cos(-1.75 * math.pi )*-0.20, 0, 0.5+math.sin(-1.75 * math.pi )*-0.20), uv = 1.15 },
     { point = vec3(math.cos(-0.00 * math.pi )*-0.20, 0, 0.5+math.sin(-0.00 * math.pi )*-0.20), uv = 1.2 },

     { point = vec3( 0, 0,-1), uv = 0.7 },
     { point = vec3( 0, 0, 0), uv = 1 }
    },
    cap = {{1,3,5},{1,5,7},{1,2,3},{3,4,5},{5,6,7},{7,8,1}},
    faces = {{1,2,3,4,5,6,7,8,9},{10,11}},
    material = materialNames
  },


  none = {
    crossPoints = {
      { point = vec3( 0, 0,-1), uv = 0 },
      { point = vec3( 0, 0, 0), uv = 1 }
    },
    faces={{1,2}},
    cap = {}
  }
}

local function computeFaces(shape)
  local faces = {}
  local vertexCount = #shape.crossPoints
  local sharpCount = 0

  for _, faceList in ipairs(shape.faces) do
    for vIndex = 2, #faceList -1 do
      if shape.crossPoints[vIndex].sharp then
        sharpCount = sharpCount +1
      end
    end
  end

  local vOff = 0
  for _, faceList in ipairs(shape.faces) do
    local vOff = 0
    for vIndex = 1, #faceList -1 do
        local this = faceList[vIndex]
        local right = faceList[vIndex+1]

        local up = this + vertexCount
        local upRight = right + vertexCount
        if shape.crossPoints[this].sharp then
          vOff = vOff + 1
        end

        faces[#faces+1] = {v = this, n = this + vOff ,u=this}
        faces[#faces+1] = {v = up, n = up + vOff + sharpCount ,u=up}
        faces[#faces+1] = {v = right, n = right + vOff ,u=right}

        faces[#faces+1] = {v = up, n = up + vOff + sharpCount ,u=up}
        faces[#faces+1] = {v = upRight, n =upRight + vOff + sharpCount ,u=upRight}
        faces[#faces+1] = {v = right, n =right + vOff , u=right}
    end
  end

  local startCap = {
    leftMesh = {}, rightMesh = {}
  }
  local endCap = {
    leftMesh = {}, rightMesh = {}
  }
  for i,face in ipairs(shape.cap) do
    startCap.leftMesh[(i-1)*3 + 1] = { v = face[1]-1, n = 0, u = 0}
    startCap.leftMesh[(i-1)*3 + 2] = { v = face[2]-1, n = 0, u = 0}
    startCap.leftMesh[(i-1)*3 + 3] = { v = face[3]-1, n = 0, u = 0}

    endCap.leftMesh[(i-1)*3 + 1] = { v = -(vertexCount+2) + face[1], n = 1, u = 0}
    endCap.leftMesh[(i-1)*3 + 2] = { v = -(vertexCount+2) + face[3], n = 1, u = 0}
    endCap.leftMesh[(i-1)*3 + 3] = { v = -(vertexCount+2) + face[2], n = 1, u = 0}

    startCap.rightMesh[(i-1)*3 + 1] = { v = face[1]-1, n = 0, u = 0}
    startCap.rightMesh[(i-1)*3 + 2] = { v = face[3]-1, n = 0, u = 0}
    startCap.rightMesh[(i-1)*3 + 3] = { v = face[2]-1, n = 0, u = 0}

    endCap.rightMesh[(i-1)*3 + 1] = { v = -(vertexCount+2) + face[1], n = 1, u = 0}
    endCap.rightMesh[(i-1)*3 + 2] = { v = -(vertexCount+2) + face[2], n = 1, u = 0}
    endCap.rightMesh[(i-1)*3 + 3] = { v = -(vertexCount+2) + face[3], n = 1, u = 0}
  end

  shape.faceInfo = {
      faces = faces,
      faceCount = #faces,
      vertexCount = vertexCount,
      normalCount = sharpCount + vertexCount,
      startCap = startCap,
      endCap = endCap
    }

end

local function computeNormals(shape)
  shape.normals = {}

  for _, faceList in ipairs(shape.faces) do
    -- normal for the first point is always sharp
    local a =  (shape.crossPoints[faceList[2]].point - shape.crossPoints[faceList[1]].point)
    a:normalize()
    shape.normals[#shape.normals+1] = vec3(-a.z,0,a.x)

    for vIndex = 2, #faceList -1 do
      local currentP = shape.crossPoints[faceList[vIndex]].point
      local nextP = shape.crossPoints[faceList[vIndex+1]].point
      local prevP = shape.crossPoints[faceList[vIndex-1]].point

      -- Vector from previous point to current point.
      local a = (currentP - prevP)
      a:normalize()
      -- Vector from current point to next point.
      local b = (nextP - currentP)
      b:normalize()

      if not shape.crossPoints[faceList[vIndex]].sharp then
        -- Actual normal.
        local n = vec3(
          -(a.z) - (b.z),
          0,
          (a.x) + (b.x)
        )
        local len = n:length()
        -- If the normal has no length (a and b parallel), simply use perpendicular vector from a.
        if len <=0.00001 then
          n = vec3(
            -(nextP.z - currentP.z),
            0,
            (nextP.x - currentP.x)
          )
        end
        -- Make sure that the normal is actually pointing outwards.
        if (-(nextP.z - currentP.z)*n.x) + ((nextP.x - currentP.x) * n.z) < 0 then
          n = -n / len
        end
        n:normalize()
        shape.normals[#shape.normals+1] = n
      else
        shape.normals[#shape.normals+1] = vec3(-a.z,0,a.x)
        shape.normals[#shape.normals+1] = vec3(-b.z,0,b.x)
      end
    end
    a =  (shape.crossPoints[faceList[#faceList]].point - shape.crossPoints[faceList[#faceList-1]].point)
    a:normalize()
    shape.normals[#shape.normals+1] = vec3(-a.z,0,a.x)
  end
end


local function compileMeshInfo(segment, shape, side,sideName)
  if shape == nil then return nil end
  local vertexCount = 1
  local normalCount = 1
  local pointsCount = 0

  local vertices = {}
  local uvs =  {}
  local normals = {}
  local faces = {}

  local point = nil
  local pointCount = 0
  local tmpVec3 = vec3()
  local cappedWidth = 0

  for pIndex = 1, #segment.points do
    point = segment.points[pIndex]
    if point.quality[segment.quality] then
      pointsCount = pointsCount +1
      cappedWidth = side * math.floor(point.width * LUTDetail + 0.5) / (LUTDetail*2)

      for i,p in ipairs(shape.crossPoints) do
        tmpVec3:set(
          p.point.x * point.orientation.nx * -side + point.orientation.nx * cappedWidth +
          p.point.y * point.orientation.ny +
          p.point.z * point.orientation.nz +
          point.position + vec3(0,0,point.zOffset)
          )
        vertices[vertexCount] ={x = tmpVec3.x, y = tmpVec3.y, z = tmpVec3.z}
        uvs[vertexCount] = {u = p.uv , v = (point.uvY * uvHeight)}
        vertexCount = vertexCount + 1
      end
      for i,p in ipairs(shape.normals) do
        tmpVec3:set(
          p.x * point.orientation.nx * -side +
          p.y * point.orientation.ny +
          p.z * point.orientation.nz
          )
        normals[normalCount] ={x = tmpVec3.x, y = tmpVec3.y, z = tmpVec3.z}
        normalCount = normalCount +1
      end
    end
  end

  -- create faces from face list
  for cpIndex = 0, pointsCount-2 do
    local vOff = shape.faceInfo.vertexCount * cpIndex
    local nOff = shape.faceInfo.normalCount * cpIndex
    if side == 1 then
      for i, f in ipairs(shape.faceInfo.faces) do
        faces[(shape.faceInfo.faceCount+1-i) + (cpIndex * shape.faceInfo.faceCount)] = {
          v = f.v + vOff-1,
          n = f.n + nOff-1,
          u = f.u + vOff-1
        }
      end
    else
      for i, f in ipairs(shape.faceInfo.faces) do
        faces[i + cpIndex * shape.faceInfo.faceCount] = {
          v = f.v + vOff-1,
          n = f.n + nOff-1,
          u = f.u + vOff-1
        }
      end
    end
  end

  local startCap, endCap = segment.meshInfo[sideName].startCap or segment.meshInfo.forceStartCap, segment.meshInfo[sideName].endCap or segment.meshInfo.forceEndCap

  if extensions.util_trackBuilder_splineTrack.ignoreCapsForMeshes then
    startCap, endCap = false
  end

  if startCap or endCap then
    local startPoint = segment.points[1]
    local endPoint   = segment.points[#segment.points]
    local faceCount = #faces

    normals[normalCount+0] = {x = -startPoint.orientation.ny.x, y =  -startPoint.orientation.ny.y, z = -startPoint.orientation.ny.z}
    normals[normalCount+1] = {x = endPoint.orientation.ny.x, y =  endPoint.orientation.ny.y, z = endPoint.orientation.ny.z}

    if startCap then
      for i, f in ipairs(shape.faceInfo.startCap[sideName]) do
        faces[faceCount+i] = {v = f.v, n = normalCount-1, u = 0 }
      end
      faceCount = faceCount + #shape.faceInfo.startCap[sideName]
    end
    if endCap then
      for i, f in ipairs(shape.faceInfo.endCap[sideName]) do
        faces[faceCount+i] = {v = vertexCount +f.v, n = normalCount, u = 0 }
      end
    end
  end

  segment.submeshIndexes[sideName] = segment.submeshCount
  segment.submeshCount = segment.submeshCount +1
  return {
    verts = vertices,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = segment.materialInfo[sideName] or 'track_editor_A_border',
    tag = "side " .. side
  }
end

local function getMeshes(segment)

  return {
    compileMeshInfo(segment,segment.quality == 4 and shapes['none'] or shapes[segment.leftMesh],-1,'leftMesh'),
    compileMeshInfo(segment,segment.quality == 4 and shapes['none'] or shapes[segment.rightMesh], 1,'rightMesh')
  }
end

for _,shape in pairs(shapes) do computeNormals(shape) computeFaces(shape) end

M.getMeshes = getMeshes
return M