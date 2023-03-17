-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui
local imUtils = require('ui/imguiUtils')
local toolWindowName = "Render test"

local mode = 'top'

local vecUp = vec3(0, 0, 1)
local ortho = im.BoolPtr(true)
local renderMain = im.BoolPtr(true)
local attachToObject = im.BoolPtr(true)
local nearClip = im.FloatPtr(12)
local farClip = im.FloatPtr(2500)
local fov = im.FloatPtr(60)
local pos
local rot
local lastMouseDragPos

local function onEditorGui()
  if not pos then pos = getCameraPosition() end
  if not rot then rot = quat(getCameraQuat()) end
  im.PushStyleVar1(im.StyleVar_WindowBorderSize, 0)
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(0, 0))
  if editor.beginWindow(toolWindowName, toolWindowName) then
    if im.Button('left') then mode = 'left' end im.SameLine()
    if im.Button('right') then mode = 'right' end im.SameLine()
    if im.Button('front') then mode = 'front' end im.SameLine()
    if im.Button('back') then mode = 'back' end im.SameLine()
    if im.Button('top') then mode = 'top' end im.SameLine()
    if im.Button('bottom') then mode = 'bottom' end im.SameLine()
    if im.Button('3d') then mode = '3d' end im.SameLine()
    if im.Checkbox('Ortho', ortho) then end im.SameLine()
    if im.Checkbox('render Main', renderMain) then
      setRenderWorldMain(renderMain[0])
    end
    im.SameLine()
    if im.Checkbox('attach', attachToObject) then end
    im.SameLine()

    im.PushItemWidth(100)
    im.SliderFloat('near clip', nearClip, 0.001, 55, "%.3f", 4) im.SameLine()
    im.PushItemWidth(100)
    im.SliderFloat('far clip', farClip, 0.001, 5500, "%.3f", 4) im.SameLine()
    im.PushItemWidth(100)
    im.SliderFloat('fov', fov, 0.001, 179, "%.3f", 4)

    local w = im.GetIO().MouseWheel
    fov[0] = fov[0] - w * 10
    if fov[0] < 0.1 then fov[0] = 0.1 end
    if fov[0] > 170 then fov[0] = 170 end

    local availSize = im.GetContentRegionAvail()

    if im.IsMouseClicked(0) then
      lastMouseDragPos = im.GetMousePos()
    end

    local delta = im.ImVec2(0, 0)
    if im.IsMouseDragging(0) then
      attachToObject[0] = false
      local mPos = im.GetMousePos()
      delta.x = (mPos.x - lastMouseDragPos.x) * 0.02 * (fov[0] / 50)
      delta.y = (mPos.y - lastMouseDragPos.y) * 0.02 * (fov[0] / 50)
    end

    local focusPos
    local focusRot
    if attachToObject[0] then
      local veh = be:getPlayerVehicle(0)
      if veh then
        focusPos = veh:getPosition()
        pos = focusPos
        focusRot = quat(veh:getRotation())
        dump{'focusRot = ', focusRot:toEulerYXZ()}

        rot = focusRot
        editor.drawSelectedObjectBBox(veh, ColorF(1, 0, 0, 1))
      end
    end

    local rot = quatFromEuler(math.pi * 0.5, 0, 0)

    --rot = quatFromDir(vec3(0,0,-1), vecUp)
    if focusPos then
      pos.z = focusPos.z + 50
    else
      pos.z = 100
    end
    if im.IsMouseDragging(0) and lastMouseDragPos then
      pos.x = pos.x - delta.x
      pos.y = pos.y + delta.y
      lastMouseDragPos = im.GetMousePos()
    end


    renderCameraToTexture(
      'editorRenderTest',
      pos,
      QuatF(rot.x, rot.y, rot.z, rot.w),
      Point2I(availSize.x, availSize.y),
      fov[0],
      Point2F(nearClip[0], farClip[0]),
      ortho[0]
    )

    local texObj = imUtils.texObj('#editorRenderTest')
    im.Image(texObj.texId, availSize)
    editor.endWindow()
  end
  im.PopStyleVar()
  im.PopStyleVar()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(400,600))
  editor.addWindowMenuItem('Render test', onWindowMenuItem, {groupMenuName = 'Experimental'})
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui

return M