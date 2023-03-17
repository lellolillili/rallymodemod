-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- exports a vehicle into glTF

-- how to use:
-- extensions.export.export('vehicle.gltf')

local M = {}

local ffi = require("ffi")

local jbeamIO = require('jbeam/io')

local EXTENSION_JBEAM = "BNG_JBeamData"
local EXTENSION_DIRECTION = "BNG_Direction"

if not _G['__gpuFlexMesh_t_cdef'] then
  ffi.cdef[[
  typedef struct gpuPrimitive_t {
    uint32_t startIndex;
    uint32_t indexCount;
    uint32_t materialId;
  } gpuPrimitive_t;

  typedef struct gpuFlexMesh_t {
    char* meshName;
    uint32_t primitivesCount;
    gpuPrimitive_t* primitives;
  } gpuFlexMesh_t;

  typedef struct gpuPropMesh_t {
    char* meshName;
    float position[3];
    float rotation[4];

    uint32_t indicesCount;
    uint32_t* indices;

    uint32_t verticesCount;
    float* vertices;

    uint32_t normalsCount;
    float* normals;

    uint32_t tangentsCount;
    float* tangents;

    uint32_t uv1Count;
    float* uv1; // Vector2

    uint32_t uv2Count;
    float* uv2; // Vector2

    uint32_t vertColorsCount;
    uint32_t* vertColors; // RGB packed

    uint32_t primitivesCount;
    gpuPrimitive_t* primitives;
  } gpuPropMesh_t;

  typedef struct gpuMesh_t {
    uint32_t indicesCount;
    uint32_t* indices;

    uint32_t verticesCount;
    float* vertices;

    uint32_t normalsCount;
    float* normals;

    uint32_t tangentsCount;
    float* tangents;

    uint32_t uv1Count;
    float* uv1;

    uint32_t uv2Count;
    float* uv2;

    uint32_t vertColorsCount;
    uint32_t* vertColors;

    uint32_t flexmeshesCount;
    gpuFlexMesh_t* flexmeshes;

    uint32_t propmeshesCount;
    gpuPropMesh_t* propmeshes;

    bool dataIsReady;
  } gpuMesh_t;

  gpuMesh_t* bng_getGPUMesh(int id);
  void bng_freeGPUMesh(int id, gpuMesh_t* meshInfo);

  unsigned char* bng_base64_encode(unsigned char* src, size_t len, size_t* out_len);
  unsigned char* bng_base64_decode(unsigned char* src, size_t len, size_t* out_len);
  void bng_base64_free(unsigned char* buffer);
  ]]

  rawset(_G, '__gpuFlexMesh_t_cdef', true)
end

-- constants
local base64Prefix = "data:application/octet-stream;base64,"
local floatByteSize = ffi.sizeof('float')
local unsignedIntByteSize = ffi.sizeof('unsigned int')

local continueRecording = false
local framesRecorded = 0
local gltfRoot
local keyFrameTimes = {}
local timer = hptimer()
local binaryBuffers = {}

local lastMeshInfo
local bufferPathPattern = nil
local exportHandler = nil
local savedImages = {}

local gltfRootTemplate = {
  asset = {
    generator = beamng_appname .. " " .. beamng_versiond,
    version = "2.0"
  },
  scenes = {
    {
      nodes = {}
    }
  },
  nodes = {},
  materials = {},
  meshes = {},
  buffers = {},
  bufferViews = {},
  accessors = {},
  images = {},
  textures = {},
}

local _log = log
local function log(level, msg)
  _log(level, 'gltfExport', msg)
end

local function dbgNodeName(gltfRoot, jsonIndex)
  local luaIndex = jsonIndex +1
  if gltfRoot.nodes[luaIndex] then
    return dumps(gltfRoot.nodes[luaIndex].name).."["..dumps(jsonIndex).."]"
  else
    return "NodeDoesNotExist!!!!["..dumps(jsonIndex).."]"
  end
end

local function _addBuffer(gltfRoot, data, dataSize, name)
  -- log('D', 'Adding buffer ' ..dumps(name) .. " size=" .. tostring(dataSize))
  -- buffer table goes first
  local buffer = {
    byteLength = dataSize
  }
  table.insert(gltfRoot.buffers, buffer)
  local bufferID = #gltfRoot.buffers - 1

  if M.gltfBinaryFormat then
    table.insert(binaryBuffers, {data=data, len=dataSize})
    bufferID = #binaryBuffers - 1
    --log('D', 'Buffers binary'..dumps(bufferID))
  else
    -- then we encode or write the data out
    if M.embedBuffers then
      -- log('D', 'Buffers are to be embedded.')
      -- write index buffer in base64 encoding
      local out_len = ffi.new('size_t[1]', 0)
      local res = ffi.C.bng_base64_encode(ffi.cast('unsigned char*', data), dataSize, out_len)
      if not res then
        log('E', 'Unable to base64 encode buffer.')
        return
      end
      -- writeFile("test.b64", ffi.string(res))
      buffer.uri = base64Prefix .. ffi.string(res, out_len[0])
      -- log('D', 'Embedded base64-encoded buffer of length: ' .. tostring(out_len[0]))
    else
      log('D', 'Buffers are to be stored externally.')
      local binaryFilename = string.format(bufferPathPattern, bufferID, name)
      local dataString = ffi.string(data, dataSize)
      writeFile(binaryFilename, dataString)
      local p, filename, ext
      p, filename, ext = path.split(binaryFilename)
      buffer.uri = filename
      log('D', 'Wrote buffer to: ' .. binaryFilename)
    end
  end
  return bufferID
end

local function _addBufferView(gltfRoot, bufferID, byteOffset, byteLength, name)
  -- then bufferview
  local bufferView = {
    buffer = bufferID,
    byteOffset = byteOffset,
    byteLength = byteLength,
  }
  if name then bufferView.name = name end
  table.insert(gltfRoot.bufferViews, bufferView)
  --dump{'bufferview', #gltfRoot.bufferViews - 1, name}
  return #gltfRoot.bufferViews - 1
end

local function _addBufferviewAccessor(gltfRoot, bufferID, byteOffset, byteLength, accessor, name)
  -- log('D', 'Adding bufferViewAccessor ' ..dumps(name) .. " buf=" ..dumps(bufferID) .. " offset=" ..dumps(byteOffset).. " len=" .. tostring(byteLength))

  local bufferViewId = _addBufferView(gltfRoot, bufferID, byteOffset, byteLength, name)

  -- then the accessor
  local _accessor = {
    bufferView = bufferViewId,
    byteOffset = 0,
  }
  tableMerge(_accessor, accessor)
  table.insert(gltfRoot.accessors, _accessor)
  local accessorID = #gltfRoot.accessors - 1
  return accessorID
end

local function _addTimeBuffers(gltfRoot)
  -- first, the times
  local timeBufferSize = #keyFrameTimes * floatByteSize
  local keyFrameTimes_c = ffi.new('float[' .. #keyFrameTimes .. ']', 0)
  for i = 1, #keyFrameTimes do
    keyFrameTimes_c[i - 1] = keyFrameTimes[i]
  end

  local accessor = {
    min = { keyFrameTimes[1] },
    max = { keyFrameTimes[#keyFrameTimes - 1] },
    componentType = 5126, -- 5126 = Float32Array.BYTES_PER_ELEMENT
    type = "SCALAR",
  }

  local bufferIDTimes = _addBuffer(gltfRoot, keyFrameTimes_c, timeBufferSize, 'time')
  local accessorIDTimes = _addBufferviewAccessor(gltfRoot, bufferIDTimes, 0, timeBufferSize, accessor, 'times')

  -- then the keyframes
  local keyframeNumbersBufferSize = #keyFrameTimes * unsignedIntByteSize
  local keyFrameNumbers_c = ffi.new('unsigned int[' .. #keyFrameTimes .. ']', 0)
  for i = 1, #keyFrameTimes do
    keyFrameNumbers_c[i - 1] = i - 1
  end

  accessor = {
    min = { 0 },
    max = { #keyFrameTimes - 1 },
    componentType = 5125, -- 5125 = Uint32Array.BYTES_PER_ELEMENT,
    type = "SCALAR",
  }

  local bufferIDKeyframes = _addBuffer(gltfRoot, keyFrameNumbers_c, keyframeNumbersBufferSize, 'keyframes')
  local accessorIDKeyframes = _addBufferviewAccessor(gltfRoot, bufferID, 0, keyframeNumbersBufferSize, accessor, 'keyframes')

  -- integration into gltf root
  local animSampler = gltfRoot.animations[1].samplers[1]
  animSampler.input = accessorIDTimes
  animSampler.output = accessorIDKeyframes
end

local function _addIndexBuffer(gltfRoot, meshInfo)
  -- log('I', 'Mesh index count: ' .. dumps(meshInfo.indicesCount) .. ', bytes: ' .. dumps(meshInfo.indicesCount * unsignedIntByteSize))
  return _addBuffer(gltfRoot, meshInfo.indices, meshInfo.indicesCount * unsignedIntByteSize, 'index')
end

local function _findBufferMinMax(count, buffer)
  local minx = math.huge
  local miny = math.huge
  local minz = math.huge
  local maxx = -math.huge
  local maxy = -math.huge
  local maxz = -math.huge
  for i = 0, (count - 1) * 3, 3 do
    local x = buffer[i]
    local y = buffer[i + 1]
    local z = buffer[i + 2]
    minx = math.min(minx, x)
    miny = math.min(miny, y)
    minz = math.min(minz, z)
    maxx = math.max(maxx, x)
    maxy = math.max(maxy, y)
    maxz = math.max(maxz, z)
  end
  return { min = { minx, miny, minz}, max = { maxx, maxy, maxz} }
end

local function _addBufferAndAccessor(gltfRoot, count, bufferSize, buffer, componentType, type, name, minMax)
  if minMax == nil then
    minMax = false
  end

  local accessor = {
    count = count,
    componentType = componentType,
    type = type
  }

  if minMax then
    local minMax = _findBufferMinMax(count, buffer)
    accessor.min = minMax.min
    accessor.max = minMax.max
  end

  local bufferID = _addBuffer(gltfRoot, buffer, bufferSize, name)
  return _addBufferviewAccessor(gltfRoot, bufferID, 0, bufferSize, accessor, name)
end

local function _addVec3Buffer(gltfRoot, count, buffer, name)
  return _addBufferAndAccessor(gltfRoot, count, count * floatByteSize * 3, buffer, 5126, "VEC3", name, true)
end

local function _addColorBuffer(gltfRoot, count, buffer, name)
  return _addBufferAndAccessor(gltfRoot, count, count * 4, buffer, 5121, "VEC4", name)
end

local function _addTangentBuffer(gltfRoot, count, buffer, name)
  return _addBufferAndAccessor(gltfRoot, count, count * floatByteSize * 4, buffer, 5126, "VEC4", name)
end

local function _addTexcoordBuffer(gltfRoot, count, buffer, name)
  return _addBufferAndAccessor(gltfRoot, count, count * floatByteSize * 2, buffer, 5126, "VEC2", name)
end

local function _ensureResourcedFreed()
  if lastMeshInfo then
    ffi.C.bng_freeGPUMesh(be:getPlayerVehicleID(0), lastMeshInfo)
    lastMeshInfo = nil
  end
end

local function _triggerExport()
  _ensureResourcedFreed()
  lastMeshInfo = ffi.C.bng_getGPUMesh(be:getPlayerVehicleID(0))
end

local function _findOrCreateMaterial(gltfRoot, matId)
  for k,v in ipairs(gltfRoot.materials) do
    if v.extras.bngMaterialId == matId then
      -- log("I", "mat reuse "..dumps(v.bngMaterialId) .. " k="..dumps(k))
      return k-1
    end
  end

  --create
  local mat = {
    extras = {bngMaterialId = matId},
    doubleSided = true,
    name = dumps(matId),
  }

  -- log("I", "mat create "..dumps(mat.bngMaterialId))

  table.insert(gltfRoot.materials, mat)
  return #gltfRoot.materials -1

end

local function _addMesh(gltfRoot, attributes, indexBufferID, meshInfo, submeshInfo)
  local meshName
  if submeshInfo.meshName then
    meshName = ffi.string(submeshInfo.meshName)
  end
  -- log("I"," *** " .. tostring(meshName) .. ' : ' .. tostring(submeshInfo.startIndex) .. '[' .. tostring(submeshInfo.indexCount) .. ']')
  -- first: add a new bufferview and accessor

  local mesh = {primitives = {}}

  for primI = 0, (submeshInfo.primitivesCount - 1 ) do
    -- log("I", "mesh="..dumps(meshName).." prim="..dumps(primI).."/"..dumps(submeshInfo.primitivesCount))
    if submeshInfo.primitives == nil then goto continue end
    local primitive = submeshInfo.primitives[primI]
    -- log("I", "primitive "..dumps(primitive.startIndex) .."-"..dumps(primitive.indexCount) .." max=" ..dumps(meshInfo.indicesCount) .." mat="..dumps(primitive.materialId) )
    -- find min/max triangle
    local minIdx = math.huge
    local maxIdx = -math.huge
    for i = primitive.startIndex, math.min(primitive.startIndex + primitive.indexCount - 1, meshInfo.indicesCount - 1) do
      local idx = meshInfo.indices[i]
      minIdx = math.min(minIdx, idx)
      maxIdx = math.max(maxIdx, idx)
    end

    -- log("I", "min/max")

    local accessor = {
      count = primitive.indexCount,
      min = { minIdx },
      max = { maxIdx },
      componentType = 5125, -- 5125 = Uint32Array.BYTES_PER_ELEMENT
      type = "SCALAR",
    }

    local meshIndexAccessorID = _addBufferviewAccessor(gltfRoot, indexBufferID, primitive.startIndex * unsignedIntByteSize, primitive.indexCount * unsignedIntByteSize, accessor, 'index_' .. meshName)
    -- log("I", "_addBufferviewAccessor")

    table.insert(mesh.primitives,
      {
        indices = meshIndexAccessorID,
        attributes = attributes,
        material = _findOrCreateMaterial(gltfRoot, primitive.materialId)
      }
    )
    -- log("I", "insert")

    ::continue::

  end

  -- second: add the according mesh

  table.insert(gltfRoot.meshes, mesh)
  local meshID = #gltfRoot.meshes - 1

  -- then the node
  local node = {
    name = meshName,
    mesh = meshID
  }
  table.insert(gltfRoot.nodes, node)
  local nodeID = #gltfRoot.nodes - 1

  --[[
  if #gltfRoot.scenes == 0 then
    table.insert(gltfRoot.scenes, {nodes = {}})
  end

  -- add to the scene
  table.insert(gltfRoot.scenes[1].nodes, nodeID)
  --]]

  return nodeID
end

local function _addMeshProp(gltfRoot, prop)

  local indexBufferID = _addIndexBuffer(gltfRoot, prop)
  local vertexAccessorID = _addVec3Buffer(gltfRoot, prop.verticesCount, prop.vertices, "vertices")
  local attributes = {
    POSITION = vertexAccessorID
  }

  if M.exportNormals then
    local normalAccessorID = _addVec3Buffer(gltfRoot, prop.normalsCount, prop.normals, "normals")
    attributes.NORMAL = normalAccessorID
  end

  if M.exportTangents then
    local tangentAccessorID = _addTangentBuffer(gltfRoot, prop.tangentsCount, prop.tangents, "tangents")
    attributes.TANGENT = tangentAccessorID
  end

  if M.exportTexCoords then
    local texcoord1AccessorID = _addTexcoordBuffer(gltfRoot, prop.uv1Count, prop.uv1, "texcoord1")
    local texcoord2AccessorID = _addTexcoordBuffer(gltfRoot, prop.uv2Count, prop.uv2, "texcoord2")
    attributes.TEXCOORD_0 = texcoord1AccessorID
    attributes.TEXCOORD_1 = texcoord2AccessorID
  end

  if M.exportColors then
    local colorAccessorID = _addColorBuffer(gltfRoot, prop.vertColorsCount, prop.vertColors, "colors")
    attributes.COLOR_0 = colorAccessorID
  end
  local nodeId = _addMesh(gltfRoot, attributes, indexBufferID, prop, prop)
  gltfRoot.nodes[nodeId+1].translation = {prop.position[0],prop.position[2],-prop.position[1]}
  gltfRoot.nodes[nodeId+1].rotation = {-prop.rotation[0],-prop.rotation[2],prop.rotation[1],prop.rotation[3]}
  return nodeId
end


local function _getPartNodeBeams(veh, v)
  local partNodeBeams = {}

  for i, beam in pairs(v.vdata.beams) do
    local id1 = beam.id1
    local id2 = beam.id2
    local part = beam.partOrigin
    if part then
      local n1 = v.vdata.nodes[id1].name
      local n2 = v.vdata.nodes[id2].name

      if n1 == nil then
        n1 = tostring(id1)
      end

      if n2 == nil then
        n2 = tostring(id2)
      end

      if partNodeBeams[part] == nil then
        partNodeBeams[part] = {
          nodes = {},
          beams = {},
        }
      end

      local p1
      local p2
      local length
      local entry = partNodeBeams[part]

      -- p1 = vec3(veh:getOriginalNodePositionRelative(id1))
      -- p2 = vec3(veh:getOriginalNodePositionRelative(id2))
      -- length = (p1 - p2):length()
      -- entry.originalNodes[n1] = {p1.x, p1.z, -p1.y}
      -- entry.originalNodes[n2] = {p2.x, p2.z, -p2.y}
      -- table.insert(entry.originalBeams, {n1, n2, length})

      p1 = vec3(veh:getNodePosition(id1))
      p2 = vec3(veh:getNodePosition(id2))
      length = (p1 - p2):length()
      entry.nodes[n1] = {p1.x, p1.z, -p1.y}
      entry.nodes[n2] = {p2.x, p2.z, -p2.y}
      table.insert(entry.beams, {n1, n2, length})
    end
  end

  return partNodeBeams
end

local function _createOrGetNode(gltfRoot, partNodes, partNodeIDs, rootNodes, partNodeBeams, part)
  if partNodes[part] == nil then
    local node = {name = part}
    partNodes[part] = node
    table.insert(gltfRoot.nodes, node)
    local nodeID = #gltfRoot.nodes - 1
    rootNodes[nodeID] = true
    partNodeIDs[part] = nodeID

    if partNodeBeams ~= nil and partNodeBeams[part] ~= nil then
      node.extras = {}
      node.extras[EXTENSION_JBEAM] = partNodeBeams[part]
    end
  end

  return partNodes[part]
end

local function _addMeshNodes(node, meshes, meshNodeMap)
  if node.children == nil then
    node.children = {}
  end

  for mesh, d in pairs(meshes) do
    if meshNodeMap[mesh] then
      table.insert(node.children, meshNodeMap[mesh])
    else
      log("E","mesh not found "..dumps(mesh))
    end
  end
  if #node.children ==0 then
    log("W","empty node child meshes. fixing gltf")
    node.children = nil --just to have valid GLTF
  end
end

local function _createPartTree(gltfRoot, chosenParts, slotMap, partToFlexMesh, meshNodeMap, partNodeBeams, createdNodeIDs)
  partToFlexMesh = deepcopy(partToFlexMesh)
  gltfRoot.scenes[1].nodes = {}

  --- not used !!!
  local parentage = {}
  for parent, children in pairs(slotMap) do
    for idx, child in ipairs(children) do
      parentage[child] = parent
    end
  end

  local partNodes = {}
  local partNodeIDs = {}
  local rootNodes = {}

  -- log("I", "===================================  chosenParts")

  for part, choice in pairs(chosenParts) do
    local node = _createOrGetNode(gltfRoot, partNodes, partNodeIDs, rootNodes, partNodeBeams, part)
    -- log("I", dbgNodeName(gltfRoot,partNodeIDs[part]))

    if partToFlexMesh[part] ~= nil then
      _addMeshNodes(node, partToFlexMesh[part], meshNodeMap)
      partToFlexMesh[part] = nil
    end

    if partToFlexMesh[choice] ~= nil then
      _addMeshNodes(node, partToFlexMesh[choice], meshNodeMap)
      partToFlexMesh[choice] = nil
    end
  end

  -- log("I", "===================================  slotMap")

  for part, data in pairs(slotMap) do
    if chosenParts[part] ~= nil and chosenParts[part] ~= '' then
      local node = _createOrGetNode(gltfRoot, partNodes, partNodeIDs, rootNodes, partNodeBeams, part)
      -- log("I", dbgNodeName(gltfRoot,partNodeIDs[part]))
      if data.slots ~= nil then
        for subPart, d in pairs(data.slots) do
          if chosenParts[subPart] ~= nil and chosenParts[subPart] ~= '' then
            if partNodes[subPart] ~= nil then
              if node.children == nil then
                node.children = {}
              end

              local subNodeID = partNodeIDs[subPart]
              -- log("I", "\t\t"..dbgNodeName(gltfRoot,subNodeID))
              table.insert(node.children, subNodeID)
              rootNodes[subNodeID] = false
            end
          end
        end
      end
    end
  end

  --parent chk
  local parent = {}
  for kn,vn in pairs(gltfRoot.nodes) do
    if rootNodes[kn-1] then
      parent[kn-1] = "scene"
    end
    if gltfRoot.nodes[kn].children then
      for _,kc in ipairs(gltfRoot.nodes[kn].children) do
        if parent[kc] then
          log("E", "parent already defined for "..dbgNodeName(gltfRoot,kc).." curentParent="..dbgNodeName(gltfRoot,parent[kc]) .." new="..dbgNodeName(gltfRoot,kn-1))
        end
        parent[kc] = kn
      end
    end
  end

  -- log("I", "dump rootNodes")

  -- dump(rootNodes)


  -- log("I", "===================================  dump tree")
  -- local function dumpChild(nodeId,i, parentNode)
  --   local luaIndex = nodeId +1
  --   if not gltfRoot.nodes[luaIndex] then
  --     log("E", string.rep("    ", i).. "invalid node "..dbgNodeName(gltfRoot,nodeId))
  --     return
  --   end
  --   if tableContains(parentNode ,nodeId) then
  --     log("E", string.rep("    ", i).. "already parented or looping tree!!! "..dbgNodeName(gltfRoot,nodeId))
  --     return
  --   end
  --   log("I", string.rep("    ", i).. dbgNodeName(gltfRoot,nodeId))
  --   table.insert(parentNode, nodeId)
  --   if gltfRoot.nodes[luaIndex].children then
  --     for k,v in ipairs(gltfRoot.nodes[luaIndex].children) do
  --       dumpChild(v,i+1, parentNode)
  --     end
  --   end
  -- end
  -- for kp,rootNode in pairs(rootNodes) do
  --   if rootNodes then
  --     dumpChild(kp,0, {} )
  --   end
  -- end

  -- log("I", "===================================  dump child")
  -- for k,v in pairs(gltfRoot.nodes) do
  --   log("I", dbgNodeName(gltfRoot,k-1) .. dumps(v.children))
  -- end

  for kn,vn in pairs(gltfRoot.nodes) do
    if not parent[kn-1] then
      log("W", "parent not found for "..dbgNodeName(gltfRoot,kn-1)..",item will be missing when reimporting")
    end
  end

  return rootNodes
end

local function _findOrCreateTexture(gltfRoot, filepath)
  filepath = filepath:lower()
  if savedImages[filepath] then
    return savedImages[filepath]
  end

  local filepathIn = filepath
  if not FS:fileExists(filepath) then
    if filepath:sub(1, 1) == '@' then
      local filepathIn = filepath
      local veh = be:getPlayerVehicle(0)
      if veh then
        filepath = '/temp/ceftexture_' .. filepath:gsub('@', '') .. '.png'
        -- always overwrite, the file might have been a leftover from another vehicle
        if veh:dumpCEFTexture(filepathIn, filepath) then
          log('I', 'dumped CEF texture ' .. filepathIn .. ' to file ' .. filepath)
        else
          log('E', 'Could not dump CEF texture ' .. filepathIn .. ' to file ' .. filepath)
        end
      end
    else
      local foundFiles = FS:findFiles('/', filepathIn, -1, false, false)
      if #foundFiles == 1 then
        filepath = foundFiles[1]
        log('D', 'assuming ' .. filepathIn .. ' is actually ' .. filepath)
      else
        log('E', 'texture file not found: ' .. tostring(filepathIn))
        return nil
      end
    end
  end

  local _, _, ext = path.split(filepath)
  local mimeType = 'image/jpeg'
  if ext == 'jpg' or ext == 'jpeg' then
    mimeType = 'image/jpeg'
  elseif ext == 'png' then
    mimeType = 'image/png'
  elseif ext == 'dds' then
    mimeType = 'image/png'
    local filepathIn = filepath
    filepath = '/temp/' .. filepath .. '.png'
    if not FS:fileExists(filepath) then
      if not convertDDSToPNG(filepathIn, filepath) then
        log('E', 'Unable to convert dds to png: ' .. tostring(filepath))
      end
      log('I', 'Converted dds to png: ' .. tostring(filepathIn) .. ' > ' .. tostring(filepath))
    end
  else
    log('E', 'Unsupported texture format: ' .. tostring(filepath))
    return nil
  end

  local f = io.open(filepath, "rb")
  local fileData = ''
  if not f then
    log('E', 'unable to open texture file: ' .. tostring(filepath))
    return nil
  end

  fileData = f:read("*all")
  f:close()
  local fileSize = string.len(fileData)
  local bufferIDTexture = _addBuffer(gltfRoot, fileData, fileSize, 'texture')
  local bufferViewID = _addBufferView(gltfRoot, bufferIDTexture, 0, fileSize, filepath)
  local dir, filename, ext = path.splitWithoutExt(filepath)
  if filename:endswith(".dds") then filename = filename:sub(1, -5) end

  local image = {
    -- uri = filepath, -- replaced by extra below
    bufferView = bufferViewID,
    mimeType = mimeType,
    name = filename,
    extras = {
      bngFilePath = filepathIn
    }
  }

  table.insert(gltfRoot.images, image)
  local imageId = #gltfRoot.images - 1
  table.insert(gltfRoot.textures, {source = imageId})

  --dump(filepath, filepathIn, bufferIDTexture, bufferViewID, image, imageId)

  savedImages[filepathIn] = {index = imageId}

  return savedImages[filepathIn]
end

local function _convertType(value, fieldInfo)
  if fieldInfo.type == "filename" or fieldInfo.type == "char" then
    return value
  elseif fieldInfo.type == "float" then
    local res = tonumber(value)
    if res then
      return res
    else
      log("E", "could not convert "..dumps(value)" to "..dumps(fieldInfo.type))
      return value
    end
  elseif fieldInfo.type == "bool" then
    local res = tonumber(value)
    if res then
      return (res == 1 and true or false)
    else
      log("E", "could not convert "..dumps(value)" to "..dumps(fieldInfo.type))
      return value
    end
  elseif fieldInfo.type == "Point3F" then
    return vec3():fromString(value):toTable()
  else
    log("W", "unkwnon field type "..dumps(fieldInfo.type).."\n"..dumps(fieldInfo))
    return value
  end
end

local function _getMaterialStages(materialObj, field, maxLayers)
  local stages = {}
  local info = materialObj:getFieldInfo(field, i)
  if not maxLayers then maxLayers=3 end
  -- dump(info)
  for i=0,maxLayers-1 do
    local tmp = materialObj:getField(field, i)
    if tmp ~= "" then
      --stages[i] = tmp --dictionary
      table.insert(stages,_convertType(tmp, info)) --array
    else
      table.insert(stages,"")
    end
  end
  if #stages == 0 then return nil end
  return stages
end

local function _exportMaterial(gltfCurrentMaterial, materialObj)
  gltfCurrentMaterial.version = tonumber(materialObj:getField('version', 0))

  if gltfCurrentMaterial.version == 1 then
    gltfCurrentMaterial.colorMap = _getMaterialStages(materialObj, "colorMap")
    gltfCurrentMaterial.normalMap = _getMaterialStages(materialObj, "normalMap")
    gltfCurrentMaterial.pixelSpecular = _getMaterialStages(materialObj, "pixelSpecular")
    gltfCurrentMaterial.specularMap = _getMaterialStages(materialObj, "specularMap")
    gltfCurrentMaterial.specularPower = _getMaterialStages(materialObj, "specularPower")
    gltfCurrentMaterial.useAnisotropic = _getMaterialStages(materialObj, "useAnisotropic")
    gltfCurrentMaterial.translucent = materialObj:getField('translucent', 0)
    gltfCurrentMaterial.translucentBlendOp = materialObj:getField('translucentBlendOp', 0)
    gltfCurrentMaterial.instanceDiffuse = _getMaterialStages(materialObj, "instanceDiffuse", gltfCurrentMaterial.activeLayers)
    if tableContains(gltfCurrentMaterial.instanceDiffuse, true) then
      local veh = be:getPlayerVehicle(0)
      gltfCurrentMaterial.instanceColor = {veh.color.x, veh.color.y, veh.color.z, veh.color.w}
      gltfCurrentMaterial.instanceColorPalette0 = {veh.colorPalette0.x, veh.colorPalette0.y, veh.colorPalette0.z, veh.colorPalette0.w}
      gltfCurrentMaterial.instanceColorPalette1 = {veh.colorPalette1.x, veh.colorPalette1.y, veh.colorPalette1.z, veh.colorPalette1.w}
    end
  elseif gltfCurrentMaterial.version == 1.5 then
    gltfCurrentMaterial.activeLayers = materialObj.activeLayers
    gltfCurrentMaterial.translucent = materialObj:getField('translucent', 0)
    gltfCurrentMaterial.alphaRef = materialObj:getField('alphaRef', 0)
    gltfCurrentMaterial.doubleSided = materialObj:getField('doubleSided', 0)
    gltfCurrentMaterial.translucentBlendOp = materialObj:getField('translucentBlendOp', 0)
    gltfCurrentMaterial.ambientOcclusionMap = _getMaterialStages(materialObj, "ambientOcclusionMap", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.baseColorMap = _getMaterialStages(materialObj, "baseColorMap", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.diffuseMapUseUV = _getMaterialStages(materialObj, "diffuseMapUseUV", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.metallicFactor = _getMaterialStages(materialObj, "metallicFactor", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.metallicMap = _getMaterialStages(materialObj, "metallicMap", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.metallicMapUseUV = _getMaterialStages(materialObj, "metallicMapUseUV", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.normalMap = _getMaterialStages(materialObj, "normalMap", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.normalMapUseUV = _getMaterialStages(materialObj, "normalMapUseUV", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.roughnessMap = _getMaterialStages(materialObj, "roughnessMap", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.roughnessMapUV1 = _getMaterialStages(materialObj, "roughnessMapUV1", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.instanceDiffuse = _getMaterialStages(materialObj, "instanceDiffuse", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.useAnisotropic = _getMaterialStages(materialObj, "useAnisotropic", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.clearCoatFactor = _getMaterialStages(materialObj, "clearCoatFactor", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.clearCoatMap = _getMaterialStages(materialObj, "clearCoatMap", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.clearCoatRoughnessFactor = _getMaterialStages(materialObj, "clearCoatRoughnessFactor", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.clearCoatMapUseUV = _getMaterialStages(materialObj, "clearCoatMapUseUV", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.colorPaletteMap = _getMaterialStages(materialObj, "colorPaletteMap", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.colorPaletteMapUseUV = _getMaterialStages(materialObj, "colorPaletteMapUseUV", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.opacityMap = _getMaterialStages(materialObj, "opacityMap", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.opacityMapUseUV = _getMaterialStages(materialObj, "opacityMapUseUV", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.emissiveFactor = _getMaterialStages(materialObj, "emissiveFactor", gltfCurrentMaterial.activeLayers)
    gltfCurrentMaterial.emissiveMap = _getMaterialStages(materialObj, "emissiveMap", gltfCurrentMaterial.activeLayers)

    if tableContains(gltfCurrentMaterial.instanceDiffuse, true) or gltfCurrentMaterial.colorPaletteMap then
      local veh = be:getPlayerVehicle(0)
      gltfCurrentMaterial.instanceColor = {veh.color.x, veh.color.y, veh.color.z, veh.color.w}
      gltfCurrentMaterial.instanceColorPalette0 = {veh.colorPalette0.x, veh.colorPalette0.y, veh.colorPalette0.z, veh.colorPalette0.w}
      gltfCurrentMaterial.instanceColorPalette1 = {veh.colorPalette1.x, veh.colorPalette1.y, veh.colorPalette1.z, veh.colorPalette1.w}
    end
  else
    log("E","unkwnon material version "..dumps(gltfCurrentMaterial.version))

  end

  --log("D","export image indexes "..dumps(materialObj.name))
  for k,v in pairs(gltfCurrentMaterial) do
    if k:endswith("Map") then
      gltfCurrentMaterial[k.."Index"] = {}
      for klayer, layer in ipairs(v) do
        if layer and layer ~= "" then
          local tex = _findOrCreateTexture(gltfRoot,layer)
          if tex then
            gltfCurrentMaterial[k.."Index"][klayer] = tex.index
          end
        end
      end
      if #gltfCurrentMaterial[k.."Index"] ==0 then gltfCurrentMaterial[k.."Index"] = nil
      --else
        --log("D",k.."Index = "..dumps(gltfCurrentMaterial[k.."Index"]))
      end
    end
  end
end

local function processExport()
  local indexBufferID
  if not gltfRoot then
    gltfRoot = deepcopy(gltfRootTemplate)
    -- only add the index buffer at the beginning
    indexBufferID = _addIndexBuffer(gltfRoot, lastMeshInfo)
  end

  local vertexAccessorID = _addVec3Buffer(gltfRoot, lastMeshInfo.verticesCount, lastMeshInfo.vertices, "vertices")
  local attributes = {
    POSITION = vertexAccessorID
  }

  if M.exportNormals then
    local normalAccessorID = _addVec3Buffer(gltfRoot, lastMeshInfo.normalsCount, lastMeshInfo.normals, "normals")
    attributes.NORMAL = normalAccessorID
  end

  if M.exportTangents then
    local tangentAccessorID = _addTangentBuffer(gltfRoot, lastMeshInfo.tangentsCount, lastMeshInfo.tangents, "tangents")
    attributes.TANGENT = tangentAccessorID
  end

  if M.exportTexCoords then
    local texcoord1AccessorID = _addTexcoordBuffer(gltfRoot, lastMeshInfo.uv1Count, lastMeshInfo.uv1, "texcoord1")
    local texcoord2AccessorID = _addTexcoordBuffer(gltfRoot, lastMeshInfo.uv2Count, lastMeshInfo.uv2, "texcoord2")
    attributes.TEXCOORD_0 = texcoord1AccessorID
    attributes.TEXCOORD_1 = texcoord2AccessorID
  end

  if M.exportColors then
    local colorAccessorID = _addColorBuffer(gltfRoot, lastMeshInfo.vertColorsCount, lastMeshInfo.vertColors, "colors")
    attributes.COLOR_0 = colorAccessorID
  end

  -- now add the meshes
  local meshNodeMap = {}
  gltfRoot.scenes[1].nodes = {}
  for i = 0, lastMeshInfo.flexmeshesCount - 1 do
    -- log("I", "flexmesh="..dumps(i))
    local nodeID = _addMesh(gltfRoot, attributes, indexBufferID, lastMeshInfo, lastMeshInfo.flexmeshes[i])
    meshNodeMap[ffi.string(lastMeshInfo.flexmeshes[i].meshName)] = nodeID
  end
  for i = 0, lastMeshInfo.propmeshesCount - 1 do
    -- log("I", "propmesh="..dumps(i))
    local nodeID = _addMeshProp(gltfRoot, lastMeshInfo.propmeshes[i])
    meshNodeMap[ffi.string(lastMeshInfo.propmeshes[i].meshName)] = nodeID
  end

  -- map the parts to flexmeshes to allow sorting meshes according to part tree
  local v = core_vehicle_manager.getPlayerVehicleData()
  if not v then
    log('E', 'Unable to get vehicle data? Try reloading the vehicle and try again.')
    return
  end
  local partToFlexMesh = {}
  for _, flexMesh in pairs(v.vdata.flexbodies or {}) do
    local origin = flexMesh.partOrigin or ""
    if partToFlexMesh[origin] == nil then
      partToFlexMesh[origin] = {}
    end

    partToFlexMesh[origin][flexMesh.mesh] = true
  end
  for _, prop in pairs(v.vdata.props or {}) do
    -- print("prop["..dumps(_)..dumps(prop.mesh))
    if prop.mesh ~= "SPOTLIGHT" then
      local origin = prop.partOrigin or ""
      if partToFlexMesh[origin] == nil then
        partToFlexMesh[origin] = {}
      end
      partToFlexMesh[origin][prop.mesh] = true
      -- dump(prop)
    end
  end

  local veh = be:getPlayerVehicle(0)

  local partNodeBeams = nil
  if M.exportBeams then
    partNodeBeams = _getPartNodeBeams(veh, v)
  end

  local slotMap = jbeamIO.getAvailableParts(v.ioCtx)

  local rootNodes = _createPartTree(gltfRoot, v.chosenParts, slotMap, partToFlexMesh, meshNodeMap, partNodeBeams)

  gltfRoot.scenes[1].nodes = {}
  for nodeID, root in pairs(rootNodes) do
    if root then
      table.insert(gltfRoot.scenes[1].nodes, nodeID)
    end
  end

  if veh.getMaterialNames then
    local matNames = veh:getMaterialNames()
    for i,v in pairs(gltfRoot.materials) do
      gltfRoot.materials[i].name = matNames[v.extras.bngMaterialId+1]

      gltfRoot.materials[i].pbrMetallicRoughness = {}

      local mat = scenetree.findObject(matNames[v.extras.bngMaterialId+1])
      local matVer
      local matIsCar = false
      if not mat then
        log("E", dumps(matNames[v.extras.bngMaterialId+1]) .. " sceneobject was not found")
        goto continueMat
      end
      if mat:getClassName():lower() ~= "material" then
        log("E", dumps(matNames[v.extras.bngMaterialId+1]) .. " is not a Material. type="..dumps(mat:getClassName()))
        goto continueMat
      end

      matVer = mat:getField("version", 0 )
      if matVer == "1" then --float are string because TS
        matIsCar = mat:getField("normalMap", 2) ~= ""

        if mat:getField("normalMap", 0) ~= "" then
          gltfRoot.materials[i].normalTexture = _findOrCreateTexture(gltfRoot, mat:getField("normalMap", 0))
        end

        if matIsCar then
          if mat:getField("colorMap", 1) ~= "" then
            gltfRoot.materials[i].pbrMetallicRoughness.baseColorTexture = _findOrCreateTexture(gltfRoot, mat:getField("colorMap", 1))
          end
          if mat:getField("specularMap", 1) ~= "" then
            gltfRoot.materials[i].pbrMetallicRoughness.metallicRoughnessTexture = _findOrCreateTexture(gltfRoot, mat:getField("specularMap", 1))
          end


        else
          if mat:getField("colorMap", 0) ~= "" then
            gltfRoot.materials[i].pbrMetallicRoughness.baseColorTexture = _findOrCreateTexture(gltfRoot, mat:getField("colorMap", 0))
          end
          --gltfRoot.materials[i].pbrMetallicRoughness.baseColorFactor = vec4(mat:getField("colorMultiply", 0))
          if mat:getField("specularMap", 0) ~= "" then
            gltfRoot.materials[i].pbrMetallicRoughness.metallicRoughnessTexture = _findOrCreateTexture(gltfRoot, mat:getField("specularMap", 0))
          end

        end

      elseif matVer == "1.5" then --pbr like input

        if mat:getField("normalMap", 0) ~= "" then
          gltfRoot.materials[i].normalTexture = _findOrCreateTexture(gltfRoot, mat:getField("normalMap", 0))
        end
        if mat:getField("baseColorMap", 0) ~= "" then
          gltfRoot.materials[i].pbrMetallicRoughness.baseColorTexture = _findOrCreateTexture(gltfRoot, mat:getField("baseColorMap", 0))
        end
        if mat:getField("emissiveMap", 0) ~= "" then
          gltfRoot.materials[i].emissiveTexture = _findOrCreateTexture(gltfRoot, mat:getField("emissiveMap", 0))
        end
        if mat:getField("occlusionTexture", 0) ~= "" then
          gltfRoot.materials[i].ambientOcclusionMap = _findOrCreateTexture(gltfRoot, mat:getField("occlusionTexture", 0))
        end
        if mat:getField("metallicMap", 0) ~= "" then
          gltfRoot.materials[i].pbrMetallicRoughness.metallicRoughnessTexture = _findOrCreateTexture(gltfRoot, mat:getField("metallicMap", 0))
        end

      else
        log("E", "unknwon Material version "..dumps(matVer))
      end

      gltfRoot.materials[i].extras.bngMaterial = {}
      _exportMaterial(gltfRoot.materials[i].extras.bngMaterial, mat)

      ::continueMat::

      if tableSize(gltfRoot.materials[i].pbrMetallicRoughness) == 0 then
        gltfRoot.materials[i].pbrMetallicRoughness = nil
      end
    end
  else
    log("E", "getMaterialNames not available" )
  end


  for i, e in pairs(gltfRoot.scenes[1].nodes) do
    local node = gltfRoot.nodes[e + 1]
    local d = veh:getDirectionVector()
    local u = veh:getDirectionVectorUp()
    if node.extras == nil then
      node.extras = {}
    end
    node.extras[EXTENSION_DIRECTION] = {
      dir = {d.x, d.z, -d.y},
      up = {u.x, u.z, -u.y}
    }
  end

  if not continueRecording and #keyFrameTimes > 1 then
    -- ensure animation exists
    if not gltfRoot.animations then
      gltfRoot.animations = {
        {
          samplers = {
            {
              interpolation = 'LINEAR',
            }
          },
          channels = {
            {
              sampler = 0,
              target = {
                node = 0,
                path = 'weights',
              }
            }
          }
        }
      }
    end
    _addTimeBuffers(gltfRoot)
  end

  --enpty array in GLTF is not allowed
  if #gltfRoot.images == 0 then
    gltfRoot.images= nil
  end
  if #gltfRoot.textures == 0 then
    gltfRoot.textures= nil
  end

  exportHandler(gltfRoot)
  _ensureResourcedFreed()

  -- continue or stop?
  if continueRecording then
    _triggerExport()
    framesRecorded = framesRecorded + 1
    local frameTime = timer:stop() / 1000
    table.insert(keyFrameTimes, frameTime)
    print(' ** frame ' .. tostring(framesRecorded) .. ' = ' .. tostring(frameTime) ..' s')
  else
    exportHandler = nil
    gltfRoot = nil
    framesRecorded = 0
  end

  guihooks.trigger("ThreeDExported")
end

local function export(handler)
  if lastMeshInfo ~= nil then
    handler(nil)
    return
  end

  exportHandler = handler

  _triggerExport()
  if lastMeshInfo.dataIsReady then
    processExport()
  else
    log("E", "not ready")
  end
end

local function exportFile(filename)
  if not M.embedBuffers then
    local dir, filename, ext = path.splitWithoutExt(filename)
    if dir == nil then
      dir = ''
    end
    bufferPathPattern = dir .. filename .. '_buffer_%03d_%s.bin'
  end

  savedImages = {} -- clear from last run

  local jsonHandler = function(gltfRoot)
    jsonWriteFile(tostring(filename), gltfRoot, true, 20)
    bufferPathPattern = nil
    log("I", "GLTF json exported "..dumps(filename))
  end

  local glbHandler = function(gltfRoot)
    local f = io.open(tostring(filename), "wb")
    local bit = require "bit"
    local function sepbytes(num)
      return bit.band(num,0xFF), bit.band(bit.rshift(num,8),0xFF), bit.band(bit.rshift(num,16),0xFF), bit.band(bit.rshift(num,24),0xFF);
    end
    local function fourByteAlignPaddingSize(size)
      if size%4 == 0 then
        return 0
      else
        return 4-(size%4)
      end
    end
    local function getStartByteBufferView(index)
      local tmp = 0
      for k,v in ipairs(binaryBuffers) do
        if k-1 == index then
          return tmp
        end
        tmp = tmp + v.len
      end
      --log("E","broken? idx="..dumps(index).." tmp="..dumps(tmp))
      --now a feature to get total len of buffers
      return tmp
    end

    --GLB Header
    f:write(string.char(0x67,0x6C,0x54,0x46)) --Magic "glTF"
    f:write(string.char(sepbytes(2))) -- version 2

    --merge all buffers, GLB have only one binary section
    local totalBinBufSize = getStartByteBufferView(#binaryBuffers)
    for k,v in pairs(gltfRoot.bufferViews) do
      if v.buffer ~= 0 then
        gltfRoot.bufferViews[k].byteOffset = gltfRoot.bufferViews[k].byteOffset + getStartByteBufferView(v.buffer)
        gltfRoot.bufferViews[k].buffer = 0
      end
    end
    gltfRoot.buffers = {{ byteLength = totalBinBufSize }}


    local jsonContent = jsonEncode(gltfRoot)
    local fileLen = #jsonContent + 2*4 + fourByteAlignPaddingSize(#jsonContent) +3*4
    fileLen = fileLen + totalBinBufSize + 2*4 + fourByteAlignPaddingSize(totalBinBufSize) -- header[2] + 4 byte alignement

    --total fileSize Including all headers
    f:write( string.char(sepbytes(fileLen)) )

    ---- ALL CHUNKS NEED TO BE 4 BYTES ALIGNED IN GLB!!!
    --chunk[0] JSON
    -- log("I", "#jsonContent="..dumps(#jsonContent).."|"..dumps(string.len(jsonContent)).. " pad = "..dumps(fourByteAlignPaddingSize(#jsonContent)))
    f:write( string.char(sepbytes(#jsonContent + fourByteAlignPaddingSize(#jsonContent))) ) --size
    f:write(string.char(0x4A,0x53,0x4F,0x4E)) --type JSON
    f:write(jsonContent)
    if fourByteAlignPaddingSize(#jsonContent) > 0 then
      f:write(string.rep(" ", fourByteAlignPaddingSize(#jsonContent))) --JSON padding
    end

    -----
    --chunk[1] Binary data / buffers
    --dump(totalBinBufSize + fourByteAlignPaddingSize(totalBinBufSize))
    --dump(sepbytes(totalBinBufSize + fourByteAlignPaddingSize(totalBinBufSize)))
    f:write( string.char(sepbytes(totalBinBufSize + fourByteAlignPaddingSize(totalBinBufSize))) ) --size
    f:write(string.char(0x42,0x49,0x4E,0x00)) --type BIN\0
    for k,v in ipairs(binaryBuffers) do
      if type(v.data) == 'cdata' then
        -- ffi buffer
        f:write(ffi.string(v.data, v.len))
      elseif type(v.data) == 'string' then
        -- normal lua buffer
        f:write(v.data)
      else
        log('E', '', 'unknown buffer type: ' .. type(v.data))
      end
    end
    if fourByteAlignPaddingSize(totalBinBufSize) > 0 then
      f:write(string.rep(string.char(0), fourByteAlignPaddingSize(totalBinBufSize))) --BIN padding
    end
    binaryBuffers={}

    log("I", "GLTF binary exported "..dumps(filename))
  end

  if M.gltfBinaryFormat then
    export(glbHandler)
  else
    export(jsonHandler)
  end
  guihooks.message("GLTF Vehicle exported "..dumps(filename), 5, "GLTFexport")
end

local function startRecording(filename)
  exportFile(filename)
  continueRecording = true
end

local function stopRecording()
  continueRecording = false
end

local function updateGFX(dt)
  if lastMeshInfo and lastMeshInfo.dataIsReady then
    processExport()
  end
end

local function suggestFilename()
  local playerVehicle = be:getPlayerVehicle(0)
  if not playerVehicle then
    return ''
  end

  local fn
  for i = 1, 100 do
    fn = playerVehicle:getPath() .. 'export_' .. string.format('%03d', i)
    if M.gltfBinaryFormat then
      fn = fn .. '.glb'
    else
      fn = fn .. '.gltf'
    end
    if not FS:fileExists(fn) then
      break
    end
  end
  return fn
end

local function getGeInfo()
  local setup = {}
  setup.gltfBinaryFormat = M.gltfBinaryFormat
  setup.vulkan = Engine.getVulkanEnabled()
  if setup.vulkan == false then --double check because of command argument
    for k,adapter in pairs(GFXInit.getAdapters()) do
      if adapter.gfx == "VK" then
        setup.vulkan = true
        break
      end
    end
  end
  return setup
end

-- public interface
M.embedBuffers = true
M.gltfBinaryFormat = true
M.exportNormals = true
M.exportTangents = false
M.exportTexCoords = false
M.exportColors = false
M.exportBeams = true

M.updateGFX = updateGFX

M.export = export
M.exportFile = exportFile
M.startRecording = startRecording
M.stopRecording = stopRecording

-- for the UI
M.suggestFilename = suggestFilename
M.getGeInfo = getGeInfo

return M
