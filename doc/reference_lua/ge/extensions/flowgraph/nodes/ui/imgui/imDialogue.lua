-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'im Dialogue'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.description = "Opens an imgui window with some text and buttons."
C.category = 'repeat_instant'
C.behaviour = { singleActive = true }
C.todo = "Showing two of these at the same time will break everything."
C.pinSchema = {
  { dir = 'in', type = 'string', name = 'title', description = 'Defines the title of the window.' },
  { dir = 'in', type = 'string', name = 'description', description = 'Defines the description of the window.' },
}

function C:init()
  self.options = { "accept", "decline" }
  self.oldOptions = {}
  self.data.wrapSize = 500
end
function C:postInit()
  self:updateButtons()
end

function C:drawCustomProperties()
  local reason = nil
  local remove = nil
  im.Text(dumps(self.options))
  im.Text(tostring(self.id))
  for i, btn in ipairs(self.options) do
    local txt = im.ArrayChar(64, btn)
    if im.InputText("##btn" .. i .. '_' .. self.id, txt, nil, im.InputTextFlags_EnterReturnsTrue) then
      if ffi.string(txt) == '' then
        remove = i
      else
        self.options[i] = ffi.string(txt)
        reason = "renamed button to" .. self.options[i]
      end
    end
  end
  if remove then
    for i = remove, #self.options do
      self.options[i] = self.options[i + 1]
    end
    reason = "Removed an option."
  end
  if im.Button("add##" .. self.id) then
    table.insert(self.options, "btn_" .. (#self.options + 1))
    reason = "added Button"
  end
  im.SameLine()
  if im.Button("rem##" .. self.id) then
    self.options[#self.options] = nil
    reason = "removed Button"
  end
  if reason then
    self:updateButtons()
  end
  return reason
end

function C:updateButtons()
  local flowLinks = {}
  local strLinks = {}
  for _, lnk in pairs(self.graph.links) do
    if lnk.sourceNode == self then
      table.insert(flowLinks, lnk)
    end
    if lnk.targetNode == self and tableContains(self.oldOptions, lnk.targetPin.name) then
      table.insert(flowLinks, lnk)
    end
  end
  local outPins = {}
  for _, pn in pairs(self.pinOut) do
    table.insert(outPins, pn)
  end
  for _, pn in pairs(outPins) do
    self:removePin(pn)
  end
  local inPins = {}
  for _, pn in pairs(self.pinInLocal) do
    if tableContains(self.oldOptions, pn.name) then
      table.insert(inPins, pn)
    end
  end
  for _, pn in pairs(inPins) do
    self:removePin(pn)
  end
  self.oldOptions = {}
  for i, btn in ipairs(self.options) do
    self:createPin("in", "string", btn)
    self:createPin("out", "flow", btn)
    self.oldOptions[i] = btn
  end

  for _, lnk in ipairs(flowLinks) do
    if lnk.sourcePin.name and self.pinOut[lnk.sourcePin.name] then
      self.graph:createLink(self.pinOut[lnk.sourcePin.name], lnk.targetPin)
    end
  end
  for _, lnk in ipairs(strLinks) do
    if lnk.targetPin.name and self.pinInLocal[lnk.targetPin.name] then
      self.graph:createLink(lnk.sourcePin, self.pinInLocal[lnk.targetPin.name])
    end
  end
end

function C:_onSerialize(res)
  res.options = deepcopy(self.options)
end

function C:_onDeserialized(nodeData)
  self.options = nodeData.options or { "accept", "decline" }
  self:updateButtons()
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:workOnce()
  self.open = true
end

function C:onNodeReset()
  self.open = false
end

function C:work()
  if self.open then
    im.Begin((self.pinIn.title.value or "Title") .. '##' .. tostring(self.id), im.BoolPtr(true))
    im.PushTextWrapPos(im.GetCursorPosX() + (self.data.wrapSize or 500))
    im.TextWrapped((self.pinIn.description.value or "Desc"))
    im.PopTextWrapPos()

    for i, btn in ipairs(self.options) do
      self.pinOut[btn].value = false
      if im.Button((self.pinIn[btn].value or btn) .. "##" .. self.id .. "-" .. i) then
        self:closeDialogue()
        self:closed()
        self.pinOut[btn].value = true
      end
    end
    im.End()
  end
end

return _flowgraph_createNode(C)
