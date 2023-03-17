-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local manualzoom = require('core/cameraModes/manualzoom')
local imgui = ui_imgui
local stopZooming = 0

local previousVehicleRenderDist
local zoomSpeed = 5

local C = {}
C.__index = C

local mouseDragStartPos
local mouseDragCamStartPos

function C:init()
  self.fovMin = 25 -- This will be overwritten in bigMapMode.lua based on map size
  self.fovMax = 42
  self.angle = 53
  self.rotAngle = 25
  self.posTransitionTime = 2.4
  self.transitionActive = true
  self.movementSpeed = 40
  self.nearClipValue = 100
  self.tod = 0.13 -- Around 15:00
  self.drawIcons = true
  self.initialCamData = nil
  self.mapBoundaries = nil

  self.isGlobal = true
  self.hidden = true
  self.manualzoom = manualzoom()
  self.manualzoom:init(self.fovMax, self.fovMin, self.fovMax)
  self:reset()
end

function C:reset()
  self.manualzoom:reset()
end

function C:setLevelProperties()
  self:init()
end

function C:onCameraChanged(focused)
  local vehicle = be:getPlayerVehicle(0)
  if focused then
    if vehicle then
      previousVehicleRenderDist = vehicle.renderDistance
      vehicle.renderDistance = 5000
    end
    self.manualzoom:reset()
  else
    if previousVehicleRenderDist and vehicle then
      vehicle.renderDistance = previousVehicleRenderDist
    end
    mouseDragStartPos = nil
    mouseDragCamStartPos = nil
  end
end

local function getRayCastHit(ray, relativeToCam)
  local dist = intersectsRay_Plane(ray.pos, ray.dir, core_terrain.getTerrain() and core_terrain.getTerrain():getWorldBox().minExtents or vec3(0,0,0), vec3(0,0,1))
  local hitPoint = ray.pos + ray.dir * dist
  if relativeToCam then
    hitPoint = hitPoint - getCameraPosition()
  end
  return hitPoint
end

local zoomMouseStartPos
local zoomDirectionLastFrame = 0
function C:zoom(value)
  if value ~= 0 then
    local zoomVal = -zoomSpeed * value
    if zoomDirectionLastFrame ~= (value > 0) then
      stopZooming = 0
    end
    stopZooming = stopZooming + 0.1
    core_camera.cameraZoom(zoomVal * stopZooming)
    zoomMouseStartPos = getRayCastHit(getCameraMouseRay())
    zoomDirectionLastFrame = value > 0
  end
end

local camToLookAtPoint
function C:setCustomData(data)
  if data then
    self.initialCamData = data.initialCamData
    local camLookAtPoint = getRayCastHit({pos = self.initialCamData.pos or getCameraPosition(), dir = self.initialCamData.rot and self.initialCamData.rot * vec3(0,1,0) or getCameraForward()})
    camToLookAtPoint = camLookAtPoint - self.initialCamData.pos or getCameraPosition()
  else
    local camLookAtPoint = getRayCastHit({pos = getCameraPosition(), dir = getCameraForward()})
    camToLookAtPoint = camLookAtPoint - getCameraPosition()
  end
  self.firstUpdate = true
  self.manualzoom:init(self.fovMax, self.fovMin, self.fovMax)
end

-- returns the relative zoom level in 3 different stages
function C:getZoomStage(fov)
  local fovNorm = (fov - self.fovMin) / (self.fovMax - self.fovMin)
  if fovNorm <= 0.33 then return 0 end
  if fovNorm <= 0.66 then return 0.5 end
  return 1
end

function C:update(data)
  if self.initialCamData and self.firstUpdate then
    data.res.pos = self.initialCamData.pos
    data.res.rot = self.initialCamData.rot
    data.res.fov = self.fovMax
    self.bigMapCamRotation = self.initialCamData.rot
    self.bigMapCamPosition = self.initialCamData.pos
  end
  self.firstUpdate = false

  local zoomBefore = self.manualzoom.fov
  self.manualzoom:update(data)
  local zoomAfter = self.manualzoom.fov
  if freeroam_bigMapMode and zoomBefore ~= zoomAfter then
    if self:getZoomStage(zoomBefore) ~= self:getZoomStage(zoomAfter) then
      freeroam_bigMapMode.updateMergeRadius(self:getZoomStage(zoomAfter))
      gameplay_missions_missionEnter.skipNextIconFading()
    end
  end

  if zoomBefore ~= zoomAfter and zoomMouseStartPos then
    -- Move the camera to keep the mouse cursor roughly on the same spot
    local camLookAtPoint = getRayCastHit({pos = getCameraPosition(), dir = getCameraForward()})
    local zoomCamStartPos = vec3(self.bigMapCamPosition)
    local zoomMouseEndPos = zoomMouseStartPos + (camLookAtPoint - zoomMouseStartPos) * (1-(zoomAfter/zoomBefore))
    local newCamPos = zoomCamStartPos - (zoomMouseEndPos - zoomMouseStartPos)
    self.bigMapCamPosition = newCamPos
  end

  if mouseDragStartPos then
    local mouseDragEndPos = getRayCastHit(getCameraMouseRay(), true)
    if mouseDragEndPos then
      local newCamPos = mouseDragCamStartPos - (mouseDragEndPos - mouseDragStartPos)
      self.bigMapCamPosition = newCamPos
    end
  end

  if MoveManager.forward ~= 0 or MoveManager.backward ~= 0 or MoveManager.left ~= 0 or MoveManager.right ~= 0 then
    local zoomBasedMovementSpeedFactor = 0
    if freeroam_bigMapMode and not freeroam_bigMapMode.isUIPopupOpen() then
      local mapExtents = self.mapBoundaries:getExtents()
      local avgSideLength = (mapExtents.x + mapExtents.y) / 2
      zoomBasedMovementSpeedFactor = (avgSideLength / 4096) * (data.res.fov / self.fovMax)
    end

    local forwardDir = quat(self.bigMapCamRotation) * vec3(0,1,0)
    forwardDir.z = 0
    forwardDir:normalize()
    local rightDir = forwardDir:cross(vec3(0,0,1))
    self.bigMapCamPosition = self.bigMapCamPosition + (MoveManager.forward * forwardDir + MoveManager.backward * -forwardDir + MoveManager.left * -rightDir + MoveManager.right * rightDir) * self.movementSpeed * data.dtReal * 80 * zoomBasedMovementSpeedFactor
  end

  if stopZooming > 0 then
    stopZooming = stopZooming - data.dtReal
    if stopZooming <= 0 then
      core_camera.cameraZoom(0)
      stopZooming = 0
      zoomMouseStartPos = nil
    end
  end

  data.res.nearClip = self.nearClipValue

  -- Keep the camera in the bounds of the map
  if camToLookAtPoint then
    local mapExtents = self.mapBoundaries:getExtents()
    local avgSideLength = (mapExtents.x + mapExtents.y) / 2
    local mapSizeFactor = avgSideLength / 10
    self.bigMapCamPosition.x = clamp(self.bigMapCamPosition.x, self.mapBoundaries.minExtents.x - camToLookAtPoint.x - mapSizeFactor, self.mapBoundaries.maxExtents.x - camToLookAtPoint.x + mapSizeFactor)
    self.bigMapCamPosition.y = clamp(self.bigMapCamPosition.y, self.mapBoundaries.minExtents.y - camToLookAtPoint.y - mapSizeFactor, self.mapBoundaries.maxExtents.y - camToLookAtPoint.y + mapSizeFactor)
  end

  data.res.rot = self.bigMapCamRotation
  if self.initialCamData then
    self.bigMapCamPosition.z = self.initialCamData.pos.z
  end
  data.res.pos = self.bigMapCamPosition
  return true
end

function C:onMouseButton(buttonDown, mouseDragging)
  if buttonDown then
    mouseDragStartPos = getRayCastHit(getCameraMouseRay(), true)
    mouseDragCamStartPos = self.bigMapCamPosition
  else
    mouseDragStartPos = nil
  end
end

function C:onSerialize()
  if self.mapBoundaries then
    self.mapBoundaries = {minExtents = self.mapBoundaries.minExtents, maxExtents = self.mapBoundaries.maxExtents}
  end
end

function C:onDeserialized()
  if self.mapBoundaries then
    local newMapBoundaries = Box3F()
    newMapBoundaries.minExtents = self.mapBoundaries.minExtents
    newMapBoundaries.maxExtents = self.mapBoundaries.maxExtents
    self.mapBoundaries = newMapBoundaries
  end
end

-- DO NOT CHANGE CLASS IMPLEMENTATION BELOW

return function(...)
  local o = ... or {}
  setmetatable(o, C)
  o:init()
  return o
end
