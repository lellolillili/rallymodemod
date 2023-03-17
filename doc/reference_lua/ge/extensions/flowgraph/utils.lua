-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local M = {}


function M.getVariableType(value)
  local t = type(value)
  if     t == "boolean"               then t = "bool"
  elseif t == "string"                then -- it's ok already
  elseif t == "number"                then -- it's ok already
  elseif t == "table" and #value == 3 then t = "vec3"
  elseif t == "table" and #value == 4 then t = "quat"
  else t = nil end
  return t
end

function M.isVariableCompatible(value, compType)
  local t = type(value)
  if     t == "boolean"               then return compType == 'bool'
  elseif t == "string"                then return compType == 'string'
  elseif t == "number"                then return compType == 'number'
  elseif t == "table" and #value == 3 then return compType == 'vec3' or compType == 'table'
  elseif t == "table" and #value == 4 then return compType == 'quat' or compType == 'color' or compType == 'table'
  else return false end
end

function M.getDefaultValueForType(typeName)

  if type(typeName) == 'table' then typeName = typeName[1] end

  if typeName == 'number' or typeName == 'any' then
    return 0
  elseif typeName == 'string' then
    return ''
  elseif typeName == 'bool' then
    return true
  elseif typeName == 'vec3' then
    return {0,0,0}
  elseif typeName == 'quat' then
    return {0,0,0,0}
  elseif typeName == 'color' then
    return {1,1,1,1}
  elseif typeName == 'table' then
    return {}
  end

end

function M.showLabel(label, color)
  if color == nil then color = im.ImVec4(1, 0, 0, 0.4) end
  im.SetCursorPosY(im.GetCursorPosY() - im.GetTextLineHeight())
  local size = im.CalcTextSize(label)

  local padding = im.GetStyle().FramePadding
  local spacing = im.GetStyle().ItemSpacing

  im.SetCursorPosX(im.GetCursorPosX() + spacing.x)
  im.SetCursorPosY(im.GetCursorPosY() - spacing.y)

  local rectMin = im.GetCursorScreenPos()
  rectMin.x = rectMin.x - padding.x
  rectMin.y = rectMin.y - padding.y

  local rectMax = im.GetCursorScreenPos()
  rectMax.x = rectMax.x + size.x + padding.x
  rectMax.y = rectMax.y + size.y + padding.y

  im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), rectMin, rectMax, im.GetColorU322(color), size.y * 0.15)
  im.TextUnformatted(label)
end

--- MERGE FUNCTIONS for variable storage ---

local mergeFunctionsAll = {
  first = {
    num = 1,
    description = "Keeps the first value set for this variable.",
    init = function(variable) variable.mergeVal = nil end,
    merge = function(variable, newValue) if variable.mergeVal then return end variable.mergeVal = newValue end,
    finalize = function(variable) variable.value = variable.mergeVal end
  },
  last = {
    num = 2,
    description = "Keeps the last value set for this variable.",
    init = function(variable) variable.mergeVal = nil end,
    merge = function(variable, newValue) variable.mergeVal = newValue end,
    finalize = function(variable) variable.value = variable.mergeVal end
  },
  readOnly = {
    num = 0,
    description = "Makes this variable read only.",
    init = nop,
    merge = nop,
    finalize = nop
  },
}

local mergeFunctionsNumber = {
  min = {
    num = 0,
    description = "Keeps the lowest of all values.",
    init = function(variable) variable.mergeVal = math.huge end,
    merge = function(variable, newValue) variable.mergeVal = math.min(variable.mergeVal, newValue) end,
    finalize = function(variable) variable.value = variable.mergeVal end
  },
  max = {
    num = 1,
    description = "Keeps the highest of all values.",
    init = function(variable) variable.mergeVal = -math.huge end,
    merge = function(variable, newValue) variable.mergeVal = math.max(variable.mergeVal, newValue) end,
    finalize = function(variable) variable.value = variable.mergeVal end
  },
  average = {
    num = 2,
    description = "Keeps the avergae of all set values.",
    init = function(variable) variable.avg = 0 variable.avgCount = 0 end,
    merge = function(variable, newValue) variable.avg = variable.avg + newValue variable.avgCount = variable.avgCount + 1 end,
    finalize = function(variable) variable.value = variable.avgCount > 0 and (variable.avg / variable.avgCount) or variable.value end
  },
  sum = {
    num = 3,
    description = "Keeps the sum of all set values.",
    init = function(variable) variable.mergeVal = 0 end,
    merge = function(variable, newValue) variable.mergeVal = variable.mergeVal + newValue end,
    finalize = function(variable) variable.value = variable.mergeVal end
  }
}

local mergeFunctionsBool = {
  or_ = {
    num = 0,
    description = "Sets the value to true if either of the sets is true.",
    init = function(variable) variable.mergeVal = false end,
    merge = function(variable, newValue) variable.mergeVal = variable.mergeVal or newValue end,
    finalize = function(variable) variable.value = variable.mergeVal end
  },
  and_ = {
    num = 1,
    description = "Sets the value to true if all of the sets are true.",
    init = function(variable) variable.mergeVal = true end,
    merge = function(variable, newValue) variable.mergeVal = variable.mergeVal and newValue end,
    finalize = function(variable) variable.value = variable.mergeVal end
  }
}

local mergeFunctionsVec = {
  average = {
    num = 2,
    description = "Keeps the average of all set values.",
    init = function(variable) variable.mergeVal = {} variable.count = 0 end,
    merge =
    function(variable, newValue)
      if tableIsEmpty(variable.mergeVal) then
        variable.mergeVal = newValue
      else
        for i, value in ipairs(newValue) do
          variable.mergeVal[i] = variable.mergeVal[i] + value
        end
      end
      variable.count = variable.count + 1
    end,
    finalize =
    function(variable)
      variable.value = {}
      for i, value in ipairs(variable.mergeVal) do
        variable.value[i] = variable.count > 0 and (variable.mergeVal[i] / variable.count) or 0
      end
    end
  },
  sum = {
    num = 3,
    description = "Keeps the sum of all set values.",
    init = function(variable) variable.mergeVal = {} end,
    merge =
    function(variable, newValue)
      if tableIsEmpty(variable.mergeVal) then
        variable.mergeVal = newValue
      else
        for i, value in ipairs(newValue) do
          variable.mergeVal[i] = variable.mergeVal[i] + value
        end
      end
    end,
    finalize = function(variable) variable.value = variable.mergeVal end
  }
}

local mergeFunctionsString = {
  concat = {
    num = 0,
    description = "Concatenates all strings.",
    init = function(variable) variable.mergeVal = "" end,
    merge = function(variable, newValue) variable.mergeVal = variable.mergeVal .. newValue end,
    finalize = function(variable) variable.value = variable.mergeVal end
  },
  concatComma = {
    num = 1,
    description = "Concatenates all strings with a comma inbetween.",
    init = function(variable) variable.mergeVal = "" variable.afterFirst = false end,
    merge = function(variable, newValue) variable.mergeVal = variable.mergeVal .. (variable.afterFirst and ',' or '') .. newValue variable.afterFirst = true end,
    finalize = function(variable) variable.value = variable.mergeVal end
  },
  concatSpace = {
    num = 2,
    description = "Concatenates all strings with a space inbetween.",
    init = function(variable) variable.mergeVal = "" variable.afterFirst = false end,
    merge = function(variable, newValue) variable.mergeVal = variable.mergeVal .. (variable.afterFirst and ' ' or '') .. newValue variable.afterFirst = true end,
    finalize = function(variable) variable.value = variable.mergeVal end
  },
  concatNewline = {
    num = 3,
    description = "Concatenates all strings with a newline inbetween.",
    init = function(variable) variable.mergeVal = "" variable.afterFirst = false end,
    merge = function(variable, newValue) variable.mergeVal = variable.mergeVal .. (variable.afterFirst and '\n' or '') .. newValue variable.afterFirst = true end,
    finalize = function(variable) variable.value = variable.mergeVal end
  }
}
local mergeFunctionsAny = {}


local sortedAny = {}
local sortedAll = {}
local sortedNumber = {}
local sortedBool = {}
local sortedVec = {}
local sortedString = {}
for name, val in pairs(mergeFunctionsAll) do
  mergeFunctionsAny[name] = val
  table.insert(sortedAny,{name = name, desc = val.description, num = val.num})
  table.insert(sortedAll,{name = name, desc = val.description, num = val.num})
  table.insert(sortedNumber,{name = name, desc = val.description, num = val.num})
  table.insert(sortedBool,{name = name, desc = val.description, num = val.num})
  table.insert(sortedVec,{name = name, desc = val.description, num = val.num})
  table.insert(sortedString,{name = name, desc = val.description, num = val.num})
end
for name, val in pairs(mergeFunctionsNumber) do
  mergeFunctionsAny['num_'.. name] = val
  table.insert(sortedAny,{name = 'num_'.. name, desc = val.description, num = val.num + 1000})
  table.insert(sortedNumber,{name = name, desc = val.description, num = val.num + 1000})
end
for name, val in pairs(mergeFunctionsBool) do
  mergeFunctionsAny['bool_'.. name] = val
  table.insert(sortedAny,{name = 'bool_'.. name, desc = val.description, num = val.num + 2000})
  table.insert(sortedBool,{name = name, desc = val.description, num = val.num + 1000})
end
for name, val in pairs(mergeFunctionsVec) do
  mergeFunctionsAny['vec_'.. name] = val
  table.insert(sortedAny,{name = 'vec_'.. name, desc = val.description, num = val.num + 3000})
  table.insert(sortedVec,{name = name, desc = val.description, num = val.num + 1000})
end
for name, val in pairs(mergeFunctionsString) do
  mergeFunctionsAny['any_'.. name] = val
  table.insert(sortedAny,{name = 'any_'.. name, desc = val.description, num = val.num + 4000})
  table.insert(sortedString,{name = name, desc = val.description, num = val.num + 1000})
end

table.sort(sortedAny, function(a,b) return a.num < b.num end)
table.sort(sortedAll, function(a,b) return a.num < b.num end)
table.sort(sortedNumber, function(a,b) return a.num < b.num end)
table.sort(sortedBool, function(a,b) return a.num < b.num end)
table.sort(sortedVec, function(a,b) return a.num < b.num end)
table.sort(sortedString, function(a,b) return a.num < b.num end)


M.mergeFuns = {
  all = mergeFunctionsAll,
  number = mergeFunctionsNumber,
  bool = mergeFunctionsBool,
  vec3 = mergeFunctionsVec,
  string = mergeFunctionsString,
  any = mergeFunctionsAny
}
M.sortedMergeFuns = {
  any = sortedAny,
  all = sortedAll,
  number = sortedNumber,
  string = sortedString,
  bool = sortedBool,
  vec3 = sortedVec
}

return M