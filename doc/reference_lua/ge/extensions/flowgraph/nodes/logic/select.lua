-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')
local C = {}

C.name = 'Select'
C.icon = "call_split"
C.description = "Selects a value from a number of choices. Not connecting the top flow pin will keep the value even if no other input is detected."
C.category = 'logic'
C.todo = "Not all modes work with all input types. Using nil as any of the input might not work correctly with some modes."

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'any', name = 'value', description = 'The final value.' },
  { dir = 'in', type = 'flow', name = 'select_1', description = 'Selects value 1.' },
  { dir = 'in', type = 'any', name = 'value_1', description = 'Value 1 that can be selected.' },
}

C.tags = {'string','util','switch'}


function C:init()
  self.count = 1
  self.mode = 'first'
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.TextUnformatted(self.mode)
end


function C:_executionStarted()

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
  im.NextColumn()
  im.TextUnformatted("Merge Functions")
  im.NextColumn()
  if im.BeginCombo("##", self.mode, 0) then
    for _,fun in ipairs(fg_utils.sortedMergeFuns.any) do
      if fun.name ~= 'readOnly' then
        if im.Selectable1(fun.name, fun.name == self.mode) then
          self.mode = fun.name
          reason = "Changed merge function to " .. fun.name
        end
        ui_flowgraph_editor.tooltip(fun.desc)
      end
    end
    im.EndCombo()
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then

    for i = old, new+1, -1 do
      for _, lnk in pairs(self.graph.links) do
        if lnk.sourcePin == self.pinInLocal['select_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.sourcePin == self.pinInLocal['value_'..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinInLocal['select_'..i])
      self:removePin(self.pinInLocal['value_'..i])
    end

  else
    for i = old+1, new do
      --direction, type, name, default, description, autoNumber
      self:createPin('in', 'flow', 'select_' .. i, nil, 'Selects value ' .. i .. '.')
      self:createPin('in', 'any', 'value_' .. i, nil, 'Value ' .. i .. ' that can be selected.')
    end
  end
  self.count = new
end

function C:work()
  local var = {value = nil}
  fg_utils.mergeFuns.any[self.mode].init(var)
  local selecting = false
  for i = 1, self.count do
    if self.pinIn['select_'..i].value then
      fg_utils.mergeFuns.any[self.mode].merge(var, self.pinIn['value_'..i].value)
      selecting = true
    end
  end
  fg_utils.mergeFuns.any[self.mode].finalize(var)
  if selecting then
    self.pinOut.flow.value = true
    self.pinOut.value.value = var.value
  else
    self.pinOut.flow.value = self.pinIn.flow.value
    self.pinOut.value.value = nil
  end
end

function C:_onSerialize(res)
  res.mode = self.mode
  res.count = self.count
end

function C:_onDeserialized(res)
  self.mode = res.mode or 'first'
  self.count = res.count or 1
  self:updatePins(1, self.count)
end

return _flowgraph_createNode(C)
