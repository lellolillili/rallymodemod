-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function onEditorPrefabExploded(groups)
  for _, group in ipairs(groups) do
    for _, name in pairs(group:getObjects()) do
      local object = scenetree.findObject(name)
      if object and object:getClassName() == "DecalRoad" then
        editor.updateRoadVertices(object)
      end
    end
  end
end

local function onEditorInitialized()
  editor.initializeLevelRoadsVertices()
end

-- public interface
M.onEditorPrefabExploded = onEditorPrefabExploded
M.onEditorInitialized = onEditorInitialized

return M