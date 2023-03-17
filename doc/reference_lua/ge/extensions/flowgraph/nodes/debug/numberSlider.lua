-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Number Slider'
C.description = "Provides a set of number sliders with varying ranges."
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'number', name = 'a', description = 'Number a.' },
  { dir = 'out', type = 'number', name = 'b', description = 'Number b.', hidden = true },
  { dir = 'out', type = 'number', name = 'c', description = 'Number c.', hidden = true },
  { dir = 'out', type = 'number', name = 'd', description = 'Number d.', hidden = true },
  { dir = 'out', type = 'number', name = 'e', description = 'Number e.', hidden = true },
}

C.tags = {'util'}

function C:init()

  self.data.aMin = -1
  self.data.aMax = 1
  self.aInput = im.FloatPtr(0)

  self.data.bMin = 0
  self.data.bMax = 1
  self.bInput = im.FloatPtr(0)

  self.data.cMin = 0
  self.data.cMax = 10
  self.cInput = im.FloatPtr(0)

  self.data.dMin = 0
  self.data.dMax = 100
  self.dInput = im.FloatPtr(0)

  self.data.eMin = 0
  self.data.eMax = 1000
  self.eInput = im.FloatPtr(0)
end

function C:drawCustomProperties()
  local reason = nil
  im.SliderFloat("a##a"..self.id,self.aInput, self.data.aMin, self.data.aMax,"%0.3f")
  im.SliderFloat("b##b"..self.id,self.bInput, self.data.bMin, self.data.bMax,"%0.3f")
  im.SliderFloat("c##c"..self.id,self.cInput, self.data.cMin, self.data.cMax,"%0.3f")
  im.SliderFloat("d##d"..self.id,self.dInput, self.data.dMin, self.data.dMax,"%0.3f")
  im.SliderFloat("e##e"..self.id,self.eInput, self.data.eMin, self.data.eMax,"%0.3f")
  return reason
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.PushItemWidth(120)
  --563: function M.SliderFloat(string_label, float_v, float_v_min, float_v_max, string_format, float_power)
  if not self.pinOut.a.hidden then
    im.SliderFloat("##a"..self.id,self.aInput, self.data.aMin, self.data.aMax,"%0.3f")
  end
  if not self.pinOut.b.hidden then
    im.SliderFloat("##b"..self.id,self.bInput, self.data.bMin, self.data.bMax,"%0.3f")
  end
  if not self.pinOut.c.hidden then
    im.SliderFloat("##c"..self.id,self.cInput, self.data.cMin, self.data.cMax,"%0.3f")
  end
  if not self.pinOut.d.hidden then
    im.SliderFloat("##d"..self.id,self.dInput, self.data.dMin, self.data.dMax,"%0.3f")
  end
  if not self.pinOut.e.hidden then
    im.SliderFloat("##e"..self.id,self.eInput, self.data.eMin, self.data.eMax,"%0.3f")
  end
  im.PopItemWidth()
end

function C:work()
  self.pinOut.a.value = self.aInput[0]
  self.pinOut.b.value = self.bInput[0]
  self.pinOut.c.value = self.cInput[0]
  self.pinOut.d.value = self.dInput[0]
  self.pinOut.e.value = self.eInput[0]
end

function C:_onSerialize(res)
  res.a = self.aInput[0]
  res.b = self.bInput[0]
  res.c = self.cInput[0]
  res.d = self.dInput[0]
  res.e = self.eInput[0]
end

-- Deserialize (loading) custo fields from data here.
-- self.data will be restored automatically.
function C:_onDeserialized(data)
  self.aInput[0] = data.a or 0
  self.bInput[0] = data.b or 0
  self.cInput[0] = data.c or 0
  self.dInput[0] = data.d or 0
  self.eInput[0] = data.e or 0
end


return _flowgraph_createNode(C)
