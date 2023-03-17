-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local basePrefix = "base_marker_"
local sidesPrefix = "cylinder_marker_"
local distantPrefix = "distant_marker_"
local baseShape = "art/shapes/interface/sideMarker/checkpoint_curve_base.dae"
local sideShape =  "art/shapes/interface/sideMarker/checkpoint_curve_active.dae"
local sideShapeFinal =  "art/shapes/interface/sideMarker/checkpoint_curve_finish.dae"
local distantShape =  "art/shapes/interface/sideMarker/checkpoint_curve_distant.dae"

local modeInfos = {
  default = {
    color = {1, 0.07, 0},
    baseColor = {1, 1, 1},
    shape = sideShape,
  },
  next = {
    color = {0.0, 0.0, 0.0},
    baseColor = {0, 0, 0},
    shape = sideShape,
  },
  start = {
    color = {0.4, 1, 0.2},
    baseColor = {1, 1, 1},
    shape = sideShape,
  },
  lap = {
    color = {0.4, 1, 0.2},
    baseColor = {1, 1, 1},
    shape = sideShapeFinal,
  },
  final = {
    color = {0.1, 0.3, 1},
    baseColor = {1, 1, 1},
    shape = sideShapeFinal,
  },
  branch = {
    color = {1, 0.6, 0},
    baseColor = {1, 1, 1},
    shape = sideShape,
  },
  hidden = {
    color = {0, 0, 0},
    baseColor = {0, 0, 0},
    shape = sideShape,
  }
}

local fadeNear = 50
local fadeFar = 75

local distanceScale = 4
local sideToDistantRatio = distanceScale*0.1/1.215

local function inverseLerp(min, max, value)
 if math.abs(max - min) < 1e-30 then return min end
 return (value - min) / (max - min)
end

-- todo: replace this by a HSV-lerp if blending with non-gray colors
local function lerpColor(a,b,t)
  return {lerp(a[1],b[1],t),lerp(a[2],b[2],t),lerp(a[3],b[3],t)}
end

-- called when this object is created. initialize variables here (but dont spawn objects)
function C:init(id)
  self.id = id
  self.visible = false

  self.pos = nil
  self.radius = nil
  self.color = nil

  self.newColor = {0,0,0,0}
  self.oldColor = {0,0,0,0}
  self.colorTimer = 0
  self.colorLerpDuration = 0.3

  self.fadeNear = fadeNear
  self.fadeFar = fadeFar

  self.modeInfos = deepcopy(modeInfos)

  self.blendTimer = 0
  self.blendState = nil
  self.blendDuration = 0.8

  self.alpha = 0
  self.targetAlpha = 0

  self.base = nil
  self.sides = nil
  self.distant = nil
  self.normal = nil

  self.mode = 'hidden'
  self.oldMode = 'hidden'
end

-- called every frame to update the visuals.
function C:update(dt, dtSim)

  self.colorTimer = self.colorTimer + dt
  if self.colorTimer >= self.colorLerpDuration then
    if self.mode == 'hidden' then
      self:hide()
    end
  end
  if not self.visible then return end

  local playerPosition = vec3(0,0,0)
  -- Should always be facing the camera
  playerPosition:set(getCameraPosition())

  local distanceFromMarker = self.pos:distance(playerPosition)

  if self.blendState == nil then
    self.blendState = (distanceFromMarker < (self.fadeNear + self.fadeFar)/2) and 'close' or 'far'
    self.blendTimer = self.blendState == 'close' and 0 or self.blendDuration
  elseif self.blendState == 'close' and distanceFromMarker > self.fadeFar then
    self.blendState = 'far'
  elseif self.blendState == 'far' and distanceFromMarker < self.fadeNear then
    self.blendState = 'close'
  end
  self.blendTimer = clamp(self.blendTimer + (self.blendState == 'close' and -1 or 1 ) * dt,0,self.blendDuration)


  local closeFade = 1--clamp(inverseLerp(closeFadeNear, closeFadeFar, distanceFromMarker - (self.radius+2)),0,1)
  local distantFade = clamp(self.blendTimer / self.blendDuration,0,1)

  local closeAlpha = closeFade--clamp(closeFade - distantFade,0,1)
  local distantAlpha = distantFade

  local fwd = self.normal and self.normal or (playerPosition-self.pos)
  local rot = quatFromDir(fwd:z0()):toTorqueQuat()

  local t = clamp(self.colorTimer / self.colorLerpDuration,0,1)
  local color = lerpColor(self.modeInfos[self.oldMode or 'default'].color, self.modeInfos[self.mode or 'default'].color, t)
  local colorBase = lerpColor(self.modeInfos[self.oldMode or 'default'].baseColor, self.modeInfos[self.mode or 'default'].baseColor, t)

  --debugDrawer:drawText(self.pos, String(string.format("%0.3f %s",t, self.blendState or "non")), ColorF(0, 0, 0, 1))
  local a = 1
  if self.mode == 'hidden' then
    a = 1-t
  end
  if self.oldMode == 'hidden' then
    a = t
  end

  self.currentColor = ColorF(color[1],color[2],color[3],1)
  if self.base then
    self.base.instanceColor = ColorF(colorBase[1],colorBase[2],colorBase[3],closeAlpha * 0.75 * a):asLinear4F()
    self.base:updateInstanceRenderData()
    if distanceFromMarker > self.radius*1.5 then
      self.base:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
    end
  end
  if self.sides then
    local sideSize = lerp(1*self.radius,sideToDistantRatio, smootherstep(distantFade))
    self.sides:setScale(vec3(self.radius, self.radius, self.radius))
    if distanceFromMarker > self.radius*1.5 then
      self.sides:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
    end
    self.currentColor.a = closeAlpha * 0.95 * a
    self.sides.instanceColor = self.currentColor:asLinear4F()
    self.sides:updateInstanceRenderData()
  end
  if self.distant then
    self.distant:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
    self.currentColor.a = distantAlpha * 0.95 * a
    self.distant.instanceColor = self.currentColor:asLinear4F()
    self.distant:updateInstanceRenderData()
  end

end

-- setting it to represent checkpoints. mode can be:
-- default (red, "normal" checkpoint)
-- branch (yellow, for branching paths)
-- next (black, the one after the current checkpoint)
-- lap (green, last cp in non-last lap)
-- finish (blue, last cp in last lap)
-- start (green, first cp when using rolling start)
function C:setToCheckpoint(wp)
  self.pos = vec3(wp.pos)
  self.radius = wp.radius
  self.normal = wp.normal and vec3(wp.normal) or nil

  self.fadeNear = wp.fadeNear or self.fadeNear
  self.fadeFar = wp.fadeFar or self.fadeFar

  if self.base then
    self.base:setPosition(vec3(self.pos))
    self.base:setScale(vec3(self.radius, self.radius, self.radius))
  end
  if self.sides then
    self.sides:setPosition(vec3(self.pos))
    self.sides:preApply()
    self.sides:setField('shapeName', 0, self.modeInfos[wp.mode or 'default'].shape)
    self.sides:postApply()
    self.sides:setScale(vec3(self.radius, self.radius, self.radius))
  end
  if self.distant then
    self.distant:setPosition(vec3(self.pos))
    self.distant:setScale(vec3(self.radius, self.radius, self.radius))
  end
end

function C:setMode(mode)
  if mode ~= 'hidden' then
    self:show()
  end
  self.oldMode = self.mode
  self.mode = mode
  self.oldColor = deepcopy(self.newColor)
  self.newColor = deepcopy(self.modeInfos[mode or 'default'].color)
  --self.currentColor = ColorF(self.oldColor[1],self.oldColor[2],self.oldColor[3],1)
  self.colorTimer = 0
  if self.sides then
    self.sides:preApply()
    self.sides:setField('shapeName', 0, self.modeInfos[mode or 'default'].shape)
    self.sides:postApply()
    --self.sides.instanceColor = self.currentColor:asLinear4F()
  end
  if self.distant then
    --self.distant.instanceColor = self.currentColor:asLinear4F()
  end
  self:update(0,0)
end

-- visibility management
function C:setVisibility(v)
  self.visible = v
  if self.base then
    self.base.hidden = not v
  end
  if self.sides then
    self.sides.hidden = not v
  end
  if self.distant then
    self.distant.hidden = not v
  end
end

function C:hide()
  self.newColor = self.modeInfos['hidden'].color
  self.oldColor = self.modeInfos['hidden'].color
  self:setVisibility(false)
end
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
  if not self.sides then
    self.sides = self:createObject(sideShape,sidesPrefix..self.id)
    table.insert(self._ids, self.sides:getId())
  end
  if not self.distant then
    self.distant = self:createObject(distantShape,distantPrefix..self.id)
    table.insert(self._ids, self.distant:getId())
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
  self.sides = nil
  self.distant = nil
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end