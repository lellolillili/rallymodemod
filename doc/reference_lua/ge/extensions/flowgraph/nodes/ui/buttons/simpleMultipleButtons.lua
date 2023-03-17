-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Simple Multiple Buttons'
C.icon = ui_flowgraph_editor.nodeIcons.button
C.color = ui_flowgraph_editor.nodeColors.button
C.description = "Handle a selection of buttons created previously."
C.category = 'once_instant'

C.todo = "TODO"
C.pinSchema = {
  {dir = 'in', type = 'bool', name = 'hideWhenDone_1', description = 'If true, the button will be hidden once it has been clicked once.'},
  {dir = 'in', type = 'string', name = 'label_1', default = "Button_1", description = 'Displayed named of the button.'},
  {dir = 'in', type = 'number', name = 'order_1', hidden = true, description = 'This buttons order in the button list. Leave empty for automatic order.'},
  {dir = 'in', type = 'string', name = 'style_1', hidden = true, description = 'This buttons styling.', hardcoded = true, default = 'default'},
  {dir = 'out', type = 'flow', name = 'clicked_1', description = 'Outflow once when the button is clicked.', impulse=true},
  {dir = 'out', type = 'flow', name = 'complete_1', description = 'Outflow after the button has been clicked the first time.',hidden=true},
    {dir = 'out', type = 'flow', name = 'incomplete_1', description = 'Outflow as long as the button has not yet been clicked.', hidden=true},
  {dir = 'out', type = 'number', name = 'buttonId_1', description = 'ID of the Button.'},
}

function C:init()
  self.count = 1
end

function C:drawMiddle(builder, style)
  builder:Middle()
end

function C:_executionStarted()
  self.hiddenAfterDone = {}
  self.hiddenAfterReset = {}
  for i = 1, self.count do
    self.hiddenAfterDone[i] = false
    self.hiddenAfterReset[i] = false
  end
end

function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Buttons")
  im.NextColumn()
  local ptr = im.IntPtr(self.count)
  if im.InputInt('##buttons'..self.id, ptr) then
    if ptr[0] < 1 then ptr[0] = 1 end
    self:updatePins(self.count, ptr[0])
    reason = "Changed button to " .. ptr[0]
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:updatePins(old, new)
  if new < old then
    for i = old, new+1, -1 do
      for _, lnk in pairs(self.graph.links) do
        if lnk.targetPin == self.pinInLocal['hideWhenDone_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['label_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['order_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinInLocal['style_'..i] then
          self.graph:deleteLink(lnk)
        end

        if lnk.sourcePin == self.pinOut['clicked_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.sourcePin == self.pinOut['complete_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.sourcePin == self.pinOut['incomplete_'..i] then
          self.graph:deleteLink(lnk)
        end
        if lnk.targetPin == self.pinOut['buttonId_'..i] then
          self.graph:deleteLink(lnk)
        end
          self:removePin(self.pinOut['clicked_'..i])
          self:removePin(self.pinOut['complete_'..i])
          self:removePin(self.pinOut['incomplete_'..i])
          self:removePin(self.pinInLocal['hideWhenDone_'..i])
          self:removePin(self.pinInLocal['label_'..i])
          self:removePin(self.pinInLocal['order_'..i])
          self:removePin(self.pinInLocal['style_'..i])
          self:removePin(self.pinOut['buttonId_' ..i])
      end
  end

  else
    for i = old+1, new do
      --direction, type, name, default, description, autoNumber
      self:createPin('in', 'bool', 'hideWhenDone_' .. i, true, 'If true, the button ' .. i .. ' will be hidden once it has been clicked.')
      self:createPin('in', 'string', 'label_' .. i, 'Button_' ..i, 'Displayed named of the button ' ..i..'.')
      local ord = self:createPin('in', 'number', 'order_' .. i, nil, i..' button order in the button list. Leave empty for automatic order.')
      local stl = self:createPin('in', 'string', 'style_' .. i, 'default', i..' button styling.')

      local clkd = self:createPin('out', 'flow', 'clicked_' .. i, nil, 'Outflow once when the button is clicked.')
      local comp = self:createPin('out', 'flow', 'complete_' .. i, nil, 'Outflow after the button has been clicked the first time.')
      local incomp = self:createPin('out', 'flow', 'incomplete_' .. i, nil, 'Outflow as long as the button has not yet been clicked.')
      self:createPin('out', 'number', 'buttonId_' .. i, nil, 'Button Id.')

      ord.hidden = true
      stl.hidden = true
      clkd.impulse = true
      comp.hidden = true
      incomp.hidden = true
    end
  end
  self.count = new
end

function C:onNodeReset()
  for i = 1, self.count do
    if self.pinOut['buttonId_'..i].value then
      if not self.hiddenAfterReset[i] then
        self.mgr.modules.button:set(self.pinOut['buttonId_'..i].value, "active", false)
        self.hiddenAfterReset[i] = true
      end
    end
    self.hiddenAfterDone[i] = false
  end
end

function C:workOnce()
  for i = 1, self.count do
    self.pinOut['buttonId_' ..i].value = self.mgr.modules.button:addButton({
      label = self.pinIn['label_' ..i].value,
      active = self.pinIn.active.value,
      order = self.pinIn['order_' ..i].value,
      style = self.pinIn['style_' ..i].value
    })
  end
end

function C:work()
  for i = 1, self.count do
    local id = self.pinOut['buttonId_'..i].value
    local button = self.mgr.modules.button:getButton(id)

    if self.hiddenAfterReset[i] then
      self.mgr.modules.button:set(id, "active", true)
    end
    self.pinOut['clicked_'..i].value = button.clicked.value
    self.pinOut['complete_'..i].value = button.complete.value
    self.pinOut['incomplete_'..i].value = not self.pinOut['complete_'..i].value
    if self.pinIn['hideWhenDone_'..i].value and not self.hiddenAfterDone[i] and button.complete.value then
      self.mgr.modules.button:set(id, "active", false)
      self.hiddenAfterDone[i] = true
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
