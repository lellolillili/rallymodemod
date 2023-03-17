-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- not working atm
--[[

local M = {}

--- options start

local reconnect = true
local ircServer = 'irc.beamng.com'
local startChannel = '#beamng'

--- options end


require "irc/init"
local sleep = require "socket".sleep

local s = nil
local refCount = 0 -- how many sinks we have using this. 0 = can be disabled
local enabled = false -- this has nothing to do with enabled or alike
local connected = false
local issueReconnect = false
local localUser = nil
local joinedChannels = {}
local statusMsg = nil

local wishedNickName = 'ingame_' .. randomASCIIString(6)


local function sendState()
  guihooks.trigger('ChatState', {user = localUser, connected = connected, channels = joinedChannels, status = statusMsg})
  --extensions.hook('onChatConnect')
  --guihooks.trigger('ChatConnect')
end

local function onInit()
  --if not settings.state or not settings.state.SettingsGameplayOtherIRC or not settings.state.SettingsGameplayOtherIRC.value then return end
  -- do not connect by default, only if actually 'used'
  sendState()
end

local function force_quit()
  if not s then return end
  s:shutdown()
  s = nil
  connected = false
  joinedChannels = {}
  sendState()
end

local function force_reconnect()
  --if not settings.state.SettingsGameplayOtherIRC.value then return end
  if Steam.isWorking and Steam.accountLoggedIn then
    wishedNickName = Steam.playerName
  end
  statusMsg = 'connecting ...'
  connected = false
  joinedChannels = {}

  s = irc.new{
    nick = wishedNickName,
    username = wishedNickName,
    realname = beamng_versiond .. '-' .. beamng_arch
  }
  -- TODO: handle NickChange for own nickname
  s:hook('OnChat', function(user, channel, message)
    --log('D', 'chat', (("[%s] %s: %s"):format(channel, user.nick, message)))
    extensions.hook('onChatMessage', user, channel, message)
    guihooks.trigger('ChatMessage', {user = user, channel = channel, message = message})
  end)

  s:hook('OnConnect', function()
    log('D', 'chat', 'connected')
    statusMsg = 'connected, joining ...'
    connected = true
    s:setMode({add = 'x'})
    s:join(startChannel)
    sendState()
  end)


  s:hook('OnBan', function(channel, message)
    log('D', 'chat', 'banned from ' .. tostring(channel))
    statusMsg = 'You are banned.'
    force_quit()
  end)


  s:hook('OnKick', function(channel, kicked, prefix, reason)
    log('D', 'chat', 'kicked from ' .. tostring(channel))
    statusMsg = 'You got kicked, trying to rejoin'
    sendState()
    s:join(channel)
  end)


  s:hook('OnDisconnect', function()
    log('D', 'chat', 'disconnected')
    connected = false
    joinedChannels = {}
    statusMsg = 'disconnected'
    sendState()
    if reconnect then
      log('D', 'chat', 'reconnecting ...')
      issueReconnect = true
    end
  end)

  s:hook('OnJoin', function(user, channel)
    if user.nick == wishedNickName then
      statusMsg = 'joined channel ' .. tostring(channel)
      localUser = user
      table.insert(joinedChannels, channel)
      sendState()
    end
  end)

  s:connect(ircServer)
end

local function onUpdate()
  --log('D', 'chat', 'onUpdate')
  if issueReconnect then
    s = nil
    force_reconnect()
  end
  if connected then
    s:think()
  end
end

local function send(target, message)
  if connected then
    s:sendChat(target, message)
  end
end

local function activate()
  if settings.getValue('onlineFeatures') ~= 'enable' then
    log('E', 'irc.activate', 'chat functions disabled because online features are disabled')
    return
  end

  if not enabled then
    log('D', 'chat', 'activating ...')
    enabled = true
    force_reconnect()
    refCount = refCount + 1
  end
end

local function deactivate()
  if enabled then
    log('D', 'chat', 'deactivating ...')
    refCount = refCount - 1

    -- stay connected for now in case the user reopens this later on
    --if refCount <= 0 then
    --  force_quit()
    --  enabled = false
    --end
  end
end

-- public interface
M.onInit = onInit
M.onUpdate = onUpdate
M.send = send
M.requestState = sendState
M.activate = activate
M.deactivate = deactivate

return M
]]
