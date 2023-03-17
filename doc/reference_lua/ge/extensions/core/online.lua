-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

-- bngstk = BeamNG Session Token
local sessionToken = nil

-- intentionally not in M, internal. External users should use: settings.getValue('onlineFeatures') == 'enable'
local enabled = false

-- tracks all requests, unique counting
local requests = {} -- data is stored in .priv and .pub. Priv is for implementation specific things, .pub for the data the API user is going to see
local request_counter = 0

local messageUIReady = false
local storedMessages = {}
local jsonEncodeFull = require('libs/lunajson/lunajson').encode -- slow but conform encoder

-- sends the current state to the user interface. It can request it via online.requestState()
local function onOnlineStateChanged(connected)
  guihooks.trigger('OnlineStateChanged', connected)
  -- send steam data as well if available
  if Steam and Steam.accountID ~= 0 then
    guihooks.trigger('SteamInfo', {
      working = Steam.isWorking,
      playerName = Steam.playerName,
      branch = Steam.branch,
      language = Steam.language,
      loggedin = Steam.accountLoggedIn
    })
  end
end

local function sendUIState()
  onOnlineStateChanged(Engine.Online.isAuthenticated())
end

local function sendUIRequests()
  local requests_pub = {}
  for id, r in pairs(requests) do
    requests_pub[id] = r.pub
  end
  guihooks.trigger('OnlineRequestsState', requests_pub)
end

-- connects to the online services
local function openSession()
  -- opening the session is only supposed to work once at game start
  if not enabled or M.sessionReqested then return end
  M.sessionReqested = true

  -- ask the c++ side to do that for us
  Engine.Online.openSession()
end

local function downloadURL(uri, finishCallback, postDataTbl, outfile, reqType, progressCallback, isJson, postFileName, authorizationHeader)
  --print('=== downloadURL ===')
  --print(' uri = ' .. dumps(uri) .. ' / ' .. type(uri))
  --print(' finishCallback = ' .. dumps(finishCallback) .. ' / ' .. type(finishCallback))
  --print(' postDataTbl = ' .. dumps(postDataTbl) .. ' / ' .. type(postDataTbl))
  --print(' outfile = ' .. dumps(outfile) .. ' / ' .. type(outfile))
  --print(' reqType = ' .. dumps(reqType) .. ' / ' .. type(reqType))
  --print(' progressCallback = ' .. dumps(progressCallback) .. ' / ' .. type(progressCallback))
  --print(' isJson = ' .. dumps(isJson) .. ' / ' .. type(isJson))

  if not enabled then return false end

  if reqType == nil then
    reqType = 'get'
  end
  reqType = string.lower(reqType)

  if not Engine.Online.isAuthenticated() then
    log('E', "online.downloadURL", "Client isn't authenticated!!!")
    return false
  end

  -- d is the local tracking table to associate the request throughout the system. Store internal data into it that you need to work with
  local d = { priv = {}, pub = {}} -- data splitted into a private and public part. Private contains implementation specific things that the API user should not care about
  if string.find(uri, 'http://') or string.find(uri, 'https://') then
    d.pub.url = uri
    d.priv.url = uri
  else
    d.pub.uri = uri
    d.priv.uri = uri
  end

  -- callback or fire and forget?
  if finishCallback then
    d.priv.callback_finish_c = 'core_online.callbackSecureCommCpp'
    d.priv.callback_finish_lua = finishCallback
  end

  -- progress callback
  if progressCallback then
    d.priv.callback_progress_c = 'core_online.callbackSecureCommCppProgress'
    d.priv.callback_progress_lua = progressCallback
  end

  -- file output?
  d.pub.outfile = outfile
  if outfile then
    d.pub.dirname, d.pub.filename, d.pub.fileext = path.split(outfile)
  end
  d.priv.outfile = outfile

  -- the id is upcounting always to be unique to prevent mixup issues
  d.priv.id = request_counter
  d.pub.id = request_counter
  requests[request_counter] = d
  request_counter = request_counter + 1

  -- state things
  d.pub.state = 'working'

  -- prepare the data to post, empty by default
  d.priv.postDataString = ''
  if postDataTbl then
    d.priv.postDataString = jsonEncodeFull(postDataTbl)
  end

  d.priv.postFileName = ''
  if postFileName then
    d.priv.postFileName = tostring(postFileName)
  end

  d.priv.reqType = reqType
  d.priv.isJson = isJson
  d.priv.authorizationHeader = authorizationHeader
  -- print('calling API: ' .. tostring(reqType) .. ' | request: ' .. dumps(d))

  -- the c++ side will use d.id for the callbacks, so make sure they are valid
  SecureComm.apiCall(d.priv)
end

local function download(uri, finishCallback, postDataTbl, outfile, reqType, progressCallback)
  return downloadURL(uri, finishCallback, postDataTbl, outfile, reqType, progressCallback, false)
end

local function apiCall(uri, finishCallback, postDataTbl, outfile, reqType, progressCallback, postFileName, authorizationHeader)
  return downloadURL(uri, finishCallback, postDataTbl, outfile, reqType, progressCallback, true, postFileName, authorizationHeader)
end

-- do not remove, called by c++
local function callbackSecureCommCpp(id, responseCode, responseBuffer, responseHeaders, responseData, postData, curlCode, curlErrorStr, effectiveURL)
  local r = requests[id]
  if not r then
    log('E', 'online', 'unknown request completed: '..tostring(id))
    log('E', 'online', 'curlCode= '..dumps(curlCode))
    log('E', 'online', 'curlErrorStr= '..dumps(curlErrorStr))
    log('E', 'online', 'effectiveURL= '..dumps(effectiveURL))
    return
  end

  if curlCode ~= 0 then
    r.pub.error = curlErrorStr
    r.pub.errorCode = curlCode
  end

  r.pub.effectiveURL = effectiveURL
  r.pub.responseCode = responseCode
  if type(responseresponseHeadersBuffer) == 'string' and string.len(responseHeaders) > 0 then
    r.pub.responseHeaders = responseHeaders
  end
  if type(responseBuffer) == 'string' and string.len(responseBuffer) > 0 then
    r.pub.responseBuffer = responseBuffer
  end
  if type(responseData) == 'table' and not tableIsEmpty(responseData) then
    r.pub.responseData = responseData
  end
  -- set to 100% as we might have missed the last progress update
  if r.pub.dlnow and r.pub.dltotal then
    r.pub.dlnow = r.pub.dltotal
  end
  if r.pub.ulnow and r.pub.ultotal then
    r.pub.ulnow = r.pub.ultotal
  end
  r.pub.state = 'finished'

  --if responseCode ~= 200 then
  --  log('E', 'online', 'unable to communicate with API: ' .. dumps(r, responseCode, responseBuffer, responseHeaders, responseData))
  --end
  -- all done, call the callback
  if r.priv.callback_finish_lua then
    r.priv.callback_finish_lua(r.pub)
  end

  -- do not remove the request, see clearFinishedRequests
end

local function clearFinishedRequests()
  for id, r in pairs(requests) do
    if r.state and r.state == 'finished' then
      -- TODO: broken downloads?
      requests[id] = nil
    end
  end
end

-- do not remove, called by c++
local function callbackSecureCommCppProgress(id, dltotal, dlnow, ultotal, ulnow, dlspeed, ulspeed, time)
  --log('E', 'online', 'callbackSecureCommCppProgress: ' .. dumps(id, dltotal, dlnow, ultotal, ulnow, dlspeed, ulspeed, time))
  local r = requests[id]
  if r and r.priv.callback_progress_lua then
    -- 0 means not set/used
    if dltotal ~= 0 then
      r.pub.dltotal = dltotal
    end
    if dlnow ~= 0 then
      r.pub.dlnow = dlnow
    end
    if ultotal ~= 0 then
      r.pub.ultotal = ultotal
    end
    if ulnow ~= 0 then
      r.pub.ulnow = ulnow
    end
    if ulspeed ~= 0 then
      r.pub.ulspeed = ulspeed
    end
    if dlspeed ~= 0 then
      r.pub.dlspeed = dlspeed
    end
    r.pub.time = time
    r.priv.callback_progress_lua(r.pub)
  end
end

-- example usage:
-- core_online.apiCall('s1/v1/getMods?query=&order_by=&order=&page=1', function(...) dump(...) end)


-- this enables the online features to be dynamically enabled/disabled
local function onSettingsChanged()
  local sValue = settings.getValue('onlineFeatures') == 'enable'

  if not enabled and sValue then
    -- enable
    --log('D', 'online', '*** Enabling online features...')
    enabled = true
    openSession()
  elseif enabled and not sValue then
    -- disable
    --log('D', 'online', '*** Disabling online features...')
    enabled = false
    settings.setValue('telemetry', 'disable')
  end
end

local function onExtensionLoaded()
  onSettingsChanged()
end

local function splitAsKeys(str, delim, maxNb, value)
  local res = {}
  local items = split(str, delim, maxNb)
  for _, i in ipairs(items) do
    res[i] = value or 1
  end
  return res
end

local function showStoredMessages()
  local hidden_ids = splitAsKeys(settings.getValue("OnlineHiddenMessageIDs", ''), ',')
  local data2display = {}
  for _, data in pairs(storedMessages) do
    if data.uid and hidden_ids[data.uid] then
      goto continue
    end
    table.insert( data2display, data )
    ::continue::
  end
  guihooks.trigger('OnlineMessage', data2display)
  storedMessages = {}
end

-- called by the UI when we can fire off the online message
local function onUIOnlineMessageReady()
  showStoredMessages()
  messageUIReady = true
end

-- used to persistently hide online messages
local function onUIOnlineMessageHide(uid)
  local hidden_ids = split(settings.getValue("OnlineHiddenMessageIDs", ''), ',')
  for _, id in ipairs(hidden_ids) do
    if uid == id then
      -- already in there
      return
    end
  end
  -- not in there, so lets add it and save it again
  table.insert(hidden_ids, uid)
  settings.setValue("OnlineHiddenMessageIDs", table.concat(hidden_ids, ','))
  settings.requestSave()
end

-- called from C++ do not remove
local function onInstructions(data)
  --log('D', 'online.onInstructions', 'got instructions: ' .. dumps(data))

  if not data.origin or data.origin ~= 'gameauth' or type(data.cmds) ~= 'table' then
    log('E', 'online.onInstructions', 'unknown instructions. Discarded: ' .. dumps(data))
    return
  end

  for _, cmd in pairs(data.cmds) do
    if cmd.type == 'message' then
      table.insert(storedMessages, cmd)
      -- if ready, directly show them
      if messageUIReady then
        showStoredMessages()
      end
    elseif cmd.type == 'modUpdateAvailable' then
      log('D',"online.onInstructions","modUpdateAvailable")
      extensions.core_modmanager.check4Update()
    elseif cmd.type == 'repomsg' then
      extensions.core_repository.setRepoMsg(cmd)
    elseif cmd.type == "repocmd" then
      extensions.core_repository.setRepoCmd(cmd)
    elseif cmd.type == 'automationmsg' then
      extensions.core_repository.setrepoAutomationMsg(cmd)
    else
      log('E', 'online.onInstructions', 'unknown instruction: ' .. dumps(cmd))
    end
  end
end

-- public interface below

-- functions to be used for it to be correctly working
M.openSession = openSession
M.onExtensionLoaded = onExtensionLoaded
M.onSettingsChanged = onSettingsChanged
M.onOnlineStateChanged = onOnlineStateChanged
M.onUIOnlineMessageReady = onUIOnlineMessageReady
M.onUIOnlineMessageHide = onUIOnlineMessageHide

-- interfaces for usage
M.apiCall = apiCall
M.download = download

-- interface for te UI
M.requestState = sendUIState
M.requestSubscriptions = requestSubscriptions

M.testWebsocket = testWebsocket

-- c++ callbacks, do not remove
M.callbackSecureCommCpp = callbackSecureCommCpp
M.callbackSecureCommCppProgress = callbackSecureCommCppProgress

M.onInstructions = onInstructions

M.getRequestsUI = sendUIRequests
M.clearFinishedRequests = clearFinishedRequests
return M
