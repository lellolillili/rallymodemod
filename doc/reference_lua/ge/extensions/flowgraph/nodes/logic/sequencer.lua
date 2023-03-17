-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Sequencer'
C.icon = "call_split"
C.description = "Sequences the flow."
C.category = 'logic'
C.todo = "Currently does start at index 2 if in auto mode"

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'number', name = 'currentIndex', description = 'Index inside the current loop.', hidden = true },
  { dir = 'out', type = 'number', name = 'maxIndex', description = 'Maximum index inside one loop.', hidden = true },
  { dir = 'out', type = 'number', name = 'totalIndex', description = 'Total, unrestrained index.', hidden = true },
  { dir = 'out', type = 'flow', name = 'value_1', description = 'Flow output for index 1' },

}

C.tags = {}

local modes = {
  loop = function(t,c) return 1+((t-1)%c) end,
  random = function(t,c) return math.floor(math.random()*c)+1 end,
  once = function(t,c) return t end,
  pingpong = function(t,c)
    local o = 1+((t-1)%(2*(c-1)))
    return o <= (2*(c-1)) and o or (2*c)-o
  end
}
local sortedModes = {'loop','random','once'}

function C:init()
  self.count = 1
  self.mode = 'loop'
  self.incMode = 'auto'
  self.index = 1
end

function C:_executionStarted()
  self.index = 0
end


function C:updateMode(m)
  if m ~= 'manual' then
    self:removePin(self.pinInLocal['next'])
    self:removePin(self.pinInLocal['reset'])
    self:removePin(self.pinInLocal['count'])
  end
  if m ~= 'select' then
    self:removePin(self.pinInLocal['index'])
  end

  if m == 'select' then
    self:createPin('in', 'number', 'index', 1, 'Value to set index to.')
  end
  if m == 'manual' then
    self:createPin('in', 'flow', 'next', nil, 'Increases the current index by 1.')
    self:createPin('in', 'flow', 'reset', nil, 'Resets the index to 1.')
    self:createPin('in', 'number', 'count')
  end
  self.incMode = m
end
function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Increment Mode")
  im.NextColumn()
  if im.BeginCombo("##imode", self.incMode) then
    for _, m in ipairs({ 'auto', 'manual', 'select' }) do
      if im.Selectable1(m) then

        reason = "Changed Increment Mode to " .. m
        self:updateMode(m)

      end
    end
    im.EndCombo()
  end
  if self.incMode ~= 'select' then
    im.NextColumn()
    im.Text("Sequence Mode")
    im.NextColumn()
    if im.BeginCombo("##mode", self.mode) then
      for _, m in ipairs(sortedModes) do
        if im.Selectable1(m) then
          self.mode = m
          reason = "Changed Sequence Mode to " .. m
        end
      end
      im.EndCombo()
    end
  end
  im.NextColumn()
  im.Text("Count")
  im.NextColumn()
  local ptr = im.IntPtr(self.count)
  if im.InputInt('##count' .. self.id, ptr) then
    if ptr[0] < 1 then
      ptr[0] = 1
    end
    self:updatePins(self.count, ptr[0])
    reason = "Changed Pin count to " .. ptr[0]
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then

    for i = old, new+1, -1 do
      self:removePin(self.pinOut['value_'..i])
    end

  else
    for i = old+1, new do
      --direction, type, name, default, description, autoNumber
      self:createPin('out', 'flow', 'value_' .. i, nil, 'Flow output for index ' .. i)
    end
  end
  self.count = new
end


function C:_onSerialize(res)
  res.mode = self.mode
  res.count = self.count
  res.incMode = self.incMode
end

function C:_onDeserialized(res)
  self.mode = res.mode or 'loop'
  self.count = res.count or 1
  self:updatePins(1, self.count)
  self.incMode = res.incMode or 'auto'
  self:updateMode( self.incMode)
end

function C:work()

  if self.incMode == 'auto' then
    self.index = self.index +1
  elseif self.incMode == 'manual' then
    if self.pinIn.next.value then
      self.index = self.index+1
    end
    if self.pinIn.reset.value then
      self.index = 1
      return
    end
  elseif self.incMode == 'select' then
    self.index = self.pinIn.index.value or 1
  end
  local c = self.mode == 'manual' and self.pinIn.count.value or self.count
  local on = modes[self.mode](self.index,c)
  for i = 1, c do
    self.pinOut['value_'..i].value = on == i
  end
  self.pinOut.currentIndex.value = on
  self.pinOut.maxIndex.value = self.count
  self.pinOut.totalIndex.value = self.index

  self.pinOut.flow.value = false

  if self.pinIn.flow.value then
    self.pinOut.flow.value = true
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.TextUnformatted(self.mode)
  im.TextUnformatted(tostring(modes[self.mode](self.index,self.count)) .. " ("..tostring(self.index)..")")
end

return _flowgraph_createNode(C)
