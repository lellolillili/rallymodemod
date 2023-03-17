-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local ffi = require('ffi')

local C = {}

local log_types = { { 'I', 'Info' }, { 'D', 'Debug' }, { 'W', 'Warning' }, { 'E', 'Error' } }

C.name = 'Log'
C.description = "Logs the input to the console. LogType can be I, D, W or E."
C.color = ui_flowgraph_editor.nodeColors.debug
C.icon = ui_flowgraph_editor.nodeIcons.debug
C.category = 'dynamic_instant'
C.todo = "Log type should be a combobox in properties"

C.pinSchema = {
  { dir = 'in', type = 'any', name = 'value', default = "", hardcoded = true, defaultHardCodeType = 'string', description = 'Value that should be logged.' },
  { dir = 'in', type = 'string', name = 'logTag', default = 'Node #', description = 'Tag to identify log' },
  { dir = 'in', type = 'string', name = 'logType', default = 'I', hardcoded = true, description = 'Can be I(Info), D(Debug), W(Warning) or E(Error)' },
}

C.tags = { 'util' }

function C:postInit()
  local type = {}
  for _, tmp in ipairs(log_types) do
    table.insert(type, { value = tmp[1], label = tmp[2] })
  end

  self.pinInLocal.logType.hardTemplates = type
  self.pinInLocal.logType.hidden = true

  self.pinInLocal.logTag.defaultValue = 'Node #' .. self.id
  self.pinInLocal.logTag.value = self.pinInLocal.logTag.defaultValue
  self.pinInLocal.logTag.hidden = true
end

function C:workOnce()
  self:createLogEntry()
end

function C:work()
  if self.dynamicMode == 'repeat' then
    self:createLogEntry()
  end
end

function C:createLogEntry()
  local msg = tostring(self.pinIn.value.value)
  if type(self.pinIn.value.value) == 'table' then
    msg = dumps(self.pinIn.value.value)
  end
  log(self.pinInLocal.logType.value, self.pinInLocal.logTag.value, msg)
  self.mgr:logEvent(msg, self.pinIn.logType.value, nil, { type = "node", node = self })
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text("('" .. self.pinInLocal.logType.value .. "','" .. self.pinInLocal.logTag.value .. "',...)")
end

return _flowgraph_createNode(C)
