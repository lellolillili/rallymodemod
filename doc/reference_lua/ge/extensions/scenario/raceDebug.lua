-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function onScenarioChange( scenario )
  local currentScenario = scenario_scenarios.getScenario()
  if not currentScenario or currentScenario.state ~= 'running' then return end
  -- find path for debug drawing only - DO NOT USE FOR ANYTHING ELSE THAN DEBUG

  local mapData = map.getMap()

  currentScenario.debugPath = {}
  currentScenario.debugNodes = {}
  if not currentScenario.lapConfig then return end

  for _, wp in pairs(currentScenario.lapConfig) do
    local n = currentScenario.nodes[wp]
    if n then
      local pp = n.pos

      if lastwp then
        --print("path from '" .. lastwp .. "' to '".. wp .. "':")
        local path = map.getPath(lastwp, wp)
        local lastWpp = nil
        for _, wpp in pairs(path) do
          if wpp ~= lastWpp then
            table.insert(currentScenario.debugPath, wpp)
            local node = currentScenario.nodes[wpp]
            if not node then
              node = deepcopy(mapData.nodes[wpp])
            end
            node.pos = vec3(node.pos)
            node.direct = (#path == 1)
            currentScenario.debugNodes[wpp] = node
            lastWpp = wpp
          end
        end
      end
      lastwp = wp
    end
  end
end

local function onDrawDebug(focusPos)
  local currentScenario = scenario_scenarios.getScenario()
  if not currentScenario then return end

  local drawDebug = tonumber(getConsoleVariable('$isEditorEnabled')) == 1 and settings.getValue("BeamNGRaceDrawDebug")

  if drawDebug and currentScenario.nodes and currentScenario.lapConfig then
    local i = 0
    for _, wp in pairs(currentScenario.lapConfig) do
      i = i + 1
      local n = currentScenario.nodes[wp]
      if n then
        local pp = n.pos
        debugDrawer:drawSphere(pp, n.radius, ColorF(1,0,0,0.3))
        --debugDrawer:drawText(pp, String("#" .. tostring(i) .. "/" .. #currentScenario.lapConfig ), ColorF(0,0,0,1))
        local label = "wp " .. tostring(i) .. "/" .. #currentScenario.lapConfig
        debugDrawer:drawText(pp, String(label), ColorF(0,0,0,1),false)
      end
    end

    local lastwpd = nil
    local lastwpdStr = nil
    for _, wp in pairs(currentScenario.debugPath) do
      local wpd = currentScenario.debugNodes[wp]
      if lastwpd then
        --print(" route: " .. tostring(lastwpdStr) .. " -> " .. tostring(wp))
        local col = ColorF(0,1,0,0.6)
        if wpd.direct or lastwpd.direct then
          col = ColorF(1,0,0,0.6)
        end
        debugDrawer:drawSquarePrism(lastwpd.pos, wpd.pos, Point2F(0.6, lastwpd.radius*2), Point2F(0.6, wpd.radius*2), col)
      end
      lastwpd = wpd
      lastwpdStr = wp
    end

  end
end

-- public interface
M.onDrawDebug = onDrawDebug
M.onScenarioChange = onScenarioChange

return M
