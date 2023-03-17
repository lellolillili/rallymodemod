-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local annotationKeywords = {}
local defaultAnnotation = ColorI(0, 255, 0, 0)

local partPriorities = {}
partPriorities['engine'] = 255
partPriorities['radiator'] = 255
partPriorities['diff'] = 128
partPriorities['doorpanel'] = 255
partPriorities['bumperbar'] = 128
partPriorities['pedal'] = 255
partPriorities['driveshaft'] = 255
partPriorities['heatshield'] = 255
partPriorities['engbaycrap'] = 255
partPriorities['radtube'] = 255
partPriorities['header'] = 255
partPriorities['intake'] = 255
partPriorities['tierod'] = 255

M.onExtensionLoaded = function()
  local cfgFile = '/tech/part_annotation_config.json'
  local annoFile = '/tech/annotations.json'

  local cmdArgs = Engine.getStartingArgs()
  for i = 1, #cmdArgs do
    local arg = cmdArgs[i]
    arg = arg:stripchars('"')
    if arg == '-partannotationconfig' and i + 1 <= #cmdArgs then
      cfgFile = cmdArgs[i + 1]
    end
    if arg == '-annotationconfig' and i + 1 <= #cmdArgs then
      annoFile = cmdArgs[i + 1]
    end
  end

  local cfg = jsonReadFile(cfgFile)
  for part, color in pairs(cfg) do
    annotationKeywords[part] = ColorI(color[1], color[2], color[3], 0)
  end

  local anno = jsonReadFile(annoFile)
  if anno ~= nil and anno.CAR ~= nil then
    defaultAnnotation = ColorI(anno.CAR[1], anno.CAR[2], anno.CAR[3], 0)
  end
end

M.getPartAnnotation = function(part)
  part = string.lower(part)
  local matches = {}
  local result = nil
  for keyword, color in pairs(annotationKeywords) do
    if string.find(part, keyword) ~= nil then
      matches[keyword] = color
    end
  end

  local maxKnown = -1
  for keyword, color in pairs(matches) do
    local len = string.len(keyword)
    if len > maxKnown then
      maxKnown = len
      result = color
    end
  end

  if result ~= nil then
    return result
  else
    return nil
  end
end

local function annotatePart(vehicle, part)
  local color = M.getPartAnnotation(string.lower(part))
  if color then
    log('I', 'partAnnotations', 'Setting mesh annotation color: ' .. part .. ': ' .. tostring(color.r) .. ', ' .. tostring(color.g) .. ', ' .. tostring(color.b))
    vehicle:setMeshAnnotationColor(part, color)
  end
end

M.annotateParts = function(vID)
  log('I', 'partAnnotations', 'Annotating vehicle: ' .. vID)
  local veh = be:getObjectByID(vID)
  local parts = veh:getMeshNames()
  for idx, part in ipairs(parts) do
    log('I', 'partAnnotations', part)
    annotatePart(veh, part)
  end
end

M.revertAnnotations = function(vID)
  local veh = be:getObjectByID(vID)
  local parts = veh:getMeshNames()
  for idx, part in ipairs(parts) do
    veh:setMeshAnnotationColor(part, defaultAnnotation)
  end
end

M.getPartAnnotations = function(vID)
  local colors = {}
  local veh = be:getObjectByID(vID)
  local parts = veh:getMeshNames()
  for idx, part in ipairs(parts) do
    local color = M.getPartAnnotation(part)
    if color then
      colors[part] = color
    end
  end
  return colors
end

return M
