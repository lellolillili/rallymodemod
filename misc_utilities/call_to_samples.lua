function dumpTable(table)
  depth = 1
  if (depth > 200) then
    print("Error: Depth > 200 in dumpTable()")
    return
  end
  for k, v in pairs(table) do
    if (type(v) == "table") then
      print(string.rep("  ", depth) .. k .. ":")
      dumpTable(v, depth + 1)
    else
      print(string.rep("  ", depth) .. k .. ": ", v)
    end
  end
end

-- custom iterator for sorting stuff
function spairs(t, order)
  -- collect the keys
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end

  -- if order function given, sort by it by passing the table and keys a, b,
  -- otherwise just sort the keys
  if order then
    table.sort(keys, function(a, b) return order(t, a, b) end)
  else
    table.sort(keys)
  end

  -- return the iterator function
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], t[keys[i]]
    end
  end
end

function TableConcat(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function stringToWords(s)
  if s then
    local words = {}
    for w in s:gmatch("%S+") do table.insert(words, w) end
    return words
  end
end

function lines_from(file)
  local lines = {}
  for line in io.lines(file) do
    if (trim(line) ~= "empty") then
      lines[#lines + 1] = trim(line)
    end
  end
  return lines
end

function updateCurrentSentence(phrase)
  if phrase ~= nil and phrase ~= "" then
    table.insert(currentSentence, trim(phrase))
    wordcount = wordcount + #(stringToWords(trim(phrase)))
  else
    log("E", logTag, "Trying to apppend an empty phrase.")
  end
end

function getPhrasesFromWords(words, list)
  local phrase = ""
  local match = ""
  for i, v in ipairs(words) do
    phrase = phrase .. v .. ' '
    -- print(phrase)
    if list[trim(phrase)] then
      match = phrase
      -- print("match!")
    end
  end
  for i = 1, #(stringToWords(match)), 1 do
    table.remove(words, 1)
  end
  if match == "" then
    return
  end
  updateCurrentSentence(match)
  getPhrasesFromWords(words, list)
end

currentSentence = {}
wordcount = 0

corners = { "L0M", "L0E", "L0P", "R0M", "R0E", "R0P", "L1M", "L1E", "L1P", "R1M",
  "R1E", "R1P", "L2M", "L2E", "L2P", "R2M", "R2E", "R2P", "L3M", "L3E", "L3P",
  "R3M", "R3E", "R3P", "L4M", "L4E", "L4P", "R4M", "R4E", "R4P", "L5M", "L5E",
  "L5P", "R5M", "R5E", "R5P", "L6M", "L6E", "L6P", "R6M", "R6E", "R6P", "RS",
  "LS" }
-- create an indexed table for convenience
corner_list_indexed = { _ = "balls" }
for _, v in ipairs(corners) do
  corner_list_indexed[v] = "balls"
end

-- codriver is in the shell script, not here
local params = { ... }
codriver_dir = params[1]

-- all the available audio samples
samples = '/tmp/codriver'
sample_list = lines_from(samples)
-- create an indexed table for convenience
sample_list_indexed = { _ = "balls" }
for _, v in ipairs(sample_list) do
  sample_list_indexed[v] = "balls"
end

-- all used calls in all prefabs
calls_file = '/tmp/calls'
calls = lines_from(calls_file)

-- we add all the substitutions we have specified
codriver_ini_file = lines_from(codriver_dir .. "/codriver.ini")
substitutions = {}
for _, v in pairs(codriver_ini_file) do
  currentSentence = {}
  wordcount = 0
  if (v:find("^#") == nil) then
    if (v:find("%>%>%>")) then
      key, sub = v:match("^(.*)%>%>%>(.*)$")
      key = trim(key)
      sub = trim(sub)
      table.insert(substitutions, key)
    end
  end
end

codriver = {}
for _, v in pairs(corners) do
  table.insert(sample_list, v)
end

sample_list = TableConcat(sample_list, substitutions)

for _, v in ipairs(sample_list) do
  codriver[v] = "balls"
end

-- print("sample_list:")
-- dumpTable(sample_list)

-- print("substitutions:")
-- dumpTable(substitutions)

-- print("codriver:")
-- dumpTable(codriver)

used_samples = {}
used_corners = {}

for _, phr in ipairs(calls) do
  currentSentence = {}
  wordcount = 0
  -- print("Phrase: " .. phr)
  getPhrasesFromWords(stringToWords(phr), codriver)
  -- print("Matches: " .. phr)
  if wordcount ~= #(stringToWords(phr)) then
    print("(ERRORS)")
    print("currentSentence:")
    dumpTable(currentSentence)
    print("Phrase: " .. phr)
  else
    for _, v in ipairs(currentSentence) do
      if corner_list_indexed[v] then
        if used_corners[v] then
          used_corners[v] = used_corners[v] + 1
        else
          used_corners[v] = 1
        end
      elseif used_samples[v] then
        used_samples[v] = used_samples[v] + 1
      else
        used_samples[v] = 1
      end
    end
  end
end

-- Uncomment for a list of used corners and other calls
--
-- print("not corners")
-- for k, v in spairs(used_samples, function(t, a, b) return t[b] < t[a] end) do
--   print(k .. ": " .. v)
-- end

-- print("corners")
-- for k, v in spairs(used_corners, function(t, a, b) return t[b] < t[a] end) do
--   print(k .. ": " .. v)
-- end
