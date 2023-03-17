-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor

-- Creates a new material object with given params and writes it to disk.
-- param 'materialName'; type 'string';
-- param 'materialFilename'; type 'string';
-- param 'materialMapTo'; type 'number';
-- returns; type 'bool';
local function createMaterial(materialName, materialFilename, materialMapTo)
  -- Check if new materialName is empty or a material with the gievn name already exists.
  if #materialName == 0 then
    log('E', logTag, 'Material name must not be empty!')
    editor.showNotification("Material name must not be empty!")
    return false
  end

  -- Check if a material with the given name exists already
  if scenetree.findObject(materialName) then
    log('E', logTag, "A material with the given name '" .. materialName .. "' already exists!")
    return false
  end

  -- Check if directory exists.
  local directory,_,_ = path.split(materialFilename)
  if FS:directoryExists(directory) == false then
    log('E', logTag, "Given directory '" .. directory .."' does not exist!")
    editor.showNotification("Given directory '" .. directory .."' does not exist!")
    return false
  end

  if #materialMapTo == 0 then
    log('W', "", "No 'mapTo' value given. Using material name instead.")
    editor.showNotification("No 'mapTo' value given. Using material name instead.")
    materialMapTo = materialName
  end

  local mat = createObject('Material')
  mat:setFilename(materialFilename)
  mat:setField('name', 0, materialName)
  mat:setField('mapTo', 0, materialMapTo)
  mat.canSave = true
  mat:registerObject(materialName)
  scenetree.matLuaEd_PersistMan:setDirty(mat, '')
  scenetree.matLuaEd_PersistMan:saveDirty()
  return true
end

-- Sets a property of a material.
-- param 'material'; type 'class<Material>' || 'string';
-- param 'property'; type 'string';
-- param 'layer'; type 'number';
-- param 'value'; type 'string';
-- returns; type 'bool';
local function setMaterialProperty(material, property, layer, value)

  if type(material) == "string" then
    material = scenetree.findObject(material)
  end

  if material.___type == "class<Material>" then
    material:setField(property, layer, value)
    material:flush()
    material:reload()
    return true
  else
    log('E', "", "Given object is not a material.")
    return false
  end
end

local function initialize(editorInstance)
  if not scenetree.materialPersistMan then
    local persistenceMgr = PersistenceManager()
    persistenceMgr:registerObject('materialPersistMan')
  end

  editor = editorInstance
  editor.createMaterial = createMaterial
  editor.setMaterialProperty = setMaterialProperty
end

local M = {}
M.initialize = initialize

return M