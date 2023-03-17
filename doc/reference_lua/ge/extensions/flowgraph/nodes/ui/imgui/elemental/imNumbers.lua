-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'im Number'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Displays one of several number inputs."
C.category = 'repeat_instant'

C.todo = ""
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'set', hidden = true, description = 'When this has inflow, the internal value will be set to setVal.' },
  { dir = 'in', type = 'number', name = 'setVal', hidden = true, hardcoded = true, default = 0, description = 'The value will be set to this initially.' },

  { dir = 'in', type = 'number', name = 'min', hidden = true, default = 0, hardcoded = true, description = 'Min value when using sliders.' },
  { dir = 'in', type = 'number', name = 'max', hidden = true, default = 10, hardcoded = true, description = 'Max value when using sliders.' },
  { dir = 'in', type = 'number', name = 'step', hidden = true, default = 1, hardcoded = true, description = 'Step value when using sliders, speed when using drag.' },
  { dir = 'in', type = 'string', name = 'format', hidden = true, default = "%0.2f", hardcoded = true, description = 'Format when using floats.' },
  { dir = 'in', type = 'number', name = 'power', hidden = true, default = 1, hardcoded = true, description = 'Power when using float sliders.' },

  { dir = 'out', type = 'number', name = 'value', description = 'Current value' },
  { dir = 'out', type = 'flow', name = 'changed', hidden = true, description = 'Outflow when number changes.', impulse = true },

  { dir = 'in', type = 'any', name = 'text', description = 'Name of the Number.' },
}

function C:init()
  self.modes = {
    'Int',
    'Float',
    'SliderInt',
    'SliderFloat',
    'DragInt',
    'DragFloat'
  }
  self.mode = 'Int'
end

function C:drawCustomProperties()
  local reason = nil
  if im.BeginCombo("##imNumberMode" .. self.id, self.mode) then
    for _, fun in ipairs(self.modes) do
      if im.Selectable1(fun, fun == self.mode) then
        self.mode = fun
        reason = "Changed function to " .. fun
      end
    end
    im.EndCombo()
  end
  return reason
end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = nil
  end
  self.val = nil
end

function C:work()
  if self.val == nil then
    self.val = self.pinIn.setVal.value
  end
  if self.pinIn.set.value then
    self.val = self.pinIn.setVal.value
  end
  if self.val == nil then return end
  local ret = nil
  local label = tostring(self.pinIn.text.value or "Number")  ..'##'.. tostring(self.id)
  local step = self.pinIn.step.value
  local min, max = self.pinIn.min.value, self.pinIn.max.value
  local format = self.pinIn.format.value

  local imVal = nil
  if self.mode == 'Int' then
    imVal = im.IntPtr(self.val)
    ret = im.InputInt(label, imVal, step)
  elseif self.mode == 'Float' then
    imVal = im.FloatPtr(self.val)
    ret = im.InputFloat(label, imVal, step, nil, format)
  elseif  self.mode == 'SliderInt' then
    imVal = im.IntPtr(self.val)
    ret = im.SliderInt(label, imVal, min, max, format)
  elseif  self.mode == 'SliderFloat' then
    imVal = im.FloatPtr(self.val)
    ret = im.SliderFloat(label, imVal, min, max, format, self.pinIn.power.value or 1)
  elseif  self.mode == 'DragInt' then
    imVal = im.IntPtr(self.val)
    ret = im.DragInt(label, imVal, step, min, max, format)
  elseif  self.mode == 'DragFloat' then
    imVal = im.FloatPtr(self.val)
    ret = im.DragFloat(label, imVal, step, min, max, format, self.pinIn.power.value or 1)
  end

  if min and imVal[0] < min then imVal[0] = min end
  if max and imVal[0] > max then imVal[0] = max end
  if not imVal then return end

  if ret == true then
    self.val = imVal[0]
    self.pinOut.changed.value = true
  else
    self.pinOut.changed.value = false
  end

  self.pinOut.value.value = self.val
end

function C:_onSerialize(res)
  res.mode = self.mode
end

function C:_onDeserialized(nodeData)
  self.mode = nodeData.mode or "Int"
end


return _flowgraph_createNode(C)
