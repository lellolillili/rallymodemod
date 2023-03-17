-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local onSpineAnimationFinished_callback = false
local logTag = 'comics'
local lastVolumes = nil

local function reset()
  if lastVolumes then
    setAudioChannelsVolume(lastVolumes)
    lastVolumes = nil
  end
end

local function playComic(comicData, comicFinishedCallback)
  log('I', logTag, 'start displaying comic')
  reset()
  if not comicData then return end
  if comicData then
      local channel = scenetree.AudioChannelGuiComic
      if channel then channel:play(0) end
      local comicPath = comicData.path
      local comicPanels = {backgroundSound = comicData.backgroundSound, list = {}}
      local numberPanels = tableSize(comicData.order)
      for i=1,numberPanels do
        if type(comicData.order[i]) == 'string' then
          local panel = comicData.order[i] ..'/'
          table.insert(comicPanels.list, comicData.path..'/'..panel)
        else
          local panel = comicData.order[i].comic ..'/'
          table.insert(comicPanels.list, {comic = comicData.path..'/'..panel, sound = comicData.order[i].sound})
        end
      end

      onSpineAnimationFinished_callback = comicFinishedCallback or nop

      -- dump(comicPanels)
      -- dump(onSpineAnimationFinished_callback)

      lastVolumes = {}
      local audioCallback = function(name, audio)
        -- dump(name)
        lastVolumes[name] = audio:getVolume()
        if name ~= 'AudioChannelGuiComic' then audio:setVolume(0) end
      end
      forEachAudioChannel(audioCallback)
      guihooks.trigger('ChangeState', {state = 'comic', params = {comiclist = comicPanels}})
    end
end

local function onSpineAnimationFinished()
  if not onSpineAnimationFinished_callback then return end

  log('I', logTag, 'finished displaying comic')
  onSpineAnimationFinished_callback()
  onSpineAnimationFinished_callback = false
  reset()

  local channel = scenetree.AudioChannelGuiComic
  if channel then channel:stop(1) end
end

local function onScenarioChange(sc)
  if not sc or sc.state == 'pre-start' then
    reset()
  end
end

M.playComic = playComic
M.onSpineAnimationFinished = onSpineAnimationFinished
M.onScenarioChange = onScenarioChange

return M
