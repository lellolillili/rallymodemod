-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = "Boolean Expression"
C.icon = "fg_gate_icon_and"
C.description = "Parses a mathematical expression."
C.category = 'simple'
C.todo = "add a safe mode for when input is nil. Or change so it only calculates when input is not nil."

C.pinSchema = {
  { dir = 'in', type = 'bool',  name = 'a', description = 'A term of the expression.' },
  { dir = 'in', type = 'bool', name = 'b', description = 'A term of the expression.' },
  { dir = 'out', type = 'bool', name = 'value', description = 'The result of the calculation.' },
}

C.tags = {'math','arithmetic','vector'}

C.templateExpressions = {
  {
    name = "AND",
    description = "Puts out true, if both a and b are true.",
    expression = "a and b",
    pinInfo = {
      { pin = "a", type = 'bool', description = "A term of the expression."},
      { pin = "b", type = 'bool', description = "A term of the expression."},
    }
  },
  {
    name = "OR",
    description = "Puts out true, if either a or b are true.",
    expression = "a or b",
    pinInfo = {
      { pin = "a", type = 'bool', description = "A term of the expression."},
      { pin = "b", type = 'bool', description = "A term of the expression."},
    }
  },
  {
    name = "XOR",
    description = "Puts out true, if either only a or b is true.",
    expression = "(a and not b) or (b and not a)",
    pinInfo = {
      { pin = "a", type = 'bool', description = "A term of the expression."},
      { pin = "b", type = 'bool', description = "A term of the expression."},
    }
  },
  {
    name = "NAND",
    description = "Puts out true, if a and b are not true.",
    expression = "not (a and b)",
    pinInfo = {
      { pin = "a", type = 'bool', description = "A term of the expression."},
      { pin = "b", type = 'bool', description = "A term of the expression."},
    }
  }
}

function C:drawCustomProperties()
  local reason = nil
  local expr = self.data.expression or ""
  local currentTemplate = nil
  for _, template in ipairs(self.templateExpressions) do
    if template.expression == expr then
      currentTemplate = template
    end
  end
  im.PushItemWidth(im.GetContentRegionAvailWidth()-25)
  if im.BeginCombo("##templateExpressions", currentTemplate and currentTemplate.name or "Custom Expression") then
    for _, template in ipairs(self.templateExpressions) do
      if im.Selectable1(template.name, template.expression == expr) then
        self.data.expression = template.expression
        reason = "Changed Expression to "..template.expression
      end
      ui_flowgraph_editor.tooltip(template.description)
    end
    im.EndCombo()
  end
  if currentTemplate then
    im.Text(currentTemplate.description)
    for _, pin in ipairs(currentTemplate.pinInfo) do
      self.mgr:DrawTypeIcon(pin.type, true, 1)
      ui_flowgraph_editor.tooltip(dumps(pin.type))
      im.SameLine()
      im.Text(pin.pin .. " - " .. pin.description)
    end
  end
  im.PopItemWidth()
  return reason
end


function C:buildBaseEnv()
  local env = {}

  --create metable to give the env access to our pin data, exceptions while accessing stuff here are expected and will be catched by the pcall during execution
  env.__pinIn = self.pinIn
  setmetatable(
    env,
    {
      __index = function(table, key)
        local val = table.__pinIn[key].value
        return val
      end
    }
  )

  return env
end

function C:parseExpression()
  --check if we find a *single standalone* "=" sign and abort parsing if found. >=, <=, == and ~= are allowed to support boolean operations
  local expression = self.data.expression
  if expression:find("[^<>~=]=[^=]") then
    return nil, "Assignments are not supported inside expressions!"
  end
  if expression:find("[^(and)(or)(not)%l%s%(%)]") then
    return nil, "Only boolean expressions are supported!"
  end
  --print(expression)
  --load the now sanitized and sandbox checked code with our custom environment
  local exprFunc, message = load("return " .. expression, nil, "t", self.expressionEnv)
  if exprFunc then
    return exprFunc, nil
  else
    --syntax error most likely
    return nil, "Parsing expression failed: " .. message
  end
end

function C:work()
  if self.data.safeMode then
    for _, p in ipairs(self.activePinList or {}) do
      if self.pinIn[p].value == nil then return end
    end
  end
  local result, error
  --check if we need to rebuild the expression func
  if self.lastBuiltExpression ~= self.data.expression then
    self.lastBuiltExpression = nil --nil our tracker, otherwise we can end up with no func
    if self.data.expression:len() <= 0 then
      error = "Please enter a valid expression"
    else
      local func
      func, error = self:parseExpression() --build new func
      self.expressionFunc = func
      if func then
        self.lastBuiltExpression = self.data.expression --save the last built expression func in the tracker
      end
    end
  end

  if self.expressionFunc then
    --execute the loaded code in protected mode to catch any non syntax errors
    local success
    success, result = pcall(self.expressionFunc)
    if not success then
      error = "Executing expression failed: " .. result
      result = nil
    end
  end
  self.pinOut.value.value = result
  self:__setNodeError("expression", error)
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.TextUnformatted(self.data.expression)
end

function C:onLink(link)
  if tableSize(self.pinInLocal) <= tableSize(self.pinIn) then
    local pinName = string.char(97 + tableSize(self.pinIn))
    self:createPin("in", "bool", pinName, 0, "A term of the expression.")
  end
end

function C:_executionStarted()
  self.activePinList = {}
  --dumpz(self.graph.links,2)
  for _, l in pairs(self.graph.links) do
    if l.targetNode.id == self.id then
      table.insert(self.activePinList, l.targetPin.name)
    end
  end
  --dumpz(self.activePinList,2)
end

function C:_onDeserialized(nodeData)
  self:parseExpression()
end

function C:onUnlink(link)
  --dump(link.targetPin.name)
end

function C:init()
  self.data.safeMode = true
  self.data.expression = ""
  self.lastBuiltExpression = nil
  self.expressionFunc = nil
  self.expressionEnv = self:buildBaseEnv()
  self.vecCache = {}
  self.quatCache = {}
  local keywordWhiteList = {"not", "true", "false", "nil"}
  self.keyworkdWhiteListLookup = {}
  for _, v in pairs(keywordWhiteList) do
    self.keyworkdWhiteListLookup[v] = true
  end
end

return _flowgraph_createNode(C)
