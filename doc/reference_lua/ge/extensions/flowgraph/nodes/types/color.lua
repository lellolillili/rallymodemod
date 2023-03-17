-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Color'
C.tags = {'color', 'colour'}
C.description = "Provides a Color."
C.category = 'provider'
C.todo = "Draw a colored square in the node for visualization."

C.pinSchema = {
    { dir = 'out', type = 'color', name = 'color', description = 'The color value.' },
}


function C:init()
  self.clr = {1, 1, 1, 1}
  self.mode = 'custom'
  self.modes = {'custom','from Pin'}
end

function C:drawCustomProperties()
  local reason = nil
  local oldMode = self.mode
  if im.BeginCombo("##cameraToMode" .. self.id, self.mode) then
    for _, m in ipairs(self.modes) do
      if im.Selectable1(m, m == self.mode) then
        self.mode = m
        reason = "Changed Mode to " .. m
      end
    end
    im.EndCombo()
  end

  if self.mode ~= oldMode then
    if self.mode == 'from Pin' then
      self:createColorPins()
    else
      self:removePin(self.r)
      self:removePin(self.g)
      self:removePin(self.b)
      self:removePin(self.a)
    end
  end

  if self.mode == "custom" then
    local editEnded = im.BoolPtr(false)
    if not self.colorData then
      self.colorData = {
        clr = im.ArrayFloat(8),
        pbr = {}
      }
      self.colorData.clr[0] = im.Float(self.clr[1])
      self.colorData.clr[1] = im.Float(self.clr[2])
      self.colorData.clr[2] = im.Float(self.clr[3])
      self.colorData.clr[3] = im.Float(self.clr[4])
      self.colorData.pbr[1] = im.FloatPtr(self.clr[5] or 0)
      self.colorData.pbr[2] = im.FloatPtr(self.clr[6] or 0)
      self.colorData.pbr[3] = im.FloatPtr(self.clr[7] or 0)
      self.colorData.pbr[4] = im.FloatPtr(self.clr[8] or 0)
    end

    editor.uiColorEdit8("##input"..self.id, self.colorData, nil, editEnded)
    if editEnded[0] then

      self.clr = {
        self.colorData.clr[0], self.colorData.clr[1], self.colorData.clr[2], self.colorData.clr[3],
        self.colorData.pbr[1][0], self.colorData.pbr[2][0], self.colorData.pbr[3][0], self.colorData.pbr[4][0]}
      reason = "Changed color property"
    end
  end
  return reason
end

function C:_onSerialize(res)
  res.clr = self.clr
  res.mode = self.mode
end

function C:_onDeserialized(nodeData)
  self.clr = nodeData.clr or {1, 1, 1, 1}
  self.clr[5] = self.clr[5] or 0
  self.clr[6] = self.clr[6] or 0
  self.clr[7] = self.clr[7] or 0
  self.clr[8] = self.clr[8] or 0

  self.mode = nodeData.mode or 'custom'

  if self.mode == 'from Pin' then
    self.valPin = self:createColorPins()
  end
end

function C:work()
  if self.mode == 'from Pin' then
    self.pinOut.color.value = {self.pinIn.r.value, self.pinIn.g.value, self.pinIn.b.value, self.pinIn.a.value}
  else
    self.pinOut.color.value = self.clr
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:createColorPins()
  self.r = self:createPin('in', "number", 'r')
  self.g = self:createPin('in', "number", 'g')
  self.b = self:createPin('in', "number", 'b')
  self.a = self:createPin('in', "number", 'a')
end

return _flowgraph_createNode(C)
