-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local fge = ui_flowgraph_editor
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local C = {}
C.windowName = 'fg_stateView'
C.windowDescription = 'State View'

function C:init()
  self.filter = im.ImGuiTextFilterPtr()
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
end

function C:attach(mgr)
  self.mgr = mgr
end

function C:drawStategraphRecursive(graph, depth)
  -- draw the states inside this graph.
  local states = {}
  for _, node in pairs(graph.nodes) do
    if node.nodeType == 'states/stateNode' and node.targetGraph and not node.targetGraph.isStateGraph then
      table.insert(states, node)
    end
  end
  table.sort(states, function(a,b) return a.id<b.id end)
  local name = "["..graph.name.."]"
  for i = 1, depth do name = " - " .. name end
  im.NextColumn()
  im.Text(name)
  im.NextColumn()
  for _, state in ipairs(states) do
    local running = false
    if self.mgr.runningState == 'running' then
      running = self.mgr.states:isRunning(state.id)
    end
    if running then
      editor.uiIconImage(editor.icons.play_circle_filled, im.ImVec2(20, 20))
    else
      editor.uiIconImage(editor.icons.pause_circle_outline, im.ImVec2(20, 20))
    end
    im.NextColumn()
    local name = state.targetGraph.name
    for i = 0, depth do name = " - " .. name end
    im.Text(name)
    im.NextColumn()
  end

  local children = {}
  for _, child in pairs(graph:getChildren()) do table.insert(children, child) end
  table.sort(children, function(a,b) return a.id<b.id end)
  for _, child in ipairs(children) do
    im.Separator()
    self:drawStategraphRecursive(child, depth+1)
  end
end


function C:draw()
  if not editor.isWindowVisible(self.windowName) then return end
  if self:Begin('States View') then

    im.Columns(2)
    im.SetColumnWidth(0,40)
    self:drawStategraphRecursive(self.mgr.stateGraph, 0)
    im.Columns(1)
  end
  self:End()
end

function C:selectNode(node, append)
  fge.SelectNode(node.id, append)
end

return _flowgraph_createMgrWindow(C)
