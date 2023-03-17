-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Ease'
C.description = [[Applies a smoothing/easing function to the input. Input is supposed to be between 0 and 1, but does not have to.]]
C.category = 'simple'
C.todo = "Maybe this functions can be merged into the math node."

-- TODO: add icons for
C.pinSchema = {
  {dir = 'in', type = 'number', name = 'value', description = 'Number between 0 and 1 as the input to the ease function.'},
  {dir = 'out', type = 'number', name = 'value', description = 'The result of the easing. Between 0 and 1.'},
}

C.tags = {'easing','inOut','quad','cubic','quart'}

local easeFunctions = {
  ['linear'] = function(t) return t end,

  ['inQuad'] = function(t) return t*t end,
  ['outQuad'] = function(t) return t*(2-t) end,
  ['inOutQuad'] = function(t) return t < 0.5 and 2*t*t or -1+(4-2*t)*t end,

  ['inCubic'] = function(t) return t*t*t end,
  ['outCubic'] = function(t) return (t-1) * (t-1) * (t-1) + 1 end,
  ['inOutCubic'] = function(t) return t < 0.5 and 4*t*t*t or (t-1)*(2*t-2)*(2*t-2)+1 end,

  ['inQuart'] = function(t) return t*t*t*t end,
  ['outQuart'] = function(t) return 1-(t-1)*(t-1)*(t-1)*(t-1) end,
  ['inOutQuart'] = function(t) return t < 0.5 and 8*t*t*t*t or 1-8*(t-1)*(t-1)*(t-1)*(t-1) end,

  ['inQuint'] = function(t) return t*t*t*t*t end,
  ['outQuint'] = function(t) return 1+(t-1)*(t-1)*(t-1)*(t-1)*(t-1) end,
  ['inOutQuint'] = function(t) return t < 0.5 and 16*t*t*t*t*t or 1-16*(t-1)*(t-1)*(t-1)*(t-1)*(t-1) end,

  ['inSin'] = function(t) return -1 * (math.cos(t * math.pi/2)) + 1 end,
  ['outSin'] = function(t) return (math.sin(t * math.pi/2)) end,
  ['inOutSin'] = function(t) return (math.cos(t * math.pi) -1) / -2 end,

  ['inExp'] = function(t) return math.pow(2,10*(t-1)) end,
  ['outExp'] = function(t) return (-math.pow(2,-10*t)+1) end,
  ['inOutExp'] = function(t) return t < 0.5 and 0.5 * math.pow(2,10*(2*t-1)) or 0.5*(-math.pow(2,-10*(2*t-1))+2)  end,

  ['inCirc'] = function(t) return -1 * (math.sqrt(1-t*t)-1) end,
  ['outCirc'] = function(t) return math.sqrt(1-(t-1)*(t-1)) end,
  ['inOutCirc'] = function(t) return t < 0.5 and -0.5 * (math.sqrt(1-(t*2)*(t*2))-1) or 0.5*(math.sqrt(1-(t*2-2)*(t*2-2))+1) end,
}

local easeFuncNameList = {
    'linear',
    'inQuad','outQuad','inOutQuad',
    'inQuart','outQuart','inOutQuart',
    'inQuint','outQuint','inOutQuint',
    'inSin','outSin','inOutSin',
    'inExp','outExp','inOutExp',
    'inCirc','outCirc','inOutCirc'}

function C:init()
  self.easeFuncName = 'linear'
  self.easeFunc = easeFunctions[self.easeFuncName]
end


function C:drawCustomProperties()
  local reason = nil
  if im.BeginCombo("##easeFunc" .. self.id, self.easeFuncName) then
    for _, fun in ipairs(easeFuncNameList) do
      if im.Selectable1(fun, fun == self.easeFuncName) then
        self.easeFuncName = fun
        self.easeFunc = easeFunctions[self.easeFuncName]
        reason = "Changed function to " .. fun
      end
    end
    im.EndCombo()
  end
  return reason
end

function C:_onSerialize(res)
  res.easeFuncName = self.easeFuncName
end

function C:_onDeserialized(nodeData)
  if nodeData.easeFuncName then
    self.easeFuncName = nodeData.easeFuncName
    self.easeFunc = easeFunctions[self.easeFuncName]
  end
end


function C:work()
  if self.pinIn.value.value then
    self.pinOut.value.value = self.easeFunc(self.pinIn.value.value)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  --im.PushItemWidth(50)
  if self.easeFuncName then
    im.Text(self.easeFuncName)
  end
end

return _flowgraph_createNode(C)
