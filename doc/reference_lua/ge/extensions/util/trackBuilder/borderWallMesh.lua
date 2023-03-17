-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local LUTDetail = 10
local uvHeight= 0.2



local shape = {

  faceInfo = {
    faceCount = 24,
    faces = {
      {v = 1, n = 1, u = 1},
      {v = 2, n = 1, u = 2},
      {v = 6, n = 5, u = 6},

      {v = 1, n = 1, u = 1},
      {v = 6, n = 5, u = 6},
      {v = 5, n = 5, u = 5},

      {v = 2, n = 2, u = 3},
      {v = 3, n = 2, u = 4},
      {v = 7, n = 6, u = 8},

      {v = 2, n = 2, u = 3},
      {v = 7, n = 6, u = 8},
      {v = 6, n = 6, u = 7},

      {v = 3, n = 3, u = 2},
      {v = 4, n = 3, u = 1},
      {v = 8, n = 7, u = 5},

      {v = 3, n = 3, u = 2},
      {v = 8, n = 7, u = 5},
      {v = 7, n = 7, u = 6},

      {v = 4, n = 4, u = 4},
      {v = 1, n = 4, u = 3},
      {v = 5, n = 8, u = 7},

      {v = 4, n = 4, u = 4},
      {v = 5, n = 8, u = 7},
      {v = 8, n = 8, u = 8}
    }
  },
  leftWall = {
    front = {
      {v = 0, n = -1, u = -1 },
      {v = 2, n = -1, u =  1 },
      {v = 3, n = -1, u =  2 },

      {v = 2, n = -1, u =  1 },
      {v = 0, n = -1, u = -1 },
      {v = 1, n = -1, u =  0 }
    },
    back = {
      {v = -5+2, n = 0, u =  3 },
      {v = -5+0, n = 0, u = -1 },
      {v = -5+3, n = 0, u =  4 },

      {v = -5+1, n = 0, u =  0 },
      {v = -5+0, n = 0, u = -1 },
      {v = -5+2, n = 0, u =  3 }
    }
  },
  rightWall = {
    front = {
      {v = 0, n = -1, u = -1 },
      {v = 3, n = -1, u =  2 },
      {v = 2, n = -1, u =  1 },

      {v = 0, n = -1, u = -1 },
      {v = 2, n = -1, u =  1 },
      {v = 1, n = -1, u =  0 }
    },
    back = {
      {v = -5+0, n = 0, u = -1 },
      {v = -5+2, n = 0, u =  3 },
      {v = -5+3, n = 0, u =  4 },

      {v = -5+0, n = 0, u = -1 },
      {v = -5+1, n = 0, u =  0 },
      {v = -5+2, n = 0, u =  3 }
    }
  }
}




local function compileMeshInfo(segment, side, sideName, sideNameField, quality)
  if shape == nil then return nil end

  local vertexCount = 1
  local normalCount = 1
  local uvCount     = 1
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
    if point.quality[quality] then
      pointsCount = pointsCount +1
      cappedWidth = side * math.floor(point.width * LUTDetail + 0.5) / (LUTDetail*2)

      tmpVec3:set(
        point.orientation.nx * cappedWidth +
        -point.orientation.nz +
        point.position + vec3(0,0,point.zOffset)
        )
      vertices[vertexCount] ={x = tmpVec3.x, y = tmpVec3.y, z = tmpVec3.z}
      vertexCount = vertexCount + 1

      tmpVec3:set(
        point.orientation.nx * (cappedWidth+side) +
        -point.orientation.nz +
        point.position + vec3(0,0,point.zOffset)
        )
      vertices[vertexCount] ={x = tmpVec3.x, y = tmpVec3.y, z = tmpVec3.z}
      vertexCount = vertexCount + 1

      tmpVec3:set(
        point.orientation.nx * (cappedWidth+side) +
        point.orientation.nz * (point[sideNameField])+
        point.position + vec3(0,0,point.zOffset)
        )
      vertices[vertexCount] ={x = tmpVec3.x, y = tmpVec3.y, z = tmpVec3.z}
      vertexCount = vertexCount + 1

      tmpVec3:set(
        point.orientation.nx * (cappedWidth) +
        point.orientation.nz * (point[sideNameField])+
        point.position + vec3(0,0,point.zOffset)
        )
      vertices[vertexCount] ={x = tmpVec3.x, y = tmpVec3.y, z = tmpVec3.z}
      vertexCount = vertexCount + 1

      uvs[uvCount] = {u = 0 , v = (point.uvY * uvHeight)}
      uvCount = uvCount+1
      uvs[uvCount] = {u = 0.125 , v = (point.uvY * uvHeight)}
      uvCount = uvCount+1
      uvs[uvCount] = {u = -0.2 , v = (point.uvY * uvHeight)}
      uvCount = uvCount+1
      uvs[uvCount] = {u = (point[sideNameField])*uvHeight , v = (point.uvY * uvHeight)}
      uvCount = uvCount+1


      normals[normalCount] ={x = -point.orientation.nz.x, y = -point.orientation.nz.y, z = -point.orientation.nz.z}
      normalCount = normalCount +1

      normals[normalCount] ={x = side * point.orientation.nx.x, y = side * point.orientation.nx.y, z = side * point.orientation.nx.z}
      normalCount = normalCount +1

      normals[normalCount] ={x = point.orientation.nz.x, y = point.orientation.nz.y, z = point.orientation.nz.z}
      normalCount = normalCount +1

      normals[normalCount] ={x = -side * point.orientation.nx.x, y =  -side * point.orientation.nx.y, z = -side *point.orientation.nx.z}
      normalCount = normalCount +1
    end
  end

  -- create faces from face list
  for cpIndex = 0, pointsCount-2 do
    local off = cpIndex * 4

    if side == -1 then
      for i, f in ipairs(shape.faceInfo.faces) do
        faces[(shape.faceInfo.faceCount+1-i) + (cpIndex * shape.faceInfo.faceCount)] = {
          v = f.v + off-1,
          n = f.n + off-1,
          u = f.u + off-1
        }
      end
    else
      for i, f in ipairs(shape.faceInfo.faces) do
        faces[i + cpIndex * shape.faceInfo.faceCount] = {
          v = f.v + off-1,
          n = f.n + off-1,
          u = f.u + off-1
        }
      end
    end
  end

  if segment.meshInfo[sideName].startCap or segment.meshInfo[sideName].endCap  or segment.meshInfo.forceStartCap or segment.meshInfo.forceEndCap then
    local startPoint = segment.points[1]
    local endPoint   = segment.points[#segment.points]
    local faceCount = #faces

    normals[normalCount+0] = {x = -startPoint.orientation.ny.x, y =  -startPoint.orientation.ny.y, z = -startPoint.orientation.ny.z}
    normals[normalCount+1] = {x = endPoint.orientation.ny.x, y =  endPoint.orientation.ny.y, z = endPoint.orientation.ny.z}

    uvs[uvCount+0] = {u =  0.0, v = -1 * uvHeight}
    uvs[uvCount+1] = {u = -0.125, v = -1 * uvHeight}
    uvs[uvCount+2] = {u = -0.125, v = 0.0 * uvHeight+startPoint[sideNameField] * uvHeight}
    uvs[uvCount+3] = {u =  0.0, v = 0.0 * uvHeight+startPoint[sideNameField] * uvHeight}
    uvs[uvCount+4] = {u = -0.125, v = 0.0 * uvHeight+endPoint[sideNameField] * uvHeight}
    uvs[uvCount+5] = {u =  0.0, v = 0.0 * uvHeight+endPoint[sideNameField] * uvHeight}
    if not extensions.util_trackBuilder_splineTrack.ignoreCapsForMeshes then

      if segment.meshInfo[sideName].startCap or segment.meshInfo.forceStartCap then
        for i, f in ipairs(shape[sideName].front) do
          faces[faceCount+i] = {v = f.v, n = normalCount+f.n, u = uvCount+f.u }
        end
        faceCount = faceCount + 6
      end
      if segment.meshInfo[sideName].endCap or segment.meshInfo.forceEndCap then
        for i, f in ipairs(shape[sideName].back) do
          faces[faceCount+i] = {v = vertexCount+f.v, n = normalCount+f.n, u = uvCount+f.u }
        end
      end
    end
  end
  segment.submeshIndexes[sideName] = segment.submeshCount
  segment.submeshCount = segment.submeshCount +1
  -- cap parts (omitted for now)
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
  if segment.quality == 4 then return {} end
  return {
    segment.meshInfo.leftWall.active  and compileMeshInfo(segment,-1,'leftWall', 'leftWallHeight',segment.quality)  or nil,
    segment.meshInfo.rightWall.active and compileMeshInfo(segment, 1,'rightWall','rightWallHeight',segment.quality) or nil
  }
end

M.getMeshes = getMeshes
return M