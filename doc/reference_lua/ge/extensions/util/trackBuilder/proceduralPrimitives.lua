-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- TORUS
local function createRing(radius, thickness, material)
  local vertices = {}
  local uvs = {}
  local normals = {}
  local faces = {}
  radius = radius*2 or 10
  thickness = thickness/2 or 0.5
  local outerSegments = math.floor(clamp((radius)*6,18,72))
  local innerSegments = math.floor(clamp((thickness)*12,8,24))
  local uvFlip = false
  local uvReps = math.ceil(radius)
  material = material or 'track_editor_A_border'
  local innerRing = {}
  for i = 1, innerSegments+1 do
    local rad = (i-1) * math.pi*2 / innerSegments
    innerRing[i] = {
      v = vec3(math.cos(rad) * thickness,0, math.sin(rad) * thickness),
      u = ((i-1) / innerSegments)
    }
  end

  for i = 1, outerSegments+1 do
    local outerRad = (i-1) * math.pi*2 / outerSegments
    local quat = quatFromEuler(-outerRad,0,0)
    local outerCenter = vec3(0,math.sin(-outerRad) * radius,math.cos(-outerRad)*radius)
    for j,p in ipairs(innerRing) do
      local n = quat:__mul(p.v)
      local v = outerCenter + n
      vertices[#vertices+1] = { x = v.x, y = v.y, z = v.z}
      normals[#normals+1] = {x = n.x, y = n.y, z = n.z}
      uvs[#uvs+1] = { v = p.u * thickness, u = uvReps * (i-1)/outerSegments}
    end
  end

  for o = 0, outerSegments-1 do
    for i = 0, innerSegments-1 do
      local fix = o * (innerSegments+1) + i
      faces[#faces+1] = { v = fix, n = fix, u = fix}
      faces[#faces+1] = { v = fix+1 + innerSegments+1, n = fix+1+innerSegments+1, u = fix+1+innerSegments+1}
      faces[#faces+1] = { v = fix+1, n = fix+1, u = fix+1}

      faces[#faces+1] = { v = fix, n = fix, u = fix}
      faces[#faces+1] = { v = fix + innerSegments+1, n = fix + innerSegments+1, u = fix + innerSegments+1}
      faces[#faces+1] = { v = fix + 1 + innerSegments+1, n = fix + 1 + innerSegments+1, u = fix + 1 + innerSegments+1}
    end
  end

  local mesh = {
    verts = vertices,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = material
  }
  return mesh
end

-- CYLINDER
local function createCylinder(radius, height, material)
  local vertices = {}
  local uvs = {}
  local normals = {}
  local faces = {}
  radius = math.abs(radius/2) or 1
  height = math.abs(height) or 5
  material = material or 'track_editor_A_border'
  local segments = math.floor(clamp(radius*8,12,72))
  local uvReps = math.ceil(height/2.5)

  vertices[#vertices+1] = {x = 0, y = 0, z =  height/2}
  for i = 1, segments+1 do
    local rad = (i-1) * math.pi*2 / segments
    local point = vec3(math.cos(rad), math.sin(rad),0)
    vertices[#vertices+1] = {x = point.x * radius, y = point.y * radius, z = point.z + height/2}
    normals[#normals+1] = {x = point.x, y = point.y, z = 0}
  end
  vertices[#vertices+1] = {x = 0, y = 0, z = -height/2}
  for i = 1, segments+1 do
    local rad = (i-1) * math.pi*2 / segments
    local point = vec3(math.cos(rad), math.sin(rad),0)
    vertices[#vertices+1] = {x = point.x * radius, y = point.y * radius, z = point.z - height/2}
  end
  normals[#normals+1] = {x = 0, y = 0, z =  1}
  normals[#normals+1] = {x = 0, y = 0, z = -1}

  -- around the cylinder
  for i = 1, segments+1 do
    local rad = (i-1)* radius/segments
    uvs[#uvs+1] = {v = rad, u = 0}
    uvs[#uvs+1] = {v = rad, u = uvReps}
  end
  -- flat sides
  for i = 1, segments+1 do
    uvs[#uvs+1] = {u = 0, v = (i)  *radius/segments}
    uvs[#uvs+1] = {u = radius/2, v =  (i+0.5)  * radius/segments}
    uvs[#uvs+1] = {u = 0, v =  (i+1)* radius/segments}
  end

  -- faces
  -- around the cylinder
  local t, u, r, ur
  local uvB, uvT
  local nT, nR
  for i = 1, segments do
    t = i
    r = i+1
    u = t + 2 + segments
    ur = r + 2 + segments
    uvB = (i-1) * 2
    uvT = uvB + 1
    faces[#faces+1] = {v = t , u = uvB,   n = i-1 }
    faces[#faces+1] = {v = r , u = uvB+2, n = i   }
    faces[#faces+1] = {v = ur, u = uvT+2, n = i   }

    faces[#faces+1] = {v = t,  u = uvB,   n = i-1 }
    faces[#faces+1] = {v = ur, u = uvT+2, n = i }
    faces[#faces+1] = {v = u,  u = uvT,   n = i-1 }
  end
  -- top
  for i = 1, segments do
    t = i
    r = i+1
    u = 0
    nT = segments+1
    uvT = 2*segments + (i)*3 -1
    faces[#faces+1] = {v = t, u = uvT,   n = nT }
    faces[#faces+1] = {v = u, u = uvT+1, n = nT }
    faces[#faces+1] = {v = r, u = uvT+2, n = nT }
  end
  -- bot
  for i = 1, segments do
    t = i + 2 + segments
    r = t+1
    u = segments+2
    nT = segments+2
    uvT = 2*segments + (i)*3 -1
    faces[#faces+1] = {v = t, u = uvT,   n = nT }
    faces[#faces+1] = {v = r, u = uvT+2, n = nT }
    faces[#faces+1] = {v = u, u = uvT+1, n = nT }
  end

  local mesh = {
    verts = vertices,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = material
  }
  return mesh
end

-- RÄMP
local function createRamp(width, len, hei, thinning, attack, twist, material)
  local vertices = {}
  local uvs = {}
  local normals = {}
  local faces = {}
  local segments = {}

  material = material or 'track_editor_A_border'
  len = math.abs(len or 10)
  local segCount = math.max(math.ceil(len),5)
  width = math.abs(width or 5)
  hei = math.abs(hei or 2)
  thinning = clamp(thinning or 0.5,0,2)
  twist = twist or 0
  attack = math.max(attack or 1, 1)

  local sideReps = math.ceil(len/4)
  local bottomReps = math.ceil(width/4)

  for i = 1, segCount do
    local t = (i-1) / (segCount-1)
    local bottomWidth = width
    local topWidth = width * (1-t) + (width * thinning) * (t)
    local height = (math.pow(t,attack) * hei)
    local length = t * len
    local twist = t * twist

    vertices[#vertices+1] = {x = -length+len/2, y =  bottomWidth/2, z = -1}
    vertices[#vertices+1] = {x = -length+len/2, y = -bottomWidth/2, z = -1}
    vertices[#vertices+1] = {x = -length+len/2, y = -topWidth/2, z = height}
    vertices[#vertices+1] = {x = -length+len/2, y =  topWidth/2, z = height}

    local pitch
    if attack > 1 then
      pitch = math.atan2(len,(attack * (math.pow(t,attack-1)))*(hei))
    else
      pitch = math.atan2(len,hei)
    end
    pitch = -(pitch - math.pi)
    local topNormal = vec3(-math.cos(pitch), 0, math.sin(pitch))
    topNormal:normalize()
    local sideNormal = vec3(0,height+1, (bottomWidth-topWidth)/2)
    local sideLen = sideNormal:length()
    sideNormal:normalize()
    normals[#normals+1] = {x = 0, y = 0, z = -1}
    normals[#normals+1] = {x = sideNormal.x, y = -sideNormal.y, z = sideNormal.z}
    normals[#normals+1] = {x = topNormal.x, y = topNormal.y, z = topNormal.z}
    normals[#normals+1] = {x = sideNormal.x, y = sideNormal.y, z = sideNormal.z}

    uvs[#uvs+1] = {u = 0, v=length/4 }
    uvs[#uvs+1] = {u = bottomReps, v=length/4 }

    uvs[#uvs+1] = {u = length/4, v= 0}
    uvs[#uvs+1] = {u = length/4, v= sideLen/4}

    uvs[#uvs+1] = {u = -topWidth/8, v= length/4}
    uvs[#uvs+1] = {u =  topWidth/8, v= length/4}

    uvs[#uvs+1] = {u = length/4, v= sideLen/4}
    uvs[#uvs+1] = {u = length/4, v= 0}
  end

  for i = 0, segCount-2 do
    for j = 0, 2 do
      local t = i*4 + j
      local u = i*8 + 2*j

      faces[#faces+1] = { v = t  , u = u,   n = t}
      faces[#faces+1] = { v = t+4, u = u+8, n = t+4 }
      faces[#faces+1] = { v = t+1, u = u+1, n = t}

      faces[#faces+1] = { v = t+1, u = u+1, n = t}
      faces[#faces+1] = { v = t+4, u = u+8, n = t+4}
      faces[#faces+1] = { v = t+5, u = u+9, n = t+4}
    end
    local t = i*4+3
    local u = i*8+6
    faces[#faces+1] = { v = t  , u = u, n = t}
    faces[#faces+1] = { v = t+4, u = u+8, n = t+4 }
    faces[#faces+1] = { v = t-3, u = u+1, n = t}

    faces[#faces+1] = { v = t-3, u = u+1, n = t}
    faces[#faces+1] = { v = t+4, u = u+8, n = t+4}
    faces[#faces+1] = { v = t+1, u = u+9, n = t+4}
  end

  local nCount = #normals
  local uvCount = #uvs
  local vCount = #vertices-4

  normals[#normals+1] = {x =  1, y = 0, z = 0}
  normals[#normals+1] = {x = -1, y = 0, z = 0}

  uvs[#uvs+1] = {u = -width/8, v=0 }
  uvs[#uvs+1] = {u = width/8, v=0 }

  uvs[#uvs+1] = {u = width/8, v=1 }
  uvs[#uvs+1] = {u = -width/8, v=1 }

  uvs[#uvs+1] = {u =  thinning*width/8, v=hei+1 }
  uvs[#uvs+1] = {u = -thinning*width/8, v=hei+1 }

  faces[#faces+1] = { v = 0, u = uvCount,   n = nCount}
  faces[#faces+1] = { v = 1, u = uvCount+1, n = nCount}
  faces[#faces+1] = { v = 3, u = uvCount+3, n = nCount}

  faces[#faces+1] = { v = 1, u = uvCount+1, n = nCount}
  faces[#faces+1] = { v = 2, u = uvCount+2, n = nCount}
  faces[#faces+1] = { v = 3, u = uvCount+3, n = nCount}

  faces[#faces+1] = { v = vCount+0, u = uvCount,   n = nCount+1}
  faces[#faces+1] = { v = vCount+3, u = uvCount+5, n = nCount+1}
  faces[#faces+1] = { v = vCount+1, u = uvCount+1, n = nCount+1}

  faces[#faces+1] = { v = vCount+1, u = uvCount+1, n = nCount+1}
  faces[#faces+1] = { v = vCount+3, u = uvCount+5, n = nCount+1}
  faces[#faces+1] = { v = vCount+2, u = uvCount+4, n = nCount+1}

  local mesh = {
    verts = vertices,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = material
  }
  return mesh
end

-- BUMP
local function createBump(length, width, height, upperLength, upperWidth, material)
  local vertices = {}
  local uvs = {}
  local normals = {}
  local faces = {}

  width = math.abs(width or 5)
  length = math.abs(length or 2)
  height = math.abs(height or 1)
  upperWidth = math.abs(upperWidth or 4)
  upperLength = math.abs(upperLength or 0.5)

  material = material or 'track_editor_A_border'
  local uvReps = vec3(math.ceil(upperWidth/2.5),math.ceil(upperLength/2.5),0)

  vertices[1] = { x =  width/2, y = -length/2, z = -height/2}
  vertices[2] = { x = -width/2, y = -length/2, z = -height/2}
  vertices[3] = { x = -width/2, y =  length/2, z = -height/2}
  vertices[4] = { x =  width/2, y =  length/2, z = -height/2}

  vertices[5] = { x =  upperWidth/2, y = -upperLength/2, z = height/2}
  vertices[6] = { x = -upperWidth/2, y = -upperLength/2, z = height/2}
  vertices[7] = { x = -upperWidth/2, y =  upperLength/2, z = height/2}
  vertices[8] = { x =  upperWidth/2, y =  upperLength/2, z = height/2}

  local lNormal = vec3(0,height,-(upperLength-length)/2)
  lNormal:normalize()
  local wNormal = vec3(height,0,-(upperWidth-width)/2)
  wNormal:normalize()
  normals = {
    { x =  lNormal.x, y = -lNormal.y, z =  lNormal.z },
    { x =  -wNormal.x, y =  wNormal.y, z =  wNormal.z },
    { x =  lNormal.x, y =  lNormal.y, z =  lNormal.z },
    { x =  wNormal.x, y =  wNormal.y, z =  wNormal.z },
    { x =  0, y =  0, z = -1 },
    { x =  0, y =  0, z =  1 }
  }

  local lHeight = math.ceil(math.sqrt(height*height + (upperLength-length)*(upperLength-length))/4)
  local wHeight = math.ceil(math.sqrt(height*height + (upperWidth-width)*(upperWidth-width))/4)

  uvs = {
    {u = 0,       v = -width/4.5      },
    {u = 0,       v =  width/4.5      },
    {u = lHeight, v =  upperWidth/4.5 },
    {u = lHeight, v = -upperWidth/4.5 },  -- FB

    {u = 0,       v = -length/4.5      },
    {u = 0,       v =  length/4.5      },
    {u = wHeight, v =  upperLength/4.5 },
    {u = wHeight, v = -upperLength/4.5 },  -- left/right

    {u = 0, v = 0}, {v = uvReps.y, u = 0}, {v = uvReps.y, u = uvReps.x}, {v = 0, u = uvReps.x}   -- top/bot
  }

  faces = {
    --left
    {v = 0, n = 0, u =  0},
    {v = 1, n = 0, u =  1},
    {v = 5, n = 0, u =  2},

    {v = 0, n = 0, u =  0},
    {v = 5, n = 0, u =  2},
    {v = 4, n = 0, u =  3},
    --back
    {v = 1, n = 1, u =  5},
    {v = 2, n = 1, u =  4},
    {v = 6, n = 1, u =  7},

    {v = 1, n = 1, u =  5},
    {v = 6, n = 1, u =  7},
    {v = 5, n = 1, u =  6},
    -- right
    {v = 2, n = 2, u =  1},
    {v = 3, n = 2, u =  0},
    {v = 7, n = 2, u =  3},

    {v = 2, n = 2, u =  1},
    {v = 7, n = 2, u =  3},
    {v = 6, n = 2, u =  2},
    --front
    {v = 3, n = 3, u =  4},
    {v = 0, n = 3, u =  5},
    {v = 4, n = 3, u =  6},

    {v = 3, n = 3, u =  4},
    {v = 4, n = 3, u =  6},
    {v = 7, n = 3, u =  7},
    -- bot
    {v = 0, n = 4, u =  10},
    {v = 3, n = 4, u =  11},
    {v = 2, n = 4, u =  8},

    {v = 0, n = 4, u =  10},
    {v = 2, n = 4, u =  8},
    {v = 1, n = 4, u =  9},
    -- top
    {v = 5, n = 5, u =  9},
    {v = 6, n = 5, u =  8},
    {v = 7, n = 5, u =  11},

    {v = 5, n = 5, u =  9},
    {v = 7, n = 5, u =  11},
    {v = 4, n = 5, u =  10},
  }

  local mesh = {
    verts = vertices,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = material
  }
  return mesh
end

-- CONE
local function createCone(radius, height, material)
  local vertices = {}
  local uvs = {}
  local normals = {}
  local faces = {}
  radius = math.abs(radius/2) or 1
  height = math.abs(height) or 5
  material = material or 'track_editor_A_border'
  local segments = math.floor(clamp(radius*8,12,72))
  local uvReps = math.ceil(height/2.5)
  local normalSlope = vec3(height, 0, radius)
  normalSlope:normalize()

  vertices[#vertices+1] = {x = 0, y = 0, z = -height/2}
  vertices[#vertices+1] = {x = 0, y = 0, z = height/2}
  normals[#normals+1] = {x = 0, y = 0, z = -1}
  for i = 1, segments+1 do
    local rad = (i-1) * math.pi*2 / segments
    local point = vec3(math.cos(rad), math.sin(rad),0)
    local quat = quatFromEuler(0,0,-rad)
    local quatC = quatFromEuler(0,0,-(i-0.5) * math.pi*2 / segments)
    vertices[#vertices+1] = {x = point.x * radius, y = point.y * radius, z = point.z - height/2}
    normals[#normals+1] =  quat:__mul(normalSlope) -- bottom parts
    normals[#normals+1] =  quatC:__mul(normalSlope) -- top parts
  end

  -- slope side
  for i = 1, segments+1 do
    uvs[#uvs+1] = {u = 0, v = (i) *radius/segments}
    uvs[#uvs+1] = {u = math.sqrt(radius*radius + height*height)/2, v = (i+0.5)  * radius/segments}
    uvs[#uvs+1] = {u = 0, v =  (i+1)* radius/segments}
  end

  -- flat side
  for i = 1, segments+1 do
    uvs[#uvs+1] = {u = 0, v = (i)  *radius/segments}
    uvs[#uvs+1] = {u = radius/2, v =  (i+0.5)  * radius/segments}
    uvs[#uvs+1] = {u = 0, v =  (i+1)* radius/segments}
  end

  -- faces
  local t, u, r
  for i = 1, segments do
    t = i+1
    r = t+1
    u = 0
    faces[#faces+1] = {v = t, u = (i-1)*3 + 0, n = (i-1)*2 + 1 }
    faces[#faces+1] = {v = 1, u = (i-1)*3 + 1, n = (i-1)*2 + 2 }
    faces[#faces+1] = {v = r, u = (i-1)*3 + 2, n = (i-1)*2 + 3 }

    faces[#faces+1] = {v = t, u = 3 * segments + (i)*3 + 0, n = 0 }
    faces[#faces+1] = {v = r, u = 3 * segments + (i)*3 + 2, n = 0 }
    faces[#faces+1] = {v = 0, u = 3 * segments + (i)*3 + 1, n = 0 }
  end

  local mesh = {
    verts = vertices,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = material
  }
  return mesh
end

-- CUBE
local function createCube(size, material, uvStyle)
  local vertices = {}
  local uvs = {}
  local normals = {}
  local faces = {}
  size = size and vec3(math.abs(size.y), math.abs(size.x), math.abs(size.z)) or vec3(1,1,1)
  material = material or 'track_editor_A_border'
  uvStyle = uvStyle or 1
  local uvReps = vec3(math.ceil(size.x/3),math.ceil(size.y/3), math.ceil(size.z/3))

  size = size * 0.5
  vertices = {
    { x =  size.x, y = -size.y, z = -size.z },
    { x = -size.x, y = -size.y, z = -size.z },
    { x = -size.x, y =  size.y, z = -size.z },
    { x =  size.x, y =  size.y, z = -size.z },
    { x =  size.x, y = -size.y, z =  size.z },
    { x = -size.x, y = -size.y, z =  size.z },
    { x = -size.x, y =  size.y, z =  size.z },
    { x =  size.x, y =  size.y, z =  size.z }
  }
  normals = {
    { x =  0, y = -1, z =  0 },
    { x = -1, y =  0, z =  0 },
    { x =  0, y =  1, z =  0 },
    { x =  1, y =  0, z =  0 },
    { x =  0, y =  0, z = -1 },
    { x =  0, y =  0, z =  1 }
  }

  if uvStyle == 1 then
    uvs = {
      {u = 0, v = 0}, {u = uvReps.x, v = 0}, {u = uvReps.x, v = uvReps.z}, {u = 0, v = uvReps.z},  -- left/right
      {u = 0, v = 0}, {u = uvReps.y, v = 0}, {u = uvReps.y, v = uvReps.z}, {u = 0, v = uvReps.z},  -- front/back
      {u = 0, v = 0}, {u = uvReps.y, v = 0}, {u = uvReps.y, v = uvReps.x}, {u = 0, v = uvReps.x}   -- top/bot
    }
  else
    uvs = {
      {u = 0, v = 0}, {u = uvReps.x, v = 0}, {u = uvReps.x, v = uvReps.z}, {u = 0, v = uvReps.z},  -- left/right
      {u = 0, v = 0}, {u = 0, v = uvReps.y}, {u = uvReps.z, v = uvReps.y}, {u = uvReps.z, v = 0},  -- front/back
      {u = 0, v = 0}, {u = uvReps.y, v = 0}, {u = uvReps.y, v = uvReps.x}, {u = 0, v = uvReps.x}   -- top/bot
    }

  end

  faces = {
    --left
    {v = 0, n = 0, u =  0},
    {v = 1, n = 0, u =  1},
    {v = 5, n = 0, u =  2},

    {v = 0, n = 0, u =  0},
    {v = 5, n = 0, u =  2},
    {v = 4, n = 0, u =  3},
    --back
    {v = 1, n = 1, u =  5},
    {v = 2, n = 1, u =  4},
    {v = 6, n = 1, u =  7},

    {v = 1, n = 1, u =  5},
    {v = 6, n = 1, u =  7},
    {v = 5, n = 1, u =  6},
    -- right
    {v = 2, n = 2, u =  1},
    {v = 3, n = 2, u =  0},
    {v = 7, n = 2, u =  3},

    {v = 2, n = 2, u =  1},
    {v = 7, n = 2, u =  3},
    {v = 6, n = 2, u =  2},
    --front
    {v = 3, n = 3, u =  4},
    {v = 0, n = 3, u =  5},
    {v = 4, n = 3, u =  6},

    {v = 3, n = 3, u =  4},
    {v = 4, n = 3, u =  6},
    {v = 7, n = 3, u =  7},
    -- bot
    {v = 0, n = 4, u =  10},
    {v = 3, n = 4, u =  11},
    {v = 2, n = 4, u =  8},

    {v = 0, n = 4, u =  10},
    {v = 2, n = 4, u =  8},
    {v = 1, n = 4, u =  9},
    -- top
    {v = 5, n = 5, u =  9},
    {v = 6, n = 5, u =  8},
    {v = 7, n = 5, u =  11},

    {v = 5, n = 5, u =  9},
    {v = 7, n = 5, u =  11},
    {v = 4, n = 5, u =  10},
  }

  local mesh = {
    verts = vertices,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = material
  }
  return mesh
end

-- ICOSPHERE
local function divideEdge(vertexList,vertexLookUp, first, second)
  if first > second then
    local tmp = first
    first = second
    second = tmp
  end
  if vertexLookUp[first][second] == nil then
    local a = vertexList[first+1] *0.5 + vertexList[second+1] * 0.5
    a:normalize()
    vertexList[#vertexList+1] = a
    vertexLookUp[first][second] = #vertexList
  end
  return vertexLookUp[first][second]
end

local function divideTriangles(oldVertices, oldTriangles)

    local newTriangles = {}
    local vertexLookUp = {}
    for i = 0, #oldVertices-1 do vertexLookUp[i] = {} end
    for i,t in ipairs(oldTriangles) do
      local mid = {}
      mid[1] = divideEdge(oldVertices, vertexLookUp, t[1],t[2])
      mid[2] = divideEdge(oldVertices, vertexLookUp, t[2],t[3])
      mid[3] = divideEdge(oldVertices, vertexLookUp, t[3],t[1])

      newTriangles[#newTriangles+1] = {t[1],mid[1]-1,mid[3]-1}
      newTriangles[#newTriangles+1] = {t[2],mid[2]-1,mid[1]-1}
      newTriangles[#newTriangles+1] = {t[3],mid[3]-1,mid[2]-1}
      newTriangles[#newTriangles+1] = {mid[1]-1,mid[2]-1,mid[3]-1}
    end
    return newTriangles
end

local function createIcosphere(origin, size, subdivisions, planetGravity)
  if not origin then origin = vec3(0,0,0) end
  if not size then size = 5 end
  if subdivisions > 5 then subdivisions = 5 end
  if not subdivisions then subdivisions = 1 end
  local X = 0.525731112119133606
  local Z = 0.850650808352039932
  local N = 0.0

  local vertexList = {
    vec3(-X,N,Z), vec3(X,N,Z), vec3(-X,N,-Z), vec3(X,N,-Z),
    vec3(N,Z,X), vec3(N,Z,-X), vec3(N,-Z,X), vec3(N,-Z,-X),
    vec3(Z,X,N), vec3(-Z,X, N), vec3(Z,-X,N), vec3(-Z,-X, N)
  }
  local uvs = {
    {u=0, v=0}
  }
  local triangleList = {
    {0,4,1},{0,9,4},{9,5,4},{4,5,8},{4,8,1},
    {8,10,1},{8,3,10},{5,3,8},{5,2,3},{2,7,3},
    {7,10,3},{7,6,10},{7,11,6},{11,0,6},{0,1,6},
    {6,1,10},{9,0,11},{9,11,2},{9,2,5},{7,2,11}
  }

  -- subdivisions
  for i = 1, subdivisions do
    triangleList = divideTriangles(vertexList,triangleList)
  end

  -- make normals
  local normals = {}
  local verts = {}
  for i,v in ipairs(vertexList) do
    normals[i] = {x = v.x, y = v.y, z=v.z}
    verts[i] = {x = v.x * size, y = v.y * size, z = v.z * size}
  end
  --    {v = 2, n = 2, u =  7},
  local faces = {}
  for i,t in ipairs(triangleList) do
    for x = 1,3 do
      faces[#faces+1] = {v = t[x], u = 0, n = t[x]}
    end
  end

  local mesh = {
    verts = verts,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = "track_editor_A_border"
  }

  local splineObject = createObject("ProceduralMesh")
  splineObject:setPosition(origin)
  splineObject.canSave = false
  splineObject:registerObject('Ico')
  splineObject:createMesh({{mesh}})
  scenetree.MissionGroup:add(splineObject.obj)
  be:reloadCollision()
  lastIco = splineObject.obj
end

M.createCylinder = createCylinder
M.createRing = createRing
M.createCube = createCube
M.createCone = createCone
M.createBump = createBump
M.createRamp = createRamp
return M