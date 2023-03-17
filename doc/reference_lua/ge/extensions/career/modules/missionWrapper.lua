-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.dependencies = {'career_career'}

local allMissionData = {}

local function init() end

local function setCurrentSaveSlot()
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  gameplay_missions_progress.setSavePath(savePath .. "/career/missions/")
  gameplay_missions_missions.reloadCompleteMissionSystem()
end

local function onExtensionLoaded()
  if not career_career.isCareerActive() then return false end

  -- load from saveslot
  setCurrentSaveSlot()
end

local function onExtensionUnloaded()
  gameplay_missions_progress.setSavePath(nil)
  gameplay_missions_missions.reloadCompleteMissionSystem()
end

-- this should only be loaded when the career is active
local function onSaveCurrentSaveSlot(currentSavePath, oldSaveDate)
  local saveSlot, savePath = career_saveSystem.getCurrentSaveSlot()
  if not saveSlot then return end
  gameplay_missions_progress.setSavePath(savePath .. "/career/missions/")
  for id, dirtyDate in pairs(allMissionData) do
    if dirtyDate > oldSaveDate then
      gameplay_missions_progress.saveMissionSaveData(id, dirtyDate)
    end
  end
end

local function setMissionInfo(id, dirtyDate)
  allMissionData[id] = dirtyDate
end

local function cacheMissionData(id, dirtyDate)
  setMissionInfo(id, dirtyDate and dirtyDate or os.date("!%Y-%m-%dT%XZ"))
end

local function onMissionLoaded(id, dirtyDate)
  cacheMissionData(id, dirtyDate)
end

local function saveMission(id)
  cacheMissionData(id)
  career_saveSystem.saveCurrent()
end

local function onAnyMissionChanged(state, mission)
  if mission and state == "stopped" then
    saveMission(mission.id)
  end
end

local missionStartStep
local function onVehicleSaveFinished()
  if missionStartStep then
    missionStartStep.handlingComplete = true
    missionStartStep = nil
  end
end

local function preMissionHandling(step, task)
  missionStartStep = step

  -- create a part condition snapshot
  local vehId = career_modules_inventory.getCurrentVehicleObjectId()
  if vehId then
    local veh = be:getObjectByID(vehId)
    if veh then
      core_vehicleBridge.executeAction(veh, 'createAndSetPartConditionResetSnapshotKey', "beforeMission")
    end
  end
  career_saveSystem.saveCurrent()
end

M.cacheMissionData = cacheMissionData
M.onMissionLoaded = onMissionLoaded
M.saveMission = saveMission
M.preMissionHandling = preMissionHandling

M.onSaveCurrentSaveSlot = onSaveCurrentSaveSlot
M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onAnyMissionChanged = onAnyMissionChanged
M.onVehicleSaveFinished = onVehicleSaveFinished

return M