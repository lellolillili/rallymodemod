-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local editor
local templatesQueuedForDel = {}

local defaultFilepath = "art/decals/managedDecalData.json"

local function getDecalDataFilePath()
  local decalFileName = (path.split(getMissionFilename()) or '') .. defaultFilepath
  if decalFileName == defaultFilepath then
    log("E","createDecalTemplate", "Error while getting mission path, decal will be used/saved in "..dumps(decalFileName))
  end
  return decalFileName
end

local function createDecalTemplate()
  local name = Sim.getUniqueName("NewTemplate")
  local templates = Engine.Render.DecalMgr.getSet():getObjects()

  local template = createObject("DecalData")
  template:setField("Material", 0, "WarningMaterial")
  template:registerObject(name)
  template:setField("Name", 0, name)

  local decalFileName = getDecalDataFilePath()

  scenetree.decalPersistMan:setDirty(template, decalFileName )
  editor.setDirty()
  return template:getID()
end

local function deleteDecalTemplate(template)
  for index=0, editor.getDecalInstanceVecSize() - 1 do
    local inst = editor.getDecalInstance(index)
    if inst and (inst.template:getName() == template:getName()) then
      editor.deleteDecalInstance(inst)
    end
  end

  table.insert(templatesQueuedForDel, template)
  editor.getDecalTemplates():removeObject(template)
  editor.setDirty()
end

local function getDecalTemplates()
  return Engine.Render.DecalMgr.getSet()
end

local function hasDirtyDecalTemplates()
  return scenetree.decalPersistMan:hasDirty()
end

local function addDecalInstance(pos, normal, rotAroundNormal, template, decalScale, decalTexIndex, flags, initialAlpha)
  editor.setDirty()
  local inst = Engine.Render.DecalMgr.addDecal(pos, normal, rotAroundNormal, template, decalScale or 1, decalTexIndex or -1, flags or 0, initialAlpha or 1)
  editor.notifyDecalModified(inst)
  return inst
end

local function addDecalInstanceWithTan(pos, normal, tangent, template, decalScale, decalTexIndex, flags, initialAlpha)
  editor.setDirty()
  local inst = Engine.Render.DecalMgr.addDecalTangent(pos, normal, tangent, template, decalScale or 1, decalTexIndex or -1, flags or 0, initialAlpha or 1)
  editor.notifyDecalModified(inst)
  return inst
end

local function addDecalInstanceWithTanForceId(pos, normal, tangent, template, decalScale, decalTexIndex, flags, initialAlpha, index)
  editor.setDirty()
  local inst = Engine.Render.DecalMgr.addDecalTangentForceId(pos, normal, tangent, template, decalScale or 1, decalTexIndex or -1, flags or 0, initialAlpha or 1, index)
  editor.notifyDecalModified(inst)
  return inst
end

local function getDecalInstance(index)
  return Engine.Render.DecalMgr.getDecalInstance(index)
end

local function getDecalInstanceVecSize()
  return Engine.Render.DecalMgr.getDecalInstanceVecSize()
end

local function deleteDecalInstance(instance)
  Engine.Render.DecalMgr.removeDecal(instance)
  editor.setDirty()
end

local function getClosestDecal(pos)
  return Engine.Render.DecalMgr.getClosestDecal(pos)
end

local function notifyDecalModified(instance)
  editor.setDirty()
  return Engine.Render.DecalMgr.notifyDecalModified(instance)
end

local function isDecalDirty(decal)
  return scenetree.decalPersistMan:isDirty(decal)
end

local function saveDecal(template)
  scenetree.decalPersistMan:saveDirtyObject(template)
end

local function saveDecals()
  for _,template in ipairs(templatesQueuedForDel) do
    if template:getFileName() == getDecalDataFilePath() then
      scenetree.decalPersistMan:removeObjectFromFileLua(template)
    end
    editor.deleteObject(template:getID())
  end
  templatesQueuedForDel = {}

  scenetree.decalPersistMan:saveDirty()

  local decalFileName = (path.split(getMissionFilename()) or '') .. "main.decals.json"
  if decalFileName then
    Engine.Render.DecalMgr.saveDecals(decalFileName)
  end
end

local function initialize(editorInstance)
  if not scenetree.decalPersistMan then
    local persistenceMgr = PersistenceManager()
    persistenceMgr:registerObject('decalPersistMan')
  end

  editor = editorInstance
  editor.createDecalTemplate = createDecalTemplate
  editor.deleteDecalTemplate = deleteDecalTemplate
  editor.getDecalTemplates = getDecalTemplates
  editor.hasDirtyDecalTemplates = hasDirtyDecalTemplates
  editor.addDecalInstance = addDecalInstance
  editor.addDecalInstanceWithTan = addDecalInstanceWithTan
  editor.addDecalInstanceWithTanForceId = addDecalInstanceWithTanForceId
  editor.getDecalInstance = getDecalInstance
  editor.getDecalInstanceVecSize = getDecalInstanceVecSize
  editor.deleteDecalInstance = deleteDecalInstance
  editor.getClosestDecal = getClosestDecal
  editor.notifyDecalModified = notifyDecalModified
  editor.isDecalDirty = isDecalDirty
  editor.saveDecal = saveDecal
  editor.saveDecals = saveDecals
  editor.getDecalDataFilePath = getDecalDataFilePath
end

local M = {}
M.initialize = initialize

return M