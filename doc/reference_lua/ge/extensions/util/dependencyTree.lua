-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local folder = 'levels/gridmap'

-- contains all items relevant for the dependency checking
local entities = {}

-- little helper lib
local function recurseFindAttribute(n, className, attributeName)
  local res = {}
  if n.class == className then
    res[n[attributeName] ] = 1
  end
  if n.childs then
    for _, c in pairs(n.childs) do
      for ck, _ in pairs(recurseFindAttribute(c, className, attributeName)) do
          res[ck] = 1
      end
    end
  end
  return res
end

local function findFiles(pattern)
  return FS:findFiles(folder, pattern, -1, true, false)
end

local function add(type, category, value)
  if value then
    if not type[category] then type[category] = {} end
    table.insert(type[category], value)
  end
end

local function normalizeFiles(fileList, sourceFile)
  if not fileList then return end
  local dir, filename, ext = path.split(sourceFile)
  for k, fn in pairs(fileList) do
    local dir2, filename2, ext2 = path.split(fn)
    if dir2 == '' then
      fileList[k] = dir .. fn
    end
  end
end

local function removeFileExtensions(fileList, sourceFile)
  if not fileList then return end
  for k, fn in pairs(fileList) do
    local dir, filename, ext = path.split(fn)
    fileList[k] = fn:gsub('.' .. ext, '')
  end
end

local function processForestFile(forestDataFilename, sourceFile, entity)
  local rootNode = jsonReadFile(forestDataFilename)
  if not rootNode or not rootNode.instances then return end

  for k, _ in pairs(rootNode.instances) do
    add(entity.deps, 'simobject', k)
  end
end

local function processSimObject(n, sourceFile)
  local entity = { deps = {}, provides = {}}
  if n.name then
    -- if it has a name, it can be referenced by
    add(entity.provides, 'simobject', n.name)
  end
  if n.class == "BeamNGVehicle" then
    add(entity.deps, 'file', n.JBeam)
    add(entity.deps, 'file', n.partConfig)

  elseif n.class == "BasicClouds" then
    add(entity.deps, 'tex', n.texture)

  elseif n.class == "CloudLayer" then
    add(entity.deps, 'tex', n.texture)

  elseif n.class == "DecalRoad" then
    add(entity.deps, 'material', n.material)

  elseif n.class == "MeshRoad" then
    add(entity.deps, 'material', n.topMaterial)
    add(entity.deps, 'material', n.bottomMaterial)
    add(entity.deps, 'material', n.sideMaterial)

  elseif n.class == "River" then
    add(entity.deps, 'material', n.topMaterial)
    add(entity.deps, 'tex', n.rippleTex)
    add(entity.deps, 'tex', n.foamTex)
    add(entity.deps, 'tex', n.depthGradientTex)
    add(entity.deps, 'simobject', n.soundAmbience)

  elseif n.class == "WaterPlane" then
    add(entity.deps, 'tex', n.rippleTex)
    add(entity.deps, 'tex', n.foamTex)
    add(entity.deps, 'tex', n.depthGradientTex)
    add(entity.deps, 'simobject', n.soundAmbience)

  elseif n.class == "ScatterSky" then
    add(entity.deps, 'tex', n.colorizeGradientFile)
    add(entity.deps, 'tex', n.sunScalegradientFile)
    add(entity.deps, 'tex', n.ambientScaleGradientFile)
    add(entity.deps, 'tex', n.fogScaleGradientFile)
    add(entity.deps, 'material', n.moonMat)
    add(entity.deps, 'simobject', n.nightCubemap)

  elseif n.class == "SkyBox" then
    add(entity.deps, 'material', n.material)

  elseif n.class == "Sun" then
    add(entity.deps, 'material', n.coronaMaterial)

  elseif n.class == "Forest" then
    processForestFile(n.dataFile, sourceFile, entity)

  elseif n.class == "ForestBrush" then
    add(entity.deps, 'simobject', n.forestItemData)

  elseif n.class == "TSForestItemData" then
    add(entity.deps, 'shape', n.shapeFile)

  elseif n.class == "Material" then
    add(entity.provides, 'material', n.mapTo)
    for i = 1, 4 do
      add(entity.deps, 'tex', n.Stages[i].diffuseMap)
      add(entity.deps, 'tex', n.Stages[i].colorMap)
      add(entity.deps, 'tex', n.Stages[i].overlayMap)
      add(entity.deps, 'tex', n.Stages[i].opacityMap)
      add(entity.deps, 'tex', n.Stages[i].colorPaletteMap)
      add(entity.deps, 'tex', n.Stages[i].lightMap)
      add(entity.deps, 'tex', n.Stages[i].toneMap)
      add(entity.deps, 'tex', n.Stages[i].detailMap)
      add(entity.deps, 'tex', n.Stages[i].normalMap)
      add(entity.deps, 'tex', n.Stages[i].detailNormalMap)
      add(entity.deps, 'tex', n.Stages[i].specularMap)
      add(entity.deps, 'tex', n.Stages[i].annotationMap)
      add(entity.deps, 'tex', n.Stages[i].envMap)
      -- old stuff
      add(entity.deps, 'tex', n.Stages[i].baseTex)
      add(entity.deps, 'tex', n.Stages[i].detailTex)
      add(entity.deps, 'tex', n.Stages[i].overlayTex)
      add(entity.deps, 'tex', n.Stages[i].bumpTex)
      add(entity.deps, 'tex', n.Stages[i].envTex)
    end
    add(entity.deps, 'simobject', n.cubemap)

  -- TODO: SFX objects
  -- SFXEmitter
  elseif n.class == "SFXAmbience" then
    add(entity.deps, 'simobject', n.environment)
    add(entity.deps, 'simobject', n.soundTrack)

  elseif n.class == "SFXDescription" then
    add(entity.deps, 'simobject', n.environment)

  elseif n.class == "DecalData" then
    add(entity.deps, 'material', n.material)

  elseif n.class == "GroundCover" then
    add(entity.deps, 'material', n.material)
    add(entity.deps, 'shape', n.shapeFilename)
    add(entity.deps, 'SimObject', n.layer)

  elseif n.class == "ParticleData" then
    add(entity.deps, 'tex', n.animTexFrames)
    add(entity.deps, 'tex', n.textureName)
    add(entity.deps, 'tex', n.animTexName)

  elseif n.class == "ParticleEmitterData" then
    add(entity.deps, 'simobject', n.particles)
    add(entity.deps, 'tex', n.textureName)

  elseif n.class == "PrecipitationData" then
    add(entity.deps, 'simobject', n.soundProfile)
    add(entity.deps, 'tex', n.dropTexture)
    add(entity.deps, 'tex', n.dropShader)
    add(entity.deps, 'tex', n.splashTexture)
    add(entity.deps, 'tex', n.splashShader)

  elseif n.class == "ConvexShape" then
    add(entity.deps, 'material', n.material)

  elseif n.class == "GroundPlane" then
    add(entity.deps, 'material', n.material)

  elseif n.class == "LevelInfo" then
    add(entity.deps, 'simobject', n.globalEnviromentMap)
    -- soundAmbience

  elseif n.class == "TSStatic" then
    add(entity.deps, 'shape', n.shapeName)
  end

  -- normalize files
  normalizeFiles(entity.deps.file, sourceFile)
  normalizeFiles(entity.deps.shape, sourceFile)
  normalizeFiles(entity.deps.tex, sourceFile)
  removeFileExtensions(entity.deps.shape, sourceFile)
  removeFileExtensions(entity.deps.tex, sourceFile)

  if tableIsEmpty(entity.deps) then entity.deps = nil end
  if tableIsEmpty(entity.provides) then entity.provides = nil end

  if entity.deps or entity.provides then
    table.insert(entities, entity)
  end

  if n.childs then
    for _, c in pairs(n.childs) do
      processSimObject(c, sourceFile)
    end
  end
end

local function test()
  -- first: find levels
  local filenames = findFiles('*.level.json\t*.material.json\t*.datablock.json')
  for _, filename in pairs(filenames) do
    processSimObject(jsonReadFile(filename), filename)
  end

  local shapeInfoFiles = findFiles('*.meshes.json')

  for _, shapeInfoFn  in pairs(shapeInfoFiles) do
    local rootNode = jsonReadFile(shapeInfoFn)
    if rootNode and rootNode.materials and #rootNode.materials > 0 then
      local entity = { deps = { material = {}}, provides = { shape = shapeInfoFn:sub(1, -13) }}
      for _, m in pairs(rootNode.materials) do
        table.insert(entity.deps.material, m)
      end
      table.insert(entities, entity)
    end
  end

  --dump(entities)
  jsonWriteFile('dependencytree.json', entities, true)

end

M.test = test

return M