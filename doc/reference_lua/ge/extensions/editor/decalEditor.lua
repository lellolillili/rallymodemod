-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_decalEditor'
local actionMapName = "DecalEditor"
local editModeName = "Edit Decal"
local toolWindowName = "decalEditor"
local PI = 3.14159265358979323846
local roadRiverGui = extensions.editor_roadRiverGui
local im = ui_imgui
local minFloatValue = -1000000000
local maxFloatValue = 1000000000

local currentSelectionDuplicated = false

local selectedInstances = {}
local selectedTemplate

local originalSizes
local originalNormals
local originalTangents
local originalPositions
local originalGizmoPos

local hiddenTemplates = {"DummyDecal", "tireTrackDecal"}

local function displayMaterialPreview(material)
  local fileName = material:getField('diffuseMap', 0) -- This sometimes contains the path and sometimes not, so we have to check
  local actualFilenameWithPath = fileName

  -- Check if it exists with the other file ending
  local _, _, ext = path.split(fileName)
  local fileNameNoExt = string.sub(fileName, 1, -(ext:len() + 1))
  if not FS:fileExists(fileNameNoExt .. "png") and not FS:fileExists(fileNameNoExt .. "dds") then
    -- We have to create the correct path ourselves
    local materialFilename = material:getFilename()
    local folderPath = string.match(materialFilename, "(.*/)")
    actualFilenameWithPath = folderPath .. fileName
  end

  local image = editor.texObj(actualFilenameWithPath)
  if image.size.y > 0 and image.size.x > 0 then
    im.Image(
      image.texId,
      im.ImVec2(200, image.size.y / (image.size.x / 200)),
      im.ImVec2Zero,
      im.ImVec2One,
      im.ImColorByRGB(255,255,255,255).Value,
      im.ImColorByRGB(255,255,255,255).Value
    )
  end
end

local cubePoints =
{
  vec3(-0.5, -0.5, -0.5), vec3(-0.5, -0.5, 0.5), vec3(-0.5, 0.5, -0.5), vec3(-0.5, 0.5, 0.5),
  vec3(0.5, -0.5, -0.5), vec3(0.5, -0.5, 0.5), vec3(0.5, 0.5, -0.5), vec3(0.5, 0.5, 0.5)
}

local function updateGizmoPos()
  local firstInstance
  local averagePos = vec3(0,0,0)

  for index, instance in pairs(selectedInstances) do
    if not firstInstance then firstInstance = instance end
    averagePos = averagePos + instance.position
  end
  averagePos.x = averagePos.x / tableSize(selectedInstances)
  averagePos.y = averagePos.y / tableSize(selectedInstances)
  averagePos.z = averagePos.z / tableSize(selectedInstances)

  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local and tableSize(selectedInstances) == 1 then
    editor.setAxisGizmoTransform(firstInstance:getWorldMatrix())
  else
    -- Set gizmo to instance position
    local gizmoHelperTransform = MatrixF(true)
    gizmoHelperTransform:setPosition(averagePos)
    editor.setAxisGizmoTransform(gizmoHelperTransform)
  end
end

local function onEditorAxisGizmoAligmentChanged()
  if (not tableIsEmpty(selectedInstances)) and editor.editMode and (editor.editMode.displayName == editor.editModes.decalEditMode.displayName) then
    updateGizmoPos()
  end
end

local function drawSelectionBBox(transMatrix, color)
  -- 8 corner points of the box
  for i = 1, 8 do
    -- 3 lines per corner point
    for j = 1, 3 do
      local startPt = vec3(cubePoints[i].x, cubePoints[i].y, cubePoints[i].z);
      local endPt = vec3(startPt.x, startPt.y, startPt.z);
      if j == 1 then
        endPt.x = endPt.x * 0.8
      end
      if j == 2 then
        endPt.y = endPt.y * 0.8
      end
      if j == 3 then
        endPt.z = endPt.z * 0.8
      end
      startPt = transMatrix:mulP3F(startPt)
      endPt = transMatrix:mulP3F(endPt)
      debugDrawer:drawLine(startPt, endPt, color)
    end
  end
end

local function drawSelectedInstanceBBox(inst, color)
  -- if this SimObject is not a visual sceneobject with a transform, then ignore it
  local transMatrix = inst:getWorldMatrix()
  local bBox = inst:getWorldBox()
  local boxScale = bBox:getExtents()
  local boxCenter = bBox:getCenter()

  transMatrix:scale(boxScale)
  transMatrix:setPosition(boxCenter)
  drawSelectionBBox(transMatrix, color)
end

local function getTemplateById(id)
  for index=0, editor.getDecalTemplates():size()-1 do
    local template = editor.getDecalTemplates():at(index)
    if template:getID() == id then
      return template
    end
  end
end

local function isSelected(instance)
  if not instance then
    return false
  end
  return selectedInstances[instance.id]
end

local function selectSingleInstance(instance)
  selectedInstances = {}
  if instance then
    selectedInstances[instance.id] = instance
  end
  updateGizmoPos()
end

local function addToSelection(instance)
  if instance then
    selectedInstances[instance.id] = instance
    updateGizmoPos()
  end
end

local function removeFromSelection(instance)
  selectedInstances[instance.id] = nil
  updateGizmoPos()
end

local function clearTemplateSelection()
  selectedTemplate = nil
  editor.clearObjectSelection()
end

-- Create template
local function createTemplateActionUndo(actionData)
  local template = scenetree.findObjectById(actionData.id)
  if selectedTemplate and selectedTemplate:getID() == template:getID() then
    clearTemplateSelection()
  end
  editor.deleteDecalTemplate(template)
end

local function createTemplateActionRedo(actionData)
  if actionData.id then
    SimObject.setForcedId(actionData.id)
  end
  actionData.id = editor.createDecalTemplate()
  if actionData.fields then
    editor.pasteFields(actionData.fields, actionData.id)
    editor.setFieldValue(actionData.id, "name", actionData.name)
  else
    actionData.fields = editor.copyFields(actionData.id)
    actionData.name = editor.getFieldValue(actionData.id, "name")
  end
end

-- Delete template
local function deleteTemplateActionUndo(actionData)
  SimObject.setForcedId(actionData.id)
  editor.createDecalTemplate()
  editor.pasteFields(actionData.fields, actionData.id)
  editor.setFieldValue(actionData.id, "name", actionData.name)
  local template = scenetree.findObjectById(actionData.id)

  for _,instanceData in ipairs(actionData.instancesData) do
    local instance = editor.addDecalInstanceWithTanForceId(instanceData.position, instanceData.normal,
                          instanceData.tangent, template, instanceData.size, instanceData.textureRectIdx, 3, 1, instanceData.id)
  end
end

local function deleteTemplateActionRedo(actionData)
  local template = scenetree.findObjectById(actionData.id)

  if selectedTemplate and selectedTemplate:getID() == template:getID() then
    clearTemplateSelection()
  end
  editor.deleteDecalTemplate(template)
end

-- Clear selection
local function clearSelectionActionUndo(actionData)
  selectedInstances = deepcopy(actionData.oldSelection)
  updateGizmoPos()
end

local function clearSelectionActionRedo(actionData)
  selectSingleInstance()
end

-- Add instance to Selection
local function addInstToSelectionActionUndo(actionData)
  removeFromSelection(actionData.instance)
end

local function addInstToSelectionActionRedo(actionData)
  addToSelection(actionData.instance)
end

-- Select single instance
local function selectSingleInstanceActionUndo(actionData)
  selectedInstances = deepcopy(actionData.oldSelection)
  updateGizmoPos()
end

local function selectSingleInstanceActionRedo(actionData)
  selectSingleInstance(actionData.instance)
end

-- Remove instance from Selection
local function removeInstFromSelectionActionUndo(actionData)
  addToSelection(actionData.instance)
end

local function removeInstFromSelectionActionRedo(actionData)
  removeFromSelection(actionData.instance)
end

-- Position instance
local function positionInstancesActionUndo(actionData)
  for id, oldPosition in pairs(actionData.oldPositions) do
    local instance = editor.getDecalInstance(id)
    instance.position = oldPosition
    editor.notifyDecalModified(instance)
  end
  updateGizmoPos()
end

local function positionInstancesActionRedo(actionData)
  for id, newPosition in pairs(actionData.newPositions) do
    local instance = editor.getDecalInstance(id)
    instance.position = newPosition
    editor.notifyDecalModified(instance)
  end
  updateGizmoPos()
end

-- Rotate instance
local function rotateInstancesActionUndo(actionData)
  for id, _ in pairs(actionData.oldTangents) do
    local instance = editor.getDecalInstance(id)
    instance.tangent = actionData.oldTangents[id]
    instance.normal = actionData.oldNormals[id]
    instance.position = actionData.oldPositions[id]
    editor.notifyDecalModified(instance)
  end
  updateGizmoPos()
end

local function rotateInstancesActionRedo(actionData)
  for id, _ in pairs(actionData.newTangents) do
    local instance = editor.getDecalInstance(id)
    instance.tangent = actionData.newTangents[id]
    instance.normal = actionData.newNormals[id]
    instance.position = actionData.newPositions[id]
    editor.notifyDecalModified(instance)
  end
  updateGizmoPos()
end

-- Change instance size
local function changeInstancesSizeActionUndo(actionData)
  for id, _ in pairs(actionData.oldSizes) do
    local instance = editor.getDecalInstance(id)
    instance.size = actionData.oldSizes[id]
    if actionData.oldPositions then
      instance.position = actionData.oldPositions[id]
    end
    editor.notifyDecalModified(instance)
  end
end

local function changeInstancesSizeActionRedo(actionData)
  for id, _ in pairs(actionData.newSizes) do
    local instance = editor.getDecalInstance(id)
    instance.size = actionData.newSizes[id]
    if actionData.newPositions then
      instance.position = actionData.newPositions[id]
    end
    editor.notifyDecalModified(instance)
  end
end

-- Delete instance
local function deleteInstanceActionUndo(actionData)
  selectedInstances = {}
  for _,instanceData in ipairs(actionData.instancesData) do
    local instance = editor.addDecalInstanceWithTanForceId(instanceData.position, instanceData.normal, instanceData.tangent, instanceData.template, instanceData.size, instanceData.textureRectIdx, 3, 1, instanceData.id)
    selectedInstances[instance.id] = instance
  end
  updateGizmoPos()
end

local function deleteInstanceActionRedo(actionData)
  for _,instanceData in ipairs(actionData.instancesData) do
    local instance = editor.getDecalInstance(instanceData.id)
    editor.deleteDecalInstance(instance)
  end
  selectSingleInstance()
  updateGizmoPos()
end

-- Create instance
local function createInstanceActionUndo(actionData)
  local instance = editor.getDecalInstance(actionData.instanceData.id)
  if isSelected(instance) then
    selectSingleInstance()
  end
  editor.deleteDecalInstance(instance)
  updateGizmoPos()
end

local function createInstanceActionRedo(actionData)
  local instance
  if actionData.instanceData.id then
    instance = editor.addDecalInstanceWithTanForceId(actionData.instanceData.position, actionData.instanceData.normal,
                            actionData.instanceData.tangent, actionData.instanceData.template, 1,
                            actionData.instanceData.textureRectIdx, 3, 1, actionData.instanceData.id)
  else
    instance = editor.addDecalInstance(actionData.instanceData.position, actionData.instanceData.normal,
                            0, actionData.instanceData.template, 1,
                            actionData.instanceData.textureRectIdx, 3, 1)
  end
  actionData.instanceData.id = instance.id
  actionData.instanceData.tangent = instance.tangent
  actionData.instanceData.textureRectIdx = instance.textureRectIdx
  selectSingleInstance(instance)
  updateGizmoPos()
end

-- Duplicate instances
local function duplicateInstancesActionUndo(actionData)
  for id, instanceData in pairs(actionData.instancesData) do
    local instance = editor.getDecalInstance(id)
    editor.deleteDecalInstance(instance)
  end
end

local function duplicateInstancesActionRedo(actionData)
  selectedInstances = {}
  for id, instanceData in pairs(actionData.instancesData) do
    local instance = editor.addDecalInstanceWithTanForceId(instanceData.position, instanceData.normal, instanceData.tangent, instanceData.template, instanceData.size, instanceData.textureRectIdx, 3, 1, instanceData.id)
    selectedInstances[instance.id] = instance
  end
end

local templateSelectionIndex = im.IntPtr(0)
local function displayTemplates()
  if not selectedTemplate then
    templateSelectionIndex = im.IntPtr(-1)
  end

  if editor.uiIconImageButton(editor.icons.add_circle, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
    editor.history:commitAction("CreateDecalTemplate", {}, createTemplateActionUndo, createTemplateActionRedo)
  end
  im.tooltip("Create Decal Template")
  im.SameLine()

  local disabled = false
  if not selectedTemplate then im.BeginDisabled() disabled = true end
  if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
    local instancesData = {}
    for index=0, editor.getDecalInstanceVecSize() - 1 do
      local inst = editor.getDecalInstance(index)
      if inst and (inst.template:getName() == selectedTemplate:getName()) then
        local instance = {position = inst.position, normal = inst.normal, tangent = inst.tangent,
                          size = inst.size / inst.template.size,
                          textureRectIdx = inst.textureRectIdx, id = inst.id}
        table.insert(instancesData, instance)
      end
    end
    editor.history:commitAction("DeleteDecalTemplate",
                {fields = editor.copyFields(selectedTemplate:getID()), id = selectedTemplate:getID(),
                name = editor.getFieldValue(selectedTemplate:getID(), "name"), instancesData = instancesData},
                deleteTemplateActionUndo, deleteTemplateActionRedo)
    selectedTemplate = nil
  end
  if disabled then im.EndDisabled() disabled = false end
  im.tooltip("Delete Template")
  im.SameLine()

  if not selectedTemplate or not editor.isDecalDirty(selectedTemplate) then im.BeginDisabled() disabled = true end
  if editor.uiIconImageButton(editor.icons.material_save_current, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
    editor.saveDecal(selectedTemplate)
  end
  if disabled then im.EndDisabled() disabled = false end
  im.tooltip("Save current Template")
  im.SameLine()

  if editor.uiIconImageButton(editor.icons.material_save_all, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
    editor.saveDecals()
  end
  im.tooltip("Save all Templates")

  if editor.hasDirtyDecalTemplates() then
    im.SameLine()
    im.TextColored(im.ImVec4(1, 0.3, 0, 1), "< Decal Templates not saved")
  end

  local templates = {}
  local names = {}
  for index=0, editor.getDecalTemplates():size()-1 do
    local template = editor.getDecalTemplates():at(index)
    local name = template:__tostring()
    if not tableContains(hiddenTemplates, name) then
      table.insert(templates, template)
      if editor.isDecalDirty(template) then
        name = name .. "*"
      end
      table.insert(names, name)
    end
  end

  local avail = im.GetContentRegionAvail()
  im.PushItemWidth(avail.x)
  if im.ListBox1("", templateSelectionIndex, im.ArrayCharPtrByTbl(names), table.getn(names), avail.y/21) then
    editor.selectObjectById(templates[templateSelectionIndex[0]+1]:getID())
    selectedTemplate = Sim.upcast(templates[templateSelectionIndex[0]+1])
    updateGizmoPos()
  end
end

local function clickedOnInstance(instance)
  local oldSelection = deepcopy(selectedInstances)
  if not instance then
    if not tableIsEmpty(selectedInstances) then
      editor.history:commitAction("ClearDecalSelection", {oldSelection = oldSelection}, clearSelectionActionUndo, clearSelectionActionRedo)
    end
    return
  end

  if editor.keyModifiers.ctrl then
    if isSelected(instance) then
      editor.history:commitAction("RemoveDecalInstFromSelection", {instance = instance}, removeInstFromSelectionActionUndo, removeInstFromSelectionActionRedo)
    else
      editor.history:commitAction("AddDecalInstToSelection", {instance = instance}, addInstToSelectionActionUndo, addInstToSelectionActionRedo)
    end
  else
    if not (isSelected(instance) and tableSize(selectedInstances) == 1) then
      editor.history:commitAction("SelectSingleInst", {instance = instance, oldSelection = oldSelection}, selectSingleInstanceActionUndo, selectSingleInstanceActionRedo)
    end
  end
end

local function degToRad(d)
  return (d * PI) / 180.0
end

local function radToDeg(r)
  return (r * 180.0) / PI;
end

local function onDeleteSelection()
  local instancesData = {}
  for id, selectedInstance in pairs(selectedInstances) do
    local instance = {position = selectedInstance.position, normal = selectedInstance.normal, tangent = selectedInstance.tangent,
                      template = deepcopy(selectedInstance.template), size = selectedInstance.size / selectedInstance.template.size,
                      textureRectIdx = selectedInstance.textureRectIdx, id = id}
    table.insert(instancesData, instance)
  end

  editor.history:commitAction("DeleteDecalInstance", {instancesData = instancesData}, deleteInstanceActionUndo, deleteInstanceActionRedo)
end

local setWidth = true
local settingPosition = false
local position = im.ArrayFloat(3)
local size = im.FloatPtr(0)
local originalPosition
local input4FloatValue = im.ArrayFloat(4)

local function displayInstances()
  local instances = {}

  for index=0, editor.getDecalInstanceVecSize()-1 do
    local inst = editor.getDecalInstance(index)
    if inst then
      if not instances[inst.template:__tostring()] then
        instances[inst.template:__tostring()] = {}
      end
      table.insert(instances[inst.template:__tostring()], inst)
    end
  end
  local templateNamesSorted = {}
  for templateName, templateInstances in pairs(instances) do
    table.insert(templateNamesSorted, templateName)
  end
  table.sort(templateNamesSorted)

  local disabled = false
  if tableIsEmpty(selectedInstances) then im.BeginDisabled() disabled = true end
  if editor.uiIconImageButton(editor.icons.delete, im.ImVec2(22 * im.uiscale[0], 22 * im.uiscale[0]), nil, nil, nil) then
    onDeleteSelection()
  end
  if disabled then im.EndDisabled() end
  im.tooltip("Delete Instance")

  im.BeginChild1("Instances", im.ImVec2(0,300), true)
  for _, templateName in ipairs(templateNamesSorted) do
    if im.TreeNode1(templateName) then
      for _, instance in ipairs(instances[templateName]) do
        local flags = bit.bor(im.TreeNodeFlags_Leaf, isSelected(instance) and im.TreeNodeFlags_Selected or 0)
        if im.TreeNodeEx1(instance.id .. " " .. templateName .. '##'.. instance.id, flags) then
          im.TreePop()
        end
        if im.IsItemClicked() then
          clickedOnInstance(instance)
        end
      end
      im.TreePop()
    end
  end
  im.EndChild()

  if tableSize(selectedInstances) == 1 then
    local selectedInstance
    for id, instance in pairs(selectedInstances) do
      selectedInstance = instance
      break
    end
    im.BeginChild1("Instance Properties", im.ImVec2(0,0), true)
    im.Text("Instance Properties")

    local label = selectedInstance.id .. " " .. selectedInstance.template:__tostring()
    local material = scenetree.findObject(selectedInstance.template.material)

    if material then
      displayMaterialPreview(material)
    end

    im.Columns(2)
    if setWidth then
      im.SetColumnWidth(0, 80)
      setWidth = false
    end
    im.Text("Instance")
    im.NextColumn()
    im.Text(label)
    im.NextColumn()
    im.Text("Position")
    im.NextColumn()

    if not settingPosition then
      position[0] = selectedInstance.position.x
      position[1] = selectedInstance.position.y
      position[2] = selectedInstance.position.z
    end

    local positionSliderEditEnded = im.BoolPtr(false)
    if editor.uiDragFloat3("##" .. "pos" .. label, position, 0.1, minFloatValue, maxFloatValue,
                          "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", 1, positionSliderEditEnded) then
      settingPosition = true
      if not originalPosition then
        originalPosition = vec3(position[0], position[1], position[2])
      end
    end

    if positionSliderEditEnded[0] then
      local oldPositions = {}
      local newPositions = {}
      oldPositions[selectedInstance.id] = originalPosition
      newPositions[selectedInstance.id] = vec3(position[0], position[1], position[2])
      editor.history:commitAction("PositionDecalInstances",
                  {oldPositions = oldPositions, newPositions = newPositions, id = selectedInstance.id},
                  positionInstancesActionUndo, positionInstancesActionRedo)
      originalPosition = nil
      settingPosition = false
    end

    im.NextColumn()
    im.Text("Rotation")
    local worldQuat = selectedInstance:getWorldMatrix():toQuatF()
    local euler = worldQuat:toEuler()

    input4FloatValue[0] = radToDeg(euler.x)
    input4FloatValue[1] = radToDeg(euler.y)
    input4FloatValue[2] = radToDeg(euler.z)

    im.NextColumn()
    if editor.uiInputFloat3("##DecalRotation", input4FloatValue, nil, im.InputTextFlags_EnterReturnsTrue, nil) then
      local decalRot = quatFromEuler(degToRad(input4FloatValue[0]), degToRad(input4FloatValue[1]), degToRad(input4FloatValue[2]))
      selectedInstance.normal = decalRot:__mul(vec3(0,0,1))
      selectedInstance.tangent = decalRot:__mul(vec3(1,0,0))
      editor.notifyDecalModified(selectedInstance)
      updateGizmoPos()
    end

    im.NextColumn()
    im.Text("Size")
    im.NextColumn()

    size = im.FloatPtr(selectedInstance.size)
    local originalSize = size[0]
    if editor.uiInputFloat("##" .. "size" .. label, size, 0.1, 1.0, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", nil) then
      local oldSizes = {}
      local newSizes = {}
      oldSizes[selectedInstance.id] = originalSize
      newSizes[selectedInstance.id] = size[0]
      editor.history:commitAction("ChangeDecalInstancesSize", {oldSizes = oldSizes, newSizes = newSizes}, changeInstancesSizeActionUndo, changeInstancesSizeActionRedo)
    end
    im.EndChild()
  end
end

local function onEditorInspectorHeaderGui(inspectorInfo)
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end

  if selectedTemplate and selectedTemplate.material then
    local material = scenetree.findObject(selectedTemplate.material)
    if material then
      displayMaterialPreview(material)
    end
  end
end

local function rotateAround(instance, euler, rotationPoint)
  local rot = quatFromEuler(euler.x, euler.y, euler.z)

  -- Rotate the decals
  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local and tableSize(selectedInstances) == 1 then
    local gizmoTransform = editor.getAxisGizmoTransform()
    local rotation = gizmoTransform:toQuatF()

    instance.normal = quat(rotation):__mul(vec3(0,0,1))
    instance.tangent = quat(rotation):__mul(vec3(1,0,0))
  else
    local gizmoRot = rot
    instance.normal = gizmoRot:__mul(vec3(originalNormals[instance.id]))
    instance.tangent = gizmoRot:__mul(vec3(originalTangents[instance.id]))
  end

  -- Rotate the positions
  local point = vec3(originalPositions[instance.id].x, originalPositions[instance.id].y, originalPositions[instance.id].z)
  point = point - rotationPoint
  point = rot * point
  point = point + rotationPoint
  instance.position = point
  editor.notifyDecalModified(instance)
end

local function gizmoBeginDrag()
  -- Reset scale
  originalGizmoPos = editor.getAxisGizmoTransform():getColumn(3)

  if editor.keyModifiers.shift then
    local copiedInstances = {}
    for id, instance in pairs(selectedInstances) do
      local copiedInstance = editor.addDecalInstanceWithTan(instance.position, instance.normal, instance.tangent, instance.template, 1, instance.textureRectIdx, 3, 1)
      copiedInstance.size = instance.size
      copiedInstances[copiedInstance.id] = copiedInstance
    end
    selectedInstances = copiedInstances
    currentSelectionDuplicated = true
  end

  originalSizes = {}
  originalNormals = {}
  originalTangents = {}
  originalPositions = {}
  for id, instance in pairs(selectedInstances) do
    originalSizes[id] = instance.size
    originalNormals[id] = instance.normal
    originalTangents[id] = instance.tangent
    originalPositions[id] = instance.position
  end
end

local function gizmoEndDrag()
  local newPositions = {}
  local newTangents = {}
  local newNormals = {}
  local newSizes = {}

  if currentSelectionDuplicated then
    local instancesData = {}
    for id, selectedInstance in pairs(selectedInstances) do
      local instance = {position = selectedInstance.position, normal = selectedInstance.normal, tangent = selectedInstance.tangent,
                        template = deepcopy(selectedInstance.template), size = selectedInstance.size / selectedInstance.template.size,
                        textureRectIdx = selectedInstance.textureRectIdx, id = id}
      instancesData[id] = instance
      editor.deleteDecalInstance(selectedInstance)
    end
    editor.history:commitAction("DuplicateDecalInstances",
                    {instancesData = instancesData}, duplicateInstancesActionUndo, duplicateInstancesActionRedo)
    currentSelectionDuplicated = false
  else
    for id, instance in pairs(selectedInstances) do
      newPositions[id] = instance.position
      newTangents[id] = instance.tangent
      newNormals[id] = instance.normal
      newSizes[id] = instance.size
    end
    if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
      editor.history:commitAction("PositionDecalInstances",
                    {oldPositions = originalPositions, newPositions = newPositions},
                    positionInstancesActionUndo, positionInstancesActionRedo, true)

    elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
      editor.history:commitAction("RotateDecalInstances",
                    {oldNormals = originalNormals, oldTangents = originalTangents, oldPositions = originalPositions, newNormals = newNormals,
                    newTangents = newTangents, newPositions = newPositions},
                    rotateInstancesActionUndo, rotateInstancesActionRedo, true)

    elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
      editor.history:commitAction("ChangeDecalInstancesSize",
                    {oldSizes = originalSizes, oldPositions = originalPositions, newSizes = newSizes, newPositions = newPositions},
                    changeInstancesSizeActionUndo, changeInstancesSizeActionRedo, true)
    end
  end

  originalSizes = nil
  originalNormals = nil
  originalTangents = nil
  originalPositions = nil
  originalGizmoPos = nil
  updateGizmoPos()
end

local function scalePoint(point, scale)
  return vec3(point.x * scale, point.y * scale, point.z * scale)
end

local function gizmoDragging()
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    for id, instance in pairs(selectedInstances) do
      instance.position = originalPositions[id] + (editor.getAxisGizmoTransform():getColumn(3) - originalGizmoPos)
      editor.notifyDecalModified(instance)
    end

  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    local euler = editor.getAxisGizmoTransform():toQuatF():toEuler()
    for id, instance in pairs(selectedInstances) do
      rotateAround(instance, euler, editor.getAxisGizmoTransform():getColumn(3))
    end

  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
    local scale = editor.getAxisGizmoScale()
    for id, instance in pairs(selectedInstances) do
      local avgScale = (scale.x + scale.y) * 0.5
      instance.size = (originalSizes[id] * avgScale)
      instance.position = originalGizmoPos + scalePoint((originalPositions[id] - originalGizmoPos), avgScale)
      editor.notifyDecalModified(instance)
    end
  end
end

local time = 0

local function onUpdate()
  local res = cameraMouseRayCast()
  if res and res.pos and not (im.IsAnyItemHovered() or im.IsWindowHovered(im.HoveredFlags_AnyWindow)) then
    local closestDecal = editor.getClosestDecal(res.pos)
    if closestDecal and not isSelected(closestDecal) then
      drawSelectedInstanceBBox(closestDecal, roadRiverGui.highlightColors.hover)
    end

    if im.IsMouseClicked(0) then
      if not editor.isAxisGizmoHovered() then
        if closestDecal then
          clickedOnInstance(closestDecal)
        else
          if selectedTemplate then
            local instanceData = {position = res.pos, normal = res.normal, tangent = 0, template = deepcopy(selectedTemplate)}
            editor.history:commitAction("CreateDecalInstance", {instanceData = instanceData}, createInstanceActionUndo, createInstanceActionRedo)
          end
        end
      end
    end
  end

  if not tableIsEmpty(selectedInstances) then
    time = time + editor.getDeltaTime()
    local factor = math.sin(time * 10) * 0.5 + 0.5
    local pulseColor = ColorF(roadRiverGui.highlightColors.selected.r * factor,
                              roadRiverGui.highlightColors.selected.g * factor,
                              roadRiverGui.highlightColors.selected.b * factor, 1)
    for _, instance in pairs(selectedInstances) do
      drawSelectedInstanceBBox(instance, pulseColor)
    end
    editor.updateAxisGizmo(gizmoBeginDrag, gizmoEndDrag, gizmoDragging)
    editor.drawAxisGizmo()
  end
end

local function onExtensionLoaded()
  log('D', logTag, "initialized")
end

local function onActivate()
  log('I', logTag, "onActivate")
  clearTemplateSelection()
  editor.showWindow(toolWindowName)
end

local function onDeactivate()
  log('I', logTag, "onDeactivate")
  editor.hideWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.editModes.decalEditMode =
  {
    displayName = editModeName,
    onActivate = onActivate,
    onDeactivate = onDeactivate,
    onUpdate = onUpdate,
    onDeleteSelection = onDeleteSelection,
    actionMap = actionMapName,
    icon = editor.icons.create_decal,
    iconTooltip = "Decal Editor",
    auxShortcuts = {},
    hideObjectIcons = true
  }
  editor.editModes.decalEditMode.auxShortcuts[bit.bor(editor.AuxControl_Ctrl, editor.AuxControl_LMB)] = "Multiselection"
  editor.editModes.decalEditMode.auxShortcuts["Shift + Drag Gizmo"] = "Duplicate decals"
  editor.registerWindow(toolWindowName, im.ImVec2(400,600))
end

local function onEditorBeforeSaveLevel()
  editor.saveDecals()
end

local function onEditorInspectorFieldChanged(selectedIds, fieldName, fieldValue, arrayIndex)
  for i = 1, #selectedIds do
    local template = scenetree.findObjectById(selectedIds[i])
    if template:getClassName() == "DecalData" then
      scenetree.decalPersistMan:setDirty(template, editor.getDecalDataFilePath())

      -- Update the decal instances
      for index=0, editor.getDecalInstanceVecSize() - 1 do
        local inst = editor.getDecalInstance(index)
        if inst and (inst.template:getName() == template:getName()) then
          editor.notifyDecalModified(inst)
        end
      end
    end
  end
  if editor.editMode and (editor.editMode.displayName == editor.editModes.decalEditMode.displayName) then
    updateGizmoPos()
  end
end

local function onEditorGui()
  if not editor.editMode or (editor.editMode.displayName ~= editModeName) then
    return
  end

  if editor.beginWindow(toolWindowName, "Decal Editor", nil, true) then
    if im.BeginTabBar("decal editor##") then
      if im.BeginTabItem("Templates") then
        displayTemplates()
        im.EndTabItem()
      end
      if im.BeginTabItem("Instances") then
        displayInstances()
        im.EndTabItem()
      end
      if im.IsItemClicked() then
        clearTemplateSelection()
      end
      im.EndTabBar()
    end

    editor.endWindow()
  end
end

M.onEditorInitialized = onEditorInitialized
M.onExtensionLoaded = onExtensionLoaded
M.onEditorBeforeSaveLevel = onEditorBeforeSaveLevel
M.onEditorInspectorHeaderGui = onEditorInspectorHeaderGui
M.onEditorInspectorFieldChanged = onEditorInspectorFieldChanged
M.onEditorAxisGizmoAligmentChanged = onEditorAxisGizmoAligmentChanged
M.onEditorGui = onEditorGui

return M