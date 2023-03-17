-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local meshPrefix = "cylinder_marker_"

local ringShape =  "art/shapes/interface/ringMarker/checkpoint_ring.dae"
local ringShapeFinal =  "art/shapes/interface/ringMarker/checkpoint_ring_finish.dae"


local modeInfos = {
  default = {
    color = {1, 0.07, 0},
    baseColor = {1, 1, 1},
    shape = ringShape,
  },
  next = {
    color = {0.0, 0.0, 0.0},
    baseColor = {0, 0, 0},
    shape = ringShape,
  },
  start = {
    color = {0.4, 1, 0.2},
    baseColor = {1, 1, 1},
    shape = ringShape,
  },
  lap = {
    color = {0.4, 1, 0.2},
    baseColor = {1, 1, 1},
    shape = ringShapeFinal,
  },
  final = {
    color = {0.1, 0.3, 1},
    baseColor = {1, 1, 1},
    shape = ringShapeFinal,
  },
  branch = {
    color = {1, 0.6, 0},
    baseColor = {1, 1, 1},
    shape = ringShape,
  },
  hidden = {
    color = {0, 0, 0},
    baseColor = {0, 0, 0},
    shape = ringShape,
  }
}

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

  self.colorTimer = 0
  self.colorLerpDuration = 0.3

  self.modeInfos = deepcopy(modeInfos)

  self.alpha = 0
  self.targetAlpha = 0

  self.ring = nil
  self.normal = nil
  self.up = nil

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

  local fwd = self.normal and self.normal or vec3(0,0,1)
  local rot = quatFromDir(fwd:z0()):toTorqueQuat()

  local t = clamp(self.colorTimer / self.colorLerpDuration,0,1)
  local color = lerpColor(self.modeInfos[self.oldMode or 'default'].color, self.modeInfos[self.mode or 'default'].color, t)
  local colorBase = lerpColor(self.modeInfos[self.oldMode or 'default'].baseColor, self.modeInfos[self.mode or 'default'].baseColor, t)

  --debugDrawer:drawText(self.pos, String(string.format("%0.3f %s",t, self.blendState or "non")), ColorF(0, 0, 0, 1))
  --debugDrawer:drawLine(vec3(self.pos), vec3(self.pos + self.normal), ColorF(1,0,0,1))
  --debugDrawer:drawLine(vec3(self.pos), vec3(self.pos + self.up), ColorF(0,1,0,1))

  local a = 1
  if self.mode == 'hidden' then
    a = 1-t
  end
  if self.oldMode == 'hidden' then
    a = t
  end
  self.currentColor = ColorF(color[1],color[2],color[3],1)
  if self.ring then
    self.ring:setScale(vec3(self.radius, self.radius, self.radius))
    self.currentColor.a = 1 * a
    self.ring.instanceColor = self.currentColor:asLinear4F()
    self.ring:updateInstanceRenderData()
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
  self.up = wp.up or vec3(0,0,1)
  if self.ring then
    self.ring:setPosition(vec3(self.pos))
    self.ring:preApply()
    self.ring:setField('shapeName', 0, self.modeInfos[wp.mode or 'default'].shape)
    self.ring:postApply()
    self.ring:setScale(vec3(self.radius+1.5, self.radius+1.5, self.radius+1.5))
    local fwd = self.normal and self.normal or vec3(0,1,0)
    local up = wp.up or vec3(0,0,1)
    local rot = quatFromDir(fwd, up):toTorqueQuat()
    self.ring:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
  end

end

function C:setMode(mode)
  if mode ~= 'hidden' then
    self:show()
  end
  self.oldMode = self.mode
  self.mode = mode
  self.colorTimer = 0
  if self.ring then
    self.ring:preApply()
    self.ring:setField('shapeName', 0, self.modeInfos[mode or 'default'].shape)
    self.ring:postApply()
  end
  self:update(0,0)
end

-- visibility management
function C:setVisibility(v)
  self.visible = v
  if self.ring then
    self.ring.hidden = not v
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
  if not self.ring then
    self.ring = self:createObject(ringShape,meshPrefix..self.id)
    table.insert(self._ids, self.ring:getId())
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
  self.ring = nil
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end