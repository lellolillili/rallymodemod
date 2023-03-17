-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Race Highscores'
C.description = 'Manages Highscores for the race system.'
C.category = 'repeat_instant'
C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.' },
  { dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },

}

C.tags = { 'scenario' }

C.legacyPins = {
  _in = {
    clear = 'reset'
  }
}

function C:init()
  self.markers = nil
end

local function getConfigKey(race)


  local rolling = race.path.config.rollingStart
  local reverse = race.path.isReversed
  local laps = race.lapCount

  local mode = "standing"

  if rolling then mode = "rolling" end
  if reverse then mode = mode.."Reverse" end
  if laps then mode = mode .. laps end

  return mode
end

function C:work()

  self.pinOut.flow.value = self.pinIn.flow.value
  if self.pinIn.reset.value then
    self:_executionStopped()
  elseif self.pinIn.flow.value then
    if self.pinIn.raceData.value then

      local state = self.pinIn.raceData.value.states[self.pinIn.vehId.value]
      if not state then return end


      print("Writing Highscores...")
      local veh
      if self.pinIn.vehId.value then
        veh = scenetree.findObjectById(self.pinIn.vehId.value)
      else
        veh = be:getPlayerVehicle(0)
      end
      local vData = core_vehicle_manager.getVehicleData(self.pinIn.vehId.value)
      local mData = core_vehicles.getModel(veh.jbeam)
      local config = {Name = "Custom Config"}
      local _, fn, ext = path.splitWithoutExt(vData.config.partConfigFilename)
      for k, c in pairs(mData.configs) do
        if fn == c then
          config = c
        end
      end
      local record = {
        playerName = vData.config.licenseName or "No License",
        vehicleBrand = mData.Brand,
        vehicleName = config.Name,
        vehicleConfig = vData.config.partConfigFilename,
        vehicleModel = veh.jbeam
      }
      local scenarioName = self.mgr.activity.missionTypeData.trackName

      local place = core_highscores.setScenarioHighscoresCustom(
        state.historicTimes[#state.historicTimes].endTime*1000,
        record,
        getCurrentLevelIdentifier(),
        self.mgr.activity.missionTypeData.trackName,
        getConfigKey(self.pinIn.raceData.value)
        )
      local scores = core_highscores.getScenarioHighscores(
        getCurrentLevelIdentifier(),
        self.mgr.activity.missionTypeData.trackName,
        getConfigKey(self.pinIn.raceData.value)
        )

      state.raceComepleteHighscores = {
        place = place,
        scores = scores
      }
    end

  end
end


return _flowgraph_createNode(C)

