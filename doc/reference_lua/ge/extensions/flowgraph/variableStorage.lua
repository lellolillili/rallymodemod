-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local C = {}

local types = {{
    name = "string"
  },{
    name = "number"
  },{
    name = 'bool'
  },{
    name = 'vec3'
  },{
    name = 'quat'
  },{
    name = 'color'
  }
}

function C:init(mgr)
  self.mgr = mgr
  self.id = mgr:getNextUniqueIdentifier()
  self.variables = { }
  self.variableChanges = {}
  self.sortedVariableNames = {}
  self.customVariableOrder = {}
  local mgrTypes = ui_flowgraph_editor.getTypes()
  for _, t in ipairs(types) do
    t.color = mgrTypes[t.name].color
    t.icon = mgrTypes[t.name].icon
  end
  self.types = types
end

function C:getName()
  return "(" .. self.mgr.name .. " / " .. self.mgr.id .. ")"
end

function C:getTypes()
  return self.types
end

function C:getMergeStrats(type)
  return fg_utils.sortedMergeFuns[type] or {}
end

function C:variableExists(name)
  return self.variables[name] ~= nil
end

-- second return value is false if the variable is nonexistent, otherwise true
function C:get(name)
  if self.variables[name] == nil then
    log("E", "VariableStorage", "Tried getting value of " .. dumps(name) .. " " .. self:getName())
    return nil, false
  end
  return self.variables[name].value, true
end

-- second return value is false if the variable is nonexistent, otherwise true
function C:getFull(name)
  if self.variables[name] == nil then
    log("E", "VariableStorage", "Tried getting full value of " .. dumps(name) .. " " .. self:getName())
    print(debug.tracesimple())
    return nil, false
  end
  return self.variables[name], true
end

function C:clear()
  table.clear(self.variableChanges)
  table.clear(self.variables)
  self:refreshSortedVariableNames()
end

function C:refreshSortedVariableNames()
  self.sortedVariableNames = {}
  local list = {}
  for name, elem in pairs(self.variables) do
      table.insert(list, {name = name, index = elem.index})
  end
  table.sort(list, function(a,b) return a.index < b.index end)
  for i, elem in ipairs(list) do
    self.sortedVariableNames[i] = elem.name
  end
end

-- moves the variable with "name" to be after "newIdx" index (relative to original order indexes)
function C:changeCustomVariableOrder(name, newIdx)
  if not self.variables[name] then return end
  local oldIdx = tableFindKey(self.customVariableOrder, name)
  if oldIdx < newIdx then
    newIdx = newIdx -1
  end
  table.remove(self.customVariableOrder, oldIdx)
  table.insert(self.customVariableOrder, newIdx, name)
end

function C:getMaxSortIndex()
  local ret = 0
  for _,v in pairs(self.variables) do
    if v.index > ret then ret = v.index end
  end
  return ret
end
-- returns false if variable already exists, otherwise true
function C:addVariable(name, value, type, mergeStrat, fixedType, undeletable)
  if self.variables[name] ~= nil then
    log("E", "VariableStorage", "Tried adding variable: " .. dumps(name) .. " / " ..  dumps(value) .. " to " .. self:getName())
    return false
  end
  self.variables[name] = {
    name = name,
    baseValue = value,
    value = value,
    index = self:getMaxSortIndex()+1,
    type = type,
    fixedType = fixedType,
    undeletable = undeletable,
  }
  self:setMergeStrat(name, mergeStrat)
  self:refreshSortedVariableNames()
  table.insert(self.customVariableOrder, name)
  return true
end

-- returns false if variable nonexistent, otherwise true
function C:setMergeStrat(name, strat)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried setting MergeStart value nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].mergeStrat = strat
  if fg_utils.mergeFuns.all[strat] then
    self.variables[name].mergeFuns = fg_utils.mergeFuns.all[strat]
  elseif fg_utils.mergeFuns[self.variables[name].type] and fg_utils.mergeFuns[self.variables[name].type][strat] then
    self.variables[name].mergeFuns = fg_utils.mergeFuns[self.variables[name].type][strat]
  else
    --log('E', '', 'Invalid Merge function! ' .. tostring(strat))
    local default = "last"
    if self.variables[name].type == 'number' then default = "max" end
    if self.variables[name].type == 'bool' then default = "or_" end
    --log('E', '', 'Using Default strat for type ' .. self.variables[name].type .. " : " .. default )
    self:setMergeStrat(name, default)
    return true
  end
  self.variables[name].mergeFuns.init(self.variables[name])
  return true
end
-- returns false if variable nonexistent or has fixed type, otherwise true
function C:updateType(name, type)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried updating type of nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  if self.variables[name].fixedType then
    log("E", "VariableStorage", "Tried updating type of fixed-type variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].type = type
  if type == 'string' then
    self.variables[name].baseValue = tostring(self.variables[name].baseValue) or ""
    self.variables[name].value = tostring(self.variables[name].value) or ""
  elseif type == 'bool' then
    self.variables[name].baseValue = false
    self.variables[name].value = false
  elseif type == 'number' then
    self.variables[name].baseValue = tonumber(self.variables[name].baseValue) or 0
    self.variables[name].value = tonumber(self.variables[name].value) or 0
  elseif type == 'vec3' then
    self.variables[name].baseValue = {0,0,0}
    self.variables[name].value = {0,0,0}
  elseif type == 'color' then
    self.variables[name].baseValue = {0,0,0,1}
    self.variables[name].value = {0,0,0,1}
  elseif type == 'quat' then
    self.variables[name].baseValue = {0,0,0,0}
    self.variables[name].value = {0,0,0,0}
  end
  self:setMergeStrat(name, 'last')
  -- update nodes
  local all = {}
  for _, gr in pairs(self.mgr.graphs) do if gr.type ~= "instance" then table.insert(all, gr) end end
  for _, gr in pairs(self.mgr.macros) do if gr.type ~= "instance" then table.insert(all, gr) end end
  local vNodes = {}
  for _, graph in pairs(all) do
    for _, node in pairs(graph.nodes) do
      if node.nodeType == 'types/getVariable' or node.nodeType == 'types/setVariable' then
        node:typeUpdated(self, name, type)
      end
    end
  end
  return true
end
-- returns false if variable nonexistent, otherwise true
function C:setFixedType(name, fixedType)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried setting fixed-type-property of nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].fixedType = fixedType or nil
  return true
end
-- returns false if variable nonexistent, otherwise true
function C:setMonitor(name, monitor)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried setting monitor-property of nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].monitored = monitor or false
  return true
end
-- returns false if variable nonexistent, otherwise true
function C:setKeepAfterStop(name, keep)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried setting keep-after-stop-property of nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].keepAfterStop = keep or false
  return true
end
-- returns false if variable nonexistent, otherwise true
function C:setActivityAttemptData(name, activityAttemptData)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried setting activityAttemptData property of nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].activityAttemptData = activityAttemptData or false
  return true
end
-- returns false if variable nonexistent or undeletable, otherwise true
function C:removeVariable(name)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried removing nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  if self.variables[name].undeletable then
    log("E", "VariableStorage", "Tried removing undeletable variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name] = nil
  self:refreshSortedVariableNames()
  local customOrderIndex = tableFindKey(self.customVariableOrder, name)
  if customOrderIndex then
    table.remove(self.customVariableOrder, customOrderIndex)
  end
  return true
end
-- returns false if variable nonexistent or type mismatch, otherwise true
function C:changeBase(name, value)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried chaning base value of nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  if not fg_utils.isVariableCompatible(value, self.variables[name].type) then
    log("E", "VariableStorage", "Tried chaning base value variable, but type mismatch (old:"..self.variables[name].type..", new:"..fg_utils.getVariableType(value)..") for variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].baseValue = value
  self.variables[name].value = value
  return true
end
-- returns false if variable nonexistent, otherwise true
function C:changeInstant(name, value)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried changing instant value of nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].value = value
  return true
end
-- returns false if variable nonexistent or value is nil, otherwise true
function C:change(name, value)
  if not self.variables[name] then
    log("E", "VariableStorage", "Tried changing value of nonexistent variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  if value == nil then
    log("E", "VariableStorage", "Tried changing value to invalid nil for variable " .. dumps(name) .. " " .. self:getName())
    return false
  end
  self.variables[name].mergeFuns.merge(self.variables[name], value)
  self.variableChanges[name] = true
  return true
end

function C:finalizeChanges()
  for name, _ in pairs(self.variableChanges) do
    self.variables[name].mergeFuns.finalize(self.variables[name])
    self.variables[name].mergeFuns.init(self.variables[name])
  end
  table.clear(self.variableChanges)
end

function C:_onClear()
  self:_executionStopped()
end

function C:_executionStopped()
  table.clear(self.variableChanges)
  for name, var in pairs(self.variables) do
    if not var.keepAfterStop then
      self:changeInstant(name, var.baseValue)
    else
      self:changeBase(name, var.value)
    end
  end
end

function C:_onSerialize()
  local ret = {
    list = {}
  }
  for name, val in pairs(self.variables) do
    table.insert(ret.list, {
      name = name,
      value = val.baseValue,
      index = val.index,
      type = val.type,
      mergeStrat = val.mergeStrat,
      fixedType = val.fixedType,
      undeletable = val.undeletable,
      monitored = val.monitored,
      keep = val.keepAfterStop,
      activityAttemptData = val.activityAttemptData
    })
  end
  ret.customVariableOrder = self.customVariableOrder
  return ret
end

function C:_onDeserialized(data)
  if not data then return end
  self.variables = {}
  self.sortedVariableNames = {}
  if not data.list then
    local oldData = deepcopy(data)
    data = {list = data}
  end
  table.sort(data.list, function(a,b)
    if a.index == b.index then
      return a.name < b.name
    else
      return a.index < b.index
    end

  end)
  for _, element in ipairs(data.list) do
    self:addVariable(element.name, element.value, element.type, element.mergeStrat, element.fixedType, element.undeletable)
    if element.monitored then
      self:setMonitor(element.name, element.monitored)
    end
    if element.keep then
      self:setKeepAfterStop(element.name, element.keep)
    end
    if element.activityAttemptData then
      self:setActivityAttemptData(element.name, element.activityAttemptData)
    end
  end
  self:refreshSortedVariableNames()
  self.customVariableOrder = self.customVariableOrder or data.customVariableOrder

end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end