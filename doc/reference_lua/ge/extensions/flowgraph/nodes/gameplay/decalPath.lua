-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}


C.name = 'DecalPath'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.description = "Will draw the given decal n amount of time from point A to point B. Works like a loading bar."
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'in', type = 'vec3', name = 'posA', description = 'Start of the line.' },
    { dir = 'in', type = 'vec3', name = 'posB', description = 'End of the line.' },
    { dir = 'in', type = 'vec3', name = 'decalScale', description = "Decal's scale", default = defaultDecalScale, hardcoded = true },
    { dir = 'in', type = 'number', name = 'spacing', description = "How many decals will be used to draw the line", default = 10, hardcoded = true },
}

C.tags = {'util', 'draw'}

function C:init()
  self.triggerTransform = {}
end

function C:getNewData()
  -- create decals
  return {
    texture = "art/shapes/arrows/arrow_groundmarkers_1.png",
    position = vec3(0, 0, 0),
    forwardVec = vec3(0, 0, 0),
    color = ColorF(40/255, 120/255, 250/255, 1),
    scale = vec3(8, 12, 4),
    fadeStart = 1000,
    fadeEnd = 1500
  }
end


function C:_executionStarted()
end

local decals, count
function C:_executionStarted()
  decals = {}
  count = 0
  self.colorCache = {
    defaultFilledColor = nil
  }
  self.colorFCache = {}
end

function C:increaseDecalPool(max)
  while count < max do
    count = count + 1
    table.insert(decals, self:getNewData())
  end
end
local route = require('/lua/ge/extensions/gameplay/route/route')()
local fwd = vec3()
local t, data, a, b
function C:work()

  route:setupPathMulti({vec3(self.pinIn.posA.value), vec3(self.pinIn.posB.value)})
  local path = route.path
  local totalPathLength = path[1].distToTarget

  --self:getTriggerTransform()
  --local scaleOffset = self.triggerTransform.scale
  --scaleOffset.x = 0
  --scaleOffset.z = 0
  --[[
  if self.colorCache.defaultFilledColor ~= self.pinIn.filledColor.value then
    self.colorCache.defaultFilledColor = self.pinIn.filledColor.value
    self.colorFCache.defaultFilledColor = ColorF(unpack(self.pinIn.filledColor.value)) or defaultFilledColor
  end

  amount = self.pinIn.amount.value or defaultAmount
  invAmount = 1/amount
  ]]

  local spacing = 20
  local distance = 0
  distance = getTime()*10 % spacing
  local pathCount = #path
  for _, wp in ipairs(path) do
    wp.distanceFromStart = totalPathLength - wp.distToTarget
  end

  local markers = {}
  for i = 1, pathCount-1 do
    local cur, nex = path[i], path[i+1]
    local segmentLength = cur.distToTarget - nex.distToTarget
    while distance < nex.distanceFromStart do
      local fwd = (nex.pos - cur.pos):normalized()
      table.insert(markers, {pos = cur.pos + fwd * (distance-cur.distanceFromStart), fwd = fwd, alpha = 1, dist = distance})
      if #markers == 1 then
        markers[1].alpha = distance / spacing
      end
      distance = distance + spacing
    end
  end

  if #markers > 1 then
    markers[#markers].alpha = ((totalPathLength-markers[#markers].dist)/spacing)
  end

  self:increaseDecalPool(#markers)

  for i, m in ipairs(markers) do
    data = decals[i]
    data.position = m.pos
    data.forwardVec = m.fwd
    data.color.a = m.alpha
  end

  Engine.Render.DynamicDecalMgr.addDecals(decals, #markers)

end

return _flowgraph_createNode(C)
