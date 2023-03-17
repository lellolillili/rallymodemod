-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local basePrefix = "base_marker_"
local cylinderPrefix = "cylinder_marker_"
local baseShape = "art/shapes/interface/checkpoint_marker_base.dae"
local cylinderShape = "art/shapes/interface/checkpoint_marker.dae"

local modeInfos = {
  default = {color = {1, 0.07, 0}}, -- red
  next = {color = {0.3, 0.3, 0.3}}, -- gray
  start = {color = {0.4, 1, 0.2}}, -- green
  lap = {color = {0.4, 1, 0.2}}, -- green
  recovery = {color = {1, 0.85, 0}}, -- yellow
  final = {color = {0.1, 0.3, 1}}, -- blue
  branch = {color = {1, 0.6, 0}} -- yellow
}

local fadeNear = 0
local fadeFar = 70

-- called when this object is created. initialize variables here (but dont spawn objects)
function C:init(id)
  self.id = id
  self.visible = false

  self.pos = nil
  self.radius = nil
  self.color = nil
  self.currentColor = {0,0,0,0}

  self.fadeNear = fadeNear
  self.fadeFar = fadeFar

  self.modeInfos = deepcopy(modeInfos)

  self.base = nil
  self.cylinder = nil

  self.mode = 'current'
end

-- called every frame to update the visuals.
function C:update()
  if not self.visible then return end

  local camPos = getCameraPosition()
  local distance = self.pos:distance(camPos)-self.radius/2
  local markerAlpha = clamp(inverseLerp(self.fadeNear,self.fadeFar,distance),0,1)

  if self.base then
    self.base.instanceColor = ColorF(1,1,1,markerAlpha*0.75):asLinear4F()
    self.base:updateInstanceRenderData()
  end
  if self.cylinder then
    self.currentColor.a = markerAlpha * 0.95
    self.cylinder.instanceColor = self.currentColor:asLinear4F()
    self.cylinder:updateInstanceRenderData()
  end
end

-- setting it to represent checkpoints. mode can be:
-- default (red, "normal" checkpoint)
-- branch (yellow, for branching paths)
-- next (gray, the one after the current checkpoint)
-- lap (green, last cp in non-last lap)
-- finish (blue, last cp in last lap)
-- start (green, first cp when using rolling start)
function C:setToCheckpoint(wp)
  self.pos = vec3(wp.pos)
  self.radius = wp.radius
  -- assume color is a table

  self.fadeNear = wp.fadeNear or self.fadeNear
  self.fadeFar = wp.fadeFar or self.fadeFar

  if self.base then
    self.base:setPosition(vec3(self.pos))
    self.base:setScale(vec3(self.radius*2, self.radius*2, self.radius*2))
  end
  if self.cylinder then
    self.cylinder:setPosition(vec3(self.pos))
    self.cylinder:setScale(vec3(self.radius, self.radius, 50))
  end
end

function C:setMode(mode)
  --dump(self.id .. " -> " .. mode)
  if mode == 'hidden' then
    self:hide()
  else
    self:show()
  end
  self.color = deepcopy(self.modeInfos[mode or 'default'].color or {0,0,0,0})
  self.currentColor = ColorF(self.color[1],self.color[2],self.color[3],1)
  self:update(0,0)
end

-- visibility management
function C:setVisibility(v)
  self.visible = v
  if self.base then
    self.base.hidden = not v
  end
  if self.cylinder then
    self.cylinder.hidden = not v
  end
end

function C:hide() self:setVisibility(false) end
function C:show() self:setVisibility(true)  end

-- marker management
function C:createObject(shapeName, objectName)
  local marker =  createObject('TSStatic')
  marker:setField('shapeName', 0, shapeName)
  marker:setPosition(vec3(0, 0, 0))
  marker.scale = vec3(1, 1, 1)
  marker:setField('rotation', 0, '1 0 0 0')
  marker.useInstanceRenderData = true
  marker:setField('instanceColor', 0, '1 1 1 1')
  marker.canSave = false
  marker.hidden = true
  marker:registerObject(objectName)

  local scenarioObjectsGroup = scenetree.ScenarioObjectsGroup
  if scenarioObjectsGroup then
    scenarioObjectsGroup:addObject(marker)
  end

  return marker
end

-- creates neccesary objects
function C:createMarkers()
  self:clearMarkers()
  self._ids = {}
  if not self.base then
    self.base = self:createObject(baseShape,basePrefix..self.id)
    table.insert(self._ids, self.base:getId())
  end
  if not self.cylinder then
    self.cylinder = self:createObject(cylinderShape,cylinderPrefix..self.id)
    table.insert(self._ids, self.cylinder:getId())
  end
end

-- destorys/cleans up all objects created by this
function C:clearMarkers()
  for _, id in ipairs(self._ids or {}) do
    local obj = scenetree.findObjectById(id)
    if obj then
      obj:delete()
    end
  end
  self._ids = nil
  self.base = nil
  self.cylinder = nil
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end