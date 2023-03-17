-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Set Variable'
C.icon = "cloud_upload"
C.category = 'repeat_instant'

C.pinSchema = {
}

C.tags = {'set', 'write'}
C.color = im.ImVec4(1,0.8,0.6,0.75)
C.localColor = im.ImVec4(1,0.8,0.6,0.75)
C.globalColor = im.ImVec4(1,0.6,0,8,0.75)
C.description = 'Sets a variable.'
C.hidden = true
function C:init()
  self.varName = nil
  self.target = self.graph.variables
  self.useSuffix = false
end

function C:setGlobal(global)
  self.global = global
  if global then
    self.color = self.globalColor
    self.target = self.graph.mgr.variables
  else
    self.color = self.localColor
    self.target = self.graph.variables
  end
  if self.varName then
    self:removePin(self.pinInLocal[self.varName])
  end
  self.varName = nil
end

function C:drawCustomProperties()
  local reason = nil
  local global = im.BoolPtr(self.global)
  if im.Checkbox("Use Project as Source##".. self.id, global) then
    self:setGlobal(global[0])
  end
  local names = self.target.sortedVariableNames
  local current = self.varName or ""
  if im.BeginCombo("##selectVar".. self.id, current) then
    for _, name in ipairs(names) do
      if im.Selectable1(name, name==current) then
        self:setVar(name)
      end
    end
    im.EndCombo()
  end
  ui_flowgraph_editor.variableEditor(self.target, self.varName)
end

function C:setVar(name)
  local var = self.target:getFull(name)
  if not var then
    log("E","","Invalid name for variable " .. dumps(name))
    return
  end
  local links = {}
  for _,lnk in pairs(self.graph.links) do
    if lnk.targetPin == self.pinInLocal[self.varName] then
      table.insert(links, lnk)
    end
  end
  if self.varName ~= nil then
    self:removePin(self.pinInLocal[self.varName])
  end
  local t = var.type
  self:createPin("in", t, name)
  self.varName = name
  for _,lnk in ipairs(links) do
    if self.graph:pinsCompatible(lnk.sourcePin, self.pinInLocal[self.varName]) then
      self.graph:createLink(lnk.sourcePin, self.pinInLocal[self.varName])
    end
  end
  self.name = "Set " .. name
end

function C:work()
  self.target:change(self.varName, self.pinIn[self.varName].value)
  self.pinOut.flow.value = self.pinIn.flow.value
end

function C:typeUpdated(source, name, newType)
  if source ~= self.target or name ~= self.varName then return end
  local links = {}
  for _,lnk in pairs(self.graph.links) do
    if lnk.targetPin == self.pinInLocal[self.varName] then
      table.insert(links, lnk)
    end
  end
  self:removePin(self.pinInLocal[self.varName])
  self:createPin("in", newType, self.varName)

  for _,lnk in ipairs(links) do
    if self.graph:pinsCompatible(lnk.sourcePin, self.pinInLocal[self.varName]) then
      self.graph:createLink(lnk.sourcePin, self.pinInLocal[self.varName])
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  if self.target and self.target:variableExists(self.varName) then
    local v = self.target:getFull(self.varName)
    if v then
      ui_flowgraph_editor.shortDisplay(v.value, v.type)
    end
  else
    im.Text("???")
    ui_flowgraph_editor.tooltip("Variable missing..?")
  end
end

function C:_onSerialize(res)
  res.varName = self.varName
  res.global = self.global
end

function C:_onDeserialized(nodeData)
  self:setGlobal(nodeData.global or false)
  self:setVar(nodeData.varName)
end

return _flowgraph_createNode(C)
