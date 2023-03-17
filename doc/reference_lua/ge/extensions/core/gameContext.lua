-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local function getGameContext()
  if not gameplay_missions_missionEnter then
    extensions.load('gameplay_missions_missionEnter')
  end
  if gameplay_missions_missionEnter then
    return gameplay_missions_missionEnter.getGameContext()
  end
  return {}
end

local function toggleMenues()
  -- disabled for the time being
  --[[
  -- if missionSystem is offline, just use basic hook.
  if not settings.getValue("showMissionMarkers") then
    guihooks.trigger('MenuItemNavigation','toggleMenues')
    return
  else
    if core_input_bindings.isMenuActive then
      if gameplay_missions_missionManager.getForegroundMissionId() then
        if bullettime.getPause() then
          bullettime.pause(false)
        end
      end
    else
      if gameplay_missions_missionManager.getForegroundMissionId() then
        if not bullettime.getPause() then
          bullettime.pause(true)
        end
      end
    end
    guihooks.trigger('MenuItemNavigation','toggleMenues')
  end
  ]]

end

local function onAnyMissionChanged(state, mission)
  guihooks.trigger('onAnyMissionChanged', state, mission and mission.id)
end



M.onAnyMissionChanged = onAnyMissionChanged

M.getGameContext = getGameContext
M.toggleMenues = toggleMenues
return M
