-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

local defaultFilledColor = ColorF(0, 1, 0, 1)
local defaultFilling1Color = ColorF(1, 0, 0, 1)
local defaultFilling2Color = ColorF(0, 0, 1, 1)
local defaultBackgorundColor = ColorF(1, 1, 1, 1)
local defaultAmount = 32
local defaultDecalPath = "art/shapes/arrows/t_arrow_opaque_d.color.png"
local defaultDecalScale = {1,1,3}
local defaultInverted = false

C.name = 'Decal Circle'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.description = "Will draw the given decal n amount of time in a shape of a circle on the ground. Works like a loading bar, but round"
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'in', type = 'vec3', name = 'pos', description = 'Center of the circle.' },
    { dir = 'in', type = 'number', name = 'radius', default = 1, description = "Circle's raidus"  },
    { dir = 'in', type = 'vec3', name = 'decalScale', description = "Individual decal's scale", default = defaultDecalScale, hardcoded = true },
    { dir = 'in', type = 'number', name = 'amount', description = "How many decals will be drawn to create the circle (The more, the smoother it'll look, but will be slower)", default = defaultAmount, hardcoded = true },
    { dir = 'in', type = 'bool', name = 'inverted', hidden = true, hardcoded = true, default = defaultInverted, description = "Whether the filling has to be inverted" },
    { dir = 'in', type = 'string', name = 'decalPath', description = "The path to the decal to be used to draw the circle", default = defaultDecalPath, hardcoded = true },
    { dir = 'in', type = 'number', name = 'filling1', description = "How much filled (0 - 100) will the first filling be (Can be used as the value for a loading circle)", default = 100, hardcoded = true },
    { dir = 'in', type = 'number', name = 'filling2', description = "How much filled (0 - 100) will be the second filling (Can be used as to show a cooldown)", default = 0, hardcoded = true },
    { dir = 'in', type = 'color', name = 'filledColor', hidden = true, hardcoded = true, default = {defaultFilledColor.r, defaultFilledColor.g, defaultFilledColor.b, defaultFilledColor.a}, description = 'Color of the entire circle when fully filled. I.e : at 100%' },
    { dir = 'in', type = 'color', name = 'fillingColor1', hidden = true, hardcoded = true, default = {defaultFilling1Color.r, defaultFilling1Color.g, defaultFilling1Color.b, defaultFilling1Color.a}, description = 'The color of the first main filling (ex : if filled at 70%, those 70% will be this color)' },
    { dir = 'in', type = 'color', name = 'fillingColor2', hidden = true, hardcoded = true, default = {defaultFilling2Color.r, defaultFilling2Color.g, defaultFilling2Color.b, defaultFilling2Color.a}, description = 'The color of the second filling' },
    { dir = 'in', type = 'color', name = 'backgroundColor', hidden = true, hardcoded = true, default = {defaultBackgorundColor.r, defaultBackgorundColor.g, defaultBackgorundColor.b, defaultBackgorundColor.a}, description = "Color of the decals that aren't 'filled'. (ex : if filled at 70%, the remaining 30% will be drawn this color)" },
}

C.tags = {'util', 'draw'}

function C:init()
end

local function getNewData()
  -- create decals
  return {
    texture = 'art/shapes/arrows/t_arrow_opaque_d.color.png',
    position = vec3(0, 0, 0),
    forwardVec = vec3(0, 0, 0),
    color = ColorF(1, 0, 0, 1 ),
    scale = vec3(1, 1, 4),
    fadeStart = 100,
    fadeEnd = 150
  }
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

--M.stepDistance = 5
local function increaseDecalPool(max)
  while count < max do
    count = count +1
    table.insert(decals, getNewData())
  end
end

local t, cosX, sinY, x, y, data, amount, invAmount, backgroundColorF, filledColorF, fillingColor1ColorF, fillingColor2ColorF
function C:work()
  if self.colorCache.defaultFilledColor ~= self.pinIn.filledColor.value then
    self.colorCache.defaultFilledColor = self.pinIn.filledColor.value
    self.colorFCache.defaultFilledColor = ColorF(unpack(self.pinIn.filledColor.value)) or defaultFilledColor
  end

  fillingColor2ColorF = ColorF(unpack(self.pinIn.fillingColor2.value))
  fillingColor1ColorF = ColorF(unpack(self.pinIn.fillingColor1.value))
  filledColorF = ColorF(unpack(self.pinIn.filledColor.value))
  backgroundColorF = ColorF(unpack(self.pinIn.backgroundColor.value))

  amount = self.pinIn.amount.value or defaultAmount
  invAmount = 1/amount
  increaseDecalPool(amount+1)

  for i = 0, amount do
    t = i*invAmount

    cosX = math.cos(math.rad(t * 360))
    sinY = math.sin(math.rad(t * 360))

    x = (self.pinIn.pos.value[1] or 0) + ((self.pinIn.radius.value or 1) * cosX)
    y = (self.pinIn.pos.value[2] or 0) + ((self.pinIn.radius.value or 1) * sinY)

    data = decals[i+1]

    if (self.pinIn.filling1.value or 100) >= 100 then
      if (self.pinIn.filling2.value or 0) > 0 then
        if (not self.pinIn.inverted.value and (t * 100) or (100 - t * 100)) < (self.pinIn.filling2.value or 0) then
          data.color = fillingColor2ColorF or defaultFilling2Color
        else
          data.color = filledColorF or defaultFilledColor
        end
      else
        data.color = self.colorFCache.defaultFilledColor
      end
    else
      if (not self.pinIn.inverted.value and (t * 100) or (100 - t * 100)) < (100 - self.pinIn.filling1.value or 0) then
        data.color = fillingColor1ColorF or defaultFilling1Color
      else
        data.color = backgroundColorF or defaultBackgorundColor
      end
    end

    data.position:set(x,y,self.pinIn.pos.value[3] or 0)
    data.forwardVec:set(cosX, sinY, 1)
    data.texture = self.pinIn.decalPath.value or defaultDecalPath
    data.scale:set(self.pinIn.decalScale.value[1],self.pinIn.decalScale.value[2],self.pinIn.decalScale.value[3])

    --table.insert(decals, data)
  end
  Engine.Render.DynamicDecalMgr.addDecals(decals, amount)
end

return _flowgraph_createNode(C)
