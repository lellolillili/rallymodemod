-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_rayCastTest'
local imgui = ui_imgui
local helperTransform = MatrixF(true)
local toolWindowName = "raycastTest"

local rayCastModes = {"Gameengine Raycast", "Physics Raycast"}
local upVec = vec3(0,0,1)
local maxRayDist = 200

local function beginDrag()
end

local function endDrag()
end

local function dragging()
end

local function drawHelper()
  local pos = helperTransform:getColumn(3)
  debugDrawer:drawSphere(pos, 0.2, ColorF(1, 0.5, 0.2, 0.25))
  debugDrawer:drawLine(pos, (vec3(pos) + vec3(0, 0, 4)), ColorF(1, 0, 0, 0.25))
  debugDrawer:drawSphere((vec3(pos) + vec3(0, 0, 4)), 0.2, ColorF(0, 1, 0.2, 0.25))
end


local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Raycast Test") then
    local rayCastModesArray = imgui.ArrayCharPtrByTbl(rayCastModes)
    local rayCastMode = imgui.IntPtr(editor.getPreference("raycastTest.general.rayCastMode"))
    if imgui.Combo1("##rayCastMode", rayCastMode, rayCastModesArray) then
      editor.setPreference("raycastTest.general.rayCastMode", rayCastMode[0])
    end
  end
  editor.endWindow()
end

local function onWindowMenuItem()
  editor.selectEditMode(editor.editModes.checkTerrainCastRay)
end

local function onExtensionLoaded()
end

local function editModeActivate()
  editor.setAxisGizmoMode(editor.AxisGizmoMode_Translate)
  editor.setAxisGizmoAlignment(editor.AxisGizmoAlignment_World)
  editor.setAxisGizmoTransform(helperTransform)
  editor.showWindow(toolWindowName)
end

local function editModeDeactivate()
  editor.hideWindow(toolWindowName)
end

local function editModeUpdate()
  local camMouseRay = getCameraMouseRay()
  local rayCastInfo = cameraMouseRayCast(true, -1)

  if editor.getPreference("raycastTest.general.rayCastMode") == 0 then
    if rayCastInfo and rayCastInfo.object then
      helperTransform:setPosition(vec3(rayCastInfo.pos.x, rayCastInfo.pos.y, rayCastInfo.pos.z))
    end
    drawHelper()
    local pos = helperTransform:getColumn(3)
    if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end
    local hit = Engine.castRay((vec3(pos) + vec3(0, 0, 4)), (vec3(pos) + vec3(0, 0, -4)), true, false)
    if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end
    if hit then
      debugDrawer:drawSphere(hit.pt, 0.1, ColorF(0, 1, 0, 1))
      debugDrawer:drawLine(hit.pt, (vec3(hit.pt) + vec3(hit.norm)), ColorF(0, 1, 1, 1))
      debugDrawer:drawSphere((vec3(hit.pt) + vec3(hit.norm)), 0.08, ColorF(0, 1, 1, 1))
    end

  elseif editor.getPreference("raycastTest.general.rayCastMode") == 1 then
    local camPos = vec3(camMouseRay.pos)
    local camMouseRayDir = vec3(camMouseRay.dir)
    local camRot = quat(getCameraQuat())
    local camUp = camRot * upVec

    local targetDist = castRayStatic(camPos, camMouseRayDir, maxRayDist)
    local targetPos = camPos + camMouseRayDir * targetDist

    local rayGridCenter = camPos + camUp
    local dir = targetPos - rayGridCenter
    dir:normalize()

    local mouseRayRight = dir:cross(camUp)
    mouseRayRight:normalize()
    local mouseRayUp = dir:cross(mouseRayRight)
    mouseRayUp:normalize()

    local points = {}
    local minDist = math.huge
    local maxDist = -math.huge
    for x = -1, 1, 0.5 do
      for y = -1, 1, 0.5 do
        local rayStart = rayGridCenter + x * mouseRayRight + y * mouseRayUp
        local dist = castRayStatic(rayStart, dir, maxRayDist)
        if dist < maxRayDist then
          local hitPoint = (rayStart + dir * dist)
          local camDist = hitPoint:distance(camPos)
          if camDist < minDist then minDist = camDist end
          if camDist > maxDist then maxDist = camDist end
          table.insert(points, hitPoint)
        end
      end
    end

    for _, point in ipairs(points) do
      local dist = point:distance(camPos)
      local saturation = (dist-minDist) / (maxDist-minDist)
      debugDrawer:drawSphere(point, 0.15, ColorF(saturation, 1, saturation, 1))
    end
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("raycastTest")
  prefsRegistry:registerSubCategory("raycastTest", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    -- hidden
    {rayCastMode = {"number", 0, "", nil, nil, nil, true}}
  })
end

local function onEditorInitialized()
  editor.editModes.checkTerrainCastRay =
  {
    onActivate = editModeActivate,
    onDeactivate = editModeDeactivate,
    onUpdate = editModeUpdate,
    actionMap = "RayCastTest",
    auxShortcuts = {}
  }
  editor.editModes.checkTerrainCastRay.auxShortcuts["esc"] = "Exit check"
  editor.registerWindow(toolWindowName, imgui.ImVec2(200,100))
  editor.addWindowMenuItem("Raycast Test", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

local function onEditorToolWindowHide(wndName)
  if toolWindowName == wndName then
    editor.selectEditMode(editor.editModes.objectSelect)
  end
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onExtensionLoaded = onExtensionLoaded
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorToolWindowHide = onEditorToolWindowHide

return M