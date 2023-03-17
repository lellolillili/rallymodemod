-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 000 -- low first, high later

C.idCounter = 0
function C:getFreeId()
  self.idCounter = self.idCounter +1
  return self.idCounter
end

function C:init()
  self.variables = require('/lua/ge/extensions/flowgraph/variableStorage')(self.mgr)
  self:clear()
end

function C:clear()
  self.variables:clear()
  self.buttons = {}
  self.buttonsChanged = true
  self.idCounter = 0
  guihooks.trigger('CustomFGButtons', {})
end

-- adds a new Button.
function C:addButton(data)
  local id = self:getFreeId()

  self.variables:addVariable(id.."label", data.label or ("Button " .. id), 'string')
  self.variables:addVariable(id.."style", data.style or "default", 'string')
  self.variables:addVariable(id.."active", (data.active == nil and true) or data.active, 'bool')
  self.variables:addVariable(id.."order", data.order or id, 'number')
  self.variables:addVariable(id.."clicked", false, 'bool')
  self.variables:addVariable(id.."complete", false, 'bool')

  local button = {
    id = id,
    label = self.variables:getFull(id.."label"),
    style = self.variables:getFull(id.."style"),
    active = self.variables:getFull(id.."active"),
    order = self.variables:getFull(id.."order"),
    clicked = self.variables:getFull(id.."clicked"),
    complete = self.variables:getFull(id.."complete"),
  }
  self.buttons[id] = button
  self.buttonsChanged = true
  return id
end

function C:getButton(id)
  return self.buttons[id]
end

function C:set(id, field, val) self.variables:change(id..field, val) self.buttonsChanged = true end

function C:buttonClicked(id)
  self.variables:change(id.."clicked", true)
  self.variables:change(id.."complete", true)
end

function C:getCmd(id)
  return 'core_flowgraphManager.getManagerByID('..self.mgr.id..').modules.button:buttonClicked('..id..')'
end

local function orderSort(a,b) if a.order == b.order then return a.id < b.id end return a.order < b.order end
function C:afterTrigger()
  self.variables:finalizeChanges()
  if self.buttonsChanged then
    local data = { }
    for id, btn in pairs(self.buttons) do
      if btn.active.value then
        table.insert(data,
        {
          name = btn.label.value,
          fun = self:getCmd(id),
          active = btn.active.value,
          order = btn.order.value,
          style = btn.style.value
        })
      end
    end
    table.sort(data, orderSort)
--    dumpz(data, 2)
    guihooks.trigger('CustomFGButtons', data)
  end
  self.buttonsChanged = nil
  for id, btn in pairs(self.buttons) do
    self.variables:change(id.."clicked", false)
  end
end

function C:executionStopped()
 -- dump("Clearing Buttons Table")
  self:clear()
end

return _flowgraph_createModule(C)