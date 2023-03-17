-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

function C:init(fgEditor)
  self.fgEditor = fgEditor
  self.hasFocus = false
end

function C:Begin(name, flags)
  return editor.beginWindow(self.windowName, name, flags)
end

function C:End()
  self.hasFocus = im.IsWindowFocused(im.FocusedFlags_ChildWindows)
  editor.endWindow()
end

function C:attach(mgr)
  self.mgr = mgr
end

function C:open()

  editor.showWindow(self.windowName)
end

function C:close()
  self.hasFocus = false
  editor.hideWindow(self.windowName)
end

function C:toggle()
  if editor.isWindowVisible(self.windowName)  then
    self:close()
  else
    self:open()
  end
end

function C:_onSerialize(res)
end

function C:__onSerialize()
  local res = {}
  self:_onSerialize(res)
  return res
end

function C:_onDeserialized(data)
end

function C:__onDeserialized(data)
  self:_onDeserialized(data)
  self.hasFocus = false
end

local M = {}

function M.createBase(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end

function M.use(fgEditor, derivedClass)
  local o = M.createBase(fgEditor)
  -- override the things in the base node
  local baseInit = o.init
  for k, v in pairs(derivedClass) do
    o[k] = v
  end

  if o.init ~= baseInit then
    o:init()
  end
  return o
end

return M