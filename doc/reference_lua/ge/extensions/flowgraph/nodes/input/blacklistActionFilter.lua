-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'Set Input Actionsfilters'
C.description = 'Enables or disables various actions by filters'
C.color = im.ImVec4(0, 0.3, 1, 0.75)
C.icon = "videogame_asset"
C.category = 'once_instant'
C.tmpSecondPassFlag = true
C.pinSchema = {
  { dir = 'in', type = 'bool', name = 'block', description = 'If true, the actions will be blocked. If false or not set, the actions will be unblocked.', hidden = true, default = true, hardcoded = true },
  { dir = 'in', type = 'bool', name = 'ignoreUnrestriced', description = 'If true, this node will be ignored if Competetive Scenario Conditions are disabled.', hidden = true, default = true, hardcoded = true },
  { dir = 'in', type = 'number', name = 'id', description = 'Id of this set of actions, so you can un-do a specific set of actions. If set, will attempt to use that list instead of the ones set in the node properties.', hidden = true },
  { dir = 'out', type = 'number', name = 'id', description = 'Id of this set of actions, so you can un-do a specific set of actions.', hidden = true },
}
C.dependencies = { 'core_input_actionFilter' }
C.tags = { 'blacklist', 'whitelist', 'allow', 'deny', 'block', 'unblock', 'disallow', 'command', 'control' }

local defaultActiveTemplates = {"vehicleTeleporting", "vehicleMenues", "physicsControls", "aiControls", "vehicleSwitching", "freeCam", "funStuff", "walkingMode"}

function C:init()
  self.activeTemplates = {}
  for _, key in ipairs(defaultActiveTemplates) do
    self.activeTemplates[key] = true
  end
end

function C:drawCustomProperties()
  local reason = nil
  if not self.actionTemplates then
    self.actionTemplates = core_input_actionFilter.getActionTemplates()
    self.sortedTemplateKeys = tableKeysSorted(self.actionTemplates)
  end

  -- todo: make more pretty
  for i, key in ipairs(self.sortedTemplateKeys) do
    if im.Checkbox(key.."##cbaf"..i, im.BoolPtr(self.activeTemplates[key] or false)) then
      self.activeTemplates[key] = not self.activeTemplates[key]
    end
    im.BeginDisabled()
    im.SameLine()
    im.Text(string.format("(%d actions)", #self.actionTemplates[key]))
    im.EndDisabled()
    local tt = table.concat(self.actionTemplates[key], ", ")
    im.tooltip(tt)
  end
  return reason
end

function C:_onSerialize(res)
  res.activeTemplates = self.activeTemplates
end

function C:_onDeserialized(data)
  self.activeTemplates = data.activeTemplates or self.activeTemplates or {}
  if data.data.ignoreWhenUnrestricted ~= nil then
    self:_setHardcodedDummyInputPin(self.pinInLocal.ignoreUnrestriced, data.data.ignoreWhenUnrestricted)
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  self.name = "Set Input Actionsfilters"
  if self.pinInLocal.block.pinMode == 'hardcoded' then
    editor.uiIconImage(self.pinIn.block.value and editor.icons.block or editor.icons.check)
    self.name = (self.pinIn.block.value and "Block" or "Allow") .. " Input Actionsfilters"
  end

end

function C:workOnce()
  local listByKey = {}
  for key, active in pairs(self.activeTemplates) do
    if active then
      listByKey[key] = true
    end
  end
  local list = core_input_actionFilter.createActionTemplate(tableKeysSorted(listByKey))

  if self.pinIn.ignoreUnrestriced.value and (not settings.getValue('restrictScenarios', true)) then
    list = {}
    log('W', logTag, '**** Restrictions on Scenario Turned off in game settings. Ignoring Set Input Actions actions. ****')
  end

  if not self.pinOut.id.value then
    self.pinOut.id.value = self.mgr.modules.action:registerList(list)
  end
  local id = self.pinIn.id.value or self.pinOut.id.value
  if self.pinIn.block.value then
    self.mgr.modules.action:blockActions(id)
  else
    self.mgr.modules.action:allowActions(id)
  end
end

return _flowgraph_createNode(C)
