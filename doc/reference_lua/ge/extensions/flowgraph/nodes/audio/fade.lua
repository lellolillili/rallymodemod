-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Fade'
C.icon = "audiotrack"
C.description = 'Fades the master volume'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'fadeIn', description = 'start fading in' },
  { dir = 'in', type = 'flow', name = 'fadeOut', description = 'start fading out' },
  { dir = 'out', type = 'flow', name = 'fadeDone', description = 'Outflow for this node.' },

  { dir = 'in', type = 'string', name = 'channel', default = 'AudioChannelMaster', description = 'The audio channel to fade' },

  { dir = 'in', type = 'number', name = 'fadeTime', default = 1, description = "How long the fade should take in seconds" },
}

C.tags = {'sound','audio','volume'}

function C:reset()
  self.timer = 0
  self.mode = ''
end

function C:init(mgr, ...)
  self:reset()
end

function C:_executionStopped()
  self:reset()

  if self.tempVolume then
    local channnelName = self.pinIn.channel.value or 'AudioChannelMaster'
    Engine.Audio.setChannelVolume(channnelName, self.tempVolume, true)
  end
end

function C:work()
  local channnelName = self.pinIn.channel.value or 'AudioChannelMaster'
  local fadeTime = self.pinIn.fadeTime.value or 1

  if self.pinIn.fadeIn.value or self.pinIn.fadeOut.value then
    local cmode = ''
    if self.pinIn.fadeIn.value and not self.pinIn.fadeOut.value then
      cmode = 'in'
    elseif self.pinIn.fadeOut.value and not self.pinIn.fadeIn.value then
      cmode = 'out'
    end
    if cmode ~= self.mode then
      -- mode changed :D
      --print("new mode: " .. tostring(cmode))
      self:reset()
      self.mode = cmode
      self.tempVolume = Engine.Audio.getChannelVolume(channnelName, true)
      self.storedVolume = Engine.Audio.getChannelVolume(channnelName, false)
    end
  end

  if self.mode == '' then return end

  self.timer = self.timer + self.mgr.dtSim
  if self.timer >= fadeTime then
    self.pinOut.fadeDone.value = true
  else
    --print(" self.mode = " .. tostring(self.mode) .. " / self.timer = " .. tostring(self.timer) .. ' / fadeTime = ' .. tostring(fadeTime))
    local newVolume = 0
    if self.mode == 'out' then
      newVolume = self.tempVolume * (fadeTime - self.timer)
    elseif self.mode == 'in' then
      newVolume = self.storedVolume * (1 - (fadeTime - self.timer))
    end
    --print(" new volume: " .. tostring(newVolume))
    Engine.Audio.setChannelVolume(channnelName, newVolume, true)
    self.pinOut.fadeDone.value = false
  end
end

return _flowgraph_createNode(C)
