local M = {}

local function getCodriver()
  return codriver
end

local function getRally()
  return rally
end

local function getRallyWps()
  return rallyWaypoints
end

local currentSentence = {}
local function updateCurrentSentence(phrase)
  if phrase ~= nil and phrase ~= "" then
    table.insert(currentSentence, trim(phrase))
  else
    log("E", logTag, "Trying to apppend an empty phrase.")
  end
end

local function clearCurrentSentence(phrase)
  currentSentence = {}
end

local function getPhrasesFromWords(words)
  local phrase = ""
  local match = ""
  for i, v in ipairs(words) do
    phrase = phrase .. v .. ' '
    if codriver[trim(phrase)] then
      match = phrase
    end
  end
  for i = 1, #string.split(match), 1 do
    table.remove(words, 1)
  end
  if match == "" then
    return
  end
  updateCurrentSentence(match)
  getPhrasesFromWords(words)
end

local playQueue = {}

local function speak()
  if tableIsEmpty(playQueue) then return 0 end
  local ph = codriver[playQueue[1]].samples
  local sample = ph[math.random(1, #ph)]
  local out = Engine.Audio.playOnce('AudioGui', sample, { volume = rcfg.volume })
  table.remove(playQueue, 1)
  return out.len
end

local function queuePhrase(s)
  if s == "" then return end
  local words = stringToWords(s)
  words._ = nil
  getPhrasesFromWords(words)
  for _, v in ipairs(currentSentence) do
    -- Only add phrases to the current sentence if they have a sample.
    -- For example, a user may provide an empty phrase as a
    -- substitution if they just want the co-driver to ignore a
    -- pacenote.
    if codriver[v].samples then
      table.insert(playQueue, v)
    end
  end
  if rcfg.visual == true then
    local pics = {}
    for _, v in ipairs(currentSentence) do
      if codriver[v].pics then
        for __, vv in ipairs(codriver[v].pics) do
          guihooks.trigger("pnotesQueueSymbol", {
            i = last, pics = vv
          })
        end
      end
    end
  end
  clearCurrentSentence()
end

local function breathe(t)
  -- TODO: not sure oneTenth is actually one tenth of a second
  -- local oneTenth = 0.0001
  -- for i=0, t, 1 do
  --   speakTimer = speakTimer + t*oneTenth
  -- end
end

local function onPreRender(dtReal, dtSim, dtRaw)
  -- TODO: not sure if this is useful, but it should short-circuit everything
  -- until the rally is initialized.
  if (not rally) or (rallyInitd == false) or (rallyPaused == true) then return end
  if speakTimer < 0 then
    speakTimer = speak(speakTimer)
  end
  speakTimer = speakTimer - dtReal
  local speed = getPlayerSpeed()
  local timeOffset = rcfg.timeOffset
  local posOffset = rcfg.posOffset
  local breathLength = rcfg.breathLength
  local pred = posOffset + speed * timeOffset
  local pnote = getPacenoteAfter(last)

  local i = pnote.index
  if i == nil then return end
  local rally = getRally()
  if last ~= 0 then
    if rally[last].call then
        rallyInfo.lastPacenote = last .. ' - ' .. rally[last].call .. '; ' .. rally[last].options
    end
  end

  if i > last and i < rallyEnd and (rally[i].call ~= nil) then
    rallyInfo.nextPacenote = i .. ' - ' ..
      rally[i].call .. '; ' .. rally[i].options

    local dist = getDistFrom(i)
    if (dist < pred) and i > last and i < rallyEnd then
      suffix = getDistCall(i)
      -- If last pacenote's automatic suffix was disabled,
      -- then also disable this pacenotes's automatic prefix.
      if nosuffix then
        prefix = ""
      end
      nosuffix = false
      if rcfg.recce then
        local name = getWaypointName(i)
      end
      queuePhrase(prefix .. ' ' .. pnote.call)
      -- TODO: all these breaththings must be double checked. No idea
      -- wtf they do.
      if pnote.opts then
        if pnote.opts:find("nosuffix") then
          breathe(breathLength)
          nosuffix = true
        elseif pnote.opts:find("nopause") then
          breathe(breathLength)
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        elseif pnote.opts:find("shortpause") then
          breathe(round(0.5 * timeOffset * 10))
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        elseif pnote.opts:find("verylongpause") then
          breathe(round(2 * timeOffset * 10))
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        elseif pnote.opts:find("longpause") then
          breathe(round(1.5 * timeOffset * 10))
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        elseif pnote.opts:find("pause") then
          breathe(round(timeOffset * 10))
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        else
          breathe(breathLength)
          queuePhrase(tostring(suffix))
          breathe(breathLength)
        end
      else
        breathe(breathLength)
        queuePhrase(tostring(suffix))
      end
      -- If the distance call is too close to get called,
      -- then prepend a linkword (e.g. "into") to the next call.
      if suffix == "" then
        prefix = rcfg.linkWord
      else
        prefix = ""
      end
      last = i
      -- TODO: probably need something better than this
      guihooks.trigger("pnotesHideSymbol", i - 1)
    end
  end
end

-- UI stuff --
--------------

M.onRaceStart = onRaceStart
M.onPreRender = onPreRender
M.onPhysicsPaused = onPhysicsPaused
M.onPhysicsUnpaused = onPhysicsUnpaused
M.onRaceWaypointReached = onRaceWaypointReached
M.onScenarioChange = onScenarioChange
M.onScenarioRestarted = onScenarioRestarted
M.getRally = getRally
M.getRallyWps = getRallyWps
M.getCodriver = getCodriver
M.stats = stats
M.dumpDebug = dumpDebug
M.uiToConfig = uiToConfig
M.getPacenoteFile = getPacenoteFile
M.quickdebug = quickdebug
M.getRallyWaypoints = getRallyWaypoints
M.rallyInit = rallyInit
M.rallyInitScenarios = rallyInitScenarios
M.getWaypointsFromHere = getWaypointsFromHere
M.buildRally = buildRally
M.startFrom = startFrom
return M
