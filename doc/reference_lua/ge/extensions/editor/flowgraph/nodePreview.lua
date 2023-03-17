-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local fg_utils = require('/lua/ge/extensions/flowgraph/utils')
local createBuilder = require('/lua/ge/extensions/flowgraph/builder')

local C = {}
C.windowKind = 'nodePreview'

function C:attach(mgr)
  self.mgr = mgr
  if mgr then
    self.dummyGraph = self.mgr:createGraph('nodePreview', true)
  end
end

function C:init()
  self.hoverInstance = nil
  self.hover = nil
  self.mode = "node"
  self.hoverGraph = nil
  self.lastHoverPath = nil
  self.previewEctx = nil
  self.previewSize = im.ImVec2(200, 200)
end

function C:setNode(node)
  self.hover = node
  self.mode = "node"
  --print("Setting Node!")
end

function C:setMacro(macro)
  self.hover = macro
  self.mode = "macro"
end

function C:setGraph(graph)
  self.hover = graph
  self.mode = "graph"
 -- print("Setting Graph!")
end

function C:draw()
  local savedEctx = ui_flowgraph_editor.GetCurrentEditor()
  if self.hover and ((self.mode == "node" and self.hover.node)  or (self.mode == "graph")) then
    --dumpz(self.hover, 2)
    if not self.previewEctx then
      self.previewEctx = ui_flowgraph_editor.CreateEditor(ui_imgui.ctx)
    end

    ui_flowgraph_editor.SetCurrentEditor(self.previewEctx)

    --dump(self.hover)
    --self.popupMousePos.x = self.popupMousePos.x + 300
    --im.SetCursorScreenPos(self.popupMousePos)
    im.BeginTooltip()

    im.BeginChild1("##nodepreview", self.previewSize, false)
    ui_flowgraph_editor.Begin('preview', im.ImVec2(0, 0), true)

    local builder = createBuilder()
    builder.drawDebug = self.debugEnabled
    local style = im.GetStyle()
    if self.mode == "node" then
      if not self.hoverInstance or self.hover.path ~= self.lastHoverPath then
        self.lastHoverPath = self.hover.path
        self.hoverInstance = self.hover.create(self.mgr, self.dummyGraph)
      end
      self.hoverInstance:draw(builder, style)
    elseif self.mode == "graph" then
      --print(self.hover.name)
      if not self.hoverInstance or self.hover.name ~= self.lastHoverPath then
        self.lastHoverPath = self.hover.name
      end
        --self.hoverInstance = self.hover.create(self.mgr, self.hover)
      --print("Made Graph...")

      for id, node in pairs(self.hover.nodes) do
        ui_flowgraph_editor.SetCurrentEditor(self.fgEditor.ectx)
        local pos = ui_flowgraph_editor.GetNodePosition(id)

        ui_flowgraph_editor.SetCurrentEditor(self.previewEctx)
        local status, err, res = xpcall(node.draw, debug.traceback, node, builder, style, drawType)
        if not status then
          log('E', 'node.'..tostring('drawGraph'), tostring(err))
          node._isSelected = true
          node:__setNodeError('work', 'Error while executing node:_drawMiddle(): ' .. tostring(err))
        end
        ui_flowgraph_editor.SetNodePosition(node.id, pos)
      end

      for _, link in pairs(self.hover.links) do
        link:draw()
      end

    end
    --ui_flowgraph_editor.CenterNodeOnScreen(self.hoverInstance.id)
    ui_flowgraph_editor.NavigateToContent(0.01)
    ui_flowgraph_editor.End()
    im.EndChild()
    im.Separator()
    im.PushTextWrapPos(self.previewSize.x)
    if self.mode == "node" then
      im.TextUnformatted(self.hover.node.name .. ' (' .. self.hover.path .. ')')
    elseif self.mode == "graph" then
      if editor.getPreference("flowgraph.debug.displayIds") then
        im.TextUnformatted(self.hover.id .. " - " .. self.hover.name)
      else
        im.TextUnformatted(self.hover.name)
      end
    end
    --im.Separator()
    if self.hover.node then
      if self.hover.node.description then
        im.TextUnformatted(self.hover.node.description)
      end
      if self.hover.node.todo then
        im.TextUnformatted("TODO: " .. self.hover.node.todo)
      end
      --if self.hover.node.author then
      --  im.TextUnformatted('Author: ' .. self.hover.node.author)
      --end
    end
    im.PopTextWrapPos()
    im.EndTooltip()
  elseif self.hover and (self.mode == "macro") then
    im.BeginTooltip()
    im.PushTextWrapPos(self.previewSize.x)
    if self.mode == "macro" then
      im.TextUnformatted(self.hover.name .. " - " .. self.hover.type)
      if self.hover.description then
        im.TextUnformatted(self.hover.description)
      end
    end
    im.PopTextWrapPos()
    im.EndTooltip()
  end

  ui_flowgraph_editor.SetCurrentEditor(savedEctx)
end

return _flowgraph_createMgrWindow(C)
