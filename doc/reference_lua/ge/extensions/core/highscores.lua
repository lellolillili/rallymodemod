-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Highscore System
local M = {}

local highscoreFile = "settings/highscores.json"
local maxHighScoreCount = 50

local function checkOldHighscoreFile()
  local oldFile = readFile("highscores")
  local newFile = readFile(highscoreFile)
  local hasOld = not (oldFile == nil or oldFile == '')
  local hasNew = not (newFile == nil or newFile == '')
  if hasOld and not hasNew then
    log('I', 'highscores', "Moved old highscores file to settings folder.")
    FS:renameFile("highscores",highscoreFile)
    FS:removeFile('highscores_beautfied')
  end


end

local function getHighscores()
  checkOldHighscoreFile()
  local content = readFile(highscoreFile)
  if content == nil or content == "" then
    return {}
  end
  return jsonDecode(content, highscoreFile)
end

local function setHighscores(scores)
  jsonWriteFile(highscoreFile,scores, true)
end

local function getScenarioHighscores(levelName, scenarioName, configKey)
  local scores = M.getHighscores()

  if scores == nil then return {} end
  scores = scores[levelName]

  if scores == nil then return {} end
  scores = scores[scenarioName]

  if scores == nil then return {} end
  scores = scores[configKey]


  if scores == nil then return {} end
  table.sort(scores, function (a,b) return (a.timeInMillis < b.timeInMillis) end)

  for i,v in ipairs(scores) do
    v.place = i
  end

  return scores
end

-- formats the time given nicely.
local function formatMillis( timeInMillis, addSign )
  if timeInMillis == nil then
    return nil
  end
  if addSign then
    if timeInMillis >= 0 then
      return '+' .. M.formatMillis(timeInMillis,false)
    else
      return '-' .. M.formatMillis(-timeInMillis,false)
    end
  else
    return string.format("%.2d:%.2d.%.3d", (timeInMillis/1000)/60, (timeInMillis/1000)%60, timeInMillis%1000)
  end
end

local function setScenarioHighscores(timeInMillis, vehicleBrand, vehicleName, playerName, levelName, scenarioName, configKey)
  local record = {
    playerName = playerName,
    vehicleBrand = vehicleBrand,
    vehicleName = vehicleName
  }
  return M.setScenarioHighscoresCustom(timeInMillis,record,levelName,scenarioName,configKey)
end

local function setScenarioHighscoresCustom(timeInMillis, record, levelName, scenarioName, configKey)
  local currentHighscores = getScenarioHighscores(levelName,scenarioName,configKey)
  timeInMillis = math.floor(timeInMillis+.5)

  record.detailed = false
  record.timeStamp = os.time()
  record.formattedTimestamp = os.date("!%c",os.time())
  record.timeInMillis = timeInMillis
  record.formattedTime = string.format("%.2d:%.2d.%.3d", (timeInMillis/1000)/60, (timeInMillis/1000)%60, timeInMillis%1000)

  log('I', 'highscores', 'Writing Highscore for '..levelName.."/"..scenarioName.."/"..configKey .. ' = ' .. dumps(record))

  currentHighscores[#currentHighscores+1] = record

  table.sort(currentHighscores, function (a,b) return (a.timeInMillis < b.timeInMillis) end)

  local newIndex = -1
  for k,v in ipairs(currentHighscores) do
    if v == record then newIndex = k end
  end
  if newIndex > maxHighScoreCount then
    return -1
  end
  local newHighscores = {}
  for i = 1,maxHighScoreCount do
    newHighscores[i] = currentHighscores[i]
  end

  local scores = M.getHighscores()
  if scores[levelName] == nil then
    scores[levelName] = {}
  end
  if scores[levelName][scenarioName] == nil then
    scores[levelName][scenarioName] = {}
  end
  if scores[levelName][scenarioName][configKey] == nil then
    scores[levelName][scenarioName][configKey] = {}
  end

  scores[levelName][scenarioName][configKey] = newHighscores
  setHighscores(scores)
  return newIndex
end


M.setHighscores = setHighscores
M.getHighscores = getHighscores
M.setScenarioHighscores = setScenarioHighscores
M.setScenarioHighscoresCustom = setScenarioHighscoresCustom
M.getScenarioHighscores = getScenarioHighscores


return M