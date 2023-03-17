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

C.name = 'Decal Line'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.description = "Will draw the given decal n amount of time from point A to point B. Works like a loading bar."
C.category = 'repeat_instant'

C.pinSchema = {
    { dir = 'in', type = 'vec3', name = 'posA', description = 'Start of the line.' },
    { dir = 'in', type = 'vec3', name = 'posB', description = 'End of the line.' },
    { dir = 'in', type = 'vec3', name = 'decalScale', description = "Decal's scale", default = defaultDecalScale, hardcoded = true },
    { dir = 'in', type = 'number', name = 'amount', description = "How many decals will be used to draw the line", default = defaultAmount, hardcoded = true },
    { dir = 'in', type = 'bool', name = 'inverted', hidden = true, hardcoded = true, default = defaultInverted, description = "Whether the line will be filling from the bottom instead" },
    --{ dir = 'in', type = 'string', name = 'trigger', hidden = true, description = "Name of the trigger that will be the transform for the line." },
    { dir = 'in', type = 'string', name = 'decalPath', description = "The path to the decal to be used", default = defaultDecalPath, hardcoded = true },
    { dir = 'in', type = 'number', name = 'filling1', description = "How much filled (0 - 100) will the first filling be (Can be used as the value for a loading bar)", default = 100, hardcoded = true },
    { dir = 'in', type = 'number', name = 'filling2', description = "How much filled (0 - 100) will be the second filling (Can be used as to show a cooldown)", default = 0, hardcoded = true },
    { dir = 'in', type = 'color', name = 'filledColor', hidden = true, hardcoded = true, default = {defaultFilledColor.r, defaultFilledColor.g, defaultFilledColor.b, defaultFilledColor.a}, description = 'Color of the entire line when fully filled. I.e : at 100%' },
    { dir = 'in', type = 'color', name = 'fillingColor1', hidden = true, hardcoded = true, default = {defaultFilling1Color.r, defaultFilling1Color.g, defaultFilling1Color.b, defaultFilling1Color.a}, description = 'The color of the first main filling (ex : if filled at 70%, those 70% will be this color)' },
    { dir = 'in', type = 'color', name = 'fillingColor2', hidden = true, hardcoded = true, default = {defaultFilling2Color.r, defaultFilling2Color.g, defaultFilling2Color.b, defaultFilling2Color.a}, description = 'The color of the second filling (that can be used to show a cooldown)' },
    { dir = 'in', type = 'color', name = 'backgroundColor', hidden = true, hardcoded = true, default = {defaultBackgorundColor.r, defaultBackgorundColor.g, defaultBackgorundColor.b, defaultBackgorundColor.a}, description = "Color of the decals that aren't 'filled'. (ex : if filled at 70%, the remaining 30% will be drawn this color)" },
}

C.tags = {'util', 'draw'}

function C:init()
  self.triggerTransform = {}
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

--function C:getTriggerTransform()
  --dump("trying to get the trigger")
  --local triggerName = self.pinIn.trigger.value
  --local target = scenetree.findObject(triggerName)
  --self.triggerTransform = {
    --position = target:getPosition(),
    --rotation = quat(target:getRotation()),
    --scale    = target:getScale()
  --}
  --dump(self.triggerTransform.scale)
--end

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

local function increaseDecalPool(max)
  while count < max do
    count = count +1
    table.insert(decals, getNewData())
  end
end

local fwd = vec3()
local t, data, a, b
function C:work()

  --self:getTriggerTransform()
  --local scaleOffset = self.triggerTransform.scale
  --scaleOffset.x = 0
  --scaleOffset.z = 0

  if self.colorCache.defaultFilledColor ~= self.pinIn.filledColor.value then
    self.colorCache.defaultFilledColor = self.pinIn.filledColor.value
    self.colorFCache.defaultFilledColor = ColorF(unpack(self.pinIn.filledColor.value)) or defaultFilledColor
  end

  local amount = self.pinIn.amount.value or defaultAmount
  local invAmount = 1/amount
  increaseDecalPool(amount+1)

  a, b  = vec3(self.pinIn.posA.value)  or vec3(0,0,0), vec3(self.pinIn.posB.value) or vec3(0,0,0)

  fwd:set((b-a):normalized())
  for i = 0, self.pinIn.amount.value or defaultAmount do
    t = i*invAmount
    data = decals[i+1]

    if (self.pinIn.filling1.value or 100) >= 100 then
      if (self.pinIn.filling2.value or 0) > 0 then
        if (not self.pinIn.inverted.value and (t * 100) or (100 - t * 100)) <= (self.pinIn.filling2.value or 0) then
          data.color = ColorF(unpack(self.pinIn.fillingColor2.value)) or defaultFilling2Color
        else
          data.color = ColorF(unpack(self.pinIn.filledColor.value)) or defaultFilledColor
        end
      else
        data.color = self.colorFCache.defaultFilledColor
      end
    else
      if (not self.pinIn.inverted.value and (t * 100) or (100 - t * 100)) <= (100 - self.pinIn.filling1.value or 0) then
        data.color = ColorF(unpack(self.pinIn.fillingColor1.value)) or defaultFilling1Color
      else
        data.color = ColorF(unpack(self.pinIn.backgroundColor.value)) or defaultBackgorundColor
      end
    end

    data.position = lerp(a, b, t)
    data.forwardVec = fwd
    data.texture = self.pinIn.decalPath.value or defaultDecalPath
    data.scale = vec3(unpack(self.pinIn.decalScale.value)) or vec3(unpack(defaultDecalScale))

  end
  Engine.Render.DynamicDecalMgr.addDecals(decals, amount)
end

return _flowgraph_createNode(C)
