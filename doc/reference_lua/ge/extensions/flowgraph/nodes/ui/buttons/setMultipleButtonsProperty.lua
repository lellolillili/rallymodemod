-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Set Multiple Buttons Property'
C.icon = ui_flowgraph_editor.nodeIcons.button
C.color = ui_flowgraph_editor.nodeColors.button
C.description = "Handle a selection of buttons properties created previously."
C.category = 'repeat_instant'

C.todo = "TODO"
C.pinSchema = {
  { dir = 'in', type = 'number', name = 'buttonId_1', description = 'ID of the button.' },
  { dir = 'in', type = 'string', name = 'label_1', default = "Button", description = 'Displayed named of the button.' },
  { dir = 'in', type = 'bool', name = 'active_1', description = 'If this button should be active or not' },
  { dir = 'in', type = 'number', name = 'order_1', description = 'This buttons order in the button list. Leave empty for automatic order.' },
  { dir = 'in', type = 'string', name = 'style_1', description = 'This buttons styling.', default = 'default' },
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
        if lnk.targetPin == self.pinInLocal['buttonId_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['label_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['active_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['order_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['style_'..i] then
          self.graph:deleteLink(lnk)
        end
      end
      self:removePin(self.pinInLocal['buttonId_'..i])
      self:removePin(self.pinInLocal['label_'..i])
      self:removePin(self.pinInLocal['active_'..i])
      self:removePin(self.pinInLocal['order_'..i])
      self:removePin(self.pinInLocal['style_'..i])
    end

  else
    for i = old+1, new do
    --direction, type, name, default, description, autoNumber
    self:createPin('in', 'number', 'buttonId_' .. i, nil, 'Button Id ' .. i .. ' to check.')
    self:createPin('in', 'string', 'label_' .. i, "Button", 'Displayed named of the button.')
    self:createPin('in', 'bool', 'active_' .. i, nil, 'If this button should be active or not')
    self:createPin('in', 'number', 'order_' .. i, nil, 'This buttons order in the button list. Leave empty for automatic order.')
    self:createPin('in', 'string', 'style_' .. i, 'default', 'This buttons styling.')
    end
  end
  self.count = new
end

local properties = {'active','order','style','label'}
function C:work()
  for i = 1, self.count do
    local id = self.pinIn['buttonId_'..i].value
    local button = self.mgr.modules.button:getButton(id)
    if id and button then
      for _, p in ipairs(properties) do
        if self.pinIn[p .. '_' ..i].value ~= nil then
          self.mgr.modules.button:set(id, p, self.pinIn[p .. '_' ..i].value)
        end
      end
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
