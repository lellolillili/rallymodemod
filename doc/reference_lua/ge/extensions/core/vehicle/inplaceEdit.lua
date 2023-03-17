-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local im = ui_imgui
local jbeamIO = require('jbeam/io')
local jbeamTableSchema = require('jbeam/tableSchema')

local windowOpen = im.BoolPtr(false)

local animationTimeFrame = 0.1
local animationTime = 0
local animationState = 0 -- 2 = enabled

local vBundle
local availableParts
local slotMap


-- the the crude UI ...
local selectedPartName
local parentPartName
local partSlots
local partSlotsIdx

local availablePartsForSlot
local availablePartsForSlotIdx

local selectionInProgress

local updateHighlightCounter = 0

local partNavHistory = {}

local function showCEFUI(val)
  local uiObj = scenetree.maincef
  if uiObj then
    uiObj.visible = val
    uiObj:postApply()
  end
end

local function unloadThis()
  -- free some memory
  vBundle = nil
  availableParts = nil
  slotMap = nil
end

local function updateAnimations(dtReal, dtSim, dtRaw)
  if animationTime > 0 then
    animationTime = animationTime - dtReal
    if animationState == 1 then
      if animationTime < 0 then
        animationState = 2
      end
    elseif animationState == 3 then
      if animationTime < 0 then
        animationState = 0
        showCEFUI(true)

        unloadThis()
        --bullettime.pause(false)
      end
    end
  end
end

local y = 0
local consoleTextCol = ColorF(0,0,0,1)
local consoleTextBgCol = ColorI(0,0,0,192)
local function text(txt)
  debugDrawer:drawTextAdvanced(vec3(0,y,0), txt, consoleTextCol, false, true, consoleTextBgCol)
  y = y + 14
end

local function blinkParts(dtReal, dtSim, dtRaw, vehicle)
  if type(vBundle.vdata.flexbodies) ~= 'table' then return end

  for _, flexbody in pairs(vBundle.vdata.flexbodies) do
    if not flexbody._blinkTimer then
      flexbody._blinkTimer = math.random() * 10
    end
    flexbody._blinkTimer = flexbody._blinkTimer + dtReal
    vehicle:setMeshAlpha(math.abs(math.sin(flexbody._blinkTimer)), flexbody.mesh, false)
  end
end


local function setVizRec(vehicle, partName, alpha, nonRec)
  local part = vBundle.vdata.activeParts[partName]
  if not part then
    log('E', '', 'part not found: ' .. tostring(partName))
    return
  end

  if not part._flexbodies_processed then
    if part.flexbodies then
      part.flexbodies_raw = part.flexbodies
      part.flexbodies = {}
      local newListSize = jbeamTableSchema.processTableWithSchemaDestructive(deepcopy(part.flexbodies_raw), part.flexbodies)
    end
    part._flexbodies_processed = true
  end

  --dumpz(part, 2)
  for _, flexbody in pairs(part.flexbodies or {}) do
    vehicle:setMeshAlpha(alpha, flexbody.mesh)
  end

  for _, slot in pairs(part.slots or {}) do
    local chosenPartName = vBundle.chosenParts[slot.type]
    if type(chosenPartName) == 'string' then
      if chosenPartName ~= '' and chosenPartName ~= 'nil' then
        if not nonRec then
          setVizRec(vehicle, chosenPartName, alpha)
        end
      end
    --else
    --  log('E', '', 'slot empty? ' .. tostring(slot.type))
    end
  end
end

local function clearVehicleData()
  vBundle = nil
  availableParts = nil
  slotMap = nil
end

local function updateVehicleData()
  -- get the data
  vBundle = extensions.core_vehicle_manager.getPlayerVehicleData()
  if not vBundle then
    log('E', 'inplaceEdit', 'unable to get vehicle data')
    return false
  end
  availableParts   = jbeamIO.getAvailableParts(vBundle.ioCtx)
  slotMap          = jbeamIO.getAvailableSlotMap(vBundle.ioCtx)

  --dumpz({'vBundle = ', vBundle}, 3)
  --dumpz({'availableParts = ', availableParts}, 2)
  --dumpz({'slotMap = ', slotMap}, 3)
  --dumpz({'flexbodies = ', vBundle.vdata.flexbodies}, 3)
end

local function updateHighlighting()
  if #partSlots == 0 or not vBundle then return end
  local vehicle = be:getPlayerVehicle(0)
  if not vehicle then
    log('E', '', 'vehicle not found')
    return
  end

  vehicle:setMeshAlpha(0, '') -- hide everything
  if parentPartName then
    setVizRec(vehicle, parentPartName, 0.4)
  end

  setVizRec(vehicle, selectedPartName, 1, true)

  local chosenPartName = vBundle.chosenParts[partSlots[partSlotsIdx].type]
  if not chosenPartName or chosenPartName == '' or chosenPartName == 'nil' then
    --log('E', '', 'part not found: ' .. tostring(chosenPartName))
    return
  end

  setVizRec(vehicle, chosenPartName, 1)
end

local function respawnWithConfig(config)
  --dump{'respawnWithConfig: ', config}
  local vehicle = be:getPlayerVehicle(0)
  if not vehicle then
    log('E', '', 'vehicle not found')
    return
  end

  clearVehicleData()
  vehicle:respawn(serialize(config))
  updateHighlighting()
  updateHighlightCounter = 5
end

local function selectPart(partName)
  local vehicle = be:getPlayerVehicle(0)
  if not vehicle then
    log('E', '', 'vehicle not found')
    return
  end

  vehicle:setMeshAlpha(0, '') -- hide everything
  setVizRec(vehicle, partName, 1) -- show all children

  selectedPartName = partName

  local part = vBundle.vdata.activeParts[partName]
  if not part then
    log('E', '', 'part not found: ' .. tostring(partName))
    return
  end
  partSlots = part.slots or {}
  dump{'partSlots = ', partSlots, partName}
  partSlotsIdx = 1
  updateHighlighting()
end

local function onUpdate(dtReal, dtSim, dtRaw)
  if not vBundle then
    updateVehicleData()
  end
  if updateHighlightCounter > 0 then
    updateHighlightCounter = updateHighlightCounter - 1
    --availablePartsForSlot = nil
    updateHighlighting()
  end
  local vehicle = be:getPlayerVehicle(0)
  if not vehicle then return end

  updateAnimations(dtReal, dtSim, dtRaw)
  if animationState ~= 2 then
    return
    --blinkParts(dtReal, dtSim, dtRaw, vehicle)
  end


  --local cam = getCameraMouseRay()
  --dump{vehicle:pickMesh(cam.pos, cam.pos + cam.dir * 1000)}
  y = 0
  text("****************************************************************************************************************")
  text("* Welcome to the ingame vehicle editor :D - usage: left/right/up/down to navigate. select: e, back: r, exit: g *")
  text("****************************************************************************************************************")
  text(" " .. tostring(tableSize(vBundle.vdata.activeParts)) .. " active parts")
  text(" " .. tostring(tableSize(availableParts)) .. " available parts")
  if selectedPartName then
    text(' ### selected part: ' .. selectedPartName .. ' ###')

    for i, slot in ipairs(partSlots) do
      local chosenPartName = vBundle.chosenParts[slot.type]
      local txt = ''
      if partSlotsIdx == i then
        if selectionInProgress == 1 then
          txt = '>>>'
        else
          txt = ' > '
        end
      else
        txt = '   '
      end
      txt = txt .. slot.type .. ' = ' .. tostring(chosenPartName)
      text(txt)

      if partSlotsIdx == i and selectionInProgress == 1 then
        if not availablePartsForSlot then
          availablePartsForSlot = deepcopy(slotMap[slot.type] or {})
          table.insert(availablePartsForSlot, 1, "<empty>")
          availablePartsForSlotIdx = 1
          for i, possiblePartname in ipairs(availablePartsForSlot) do
            if possiblePartname == chosenPartName or ((chosenPartName == '' or chosenPartName == 'nil') and possiblePartname == '<empty>') then
              availablePartsForSlotIdx = i
              break
            end
          end
        end
        for i, possiblePartname in ipairs(availablePartsForSlot) do
          local txt2 = ''
          if i == availablePartsForSlotIdx then
            txt2 = ' > '
          else
            txt2 = '   '
          end
          text('   ' .. txt2 .. possiblePartname)
        end
      end
    end
  end
end

local function onKeyDown()
  if selectionInProgress == 1 then
    availablePartsForSlotIdx = availablePartsForSlotIdx + 1
    availablePartsForSlotIdx = math.max(1, math.min(#availablePartsForSlot, availablePartsForSlotIdx))

    dump{'### choosing slot: ', partSlots[partSlotsIdx].type, availablePartsForSlot[availablePartsForSlotIdx]}
    local partName = availablePartsForSlot[availablePartsForSlotIdx]
    if partName == '<empty>' then partName = '' end
    vBundle.config.parts[partSlots[partSlotsIdx].type] = partName
    respawnWithConfig(vBundle.config)
  else
    partSlotsIdx = partSlotsIdx + 1
    partSlotsIdx = math.max(1, math.min(#partSlots, partSlotsIdx))
    updateHighlighting()
  end
end

local function onKeyUp()
  if selectionInProgress == 1 then
    availablePartsForSlotIdx = availablePartsForSlotIdx - 1
    availablePartsForSlotIdx = math.max(1, math.min(#availablePartsForSlot, availablePartsForSlotIdx))

    dump{'### choosing slot: ', partSlots[partSlotsIdx].type, availablePartsForSlot[availablePartsForSlotIdx]}
    local partName = availablePartsForSlot[availablePartsForSlotIdx]
    if partName == '<empty>' then partName = '' end
    vBundle.config.parts[partSlots[partSlotsIdx].type] = partName
    respawnWithConfig(vBundle.config)
  else
    partSlotsIdx = partSlotsIdx - 1
    partSlotsIdx = math.max(1, math.min(#partSlots, partSlotsIdx))
    updateHighlighting()
  end
end



local function onModeChanged(val)
  --guihooks.trigger('ShowApps', val == false)
  if val then
    pushActionMapHighestPriority("vehicleEdit")
    partNavHistory = {}
  else
    popActionMap("vehicleEdit")
    local vehicle = be:getPlayerVehicle(0)
    if vehicle then
      vehicle:setMeshAlpha(1, '')
    end
  end
  if val and animationState == 0 then
    --bullettime.pause(true)
    showCEFUI(false)

    updateVehicleData()

    selectPart(vBundle.mainPartName)

    animationState = 1
    animationTime = animationTimeFrame
  elseif not val and animationState == 2 then
    animationState = 3
    animationTime = animationTimeFrame
  end
end

local function setShowWindow(val)
  windowOpen[0] = val == true
  onModeChanged(windowOpen[0])
end

local function toggleShowWindow()

  windowOpen[0] = not windowOpen[0]
  onModeChanged(windowOpen[0])

  local vehicle = be:getPlayerVehicle(0)
  if vehicle then
    vehicle:toggleEditMode()
  end
end

local function onInput(type, value)
  if value ~= 1 then return end
  if type == 'up' then
    onKeyUp()
  elseif type == 'down' then
    onKeyDown()
  elseif type == 'right' then
    if not selectionInProgress then
      if #partSlots > 0 then
        local chosenPartName = vBundle.chosenParts[partSlots[partSlotsIdx].type]
        if chosenPartName ~= '' and chosenPartName ~= 'nil' then
          parentPartName = selectedPartName
          table.insert(partNavHistory, selectedPartName)
          selectPart(chosenPartName)
          dump{'parent part: ', tostring(parentPartName), 'new part: ', chosenPartName}
        end
      end
    end
  elseif type == 'left' then
    if not selectionInProgress then
      if #partNavHistory > 0 then
        local oldPartName = partNavHistory[#partNavHistory]
        table.remove(partNavHistory, #partNavHistory)
        parentPartName = nil
        if #partNavHistory > 0 then
          parentPartName = partNavHistory[#partNavHistory]
        end
        selectPart(oldPartName)
        --dump{'parent part: ', tostring(parentPartName), 'new part: ', oldPartName}
      end
    end
  elseif type == 'select' then
    if not selectionInProgress or selectionInProgress == 0 then
      selectionInProgress = 1
      availablePartsForSlot = nil

    elseif selectionInProgress == 1 then
      --selectionInProgress = 2

      dump{'### choosing slot: ', partSlots[partSlotsIdx].type, availablePartsForSlot[availablePartsForSlotIdx]}
      local partName = availablePartsForSlot[availablePartsForSlotIdx]
      if partName == '<empty>' then partName = '' end
      vBundle.config.parts[partSlots[partSlotsIdx].type] = partName
      respawnWithConfig(vBundle.config)
      availablePartsForSlot = nil
      availablePartsForSlotIdx = nil
      selectionInProgress = nil
    end
  elseif type == 'back' then
    selectionInProgress = nil
    availablePartsForSlot = nil
    availablePartsForSlotIdx = nil
  end
end

M.onUpdate = onUpdate
M.setShowWindow = setShowWindow
M.toggleShowWindow = toggleShowWindow


M.onInput = onInput

return M