-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- used to generate some statistics from jbeam files

-- dump(extensions.util_jbeamStats.getStats())

-- jsonWriteFile('jbeam_stats.json', extensions.util_jbeamStats.getStats(), true)

local M = {}

local function getStats()
  local res = {}

  local jbeamFiles = FS:findFiles('/', '*.jbeam', -1, true, false)
  res.totalJbeamFiles = #jbeamFiles

  local sectionCount = {}
  local sectionRowCount = {}
  local totalModifiersCount = 0
  local totalLineCount = 0
  local totalRootParts = 0

  local partCount = 0
  for _, filename in ipairs(jbeamFiles) do
    local content = readFile(filename)
    totalLineCount = totalLineCount + select(2, content:gsub('\n', '\n'))
    if content ~= nil then
        local state, parts = pcall(json.decode, content)
        if state ~= false then
          partCount = partCount + tableSize(parts)

          for partName, part in pairs(parts) do

            if type(part.slotType) == 'string' and part.slotType == 'main' then
              totalRootParts = totalRootParts + 1
            end

            for sectionName, section in pairs(part) do
              if not sectionCount[sectionName] then sectionCount[sectionName] = 0 end
              sectionCount[sectionName] = sectionCount[sectionName] + 1

              if type(section) == 'table' and section[1] then
                local countedRows = 0
                for _, row in pairs(section) do
                  if type(row) == 'table' and row[1] then
                    countedRows = countedRows + 1
                  else
                    totalModifiersCount = totalModifiersCount + 1
                  end
                end
                countedRows = countedRows - 1 -- substract header row :D
                if countedRows > 0 then
                  if not sectionRowCount[sectionName] then sectionRowCount[sectionName] = 0 end
                  sectionRowCount[sectionName] = sectionRowCount[sectionName] + countedRows
                end
              end
            end
          end
        end
    end
  end

  -- transform section count to a sorted table
  local newSectionCount = {}
  for s, c in pairs(sectionCount) do
    table.insert(newSectionCount, {s, c})
  end
  table.sort(newSectionCount, function(a, b) return a[2] > b[2] end)

  res.partCount = partCount
  res.sectionCount = sectionCount
  res.sectionCountOrdered = newSectionCount
  res.sectionRowCount = sectionRowCount
  res.totalLineCount = totalLineCount
  res.totalRootParts = totalRootParts
  res.totalModifiersCount = totalModifiersCount
  return res
end

M.getStats = getStats

return M