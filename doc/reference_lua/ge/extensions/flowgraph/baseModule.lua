-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}
C.moduleOrder = 0 -- low first, high later

function C:init(mgr)
  self.mgr = mgr
end
C.hooks = {}
-- functions you can use
function C:clear() end
function C:onUpdate(dtReal, dtSim, dtRaw) end
function C:executionStopped() end
function C:executionStarted() end
function C:onClear() self:executionStopped() end

-- use these if needed.
--function C:preTrigger() end
--function C:afterTrigger() end

local M = {}

function M.createBase(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end

function M.use(mgr, derivedClass)
  local o = M.createBase(mgr)
  -- override the things in the base node
  local baseInit = o.init
  for k, v in pairs(derivedClass) do
    --print('k = ' .. tostring(k) .. ' = '.. tostring(v) )
    o[k] = v
  end
  --o:_preInit()
  if o.init ~= baseInit then
    o:init()
  end
  --o:_postInit()
  return o
end

return M