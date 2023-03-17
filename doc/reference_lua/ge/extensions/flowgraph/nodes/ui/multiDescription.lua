-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Multi Description'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Merges multiple strings into a multi-description to be used with the startScreen node."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'table', name = 'value', tableType = 'multiTranslationObject', description = 'The result of the matching.' },
}

C.tags = {}

function C:init()
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
  self.pinOut.value.value = {}
  for i = 1, self.count do
    table.insert(self.pinOut.value.value, self.pinIn['value_'..i].value)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.data.pattern then
    local txt = self.data.pattern
    if txt:len() > 10 then
      im.Text(txt:sub(1,10).."...")
    else
      im.Text(txt)
    end
    ui_flowgraph_editor.tooltip(txt)
  end
end

return _flowgraph_createNode(C)
