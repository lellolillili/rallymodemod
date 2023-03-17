-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')


local C = {}

C.name = 'I/O'
C.macro = 1
C.description = "Handles IO from and to parent graph."
C.hidden = true
C.undeleteable = true

-- this node serializes it's pins, name and color

function C:init()
  self.savePins = true
  self.ioType = "io" -- must be "in" or "out"
  self.clearOutPinsOnStart = false
  self.ignoreAsRoot = true
end

function C:_onSerialize(res)
  res.name = self.name

  local col = self.color
  res.color = {col.x, col.y, col.z, col.w}
  if self.ioType == "io" then
    log('E', '', 'I/O node has no in/out type! ID: ' .. self.id)
  end
  res.ioType = self.ioType
end

function C:_onDeserialized(nodeData)
  self.name = nodeData.name
  self.color = im.ImVec4(nodeData.color[1], nodeData.color[2], nodeData.color[3], nodeData.color[4])
  self.ioType = nodeData.ioType
  if self.ioType == 'in' then
    self.allowCustomOutPins = true
  else
    self.allowCustomInPins = true
  end

end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.targetGraph then
    im.Text(self.targetGraph.name)
  end
  im.Text("...")
  if im.IsItemHovered() then
    -- display blue rectangle when node is hovered
    local cursor = im.GetCursorPos()
    local itemSize = {x = 100, y = 100}
    --[[im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                          cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                          im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                          cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                          im.GetColorU321(im.Col_HeaderHovered), 1, 1)
]]

    if self.mgr.fgEditor then
      self.mgr.fgEditor.nodePreviewPopup:setGraph(self.targetGraph)
    end

  end
end

function C:doubleClicked()
  if self.targetGraph then
    self.mgr:selectGraph(self.targetGraph)
  end
end

function C:work()
  -- when the flow reaches this node, we can consider the subgraph "complete"
  -- and adjust the pins of the integrated node.
  -- these are not connected and are only for visibility
  if self.ioType == 'out' then
    if self.integratedNode then
      self.integratedNode:updatePins()
    end
  end
end

return _flowgraph_createNode(C)
