--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local jbeamUtils = require("jbeam/utils")


local function _cleanupRows(row)
  -- clean some commonly leaking things ...
  row.nodeOffset = nil
  row.skinName = nil
end

local function processEvents(objID, vehicleObj, vehicle)
  profilerPushEvent('processEvents')
  if vehicle.events ~= nil then
    for _, ab in pairs(vehicle.events) do
      _cleanupRows(ab)
    end
    --extensions.core_input_actions.updateVehiclesActions()
    --log('D', "jbeam.pushToPhysics","- found ".. #vehicle.events .." Events")
  end
end

local function processTriggers(objID, vehicleObj, vehicle)
  profilerPushEvent('processTriggers')
  if vehicle.triggers ~= nil and vehicleObj then
    local trigger_count = 0

    for _, ab in pairs(vehicle.triggers) do
      _cleanupRows(ab)
      local abid = vehicleObj:addTrigger()
      if abid < 0 then
        log('E', 'jbeam.pushToPhysics', 'unable to create Trigger')
        goto continue
      end
      if abid ~= ab.cid then
        log('E', 'jbeam.pushToPhysics', 'Trigger cId desync: ' .. dumps(ab) .. ' != ' .. tostring(ab.cid))
        goto continue
      end

      ab.abid = abid
      local abo = vehicleObj:getTrigger(abid)
      if abo ~= nil then
        trigger_count = trigger_count + 1
        -- now clean up the input data
        local rotDeg = vec3(ab.rotation)
        ab.rotation        = vec3(math.rad(rotDeg.x), math.rad(rotDeg.y), math.rad(rotDeg.z))
        ab.translation     = vec3(ab.translation)

        abo:set(tonumber(ab.idRef), tonumber(ab.idX), tonumber(ab.idY))

        if ab.baseTranslation ~= nil then
          ab.baseTranslation = vec3(ab.baseTranslation)
          abo.baseTranslation = ab.baseTranslation
        end
        if ab.translationOffset ~= nil then
          ab.translationOffset = vec3(ab.translationOffset)
          abo.translationOffset = ab.translationOffset
        end
        if ab.baseRotation ~= nil then
          local rot = vec3(ab.baseRotation)
          ab.baseRotation = vec3(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z))
          abo.baseRotation = ab.baseRotation
        end
        if ab.color then
          abo.color = ColorF(ab.color[1], ab.color[2], ab.color[3], ab.color[4])
        end
        if type(ab.label) == 'string' then
          abo.label = ab.label
        end
        if ab.type == 'box' then
          abo.typeId = 0
        elseif ab.type == 'sphere' then
          abo.typeId = 1
        end

        local typeStr = ab.type or 'box'
        if typeStr == 'box' and type(ab.size) == 'table' then
          ab.size = vec3(ab.size)
          abo:setBoxSize(ab.size)
        elseif typeStr == 'sphere' and type(ab.size) == 'number' then
            abo:setSphereSize(ab.size)
        end

        abo.visibleDistance = 0.3

        abo:update(ab.translation, ab.rotation, true, 0)
      else
        print("Trigger not found")
      end
      ::continue::
    end

    --log('D', "jbeam.pushToPhysics","- added ".. trigger_count .." triggers")

    -- enable debug drawing for the triggers
    --VehicleTrigger.debug = true

    if trigger_count > 0 then
      extensions.load('core_vehicleTriggers')
    end
  end

  profilerPopEvent()
end

local function processTriggerEventLinks(objID, vehicleObj, vehicle)
  profilerPushEvent('processTriggerEventLinks')

  if vehicle.triggerEventLinks ~= nil then
    vehicle.triggerEventLinksDict = {}

    for _, lnk in pairs(vehicle.triggerEventLinks) do
      if not lnk.targetEventId then
        print("targetEventId is missing: " .. dumps(lnk))
        goto continue2
      end
      if not lnk.triggerId then
        print("triggerId is missing or wrong: " .. dumps(lnk))
        goto continue2
      end
      if not lnk.action then
        print("action is missing: " .. dumps(lnk))
        goto continue2
      end
      -- now link the event
      if not vehicle.events[lnk.targetEventId] then
        print("targetEvent is missing / wrong: " .. dumps(lnk))
        goto continue2
      end

      lnk.targetEvent = vehicle.events[lnk.targetEventId]

      if not vehicle.triggerEventLinksDict[lnk.triggerId] then vehicle.triggerEventLinksDict[lnk.triggerId] = {} end
      if not vehicle.triggerEventLinksDict[lnk.triggerId][lnk.action] then vehicle.triggerEventLinksDict[lnk.triggerId][lnk.action] = {} end
      table.insert(vehicle.triggerEventLinksDict[lnk.triggerId][lnk.action], lnk)

      ::continue2::
    end
  end

  profilerPopEvent()
end


local function process(objID, vehicleObj, vehicle)
  profilerPushEvent('jbeam/events.process')

  processEvents(objID, vehicleObj, vehicle)
  processTriggers(objID, vehicleObj, vehicle)
  processTriggerEventLinks(objID, vehicleObj, vehicle)

  profilerPopEvent() -- jbeam/meshs.process
end

M.process = process

return M