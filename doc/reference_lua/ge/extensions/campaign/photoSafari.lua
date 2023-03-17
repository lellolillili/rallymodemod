-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

M.accept = false
M.photomodeOpen = false
M.targetObj = nil

local hintTriggers ={'prototype_2_trigger_CD','prototype_2_shady_trigger','prototype_2_ranger_trigger','prototype_2_stuntman_trigger','prototype_2_police_trigger'}
local val = false
local onsiteLocationActive,onsiteVehPos = false,false
local unlockedHints,subLocationsHints,seen,photoSafariData = {},{},{},{}
--M.photoSafariData.subLocations[M.location].hints
--[[
is called when photosafari mission accepted
@file is json file of photsafari
this function reads json file in photosafaridata and added all the locations to photsafarimission table
also added hints to subLocationsHints table
]]
local function missionaccepted(file)
  if not file then return end
  if FS:fileExists(file) then
    M.photoSafariData = jsonReadFile(file)
    M.accept = true
    subLocationsHints = {}
    unlockedHints = {}
    M.description = {}
    local test ={}
    M.photoSafarimissions = tableKeys(M.photoSafariData)
   for _,k in ipairs(M.photoSafarimissions) do
     subLocationsHints[k]= M.photoSafariData[k].hints
    end
    seen = {}
    M.foundLocation = {}
  end
end


local function onBeamNGTrigger(data)
  local vid = be:getPlayerVehicleID(0)
  if not vid or not data or not data.subjectID or data.subjectID ~= vid then
    return
  end
  if M.accept then
    if data.event == 'enter' then
      if tableFindKey(hintTriggers,data.triggerName) and not tableFindKey(seen,data.triggerName) then
        if next(seen) == nil then
          M.count = 1
          for k,v in pairs(subLocationsHints) do
            unlockedHints[k] = subLocationsHints[k][1]
            M.description[k] = unlockedHints[k]
          end
        else
          M.count = #seen +1
          for k,v in pairs(subLocationsHints) do
            if not  M.foundLocation[k] then
              unlockedHints[k] = subLocationsHints[k][M.count]
              if unlockedHints[k] then
                M.description[k] = M.description[k]..' '..unlockedHints[k]
              end
            else
              table.remove(subLocationsHints[k])
            end
          end
        end
        M.showhint = true
        table.insert(seen,data.triggerName)
      end
      if tableFindKey(M.photoSafarimissions, data.triggerName) then
        if not (scenetree.findObject(M.photoSafariData[data.triggerName].objectName)) then
          log('E', logTag, M.photoSafariData.objectName..' is not existing')
          return
        end
        M.location = data.triggerName
        M.targetObj = M.photoSafariData[data.triggerName].objectName
        M.photomodeOpen = true
        if data.triggerName == 'on_site' then
          onsiteLocationActive = true
        else
          onsiteLocationActive = false
        end
      end

      if M.location and data.triggerName == M.photoSafariData[M.location].closeToPhoto then
        M.closeToPhoto = true
        local sceneObject = scenetree.findObject(M.targetObj)
        local pos = vec3(sceneObject:getPosition())
        local campos = getCameraPosition()
        M.cameraDistanceToObject = (campos - pos):length()
      end
      if onsiteLocationActive and data.triggerName =='on_site_obj' then
        onsiteVehPos=true
      end
    end
    if M.location and data.event == 'exit' then
      if data.triggerName == M.location then
        M.photomodeOpen = false
      else
        M.closeToPhoto = false
      end
    end
  end
end
--[[
only to handle on site location
]]
local function on_siteLocation(campos,sceneObject)
  local vehicle = scenetree.findObjectById(be:getPlayerVehicleID(0))
  local camTriggerObj = scenetree.findObject('camtrig')
  local camTriggerPos = camTriggerObj:getPosition()
  local camdis = (campos - vec3(camTriggerObj:getPosition())):length()
  if camdis > M.cameraDistanceToObject then
    M.msg = "camera is too far from the object "
    val = false
    return val
  end
  if camdis <= 5 then
    if onsiteVehPos then
      if not Engine.sceneGetCameraFrustum():isBoxOutside(sceneObject:getWorldBox()) and Engine.sceneGetCameraFrustum():isBoxContained(sceneObject:getWorldBox()) then
        M.msg = "vehicle and building is in the scene"
        val = true
        onsiteLocationActive = false
        M.photomodeOpen = false
        M.foundLocation[M.location] = true
      else
        M.msg = "Target is not in the scene"
        val = false
      end
    else
      M.msg = "vehicle is not is the scene"
      val = false
    end
    return val
  else
    M.msg = "Adjust your camera"
    return false
  end
end
--[[
this function is called inside photomode.js
check if the object is in the scene or not and if the camera is adjusted or away from the object
]]
local function takepiccheck()
  if M.foundLocation[M.location] then
    M.closeToPhoto = false
    return
  end
  if not M.closeToPhoto then
    guihooks.trigger('ChangeState', {state = 'menu'})
    guihooks.trigger('ScenarioFlashMessage', {{'Drive closer to the target to take the picture', 2}} )
    bullettime.pause(false)
    return
  end
  local vehicle = scenetree.findObjectById(be:getPlayerVehicleID(0))
  local photoTrigger = scenetree.findObject(M.location)
  local vehicleDistance_To_Obj = (vehicle:getPosition() - photoTrigger:getPosition()):len()
  local sceneObject = scenetree.findObject(M.targetObj)
  local pos = vec3(sceneObject:getPosition())
  local campos = getCameraPosition()
  local camdis = (campos - pos):length()

  if onsiteLocationActive then
    val = on_siteLocation(campos,sceneObject)
  elseif camdis > M.cameraDistanceToObject then
    M.msg = "camera is too far from the object "
    val = false
  elseif not Engine.sceneGetCameraFrustum():isBoxOutside(sceneObject:getWorldBox()) and Engine.sceneGetCameraFrustum():isBoxContained(sceneObject:getWorldBox()) and camdis <= M.cameraDistanceToObject then
    M.msg = "target is in the scene nice photo"
    val = true
    M.photomodeOpen = false
    M.closeToPhoto = false
    M.foundLocation[M.location] = true
  else
    M.msg= "target is not in the scene"
    val = false
  end
  guihooks.trigger('ChangeState', {state = 'menu'})
  guihooks.trigger('ScenarioFlashMessage', {{M.msg, 2}} )
  bullettime.pause(false)
  return val
end


M.missionaccepted = missionaccepted
M.onBeamNGTrigger = onBeamNGTrigger
M.takepiccheck = takepiccheck
return M