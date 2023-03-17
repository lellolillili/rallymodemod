-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function onEditorInspectorFieldChanged(selectedIds, fieldName, fieldValue, arrayIndex)
  for i = 1, #selectedIds do
    if fieldName == "rippleTex" or fieldName == "foamTex" or fieldName == "depthGradientTex" or fieldName == "cubemap" then
      local object = scenetree.findObjectById(selectedIds[i])
      if object:isSubClassOf("WaterObject") then
        object:reloadTextures()
      end
    end
  end
end

M.onEditorInspectorFieldChanged = onEditorInspectorFieldChanged

return M