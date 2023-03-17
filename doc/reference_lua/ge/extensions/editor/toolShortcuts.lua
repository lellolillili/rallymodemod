-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function onEditorInitialized()
  local sortedKeys = {}
  for key, mode in pairs(editor.editModes) do
    if key ~= "objectSelect" and key ~= "createObject" and mode.icon then table.insert(sortedKeys, key) end
  end
  table.sort(sortedKeys)
  -- we always want object select to be first edit mode and create object second
  table.insert(sortedKeys, 1, "objectSelect")
  table.insert(sortedKeys, 2, "createObject")

  -- Create function openTool1 to 9, etc, F1 is reserved for Help
  for i = 1, 9 do
    editor["openTool" .. i] = function()
      if sortedKeys[i] then
        local mode = editor.editModes[sortedKeys[i]]
        if mode then
          editor.selectEditMode(mode)
        end
      end
    end
  end
end

-- public interface
M.onEditorInitialized = onEditorInitialized

return M