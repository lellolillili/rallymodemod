-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'MissionInfo'
M.buttonsTable = nil

M.performAction = function(actionName)
  -- log('I', logTag, tostring(actionName) .. " action triggered. Looking for " .. tostring(actionName) .. " action in "..dumps(M.buttonsTable))
  if M.buttonsTable then
    for i,button in ipairs(M.buttonsTable) do
      if button.action == actionName then
        loadstring(button.cmd)()
        return
      end
    end
  end
end

M.openDialogue = function(content)
  content = content or {}
  -- do not push the actionmap if content says so
  if content.actionMap ~= false then
    local am = scenetree.findObject("MissionUIActionMap")
    if am then am:push() end
  end
  M.buttonsTable = content.buttons or {}
  guihooks.trigger('MissionInfoUpdate', content)
end

M.closeDialogue = function()
  local am = scenetree.findObject("MissionUIActionMap")
  if am then am:pop() end
  M.buttonsTable = nil
  guihooks.trigger('MissionInfoUpdate', nil)
end

return M
