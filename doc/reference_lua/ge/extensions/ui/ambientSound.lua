-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M ={}
local soundStreams={}
local streamID = 0

--[[get random soundfile and random delay and add it to currentSoundData table
@@param stream table that contain one soundstream data
]]
local function getRandomSound(stream)
  local temp =nil
  repeat
    temp= math.random(#stream.sounds)
  until stream.previousSound~=temp
  stream.previousSound=temp
  stream.currentSoundData={}                  --which sound file in soundstream is currently playing
  stream.currentSoundData.currentSound = stream.sounds[temp]
  if stream.delay and tableSize(stream.delay) ==2 then
    stream.currentSoundData.delay = math.random(stream.delay[1],stream.delay[2])
  elseif tableSize(stream.delay)==1 then
    temptable.delay = math.random(stream.delay[1])   --  generates integer numbers between 1 and stream.delay[1]
  else
    temptable.delay = 0
  end
  stream.currentSoundData.currentTime  =0
  stream.currentSoundData.playing =false
end
--[[
setStreamState to set volume ,pitch..etc of each stream
]]
local function setStreamState(streamID,volume,pitch,fadeInTime)
  for i=1,#soundStreams do
    if i== streamID then
      soundStreams[i].volume = volume
      soundStreams[i].pitch= pitch
    end
  end
end
--[[
this function update the sounds in currentSoundData
]]
local function update(dt)
  for i=1,#soundStreams do
    local curSound =soundStreams[i].currentSoundData
    if FS:fileExists(curSound.currentSound) then
      if curSound.playing ==false then
        if not soundStreams[i].volume then
          soundStreams[i].volume =1
        end
        local res = Engine.Audio.playOnce('AudioGui', curSound.currentSound,{ volume = 0.29,pitch=soundStreams[i].pitch,fadeInTime=soundStreams[i].fadeInTime} )
        curSound.length= res.len
        curSound.playing =true
      else
        curSound.currentTime = curSound.currentTime + dt
        if curSound.currentTime > curSound.delay + curSound.length then
          getRandomSound(soundStreams[i])
        end
      end
    end
  end
end
--[[
set soundStreams table that contains number of streams to be played
call getrandomSound to set currentSoundData and returns stream ID
@param json string
]]
local function init(json)
  if not FS:fileExists(json) then
    log('E',json .. "not Exist")
    return
  end
  local soundFile = jsonReadFile(json)
  local soundTable={}
  for k,v in pairs(soundFile) do
    soundTable[k]=v
  end
  table.insert(soundStreams,soundTable.data)
  streamID = streamID + 1
  soundStreams[streamID].streamID = streamID
  getRandomSound(soundStreams[streamID])
  return streamID
end

--[[
this function remove stream object from sounstream table
@param ID is number represent streamID
]]
local function deleteSoundSFX(ID)
  local soundtablesize =tableSize(soundStreams)
  for i=1,soundtablesize do
    if soundStreams[i].streamID == ID then
      table.remove(soundStreams,i)
      return
    end
  end
end

M.init =init
M.update=update
M.deleteSoundSFX = deleteSoundSFX
M.setStreamState = setStreamState
return M