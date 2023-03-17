-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'And'
C.icon = 'fg_gate_icon_and'
C.description = "Only lets flow through if all input pins receive flow."
C.todo = "Add properties option to increase the number of input pins arbitrarily"
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow_1', description = 'First flow input.' },
  { dir = 'in', type = 'flow', name = 'flow_2', description = 'Second flow input.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node, if all inputs receive flow.' },
}

C.legacyPins = {
  _in = {
    a = 'flow_1',
    b = 'flow_2'
  },
}


function C:init()
  self.count = 2
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
        if lnk.targetPin == self.pinInLocal['flow'..'_'..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinInLocal['flow'..'_'..i])
    end
  else
    for i = old+1, new do
      --direction, type, name, default, description, autoNumber
      self:createPin('in','flow','flow'..'_'..i)
    end
  end
  self.count = new
end



function C:work()
  for i = 1, self.count do
    if not self.pinIn['flow_'..i].value then
      self.pinOut.flow.value = false
      return
    end
  end
  self.pinOut.flow.value = true
end
function C:_onSerialize(res)
  res.count = self.count
end

function C:_onDeserialized(res)
  self.count = res.count or 2
  self:updatePins(2, self.count)
end

return _flowgraph_createNode(C)
