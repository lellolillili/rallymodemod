-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local views = {}

local function addView(name, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, resolutionX, resolutionY, renderDetail, fov, nearClip, farClip, enableShadows, windowX, windowY, borderless)
  table.insert(
    views,
    {
      name = name,
      position = vec3(positionX or 0, positionY or 0, positionZ or 0),
      rotation = quatFromEuler(rotationX or 0, rotationY or 0, rotationZ or 0),
      resolution = Point2I(resolutionX or 1080, resolutionY or 720),
      renderDetail = renderDetail or 0.3,
      fov = math.rad(fov or 80),
      clipPlane = Point2F(nearClip or 1, farClip or 1000),
      enableShadows = enableShadows or 0,
      windowX = windowX or 0,
      windowY = windowY or 0,
      borderless = borderless or false
    }
  )
end

local function removeAllViews()
  if destroyCameraToWindow then
    for _, view in ipairs(views) do
      destroyCameraToWindow(view.name)
    end
  end
  views = {}
end

local function onPreRender()
  if getOrCreateCameraToWindow and requestCameraToWindowRender then
    local veh = be:getPlayerVehicle(0)
    local p0 = Point2F(0, 0)
    if veh then
      local vehicleRotation = quatFromDir(veh:getDirectionVector(), veh:getDirectionVectorUp())
      local vehiclePosition = veh:getPosition()
      for _, view in ipairs(views) do
        local window = getOrCreateCameraToWindow(view.name, view.windowX, view.windowY, view.borderless)
        local position = vehiclePosition + (vehicleRotation * view.position)
        local rotation = view.rotation * vehicleRotation
        position = vec3(position.x, position.y, position.z)
        rotation = QuatF(rotation.x, rotation.y, rotation.z, rotation.w)
        requestCameraToWindowRender(window, position, rotation, view.resolution, view.renderDetail, view.fov, view.clipPlane, view.enableShadows, p0)
      end
    end
  end
end

local function onUnload()
  M.removeAllViews()
end

M.onPreRender = onPreRender
M.onUnload = onUnload
M.addView = addView
M.removeAllViews = removeAllViews

return M
