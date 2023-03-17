-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}

local earlyMatchBonus = 0.5
local function matchStringScore(name, match, ignoreEarly)
  local pos1 = 1
  local pos2 = 0
  local labelLower = name:lower()
  local highlightLower = match:lower()
  local highlightLowerLen = string.len(highlightLower) - 1
  local matchedCharCount = 0
  local firstMatchDistance = nil
  for i = 0, 6 do -- up to 6 matches overall ...
    pos2 = labelLower:find(highlightLower, pos1, true)

    -- no match found? end search
    if not pos2 then break end

    --store the first distance for priorotizing early finds
    if not firstMatchDistance then firstMatchDistance = pos2-1 end

    matchedCharCount = matchedCharCount + highlightLowerLen+1
    pos1 = pos2 + highlightLowerLen+1
  end
  local score = (matchedCharCount / #labelLower)

  if not ignoreEarly and  firstMatchDistance and #labelLower > #match then
    local firstMatchScore = 1-(firstMatchDistance/(#labelLower - #match))
    score = score * (1-earlyMatchBonus) + firstMatchScore * earlyMatchBonus
  end
  return score
end
C.matchStringScore = matchStringScore

local function defaultScoringFunction(element, match)
  local score = matchStringScore(element.name, match)
  return score
end

local function defaultSameScoreResolvingFunction(a,b)
  return a.name < b.name
end

-- initializes stuff for the helper.
function C:init()
  self.scoringFunction = defaultScoringFunction
  self.sameScoreResolvingFunction = defaultSameScoreResolvingFunction
  self.frecencyWeight = 0.5
end


function C:setScoringFunction(fun)
  self.scoringFunction = fun
end

function C:setSameScoreResolvingFunction(fun)
  self.sameScoreResolvingFunction = fun
end

function C:startSearch(matchString)
  self.results = {}
  self.matchString = matchString
  self.undoFrecency = nil
end

function C:queryElement(elem, scoringFunction)
  local score =  (scoringFunction or self.scoringFunction)(elem, self.matchString)
  elem.score = score
  if score > 0 then
    table.insert(self.results, elem)
  end
end

function C:finishSearch()
  local sortingFunction = function(a,b)
    if a.finalScore == b.finalScore then
      return self.sameScoreResolvingFunction(a,b)
    else
      return a.finalScore > b.finalScore
    end
  end
  for _, result in ipairs(self.results) do
    result.frecency = self:getFrecencyScore(result.frecencyId)
    result.finalScore = result.score * (1-self.frecencyWeight) + result.frecency * self.frecencyWeight
  end

  table.sort(self.results, sortingFunction)
  return self.results
end

function C:setFrecencyData(frecencyData)
  self.frecency = frecencyData
end

function C:getFrecencyData()
  return self.frecency
end

local undoTime = 10 -- 10s auto undo for frecency
function C:updateFrecencyEntry(fId)
  if not fId then return end
  self.frecency = self.frecency or {}
  if self.undoFrecency then
    if os.time() - self.undoFrecency.time <= undoTime then
      self.frecency[self.undoFrecency.fId] = self.undoFrecency.value
      log("D","","Undid a frecency update: " .. dumps(self.undoFrecency))
    end
  end
  self.undoFrecency = {
    fId = fId,
    value = self.frecency[fId],
    time = os.time()
  }
  self.frecency[fId] = os.time()
end

local recencyHalfTime = 60*60*24
local recencyExp = 1.25
function C:getFrecencyScore(fId)
  if not self.frecency or not self.frecency[fId] then return 0 end

  local diff = math.max(0,(os.time() - self.frecency[fId]))
  local e = diff / recencyHalfTime
  return 1/math.pow(recencyExp, e)
end


function C:beginSearchableSimpleCombo(im, string_label, string_preview_value, elementsAsList, ImGuiComboFlags_flags)
  local ret = nil
  string_preview_value = string_preview_value or "(None Selected)"
  if im.BeginCombo("##" .. string_label.."bigCombo", string_preview_value, ImGuiComboFlags_flags) then
    if not self.searchText then self.searchText = im.ArrayChar(128) end
    if im.InputText("##searchInProject", self.searchText, nil, im.InputTextFlags_AutoSelectAll) then
      self.searchChanged = true
    end
    im.SameLine()
    if im.Button("X") then
      self.searchChanged = true
      self.searchText = im.ArrayChar(128)
    end


    if self.searchChanged or not self.filtered then
      --self.search:setFrecencyData({})
      self:startSearch(ffi.string(self.searchText))
    --    self.search:setSameScoreResolvingFunction(sortFun)
      for _, elem in ipairs(elementsAsList) do
        self:queryElement({
          id = elem,
          name = elem,
          info = elem,
          frecencyId = elem,
        })
      end
      self.filtered = self:finishSearch()
      self.searchChanged = false
    end

    im.BeginChild1("##"..string_label.."childCombo", im.ImVec2(im.GetContentRegionAvailWidth(), 140 * editor.getPreference("ui.general.scale")) )
    for _, result in ipairs(self.filtered) do
      if self.matchString ~= '' then
        im.HighlightSelectable(result.id, self.matchString)
      else
        im.Selectable1(result.id)
      end

      if im.IsItemClicked() then
        ret = result.id
        im.CloseCurrentPopup()
      end
    end
    im.EndChild()
    im.EndCombo()
  else
    self.filtered = nil
  end
  im.tooltip(string_preview_value)
  if ret then
  end
  return ret

end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end