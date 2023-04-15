local M = {}

local function onScenarioLoaded(scenario)
  extensions.load("ge/extensions/scenario/rallyMode")
end

M.onScenarioLoaded = onScenarioLoaded

return M
