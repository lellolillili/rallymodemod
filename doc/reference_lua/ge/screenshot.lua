-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local uploadQueue = nil

local screenshotPath = 'screenshots/'
local media_url = 'http://media.beamng.com/'
local uploadCounter = 0

local function nop()
end

local function uploadScreenshot(filename, filepath, batchTag)
  local f = io.open(filepath, "rb")
  if f == nil then
    -- screenshot will not exist for some frames when it is created
    --log('E', 'screenshot', "screenshot not existing: " .. tostring(filepath));
    return false
  end
  log('D', 'screenshot', "uploading screenshot: " .. tostring(filename));
  local file_contents = f:read("*all")
  f:close()

  local http = require "socket.http"
  local ltn12 = require "ltn12"
  local boundary = "----LuaSocketFormBoundary1n0Akh2QVfS8vm6B9U"
  local reqbody =
      '--'..boundary..'\r\n'..
      'Content-Disposition: form-data; name="source"\r\n\r\n'..
      'ingame\r\n'

  if batchTag then
    reqbody = reqbody ..
      '--'..boundary..'\r\n'..
      'Content-Disposition: form-data; name="t"\r\n\r\n'..
      batchTag ..'\r\n'
  end

  reqbody = reqbody ..
      '--'..boundary..'\r\n'..
      'Content-Disposition: form-data; name="file"; filename='..filename..'\r\n'..
      'Content-type: image/png\r\n\r\n'..
      file_contents..'\r\n'

  -- add metaData to the POST
  local metaData = {
    versionb = beamng_versionb,
    versiond = beamng_versiond,
    windowtitle = beamng_windowtitle,
    buildtype = beamng_buildtype,
    buildinfo = beamng_buildinfo,
    arch = beamng_arch,
    buildnumber = beamng_buildnumber,
    shipping_build = shipping_build,
  }
  metaData.level = getMissionFilename()
  if extensions.core_gamestate.state.state then
    metaData.gameState = extensions.core_gamestate.state.state
  end

  if Steam and Steam.isWorking and Steam.accountID ~= 0 then
    metaData.steamIDHash = tostring(hashStringSHA1(Steam.getAccountIDStr()))
    metaData.steamPlayerName = Steam.playerName
  end

  local pos = getCameraPosition()
  local rot = getCameraQuat()
  if pos.x ~= 0 or pos.y ~=0 or pos.z ~= 0 then
    metaData.cameraPos = {pos.x, pos.y, pos.z}
    metaData.cameraRot = {rot.x, rot.y, rot.z, rot.w}
  end

  metaData.os = Engine.Platform.getOSInfo()
  metaData.cpu = Engine.Platform.getCPUInfo()
  metaData.gpu = Engine.Platform.getGPUInfo()
  if metaData.gpu then
    metaData.gpu.vulkanEnabled = Engine.getVulkanEnabled()
  end
  if core_environment then
    metaData.tod = core_environment.getTimeOfDay()
  end

  extensions.hook('onUploadScreenshot', metaData)

  reqbody = reqbody ..
  '--'..boundary..'\r\n'..
  'Content-Disposition: form-data; name="metaData"\r\n\r\n'..
  jsonEncode(metaData) ..'\r\n'
  -- metaData done

  -- any shared account present?
  --local adminTag = nil
  --if Steam and Steam.isWorking and Steam.accountID ~= 0 then
  --  adminTag = tostring(hashStringSHA1(Steam.getAccountIDStr()))
  --end
  --if adminTag then
  --  reqbody = reqbody ..
  --    '--'..boundary..'\r\n'..
  --    'Content-Disposition: form-data; name="a"\r\n\r\n'..
  --    adminTag ..'\r\n'
  --end

  -- complete the message
  reqbody = reqbody ..  '--'..boundary..'--\r\n'

  local respbody = {}
  local body_exist, code, headers, status = http.request {
    method = "POST",
    url = media_url .. "/s4/u/",
    source = ltn12.source.string(reqbody),
    headers = {
      ["Content-Type"] = "multipart/form-data; boundary="..boundary,
      ["Content-Length"] = #reqbody,
    },
    sink = ltn12.sink.table(respbody)
  }

  if tonumber(code) ~= 200 then
    log('E', 'screenshot', "error uploading screenshot: " .. tostring(filename));
    log('E', 'screenshot', 'body:' .. dumps(respbody))
    log('E', 'screenshot', 'code:' .. tostring(code))
    log('E', 'screenshot', 'headers:' .. dumps(headers))
    log('E', 'screenshot', 'status:' .. tostring(status))
    return true
  end

  if tonumber(body_exist) == 1 and tonumber(code) == 200 and #respbody > 0 then
    log('D', 'screenshot', "screenshot uploaded successfully: " .. tostring(filename));
    local state, response = pcall(json.decode, respbody[1])
    if state and response.ok == 1 then
      --dump(response)
      --local uri = media_url..response.tag..'/'..filename
      local url = response.adminURLQuick
      openWebBrowser(url)
      setClipboard(response.url)
      return true
    end
  end
  return true
end

M.updateGFX = nop
local function updateGFX()
  if uploadQueue == nil then return end
  uploadCounter = uploadCounter - 1

  if uploadScreenshot(uploadQueue[1], uploadQueue[2], uploadQueue[3]) or uploadCounter <= 0 then
    uploadQueue = nil
    M.updateGFX = nop
  end
end

local function doScreenshot(batchTag, upload, path, ext)
  -- find the next available screenshot filename
  if uploadQueue ~= nil then return end
  local counter = 0

  local finalPath, format, filepath, filename
  if path and ext then
    finalPath = path
    format = ext
    upload = nil
    batchTag = nil
  else
    format = settings.getValue("screenshotFormat")

    filename = ''
    local filename_without_ext = ''
    filepath = ''
    local screenPath = screenshotPath .. tostring(getScreenShotFolderString())
    if not FS:directoryExists(screenPath) then
      FS:directoryCreate(screenPath)
    end
    repeat
      filename_without_ext = 'screenshot_' .. tostring(getScreenShotDateTimeString())
      if counter > 0 then
        filename_without_ext = filename_without_ext .. '_' .. tostring(counter)
      end
      filename = filename_without_ext .. '.' ..format
      filepath = screenPath .. '/' .. filename
      counter = counter + 1
    until not FS:fileExists(filepath)
    finalPath = screenPath .. '/' .. filename_without_ext
  end
  createScreenshot(finalPath, format)
  if upload then
    uploadQueue = {filename, filepath, batchTag}
    M.updateGFX = updateGFX
    uploadCounter = 50
  end
end

local function publish(batchTag)
  if settings.getValue('onlineFeatures') ~= 'enable' then
    log('E', 'screenshot.publish', 'screenshot publishing disabled because online features are disabled')
    guihooks.trigger("toastrMsg", {type="warning", title="Error uploading screenshot", msg="Online features are disabled. This setting must be enbled to upload screenshots to BeamNG's media server"})
    return
  end
  doScreenshot(batchTag, true)
end

local function doSteamScreenshot()
  if settings.getValue('onlineFeatures') ~= 'enable' then
    log('E', 'screenshot.publish', 'screenshot publishing disabled because online features are disabled')
    return
  end
  Steam.triggerScreenshot()
end

local function openScreenshotsFolderInExplorer()
  if not fileExistsOrNil('/screenshots/') then  -- create dir if it doesnt exist
    FS:directoryCreate('/screenshots/', true)
  end
   Engine.Platform.exploreFolder('/screenshots/')
end

local function _screenshot(superSampling, tiles, overlap, highest, downsample )
  M.screenshotHighest = highest

  -- set the new values
  if M.screenshotHighest then
    -- log('I','screenshot', "Setting new render parameters ...")
    -- save current values
    M.sc_detailAdjustSaved = TorqueScriptLua.getVar("$pref::TS::detailAdjust")
    M.sc_lodScaleSaved = TorqueScriptLua.getVar("$pref::Terrain::lodScale")
    M.sc_GroundCoverScaleSaved =  getGroundCoverScale()

    local sunsky = scenetree.findObject("sunsky")
    if sunsky then
      M.sc_sunskyTexSizeSaved = sunsky.texSize
      M.sc_sunskyShadowDistanceSaved = sunsky.shadowDistance
      sunsky.texSize = 8192         -- 1024 -- default value on our levels, high is better
      sunsky.shadowDistance = 8000  -- 1600; -- default for gridmap, high is better
    end

    TorqueScriptLua.setVar("$pref::TS::detailAdjust", 20) -- 1.5; -- high is better
    TorqueScriptLua.setVar("$pref::Terrain::lodScale", 0.001) -- 0.75; -- lower is better
    setGroundCoverScale(8) -- 1 -- bigger is better
    flushGroundCoverGrids()
  end


  local screenshotFolderString = getScreenShotFolderString()
  local path = string.format("screenshots/%s", screenshotFolderString)
  if not FS:directoryExists(path) then FS:directoryCreate(path) end
  local screenshotDateTimeString = getScreenShotDateTimeString()
  local subFilename = string.format("%s/screenshot_%s", path, screenshotDateTimeString)
  local screenshotFormat = settings.getValue("screenshotFormat")

  local fullFilename
  local screenshotNumber = 0
  repeat
    if screenshotNumber > 0 then
      fullFilename = FS:expandFilename(string.format("%s_%s", subFilename, screenshotNumber))
    else
      fullFilename = FS:expandFilename(subFilename)
    end
    screenshotNumber = screenshotNumber + 1
  until not FS:fileExists(fullFilename)
  log('I','screenshot', "writing screenshot: " .. fullFilename)

  -- log('I','screenshot', "Taking screenshot "..fullFilename.." Format = "..screenshotFormat.." superSampling = "..tostring(superSampling).." tiles = "..tostring(tiles).." overlap = "..tostring(overlap).." downsample = "..tostring(downsample))
  screenShot(fullFilename, screenshotFormat, superSampling, tiles, overlap, downsample)
end

-- executed by c++ when the screenshot is done
local function _screenshotDone()
  if M.screenshotHighest then
      log('I','screenshot', "Screenshot done, resetting render parameters")
      TorqueScriptLua.setVar("$pref::TS::detailAdjust", M.sc_detailAdjustSaved)
      TorqueScriptLua.setVar("$pref::Terrain::lodScale", M.sc_lodScaleSaved)
      setGroundCoverScale(M.sc_GroundCoverScaleSaved)

    local sunsky = scenetree.findObject("sunsky")
    if sunsky then
      sunsky.texSize = M.sc_sunskyTexSizeSaved
      sunsky.shadowDistance = M.sc_sunskyShadowDistanceSaved
    end
  end
end

-- public interface
M.publish = publish
M.doScreenshot = doScreenshot
M.doSteamScreenshot = doSteamScreenshot
M.openScreenshotsFolderInExplorer = openScreenshotsFolderInExplorer
M.takeScreenShot = function() _screenshot(4, 1, 0, false, true) end
M.takeBigScreenShot = function() _screenshot(9, 1, 0, false) end
M.takeHugeScreenShot = function() _screenshot(36, 1, 0, true) end
M.screenshotDone = _screenshotDone

return M