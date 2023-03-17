-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui
local imUtils = require('ui/imguiUtils')

local vecUp = vec3(0, 0, 1)

local renderMain = im.BoolPtr(true)

local createNewViewNextFrame = false -- this is required to not add new things to the table while iterating over it ...

local wndNamePrefix = "Scene View "
local sceneViews = {} -- contains all sceneviews

local tmpRect = RectI()

local editorInit = false

local function createViewFromData(id, data)
  local wndName = wndNamePrefix .. tostring(id)

  sceneViews[id] = {
    name = wndName,
    mode = data.mode or '3d',
    nearClip = im.FloatPtr(data.nearClip or 0.01),
    farClip = im.FloatPtr(data.farClip or 2500),
    fov = im.FloatPtr(data.fov or 70),
    pos = data.pos or getCameraPosition(),
    rot = data.rot or quat(getCameraQuat()),
    lastMouseDragPos = im.ImVec2(0,0),
    attachToObject = im.BoolPtr(data.attachToObject or true),
    editorIconsVisible = im.BoolPtr(data.editorIconsVisible or false),
    ortho = im.BoolPtr(data.ortho or false),
    dragOffset = data.dragOffset or vec3(0,0,0),
    --control = ImguiRenderViewControl.getOrCreate(wndName),
  }

  return wndName
end

-- Using World Editor preferences system to load and save data
-- should store data a different way in future :)
local function init()
  local viewsSerialized = editor.getPreference("vehicleEditor.veView.sceneViews")
  if viewsSerialized then
    for id, data in ipairs(viewsSerialized) do
      if data then
        createViewFromData(id, data)
      else
        sceneViews[id] = false
      end
    end
  end
end

local function saveSettings()
  local viewsSerialized = {}
  for id, view in ipairs(sceneViews) do
    if view then
      viewsSerialized[id] = {
        name = view.name,
        mode = view.mode,
        nearClip = view.nearClip[0],
        farClip = view.farClip[0],
        fov = view.fov[0],
        pos = view.pos,
        rot = view.rot,
        attachToObject = view.attachToObject[0],
        editorIconsVisible = view.editorIconsVisible[0],
        ortho = view.ortho[0],
        dragOffset = view.dragOffset,
      }
    else
      viewsSerialized[id] = false
    end
  end
  editor.setPreference("vehicleEditor.veView.sceneViews", viewsSerialized)
end

local function unload()
  for id, data in ipairs(sceneViews) do
    if data and data.control then
      ImguiRenderViewControl.destroy(data.control)
      data.control = nil
    end
  end

  table.clear(sceneViews)
end

-- creates a new sceneview, arguments can be nil
local function createNewSceneView(id, data)
  if data == nil then data = {} end

  local wndName = createViewFromData(id or tableSize(sceneViews) + 1, data)
  saveSettings()

  editor.registerWindow(wndName, im.ImVec2(400,600))
  editor.showWindow(wndName)
end

local function addSceneView()
  local idNotInUse = -1

  for id, view in ipairs(sceneViews) do
    if not view or (view and not editor.isWindowVisible(view.name)) then
      idNotInUse = id
      break
    end
  end

  if idNotInUse == -1 then
    idNotInUse = tableSize(sceneViews) + 1
  end

  local sceneViewName = wndNamePrefix .. tostring(idNotInUse)

  if editor.isWindowRegistered(sceneViewName) then
    if not sceneViews[idNotInUse] then
      createNewSceneView(idNotInUse)
    else
      editor.showWindow(sceneViewName)
    end
  else
    createNewSceneView(idNotInUse)
  end
end

local function _drawgrid(size, rot, gridOrigin, width)
  local p1 = vec3(0,0,-size)
  local p2 = vec3(0,0,size)
  local col = ColorF(0.3,0.3,0.3,1)
  local col2 = ColorF(0.8,0.3,0.3,1)
  local col3 = ColorF(0.3,0.6,0.3,1)
  local bgColor = ColorF(1,1,1,1)
  for i = -size, size, 0.25 do
    p1.x = i
    p2.x = i
    local c = col
    if i % 2 == 0 then
      c = col3
    elseif i % 1 == 0 then
      c = col2
    end
    debugDrawer:drawLine(rot * p1 + gridOrigin, rot * p2 + gridOrigin, c)
    --debugDrawer:drawLineInstance(rot * p1 + gridOrigin, rot * p2 + gridOrigin, width, c)
  end
  p1.x = -size
  p2.x = size
  for i = -size, size, 0.25 do
    p1.z = i
    p2.z = i
    local c = col
    if i % 2 == 0 then
      c = col3
    elseif i % 1 == 0 then
      c = col2
    end
    debugDrawer:drawLine(rot * p1 + gridOrigin, rot * p2 + gridOrigin, c)
    --debugDrawer:drawLineInstance(rot * p1 + gridOrigin, rot * p2 + gridOrigin, width, c)
  end
end

local function _windowContent(id, sceneViewName, view)
  debugDrawer:setTargetRenderView(sceneViewName)

  local delta = vec3(0, 0, 0)
  local gridSize = 5 -- meters
  local gridLineWidth = 0.5

  if view.isHovered then
    -- zooming
    local w = im.GetIO().MouseWheel
    if view.ortho[0] then
      view.fov[0] = view.fov[0] - w * 10
      if view.fov[0] < 0.1 then view.fov[0] = 0.1 end
      if view.fov[0] > 170 then view.fov[0] = 170 end
    else
      delta.z = - w
    end

    if w ~= 0 then saveSettings() end
  end

  local availSize = im.GetContentRegionAvail()

  if im.IsMouseClicked(0) then
    view.lastMouseDragPos = im.GetMousePos()
  end

  -- view dragging?
  if view.mouseDragging0 then
    local mPos = im.GetMousePos()
    delta.x = (mPos.x - view.lastMouseDragPos.x) * 0.005 * (view.fov[0] / 50)
    delta.y = (mPos.y - view.lastMouseDragPos.y) * 0.005 * (view.fov[0] / 50)
  end

  local focusPos
  local focusRot
  local focusObj
  if view.attachToObject[0] then
    focusObj = be:getPlayerVehicle(0)
    if focusObj then
      focusRot = quat(focusObj:getRefNodeRotation())
      focusPos = focusObj:getPosition() + focusRot * view.dragOffset
      view.pos = focusObj:getPosition()
      view.rot = focusRot
    end
  end

  -- the different views. buggy and rushed.
  if view.mode == 'left' then
    view.rot = quatFromDir(vec3(-1,0,0), vecUp)
    if view.mouseDragging0 and view.lastMouseDragPos then
      view.dragOffset = view.dragOffset + vec3(0, -delta.x, delta.y)
    end
    view.dragOffset = view.dragOffset + vec3(delta.z, 0, 0)
    if focusObj then
      view.pos = focusPos + focusRot * vec3(10, 0, 0)
      view.rot = quatFromDir(focusPos - view.pos, vecUp)
      _drawgrid(gridSize, view.rot, focusPos - focusRot * view.dragOffset, gridLineWidth)
    end
  elseif view.mode == 'right' then
    view.rot = quatFromDir(vec3(1,0,0), vecUp)
    if view.mouseDragging0 and view.lastMouseDragPos then
      view.dragOffset = view.dragOffset + vec3(0, delta.x, delta.y)
    end
    view.dragOffset = view.dragOffset + vec3(delta.z, 0, 0)
    if focusObj then
      view.pos = focusPos + focusRot * vec3(-3, 0, 0)
      view.rot = quatFromDir(focusPos - view.pos, vecUp)
      _drawgrid(gridSize, view.rot, focusPos - focusRot * view.dragOffset, gridLineWidth)
    end
  elseif view.mode == 'front' then
    view.rot = quatFromDir(vec3(0,1,0), vecUp)
    if view.mouseDragging0 and view.lastMouseDragPos then
      view.dragOffset = view.dragOffset + vec3(-delta.x, 0, delta.y)
    end
    view.dragOffset = view.dragOffset + vec3(0, delta.z, 0)
    if focusObj then
      view.pos = focusPos + focusRot * vec3(0, -3, 0)
      view.rot = quatFromDir(focusPos - view.pos, vecUp)
      _drawgrid(gridSize, view.rot, focusPos - focusRot * view.dragOffset, gridLineWidth)
    end
  elseif view.mode == 'back' then
    view.rot = quatFromDir(vec3(0,-1,0), vecUp)
    if view.mouseDragging0 and view.lastMouseDragPos then
      view.dragOffset = view.dragOffset + vec3(delta.x, 0, delta.y)
    end
    view.dragOffset = view.dragOffset + vec3(0, delta.z, 0)
    if focusObj then
      view.pos = focusPos + focusRot * vec3(0, 6, 0)
      view.rot = quatFromDir(focusPos - view.pos, vecUp)
      _drawgrid(gridSize, view.rot, focusPos - focusRot * view.dragOffset, gridLineWidth)
    end
  elseif view.mode == 'top' then
    view.rot = quatFromDir(vec3(0,0,-1), vec3(1,0,0))
    if view.mouseDragging0 and view.lastMouseDragPos then
      view.dragOffset = view.dragOffset + vec3(delta.x, -delta.y, 0)
    end
    view.dragOffset = view.dragOffset + vec3(0, 0, delta.z)
    if focusObj then
      local fwd = focusObj:getDirectionVector()
      view.pos = focusPos + focusRot * vec3(0, 0, 5)
      view.rot = quatFromDir(vec3(0,0,-1), fwd)
      --view.rot = quatFromDir(focusPos - view.pos, vecUp)
      _drawgrid(gridSize, view.rot, focusPos - focusRot * view.dragOffset, gridLineWidth)
    end
  elseif view.mode == 'bottom' then
    view.rot = quatFromDir(vec3(0,0,1), vecUp)
    if view.mouseDragging0 and view.lastMouseDragPos then
      view.dragOffset = view.dragOffset + vec3(delta.x, delta.y, 0)
    end
    view.dragOffset = view.dragOffset + vec3(0, 0, delta.z)
    if focusObj then
      view.pos = focusPos + focusRot * vec3(0.01, 0.01, -5)
      view.rot = quatFromDir(focusPos - view.pos, vecUp)
      _drawgrid(gridSize, view.rot, focusPos - focusRot * view.dragOffset, gridLineWidth)
    end
  elseif view.mode == '3d' then
    focusObj = nil
    view.pos = getCameraPosition()
    view.rot = quat(getCameraQuat())
  end

  if delta.x ~= 0 or delta.y ~= 0 then saveSettings() end

  -- construct world matrix
  local mat = QuatF(view.rot.x, view.rot.y, view.rot.z, view.rot.w):getMatrix()
  mat:setPosition(view.pos)


  local txt = dumps{'type: ', view.mode, 'view.pos: ', view.pos}
  debugDrawer:drawTextAdvanced((vec3(0,20,0)), "PLEASE DISABLE AMBIENT OCCLUSION", ColorF(0,0,0,1), false, true, ColorI(0, 0, 0, 255))
  debugDrawer:drawTextAdvanced((vec3(0,40,0)), txt, ColorF(0,0,0,1), false, true, ColorI(0, 0, 0, 255))
  debugDrawer:clearTargetRenderView()

  -- update renderview settings
  if focusObj then
    view.control.renderView.focusObject = focusObj
  else
    view.control.renderView:clearFocusObject()
  end
  view.control.renderView.renderCubemap = false
  view.control.renderView.cameraMatrix = mat
  view.control.renderView.resolution = Point2I(availSize.x, availSize.y)
  tmpRect:set(0, 0, availSize.x, availSize.y)
  view.control.renderView.viewPort = tmpRect

  local aspectRatio = availSize.x / availSize.y
  view.control.renderView.frustum = Frustum.construct(view.ortho[0], math.rad(view.fov[0]), aspectRatio, view.nearClip[0], view.farClip[0])
  view.control.renderView.fov = view.fov[0]
  view.control.renderView.renderEditorIcons = view.editorIconsVisible[0]

  view.control:draw()
  --Imgui_ThreeDView('#' .. sceneViewName)

  -- display the texture in imgui
  --local texObj = imUtils.texObj('#' .. sceneViewName)
  --im.Image(texObj.texId, availSize)

  view.mouseDragging0 = false
  view.isHovered = im.IsItemHovered()
  if view.isHovered then
    view.mouseDragging0 = im.IsMouseDragging(0)
    view.dragMode = ''
    if view.mouseDragging0 then
      view.dragMode = 'translate'
      if im.GetIO().KeyShift then
        view.dragMode = 'rotate'
      end
      view.lastMouseDragPos = im.GetMousePos()

    end
  end

  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(6, 6))
  if im.BeginPopup('viewcontrol' .. tostring(sceneViewName)) then
    local changedOrtho = false
    if im.BeginMenu('Mode') then
      if im.MenuItem1('3D') then
        view.ortho[0] = false
        changedOrtho = true
        view.mode = '3d'
        im.CloseCurrentPopup()
        saveSettings()
      end
      if im.MenuItem1('Left') then
        view.ortho[0] = true
        changedOrtho = true
        view.mode = 'left'
        view.dragOffset = vec3(0,0,0)
        im.CloseCurrentPopup()
        saveSettings()
      end
      if im.MenuItem1('Right') then
        view.ortho[0] = true
        changedOrtho = true
        view.mode = 'right'
        view.dragOffset = vec3(0,0,0)
        im.CloseCurrentPopup()
        saveSettings()
      end
      if im.MenuItem1('Front') then
        view.ortho[0] = true
        changedOrtho = true
        view.mode = 'front'
        view.dragOffset = vec3(0,0,0)
        im.CloseCurrentPopup()
        saveSettings()
      end
      if im.MenuItem1('Back') then
        view.ortho[0] = true
        changedOrtho = true
        view.mode = 'back'
        view.dragOffset = vec3(0,0,0)
        im.CloseCurrentPopup()
        saveSettings()
      end
      if im.MenuItem1('Top') then
        view.ortho[0] = true
        changedOrtho = true
        view.mode = 'top'
        view.dragOffset = vec3(0,0,0)
        im.CloseCurrentPopup()
        saveSettings()
      end
      if im.MenuItem1('Bottom') then
        view.ortho[0] = true
        changedOrtho = true
        view.mode = 'bottom'
        view.dragOffset = vec3(0,0,0)
        im.CloseCurrentPopup()
        saveSettings()
      end
      im.EndMenu()
    end
    if im.Checkbox('Ortho', view.ortho) or changedOrtho then
      if view.ortho[0] then
        view.nearClip[0] = 0.6
        view.farClip[0] = 100
        view.fov[0] = 150
        view.editorIconsVisible[0] = false
      else
        view.nearClip[0] = 0.01
        view.farClip[0] = 2000
        view.fov[0] = 70
        view.editorIconsVisible[0] = true
      end
      saveSettings()
    end
    if im.Checkbox('Render Main', renderMain) then
      setRenderWorldMain(renderMain[0])
      saveSettings()
    end
    if im.Checkbox('Attach to Object', view.attachToObject) then saveSettings() end
    if im.Checkbox('Show Icons', view.editorIconsVisible) then saveSettings() end
    im.PushItemWidth(100)
    if im.SliderFloat('Near Clip', view.nearClip, 0.001, 55, "%.3f", 4) then saveSettings() end
    im.PushItemWidth(100)
    if im.SliderFloat('Far Clip', view.farClip, 0.001, 5500, "%.3f", 4) then saveSettings() end
    im.PushItemWidth(100)
    if im.SliderFloat('FOV', view.fov, 0.001, 179, "%.3f", 4) then saveSettings() end
    im.Separator()
    if im.MenuItem1('Add New View') then
      addSceneView()
      im.CloseCurrentPopup()
    end
    if im.MenuItem1('Delete This View') then
      if view.control then
        ImguiRenderViewControl.destroy(view.control)
        view.control = nil
      end
      editor.hideWindow(view.name)

      sceneViews[id] = false
      im.CloseCurrentPopup()
      saveSettings()
    end
    im.EndPopup()
  end
  im.PopStyleVar()

  if im.IsItemClicked(1) then
    im.OpenPopup('viewcontrol' .. tostring(sceneViewName))
  end
end

local function onEditorGui()
  im.PushStyleVar1(im.StyleVar_WindowBorderSize, 0)
  im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(0, 0))
  if createNewViewNextFrame then
    createNewSceneView()
    createNewViewNextFrame = false
  end

  for id, view in ipairs(sceneViews) do
    if view and editor.isWindowRegistered(view.name) then
      if editor.beginWindow(view.name, view.name) then -- Window open
        if not view.control then
          view.control = ImguiRenderViewControl.getOrCreate(view.name)
        end

        if view.control.renderView then
          _windowContent(id, view.name, view)
        else
          im.TextUnformatted('...')
        end
      else -- Window closed
        if view.control then
          ImguiRenderViewControl.destroy(view.control)
          view.control = nil
        end
      end
      editor.endWindow()
    end
  end

  im.PopStyleVar()
  im.PopStyleVar()

end

local function onEditorHeadlessChange(enabled, toolName)
  if toolName == "vehicleEditor" then
    if enabled then
      init()
    else
      unload()
    end
  end
end

local function onEditorInitialized()
  if not editorInit then
    init()
    editorInit = true
  end
end

--M.createNewSceneView = createNewSceneView
M.addSceneView = addSceneView

M.onEditorGui = onEditorGui
M.onEditorHeadlessChange = onEditorHeadlessChange
M.onEditorInitialized = onEditorInitialized

return M