-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Thanks for checking out the instanced line drawing demo :)

-- How to load: extensions.load('util_instancedLineRenderDemo')

-- Idea based on https://github.com/BeamNG/instanced-lines-demos/blob/master/src/n-body.js

-- relevant c++ interfaces:
-- void DebugDrawer::drawLineInstance(const Point3F& posA, const Point3F& posB, const float widthA, const ColorF& colorA, const float widthB, const ColorF& colorB, const ColorF& colOutlineA, const ColorF& colOutlineB, float outLineMultiplier, bool endRoundCaps)
-- void DebugDrawer::drawDot(const Point3F& pos, const float size, const ColorF& color, const ColorF& colOutline, const float outLineMultiplier)

local M = {}

local nMasses = 5
local history = 10000
local masses = {}
local origin = vec3(0, 0, 3)

local simDrawOffset = origin + vec3(0, 10, 0)

local t = 0

local function vec3Random()
  return vec3(math.random(), math.random(), math.random())
end

local function startSim()
  for i = 0, nMasses, 1 do
    table.insert(masses, {
      force = vec3(0, 0, 0),
      velocity = vec3Random(1),
      position = vec3Random(1),
      mass = math.random() * 0.5 + 1.5,
      lines = {},
      color = ColorF(math.random(), math.random(), math.random(), 1)
    })
  end
end

local function simStep(dt)
  for j, mj in ipairs(masses) do
    mj.force = mj.position * -32
    for k, mk in ipairs(masses) do
      if j ~= k then
        local jk = mk.position - mj.position
        local jkl = jk:length()
        local mag = jkl * jkl - 16
        local force = jk:normalized()
        force:setScaled(mag / mj.mass)
        mj.force = mj.force + force
      end
    end
    if mj.force:length() > 1 then
      mj.force:normalize()
    end
  end
  for _, mass in ipairs(masses) do
    mass.velocity = mass.velocity + (mass.force * dt / mass.mass)
    if mass.velocity:length() > 1 then
      mass.velocity:normalize()
    end
    mass.position = mass.position + (mass.velocity * dt)


    local lastPoint = mass.position + origin
    if #mass.lines > 1 then
      lastPoint = mass.lines[#mass.lines - 1][2]
    end
    local positionMag = math.max(0.125, mass.position:length() - 0.5)
    local col = ColorF(mass.color.r * math.min(1, math.pow(positionMag, 1.0)),
                       mass.color.g * math.min(1, math.pow(positionMag, 1.0)),
                       mass.color.b * math.min(1, math.pow(positionMag, 1.0)), 1)

    table.insert(mass.lines, {lastPoint, mass.position + origin, col})
    if #mass.lines > history then
      table.clear(mass.lines)
    end
  end
end

local function drawgrid(size, rot, gridOrigin, mode, width)
  local p1 = vec3(0,0,-size)
  local p2 = vec3(0,0,size)
  local col = ColorF(0.3,0.3,0.3,1)
  local col2 = ColorF(0.8,0.3,0.3,1)
  local col3 = ColorF(0.3,0.6,0.3,1)
  local bgColor = ColorF(1,1,1,1)
  for i = -size, size, 0.25 do
    p1.x = i
    p2.x = i
    local c = col
    local w = width
    if i % 2 == 0 then
      c = col3
    elseif i % 1 == 0 then
      c = col2
    end
    if not mode then
      debugDrawer:drawLine(rot * p1 + gridOrigin, rot * p2 + gridOrigin, c)
    else
      debugDrawer:drawLineInstance(rot * p1 + gridOrigin, rot * p2 + gridOrigin, w, c, w, c, bgColor, bgColor, 5)
    end
  end
  p1.x = -size
  p2.x = size
  for i = -size, size, 0.25 do
    p1.z = i
    p2.z = i
    local c = col
    local w = width
    if i % 2 == 0 then
      c = col3
    elseif i % 1 == 0 then
      c = col2
    end
    if not mode then
      debugDrawer:drawLine(rot * p1 + gridOrigin, rot * p2 + gridOrigin, c)
    else
      debugDrawer:drawLineInstance(rot * p1 + gridOrigin, rot * p2 + gridOrigin, w, c, w, c, bgColor, bgColor, 5)
    end
  end
end

local function updateSim(dt)
  simStep(dt)

  -- draw them all
  local offset = vec3(6, 0, 0)
  for _, mass in ipairs(masses) do
    for _, line in ipairs(mass.lines) do
      debugDrawer:drawLineInstance(line[1] + simDrawOffset, line[2] + simDrawOffset, 3, line[3])
      --debugDrawer:drawLine(line[1] + offset, line[2] + offset, line[3])
    end
  end
end

local rotY = 0
local function testGrid(dt)
  local z = 0 -- math.sin(t) * 0.1 - 3

  rotY = 50 -- dt * 0.5
  local rot = quatFromEuler(0, math.rad(rotY), 0)

  local width = 3 -- math.abs(math.sin(t) * 3)

  local gridSize = 5
  drawgrid(gridSize, rot, origin + vec3(gridSize * 3, -1, z), false, width)
  drawgrid(gridSize, rot, origin + vec3(gridSize * 3, 0, z), true, width)
  debugDrawer:drawText(origin + vec3(gridSize * 3, -0.5, z), String('grid line width = ' .. tostring(width)), ColorF(0, 0, 0, 1))
end

local function drawSin(t, pos, width, step)
  local counter = 0
  local lp
  local lc
  for i = 0, 2 * math.pi, math.pi / step do
    local p = vec3(-i, 0, math.sin(t + i)) + pos
    local col = ColorF(math.sin(t + p.x), math.cos(t + p.x), 0, 1)
    if lp then
      debugDrawer:drawLineInstance(lp, p, width, col)
      counter = counter + 1
    end
    lp = p
    lc = col
  end
  return counter
end

local function drawSinWaveTest()
  local step = 100 --math.abs(math.sin(t)) * 30 + 4
  for i = 0, 10, 1 do
    local pos = origin + vec3(-5, 0, i * 0.3)
    local elCount = drawSin(t, pos, i, step)
    local txt = 'w = ' .. tostring(i) .. ', elements = ' .. tostring(elCount)
    debugDrawer:drawText(pos, String(txt), ColorF(0, 0, 0, 1))
  end
end

local function drawEdgeTest()
  local bgColor = ColorF(1,1,1,0.5)
  debugDrawer:drawLineInstance(origin + vec3(-3,0,1), origin + vec3(-3,0,2), 10, ColorF(1,1,0,1), 30, ColorF(0,1,0,1), bgColor, bgColor, 30)
  debugDrawer:drawLineInstance(origin + vec3(-3,0,2), origin + vec3(-4,0,3), 30, ColorF(0,1,0,1), 20, ColorF(0,0,1,1), bgColor, bgColor, 30)
  debugDrawer:drawLineInstance(origin + vec3(-4,0,3), origin + vec3(-3,0,4 ), 20, ColorF(0,0,1,1), 30, ColorF(1,0,0,1), bgColor, bgColor, 30)

  --debugDrawer:drawDot(origin, 50, ColorF(0,1,0,1), ColorF(0,0,0,1), 1.2)

  debugDrawer:drawLineInstance(origin + vec3(-4,0,4), origin + vec3(-3,0,5), 30, ColorF(0,0,1,1))
  debugDrawer:drawLineInstance(origin + vec3(-4,0,5), origin + vec3(-3,0,6), 30, ColorF(0,0,1,1))
end

local signalMode = 1
local signalTimer = 0
local signalColors = {
  {ColorF(1,0,0,1), ColorF(0.4,0.4,0,1), ColorF(0,0.4,0,1)}, -- red
  {ColorF(1,0,0,1), ColorF(1,1,0,1), ColorF(0,0.4,0,1)}, -- red-yellow
  {ColorF(0.4,0,0,1), ColorF(0.4,0.4,0,1), ColorF(0,1,0,1)}, -- green
  {ColorF(0.4,0,0,1), ColorF(1,1,0,1), ColorF(0,0.4,0,1)}, -- yellow
}
local function drawSignal(pos)
  debugDrawer:drawDot(pos + vec3(0,0,-3), 20, ColorF(0,0,0,1))
  debugDrawer:drawLineInstance(pos + vec3(0,0,-3), pos + vec3(0,0,0.4), 5, ColorF(0,0,0,1))
  debugDrawer:drawLineInstance(pos + vec3(0,0,-0.4), pos + vec3(0,0,0.4), 80, ColorF(1,1,1,0.8), 80, ColorF(1,1,1,0.8), ColorF(0,0,0,1), ColorF(0,0,0,1), 30)

  debugDrawer:drawDot(pos + vec3(0,0, 0.4), 56, ColorF(0,0,0,1))
  debugDrawer:drawDot(pos + vec3(0,0, 0.4), 50, signalColors[signalMode][1])
  debugDrawer:drawDot(pos                 , 56, ColorF(0,0,0,1))
  debugDrawer:drawDot(pos                 , 50, signalColors[signalMode][2], ColorF(0,0,0,1), 1.2)
  debugDrawer:drawDot(pos + vec3(0,0,-0.4), 56, ColorF(0,0,0,1))
  debugDrawer:drawDot(pos + vec3(0,0,-0.4), 50, signalColors[signalMode][3], ColorF(0,0,0,1), 1.2)

  if signalTimer > 1 then
    signalTimer = signalTimer - 1
    signalMode = signalMode + 1
    if signalMode > #signalColors then signalMode = 1 end
  end
end

local function onPreRender(dtReal, dtSim, dtRaw)
  t = t + dtSim * 0.5
  updateSim(dtSim)
  testGrid(dtSim)
  drawSinWaveTest()
  drawEdgeTest()

  signalTimer = signalTimer + dtSim
  drawSignal(origin + vec3(-2,0,3))

  --debugDrawer:drawLineInstance(origin + vec3(0, 0, 0), origin + vec3(0, 0, 500), 30, ColorF(1, 0, 1, 1))
end

local function onExtensionLoaded()
  startSim()
end

M.onPreRender = onPreRender
M.onExtensionLoaded = onExtensionLoaded

return M
