-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Generic Set/Get Variable'
C.icon = "wb_cloudy"
C.description = 'Sets or gets a variable.'
C.category = 'repeat_instant'

C.todo = "More generalization by changin the varName/suffix to any pins and increase number of pins."
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'in', type = 'string', name = 'varName', description = 'Defines the name of the variable.' },
  { dir = 'in', type = 'number', name = 'suffix', description = 'Defines an optional suffix for the variable name.' },
}

C.value = nil

function C:init()
  self.getter = true
  self.global = true
  self:setupGetPins()
end

function C:work()
  if not self.pinIn.varName.value then return end
  if self.currentGlobal ~= self.global then
    self.target = self.global and self.mgr.variables or self.mgr.graph.variables
    self.currentGlobal = self.global
  end
  local varName = self.pinIn.varName.value
  if self.pinIn.suffix.value then
    varName = varName..self.pinIn.suffix.value
  end
  if self.getter then
    local val = self.target:get(varName)
    if val then
      self.pinOut.val.value = val
    end
  else
    self.target:change(varName, self.pinIn.val.value)
  end
  self.pinOut.flow.value = self.pinIn.flow.value
end


function C:_onSerialize(res)
  res.getter = self.getter
  res.global = self.global
end

function C:_onDeserialized(nodeData)
  self.getter = nodeData.getter
  self.global = nodeData.global
  if self.getter then
    self:setupGetPins()
  else
    self:setupSetPins()
  end
end

function C:setupGetPins()
  self.name = "Generic Getter"
  self:removePin(self.pinInLocal.val)
  self:removePin(self.pinOut.val)
  self:createPin('out','any','val')
end

function C:setupSetPins()
  self.name = "Generic Setter"
  self:removePin(self.pinOut.val)
  self:removePin(self.pinInLocal.val)
  self:createPin('in','any','val')
end


function C:drawCustomProperties()
  local reason = nil
  local global = im.BoolPtr(self.global)
  if im.Checkbox("Use Project as Source##".. self.id, global) then
    self.global = global[0]
  end
  local getter = im.BoolPtr(self.getter)
  if im.Checkbox("Is Getter##".. self.id, getter) then
    self.getter = getter[0]
    if self.getter then
      self:setupGetPins()
    else
      self:setupSetPins()
    end
  end
end


return _flowgraph_createNode(C)
