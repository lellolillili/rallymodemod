local M = {}

local function onScenarioLoaded(scenario)
  extensions.loadAtRoot("ge/extensions/scenario/rallyMode", "scenario")
end

M.onScenarioLoaded = onScenarioLoaded

return M
