-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get Multiple Buttons'
C.icon = ui_flowgraph_editor.nodeIcons.button
C.color = ui_flowgraph_editor.nodeColors.button
C.description = "Handle a selection of buttons created previously."
C.category = 'repeat_instant'

C.todo = "TODO"
C.pinSchema = {
  {dir = 'in', type = 'number', name = 'buttonId_1', description = 'ID of the button.'},
  {dir = 'out', type = 'flow', name = 'clicked_1', description = 'Puts out flow if the buttonId_1 is clicked', impulse = true},
  {dir = 'out', type = 'number', name = 'buttonId_1', description = 'Value 1 to compare.'},
}

function C:init()
  self.count = 1
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Button Ids")
  im.NextColumn()
  local ptr = im.IntPtr(self.count)
  if im.InputInt('##ids'..self.id, ptr) then
      if ptr[0] < 1 then ptr[0] = 1 end
      self:updatePins(self.count, ptr[0])
      reason = "Changed Value id to " .. ptr[0]
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then
    for i = old, new+1, -1 do
      for _, lnk in pairs(self.graph.links) do
        if lnk.sourcePin == self.pinOut['clicked_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['buttonId_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinOut['buttonId_'..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinOut['clicked_'..i])
      self:removePin(self.pinInLocal['buttonId_'..i])
      self:removePin(self.pinOut['buttonId_' ..i])
    end

  else
    for i = old+1, new do
    --direction, type, name, default, description, autoNumber
    self:createPin('in', 'number', 'buttonId_' .. i, nil, 'Button Id ' .. i .. ' to check.')
    local clkd = self:createPin('out', 'flow', 'clicked_' .. i, nil, 'Puts out flow if the buttonId_' ..i.. ' is clicked.')
    clkd.impulse = true

    self:createPin('out', 'number', 'buttonId_' .. i, nil, 'Button Id ' .. i)
    end
  end
  self.count = new
end

function C:work()
  local button = nil
  local id = nil
  for i = 1, self.count do
    id = self.pinIn['buttonId_'..i].value
    button = self.mgr.modules.button:getButton(id)
    if id and button then
      self.pinOut['clicked_' .. i].value = button.clicked.value
    end
  end
end

function C:_onSerialize(res)
  res.count = self.count
end

function C:_onDeserialized(res)
  self.count = res.count or 1
  self:updatePins(1, self.count)
end

return _flowgraph_createNode(C)
