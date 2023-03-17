-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Timed Sequence'

C.icon = "timer"
C.description = "Timed Sequence."
C.category = 'once_f_duration'

C.legacyPins = {
  out = {
    allComplete = 'complete'
  }
}

C.tags = {'util'}

function C:init()
  self.count = 0
  self.index = 0
  self.endTime = nil
  self.time = 0
  self.current = 0
end

function C:postInit()
  self:updatePins(0, 1)
end

function C:_executionStarted()
  self.index = 0
  self.endTime = nil
  self.time = 0
  self.current = 0
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
      self:removePin(self.pinInLocal['duration_'..i])
      self:removePin(self.pinOut['start_'..i])
      self:removePin(self.pinOut['active_'..i])
      self:removePin(self.pinOut['complete_'..i])
    end
  else
    for i = old+1, new do
      --direction, type, name, default, description, autoNumber
      local pn = self:createPin('in','number','duration_'..i, 5, "Duration of part " .. i)
      self:_setHardcodedDummyInputPin(pn, 5)
      self:createPin('out','flow','start_'..i, nil, "Outflow once when part " .. i .. " begins.")
      self:createPin('out','flow','active_'..i, nil, "Outflow when part " .. i .. " is active.")
      self:createPin('out','flow','complete_'..i, nil, "Outflow once when part " .. i .. " is completed.")
    end
  end
  self.count = new
end

function C:workOnce()
  self:setDurationState('started')
end

function C:onNodeReset()
  self.time = 0
  self:setDurationState('inactive')
end

function C:work()
  if self.durationState == 'started' then
    if not self.endTime then
      self.endTime = 0
      for i = 1, self.count do
        self.endTime = self.endTime + self.pinIn['duration_'..i].value
      end
    end
    if self.time >= self.endTime then
      self:setDurationState('finished')
      if self.current == self.count then
        self.pinOut["complete_"..self.current].value = true
        self.current = self.current +1
      else
        self.pinOut["complete_"..(self.current-1)].value = false
      end
    else
      self.time = self.time + self.mgr.dtSim
      local eTime = 0
      for i = 1, self.count do
        self.pinOut["start_"..i].value = false
        self.pinOut["active_"..i].value = false
        self.pinOut["complete_"..i].value = false
      end
      for i = 1, self.count do
        eTime = eTime + self.pinIn['duration_'..i].value
        if self.time < eTime then
          if self.current ~= i then
            self.pinOut["start_"..i].value = true
            if self.pinOut["complete_"..(i-1)] then
              self.pinOut["complete_"..(i-1)].value = true
            end
            self.current = i
          end
          self.pinOut["active_"..i].value = true
          break
        end
      end
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.time then
    im.Text(string.format("%0.1fs", self.time))
  end
  if self.current then
    im.Text("Section: " .. self.current)
  end
  --im.BeginChild1("child",im.ImVec2(self.sliderWidth[0],50), true)
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
