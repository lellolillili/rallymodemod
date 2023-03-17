-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local updateQueue = {}

local progressQueue = {}
local progressQueueDirty = false
local progressQueueTimer = 0

local updatingRepo = false

local repoMsg = {}
local repoCmd = {}
local repoAutomationMsg = {}

local optoutFile = '/settings/cloud/mods-optout.json'

local subList = {}

local function logOnline(fn,r)
  guihooks.trigger('repoError', 'Server Error')
  log('E', 'modmanager.'..fn, 'Server Error')
  log('E', 'modmanager.'..fn, 'url = '..tostring(r.uri))
  log('E', 'modmanager.'..fn, 'responseBuf = '..tostring(r.responseBuffer))
end

local function downloadProgressCallback(r)
  --log('I', 'repository', 'request progress: ' .. dumps(r))
  --log('D', 'repository', 'request progress: ' .. string.format('% 4.2f', r.dlnow / r.dltotal * 100) .. ' %. Speed: ' .. string.format('%2.2f kB/s', r.dlspeed / 1024))

  -- Sending download status to UI
  --guihooks.trigger('downloadStateChanged', r);
  for k,v in pairs(progressQueue) do
    if v.id == r.id then
      progressQueue[k] = r
      progressQueueDirty = true
      return
    end
  end
  table.insert( progressQueue, r )
  progressQueueDirty = true
end

local function onUpdate(dt)
  if progressQueueDirty then
    guihooks.trigger('downloadStatesChanged', progressQueue);
    progressQueueDirty = false
  end
end

local function uiUpdateQueue()
  --print("uiUpdateQueue")
  local data = {}
  data.updatingList = {}
  data.doneList = {}
  data.missingList = {}
  for k,v in ipairs(updateQueue) do
    if v.state == "done" then
      table.insert(data.doneList, v)
    elseif v.action == "missing" then
      table.insert(data.missingList, v)
    else
      table.insert(data.updatingList, v)
    end
  end
  data.updating = updatingRepo
  guihooks.trigger('UpdateQueueState', data)
end

local function deleteUpdateQueue(data)
  log('D', 'repo.deleteUpdateQueue', 'delete ' .. tostring(data.filename) ..'   URI=' .. tostring(data.filename))
  for k,v in pairs(updateQueue) do
    if v.uri == data.uri then
      table.remove( updateQueue, k )
      uiUpdateQueue()
      log('D', 'repo.deleteUpdateQueue', 'deleted ' .. tostring(k))
      return
    end
  end
end

local function idInUpdateQueue(idlook)
  if #updateQueue == 0 then return false end

  for k,v in pairs(updateQueue) do
    if v.id == idlook then return true end
  end
  return false
end

local function getDownloadState(idlook)
  if #updateQueue == 0 then return false end

  for k,v in pairs(updateQueue) do
    if v.id == idlook then return v.state end
  end
  return false
end

local function updateDownloadQueue()
  local toDelete = {}
  local waiting = 0
  local downloading = 0
  -- log('D', 'repo.updateDownloadQueue', "in queue "..tostring(#updateQueue))
  for k,v in pairs(updateQueue) do
    -- log('D', 'repo.updateDownloadQueue',v.filename.."  update="..tostring(v.update) .."   state="..tostring(v.state) )
    if v.state == "downloading" then
      downloading = downloading + 1
    end
    -- if v.state == "done" then
    --   table.insert( toDelete, v)
    -- end
  end
  -- if(#toDelete>0) then
  --   for k,v in pairs(toDelete) do
  --     deleteUpdateQueue(v)
  --   end
  -- end

  local parDownloads = tonumber(settings.getValue('modNumParallelDownload', 3))

  for k,v in pairs(updateQueue) do
    if v.update and v.state == "updating" and downloading < parDownloads then
      M.installMod(v.uri,v.filename)
      downloading = downloading + 1
    end
    if v.update and v.state == "updating" then waiting = waiting+1 end
  end
  if(waiting == 0 and downloading == 0) then
    updatingRepo = false
    guihooks.trigger('UpdateFinished')
    core_modmanager.enableAutoMount()
  end
end

local function changeStateUpdateQueue(fname,nstate)
  --log('I', 'repo.changeStatusUpdateQueue', ' ' .. tostring(fname))
  for k,v in pairs(updateQueue) do
    if v.filename == fname then
      updateQueue[k].state = nstate
      uiUpdateQueue()
      guihooks.trigger('RepoModChangeStatus', v)
      --log('I', 'repo.changeStatusUpdateQueue', tostring(k) ..' '  .. nstate)
      return
    end
  end
end

local function installMod(uri, filename, localPath, callback)
  log('D', 'repo.installMod',"filename="..filename)
  if not localPath then localPath = '/mods/repo/' end
  local targetFilename = localPath .. filename
  if FS:fileExists("/mods/"..filename) then
    FS:removeFile("/mods/"..filename)
  end
  log('D', 'repository', 'installMod: ' .. tostring(uri) .. ' / ' .. tostring(targetFilename))

  local function downloadFinishedCallback(r)
    --log('D', 'repository', 'downloadFinishedCallback: ' .. dumps(r))
    downloadProgressCallback(r)
    local data = {}
    data.responseData = r.responseData
    data.modID = string.match(uri, '%w+')
    for k,v in pairs(progressQueue) do
      if v.id == r.id then
        table.remove(progressQueue, k)
        progressQueueDirty = true
      end
    end
    for k,v in pairs(updateQueue) do
      if v.id==data.modID then
        v.dlspeed = r.dlspeed
        v.dltotal = r.dltotal
        v.time = r.time
        v.effectiveURL = r.effectiveURL
      end
    end
    guihooks.trigger('ModDownloaded', data)
    changeStateUpdateQueue(filename, "downloaded")
    if r.responseCode ~= 200 then
      log('E', 'repo.downloadFinishedCallback', 'unable to download file: ' .. tostring(targetFilename) .. ' / reply: ' .. dumps(r))
      guihooks.trigger("toastrMsg", {type="error", title="Repo Error", msg="Could not download the file (Check console for details)"})
      if FS:fileExists(r.outfile) then
        FS:removeFile(r.outfile)
      end
      for k,v in pairs(updateQueue) do
        if v.id==data.modID then table.remove( updateQueue, k ) end
      end
      return
    end
    if type(callback) == 'function' then
      callback(r)
    end
    --print("EXISTS: " .. tostring(FS:fileExists(r.outfile)))
    if not FS:fileExists(r.outfile) then
      log('E', 'repo.downloadFinishedCallback', 'unable to download file: ' .. tostring(uri) .. ' / File missing: ' .. tostring(r.outfile) .. ' / reply: ' .. dumps(r))
      guihooks.trigger("toastrMsg", {type="error", title="Repo Error", msg="Could not download the file, File missing"})
      for k,v in pairs(updateQueue) do
        if v.id==data.modID then table.remove( updateQueue, k ) end
      end
      return
    else
      log('D', 'repo.downloadFinishedCallback', 'file successfully downloaded: ' .. tostring(uri) .. ' > ' .. tostring(r.outfile))
    end

    --delete mods outside repo folder
    local modname = filename:gsub(".zip",""):lower()
    local prevInfo = core_modmanager.getModDB(modname)
    if prevInfo ~= nil and prevInfo.dirname == "mods/" and prevInfo.fullpath ~= r.outfile then
      log('D', 'repo.downloadFinishedCallback', 'delete old file: ' .. modname .. ' ' .. tostring(prevInfo.fullpath))
      core_modmanager.deleteMod(modname)
    end
    -- inspect / mount it
    --core_modmanager.workOffChangedMod(r.outfile, 'added')
    if completeCallback then completeCallback(r) end
    changeStateUpdateQueue(filename, "done")
    local finished = true
    for k,v in pairs(updateQueue) do
      if v.update and v.state ~= "done" then
        finished = false
      end
    end
    -- log('I', 'repo.finish', "finished="..dumps(finished))
    if finished then
      local updmods = {}
      -- log('I', 'repo.finish', "updateQueue"..dumps(updateQueue) )
      for k,v in pairs(updateQueue) do
        if v.state == "done" then
          table.insert( updmods, {id = v.id, ver = v.ver, dlspeed = r.dlspeed, dltotal = r.dltotal, time = r.time, effectiveURL=r.effectiveURL:match("https?://([%w.:@]+)")} )
        end
      end
      --print("updmods = "..dumps(updmods))
      core_online.apiCall('s2/v4/modUpdateSuccess', function(request)
          if request.responseData == nil then
            logOnline("installMod.downloadFinishedCallback",request)
            return
          end
          --print("modUpdateSucess")
          guihooks.trigger('UpdateFinished')
        end, {
          mods = updmods,
        })
      for i=#updateQueue,1,-1 do
        if updateQueue[i].state == "done" then
          table.remove(updateQueue,i)
        end
      end
      uiUpdateQueue()
    end

    guihooks.trigger('downloadStateChanged', r);
    updateDownloadQueue()
  end--downloadFinishedCallback

  changeStateUpdateQueue(filename, "downloading")
  core_online.apiCall('s1/v4/download/mods/' .. uri, downloadFinishedCallback, nil, targetFilename, nil, downloadProgressCallback)
end

local function requestMods(query, order_by, order, page, categories)
  if( not Engine.Platform.isNetworkUnrestricted()) then
    log('W', 'modmanager.checkUpdate', 'Network is metered or restricted!')
  end

  core_online.apiCall('s1/v4/getMods', function(request)
      if request.responseData == nil then
        logOnline("requestMods",request)
        return
      end
      local modList = request.responseData.data
      request.responseData.metered = not Engine.Platform.isNetworkUnrestricted()
      request.responseData.updatingRepo = updatingRepo
      request.responseData.repoMsg = repoMsg
      request.responseData.automationMsg = repoAutomationMsg
      for k,v in pairs(modList) do
        modList[k].pending = idInUpdateQueue(v.tagid)
        modList[k].unpacked = core_modmanager.modIsUnpacked(v.filename)
        modList[k].downState = getDownloadState(v.tagid)
      end

      guihooks.trigger('ModListReceived', request.responseData)
    end, {
      query = query,
      order_by = order_by,
      order = order,
      page = page - 1,
      categories = categories,
    })
end

local function requestModOffline(mod_id)
  log('D', 'repo.requestModOffline', "id="..tostring(mod_id))
  local data = {}
  local modname = core_modmanager.getModNameFromID(mod_id)
  if modname then
    local mdb = core_modmanager.getModDB( modname )
    data.data = mdb.modData
    data.localMod = mdb
    if data.data.message then
      data.data.filesize = mdb.stat.filesize
      local lstr = data.data.message:len()
      --Mod repack used description from another mod for the first 2 month
      if data.data.message:find("X4YRUwRrR9Y.jpg") then
        log('E', 'repo.requestModOffline', "message of modinfo "..tostring(mod_id).." is incorect and have been discarded")
        data.data.message = "Offline Data. [br] Description is incorect."
      end
      data.data.message = data.data.message:gsub("\\\\", "\\"):gsub("\\/", "/")
    end
    data.ok = 1
  else
    data.ok = 0
  end
  --log('D', 'repo.requestModOffline', "dump="..dumps(data))
  guihooks.trigger('ModReceived', data )
end

local function requestMod(mod_id)
  if(settings.getValue('onlineFeatures') ~= 'enable') then
    requestModOffline(mod_id)
    return
  end

  core_online.apiCall('s1/v4/getMod/'..mod_id, function(request)
    if request.responseData == nil then
      logOnline("requestMod",request)
      if( FS:fileExists("mod_info/"..mod_id.."/info.json")) then
        requestModOffline(mod_id)
      end
      return
    end
    request.responseData.data.message = string.gsub(request.responseData.data.message, "\n", "<br>")
    request.responseData.data.pending = idInUpdateQueue(mod_id)
    request.responseData.data.unpacked = core_modmanager.modIsUnpacked(request.responseData.data.filename)
    request.responseData.data.downState = getDownloadState(mod_id)
    request.responseData.updatingRepo = updatingRepo
    request.responseData.metered = not Engine.Platform.isNetworkUnrestricted()
    guihooks.trigger('ModReceived', request.responseData)
  end)
end

local function requestMyMods(query,order_by,order,page,categories)
  if( not Engine.Platform.isNetworkUnrestricted()) then
    log('W', 'modmanager.checkUpdate', 'Network is metered or restricted')
  end
  core_online.apiCall('s1/v4/getMods' , function(request)
    if request.responseData == nil then
      logOnline("requestMyMods",request)
      return
    end
    local modList = request.responseData.data
    request.responseData.updatingRepo = updatingRepo
    request.responseData.metered = not Engine.Platform.isNetworkUnrestricted()
    request.responseData.repoMsg = repoMsg
    request.responseData.automationMsg = repoAutomationMsg
    for k,v in pairs(modList) do
      modList[k].pending = idInUpdateQueue(v.id)
      modList[k].unpacked = core_modmanager.modIsUnpacked(v.filename)
      modList[k].downState = getDownloadState(v.tagid)
    end
    guihooks.trigger('MyModsReceived', request.responseData)
  end, {
    query = query,
    order_by = order_by,
    order = order,
    page = page-1,
    categories = categories,
    own = 1,
  })
end

local function modSubscribe(mod_id, useOptOut)
  local optOutData = jsonReadFile(optoutFile) or {}
  if useOptOut and optOutData[mod_id] then
    -- user opted out, ignore this request
    log('D', 'repo.modSubscribe', "Subscription '"..tostring(mod_id).."' opt out")
    return
  end
  optOutData[mod_id] = nil -- remove it from the opt-out list
  jsonWriteFile(optoutFile, optOutData)

  if not core_modmanager.isReady() or not Engine.Online.isAuthenticated() then
    log('D', 'repo.modSubscribe', "Subscription \'"..tostring(mod_id).."\' when online and modmgr is ready")
    table.insert(subList, mod_id)
    return
  end

  for k,v in pairs(updateQueue) do
    if v.id == mod_id then log('E', 'repo.modSubscribe', "Subscription '"..tostring(mod_id).."' already in update list"); return end
  end
  log('D', 'repo.modSubscribe', "Subscription '"..tostring(mod_id))
  core_online.apiCall('s2/v4/modSubscribe/' .. mod_id, function(request)
    if request.responseData == nil then
      logOnline("modSubscribe",request)
      return
    end
    if request.responseData.error ~= nil and request.responseData.error == 1 then
      local msg = "no error message"
      if request.responseData.message ~= nil then
        msg = request.responseData.message
      end
      guihooks.trigger('repoError', 'Server Error : '..msg.. " ("..tostring(mod_id)..")")
      log('E', 'repo.modSubscribe', 'Server Error : '..msg.. " ("..tostring(mod_id)..")")
      return
    end
    guihooks.trigger('ModSubscribed', request.responseData)
    local modData = request.responseData.modData
    modData.id = mod_id
    modData.reason = "subscription"
    modData.sub = true
    M.addUpdateQueue(modData)
    guihooks.trigger('RepoModChangeStatus', modData)

    for k,v in pairs(updateQueue) do
      if v.reason ~= "subscription" then v.update = false end
    end
    uiUpdateQueue()
    updateDownloadQueue()
    core_modmanager.disableAutoMount()
    updatingRepo = true

  end)
end

local function modUnsubscribe(mod_id)
  -- record in that file that we opted out intentionally
  local optOutData = jsonReadFile(optoutFile) or {}
  optOutData[mod_id] = true
  jsonWriteFile(optoutFile, optOutData)

  -- if not core_modmanager.isReady() or not Engine.Online.isAuthenticated() then
  --   log('E', 'repo.modUnsubscribe', "Unsubscribe '"..tostring(mod_id).."' when online and modmgr is ready")
  --   table.insert(unsubList, mod_id)
  --   return
  -- end

  local modName = extensions.core_modmanager.getModNameFromID(mod_id)
  log('D', 'repo.modUnsubscribe', tostring(mod_id).." -> "..tostring(modName))
  for k,v in pairs(updateQueue) do
    if v.id == mod_id then
      if v.state == "downloading" then
        log('E', 'repo.modUnsubscribe', "Can't unsubscribe '"..tostring(mod_id).."' because it's downloading")
        return
      end
      table.remove( updateQueue, k )
      log('D', 'repo.modUnsubscribe', tostring(mod_id).." pre-canceled")
    end
  end
  if modName then core_modmanager.deleteMod( modName) end
  if (modName and mod_id ~= modName) or modName==nil  then
    core_online.apiCall('s2/v4/modUnsubscribe/' .. mod_id, function(request)
      if request.responseData == nil then
        logOnline("modUnsubscribe", request)
        return
      end
      if request.responseData.error ~= nil and request.responseData.error == 1 then
        local msg = "no error message"
        if request.responseData.message ~= nil then
          msg = request.responseData.message
        end
        guihooks.trigger('repoError', 'Server Error : '..msg.. " ("..tostring(mod_id)..")")
        log('E', 'repo.modUnsubscribe', 'Server Error : '..msg.. " ("..tostring(mod_id)..")")
        return
      end
      guihooks.trigger('ModUnsubscribed', request.responseData)
    end)
  end
end

local function addUpdateQueue(data)
  for k,v in pairs(updateQueue) do --no duplicate
    if v.id == data.id then return end
  end
  data.dirname = "/mods/repo/"
  data.dlnow=0
  data.speed=0
  data.fileext="zip"
  data.outfile = data.dirname..data.filename
  data.state="waiting"
  data.time=0
  --data.date=os.time(os.date('*t'))
  data.uri= data.id .."/".. data.ver .."/" .. data.filename
  data.icon = data.id .."/".. data.ver .."/" .. "icon.jpg"
  if data.reason == "subscription" then
    data.modname = data.filename:gsub(".zip","")
    data.update = true --we don't need to check it's new
    data.conflict = nil
    data.state="updating"
  else
    data.modname = core_modmanager.getModNameFromID(data.id)
    data.update = true--core_modmanager.checkMod(data.modname)
    data.conflict = nil--core_modmanager.getConflict(data.modname)
  end
  log('D', 'repo.addUpdateQueue',"reason="..data.reason.."   "..dumps(data.id).." - "..dumps(core_modmanager.getModNameFromID(data.id)))
  table.insert(updateQueue,data)
  --log('I', 'repo.addUpdateQueue',tostring(#updateQueue) )
  --uiUpdateQueue()
end

local function updateAllMods()
  log('D', 'updateAllMods', "*************************")
  core_modmanager.disableAutoMount()
  updatingRepo = true
  for k,v in pairs(updateQueue) do
    if v.action == "update" then
      v.update = true
      v.state  = "updating"
    end
  end
  updateDownloadQueue()
end

local function updateOneMod(id)
  log('D', 'updateAllMods', "updateOneMod id="..dumps(id))
  updatingRepo = true
  for k,v in pairs(updateQueue) do
    if v.id == id then
      v.update = true
      v.state  = "updating"
      v.action = "update"
    end
  end
  updateDownloadQueue()
end

local function updateAllMissing()
  log('D', 'updateAllMissing', "")
  updatingRepo = true
  for k,v in pairs(updateQueue) do
    if v.action == "missing" then
      v.update = true
      v.state  = "updating"
      v.action = "update"
    end
  end
  updateDownloadQueue()
end

local function setRepoMsg(data)
  repoMsg = data
end

local function setRepoCmd(cmddata)
  repoCmd = cmddata
end

local function setrepoAutomationMsg(data)
  repoAutomationMsg = data
end

local function onModManagerReady()
  local mname = ""
  M.runSubscription()
  if repoCmd.forceInstall then
    for k,v in pairs(repoCmd.forceInstall) do
      if core_modmanager.getModNameFromID(v) == nil then
        modSubscribe(v)
      end
    end
  end
  if repoCmd.forceRemove then
    for k,v in pairs(repoCmd.forceRemove) do
      if core_modmanager.getModNameFromID(v) ~= nil then
        modUnsubscribe(v)
      end
    end
  end
  if repoCmd.forceDisable then
    for k,v in pairs(repoCmd.forceDisable) do
      guihooks.trigger('repoError', 'force Disable : '..v)
      if(v:find(".zip") ~= nil) then
        mname = v:gsub(".zip", "")
      else
        mname = core_modmanager.getModNameFromID(v)
      end
      if mname ~= nil then
        core_modmanager.deactivateModId(mname)
      end
    end
  end
  repoCmd = {}
end

local function uiShowRepo()
  guihooks.trigger('MenuHide', false);
  guihooks.trigger('ChangeState', {state = "menu.mods.local", params = {}})
end

local function uiShowMod(modId)
  guihooks.trigger('MenuHide', false);
  -- guihooks.trigger('ChangeState', {state = "menu.mods.local", params = {}})
  -- guihooks.trigger('ChangeState', {state = 'menu.mods.details({modId:"'..modId..'"})', params = {}})
  guihooks.trigger('ShowMod', modId)
end

local function runSubscription()
  if #subList > 0 and core_modmanager.isReady() and Engine.Online.isAuthenticated() then
    for k,v in pairs(subList) do
      modSubscribe(v)
    end
    subList = {}
  end
end

local function onOnlineStateChanged( connected )
  runSubscription()
end

-- interface
M.requestMods = requestMods
M.requestMyMods = requestMyMods
M.requestMod = requestMod
M.requestSubscriptions = requestSubscriptions
M.modSubscribe = modSubscribe
M.modUnsubscribe = modUnsubscribe
M.installMod = installMod
M.addUpdateQueue = addUpdateQueue
M.uiUpdateQueue = uiUpdateQueue
M.updateAllMods = updateAllMods
M.updateOneMod = updateOneMod
M.changeStateUpdateQueue = changeStateUpdateQueue
M.onUpdate = onUpdate
M.setRepoMsg = setRepoMsg
M.setRepoCmd = setRepoCmd
M.setrepoAutomationMsg = setrepoAutomationMsg
M.onModManagerReady = onModManagerReady
M.uiShowRepo = uiShowRepo
M.uiShowMod = uiShowMod
M.onOnlineStateChanged = onOnlineStateChanged
M.runSubscription = runSubscription
M.requestModOffline = requestModOffline
M.updateAllMissing = updateAllMissing

-- how to use in JS:
-- var args = { test = 1 }
-- bngApi.engineLua("extensions.core_repository.requestMods(" + bngApi.serializeToLua(args) + ")");

return M
