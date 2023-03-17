-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ufe = ui_flowgraph_editor

local C = {}

function C:init(mgr)
  -- make our own custom pins for the borders
  local _createPin = require('/lua/ge/extensions/flowgraph/pin')
  self.transitionPins = {_in = {}, _out = {}}
  for _, d in ipairs({'N','E','S','W'}) do
    local pIn = _createPin(self.graph, self, "in", "transition", "tIn"..d)
    local pOut = _createPin(self.graph, self, "out", "transition", "tOut"..d)
    self.transitionPins._in[d] = pIn
    self.transitionPins._out[d] = pOut
  end
end

function C:customDrawEnd(builder)
  local wp = im.GetWindowPos()
  local pivotSize = 5
  local nodeRect = {x = builder.NodeRect.x - wp.x - pivotSize/2, y = builder.NodeRect.y - wp.y - pivotSize/2, w = builder.NodeRect.w, h = builder.NodeRect.h }

  --im.ImDrawList_AddRect(im.GetWindowDrawList(), builder.NodeRect.top_left(), builder.NodeRect.bottom_right(), im.GetColorU322(im.ImVec4(1, 1, 0, 1)))
  -- setup link strengths for all of these pins.
  ufe.PushStyleVar1(ufe.StyleVar_LinkStrength,0)
  -- in pins are ccw side
  -- setup arrow size for in-Pins
  ufe.PushStyleVar1(ufe.StyleVar_PinArrowSize,20)
  ufe.PushStyleVar1(ufe.StyleVar_PinArrowWidth,20)
  --make each pin individually.
  im.SetCursorPos(im.ImVec2(nodeRect.x, nodeRect.y))
  ufe.PushStyleVar2(ufe.StyleVar_PivotSize,im.ImVec2(nodeRect.w/3,pivotSize))
  ufe.BeginPin(self.transitionPins._in.N.id, ufe.PinKind_Input)
  self.transitionPins._in.N.imPos = im.GetCursorPos()
  ufe.EndPin() ufe.PopStyleVar(1)

  im.SetCursorPos(im.ImVec2(nodeRect.x, nodeRect.y+nodeRect.h*2/3))
  ufe.PushStyleVar2(ufe.StyleVar_PivotSize,im.ImVec2(pivotSize,nodeRect.h/3))
  ufe.BeginPin(self.transitionPins._in.W.id, ufe.PinKind_Input)
  self.transitionPins._in.W.imPos = im.GetCursorPos()
  ufe.EndPin() ufe.PopStyleVar(1)

  im.SetCursorPos(im.ImVec2(nodeRect.x+nodeRect.w*2/3, nodeRect.y+nodeRect.h))
  ufe.PushStyleVar2(ufe.StyleVar_PivotSize,im.ImVec2(nodeRect.w/3,pivotSize))
  ufe.BeginPin(self.transitionPins._in.S.id, ufe.PinKind_Input)
  self.transitionPins._in.S.imPos = im.GetCursorPos()
  ufe.EndPin() ufe.PopStyleVar(1)

  im.SetCursorPos(im.ImVec2(nodeRect.x+nodeRect.w, nodeRect.y))
  ufe.PushStyleVar2(ufe.StyleVar_PivotSize,im.ImVec2(pivotSize,nodeRect.h/3))
  ufe.BeginPin(self.transitionPins._in.E.id, ufe.PinKind_Input)
  self.transitionPins._in.E.imPos = im.GetCursorPos()
  ufe.EndPin() ufe.PopStyleVar(1)

  ufe.PopStyleVar(2)


  -- out pins have no arrows and are cw side
  im.SetCursorPos(im.ImVec2(nodeRect.x+nodeRect.w*2/3, nodeRect.y))
  ufe.PushStyleVar2(ufe.StyleVar_PivotSize,im.ImVec2(nodeRect.w/3,pivotSize))
  ufe.BeginPin(self.transitionPins._out.N.id, ufe.PinKind_Output)
  self.transitionPins._out.N.imPos = im.GetCursorPos()
  ufe.EndPin() ufe.PopStyleVar(1)

  im.SetCursorPos(im.ImVec2(nodeRect.x, nodeRect.y))
  ufe.PushStyleVar2(ufe.StyleVar_PivotSize,im.ImVec2(pivotSize,nodeRect.h/3))
  ufe.BeginPin(self.transitionPins._out.W.id, ufe.PinKind_Output)
  self.transitionPins._out.W.imPos = im.GetCursorPos()
  ufe.EndPin() ufe.PopStyleVar(1)

  im.SetCursorPos(im.ImVec2(nodeRect.x, nodeRect.y+nodeRect.h))
  ufe.PushStyleVar2(ufe.StyleVar_PivotSize,im.ImVec2(nodeRect.w/3,pivotSize))
  ufe.BeginPin(self.transitionPins._out.S.id, ufe.PinKind_Output)
  self.transitionPins._out.S.imPos = im.GetCursorPos()
  ufe.EndPin() ufe.PopStyleVar(1)

  im.SetCursorPos(im.ImVec2(nodeRect.x+nodeRect.w, nodeRect.y+nodeRect.h*2/3))
  ufe.PushStyleVar2(ufe.StyleVar_PivotSize,im.ImVec2(pivotSize,nodeRect.h/3))
  ufe.BeginPin(self.transitionPins._out.E.id, ufe.PinKind_Output)
  self.transitionPins._out.E.imPos = im.GetCursorPos()
  ufe.EndPin() ufe.PopStyleVar(1)

  ufe.PopStyleVar(1)


end


local M = {}

function M.createBase(...)
  local o = require('/lua/ge/extensions/flowgraph/basenode').createBase(...)

  --setmetatable(o, C)
  for k, v in pairs(C) do
    --print('k = ' .. tostring(k) .. ' = '.. tostring(v) )
    o[k] = v
  end
  C.__index = C
  o:init(...)
  return o
end

function M.use(mgr, graph, forceId, derivedClass)
  local o = M.createBase(mgr, graph, forceId)
  -- override the things in the base node
  local baseInit = o.init
  for k, v in pairs(derivedClass) do
    --print('k = ' .. tostring(k) .. ' = '.. tostring(v) )
    o[k] = v
  end
  o:_preInit()
  if o.init ~= baseInit then
    o:init()
  end
  o:_postInit()
  return o
end

return M