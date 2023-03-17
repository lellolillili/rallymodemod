-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}
C.windowName = 'fg_legend'
C.windowDescription = 'Legend Test'

function C:attach(mgr)
  self.mgr = mgr
end

function C:init()
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
  self.items = {
    {name = "A", id = 1, open = im.BoolPtr(true)},
    {name = "B", id = 10, open = im.BoolPtr(true)},
    {name = "C", id = 5, open = im.BoolPtr(true)},
    {name = "D", id = 3, open = im.BoolPtr(true)},
  }
end

function C:draw()
  if not editor.isWindowVisible(self.windowName) then return end
  self:Begin(self.windowName)
  im.BeginTabBar("LegendTest", im.TabBarFlags_Reorderable)
  local itms = {}
  for _, item in ipairs(self.items) do
    local cp = im.GetCursorPosX()
    if item.open[0] then
      if im.BeginTabItem(item.name..'##'..item.id, item.open) then
        im.Text(item.name .. cp)
        im.EndTabItem()
      end
      table.insert(itms, item.name)
    end
  end

  im.EndTabBar()
  im.Text(dumps(itms))

  self:End()
end


function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

return _flowgraph_createMgrWindow(C)
