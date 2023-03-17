-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Concat'
C.description = "Combines all input strings into one string."
C.todo = "Auto-Pin increment does not work with hardcoded pins. As a workaround, boolean values have to be stringified manually."
C.category = 'simple'

C.color = ui_flowgraph_editor.nodeColors.string
C.pinSchema = {
  {dir = 'in', type = 'any', name = 'value1', description = 'Element to be concattenated.'},
  {dir = 'out', type = 'string', name = 'value', description = 'The resulting string.'},
}
C.obsolete = "Use the Format String node instead."
C.tags = {}

function C:init()
  self.pinOut.value.value = ""
  self.inputCache = {}
  self.savePins = true
end


function C:_executionStarted()
  self.inputCache = {}
end

-- compare the list of concat inputs, return false if they're the same as last time, return true if any input has changed
-- also make sure to update the inputCache (which will be used for the comparison next time)
function C:updateCache()
  local dirty = false
  local i = 0

  -- update all new inputs
  for _,pin in ipairs(self.pinList) do
    -- skip unsuitable pins that don't affect the computation of the output concat string
    if pin.direction == "in" and pin.type ~= "flow" then
      if self.pinIn[pin.name].value ~= nil and self.pinIn[pin.name].value ~= false then
        local newValue = tostring(self.pinIn[pin.name].value)
        -- skip over nil pins, as they don't introduce any new characters to the output concat string, AND they will stop table iteration
        if newValue ~= nil then
          i = i + 1
          dirty = dirty or (tostring(self.inputCache[i]) ~= newValue)
          self.inputCache[i] = newValue
        end
      end
    end
  end

  -- remove all old additional cached inputs (that no longer exist)
  for i=i+1, #self.inputCache do
    dirty = true
    self.inputCache[i] = nil
  end

  return dirty
end

function C:work()
  local dirty = self:updateCache()
  if dirty then
    self.pinOut.value.value = table.concat(self.inputCache, "")
  end
end

function C:onLink(link)
  if not self.currentlyCleaning then
    self:cleanupPins()
  end
end
function C:onUnlink(link)
  if not self.currentlyCleaning then
    self:cleanupPins()
  end
end

-- make sure we have one (and only one) empty pin available at the end of our inPins
-- also make sure we preserve pins that have become empty inbetween the rest of pins (don't remove those)
function C:cleanupPins()
  self.currentlyCleaning = true
  local nSuitablePins = 0 -- counter of suitable pins (only 'in' pints, excluding 'flow' pins)
  local emptyTrailingPins = {} -- list of empty suitable pins at the end of our pin list

  -- find out suitable pins, and which of them are empty & the end of the list
  for _,pin in ipairs(self.pinList) do
    if pin.direction == "in" and pin.type ~= "flow" then
      nSuitablePins = nSuitablePins + 1
      local pinName = pin.name
      if self.pinInLocal[pinName]:isUsed() then
        table.clear(emptyTrailingPins)
      else
        table.insert(emptyTrailingPins, pinName)
      end
    end
  end
  local nEmptyTrailingPins = #emptyTrailingPins

  -- remove all empty trailing pins, except one of them (always leave an empty available pin at the end)
  for j=2, nEmptyTrailingPins do
    local pinName = emptyTrailingPins[j]
    local pin = self.pinInLocal[pinName]
    self:removePin(pin)
  end

  -- make sure there's at least one empty trailing pin
  if nEmptyTrailingPins == 0 then
    local newPinName = "value"..(nSuitablePins+1)
    self:createPin('in', "any", newPinName, nil, 'Element to be concattenated.')
  end
  self.currentlyCleaning = false
end

function C:drawMiddle(builder, style)
end

return _flowgraph_createNode(C)
