local M = {}

local function onScenarioLoaded(scenario)
  extensions.load("ge/extensions/scenario/rallyMode","scenario")
end

M.onScenarioLoaded = onScenarioLoaded

return M
