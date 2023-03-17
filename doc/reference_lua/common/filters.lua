-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- This file contains several smoothing filters. Please refer to the documentation
-- created by BeamNG

local max, min, abs = math.max, math.min, math.abs

--=Spring based temporal
local temporalSpring = {}
temporalSpring.__index = temporalSpring

function newTemporalSpring(spring, damp, startingValue)
  local data = {spring = spring or 10, damp = damp or 2, state = startingValue or 0, vel = 0}
  setmetatable(data, temporalSpring)
  return data
end

function temporalSpring:get(sample, dt)
  self.vel = self.vel * max(1 - self.damp * dt, 0) + (sample - self.state) * min(self.spring * dt, 1/dt)
  self.state = self.state + self.vel * dt
  return self.state
end

function temporalSpring:getWithSpringDamp(sample, dt, spring, damp)
  self.vel = self.vel * max(1 - damp * dt, 0) + (sample - self.state) * min(spring * dt, 1/dt)
  self.state = self.state + self.vel * dt
  return self.state
end

function temporalSpring:set(sample)
  self.state = sample
  self.vel = 0
end

function temporalSpring:value()
  return self.state
end

-- S-curve temporal
local temporalSigmoidSmoothing = {}
temporalSigmoidSmoothing.__index = temporalSigmoidSmoothing

function newTemporalSigmoidSmoothing(inRate, startAccel, stopAccel, outRate, startingValue)
  local rate = inRate or 1
  local startaccel = startAccel or math.huge
  local data = {[false] = rate, [true] = outRate or rate, startAccel = startaccel, stopAccel = stopAccel or startaccel, state = startingValue or 0, prevvel = 0}
  setmetatable(data, temporalSigmoidSmoothing)
  return data
end

function temporalSigmoidSmoothing:get(sample, dt)
  local dif = sample - self.state

  local prevvel = self.prevvel * max(sign(self.prevvel * dif), 0)
  local vsq = prevvel * prevvel
  local absdif = abs(dif)
  local difsign = sign(dif)
  local acceldt

  local absdif2 = absdif * 2
  if vsq > absdif2 * self.stopAccel then
    acceldt = -difsign * min((vsq / absdif2) * dt, abs(prevvel))
  else
    acceldt = difsign * self.startAccel * dt
  end

  local ratelimit = self[dif * self.state >= 0]
  self.state = self.state + difsign * min(min(abs(prevvel + 0.5 * acceldt), ratelimit) * dt, absdif)
  self.prevvel = difsign * min(abs(prevvel + acceldt), ratelimit)
  return self.state
end

function temporalSigmoidSmoothing:getWithRateAccel(sample, dt, ratelimit, startAccel, stopAccel)
  local dif = sample - self.state
  local prevvel = self.prevvel * max(sign(self.prevvel * dif), 0)
  local vsq = prevvel * prevvel
  local absdif = abs(dif)
  local difsign = sign(dif)
  local acceldt

  local absdif2 = absdif * 2
  if vsq > absdif2 * (stopAccel or startAccel) then
    acceldt = -difsign * min((vsq / absdif2) * dt, abs(prevvel))
  else
    acceldt = difsign * startAccel * dt
  end

  self.state = self.state + difsign * min(min(abs(prevvel + 0.5 * acceldt), ratelimit) * dt, absdif)
  self.prevvel = difsign * min(abs(prevvel + acceldt), ratelimit)
  return self.state
end

function temporalSigmoidSmoothing:set(sample)
  self.state = sample
  self.prevvel = 0
end

function temporalSigmoidSmoothing:reset()
  self.state = 0
  self.prevvel = 0
end

function temporalSigmoidSmoothing:value()
  return self.state
end

-- Exponential/Non Linear temporal
local temporalSmoothingNonLinear = {}
temporalSmoothingNonLinear.__index = temporalSmoothingNonLinear

function newTemporalSmoothingNonLinear(inRate, outRate, startingValue)
  local rate = min(inRate or 1, 1e+30)
  local data = {[false] = rate, [true] = min(outRate or rate, 1e+30), state = startingValue or 0}
  setmetatable(data, temporalSmoothingNonLinear)
  return data
end

function temporalSmoothingNonLinear:get(sample, dt)
  local st = self.state
  local dif = sample - st
  local ratedt = self[dif * st >= 0] * dt
  st = st + dif * ratedt / (1 + ratedt)
  self.state = st
  return st
end

function temporalSmoothingNonLinear:getWithRate(sample, dt, rate)
  local st = self.state
  local ratedt = rate * dt
  st = st + (sample - st) * ratedt / (1 + ratedt)
  self.state = st
  return st
end

function temporalSmoothingNonLinear:set(sample)
  self.state = sample
end

function temporalSmoothingNonLinear:value()
  return self.state
end

function temporalSmoothingNonLinear:reset()
  self.state = 0
end

-- Linear temporal
local temporalSmoothing = {}
temporalSmoothing.__index = temporalSmoothing

function newTemporalSmoothing(inRate, outRate, autoCenterRate, startingValue)
  inRate = max(inRate or 1, 1e-307)
  startingValue = startingValue or 0

  local data = {[false] = inRate, [true] = max(outRate or inRate, 1e-307),
                autoCenterRate = max(autoCenterRate or inRate, 1e-307),
                _startingValue = startingValue,
                state = startingValue}

  setmetatable(data, temporalSmoothing)

  if data.autoCenterRate ~= inRate then
    data.getUncapped = data.getUncappedAutoCenter
  end
  return data
end

function temporalSmoothing:getUncappedAutoCenter(sample, dt)
  local st = self.state
  local dif = (sample - st)
  local rate

  if sample == 0 then
    rate = self.autoCenterRate  -- autocentering
  else
    rate = self[dif * st >= 0]
  end
  st = st + dif * min(rate * dt / abs(dif), 1)
  self.state = st
  return st
end

function temporalSmoothing:get(sample, dt)
  local st = self.state
  local dif = sample - st
  st = st + dif * min(self[dif * st >= 0] * dt / abs(dif), 1)
  self.state = st
  return st
end

function temporalSmoothing:getCapped(sample, dt)
  return max(min(self:getUncapped(sample, dt), 1), -1)
end

function temporalSmoothing:getWithRate(sample, dt, rate)
  local st = self.state
  local dif = (sample - st)
  st = st + dif * min(rate * dt / (abs(dif) + 1e-307), 1)
  self.state = st
  return st
end

function temporalSmoothing:getWithRateCapped(sample, dt, rate)
  return max(min(self:getWithRate(sample, dt, rate), 1), -1)
end

temporalSmoothing.getUncapped = temporalSmoothing.get
temporalSmoothing.getWithRateUncapped = temporalSmoothing.getWithRate

function temporalSmoothing:reset()
  self.state = self._startingValue
end

function temporalSmoothing:value()
  return self.state
end

function temporalSmoothing:set(v)
  self.state = v
end

--== Linear ==--
local linearSmoothing = {}
linearSmoothing.__index = linearSmoothing

function newLinearSmoothing(dt, inRate, outRate)
  inRate = max(inRate or 1, 1e-307)
  local data = {[false] = inRate * dt, [true] = max(outRate or inRate, 1e-307) * dt, state = 0}
  setmetatable(data, linearSmoothing)
  return data
end

function linearSmoothing:get(sample) -- no autocenter
  local st = self.state
  local dif = (sample - st)
  st = st + dif * min(self[dif * st >= 0] / abs(dif), 1)
  self.state = st
  return st
end

function linearSmoothing:set(v)
  self.state = v
end

function linearSmoothing:reset()
  self.state = 0
end

-- Exponential
local exponentialSmoothing = {}
exponentialSmoothing.__index = exponentialSmoothing

function newExponentialSmoothing(window, startingValue, fixedDt)
  local data = {a = 2 / max(window, 2), _startingValue = startingValue or 0, st = startingValue or 0}
  local adt = data.a * (fixedDt or 0.0005)
  data.a = (2000 + data.a) * adt / (1 + adt)
  setmetatable(data, exponentialSmoothing)
  return data
end

function exponentialSmoothing:get(sample)
  local st = self.st
  st = st + self.a * (sample - st)
  self.st = st
  return st
end

function exponentialSmoothing:getWindow(sample, window)
  local st = self.st
  st = st + 2 * (sample - st) / max(window, 2)
  self.st = st
  return st
end

function exponentialSmoothing:value()
  return self.st
end

function exponentialSmoothing:set(value)
  self.st = value
end

function exponentialSmoothing:reset(value)
  self.st = value or self._startingValue
end

-- Exponential + Trend
local exponentialSmoothingT = {}
exponentialSmoothingT.__index = exponentialSmoothingT

function newExponentialSmoothingT(window, window2, startingValue)
  startingValue = startingValue or 0
  local data = {a = 2 / max(window, 2), a2 = 2 / max(window2 or math.huge, 2), startingValue = startingValue, st = startingValue, [true] = 0, [false] = 0}
  setmetatable(data, exponentialSmoothingT)
  return data
end

function exponentialSmoothingT:get(sample)
  local a, a2, st, st1, st2 = self.a, self.a2, self.st, self[true], self[false]
  local samplst2 = sample - self[sample >= st]
  if (samplst2 - st) * (sample - st) < 0 then samplst2 = sample end
  st = st + a * (samplst2 - st)
  local dif = samplst2 - st
  local a2dif = a2 * dif
  if dif >= 0 then
    st1, st2 = min(dif, st1 + a2dif), min(0, st2 + a2dif)
    st = st + st1
  else
    st1, st2 = max(0, st1 + a2dif), max(dif, st2 + a2dif)
    st = st + st2
  end
  self.st, self[true], self[false] = st, st1, st2
  return st
end

function exponentialSmoothingT:getWindow(sample, window, window2)
  local st, st1, st2 = self.st, self[true], self[false]
  local samplst2 = sample - self[sample >= st]
  if (samplst2 - st) * (sample - st) < 0 then samplst2 = sample end
  st = st + (samplst2 - st) * 2 / max(window, 2)
  local dif = samplst2 - st
  local a2dif = dif * 2 / max(window2 or math.huge, 2)
  if dif >= 0 then
    st1, st2 = min(dif, st1 + a2dif), min(0, st2 + a2dif)
    st = st + st1
  else
    st1, st2 = max(0, st1 + a2dif), max(dif, st2 + a2dif)
    st = st + st2
  end
  self.st, self[true], self[false] = st, st1, st2
  return st
end

function exponentialSmoothingT:value()
  return self.st
end

function exponentialSmoothingT:set(value)
  self.st = value
end

function exponentialSmoothingT:reset(value)
  self.st, self[true], self[false] = value or self._startingValue, 0, 0
end

-- Kalman with acceleration
local kalmanAccel = {}
kalmanAccel.__index = kalmanAccel

function newKalmanAccel(r, x0, p0)
  r = r or 0
  local self = setmetatable({}, kalmanAccel)

  -- The initial state vector, x (position, velocity, acceleration).
  self.sx0 = x0
  self.sp0 = p0
  self.x = vec3(x0 or 0, 0, 0)

  p0 = p0 or 0
  -- The initial state uncertainty covariance matrix, p, as three row vectors.
  self.p0, self.p1, self.p2 = vec3(p0, 0, 0), vec3(0, p0, 0), vec3(0, 0, p0)

  -- The measurement noise, r.
  self.r = r

  return self
end

function kalmanAccel:get(sample, dt, r)
  -- Cache x and p throughout the iteration, for faster access.
  local x, p0, p1, p2 = self.x, self.p0, self.p1, self.p2

  -- Kalman prediction stage. Update x and p.
  -- X := (A x X) + (B x U). Note: we ignore the B and U terms in this version. They could be added later if ever required.
  local dtSquared = dt * dt
  local halfDtSquared = dtSquared * 0.5
  x.x, x.y = x.x + dt * x.y + halfDtSquared * x.z, x.y + dt * x.z

  -- P := A x (P x A^T) + Q.
  local dt3 = dtSquared * dt
  local dt3Over6, dt4Over8 = dt3 / 6, dtSquared * dtSquared * 0.125
  local f1 = p1.x + p1.y * dt + p1.z * halfDtSquared
  local f2 = p1.y + p1.z * dt
  local f3 = p2.x + p2.y * dt + p2.z * halfDtSquared
  local f4 = p2.y + p2.z * dt
  p0.x = p0.x + dt * (p0.y + f1) + halfDtSquared * (p0.z + f3) + dt3 * dtSquared * 0.05
  p0.y = p0.y + dt * (p0.z + f2) + halfDtSquared * f4 + dt4Over8
  p0.z = p0.z + dt * p1.z + halfDtSquared * p2.z + dt3Over6
  p1:set(f1 + dt * f3 + dt4Over8, f2 + dt * (f4 + dtSquared / 3), p1.z + dt * p2.z + halfDtSquared)
  p2:set(f3 + dt3Over6, f4 + halfDtSquared, p2.z + dt)

  -- Kalman update stage. Update x and p again with respect to the Kalman gain.
  -- X := X + ( K x [ Z - ( H x X ) ] ), where Kalman gain is K := P x ( H^T x S^-1 ).
  local sInverse = max(min(1 / ((r or self.r) + 1 + p0.x), 1e200), -1e200)
  local f5 = (sample - x.x) * sInverse
  x.x, x.y, x.z = x.x + p0.x * f5, x.y + p1.x * f5, x.z + p2.x * f5

  -- P := P - [ K x (S x K^T) ].
  local tP0X, tP1X, tP2X = p0.x, p1.x, p2.x
  local sP0X, sP1X, sP2X = sInverse * tP0X, sInverse * tP1X, sInverse * tP2X
  p0.x, p0.y, p0.z = p0.x - sP0X * tP0X, p0.y - sP0X * tP1X, p0.z - sP0X * tP2X
  p1.x, p1.y, p1.z = p1.x - sP1X * tP0X, p1.y - sP1X * tP1X, p1.z - sP1X * tP2X
  p2.x, p2.y, p2.z = p2.x - sP2X * tP0X, p2.y - sP2X * tP1X, p2.z - sP2X * tP2X

  return x.x
end

function kalmanAccel:value()
  return self.x.x
end

function kalmanAccel:set(x0)
  -- set the state, X.
  self.x:set(x0 or 0, 0, 0)

  -- Reset the state uncertainty covariance matrix, P.
  local sp0 = self.sp0 or 0
  self.p0:set(sp0, 0, 0)
  self.p1:set(0, sp0, 0)
  self.p2:set(0, 0, sp0)
end

function kalmanAccel:reset()
  self:set(self.sx0 or 0)
end
