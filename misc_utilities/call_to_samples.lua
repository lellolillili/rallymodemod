corners = {"L0M", "L0E", "L0P", "R0M", "R0E", "R0P", "L1M", "L1E", "L1P", "R1M",
"R1E", "R1P", "L2M", "L2E", "L2P", "R2M", "R2E", "R2P", "L3M", "L3E", "L3P",
"R3M", "R3E", "R3P", "L4M", "L4E", "L4P", "R4M", "R4E", "R4P", "L5M", "L5E",
"L5P", "R5M", "R5E", "R5P", "L6M", "L6E", "L6P", "R6M", "R6E", "R6P", "RS",
"LS"}

function dumpTable(table)
  depth = 1
  if (depth > 200) then
    print("Error: Depth > 200 in dumpTable()")
    return
  end
  for k,v in pairs(table) do
    if (type(v) == "table") then
      print(string.rep("  ", depth)..k..":")
      dumpTable(v, depth+1)
    else
      print(string.rep("  ", depth)..k..": ",v)
    end
  end
end

function trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

currentSentence={}
wordcount=0
function updateCurrentSentence(phrase)
    if phrase ~= nil and phrase ~= "" then
        table.insert(currentSentence, trim(phrase))
        wordcount=wordcount+#(stringToWords(trim(phrase)))
    else
        log("E", logTag, "Trying to apppend an empty phrase.")
    end
end

function stringToWords(s)
    if s then
        local words = {}
        for w in s:gmatch("%S+") do table.insert(words, w) end
        return words
    end
end

function getPhrasesFromWords(words)
    local phrase = ""
    local match = ""
    for i, v in ipairs(words) do
        phrase = phrase .. v .. ' '
        -- print(phrase)
        if codriver[trim(phrase)] then
            match = phrase
            -- print("match!")
        end
    end
    for i=1, #(stringToWords(match)), 1 do
        table.remove(words,1)
    end
    if match == "" then
        return
    end
    updateCurrentSentence(match)
    getPhrasesFromWords(words)
end


function lines_from(file)
  local lines = {}
  for line in io.lines(file) do
    if (trim(line)~="empty") then
      lines[#lines + 1] = trim(line)
    end
  end
  return lines
end

codriver_file = '/tmp/codriver'
calls_file = '/tmp/calls'
samplelist = lines_from(codriver_file)
calls = lines_from(calls_file)

codriver = {}
for _, v in pairs(corners) do
  table.insert(samplelist, v)
end

for _, v in ipairs(samplelist) do
  codriver[v]="balls"
end

-- print("codriver:")
-- dumpTable(codriver)

-- print("all calls:")
-- dumpTable(calls)

-- print("codriver:")

print("output:")
for _, phr in ipairs(calls) do
  currentSentence={}
  wordcount=0
  -- print("Phrase: " .. phr)
  getPhrasesFromWords(stringToWords(phr))
  -- print("Matches: " .. phr)
  if wordcount ~= #(stringToWords(phr)) then
    print("(ERRORS:)")
    dumpTable(currentSentence)
    print("Phrase: " .. phr)
    print("Matches: " .. phr)
  end
end
