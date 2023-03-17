-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local lastPursuitData = {
  pursuitScore = 0,
  pursuitLevel = 0,
  sightValue = 0,
  timer = 0,
  arrest = 0,
  evade = 0,
  offensesCount = 0
}

M.enabled = true

local function resetPursuitTable() -- resets values to zero
  for k, v in pairs(lastPursuitData) do
    if type(v) == 'number' then
      lastPursuitData[k] = 0
    end
  end
  guihooks.trigger('PoliceInfoUpdate', lastPursuitData)
end

local function onVehicleSwitched(_, id)
  if M.enabled then
    resetPursuitTable()
  end
end

local function onGuiUpdate(dt)
  local pursuit = gameplay_police.getPursuitData() -- player vehicle pursuit data
  if not pursuit then
    if lastPursuitData.pursuitScore ~= 0 then
      resetPursuitTable()
    end
    return
  end
  if not be:getEnabled() or not M.enabled then return end

  local pd = lastPursuitData
  pd.pursuitScore = pursuit.score
  pd.pursuitLevel = pursuit.mode
  pd.sightValue = pursuit.sightValue
  pd.timer = pursuit.timers.main
  pd.arrest = lerp(pd.arrest, pursuit.timers.arrestValue, 0.5)
  pd.evade = lerp(pd.evade, pursuit.timers.evadeValue, 0.5)
  -- lerp is used to make the progress bar act fancy when values get reset to zero

  if pd.offensesCount < pursuit.uniqueOffensesCount then
    pd.offense = pursuit.offensesList[#pursuit.offensesList] -- latest offense (gets sent for one frame)
  end
  pd.offensesCount = pursuit.uniqueOffensesCount

  guihooks.trigger('PoliceInfoUpdate', pd)
  pd.offense = nil
end

M.onGuiUpdate = onGuiUpdate
M.onVehicleSwitched = onVehicleSwitched

return M