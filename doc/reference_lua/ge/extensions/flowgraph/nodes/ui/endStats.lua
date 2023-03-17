-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'End Stats'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Gathers the end stats for the End Screen node."
C.category = 'repeat_instant'

C.pinSchema = {
  { dir = 'out', type = 'table', name = 'statData', tableType = 'endStats', description = 'statData, use with endScreen node.' },
  { dir = 'in', type = 'table', name = 'statData', tableType = 'endStats', description = 'statData, use with endScreen node.', hidden = true },
}

C.tags = {'string','util','switch'}

local pinsPerStat = {
  {'label',{'string','table'},'translationObject'},{'points','number'},{'maxPoints','number'},
  --{'value','number'},{'maxValue','number'},{'predefinedUnit','string'},{'decimals','number'}

}

function C:init()
  self.count = 0
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
      for _, p in ipairs(pinsPerStat) do
        for _, lnk in pairs(self.graph.links) do
          if lnk.targetPin == self.pinInLocal[p[1]..'_'..i] then
            self.graph:deleteLink(lnk)
          end
        end
        self:removePin(self.pinInLocal[p[1]..'_'..i])
      end
    end
  else
    for i = old+1, new do
      for _, p in ipairs(pinsPerStat) do
        --direction, type, name, default, description, autoNumber
        if type(p[2]) == 'table' and tableContains(p[2],'table') then
          local pin = self:createPin('in',p[2],p[1]..'_'..i)
          pin.tableType = p[3]
        else
          self:createPin('in',p[2],p[1]..'_'..i)
        end
      end
    end
  end
  self.count = new
end

function C:work()
  local out = self.pinIn.statData.value or {}
  for i = 1, self.count do
    local stat = {}
    for _, p in ipairs(pinsPerStat) do
      stat[p[1]] = self.pinIn[p[1]..'_'..i].value
    end
    if stat.points and stat.maxPoints then
      stat.relativePoints = stat.points*100/stat.maxPoints
    end
    table.insert(out, stat)
  end
  self.pinOut.statData.value = out
end

function C:_onSerialize(res)
  res.count = self.count
end

function C:_onDeserialized(res)
  self.count = res.count or 0
  self:updatePins(0, self.count)
end

return _flowgraph_createNode(C)
