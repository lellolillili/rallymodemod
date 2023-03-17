-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this is a little helper for the level people, so they can mark things :)

local M = {}

local im = ui_imgui
local imUtils = require('ui/imguiUtils')

local toolWindowName = "scriptAIManager"

local recordings = {}

local vehState = {}
local vehInfo = {}

local persistenceFilename = 'aiscript.json'

local graphType = im.IntPtr(0)
local vehicleChooser = im.IntPtr(0)
local debugDisplay = im.BoolPtr(false)
local fastForward = im.BoolPtr(false)
local debugPath = im.BoolPtr(true)

local loopRecordingBoolPtr = {}
local displayDebugBoolPtr = {}
local timeOffsetFloatPtr = {}
local startDelayFloatPtr = {}

local vehDataReceived = {} -- record if we ever received data -- see below

local activeVehicleId = nil

local trackFilePath = '/replays/scriptai/tracks/'
local trackFileExt = '.track.json'
local tmpSaveFilename

local initialWindowSize = im.ImVec2(800, 200)

local function findActivePlayerID(newID)
  if newID == nil then newID = be:getPlayerVehicleID(0) end
  local maxObj = be:getObjectCount()-1
  for i = 0, maxObj do
    local vehId = be:getObject(i):getId()
    if newID == vehId then
      vehicleChooser[0] = i
      activeVehicleId = vehId
      return
    end
  end
end

local function playVehicle(bo)
  local vehId = bo:getId()
  if not recordings[vehId] then return end
  recordings[vehId].loopCount = -1
  if loopRecordingBoolPtr[vehId] ~= nil then
    if loopRecordingBoolPtr[vehId][0] then
      recordings[vehId].loopCount = -1
    else
      recordings[vehId].loopCount = 1
    end
  end
  if timeOffsetFloatPtr[vehId] ~= nil then
    recordings[vehId].timeOffset = timeOffsetFloatPtr[vehId][0]
  end
  if startDelayFloatPtr[vehId] ~= nil then
    recordings[vehId].startDelay = startDelayFloatPtr[vehId][0]
  end

  bo:queueLuaCommand('ai.startFollowing(' .. serialize(recordings[vehId]) .. ')')
  vehState[vehId] = 'playing'
  vehInfo[vehId] = nil
  if vehDataReceived[vehId] then vehDataReceived[vehId] = nil end
end

local function stopPlaying(bo, vehId)
  bo:queueLuaCommand('ai.stopFollowing()')
  vehState[vehId] = 'idle'
end

local function startRecording(bo, vehId)
  bo:queueLuaCommand('ai.startRecording()')
  vehState[vehId] = 'recording'
  vehInfo[vehId] = nil
  recordings[vehId] = nil
end

local function stopRecording(bo, vehId)
  bo:queueLuaCommand('obj:queueGameEngineLua("extensions.hook(\\"onVehicleSubmitRecording\\","..tostring(objectId)..","..serialize(ai.stopRecording())..")")')
  vehState[vehId] = 'idle'
end

local columnsInitialized = false

local function saveRecording(bo, vehId, filename)
  local rec = recordings[vehId]
  local data = {
    levelName = editor.getLevelName(),
    vehicle = bo.JBeam,
    recording = rec,
    version = 2,
  }
  if startDelayFloatPtr[vehId] then
    data.startDelay = startDelayFloatPtr[vehId][0]
  end
  if timeOffsetFloatPtr[vehId] then
    data.timeOffset = timeOffsetFloatPtr[vehId][0]
  end
  jsonWriteFile(trackFilePath .. filename .. trackFileExt, data, true)
end

local function loadRecording(bo, vehId, filename)
  local data = jsonReadFile(filename)
  recordings[vehId] = data.recording

  if data.startDelay then
    if startDelayFloatPtr[vehId] == nil then startDelayFloatPtr[vehId] = im.FloatPtr(0) end
    startDelayFloatPtr[vehId][0] = data.startDelay
  end

  if data.timeOffset then
    if timeOffsetFloatPtr[vehId] == nil then timeOffsetFloatPtr[vehId] = im.FloatPtr(0) end
    timeOffsetFloatPtr[vehId][0] = data.timeOffset
  end
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Script AI Manager") then
    be:queueAllObjectLua('obj:queueGameEngineLua("extensions.hook(\\"onVehicleSubmitInfo\\","..tostring(objectId)..","..serialize(ai.scriptState())..")")')
    local objMax = be:getObjectCount()-1

    im.Columns(4, "AIMgmtcolumns")

    if not columnsInitialized then
      local avail = im.GetContentRegionAvail()
      local colsize_1 = im.CalcTextSize("00000 - thePlayer - vehicleName ----")
      local colsize_2 = im.CalcTextSize("playing - 100% --")

      im.SetColumnWidth(0, colsize_1.x)
      im.SetColumnWidth(1, colsize_2.x)
      im.SetColumnWidth(2, 100)
      im.SetColumnWidth(3, 1000)
      columnsInitialized = true
    end

    --im.Separator()

    im.Text('ID/Vehicle Name')
    im.NextColumn()
    im.Text('State')
    im.NextColumn()

    im.Text('Progress')
    --im.BeginGroup()
    --im.RadioButton2("none", graphType, 0)
    --im.SameLine()
    --im.RadioButton2("Position error", graphType, 1)
    --im.EndGroup()

    im.NextColumn()

    if editor.uiIconImageButton(editor.icons.stop, im.ImVec2(24,24), nil, nil, nil, 'stopall') then
      for i = 0, objMax do
        local bo = be:getObject(i)
        local vehId = bo:getId()
        bo:queueLuaCommand('ai.scriptStop()')
        vehState[vehId] = 'idle'
      end
    end
    im.tooltip('Stop all')

    im.SameLine()

    if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(24,24), nil, nil, nil, 'playall') then
      for i = 0, objMax do
        playVehicle(be:getObject(i))
      end
    end
    im.tooltip('Play all')



    im.NextColumn()
    im.Dummy(im.ImVec2(im.GetContentRegionAvailWidth(), 0))
    im.Separator()

    local textLineHeight = im.GetTextLineHeight()


    for i = 0, objMax do
      local bo = be:getObject(i)
      local vehId = bo:getId()
      if not vehState[vehId] then vehState[vehId] = 'idle' end

      local vi = vehInfo[vehId]

      local vehIdtxt = tostring(vehId) .. ' - ' .. tostring(bo:getName()) .. ' - ' .. tostring(bo.JBeam)

      local statetxt = tostring(vehState[vehId])
      if vi and vehState[vehId] == 'playing' and vi and vi.endScriptTime then
        if vi.isSleeping then
          statetxt = 'sleeping'
        end
        statetxt = statetxt .. ' - ' .. string.format('%3.0f', vi.percent) .. '%'
      end

      if im.RadioButton2(vehIdtxt .. '##' .. 'vehRecording' .. tostring(vehId), vehicleChooser, i) then
        be:enterVehicle(0, bo)
      end

      if debugDisplay[0] then
        if activeVehicleId == nil then findActivePlayerID() end

        local activetxt = ''
        if activeVehicleId == vehId then activetxt = '[active] ' end
        local p1 = bo:getPosition() + vec3(0, 0, 4)
        local dbgTxt = ' ' .. activetxt .. tostring(vehId) .. ' - ' .. tostring(bo:getName()) .. ': ' .. statetxt
        debugDrawer:drawText(p1, String(dbgTxt), ColorF(0, 0, 0, 1))
        debugDrawer:drawLine(bo:getPosition(), p1, ColorF(0, 0, 0, 1))
      end

      im.NextColumn()

      im.Text('%s', statetxt)

      im.NextColumn()

      if vi then
        local cw = im.GetColumnWidth(-1)
        if vi.status == 'following' then

          local dl = im.GetWindowDrawList()
          --im.ImGuiStyle_ItemSpacing(tmpVecPos)
          local spacing = im.ImVec2(0, 0) --tmpVecPos[0].x, tmpVecPos[0].y)

          local cPos = im.GetCursorScreenPos()
          local graphPos = im.ImVec2(cPos.x, cPos.y)

          local p1 = im.ImVec2(graphPos.x, graphPos.y)
          local p2 = im.ImVec2(graphPos.x + cw - spacing.x * 2 - 12, graphPos.y + textLineHeight)
          local col = im.GetColorU322(im.ImVec4(0.3, 0.3, 0.3, 1))
          -- the background
          if p2.x > p1.x then
            im.ImDrawList_AddRectFilled(dl, p1, p2, col)

            local barheight = textLineHeight * 0.5
            -- then the foreground
            local cwGraph = cw - spacing.x * 2 - 12
            local perc = vi.time / vi.endScriptTime
            p1 = im.ImVec2(graphPos.x, graphPos.y)
            p2 = im.ImVec2(graphPos.x + (perc * cwGraph), graphPos.y + barheight )
            col = im.GetColorU322(im.ImVec4(0, 1, 0, 1))
            if vi.isSleeping then
              col = im.GetColorU322(im.ImVec4(1, 0, 0, 1))
            end
            if p2.x > p1.x then
              im.ImDrawList_AddRectFilled(dl, p1, p2, col)
            end

            perc = vi.scriptTime / vi.endScriptTime
            p1 = im.ImVec2(graphPos.x, graphPos.y + barheight)
            p2 = im.ImVec2(graphPos.x + (perc * cwGraph), graphPos.y + barheight * 2)
            col = im.GetColorU322(im.ImVec4(1, 1, 1, 1))
            if p2.x > p1.x then
              im.ImDrawList_AddRectFilled(dl, p1, p2, col)
            end

            --[[
            if graphType[0] == 1 then
                -- aggregate the data
              local graphData = {}
              local maxY = 1
              -- TODO: FIXME
              for _, vii in pairs(vehInfo[vehId]) do
                if vii and vii.scriptTime then
                  local perc = vii.scriptTime / vii.endScriptTime
                  local x = math.floor(perc * cwGraph)
                  local gx = graphData[x] or 0
                  if math.abs(vii.posError) > math.abs(gx) then graphData[x] = vii.posError end
                  maxY = math.max(maxY, math.abs(vii.posError))
                end
              end
              -- then draw
              local xi = 0
              for x = 0, cwGraph do
                local y = graphData[x]
                if y then
                  local ys = (y / 3) -- maxY
                  local p1 = im.ImVec2(graphPos.x + x, graphPos.y)
                  local p2 = im.ImVec2(graphPos.x + x, graphPos.y + textLineHeight)
                  col = im.GetColorU322(im.ImVec4( 1, 0, 0, math.min(math.abs(ys), 1)))
                  im.ImDrawList_AddLine(dl, p1, p2, col, 1)
                end
              end
            end
            --]]
          end
        end
      end

      im.NextColumn()

      if im.BeginPopupModal('Save Recording##'..vehId, nil, im.WindowFlags_AlwaysAutoResize) then
        im.InputText("Filename", tmpSaveFilename)

        if im.Button('OK') then
          local filename = ffi.string(ffi.cast("char*",tmpSaveFilename))
          saveRecording(bo, vehId, filename)
          im.CloseCurrentPopup()
        end
        im.SetItemDefaultFocus(g)
        im.SameLine(g)
        if im.Button('Cancel') then im.CloseCurrentPopup() end

        im.EndPopup()
      end

      if im.BeginPopupModal('Load Recording##'..vehId, nil, im.WindowFlags_AlwaysAutoResize) then
        local files = FS:findFiles(trackFilePath, '*' .. trackFileExt, -1, true, false)
        for _, filename in pairs(files) do

          local fn_short = string.sub(filename, string.len(trackFilePath) + 1)
          fn_short = string.sub(fn_short, 1, string.len(fn_short) - string.len(trackFileExt))
          if im.Button(fn_short) then
            loadRecording(bo, vehId, filename)
            im.CloseCurrentPopup()
          end
        end
        im.SetItemDefaultFocus(g)

        if im.Button('Cancel') then im.CloseCurrentPopup() end

        im.EndPopup()
      end

      if vehState[vehId] == 'idle' then
        if editor.uiIconImageButton(editor.icons.fiber_manual_record, im.ImVec2(24,24), nil, nil, nil, 'record'..vehId) then
          startRecording(bo, vehId)
        end
        im.tooltip('Record')
        if recordings[vehId] then
          im.SameLine()
          if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(24,24), nil, nil, nil, 'play'..vehId) then
            playVehicle(bo)
          end
          im.tooltip('Play')
        end
      elseif vehState[vehId] == 'recording' then
        if editor.uiIconImageButton(editor.icons.stop, im.ImVec2(24,24), nil, nil, nil, 'stopRecord'..vehId) then
          stopRecording(bo, vehId)
        end
        im.tooltip('Stop Recording')
        im.SameLine(g)
      elseif vehState[vehId] == 'playing' then
        if editor.uiIconImageButton(editor.icons.replay, im.ImVec2(24,24), nil, nil, nil, 'play'..vehId) then
          playVehicle(bo)
        end
        im.tooltip('Restart Replay')
        im.SameLine(g)
        if editor.uiIconImageButton(editor.icons.stop, im.ImVec2(24,24), nil, nil, nil, 'stopPlay'..vehId) then
          stopPlaying(bo, vehId)
        end
        im.tooltip('Stop Playing')
      end

      if recordings[vehId] then
        im.SameLine(g)
        if editor.uiIconImageButton(editor.icons.save, im.ImVec2(24,24), nil, nil, nil, 'saverecord'..vehId) then
          if not tmpSaveFilename then
            tmpSaveFilename = im.ArrayChar(128)
          end
          ffi.copy(tmpSaveFilename, tostring(vehId) .. '-' .. tostring(bo:getName()) .. '-' .. tostring(bo.JBeam))
          im.OpenPopup('Save Recording##'..vehId)
        end
        im.tooltip('Save Recording')
      end
      im.SameLine(g)
      if editor.uiIconImageButton(editor.icons.folder_open, im.ImVec2(24,24), nil, nil, nil, 'loadrecord'..vehId) then
        im.OpenPopup('Load Recording##'..vehId)
      end
      im.tooltip('Load Recording')

      im.SameLine(g)
      if im.Button('More##'..vehId) then
        im.OpenPopup('controlsPopup##'..vehId)
      end
      im.SameLine(g)

      if loopRecordingBoolPtr[vehId] == nil then loopRecordingBoolPtr[vehId] = im.BoolPtr(true) end
      if displayDebugBoolPtr[vehId] == nil then displayDebugBoolPtr[vehId] = im.BoolPtr(true) end
      if timeOffsetFloatPtr[vehId] == nil then timeOffsetFloatPtr[vehId] = im.FloatPtr(0) end
      if startDelayFloatPtr[vehId] == nil then startDelayFloatPtr[vehId] = im.FloatPtr(0) end

      if im.BeginPopup('controlsPopup##'..vehId) then
        im.MenuItem1(vehIdtxt, nil, false, false)
        im.Checkbox('Loop##loop'..vehId, loopRecordingBoolPtr[vehId])
        im.tooltip('Restart when recording reaches the end')
        im.SameLine(g)
        im.Checkbox('Debug##debug'..vehId, displayDebugBoolPtr[vehId])
        im.PushItemWidth(60)
        im.DragFloat('Start Offset', timeOffsetFloatPtr[vehId], 0.01)
        im.tooltip('Cuts of X seconds from the start. You need to restart the playback after changing this.')
        im.PushItemWidth(60)
        im.DragFloat('Start Delay', startDelayFloatPtr[vehId], 0.01)
        im.tooltip('Delays the start for X seconds. You need to restart the playback after changing this.')

        if im.MenuItem1('Reset Recording##'..vehId) then
          bo:queueLuaCommand('ai.scriptStop()')
          recordings[vehId] = nil
          vehState[vehId] = 'idle'
          vehInfo[vehId] = nil
        end

        if im.MenuItem1('Reset Vehicle##'..vehId) then
          bo:queueLuaCommand('obj:requestReset(RESET_PHYSICS)')
        end

        im.EndPopup()
      end

      im.NextColumn()
      im.Separator()
    end
    im.Columns(1)
    --[[
    if (not tableIsEmpty(recordings)) and im.SmallButton("save") then
      jsonWriteFile(persistenceFilename, M.onSerialize())
    end
    im.SameLine()
    if FS:fileExists(persistenceFilename) and im.SmallButton("load") then
      M.onDeserialized(jsonReadFile(persistenceFilename))
    end
    ]]--


    im.Dummy(im.ImVec2(im.GetContentRegionAvailWidth(), 0))
    im.Text('Debug: ')
    im.SameLine()
    if im.Checkbox("Fast forward", fastForward) then
      if fastForward[0] then
        be:setPhysicsSpeedFactor(2)
      else
        be:setPhysicsSpeedFactor(0)
      end
    end
    im.SameLine()
    im.Checkbox("Display IDs", debugDisplay)
    im.tooltip('Display ID above the vehicle')
    im.SameLine()
    im.Checkbox("Display Path", debugPath)
    im.tooltip('Visualize recorded path. Could be performance heavy!')
  end
  editor.endWindow()
end

local dbgPt = vec3()
local lastPt = vec3()
local dbgPrimA = Point2F(0.4, 0.7)
local dbgPrimB = Point2F(0.4, 0.7)
local vehColors = nil
local vehColorsSize = nil

local function onDrawDebug(lastDebugFocusPos, dtReal, dtSim, dtRaw)
  if not debugPath[0] or not (editor.isWindowVisible and editor.isWindowVisible(toolWindowName)) then return end

  local focusPos = vec3(Lua.lastDebugFocusPos)
  local campos = getCameraPosition()
  local camDist = (campos - focusPos):length()

  local objMax = be:getObjectCount() - 1

  --print("camDist = " .. tostring(camDist))
  local cutoffPointSq = math.min(200, math.max(100, camDist))
  --print("cutoffPoint = " .. tostring(cutoffPointSq))
  cutoffPointSq = cutoffPointSq * cutoffPointSq

  if not vehColors or vehColorsSize ~= objMax + 1 then
    vehColors = {}
    for i = 0, objMax do
      local col = rainbowColor(objMax + 1, i + 1, 1)
      table.insert(vehColors, ColorF(col[1], col[2], col[3], 0.2))
    end
    vehColorsSize = #vehColors
  end

  local bo
  local vehId
  for i = 0, objMax do
    bo = be:getObject(i)
    vehId = bo:getId()

    if recordings[vehId] and displayDebugBoolPtr[vehId] and displayDebugBoolPtr[vehId][0]then
      for k, p in pairs(recordings[vehId].path) do
        dbgPt:set(p)
        if (dbgPt - campos):squaredLength() < cutoffPointSq then -- 100 x 100 m
          --debugDrawer:drawSphere(dbgPt, 0.1, col)
          if k > 1 then
            debugDrawer:drawSquarePrism(lastPt, dbgPt, dbgPrimA, dbgPrimB, vehColors[i + 1])
          end
        end
        lastPt:set(dbgPt)
      end
    end

  end
end

local function onVehicleSubmitRecording(vehId, data)
  --print(' * got data: ' .. tostring(vehId)) -- .. ' : ' .. dumps(data))
  recordings[vehId] = data
end


local function onVehicleSubmitInfo(vehId, data)

  -- record percentages
  if data then
    --dump({' * got info: ', vehId, data})
    data.percent = 0
    if data.scriptTime and data.endScriptTime and vehDataReceived[vehId] then
      data.percent = data.time / data.endScriptTime * 100
      if data.startDelay and data.time < data.startDelay then
        data.isSleeping = true
      end
    end
  end

  vehInfo[vehId] = data

  if data and not vehDataReceived[vehId] then vehDataReceived[vehId] = true end

  -- detect when we are done
  if vehDataReceived[vehId] and vehState[vehId] and vehState[vehId] == 'playing' and not data then
    vehState[vehId] = 'idle'
    vehInfo[vehId] = nil
    vehDataReceived[vehId] = nil
  end

  -- recording:
  --  time = wall time spent so far
  -- following:
  --  endScriptTime = total time in recording
  --  scriptTime = where we are in the script
  --  percent done = scriptTime/endScriptTime
  --  posError = distance to the line in meters: minus = left of path, + = right of path
  --  time = wall clock of playback
  --  timeError = time - scriptTime

end

local function onWindowMenuItem()
  findActivePlayerID()
  editor.showWindow(toolWindowName)
end

local function onSerialize()
  return {recordings = recordings, vehState = vehState}
end

local function onDeserialized(data)
  recordings = data.recordings
  vehState = data.vehState
  findActivePlayerID()
end

local function onVehicleSwitched(oldVehicle, newVehicle, player)
  findActivePlayerID(newVehicle)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, initialWindowSize)
  editor.addWindowMenuItem("Script AI Manager", onWindowMenuItem, {groupMenuName = 'Gameplay'})
end

M.getCurrentRecordings = function() return recordings end

-- public interface
M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onVehicleSwitched = onVehicleSwitched
M.onDrawDebug = onDrawDebug

-- vehicle API, do not use directly
M.onVehicleSubmitRecording = onVehicleSubmitRecording
M.onVehicleSubmitInfo = onVehicleSubmitInfo

-- persistence
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

return M