-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local basePrefix = "base_marker_"
local sidesPrefix = "cylinder_marker_"
local distantPrefix = "distant_marker_"
local baseShape = "art/shapes/interface/sideMarker/checkpoint_curve_base.dae"
local sideShape =  "art/shapes/interface/single_faded_column.dae"

local modeInfos = {
  default = {
    color = {1, 0.07, 0},
    baseColor = {1, 1, 1},
  },
  next = {
    color = {0.0, 0.0, 0.0},
    baseColor = {0, 0, 0},
  },
  start = {
    color = {0.4, 1, 0.2},
    baseColor = {1, 1, 1},
  },
  lap = {
    color = {0.4, 1, 0.2},
    baseColor = {1, 1, 1},
  },
  recovery = {
    color = {1, 0.85, 0},
    baseColor = {1, 1, 1},
  },
  final = {
    color = {0.1, 0.3, 1},
    baseColor = {1, 1, 1},
  },
  branch = {
    color = {1, 0.6, 0},
    baseColor = {1, 1, 1},
  },
  hidden = {
    color = {0, 0, 0},
    baseColor = {0, 0, 0},
  }
}

local zVec = vec3(0,0,1)

local fadeNear = 1
local fadeFar = 50

local function inverseLerp(min, max, value)
 if math.abs(max - min) < 1e-30 then return min end
 return (value - min) / (max - min)
end

-- todo: replace this by a HSV-lerp if blending with non-gray colors
local lerpedColor = vec3()
local function lerpColor(a,b,t)
  lerpedColor:set(lerp(a[1],b[1],t), lerp(a[2],b[2],t), lerp(a[3],b[3],t))
  return lerpedColor
end

-- called when this object is created. initialize variables here (but dont spawn objects)
function C:init(id)
  self.id = id
  self.visible = false

  self.pos = nil
  self.radius = nil
  self.color = nil
  self.currentColor = ColorF(1,1,1,1):asLinear4F()
  self.colorBase = ColorF(1,1,1,1):asLinear4F()

  self.colorTimer = 0
  self.colorLerpDuration = 0.3
  self.minAlpha = 0.25

  self.fadeNear = fadeNear
  self.fadeFar = fadeFar

  self.modeInfos = deepcopy(modeInfos)

  self.base = nil
  self.sides = nil
  self.distant = nil
  self.normal = nil

  self.mode = 'hidden'
  self.oldMode = 'hidden'
end

-- called every frame to update the visuals.
local playerPosition = vec3(0,0,0)
local scale = vec3()
local markerOffset = vec3(0,0,-10)
function C:update(dt, dtSim)
  self.colorTimer = self.colorTimer + dt
  if self.colorTimer >= self.colorLerpDuration then
    if self.mode == 'hidden' then
      self:hide()
    end
  end
  if not self.visible then return end

  playerPosition:set(getCameraPosition())

  local distanceFromMarker = self.pos:distance(playerPosition)

  local t = clamp(self.colorTimer / self.colorLerpDuration,0,1)
  local color = lerpColor(self.modeInfos[self.oldMode or 'default'].color, self.modeInfos[self.mode or 'default'].color, t)
  self.currentColor.x = color.x
  self.currentColor.y = color.y
  self.currentColor.z = color.z
  self.currentColor.w = clamp(inverseLerp(self.fadeNear,self.fadeFar,distanceFromMarker),0,0.75) + clamp(self.minAlpha, 0, 0.25)

  local normal = self.normal and self.normal or (playerPosition-self.pos):normalized()
  local rot = quatFromDir(normal:z0()):toTorqueQuat()
  if distanceFromMarker > self.radius*1.5 then
    self.side = normal:cross(zVec)
  end
  local baseHeight = clamp(inverseLerp(10,40,distanceFromMarker),self.radius,self.radius*3)
  if self.base then
    local color = lerpColor(self.modeInfos[self.oldMode or 'default'].baseColor, self.modeInfos[self.mode or 'default'].baseColor, t)
    self.colorBase.x = color.x
    self.colorBase.y = color.y
    self.colorBase.z = color.z
    self.colorBase.w = self.currentColor.w * 0.5

    self.base.instanceColor = self.colorBase
    if distanceFromMarker > self.radius*1.5 then
      self.base:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
    end
    self.base:setScale(vec3(self.radius, self.radius, baseHeight))
    self.base:updateInstanceRenderData()
  end
  local sideRadius = math.max(0.125, distanceFromMarker*0.03)
  local sideHeight = clamp(inverseLerp(60,180,distanceFromMarker),0,20)+1 +clamp(inverseLerp(1800,2040,distanceFromMarker),0,20)
  --debugDrawer:drawTextAdvanced(self.pos, String(string.format("%0.2f -> %0.2f / %0.2f / %0.2f", distanceFromMarker, sideRadius, sideHeight, baseHeight)), ColorF(1,1,1,1), true, false, ColorI(0,0,0,192))
  if self.left then
    self.left.instanceColor = self.currentColor
    self.left:setPosition(self.pos - self.side * self.radius + markerOffset)
    self.left:updateInstanceRenderData()
    scale:set(sideRadius, sideRadius, sideHeight)
    self.left:setScale(scale)
  end
  if self.right then
    self.right.instanceColor = self.currentColor
    self.right:setPosition(self.pos + self.side * self.radius + markerOffset)
    self.right:updateInstanceRenderData()
    scale:set(sideRadius, sideRadius, sideHeight)
    self.right:setScale(scale)
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
  self.side = (self.normal or vec3(1,0,0)):cross(vec3(0,0,1))

  self.fadeNear = wp.fadeNear or self.fadeNear
  self.fadeFar = wp.fadeFar or self.fadeFar
  self.minAlpha = wp.minAlpha or self.minAlpha

  if self.base then
    self.base:setPosition(vec3(self.pos))
    self.base:setScale(vec3(self.radius, self.radius, self.radius))
  end
  if self.left then
    self.left:setPosition(vec3(self.pos - self.side * self.radius))
    self.left:setScale(vec3(1,1,1))
  end
  if self.right then
    self.right:setPosition(vec3(self.pos + self.side * self.radius))
    self.right:setScale(vec3(1,1,1))
  end
end

function C:setMode(mode)
  if mode ~= 'hidden' then
    self:show()
  end
  self.oldMode = self.mode
  self.mode = mode
  self.colorTimer = 0

  self:update(0,0)
end

-- visibility management
function C:setVisibility(v)
  self.visible = v
  if self.base then
    self.base.hidden = not v
  end
  if self.left then
    self.left.hidden = not v
  end
  if self.right then
    self.right.hidden = not v
  end
end

function C:hide()
  self.newColor = modeInfos['hidden'].color
  self.oldColor = modeInfos['hidden'].color
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
  if not self.left then
    self.left = self:createObject(sideShape,sidesPrefix.."left"..self.id)
    table.insert(self._ids, self.left:getId())
  end
  if not self.right then
    self.right = self:createObject(sideShape,sidesPrefix.."right"..self.id)
    table.insert(self._ids, self.right:getId())
  end
end

-- destorys/cleans up all objects created by this
function C:clearMarkers()
  for _, id in ipairs(self._ids or {}) do
    local obj = scenetree.findObjectById(id)
    if obj then
      --print("Found Obj with id " .. id)
      obj:delete()
    else
      --print("No obj by ID " .. id)
    end
  end
  self._ids = nil
  self.base = nil
  self.left = nil
  self.right = nil
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end