-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this system determines how fast the simulation time is running (or paused) considering all circumstances.

local M = {}

local updateDispatch = nop

M.simulationSpeed = be:getSimulationTimeScale() -- after a gelua load or gelua reload, ensure we're in sync with the c++ engine
M.simulationSpeedReal = M.simulationSpeed
local initialTimeScale = M.simulationSpeed

local drateLimit, dstartAccel, dstopAccel = 20, 10, 3
local mrateLimit, mstartAccel, mstopAccel
local simulationSpeed_smooth = newTemporalSigmoidSmoothing(drateLimit, dstartAccel, dstopAccel, drateLimit, M.simulationSpeed) -- start at current timescale

local pauseTransition = false

local bulletTimeSlots = {1/1000, 1/500, 1/200, 1/100, 1/50, 1/32, 1/16, 1/8, 1/4, 1/2, 3/4, 1.0}
local instantSlowmoSlot = 8
local toggleSlowmoSlot = 8
-- figure out the selectionSlot for the current time scale (could be different than 1 if e.g. we've reloaded gelua while in slowmo)
M.selectionSlot = #bulletTimeSlots
for currSlot,currTimescale in ipairs(bulletTimeSlots) do
  local selectionDiff = math.abs(M.simulationSpeed - bulletTimeSlots[M.selectionSlot])
  local currDiff = math.abs(M.simulationSpeed - currTimescale)
  if currDiff < selectionDiff then
    M.selectionSlot = currSlot
  end
end

local function getPause()
  if core_replay.state.state == "playing" then
    return core_replay.isPaused()
  else
    return not be:getEnabled()
  end
end

local function updateFct(dt)
  if not pauseTransition and getPause() then return end -- do not transition while paused

  local finalSpeed = M.simulationSpeed
  local realSpeed = simulationSpeed_smooth:getWithRateAccel(finalSpeed, dt, mrateLimit or drateLimit, mstartAccel or dstartAccel, mstopAccel or dstopAccel)

  physicsEngineEvent('timescale',realSpeed)
  be:setSimulationTimeScale(realSpeed)
  M.simulationSpeedReal = realSpeed

  if realSpeed == finalSpeed then
    if finalSpeed == 0 then
      be:setEnabled(false)
      physicsStateChanged(false)
    end

    pauseTransition = false
    mrateLimit, mstartAccel, mstopAccel = nil, nil, nil
    updateDispatch = nop
  end
end

local function reportSpeed(speed, simplified)
  if speed > 1.001 then
    ui_message({txt="vehicle.bullettime.changeFast", context={speed=speed}}, 5, "bullettime")
  elseif speed > 0.999 then
    if not simplified then
      ui_message("vehicle.bullettime.realtime", 5, "bullettime")
    end
  else
    if simplified then
      ui_message("vehicle.bullettime.slowmotion", 5, "bullettime")
    else
      local times = 1/speed
      local rounded = math.floor(times+0.5)
      if times < 2 and times ~= rounded then
        times = string.format("%.2f", 1/speed)
      else
        times = rounded
      end
      ui_message({txt="vehicle.bullettime.changeSlow", context={slowmoTimes=times}}, 5, "bullettime")
    end
  end
end

local function setTargetSpeed(val)
  if type(val) ~= "number" then
    log("E","bullettime","Tried to set non-numeric speed: "..dumps(val))
    return
  end
  M.simulationSpeed = clamp(val, 0.001, 1)
  initialTimeScale = M.simulationSpeed
  if getPause() then return end
  updateDispatch = updateFct
end

local function selectPreset(val)
  if core_replay.state.state == "playing" then
    if     val == "^" then core_replay.toggleSpeed("realtime")
    elseif val == "v" then core_replay.toggleSpeed("slowmotion")
    elseif val == "<" then core_replay.toggleSpeed( -1)
    elseif val == ">" then core_replay.toggleSpeed(  1)
    end
  else
    if     val == "^" then
      if M.selectionSlot == #bulletTimeSlots then
        M.selectionSlot = toggleSlowmoSlot
      else
        toggleSlowmoSlot = M.selectionSlot
        M.selectionSlot = #bulletTimeSlots
      end
    elseif val == "v" then M.selectionSlot = instantSlowmoSlot
    elseif val == "<" then M.selectionSlot = M.selectionSlot - 1
    elseif val == ">" then M.selectionSlot = M.selectionSlot + 1
    end

    M.selectionSlot = clamp(M.selectionSlot, 1, #bulletTimeSlots)
    setTargetSpeed(bulletTimeSlots[M.selectionSlot])
    reportSpeed(M.simulationSpeed, false)
  end
end

local function getReal()
  return M.simulationSpeedReal
end

local function get()
  return M.simulationSpeed
end

local function set(val)
  setTargetSpeed(val)
  reportSpeed(M.simulationSpeed, true)
end

local function setInstant(val)
  setTargetSpeed(val)
  simulationSpeed_smooth:set(M.simulationSpeed)
end

local function requestValue()
  guihooks.trigger("BullettimeValueChanged", M.simulationSpeed)
end

local function pause(paused)
  if core_replay.state.state == "playing" then
    core_replay.pause(paused)
  else
    if paused == getPause() then return end
    if paused then
      if not pauseTransition then
        initialTimeScale = M.simulationSpeed -- backup the original physics scale
        pauseTransition = false
      end
      M.simulationSpeed = 0
      updateDispatch = nop
    else
      simulationSpeed_smooth:set(initialTimeScale) -- start smoother in current value, not in zero
      setTargetSpeed(initialTimeScale) -- restore the original physics scale
    end
    be:setSimulationTimeScale(M.simulationSpeed)
    be:setEnabled(not paused)
    physicsStateChanged(not paused)
  end
end

local function pauseSmooth(paused, rateLimit, startAccel, stopAccel)
  if core_replay.state.state == "playing" then
    core_replay.pause(paused)
  else
    if paused == getPause() and not pauseTransition then return end
    mrateLimit, mstartAccel, mstopAccel = rateLimit, startAccel, stopAccel
    updateDispatch = updateFct

    if paused then
      if not pauseTransition then
        initialTimeScale = M.simulationSpeed -- backup the original physics scale
      end
      M.simulationSpeed = 0
    else
      M.simulationSpeed = initialTimeScale
      if getPause() then
        simulationSpeed_smooth:set(0)
        be:setEnabled(true)
        physicsStateChanged(true)
      end
    end
    pauseTransition = true
  end
end

local function togglePause()
  if core_replay.state.state == "playing" then
    core_replay.togglePlay()
  else
    pause(not getPause())
  end
end


local function onSerialize()
  -- TODO: serialize speed and state properly
  return { simulationSpeed = M.simulationSpeed, initialTimeScale = initialTimeScale }
end

local function onDeserialized(data)
  -- TODO: verify this is working
  M.simulationSpeed = data.simulationSpeed
  initialTimeScale = data.initialTimeScale
end

-- the extension system registers the function pointers, thus functions called back by it cannot be nop'ed. So we wrap it in another function.
local function update(...)
  updateDispatch(...)
end

-- public interface
M.update = update
M.get = get -- 1=realtime, 0.5=slowmo, 2=fastmotion (desired value, which may or may not have been reached yet)
M.getReal = getReal -- 1=realtime, 0.5=slowmo, 2=fastmotion (current value in effect, with smoothing in action)
M.set = set -- 1=realtime, 0.5=slowmo, 2=fastmotion (change won't be instant: speed will slowly reach the desired value)
M.setInstant = setInstant -- same as set, but instantaneous
M.selectPreset = selectPreset
M.pause = pause
M.pauseSmooth = pauseSmooth
M.getPause = getPause
M.togglePause = togglePause
M.requestValue = requestValue
M.reportSpeed = reportSpeed

M.onSerialize    = onSerialize
M.onDeserialized = onDeserialized


return M
