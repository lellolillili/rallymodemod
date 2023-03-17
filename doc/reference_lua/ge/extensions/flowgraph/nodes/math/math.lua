-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = "Expression"
C.icon = "fg_expression"
C.description = "Parses a mathematical expression."
C.category = 'simple'
C.todo = "add a safe mode for when input is nil. Or change so it only calculates when input is not nil."

C.pinSchema = {
  { dir = 'in', type = { 'number', 'vec3', 'quat' }, name = 'a', description = 'A term of the expression.' },
  { dir = 'in', type = { 'number', 'vec3', 'quat' }, name = 'b', description = 'A term of the expression.' },
  { dir = 'out', type = { 'number', 'vec3', 'quat' }, name = 'value', description = 'The result of the caluclation.' },
}

C.tags = {'math','arithmetic','vector'}

C.templateExpressions = {
  {
    name = "Distance between two positions",
    description = "Calculates the distance between two positions.",
    expression = "(a-b):length()",
    pinInfo = {
      { pin = "a", type = 'number', description = "The first position"},
      { pin = "b", type = 'number', description = "The first position"},
    }
  },
  {
    name = "Lerping between two values",
    description = "Smoothly changes a value from one to another, according to a lerping parameter. a and b can be number, vec3 or quat, but need to be the same type.",
    expression = "lerp(a,b,c)",
    pinInfo = {
      { pin = "a", type = {'number','vec3','quat'}, description = "The first value"},
      { pin = "b", type = {'number','vec3','quat'}, description = "The second value"},
      { pin = "c", type = 'number', description = "The lerping parameter. 0 means value a, 1 means value b."},
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



--function used as a case selector, input can be both int and bool as the first argument, any number of arguments after that
--in case it's a bool, it works like a ternary if, returning the second param if true, the third if false
--if the selector is an int n, it simply returns the nth+1 param it was given, if n > #params it returns the last given param
local function case(selector, ...)
  local index = 0
  local selectorType = type(selector)

  if selectorType == "boolean" then
    index = selector and 1 or 0
  elseif selectorType == "number" then
    index = math.floor(selector) --make sure we have an int for table access
  else
    log("E", "jbeam.expressionParser.parse", "Only booleans and numbers are supported as case selectors! Defaulting to last argument... Type: " .. selectorType)
  end

  local arg = {...}
  return arg[index] or arg[select("#", ...)] --fetch value from given index or from the last index
end

function C:buildBaseEnv()
  --we build our custom environment for the parsed lua from jbeam variables
  --we also include a list of variables from the pc file so that we can keep backwards compatibility with (now) removed variables
  local env = {}
  --include all math functions and constants
  for k, v in pairs(math) do
    env[k] = v
  end

  --also include a few of our own math functions
  env.linearScale = linearScale
  env.clamp = clamp
  env.round = round
  env.sign = sign
  env.quatFromDir = quatFromDir
  env.smoothstep = smoothstep
  env.smootherstep = smootherstep
  env.smoothmin = smoothmin
  env.terrainHeight = function(v) return core_terrain and (core_terrain.getTerrainHeight(v) or v.z) or v.z end
  env.case = case

  env.vec3 = vec3
  env.quat = quat
  env.euler = quatFromEuler
  env.quatFromEuler = quatFromEuler

  env.pingpong = function(t, max)
    local v = (t % (2 * max))
    if v > max then
      return max - (v - max)
    else
      return v
    end
  end

  env.square = square
  env.lerp = lerp
  env.inverseLerp = function(min, max, value)
   if math.abs(max - min) < 1e-30 then return min end
   return (value - min) / (max - min)
  end

  --create metable to give the env access to our pin data, exceptions while accessing stuff here are expected and will be catched by the pcall during execution
  env.__pinIn = self.pinIn
  setmetatable(
    env,
    {
      __index = function(table, key)
        local val = table.__pinIn[key].value
        if type(val) == 'table' then
          if val[4] then
            if self.quatCache[key] then
              self.quatCache[key].x = val[1]
              self.quatCache[key].y = val[2]
              self.quatCache[key].z = val[3]
              self.quatCache[key].w = val[4]
            else
              self.quatCache[key] = quat(val)
            end
            return self.quatCache[key]
          else
            if self.vecCache[key] then
              self.vecCache[key].x = val[1]
              self.vecCache[key].y = val[2]
              self.vecCache[key].z = val[3]
            else
              self.vecCache[key] = vec3(val)
            end
            return self.vecCache[key]
          end
        else
          return val
        end
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
  if type(result) == 'cdata' then
    if ffi.istype('struct __luaVec3_t', result) then
      self.pinOut.value.value = {result.x, result.y, result.z}
    else
      self.pinOut.value.value = {result.x, result.y, result.z, result.w}
    end
  else
    self.pinOut.value.value = result
  end
  self:__setNodeError("expression", error)
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.TextUnformatted(self.data.expression)
end

function C:onLink(link)
  if tableSize(self.pinInLocal) <= tableSize(self.pinIn) then
    local pinName = string.char(97 + tableSize(self.pinIn))
    self:createPin("in", {"number",'vec3','quat'}, pinName, 0, "A term of the expression.")
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
