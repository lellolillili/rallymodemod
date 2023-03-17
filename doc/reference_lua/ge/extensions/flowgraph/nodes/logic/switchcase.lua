-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')
local C = {}

C.name = 'Switch Case'
C.icon = "call_split"
C.description = "Compares the input value against each switch value. Lets flow through the matching one."
C.category = 'logic'

C.todo = "WiP"
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'any', name = 'value', description = 'The value which will be checked.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'flow', name = 'none', description = 'When no matching occured.' },
  { dir = 'in', type = 'any', name = 'value_1', description = 'Value 1 to compare.' },
  { dir = 'out', type = 'flow', name = 'match_1', description = 'Puts out flow, if value 1 is a match.' },
}

C.tags = {'string','util','switch'}


function C:init()
  self.count = 1

end

function C:drawMiddle(builder, style)
  builder:Middle()
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
  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then
    for i = old, new+1, -1 do
      for _, lnk in pairs(self.graph.links) do
        if lnk.sourcePin == self.pinOut['match_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['value_'..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinOut['match_'..i])
      self:removePin(self.pinInLocal['value_'..i])
    end

  else
    for i = old+1, new do
      --direction, type, name, default, description, autoNumber
      self:createPin('in', 'any', 'value_' .. i, nil, 'Value ' .. i .. ' to compare.')
      self:createPin('out', 'flow', 'match_' .. i, nil, 'Puts out flow, if value ' .. i .. ' is a match.')
    end
  end
  self.count = new
end

function C:work()
  self.pinOut.flow.value = true
  local matchNumber = -1
  for i = 1, self.count do
    if self.pinIn['value_'..i].value == self.pinIn.value.value then
      matchNumber = i
      self.pinOut['match_'..i].value = true
    else
      self.pinOut['match_'..i].value = false
    end
  end
  self.pinOut.none.value = matchNumber == -1
end

function C:_onSerialize(res)
  res.count = self.count
end

function C:_onDeserialized(res)
  self.count = res.count or 1
  self:updatePins(1, self.count)
end

return _flowgraph_createNode(C)
