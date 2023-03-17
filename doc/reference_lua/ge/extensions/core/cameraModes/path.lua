-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this lets the camera fly on the first path of the map

local C = {}
C.__index = C

local sqrt = math.sqrt
local origin = vec3(0,0,0)

function C:init()
  self.isGlobal = true
  self.hidden = true
  self.ctrlPoint = 0
  self.camT = 0
  self.customData = nil
  self.path = nil
  self.lastSpeed = nil
  self.pathName = nil

  -- This is for backwards compatibility. Might just be a typo of "pathName", but i'll keep it in for safety
  self.pathname = nil
end

local function calculateTnorm(d12, d23, d34, t1, t2, t3, t)
  return clamp((monotonicSteffen(0, d12, d12 + d23, d12 + d23 + d34, 0, t1, t1 + t2, t1 + t2 + t3, t1 + t) - d12) / d23, 0, 1)
end

function C:getTimeToNext(path, index)
  local markers = path.markers
  if self.customData and self.customData.useJsonVersion then
    return (index < #markers) and (markers[index+1].time - markers[index].time) or (path.looped and path.loopTime or 2)
  else
    return markers[index].time
  end
end

function C:getGlobalTime(path, index, looped)
  if self.customData and self.customData.useJsonVersion then
    if looped and (index == 1) then
      return path.markers[#path.markers].time + (path.loopTime or 2)
    else
      return path.markers[index].time
    end
  else
    local globalTime = 0
    for i=1, index - 1 do
      globalTime = globalTime + path.markers[i].time
    end
    return globalTime
  end
end

function C:update(data)
  if self.customData and self.customData.useJsonVersion then
    if not self.path and self.customData then
      self.path = self.customData:getNextPath()
    end
  else
    if not self.pathName and self.customData then
      self.pathName = self.customData:getNextPath()
    end
  end

  local path
  if self.customData and self.customData.useJsonVersion then
    path = self.path
  else
    path = core_paths.getPath(self.pathName)
  end
  if not path or #path.markers < 2 then return end
  local markers = path.markers

  data.dt = data.dtSim -- switch to physics dt, to respect time scaling
  if self.customData and self.customData.useDtReal then
    data.dt = data.dtReal -- allow to use real DT
  end
  if path.replay then
    self.camT = core_replay.getPositionSeconds()
    if self.camT > markers[#markers].time then
      self.camT = markers[#markers].time
    end
    self.ctrlPoint = 0
  else
    self.camT = self.camT + data.dt
  end

  self.fovOffset = self.fovOffset or 0
  path.rotFixId = path.rotFixId or 1

  if self.ctrlPoint == 0 then
    if self.customData and self.customData.useJsonVersion and (self.camT < markers[1].time) then
      data.res.pos = markers[1].pos
      data.res.rot = markers[1].rot
      if path.manualFov then
        if self.fovOffset > 0 then
          local rdz = 4.5*data.dt*(MoveManager.zoomIn - MoveManager.zoomOut) * 120 / (120 - markers[1].fov) * 0.5
          self.fovOffset = clamp(self.fovOffset + rdz, -1, 1)
          data.res.fov = clamp(markers[1].fov + (120 - markers[1].fov) * self.fovOffset, 10, 120)
        else
          local rdz = 4.5*data.dt*(MoveManager.zoomIn - MoveManager.zoomOut) * 120 / (markers[1].fov - 10) * 0.5
          self.fovOffset = clamp(self.fovOffset + rdz, -1, 1)
          data.res.fov = clamp(markers[1].fov + (markers[1].fov - 10) * self.fovOffset, 10, 120)
        end
      else
        data.res.fov = markers[1].fov
      end
      return true
    else
      self.ctrlPoint = 1
    end
  end

  -- simulate interpolated camera
  local n1, n2, n3, n4 = core_paths.getMarkerIds(path, self.ctrlPoint)

  local nextTime = self:getGlobalTime(path, n3, path.looped)
  while self.camT > nextTime and self.ctrlPoint <= core_paths.getEndIdx(path) - 1 do
    if self.customData and self.customData.onNextControlPoint then
      self.customData:onNextControlPoint(self.ctrlPoint+1, #path.markers)
    end
    self.ctrlPoint = self.ctrlPoint + 1
    n1, n2, n3, n4 = core_paths.getMarkerIds(path, self.ctrlPoint)
    nextTime = self:getGlobalTime(path, n3, path.looped)
  end

  if self.ctrlPoint ~= self.lastFrameCtrlPoint then
    -- Passed a marker
    self.lastCtrlPointR2 = deepcopy(self.lastFrameR2)
    if markers[n2].cut then
      data.res.pos = markers[n3].pos
      data.res.rot = markers[n3].rot
      data.res.fov = markers[n3].fov or 60
      self.ctrlPoint = self.ctrlPoint + 1
      return true
    end
  end

  self.lastFrameCtrlPoint = self.ctrlPoint
  local camTLocal = self.camT - self:getGlobalTime(path, n2)
  local p1, p2, p3, p4 = markers[n1].pos, markers[n2].pos, markers[n3].pos, markers[n4].pos
  local t1, t2, t3 = self:getTimeToNext(path, n1), self:getTimeToNext(path, n2), self:getTimeToNext(path, n3)

  if path.markers[n2].movingStart and (n1 == n2) then
    -- Add a virtual marker at the start for p1, so the cam speed is smoother
    if p3:distance(p2) == 0 then
      p1 = p2
      t1 = 0
    else
      local direction = catmullRomChordal(p1, p2, p3, p4, 0.1, markers[n2].positionSmooth) - p2
      p1 = p2 - direction
      t1 = t2 * direction:length() / p3:distance(p2)
    end
  end

  -- TODO with movingEnd the rotation doesnt have the correct timing
  if path.markers[n2].movingEnd and (n3 == n4) then
    -- Add a virtual marker at the end for p4, so the cam speed is smoother
    if p3:distance(p2) == 0 then
      p4 = p3
      t3 = 0
    else
      local direction = p3 - catmullRomChordal(p1, p2, p3, p4, 0.9, markers[n2].positionSmooth)
      p4 = p3 + direction
      t3 = t2 * direction:length() / p3:distance(p2)
    end
  end

  local tNorm = calculateTnorm(p1:distance(p2), p2:distance(p3), p3:distance(p4), t1, t2, t3, camTLocal)
  local pos = catmullRomChordal(p1, p2, p3, p4, tNorm, markers[n2].positionSmooth)

  local target = origin
  if data.pos then
    target = data.pos
  end
  local targetRotation = quatFromDir(target - pos, vec3(0,0,1))

  local r1 = self.lastCtrlPointR2 or (markers[n1].trackPosition and targetRotation or markers[n1].rot)
  local r2 = markers[n2].trackPosition and targetRotation or markers[n2].rot
  local r3 = markers[n3].trackPosition and targetRotation or markers[n3].rot
  local r4 = markers[n4].trackPosition and targetRotation or markers[n4].rot

  if path.markers[n2].movingStart and (n1 == n2) then
    -- Set the correct rotation to the virtual marker at the start
    local catMullRot = catmullRomCentripetal(r1, r2, r3, r4, 0.1):normalized()
    r1 = r2:nlerp(catMullRot, -1)
  end

  if path.markers[n2].movingEnd and (n3 == n4) then
    -- Set the correct rotation to the virtual marker at the end
    local catMullRot = catmullRomCentripetal(r1, r2, r3, r4, 0.9):normalized()
    r4 = r3:nlerp(catMullRot, -1)
  end

  -- Fix rotations
  for i = path.rotFixId, self.ctrlPoint - 2 do
    if markers[i].rot:dot(markers[i + 1].rot) < 0 then
      markers[i + 1].rot = -markers[i + 1].rot
    end
  end
  path.rotFixId = self.ctrlPoint

  if r1:dot(r2) < 0 then r2 = -r2 end
  if r2:dot(r3) < 0 then r3 = -r3 end
  if r3:dot(r4) < 0 then r4 = -r4 end
  self.lastFrameR2 = r2

  local rot = catmullRomCentripetal(r1, r2, r3, r4, calculateTnorm(sqrt(r1:distance(r2)), sqrt(r2:distance(r3)), sqrt(r3:distance(r4)), t1, t2, t3, camTLocal)):normalized()
  local fov = monotonicSteffen(markers[n1].fov or 60, markers[n2].fov or 60, markers[n3].fov or 60, markers[n4].fov or 60, 0, t1, t1 + t2, t1 + t2 + t3, t1 + camTLocal)
  if markers[n1].nearClip then
    local nearClip = monotonicSteffen(markers[n1].nearClip or 0.1, markers[n2].nearClip or 0.1, markers[n3].nearClip or 0.1, markers[n4].nearClip or 0.1, 0, t1, t1 + t2, t1 + t2 + t3, t1 + camTLocal)
    data.res.nearClip = nearClip
  end
  -- restarting when reached the end
  if self.ctrlPoint >= core_paths.getEndIdx(path) - 1 and self.camT >= nextTime then
    self.ctrlPoint = 0
    self.camT = 0
    self.lastCtrlPointR2 = nil
    self.lastFrameR2 = nil

    if self.customData then
      if self.customData.finishedPath then
        self.customData:finishedPath()
      end
      if self.customData.useJsonVersion then
        self.path = self.customData:getNextPath()
      else
        self.pathName = self.customData:getNextPath()
      end
    end
  end

  -- application
  data.res.pos = pos
  data.res.rot = rot
  if path.manualFov then
    if self.fovOffset > 0 then
      local rdz = 4.5*data.dt*(MoveManager.zoomIn - MoveManager.zoomOut) * 120 / (120 - fov) * 0.5
      self.fovOffset = clamp(self.fovOffset + rdz, -1, 1)
      data.res.fov = clamp(fov + (120 - fov) * self.fovOffset, 10, 120)
    else
      local rdz = 4.5*data.dt*(MoveManager.zoomIn - MoveManager.zoomOut) * 120 / (fov - 10) * 0.5
      self.fovOffset = clamp(self.fovOffset + rdz, -1, 1)
      data.res.fov = clamp(fov + (fov - 10) * self.fovOffset, 10, 120)
    end
  else
    data.res.fov = fov
  end

  if path.replay and markers[self.ctrlPoint] and markers[self.ctrlPoint].bullettime and markers[self.ctrlPoint].bullettime ~= self.lastSpeed then
    core_replay.setSpeed(markers[self.ctrlPoint].bullettime)
    self.lastSpeed = markers[self.ctrlPoint].bullettime
  end

  return true
end

local function replayExists(replay)
  if replay == "" then return false end
  return FS:fileExists(replay)
end

function C:setCustomData(data)
  self:reset()
  self.customData = data
  self.camT = data.offset or 0
  if self.customData.path and self.customData.path.replay then
    if replayExists(self.customData.path.replay) then
      if (self.customData.path.replay ~= core_replay.getLoadedFile()) then
        core_replay.loadFile(self.customData.path.replay)
      end
    else
      self.customData.path.replay = nil
    end
  end
end

function C:reset()
  if self.customData and self.customData.reset then
    self.customData:reset()
  end
  self.path = nil
  self.camT = 0
  self.ctrlPoint = 0
  self.fovOffset = 0
  self.pathName = nil

  -- This is for backwards compatibility. Might just be a typo of "pathName", but i'll keep it in for safety
  self.pathname = nil
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
