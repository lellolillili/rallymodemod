-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Format String'
C.icon = "mode_edit"
C.color = ui_flowgraph_editor.nodeColors.string
C.description = "Formats a string and inserts values.."
C.category = 'repeat_instant'
C.todo = "Currently only works for up to 16 values. Need variable string.format..."

C.pinSchema = {
  {dir = 'out', type = 'string', name = 'value', description = 'The result of the matching.'},
}

C.tags = {}

function C:init()
  self.data.pattern = "%d"
  self.count = 1
end

function C:postInit()
  self:updatePins(0,self.count)
end

function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Count")
  im.NextColumn()
  local ptr = im.IntPtr(self.count)
  if im.InputInt('##count'..self.id, ptr) then
    if ptr[0] < 1 then ptr[0] = 1 end
    self:updatePins(self.count, ptr[0])
    reason = "Changed Value count to " .. ptr[0]
  end

  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then
    for i = old, new+1, -1 do
      for _, lnk in pairs(self.graph.links) do
        if lnk.sourcePin == self.pinInLocal['value_'..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinInLocal['value_'..i])
    end
  else
    for i = old+1, new do
      self:createPin('in','any','value_'..i)
    end
  end
  self.count = new
end

function C:_onSerialize(res)
  res.count = self.count
end

function C:_onDeserialized(res)
  self.count = res.count or 1
  self:updatePins(1, self.count)
end


function C:work()
  if self.count == 1 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value)
  elseif self.count == 2 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value)
  elseif self.count == 3 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value)
  elseif self.count == 4 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value)
  elseif self.count == 5 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value)
  elseif self.count == 6 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value)
  elseif self.count == 7 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value)
  elseif self.count == 8 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value)
  elseif self.count == 9 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value, self.pinIn.value_9.value)
  elseif self.count == 10 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value, self.pinIn.value_9.value, self.pinIn.value_10.value)
  elseif self.count == 11 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value, self.pinIn.value_9.value, self.pinIn.value_10.value,
    self.pinIn.value_11.value)
  elseif self.count == 12 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value, self.pinIn.value_9.value, self.pinIn.value_10.value,
    self.pinIn.value_11.value,self.pinIn.value_12.value)
  elseif self.count == 13 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value, self.pinIn.value_9.value, self.pinIn.value_10.value,
    self.pinIn.value_11.value,self.pinIn.value_12.value,self.pinIn.value_13.value)
  elseif self.count == 14 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value, self.pinIn.value_9.value, self.pinIn.value_10.value,
    self.pinIn.value_11.value,self.pinIn.value_12.value,self.pinIn.value_13.value,self.pinIn.value_14.value)
  elseif self.count == 15 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value, self.pinIn.value_9.value, self.pinIn.value_10.value,
    self.pinIn.value_11.value,self.pinIn.value_12.value,self.pinIn.value_13.value,self.pinIn.value_14.value,
    self.pinIn.value_15.value)
  elseif self.count == 16 then
    self.pinOut.value.value = string.format(self.data.pattern, self.pinIn.value_1.value, self.pinIn.value_2.value,
      self.pinIn.value_3.value, self.pinIn.value_4.value, self.pinIn.value_5.value, self.pinIn.value_6.value,
      self.pinIn.value_7.value, self.pinIn.value_8.value, self.pinIn.value_9.value, self.pinIn.value_10.value,
    self.pinIn.value_11.value,self.pinIn.value_12.value,self.pinIn.value_13.value,self.pinIn.value_14.value,
    self.pinIn.value_15.value,self.pinIn.value_16.value)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.data.pattern then
    local txt = self.data.pattern
    if txt:len() > 16 then
      im.Text(txt:sub(1,16).."...")
    else
      im.Text(txt)
    end
    ui_flowgraph_editor.tooltip(txt)
  end
end

return _flowgraph_createNode(C)
