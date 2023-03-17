-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Monologue'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { duration = true }
C.description = "Shows a number of messages sequentally."
C.category = 'once_f_duration'

C.todo = "Not tested a lot, added rudimentary reset functionality for now"
C.pinSchema = {
  { dir = 'in', type = 'string', name = 'category', default = 'flowgraph', description = 'Defines the message category.' },
  { dir = 'in', type = 'string', name = 'icon', default = 'error', description = 'Defines the icon for the messages.' },
  { dir = 'in', type = 'any', name = 'message_1', description = 'Message 1 to display.' },
  { dir = 'in', type = 'number', name = 'duration_1', default = 5, description = 'Duration for message 1.' },
}

C.tags = {'string','util'}

function C:init()
  self.count = 1
end

function C:_executionStarted()
  self.index = 0
  self.endTime = nil
  self.time = 0
  self.current = 0
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
    reason = "Changed Pin count to " .. ptr[0]
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then

    for i = old, new+1, -1 do
      for _, lnk in pairs(self.graph.links) do
        if lnk.sourcePin == self.pinInLocal['message_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.sourcePin == self.pinInLocal['duration_'..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinInLocal['message_'..i])
      self:removePin(self.pinInLocal['duration_'..i])
    end

  else
    for i = old+1, new do
      --direction, type, name, default, description, autoNumber
      self:createPin('in', 'any', 'message_' .. i, 0, 'Message ' .. i .. ' to display.')
      self:createPin('in', 'number', 'duration_' .. i, 5, 'Duration for message ' .. i .. '.')
    end
  end
  self.count = new
end

function C:onNodeReset()
  self:setDurationState('inactive')
end

function C:workOnce()
  self.time = 0
  self:setDurationState('started')
end

function C:work()
    if not self.endTime then
      self.endTime = 0
      for i = 1, self.count do
        self.endTime = self.endTime + self.pinIn['duration_'..i].value
      end
    end
  if self.time >= self.endTime then
    if self.durationState ~= 'finished' then
      self:setDurationState('finished')
    end
  else
    self.time = self.time + self.mgr.dtSim
    local eTime = 0
    for i = 1, self.count do
      eTime = eTime + self.pinIn['duration_'..i].value
      if self.time < eTime then
        if self.current ~= i then
          self.current = i
          ui_message(tostring(self.pinIn['message_'..i].value), self.pinIn['duration_'..i].value, self.pinIn.category.value or "", self.pinIn.icon.value)
        end
        break
      end
    end
  end
end

function C:_onSerialize(res)
  res.mode = self.mode
  res.count = self.count
end

function C:_onDeserialized(res)
  self.mode = res.mode or 'loop'
  self.count = res.count or 1
  self:updatePins(1, self.count)
end

return _flowgraph_createNode(C)
