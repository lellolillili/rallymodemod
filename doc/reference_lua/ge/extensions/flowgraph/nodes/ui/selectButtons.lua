-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

C.name = 'Select Buttons'
C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.behaviour = { once = true, singleActive = true }
C.category = 'once_instant'
C.description = "Shows the user a dialoge with a number of buttons. Inputs with empty strings will be ignored."
C.todo = "Showing two of these at the same time will break everything."

C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'altMode', hidden = true, hardcoded = true, default = false, description = 'If enabled, the popup is alligned to the lower part of the screen.' },
  { dir = 'in', type = 'string', name = 'title', description = 'Defines the title of the dialogue.' },
  { dir = 'in', type = {'string','table'}, tableType = 'multiTranslationObject', name = 'description', description = 'Defines the description of the dialogue.' },
  { dir = 'in', type = 'bool', name = 'hideApps', description = 'Hides apps while this dialogue is active.', default=false, hardcoded=true, hidden=true },
}


function C:init()
  self.open = false
  self.oldOptions = {}
  self.options = {"accept","decline"}
    self.count = 1

end

function C:postInit()
  self:updateButtons()
end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
end

function C:drawCustomProperties()
  local reason = nil
  local remove = nil

  im.PushID1("LAYOUT_COLUMNS")
  im.Columns(2, "layoutColumns")
  im.Text("Button count")
  im.NextColumn()

  for i, btn in ipairs(self.options) do
    local txt = im.ArrayChar(64, btn)
    if im.InputText("##btn" .. i, txt, nil, im.InputTextFlags_EnterReturnsTrue) then
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
      self.options[i] = self.options[i+1]
    end
    reason = "Removed an option."
  end

  if im.Button("add") then
    table.insert(self.options, "btn_"..(#self.options+1))
    reason = "added Button"
  end
  im.SameLine()

  if im.Button("rem") then
    self.options[#self.options] = nil
    reason = "removed Button"
  end

  if reason then
    self:updateButtons()
  end

  im.Columns(1)
  im.PopID()

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
    if tableContains(self.oldOptions, pn.name) then
      table.insert(outPins, pn)
    end
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
    if lnk.sourcePin.name and lnk.sourcePin.name ~= "flow" and self.pinOut[lnk.sourcePin.name] then
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
  self.options = nodeData.options or {"accept","decline"}
  self:updateButtons()
end

function C:_executionStarted()
  for _, p in pairs(self.pinOut) do
    p.value = false
  end
end

function C:_executionStopped()
  if self.open then
    self:closeDialogue()
  end
end

function C:_afterTrigger()
  if self.pinIn.flow.value == false and self.open then
    self:closeDialogue()
  end
end
function C:buttonPushed(action)
  for nm, pn in pairs(self.pinOut) do
    self.pinOut[nm].value = nm == action
  end
  if self.open then
    self:closeDialogue()
  end
end

function C:getCmd(action)
  return 'core_flowgraphManager.getManagerByID('..self.mgr.id..').graphs['..self.graph.id..'].nodes['..self.id..']:buttonPushed("'..action..'")'
end

function C:closeDialogue()
  ui_missionInfo.closeDialogue()
  if self.pinIn.hideApps.value then
    guihooks.trigger('ShowApps', true)
  end
  self.open = false
end

local actionList = {'accept', 'decline'}

function C:openDialogue()
  self.open = true
  local buttonsTable = {}
  for i, btn in ipairs(self.options) do
    if self.pinIn[btn].value and self.pinIn[btn].value ~= "" then
      table.insert(buttonsTable, {action = actionList[i] or btn, text = self.pinIn[btn].value, cmd = self:getCmd(btn)})
    end
  end

  local content = {title = self.pinIn.title.value or "", typeName = self.pinIn.description.value or "", altMode = self.pinIn.altMode.value or false, buttons = buttonsTable}
  --dumpz(content)
  if self.pinIn.hideApps.value then
    guihooks.trigger('ShowApps', false)
  end
  ui_missionInfo.openDialogue(content)
end

function C:onNodeReset()
  if self.open then
    self:closeDialogue()
  end
  for _,pn in pairs(self.pinOut) do
    pn.value = false
  end
end

function C:workOnce()
  self:openDialogue()
end


return _flowgraph_createNode(C)
