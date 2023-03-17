-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Compare'
C.icon = "fg_compare"
C.description = "Compares two values based on a comparison function."
C.todo = "Since we allow 'any' type, comparisons should include other types like string comparators"
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node." },
  { dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node." },
  { dir = 'in', type = 'any', name = 'A', description = "First value for comparision." },
  { dir = 'in', type = 'any', name = 'B', description = "Second value for comparison." },
  { dir = 'out', type = 'flow', name = 'true', description = "Gives flow when the comparison returns true." },
  { dir = 'out', type = 'flow', name = 'false', description = "Gives flow when the comparison returns false." },
  { dir = 'out', type = 'bool', name = 'value', hidden = true, description = "The boolean result of the comparison." },
}

C.tags = {"greater", "less", "equals", "if"}

local comparisonOps = getComparisonOps()

function C:init()
  local mySortFunct = function (a,b)
    return a.opName < b.opName
  end
  table.sort(comparisonOps, mySortFunct)
  self.comparison = comparisonOps[1]
  self.compFunc = self.comparison.op
end

function C:drawCustomProperties()
  local reason = nil
  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.TextUnformatted("Comparison Function")
  im.NextColumn()
  if im.BeginCombo("##comparisonFunc", self.comparison.opName, 0) then
    for _,comparison in ipairs(comparisonOps) do
      if im.Selectable1(comparison.opName, comparison.opName == self.comparison.opName) then
        self.comparison = comparison
        self:refreshFunction()
        reason = "Changed function to " .. comparison.opName
      end
    end
    im.EndCombo()
  end
  im.Columns(1)
  im.PopID()
  return reason
end

function C:refreshFunction()
  self.compFunc = self.comparison.op

  local err = nil
  if not self.compFunc then
    self.compFunc = function(a, b) end
    err = 'Invalid comparison: ' .. tostring(self.data.comparisonFunc)
  end
  self:__setNodeError('compare', err)
end

function C:_onPropertyChanged(key, val)
  -- log('I', 'compare', "_onPropertyChanged:  Key = "..tostring(key) .. "  Value = "..tostring(value))
  self:refreshFunction()
end

function C:_onSerialize(res)
  res.opSymbol = self.comparison.opSymbol
end

function C:_onDeserialized(res)
  local opSymbol = nil
  if res.opSymbol then
    opSymbol = res.opSymbol
  elseif res.data.comparisonFunc then
    opSymbol = res.data.comparisonFunc
    self.data.comparisonFunc = nil
  end

  for _, comparison in ipairs(comparisonOps) do
    if opSymbol == comparison.opSymbol then
      self.comparison = comparison
      break
    end
  end
  self:refreshFunction()
end

function C:work()
  -- safeguard for <, >, <=, >= if one operand is nil
  if self.comparison.opSymbol ~= "==" and self.comparison.opSymbol ~="~=" and (self.pinIn.A.value == nil or self.pinIn.B.value == nil) then
    --self:__setNodeError('Nil Error', "One operand is nil!")
    self.mgr:logEvent("Nil Error", "E", 'One Operand is nil!', { type = "node", node = self })
    self.pinOut.value.value = false
    self.pinOut.flow.value = false
    self.pinOut['true'].value = false
    self.pinOut['false'].value = false
  else
    self.pinOut.value.value = self.compFunc(self.pinIn.A.value, self.pinIn.B.value)
    self.pinOut.flow.value = self.pinIn.flow.value
    self.pinOut['true'].value = self.pinOut.value.value
    self.pinOut['false'].value = not self.pinOut.value.value
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.TextUnformatted(self.comparison.opSymbol)
end

return _flowgraph_createNode(C)
