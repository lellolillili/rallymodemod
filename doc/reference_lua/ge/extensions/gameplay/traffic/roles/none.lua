-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

-- this role is minimal and prevents extra actions or AI from getting applied

function C:init()
  self.actions = {}
  for k, v in pairs(self.baseActions) do
    self.actions[k] = v
  end
  self.baseActions = nil
end

return function(...) return require('/lua/ge/extensions/gameplay/traffic/baseRole')(C, ...) end