-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_roadUtils'
local roadDecorations = extensions.editor_roadDecorations

local materials = {}
local materialNames = {}
local roadTemplateFiles = {}

local roadResolutionMetres = 2


local function randomizeDecoration(decoID, factor)
  local decoGroup = scenetree.findObjectById(decoID)

  for i=0, decoGroup:size()-1 do
    local decoObjectID = decoGroup:at(i):getID()
    local decoObject = scenetree.findObjectById(decoObjectID)
    local oldPos = decoObject:getPosition()
    math.randomseed(oldPos.x + oldPos.y + oldPos.z)

    -- Randomize Position
    local newPos = oldPos
    newPos.x = newPos.x + (math.random() - 0.5) * factor
    newPos.y = newPos.y + (math.random() - 0.5) * factor
    newPos.z = core_terrain.getTerrainHeight(newPos)

    -- Randomize Rotation
    local rotation
    if factor ~= 0 then
      rotation = quatFromEuler(0, 0, math.random() * math.pi)
    else
      rotation = decoObject:getRotation()
    end
    decoObject:setPosRot(newPos.x, newPos.y, newPos.z, rotation.x, rotation.y, rotation.z, rotation.w)
  end
end


local function reloadDecorations(road)
  if not editor.getPreference("roadTemplates.general.loadTemplates") then return end
  if road:getField("isChildRoad", "") == "true" then return end

  local filename = road:getField("template", "")
  if filename == "" then return end
  local template = jsonReadFile(filename)

  -- Delete old decorations
  local decorationIDs = road:getField("decorationIDs", "")
  for decoID in string.gmatch(decorationIDs, "%d+") do
    local object = scenetree.findObjectById(tonumber(decoID))
    if object then
      object:deleteObject()
    end
  end

  if road:getField("useTemplate", "") ~= "true" or not template then return end

  -- Create the decorations
  local decorationIDsString = ""
  if template.decorations then
    for index, decorationSettings in ipairs(template.decorations) do
      local decoID = roadDecorations.decorateProps(road:getID(), decorationSettings.shapeName, tonumber(decorationSettings.distance),
                                                  tonumber(decorationSettings.period), quatFromEuler(0,0,(tonumber(decorationSettings.rotation)/360) * 2*math.pi),
                                                  tonumber(decorationSettings.zOff), decorationSettings.align == "true")
      decorationIDsString = decorationIDsString .. tostring(decoID) .. " "
      randomizeDecoration(decoID, tonumber(decorationSettings.randomFactor))
    end
  end
  road:setDynDataFieldbyName("decorationIDs", 0, decorationIDsString)
end


local function getRoadWidth(road, metres)
  local spline = editor.getAllSplines()[road:getID()]
  local posData = roadDecorations.findOffsetPoint(spline, metres, 0, false)
  if not posData then return nil end

  -- Interpolate width of this edge and the next one
  local roadWidthBefore = (road:getLeftEdgePosition(posData["edgeIdx"]) - road:getRightEdgePosition(posData["edgeIdx"])):length()
  local roadWidthAfter = (road:getLeftEdgePosition(posData["edgeIdx"] + 1) - road:getRightEdgePosition(posData["edgeIdx"] + 1)):length()

  local edgePosBefore = road:getMiddleEdgePosition(posData["edgeIdx"])
  local edgePosAfter = road:getMiddleEdgePosition(posData["edgeIdx"] + 1)

  local distBefore = edgePosBefore:distance(posData.point)
  local distAfter = edgePosAfter:distance(posData.point)
  local wholeDistance = distBefore + distAfter
  local interpolationFactor = distBefore / wholeDistance
  return (1-interpolationFactor) * roadWidthBefore + interpolationFactor * roadWidthAfter
end


local function reloadDecals(road, template)
  if not editor.getPreference("roadTemplates.general.loadTemplates") then return end
  local decalIDsString = ""

  -- Delete old decals
  local decalIDs = road:getField("decalIDs", "")
  for decalID in string.gmatch(decalIDs, "%d+") do
    editor.deleteRoad(tonumber(decalID))
  end

  if road:getField("useTemplate", "") ~= "true" then return end

  if not template then
    local filename = road:getField("template", "")
    template = jsonReadFile(filename)
  end

  if not template then return end

  -- Create the array of points
  local points = editor.getAllSplines()[road:getID()]

  local seed = (points[1].x * 100 + points[1].y * 10)^2
  math.randomseed(seed)

  -- Create Decals
  if template.decals then
    for index, decalSettings in ipairs(template.decals) do
      local minDecalLength = decalSettings.dynamicFields.minLength
      local maxDecalLength = decalSettings.dynamicFields.maxLength
      local minDecalWidth = decalSettings.dynamicFields.minWidth
      local maxDecalWidth = decalSettings.dynamicFields.maxWidth
      local maxHorizOffset = decalSettings.dynamicFields.maxHorizOffset
      local probability = decalSettings.dynamicFields.probability

      local decalNodes = {}
      local partOfDecal
      local actualDecalLength
      local decalWidth
      local relativeHorizPos

      local metres = 0
      while true do
        if not partOfDecal then
          partOfDecal = math.random() < tonumber(probability)
          actualDecalLength = math.random(minDecalLength,maxDecalLength)
          decalWidth = math.random() * (maxDecalWidth - minDecalWidth) + minDecalWidth
          relativeHorizPos = math.random() * 2 * maxHorizOffset - maxHorizOffset
        end

        if partOfDecal then
          local roadWidth = getRoadWidth(road, metres)
          if not roadWidth then break end
          local posData = roadDecorations.findOffsetPoint(points, metres, relativeHorizPos * roadWidth/2, false)
          if not posData then break end
          local nodePos = posData["point"]
          table.insert(decalNodes, {pos = nodePos, width = decalWidth})

          if table.getn(decalNodes) >= actualDecalLength + 1 then
            local decalID = editor.createRoad(decalNodes, decalSettings)
            editor.updateRoadVertices(scenetree.findObjectById(decalID))
            editor.setDynamicFieldValue(decalID, "isDecal", "true", false)
            decalIDsString = decalIDsString .. tostring(decalID) .. " "
            decalNodes = {}
            partOfDecal = false
          end
        end
        metres = metres + roadResolutionMetres
      end
    end
  end
  road:setDynDataFieldbyName("decalIDs", 0, decalIDsString)
end


local function updateChildRoads(road)
  if not editor.getPreference("roadTemplates.general.loadTemplates") then return end
  local filename = road:getField("template", "")
  if filename == "" then return end

  local middlePoints = editor.getAllSplines()[road:getID()]

  -- Delete child roads
  local childIDs = road:getField("childRoads", "")
  for childID in string.gmatch(childIDs, "%d+") do
    editor.deleteRoad(tonumber(childID))
  end

  if road:getField("useTemplate", "") ~= "true" then return end

  local template = jsonReadFile(filename)
  if not template then return end

  -- Create the child roads
  local childIDsString = ""
  for index, childRoadSettings in ipairs(template.roads) do
    if index == 1 then
      editor.pasteFields(childRoadSettings, road:getID())
    else
      local horizPosRelative = tonumber(childRoadSettings.dynamicFields.horizPosRelative)
      local metres = 0
      local pointIndex = 0
      local nodes = {}

      while true do

        -- Find the width of the road
        local roadWidth = getRoadWidth(road, metres)
        if not roadWidth then break end

        local width = tonumber(childRoadSettings.dynamicFields.width)
        if childRoadSettings.dynamicFields.isWidthRelative == "true" then
          width = roadWidth * width
        end

        local posData = roadDecorations.findOffsetPoint(middlePoints, metres, horizPosRelative * roadWidth/2, false)
        local nodePos = posData["point"]

        table.insert(nodes, {pos = nodePos, width = width})
        metres = metres + roadResolutionMetres
        pointIndex = pointIndex + 1
      end

      -- Create child road
      local childRoadID = editor.createRoad(nodes, childRoadSettings)
      childIDsString = childIDsString .. tostring(childRoadID) .. " "
      editor.setDynamicFieldValue(childRoadID, "isChildRoad", "true", false)

      local childRoad = scenetree.findObjectById(childRoadID)
      childRoad:setField('canSave', 0, "0")
      editor.updateRoadVertices(childRoad)
    end
  end
  editor.setDynamicFieldValue(road:getID(), "childRoads", childIDsString, false)
end


local function reloadTemplates()
  if not editor.getPreference("roadTemplates.general.loadTemplates") then return end

  if not editor.getLevelName() then return end
  roadTemplateFiles = FS:findFiles("levels/" .. editor.getLevelName() .. "/roadtemplates","*.road.json", 0, true, true)

  -- Update materials from templates
  materials = {}
  materialNames = {}
  local i = 1

  for k,filename in pairs(roadTemplateFiles) do
    local jsonData = jsonReadFile(filename)
    local matName = jsonData.roads[1].fields.Material
    local mat = scenetree.findObject(matName)
    if mat then
      -- TODO Use colorMap here?
      materials[i] = editor.texObj(mat:getField("colorMap", ""))
      materialNames[i] = matName
    else
      materials[i] = editor.texObj("/core/art/warnMat.dds")
      materialNames[i] = matName
    end
    i = i + 1
  end

  -- Apply templates to roads. Delete old child roads. Create new ones.
  local allRoadsCopy = shallowcopy(editor.getAllRoads())
  for roadID, _ in pairs(allRoadsCopy) do
    local road = scenetree.findObjectById(roadID)

    if not road then
      -- If road is nil, this road already got removed
    else
      local filename = road:getField("template", "")
      if filename and filename ~= "" then
        local template = jsonReadFile(filename)

        if template then
          updateChildRoads(road)
          reloadDecorations(road)
          reloadDecals(road, template)
        end
      end
    end
  end
  be:reloadCollision()
end

local function getMaterials()
  return materials
end

local function getMaterialNames()
  return materialNames
end

local function getRoadTemplateFiles()
  return roadTemplateFiles
end

M.onEditorInitialized = nil
M.updateChildRoads = updateChildRoads
M.reloadTemplates = reloadTemplates
M.getMaterials = getMaterials
M.getMaterialNames = getMaterialNames
M.getRoadTemplateFiles = getRoadTemplateFiles
M.reloadDecorations = reloadDecorations
M.reloadDecals = reloadDecals

return M