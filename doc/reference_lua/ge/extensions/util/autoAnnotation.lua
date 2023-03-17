-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local _log = log
local function log(level, msg)
  _log(level, 'autoAnnotation', msg)
end

local visitors = {}

local shapeMatches = {}
shapeMatches['building'] = 'BUILDINGS'
shapeMatches['tree'] = 'NATURE'
shapeMatches['sidewalk'] = 'SIDEWALK'
shapeMatches['sign'] = 'TRAFFIC_SIGNS'
shapeMatches['tunnel'] = 'STREET'
shapeMatches['fence'] = 'BUILDINGS'
shapeMatches['fencing'] = 'BUILDINGS'
shapeMatches['road'] = 'ASPHALT'
shapeMatches['busstop'] = 'BUILDINGS'
shapeMatches['excavator'] = 'CAR'

local nameMatches = {}
nameMatches['grass'] = 'NATURE'
nameMatches['shrubs'] = 'NATURE'

local function setAnnotation(node, annotation)
  node:setField('annotation', 0, annotation)
  node:setField('mode', 0, 'Override')
  node:postApply()
end

local function fuzzyMatchTableKey(tab, key)
  key = string.lower(key)
  for pattern, annotation in pairs(tab) do
    pattern = string.lower(pattern)
    if string.match(key, pattern) then
      return annotation
    end
  end

  return nil
end

local function guessShapeAnnotation(shapeName)
  return fuzzyMatchTableKey(shapeMatches, shapeName)
end

local function setShapeNameAnnotation(parent, node)
  local annotation = node:getField('annotation', '')
  if string.len(annotation) == 0 then
    local shapeName = node:getField('shapeName', '')

    local guess = guessShapeAnnotation(shapeName)
    if guess == nil then
      log('W', 'Shape that has no matching guess, defaulting to OBSTACLES: ' .. tostring(shapeName))
      guess = 'OBSTACLES'
    end

    setAnnotation(node, guess)
  end
end

local function visitNode(parent, node)
  local className = node:getClassName()
  local name = node:getName()
  local id = node:getID()
  local str = tostring(className) .. ': ' ..tostring(name) .. '(' .. tostring(id) .. ')'

  local visitor = visitors['visit' .. className]
  if visitor ~= nil then
    visitor(parent, node)
  else
    log('D', 'Could not find auto annotation visitor for: ' .. str)
  end

  node = Sim.upcast(node)

  if node.getObject ~= nil and node.getCount ~= nil then
    local count = node:getCount()
    for i = 0, count - 1 do
      local child = node:getObject(i)
      visitNode(node, child)
    end
  end
end

visitors.visitSFXSpace = nop
visitors.visitSFXEmitter = nop
visitors.visitPointLight = nop
visitors.visitSpotLight = nop

visitors.visitTSStatic = setShapeNameAnnotation
visitors.visitTSForestItemData = visitors.visitTSStatic

visitors.visitForest = function(parent, node)
  node = Sim.upcast(node)
  for i, item in ipairs(node:getData():getItems()) do
    local itemData = item:getData()
    visitNode(node, itemData)
  end
end

visitors.visitGroundCover = function(parent, node)
  local material = node:getField('Material', '')
  local annotation = node:getField('annotation', '')

  if string.len(annotation) == 0 then
    local name = node:getName()
    local guess = fuzzyMatchTableKey(nameMatches, name)
    if guess == nil then
      log('W', 'GroundCover name has no matching guess, defaulting to NATURE: ' .. tostring(name))
      guess = 'NATURE'
    end

    setAnnotation(node, guess)
  end
end

M.onInit = function()
end

M.autoAnnotateScenetree = function()
  local root = Sim.findObject('MissionGroup')

  if root == nil then
    log('E', 'No MissionGroup found. Not annotating the scenetree.')
    return
  end

  visitNode(root, root)
end

M.autoAnnotateGroups = function()
  local forestItems = Sim.findObject('ForestItemDataSet')
  visitNode(forestItems, forestItems)
end

M.autoAnnotateLevel = function()
  M.autoAnnotateScenetree()
  M.autoAnnotateGroups()
end

return M
