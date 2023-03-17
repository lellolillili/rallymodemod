-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'String'
C.description = "Provides a string."
C.category = 'provider'

C.pinSchema = {
    { dir = 'out', type = 'string', name = 'value', description = 'The string value.' },
}


function C:init()
  self.string = "Hello World"
  self.multiLine = false
end

function C:work()
  self.pinOut.value.value = self.string
end

function C:drawCustomProperties()
  local reason = nil
  self.imText = self.imText or im.ArrayChar(2048, self.string)
  local ml = im.BoolPtr(self.multiLine)
  if im.Checkbox("Multi Line", ml) then
    self.multiLine = ml[0]
  end
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  if self.multiLine then
    if im.InputTextMultiline("##mf" .. self.id, self.imText) then
      self.string = ffi.string(self.imText)
      reason = "Changed Text"
    end
    if im.IsItemActive() then
      self._active = true
    else
      if self._active then
        self._active = false
      end
    end
  else
    if im.InputText("##mf" .. self.id, self.imText, nil, im.InputTextFlags_EnterReturnsTrue) then
      self.string = ffi.string(self.imText)
      reason = "Changed Text"
    end
  end
  return reason
end

function C:drawMiddle(builder, style)
  builder:Middle()
  --im.BeginChild1("str"..self.id, im.ImVec2(160,100),1)
  if self.string then
    if #self.string > 10 then
      im.Text(self.string:sub(1,10).. "...")
    else
      im.Text(self.string)
    end
  end

  --im.EndChild()
end

function C:drawProperties()
end

function C:_onSerialize(res)
  res.string = string.gsub(self.string, "\n", "\\n")
  res.multiLine = self.multiLine
end

function C:_onDeserialized(nodeData)
  self.string = nodeData.data.value or (string.gsub(nodeData.string or "", "\\n", "\n")) or "Hello World"
  self.data.value = nil
  self.multiLine = nodeData.multiLine or false
end

return _flowgraph_createNode(C)
