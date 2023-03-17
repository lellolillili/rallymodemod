-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- roof of concept: creates and SVG image with the roads and vehicle dots
-- created by BeamNG

require('mathlib')
local svg = require('libs/EzSVG/EzSVG')

local M = {}

local heatSVG = nil
local time = 0

local aimap = nil
local terrainPosition = nil
local filename = nil
local terrainSize = 2048 -- terrain.baseTexSize

-- tranforms / flips the coordinates before writing to file
local function transformPoint(p)
  p.y = terrainSize - p.y -- Y flip
  return p
end

local function drawRoads()

  local lines = svg.Group()

  local m = map.getMap()
  if not m or not next(m.nodes) then return end
  -- draw edges
  for nid, n in pairs(m.nodes) do
    for lid, dif in pairs(n.links) do
      local p1 = transformPoint(n.pos - terrainPosition)
      local p2 = transformPoint(m.nodes[lid].pos - terrainPosition)

      -- TODO: add proper fading between some colors
      local typeColor = 'black'
      if dif < 0.7 then
        typeColor = svg.rgb(170, 68, 0) -- dirt road = brown
      end

      local l = svg.Polyline({p1.x, p1.y, p2.x, p2.y}, {
        fill = 'none',
        stroke = typeColor,
        stroke_width = n.radius * 2,
        --stroke_opacity=0.4,
      })
      lines:add(l)
    end
  end
  heatSVG:add(lines)

  -- draw nodes
  local nodes = svg.Group()
  for nid, n in pairs(m.nodes) do
    local p = transformPoint(n.pos - terrainPosition)
    local circle = svg.Circle(p.x, p.y, n.radius, {
      fill = 'black',
      --fill_opacity=0.4,
      stroke = 'none',
    })
    nodes:add(circle)
  end
  heatSVG:add(nodes)
end

local function save()
  if not heatSVG then return end
  heatSVG:writeTo(filename)
end

local function destroy()
  save()
  heatSVG = nil
  terrainPosition = nil
end

local function init(_filename)
  filename = _filename
  destroy()

  local terrain = scenetree.findObject(scenetree.findClassObjects('TerrainBlock')[1])
  terrainPosition = terrain:getPosition()
  --local squareSize = terrain.squareSize
  -- TODO: reproject onto new coordinates

  terrainSize = 2048 -- terrain.baseTexSize
  --terrainfactor = squareSize
  heatSVG = svg.Document(terrainSize, terrainSize, svg.gray(255))
  drawRoads()
end

-- executed every frame, also when not rendering 3d in the menu
local function update()
  if not heatSVG then return end
  aimap = map.getMap()
  if not aimap then return end

  --for k,v in pairs(map.objects) do
  --  heatSVG:drawIcon(pos - terrainPosition, 'x', ColorI(255, 0, 0, 255))
  --end

  -- draw?
  if heatSVG and terrainPosition then
    for mk, mv in pairs(map.objects) do
      -- {active = isactive, pos = pos, vel = vel, dirVec = dirVec, damage = damage}
      -- TODO: fix coordinate system
      local p = transformPoint(mv.pos - terrainPosition)
      local velo = math.min(254, mv.vel:length() * 20)
      --heatSVG:drawPoint(x, y, ColorI(velo, 0, 0, 255), 2)
      local circle = svg.Circle(p.x, p.y, 2, {
        fill="red",
        --stroke="red",
        --stroke_width=1
      })
      heatSVG:add(circle)
    end
  end
end

M.init = init
M.destroy = destroy
M.save = save
M.update = update

return M
