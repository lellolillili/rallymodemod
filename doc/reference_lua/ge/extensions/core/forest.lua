-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt


local M = {}
local forestId = nil

local function getForestObject()
  local forest = forestId and scenetree.findObjectById(forestId)
  if not forest then
    local forests = scenetree.findClassObjects("Forest")
    if next(forests) then
      forest = scenetree.findObject(forests[1])
      forestId = forest:getId()
    end
  end
  return forest
end

-- public interface
M.getForestObject = getForestObject

return M
