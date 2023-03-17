-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.never = {
  info = 'This will never be true.',
  getLabel = function(c) return 'Never' end,
  conditionMet = function(c) return false end
}

M.missing = {
  info = 'This will appear if the condition is invalid or cant be found.',
  getLabel = function(c) return 'missions.missions.unlock.missing' end,
  conditionMet = function(c) return true end
}


M.always = {
  info = 'This will always be true.',
  getLabel = function(c) return 'missions.missions.unlock.always' end,
  conditionMet = function(c) return true end,
  hidden = true
}

M.multiAnd = {
  info = 'Returns true, if all contents are true.',
  editorFunction = "displayNestedCondition",
  getLabel = function(c) return 'missions.missions.unlock.multiAnd' end,
  conditionMet = function(c)
    local nested = {}
    local met = true
    for _, cond in ipairs(c.nested or {}) do
      local cMet = gameplay_missions_unlocks.conditionMet(cond)
      met = met and cMet.met
      table.insert(nested, cMet)
    end
    return met, nested
  end
}
M.multiOr = {
  info = 'Returns true, if any of these conditions are true.',
  editorFunction = "displayNestedCondition",
  getLabel = function(c) return 'missions.missions.unlock.multiOr' end,
  conditionMet = function(c)
    local nested = {}
    local met = false
    if not next(c.nested or {}) then
      return true, {}
    end
    for _, cond in ipairs(c.nested or {}) do
      local cMet = gameplay_missions_unlocks.conditionMet(cond)
      met = met or cMet.met
      table.insert(nested, cMet)
    end
    return met, nested
  end
}

return M