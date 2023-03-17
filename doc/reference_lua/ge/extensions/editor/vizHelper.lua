-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper for the level people, so they can mark things :)

local M = {}
local logTag = 'editor_viz_helper'

local im = ui_imgui
local imUtils = require('ui/imguiUtils')

local windowOpen = im.BoolPtr(false)
local windowWasOpen = false
local initialWindowSize = im.ImVec2(300, 500)

local artPath = 'art/vizhelper/'

local mouseWheelSensitivity = 2

local vizHelper = {}
local vizHelperComboStr = {}
local curItem = im.IntPtr(0)

local scale = im.FloatPtr(20)
local rotation = im.FloatPtr(0)
local minDistance = im.FloatPtr(0.3)
local dragRotation = im.BoolPtr(true)
local color = im.ArrayFloatByTbl({1, 0, 0, 1})

local lastPos = vec3()

local savedDecals = {}

local io

local function openWindow()
  windowOpen[0] = true
end

-- HELPER
local function onWindowOpened( )
  log(logTag, 'I', 'onWindowOpened')
end

local function onWindowClosed( )
  log(logTag, 'I', 'onWindowClosed')
end

local function onEditorGui( )
  -- check if window has been closed and fire onWindowClosed event
  if windowWasOpen and windowOpen[0] == false then
    windowWasOpen = false
    onWindowClosed()
  end

  if windowOpen[0] ~= true then return end

  im.SetNextWindowSize(initialWindowSize, im.Cond_FirstUseEver)

  local mouseHit = cameraMouseRayCast()
  if not mouseHit or not mouseHit.pos then
    im.Begin("Viz Helper", windowOpen)
    im.Text("Mouse not over anything")
    im.End()
    return
  end
  local focusPos = vec3(mouseHit.pos)
  --TODO: convert to editor.beginWindow/endWindow api
  im.Begin("Viz Helper", windowOpen)

  -- check if window has been opened and fire onWindowOpened event
  if windowWasOpen == false then
    windowWasOpen = true
    onWindowOpened()
  end

  im.Text('MouseWheel = Rotate')
    im.Text('Ctrl + MouseWheel = Scale')
    im.Text('Alt + MouseWheel = Change image')
    im.Text('Shift = Mousewheel sensitivity')
    im.Text('Click = Place')
    im.Separator()
    if im.TreeNode1("Options") then
      im.Combo2("Image", curItem, vizHelperComboStr)
      im.SliderFloat("Size", scale, 0.1, 50, "%.2f")
      im.SliderFloat("Rotation", rotation, 0.1, 360, "%.2f")
      im.SliderFloat("MinDist", minDistance, 0, 10, "%.2f")
      im.Checkbox('Drag Rotation', dragRotation)

      im.ColorEdit4("Color", color, im.flags(im.ColorEditFlags_NoInputs, im.ColorEditFlags_AlphaBar))
      im.Separator()
      im.Text("object: " .. tostring(mouseHit.object:getId() .. ' in ' .. string.format('%0.2f', mouseHit.distance) .. 'm'))

      im.TreePop()
    end
    im.Separator()
    im.Text(tostring(#savedDecals) .. " decals saved")
    im.SameLine()
    if im.SmallButton("clear") then
      savedDecals = {}
    end
    im.Separator()


    -- interactive hacky input
    if not im.IsMouseDown(1) then
      -- right mouse means we are moving the camera ...
      local sens = mouseWheelSensitivity
      if im.GetIO().KeyShift then
        sens = sens * 10
      end
      if im.GetIO().KeyAlt then
        -- alt = change type
        local w = im.GetIO().MouseWheel
        if w >= 1 then
          curItem[0] = curItem[0] + 1
          if curItem[0] >= #vizHelper then curItem[0] = 0 end
        elseif w <= -1 then
          curItem[0] = curItem[0] - 1
          if curItem[0] < 0 then curItem[0] = #vizHelper - 1 end
        end
      elseif im.GetIO().KeyCtrl then
        -- scale
        scale[0] = scale[0] + im.GetIO().MouseWheel * sens
        if scale[0] < 0.01 then scale[0] = 0.01 end
      else
        -- rotate
        rotation[0] = rotation[0] + im.GetIO().MouseWheel * sens
        if rotation[0] < 0 then
          rotation[0] = rotation[0] + 360
        elseif rotation[0] > 360 then
          rotation[0] = rotation[0] - 360
        end
      end
    end

    debugDrawer:drawSphere(focusPos, 0.1, ColorF(0,1,0,1))

    local norm = vec3(mouseHit.normal)

    local data = {}
    data.texture = artPath .. vizHelper[curItem[0] + 1]
    data.position = focusPos
    data.color = ColorF(color[0], color[1], color[2], color[3])

    -- rotate the forward vector around the normal
    local angle = math.rad(rotation[0])
    local fwd = norm:perpendicularN()
    fwd = fwd * math.cos(angle) + fwd:cross(norm) * math.sin(angle)

    data.forwardVec = fwd
    data.scale = vec3(scale[0], scale[0], scale[0])
    data.fadeStart = 2000
    data.fadeEnd   = 2500

    data.normal = norm

    if not im.GetIO().WantCaptureMouse and im.IsMouseDown(0) then
      if (lastPos - focusPos):length() >= minDistance[0] then
        table.insert(savedDecals, data)
        lastPos = focusPos
      end
    else
      Engine.Render.DynamicDecalMgr.addDecal(data)
    end

    -- Engine.Render.DynamicDecalMgr.addDecals(savedDecals)

  im.End( )
end

local function onUpdate()
  Engine.Render.DynamicDecalMgr.addDecals(savedDecals)
end

local function ticketInspectorGui(inspectorInfo)

end

local function onWindowMenuItem()
  windowOpen[0] = true
end

local function onEditorInitialized()
  -- editor.registerInspectorTypeHandler("ticket", ticketInspectorGui)
  editor.addWindowMenuItem("Viz Helper", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

local function onExtensionLoaded()
  vizHelper = FS:findFiles(artPath, "*", -1, true, false)
  for k, v in ipairs(vizHelper) do
    vizHelper[k] = string.sub(v, string.len(artPath) + 1)
  end
  vizHelperComboStr = table.concat(vizHelper, '\0') .. '\0'
end

local function onEditorActivated()
end

local function onEditorDeactivated()
  savedDecals = {}
end

local function onSerialize()
  return {
    windowOpen = windowOpen[0],
  }
end

local function onDeserialized(data)
  windowOpen[0] = data.windowOpen
end

-- public interface
M.openWindow = openWindow
M.windowOpen = windowOpen

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorActivated = onEditorActivated
M.onEditorDeactivated = onEditorDeactivated
M.onExtensionLoaded = onExtensionLoaded
M.onUpdate = onUpdate
M.onDeserialized = onDeserialized
M.onSerialize = onSerialize

return M