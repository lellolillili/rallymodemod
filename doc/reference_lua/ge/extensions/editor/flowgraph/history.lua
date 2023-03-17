-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}
C.windowName = 'fg_history'
C.windowDescription = 'History'
local disabledColor = im.ImVec4(0.5,0.5,0.5,1)

function C:attach(mgr)
  self.mgr = mgr
end

function C:init()
    editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
end

function C:draw()
  if not editor.isWindowVisible(self.windowName) then return end
  self:Begin('History')
  if im.Button("Undo") then
    self.mgr:undo()
  end
  im.SameLine()
  if im.Button("Redo") then
    self.mgr:redo()
  end
  local avail = im.GetContentRegionAvail()
  im.BeginChild1("historyChild", im.ImVec2(avail.x-1, avail.y - 5))
  im.Columns(2)
  im.SetColumnWidth(0, 40)
  local goToHistory = nil
  im.Text("Idx")
  im.NextColumn()
  im.Text("Action")
  im.NextColumn()
  im.Separator()
  for i = self.mgr.maxHistoryCount, 1, -1  do
    if self.mgr.history[i] then


      if i > self.mgr.currentHistoryIndex then
        im.TextColored(disabledColor,tostring(i))
        if im.IsItemClicked() then goToHistory = i end
        im.NextColumn()
        im.PushStyleColor2(im.Col_Text, disabledColor)
        im.TextWrapped(self.mgr.history[i].title)
        im.PopStyleColor()
        if im.IsItemClicked() then goToHistory = i end
        im.NextColumn()

      elseif i == self.mgr.currentHistoryIndex then
        im.Text('>' .. tostring(i))
        if im.IsItemClicked() then goToHistory = i end
        im.NextColumn()
        im.TextWrapped(self.mgr.history[i].title)
        if im.IsItemClicked() then goToHistory = i end
        im.NextColumn()
      else
        im.Text(tostring(i))
        if im.IsItemClicked() then goToHistory = i end
        im.NextColumn()
        im.TextWrapped(self.mgr.history[i].title)
        if im.IsItemClicked() then goToHistory = i end
        im.NextColumn()
      end

    end
  end
  im.Columns(1)

  if goToHistory ~= nil then
    self.mgr:goToHistory(goToHistory)
  end
  im.EndChild()
  self:End()
end

function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

return _flowgraph_createMgrWindow(C)
