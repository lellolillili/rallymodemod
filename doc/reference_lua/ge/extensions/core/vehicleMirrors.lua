-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = extensions.ui_imgui

local function onVehicleSwitched(oldVehId, newVehId)
end

local focusVehicleID = nil -- which vehicle ID the data is valid for
local vehicleMirrorData = nil -- mirror data
local requestStatus = 0 -- 0 = not done, 1 = in progress, 2 = complete

local userCorrection = vec3()
local showDebug = im.BoolPtr(false)
local time = 0
local updateTime = im.FloatPtr(0.3)


local function renderMirrors(dtSim, veh)
  time = time + dtSim
  if time < updateTime[0] then
    return
  end
  time = time - updateTime[0]

  local camPos = getCameraPosition()
  local camUp = vec3(getCameraUp())
  local vehPos = veh:getPosition()

  local mirrorCamPos = vec3()
  for _, m in pairs(vehicleMirrorData) do
    local id1 = vec3(veh:getNodePosition(m.id1))
    local id2 = vec3(veh:getNodePosition(m.id2))
    local id3 = vec3(veh:getNodePosition(m.id3))

    mirrorCamPos = (id1 + id3) * 0.5 + vehPos

    local id32 = id3 - id2

    local norm = (id2 - id1):cross(id32):normalized()

    local lookDir = (norm + m.userCorrection):normalized()
    --local mirrorCamQuatF = quatFromDir(norm, id32:normalized())

    local camMirrorDir = (camPos - mirrorCamPos)
    local reflectionDir = (camMirrorDir - 2 * camMirrorDir:projectToOriginPlane(lookDir)):normalized()
    local c = camMirrorDir:cross(lookDir)
    local refrectCamQuatF = quatFromDir(reflectionDir, id32:normalized())

    if showDebug[0] then
      debugDrawer:drawSphere(mirrorCamPos, 0.01, ColorF(1,0,0,1))
      debugDrawer:drawCylinder(mirrorCamPos, (mirrorCamPos + lookDir * 0.2), 0.005, ColorF(1,0,0,1))
      debugDrawer:drawCylinder(mirrorCamPos, (mirrorCamPos + reflectionDir * 0.4), 0.01, ColorF(0,1,0,1))
    end

    debugDrawer:setDrawingEnabled(false)
    veh:renderCameraToMaterial(m.textureTarget,
      mirrorCamPos,
      QuatF(refrectCamQuatF.x, refrectCamQuatF.y, refrectCamQuatF.z, refrectCamQuatF.w),
      Point2I(128, 128),
      70,
      Point2F(0.1, 250)
    )
    debugDrawer:setDrawingEnabled(true)
  end
end

local windowOpen = im.BoolPtr(false)
local function renderUI()
  if not vehicleMirrorData or not vehicleMirrorData[0] then return end

  local m = vehicleMirrorData[0]

  if im.Begin("Mirror control", windowOpen) then
    if im.Button("<") then
      m.userCorrection.x = m.userCorrection.x + 0.05
    end
    im.SameLine()
    if im.Button(">") then
      m.userCorrection.x = m.userCorrection.x - 0.05
    end
    im.SameLine()
    if im.Button("/\\") then
      m.userCorrection.z = m.userCorrection.z + 0.05
    end
    im.SameLine()
    if im.Button("V") then
      m.userCorrection.z = m.userCorrection.z - 0.05
    end
    im.SameLine()
    if im.Button("reset") then
      m.userCorrection = vec3()
    end
    im.SameLine()
    if im.Button("unload") then
      extensions.unload('core_vehicleMirrors')
    end
    im.SameLine()
    im.SliderFloat("updateRate", updateTime, 0, 1)
    im.Checkbox("debug", showDebug)
  end
  im.End()
end

local function onPreRender(dtReal, dtSim, dtRaw)
  local veh = be:getPlayerVehicle(0)
  if not veh then return end
  local vData = extensions.core_vehicle_manager.getVehicleData(veh:getId())
  if not vData then return end

  if focusVehicleID ~= veh:getId() or not vehicleMirrorData then
    if requestStatus == 0 then
      vehicleMirrorData = nil
      focusVehicleID = veh:getId()
      extensions.hook('onVehicleMirrorsChanged', focusVehicleID, vData.mirrors or {})
      requestStatus = 1
    end
    return
  end
  -- renderMirrors(dtSim, veh)

  --renderUI()
end

local function onVehicleMirrorsChanged(id, data)
  if id ~= focusVehicleID then return end
  requestStatus = 2
  vehicleMirrorData = data
  --dump({'got config', id, data})

  -- add some more stuff
  for _, m in pairs(vehicleMirrorData) do
    m.userCorrection = vec3()
  end

end

M.onVehicleSwitched = onVehicleSwitched
M.onVehicleMirrorsChanged = onVehicleMirrorsChanged
M.onPreRender = onPreRender

return M