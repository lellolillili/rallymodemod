-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui
local toolWindowName = "AI Path Route Test"
local fromPos, toPos, midPos
local route = require('/lua/ge/extensions/gameplay/route/route')()
local useMid = im.BoolPtr(false)
local ignoreOneWay = im.BoolPtr(false)
local fullDebug = im.BoolPtr(false)
local trackPlayer = im.BoolPtr(false)
local isTracking = false

local colorWhite = ColorF(1, 1, 1, 1)
local colorIBlack = ColorI(0, 0, 0, 192)

local function onEditorGui()
  if editor.beginWindow(toolWindowName, toolWindowName) then
    local change = false

    im.Text("Set Start: ")
    im.SameLine()
    if im.Button("Player Vehicle##routeStart") then
      if be:getPlayerVehicle(0) then
        fromPos:set(be:getPlayerVehicle(0):getPosition())
        change = true
      end
    end
    im.SameLine()
    if im.Button("Camera##routeStart") then
      fromPos:set(getCameraPosition() - vec3(0, 0, 1))
      change = true
    end
    change = change or fromPos:update()
    im.Dummy(im.ImVec2(0, 5))

    if not useMid[0] then im.BeginDisabled() end
    im.Text("Set Mid: ")
    im.SameLine()
    if im.Button("Player Vehicle##routeMid") then
      if be:getPlayerVehicle(0) then
        midPos:set(be:getPlayerVehicle(0):getPosition())
        change = true
      end
    end
    im.SameLine()
    if im.Button("Camera##routeMid") then
      midPos:set(getCameraPosition() - vec3(0, 0, 1))
      change = true
    end
    im.SameLine()
    if not useMid[0] then im.EndDisabled() end
    if im.Checkbox("Enable", useMid) then
      change = true
    end
    if not useMid[0] then im.BeginDisabled() end
    change = change or midPos:update()
    if not useMid[0] then im.EndDisabled() end
    im.Dummy(im.ImVec2(0, 5))

    im.Text("Set Finish: ")
    im.SameLine()
    if im.Button("Player Vehicle##routeFinish") then
      if be:getPlayerVehicle(0) then
        toPos:set(be:getPlayerVehicle(0):getPosition())
        change = true
      end
    end
    im.SameLine()
    if im.Button("Camera##routeFinish") then
      toPos:set(getCameraPosition() - vec3(0, 0, 1))
      change = true
    end
    change = change or toPos:update()
    im.Dummy(im.ImVec2(0, 5))

    im.Separator()
    if im.Checkbox("Override One Way Roads", ignoreOneWay) then
      route:setRouteParams(nil, ignoreOneWay[0] and 1 or 1e3)
      change = true
    end
    im.Checkbox("Display Details", fullDebug)
    im.Checkbox("Track Player Vehicle", trackPlayer)

    if change then
      if useMid[0] then
        route:setupPathMulti({fromPos.pos, midPos.pos, toPos.pos})
      else
        route:setupPathMulti({fromPos.pos, toPos.pos})
      end
    end
    for i, e in ipairs(route.path) do
      local clr = rainbowColor(#route.path, i, 1)
      debugDrawer:drawSphere(vec3(e.pos), 1, ColorF(clr[1], clr[2], clr[3], 0.6))
      if e.wp then
        --debugDrawer:drawTextAdvanced(e.pos, String(e.wp), ColorF(1,1,1,1), true, false, ColorI(0,0,0,192))
      end
      if i > 1 then
        --debugDrawer:drawLine(vec3(e.pos), vec3(route.path[i-1].pos), )
        debugDrawer:drawSquarePrism(
          vec3(e.pos), vec3(route.path[i-1].pos),
          Point2F(2,0.5),
          Point2F(2,0.5),
          ColorF(clr[1], clr[2], clr[3], 0.4))
      end
      if fullDebug[0] then
        debugDrawer:drawTextAdvanced(vec3(e.pos), String(string.format("%0.1fm", e.distToTarget or -1)), colorWhite, true, false, colorIBlack)
      end
    end
    debugDrawer:drawTextAdvanced(fromPos.pos, "Start", colorWhite, true, false, colorIBlack)
    debugDrawer:drawTextAdvanced(toPos.pos, "Finish", colorWhite, true, false, colorIBlack)
    if useMid[0] then
      debugDrawer:drawTextAdvanced(midPos.pos, "Mid", colorWhite, true, false, colorIBlack)
    end

    if trackPlayer[0] then
      local playerVehicle = be:getPlayerVehicle(0)
      if playerVehicle then
        local idx, dist = route:trackVehicle(playerVehicle)
        im.Text(string.format("Idx: %d, distance: %0.1f", idx or -1, dist or -1))
        isTracking = true
      else
        im.Text("No player vehicle!")
      end
    else
      if isTracking then
        route:trackPosition(fromPos.pos)
        isTracking = false
      end
    end

    editor.endWindow()
  end
end

local function onWindowMenuItem() editor.showWindow(toolWindowName) end

local data = {}

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(400, 500))
  editor.addWindowMenuItem("AI Path Route Test", onWindowMenuItem, {groupMenuName = 'Experimental'})
  fromPos = require('/lua/ge/extensions/editor/util/transformUtil')("From", "From")
  fromPos.allowScale = false
  fromPos.allowRotate = false

  midPos = require('/lua/ge/extensions/editor/util/transformUtil')("Mid", "Mid")
  midPos.allowScale = false
  midPos.allowRotate = false

  toPos = require('/lua/ge/extensions/editor/util/transformUtil')("To", "To")
  toPos.allowScale = false
  toPos.allowRotate = false
  if data then
    fromPos.pos = vec3(data.fromPos)
    midPos.pos = vec3(data.midPos)
    toPos.pos = vec3(data.toPos)
  end
  data = nil
end

M.onSerialize = function()
  return {
    fromPos = fromPos and fromPos.pos and fromPos.pos:toTable(),
    midPos = midPos and midPos.pos and midPos.pos:toTable(),
    toPos = toPos and toPos.pos and toPos.pos:toTable(),
  }
end

M.onDeserialized = function(d)
  data = d
end

M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui

return M