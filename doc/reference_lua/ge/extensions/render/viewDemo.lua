-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- tiny example to demo how to use renderviews

-- extensions.load('render_viewDemo')

local M = {}

local im = ui_imgui
local imUtils = require('ui/imguiUtils')


local renderViewName = 'Demo view 1' -- the name is the unique identifier for renderviews
local renderView = nil

local windowOpen = im.BoolPtr(true)

local imageRes = im.ImVec2(512, 256) -- resolution in pixels

local timer = 0

local function onUpdate(dtReal, dtSim, dtRaw)
  timer = timer + dtSim

  if not renderView then
    -- create the renderview
    renderView = RenderViewManagerInstance:getOrCreateView(renderViewName)
    renderView.luaOwned = true -- make sure the view is deleted properly if the GC collects it

    -- update the parameters
    local mat = QuatF(0, 0, 0, 1):getMatrix()
    mat:setPosition(vec3(0, 0, 0))

    renderView.renderCubemap = false
    renderView.cameraMatrix = mat -- determines where the virtual camera is in 3d space
    renderView.resolution = Point2I(imageRes.x, imageRes.y)
    local tmpRect = RectI()
    tmpRect:set(0, 0, imageRes.x, imageRes.y)
    renderView.viewPort = tmpRect
    renderView.namedTexTargetColor = renderViewName -- important: the target texture, used in texObj
    -- renderView.focusObject
    -- renderView.clearFocusObject()
    -- renderView.getCameraObject()
    -- renderView.setCameraObject()
    -- renderView.clearCameraObject()
    local aspectRatio = imageRes.x / imageRes.y
    local renderOrthogonal = false
    local fov = 75
    local nearClip = 0.1
    local farClip = 2000
    renderView.frustum = Frustum.construct(renderOrthogonal, math.rad(fov), aspectRatio, nearClip, farClip)
    renderView.fov = fov
    renderView.renderEditorIcons = true
  end

  -- move the view around as exanple
  local mat = QuatF(0, 0, 0, 1):getMatrix()
  mat:setPosition(vec3(math.sin(timer), 0, math.cos(timer) + 1.5))
  renderView.cameraMatrix = mat

  -- how to debug drawdraw in only a certain view
  debugDrawer:setTargetRenderView(renderViewName)
  debugDrawer:drawTextAdvanced((vec3(20,20,0)), 'Hello world view :)', ColorF(0,0,0,1), false, true, ColorI(0, 0, 0, 255))
  debugDrawer:clearTargetRenderView()

  -- display the texture in imgui
  im.Begin("Render view test", windowOpen)
  local texObj = imUtils.texObj('#' .. renderViewName)
  im.Image(texObj.texId, imageRes)
  im.End()
end

M.onUpdate = onUpdate

return M