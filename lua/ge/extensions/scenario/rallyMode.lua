local M = {}

local raceMarker = require("scenario/race_marker")

local rallyInitd = false
local rallyPaused = false

local logTag = "rallyMode"
local rallyCfgFile = "/settings/rallyconfig.ini"
local symbolsDir = "/art/symbols/"
local last = 0
local prefix = ""
local suffix = ""
local nosuffix = false
local speakTimer = -1
local codriver = {}
local rally = {}
local allowedDists = {}
local corners = {}

-- Editable configuration options will go in this table
local rcfg = {}
local rallyInfo = {}

-- From http://lua-users.org/wiki/CsvUtils
local function fromCSV(s)
    s = s .. ',' -- ending comma
    local t = {} -- table to collect fields
    local fieldstart = 1
    repeat
        -- next field is quoted? (start with `"'?)
        if string.find(s, '^"', fieldstart) then
            local a, c
            local i = fieldstart
            repeat
                -- find closing quote
                a, i, c = string.find(s, '"("?)', i + 1)
            until c ~= '"' -- quote not followed by quote?
            if not i then error('unmatched "') end
            local f = string.sub(s, fieldstart + 1, i - 1)
            table.insert(t, (string.gsub(f, '""', '"')))
            fieldstart = string.find(s, ',', i) + 1
        else -- unquoted; find next comma
            local nexti = string.find(s, ',', fieldstart)
            table.insert(t, string.sub(s, fieldstart, nexti - 1))
            fieldstart = nexti + 1
        end
    until fieldstart > string.len(s)
    return t
end

local function strToBool(s)
    local b
    if s == "true" then
        b = true
    elseif s == "false" then
        b = false
    end
    return b
end

local function getWaypointName(index)
    local sc = scenario_scenarios.getScenario()
    return sc.BranchLapConfig[index]
end

local function isSlow(s)
    -- True if s is a slow corner
    for _, v in ipairs(rcfg.slowCorners) do
        if s:find(v) then
            return true
        end
    end
end

local function isLinked(s)
    -- True if s has a link word in it
    if rcfg.linkWord == s:match("(%w+)") then
        return true
    end
end

local function distOrLink(d)
    -- Outputs rounded distance or linkWords when below cutoff
    local M = tonumber(allowedDists[#allowedDists])
    if d > M then
        return M
    end
    if d < rcfg.cutoff then
        return ""
    else
        for i, v in ipairs(allowedDists) do
            -- The + 3 means we're rounding conservatively
            print(v)
            if d + 3 < tonumber(v) then
                return allowedDists[i - 1]
            end
        end
    end
end

local function getWaypointPos(i)
    -- Gets the position vector of the i-th waypoint
    local name = getWaypointName(i)
    local obj = scenetree.findObject(name)
    return obj:getPosition()
end

local function getDistBtw(m, n)
    -- Returns dist between the m-th and n-th waypoints
    local d = 0
    for i = m, n - 1, 1 do
        local a = getWaypointPos(i)
        local b = getWaypointPos(i + 1)
        d = d + a:distance(b)
    end
    return d
end

local function getCallFromWp(i)
    -- Gets content of the "pacenote" DynamicField from waypoints. Only used to
    -- build the rally table from the prefab
    local name = getWaypointName(i)
    local obj = scenetree.findObject(name)
    local call = obj:getDynDataFieldbyName("pacenote", 0) or "empty"
    return call
end

local function getCall(i)
    if rally[i] then return rally[i].call end
end

local function getMarkerFromWp(i)
    -- Returns nil if the waypoint is not a marker. Only used to build the
    -- rally table from the prefab
    local name = getWaypointName(i)
    local obj = scenetree.findObject(name)
    local marker = obj:getDynDataFieldbyName("marker", 0)
    return marker
end

local function getMarker(i)
    if rally[i] then return rally[i].marker end
end

local function getOptionsFromWp(i)
    -- Gets the contents of the "options" DynamicField. Only used to build the
    -- rally table from the prefab
    if i == nil then return end
    local name = getWaypointName(i)
    local obj = scenetree.findObject(name)
    local opts = obj:getDynDataFieldbyName("options", 0)
    return opts or ""
end

local function getOptions(i)
    if rally[i] then return rally[i].options end
end

local function getPacenoteAfter(i)
    -- Gets next nonempty pacenote after "i" and its options
    local sc = scenario_scenarios.getScenario()
    local max = #sc.BranchLapConfig
    local inext = i + 1
    for k = inext, max, 1 do
        local pCall = getCall(k)
        if k >= max then
            --TODO: not sure what this does anymore
            return { index = max, call = pCall }
        end
        if pCall ~= nil then
            if pCall ~= "empty" then
                local pnote = {
                    index = k,
                    call = pCall,
                    opts = getOptions(k)
                }
                if isSlow(pCall) then
                    pnote.opts = pnote.opts .. "pause"
                end
                return pnote
            end
        end
    end
end

local function getDistCall(p)
    -- Gets the distance call to append to the next call, or a linkword if the
    -- next corner is closer than the cutoff
    local pFinal = getPacenoteAfter(p).index
    if (pFinal == p + 1) then
        local dist = getDistBtw(p, pFinal)
        return distOrLink(dist)
    elseif pFinal > p + 1 then
        for i = pFinal - 1, p + 1, -1 do
            if getMarker(i) ~= nil then
                p = i
            end
        end
        local dist = getDistBtw(p, pFinal)
        return distOrLink(dist)
    elseif pFinal <= p then
        log("E", logTag, "Next waypoint index is <= than the previous.")
    elseif pFinal == nil then
        log("E", logTag, "Could not get next waypoint index.")
    end
end

local function getWaypointId(index)
    -- TODO: This is probably stupidly roundabout
    local sc = scenario_scenarios.getScenario()
    local name = sc.BranchLapConfig[index]
    local obj = scenetree.findObject(name)
    return obj:getId()
end

local function getPlayerPos()
    return core_vehicles.getCurrentVehicleDetails().current.position
end

local function getPlayerVelocity()
    -- Returns the velocity vector. Components are in m/s
    local playerVehicle = scenetree.findObject(be:getPlayerVehicleID(0))
    return playerVehicle:getVelocity()
end

local function getPlayerSpeed()
    -- Returns the norm of the velocity vector
    local playerVehicle = scenetree.findObject(be:getPlayerVehicleID(0))
    local velocity = playerVehicle:getVelocity()
    return velocity:lengthGuarded()
end

local function getLastWaypointIndex()
    -- Returns the index of the last crossed waypoint
    local id = be:getPlayerVehicleID(0)
    local w = scenario_waypoints.state.vehicleWaypointsData[id]
    if w == nil then
        return 0
    end
    return w.cur
end

local function getDistFrom(n)
    -- Gets distance between player and n-th waypoint
    local i = getLastWaypointIndex() + 1
    local wPos = getWaypointPos(i)
    local pPos = getPlayerPos()
    local d = pPos:distance(wPos) + getDistBtw(i, n)
    return d
end

local function stageLength()
    local iFinal = #scenario_waypoints.state.originalBranches.mainPath
    return getDistBtw(1, iFinal)
end

local function getToFinish()
    local iFinal = #scenario_waypoints.state.originalBranches.mainPath
    return getDistFrom(iFinal)
end

local function getFromStart()
    return stageLength() - getToFinish()
end

local function getLastWaypoint()
    local wIndex = getLastWaypointIndex()
    local wCall = getCall(wIndex)
    if wCall == nil then
        wCall = "empty"
    end
    local pName = getWaypointName(wIndex)
    return { index = wIndex, call = wCall, name = wName }
end

local function tokm(x)
    local xkm = x / 1000
    return string.format("%.1f", xkm)
end

local function stats()
    local total = stageLength()
    local from = getFromStart()
    local to = getToFinish()
    local s = tostring(tokm(from) .. " / " .. tokm(total) .. " (km)")
    log("I", logTag, "Stats: " .. s)
    guihooks.trigger('Message',
        { ttl = 5, msg = s, category = "align", icon = "flag" })
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

local function fileExists(f)
    local f = io.open(f, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

local function stringToWords(s)
    if s then
        local words = {}
        for w in s:gmatch("%S+") do table.insert(words, w) end
        return words
    end
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

-- You can use up to 20 alternative samples
local altSuffixes = {}
for i = 1, 20 do altSuffixes[i] = '_' .. tostring(i) end

local function buildCodriver(f)
    local dir = f
    if (not fileExists(dir .. "/codriver.ini")) then
        log("E", logTag, "Codriver file not found. Expecting \"" .. dir .. "/codriver.ini\".")
        return
    end
    local d = {}
    local f = io.open(dir .. "/codriver.ini", "r")
    for line in f:lines() do
        if string.len(line) > 0 then
            local firstChar = string.sub(line, 1, 1)
            if firstChar ~= '#' and firstChar ~= ';' and firstChar ~= '/' then
                if line:find("slowCorners=") then
                    local sc = line:match("slowCorners=(.*)$")
                    rcfg.slowCorners = fromCSV(sc)
                elseif line:find("LR") then
                    local cstring
                    local sample
                    cstring, sample = line:match("^(%d*%u)%s%-%s(.*)$")
                    corners["L" .. cstring] = sample:gsub("LR", "left")
                    corners["R" .. cstring] = sample:gsub("LR", "right")
                else
                    local key
                    local sub
                    if line:find("%>%>%>") then
                        key, sub = line:match("^(.*)%>%>%>(.*)$")
                        key = trim(key)
                        sub = trim(sub)
                    else
                        key = trim(line:match("^(.+)$"))
                    end
                    d[key] = {}
                    local mainSample = dir ..
                        '/samples/' .. (sub or key) .. '.ogg'
                    if fileExists(mainSample) then
                        d[key]["samples"] = {}
                        table.insert(d[key]["samples"], mainSample)
                        for _, v in ipairs(altSuffixes) do
                            local altSample = dir ..
                                '/samples/alts/' .. (sub or key) .. v .. '.ogg'
                            -- Dont search for the i+1-th and following
                            -- alternative samples if you can't find the i-th
                            -- sample. This avoids a lot of useless, very
                            -- slow, file searches.  The filenames must not
                            -- skip any numbers though.
                            if not fileExists(altSample) then break end
                            table.insert(d[key]["samples"], altSample)
                        end
                    end

                    local pf = symbolsDir .. (sub or key) .. '.svg'
                    if fileExists(pf) then
                        d[key]["pics"] = {}
                        table.insert(d[key]["pics"], pf)
                    end
                end
            end
        end
    end
    f:close()

    local fs = io.open(dir .. "/symbols.ini", "r")
    for line in fs:lines() do
        if string.len(line) > 0 then
            local firstChar = string.sub(line, 1, 1)
            if firstChar ~= '#' and firstChar ~= ';' and firstChar ~= '/' then
                if line:find("%>%>%>") then
                    local key
                    local sub = nil
                    key, sub = line:match("^(.*)%>%>%>(.*)$")
                    key = trim(key)
                    sub = fromCSV(sub)
                    if d[key] then
                        d[key].pics = {}
                        for _, v in ipairs(sub) do
                            local pf = symbolsDir .. trim(v) .. '.svg'
                            if fileExists(pf) then
                                table.insert(d[key].pics, pf)
                            else
                                log("W", logTag, pf .. " - Symbol substitution was specified,\
                                but symbol file \"" .. pf .. "\" was not found. You might be missing a picture.")
                            end
                        end
                    else
                        log("W", logTag, "Symbol substitution was specified,\
                        but key \"" .. key .. "\" was not found in the codriver. You might be missing the audio sample.")
                    end
                end
            end
        end
    end
    fs:close()

    local dists = { 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130,
        140, 150, 160, 170, 180, 190, 200, 250, 300, 350, 400, 450, 500, 550,
        600, 650, 700, 750, 800, 850, 900, 1000, 1500, 2000 }
    for _, v in ipairs(dists) do
        if d[tostring(v)] then
            table.insert(allowedDists, v)
        end
    end

    d["_"] = nil

    return d
end

local function checkConfig(c)
    -- TODO: this is used to check config of the ini file, and to check config
    -- from the UI. It should probably be a bit more sophisticated.

    if c == nil then return false end
    if rcfg == nil then return false end

    local b = false

    if type(c.breathLength) == "number" then
        b = true
    elseif type(c.timeOffset) == "number" then
        b = true
    elseif type(c.visual) == "bool" then
        b = true
    elseif type(c.volume) == "number" then
        b = true
    elseif type(c.iconSize) == "number" then
        b = true
    elseif type(c.iconPad) == "number" then
        b = true
    else
        b = false
    end
    return b
end

local function readCfgFromIni()
    -- Reads config from "rallyConfig.ini"
    log("I", logTag, [[========= Pacenote Director Started ========]])
    local c = loadIni(rallyCfgFile)
    rcfg.hideMarkers = c.hideMarkers
    rcfg.timeOffset = c.timeOffset
    rcfg.posOffset = c.posOffset
    rcfg.cutoff = c.cutoff
    rcfg.linkWord = c.linkWord
    rcfg.breathLength = c.breathLength
    rcfg.recce = c.recce
    rcfg.visual = c.visual
    rcfg.firstTime = c.firstTime
    rcfg.codriverDir = c.codriverDir
    rcfg.volume = c.volume
    rcfg.iconSize = c.iconSize
    rcfg.iconPad = c.iconPad
    if (checkConfig(rcfg) == false) then
        log("E", logTag, "Bad configuration file. Delete your local config file. Using some reasonable defaults instead.")
        rcfg.breathLength = 0.1
        rcfg.codriverDir = "Stu"
        rcfg.cutoff = 30
        rcfg.hideMarkers = true
        rcfg.linkWord = "into"
        rcfg.posOffset = 0
        rcfg.recce = true
        rcfg.timeOffset = 3.8
        rcfg.visual = true
        rcfg.firstTime = true
        rcfg.volume = 8
        rcfg.iconSize = 100
        rcfg.iconPad = 0
    else
        log("I", logTag, "Config file loaded.")
    end
end

local function getPacenoteFile()
    local sc = scenario_scenarios.getScenario()
    local src = sc.sourceFile or sc.track.sourceFile
    local f = src:gsub(".json", "") .. ".pnt"
    return f
end

local function buildRally()
    local t = {}
    local sc = scenario_scenarios.getScenario()
    local max = #sc.BranchLapConfig
    for i = 1, max, 1 do
        -- TODO: don't forget to change this if you change the way markers
        -- work. Which you probably should cause it's a bit dumb.
        local isMarker = false
        if getMarkerFromWp(i) then isMarker = true end
        local r = {
            wpName = getWaypointName(i),
            wpId = getWaypointId(i),
            marker = isMarker,
            options = getOptionsFromWp(i),
            pos = getWaypointPos(i),
            default = true
        }
        local s = getCallFromWp(i)

        if (s ~= nil) and (s ~= "empty") then
            for i, v in pairs(corners) do
                s = s:gsub(i, v)
            end

            r["call"] = s
            r["linked"] = isLinked(s)
            r["slow"] = isSlow(s)

            table.insert(t, r)
        else
            table.insert(t, r)
        end
    end
    -- Loads custom pacenotes if found
    local src = sc.sourceFile or sc.track.sourceFile
    local f = src:gsub(".json", "") .. ".pnt"
    local cfname = f
    local f = io.open(f, "r")
    if f then
        log("I", logTag,
            "Found a custom pacenotes file (\"" .. cfname ..
            "\"). \nDefault pacenotes will be overwritten wherever an alternative\
        is provided."
        )
        local d = {}
        for line in f:lines() do
            if string.len(line) > 0 then
                local firstChar = string.sub(line, 1, 1)
                if firstChar ~= '#' then
                    local ind = tonumber(line:match("^%s*(%d+)%s*%-.*$"))
                    if ind then
                        local mrk = line:find("^%s*%d+%s*%-%s*marker")
                        if mrk == nil then
                            local s = line:match("^%s*%d+%s*%-%s*(.*)%s*;%s*.*")
                            local opt = line:match("^%s*%d+%s*%-%s*.*%s*;%s*(.*)$") or ""
                            if (s ~= nil) and (s ~= "empty") then
                                for i, v in pairs(corners) do
                                    s = s:gsub(i, v)
                                end
                                t[ind].call = s
                                t[ind].options = opt
                            end
                        else
                            t[ind].marker = true
                        end
                    end
                end
            end
        end
        f:close()
    else
        log("I", logTag,
            "No custom pacenotes not found (\"" .. cfname .. "\").\
        Using default pacenotes."
        )
    end
    -- TODO: I don't think this works. wtf is that
    for k, v in ipairs(rally) do
        if v.call then
            local wds = stringToWords(v.call)
            dump(wds)
            getPhrasesFromWords(wds)
            dump(currentSentence)
            dump("test")
            local mat = 0
            for _, m in ipairs(wds) do
                mat = mat + #(wds)
            end
            if mat ~= #(wds) then
                log("W", logTag,
                    "Fix pacenotes or codriver. Problems with: " .. tostring(k) ..
                    " - " .. v.call .. ". Pacenotes will malfunction."
                )
            end
            clearCurrentSentence()
        end
    end
    return t
end

local function rallyInit()
    readCfgFromIni()
    codriver = buildCodriver("/art/codrivers/" .. rcfg.codriverDir)
    rally = buildRally()
    if rcfg.hideMarkers then raceMarker.hide(true) end
    last = 0
    prefix = ""
    suffix = ""
    nosuffix = false
    speakTimer = -1
    rallyInitd = true
    rallyInfo.pacenoteFile = getPacenoteFile()
end

local function onScenarioRestarted()
    rallyInitd = false
    rallyInit()
end

--- Hooks --
------------

local function onScenarioChange()
    if rcfg.hideMarkers then raceMarker.hide(true) end
    guihooks.trigger("cfgToUI", rcfg)
    guihooks.trigger("infoToUI", rallyInfo)
    if rallyInitd == false or rallyInitd == nil then
        rallyInit()
    end
end

local function onRaceStart()
    if rcfg == nil then return end
    if rcfg.firstTime == true then
        local str = "Rally Mode Mod by Lello Lillili\
                    ================================\
                    Quick Start Guide\
                    =================\
                    1) Enable Rally Mode UI \
                    [ Shift+Alt+U > Add App > Rally Mode UI ]\
                    2) Pause Physics (J) to open config/info menu\
                    3) Play around with the options\
                    4) Save (always save after changing the config)\
                    5) Unpause (J)\
                    6) To Hide this message,\
                    tick \"Welcome message\" from the pause menu\
                    (may take effect after changing map or restarting the game)\
                    "
        guihooks.trigger('Message',
            { ttl = 120, msg = str, category = "align", icon = "flag" })
    end
    guihooks.trigger("cfgToUI", rcfg)
    guihooks.trigger("infoToUI", rallyInfo)
    guihooks.trigger("showOpts")
    guihooks.trigger("hideUiOpts")
end

local function onRaceWaypointReached(data)
    if rcfg.hideMarkers then raceMarker.hide(true) end
    local i = getLastWaypointIndex()

    local name = getWaypointName(i)

    guihooks.trigger("pnotesHideSymbol", i - 1)
    if rcfg.recce then
        print('W[ ' .. tostring(i) .. ' ] - ' .. name)
    end

    rallyInfo.lastWaypointN = i
    rallyInfo.lastWaypoint = name
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
    --     speakTimer = speakTimer + t*oneTenth
    -- end
end

local function onPreRender(dtReal, dtSim, dtRaw)
    -- TODO: not sure if this is useful, but it should short-circuit everything
    -- until the rally is initialized.
    if (rallyInitd == false) or (rallyPaused == true) then return end
    if speakTimer < 0 then
        speakTimer = speak(speakTimer)
    end
    speakTimer = speakTimer - dtReal
    -- Other stuff
    local sc = scenario_scenarios.getScenario()
    if sc == nil then return end
    local raceState = sc.raceState
    local scenarioState = sc.state
    local max = #sc.BranchLapConfig
    if raceState == "racing" and scenarioState == "running" then
        local speed = getPlayerSpeed()
        local timeOffset = rcfg.timeOffset
        local posOffset = rcfg.posOffset
        local breathLength = rcfg.breathLength
        local pred = posOffset + speed * timeOffset
        local pnote = getPacenoteAfter(last)

        local i = pnote.index
        if i == nil then return end

        if last ~= 0 then
            rallyInfo.lastPacenote = last .. ' - ' ..
                rally[last].call .. '; ' .. rally[last].options
        end

        if i > last and i < max and (rally[i].call ~= nil) then
            rallyInfo.nextPacenote = i .. ' - ' ..
                rally[i].call .. '; ' .. rally[i].options

            local dist = getDistFrom(i)
            if (dist < pred) and i > last and i < max then
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
            end
        end
    end
end

local function getCodriver()
    return codriver
end

local function getRally()
    return rally
end

-- UI stuff --
--------------

local function writeCfgToIni()
    -- Need to convert tables into strings, and store back as table.
    if rcfg == nil then return end
    local t = deepcopy(rcfg)
    local s = ''
    for _, v in ipairs(t.slowCorners) do
        s = s .. v .. ','
    end
    t.slowCorners = s:sub(1, -2)
    log("I", logTag, "Writing config to" .. rallyCfgFile)
    saveIni(rallyCfgFile, t)
end

local function onPhysicsUnpaused()
    if rallyInitd == false or rallyInitd == nil then return end
    if rcfg == nil then return end
    guihooks.trigger("hideUiOpts")
    rallyPaused = false
end

local function onPhysicsPaused()
    rallyPaused = true
    if rallyInitd == false or rallyInitd == nil then return end
    if rcfg == nil then return end
    guihooks.trigger("cfgToUI", rcfg)
    guihooks.trigger("infoToUI", rallyInfo)
    guihooks.trigger("showOpts")
end

local function dumpDebug()
    dumpToFile("pacenoteDirector_rally.log", rally)
    dumpToFile("pacenoteDirector_codriver.log", codriver)
end

local function uiToConfig(s)
    -- TODO: this is really lazy
    if rcfg == nil then return end
    local opts          = fromCSV(s)
    local tmpcfg        = {}
    tmpcfg.breathLength = tonumber(opts[1])
    tmpcfg.timeOffset   = tonumber(opts[2])
    tmpcfg.visual       = strToBool(opts[3])
    tmpcfg.firstTime    = strToBool(opts[4])
    tmpcfg.volume       = tonumber(opts[5])
    tmpcfg.iconSize     = tonumber(opts[6])
    tmpcfg.iconPad      = tonumber(opts[7])
    local check         = checkConfig(tmpcfg)
    if check == true then
        log("I", logTag,
            "Options parsed from the UI are good.\
             Updating current game's rally config.")
        for k, v in pairs(tmpcfg) do
            rcfg[k] = v
        end
    else
        log("I", logTag,
            "Options parsed from the UI are bad.\
             Keeping current game's rally config.")
    end
    if (check == true) and (tableSize(rcfg) == 14) then
        log("I", logTag, "Configuration is good.")
        writeCfgToIni()
    else
        log("I", logTag,
            "Problem with options. Not writing to file.")
    end
end

-- Initialization stuff, including UI --
----------------------------------------

-- Loads a custom version of the scenario_waypoints extension
M.onScenarioLoaded = function()
    scenario_waypoints = extensions.scenario_waypointsNoSound
end

-- M.onExtensionLoaded

local function onUiReady()
    if rcfg == nil then return end
    guihooks.trigger("cfgToUI", rcfg)
    guihooks.trigger("infoToUI", rallyInfo)
end

-- Example
--
-- unloading extensions
--
-- local function uiHotlappingAppDestroyed()
--   --log("I",logTag,"uiHotlappingAppDestroyed called.....")
--   if not scenario_scenarios or not (scenario_scenarios and scenario_scenarios.getScenario()) then
--     extensions.unload('core_hotlapping');
--   end
-- end
--
-- Interface --
---------------

M.onRaceStart = onRaceStart
M.onExtensionLoaded = onExtensionLoaded
M.onPreRender = onPreRender
M.onPhysicsPaused = onPhysicsPaused
M.onPhysicsUnpaused = onPhysicsUnpaused
M.onRaceWaypointReached = onRaceWaypointReached
M.onScenarioChange = onScenarioChange
M.onScenarioRestarted = onScenarioRestarted
M.getRally = getRally
M.getCodriver = getCodriver
M.stats = stats
M.dumpDebug = dumpDebug
M.uiToConfig = uiToConfig
M.getPacenoteFile = getPacenoteFile

return M
