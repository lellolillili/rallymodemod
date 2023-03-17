--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local min, max = math.min, math.max
local str_byte, str_sub, str_len, str_find = string.byte, string.sub, string.len, string.find

local jbeamUtils = require("jbeam/utils")
local particles = require("particles")

local materials, materialsMap = particles.getMaterialsParticlesTable()

-- these are defined in C, do not change the values
local NORMALTYPE = 0
local NODE_FIXED = 1
local NONCOLLIDABLE = 2
local BEAM_ANISOTROPIC = 1
local BEAM_BOUNDED = 2
local BEAM_PRESSURED = 3
local BEAM_LBEAM = 4
local BEAM_HYDRO = 6
local BEAM_SUPPORT = 7


local specialVals = {FLT_MAX = math.huge, MINUS_FLT_MAX = -math.huge}
local typeIds = {
  NORMAL = NORMALTYPE,
  HYDRO = BEAM_HYDRO,
  ANISOTROPIC = BEAM_ANISOTROPIC,
  TIRESIDE = BEAM_ANISOTROPIC,
  BOUNDED = BEAM_BOUNDED,
  PRESSURED = BEAM_PRESSURED,
  SUPPORT = BEAM_SUPPORT,
  LBEAM = BEAM_LBEAM,
  FIXED = NODE_FIXED,
  NONCOLLIDABLE = NONCOLLIDABLE,
  SIGNAL_LEFT = 1,   -- GFX_SIGNAL_LEFT
  SIGNAL_RIGHT = 2,  -- GFX_SIGNAL_RIGHT
  HEADLIGHT = 4,     -- GFX_HEADLIGHT
  BRAKELIGHT = 8,    -- GFX_BRAKELIGHT
  RUNNINGLIGHT = 16, -- GFX_RUNNINGLIGHT
  REVERSELIGHT = 32, -- GFX_REVERSELIGHT
}

local function replaceSpecialValues(val)
  local typeval = type(val)
  if typeval == "table" then
    -- recursive replace
    for k, v in pairs(val) do
      val[k] = replaceSpecialValues(v)
    end
    return val
  end
  if typeval ~= "string" then
    -- only replace strings
    return val
  end

  if specialVals[val] then return specialVals[val] end

  if str_find(val, '|', 1, true) then
    local parts = split(val, "|", 999)
    local ival = 0
    for i = 2, #parts do
      local valuePart = parts[i]
      -- is it a node material?
      if valuePart:sub(1,3) == "NM_" then
        ival = particles.getMaterialIDByName(materials, valuePart:sub(4))
        --log('D', "jbeam.replaceSpecialValues", "replaced "..valuePart.." with "..ival)
      end
      ival = bit.bor(ival, typeIds[valuePart] or 0)
    end
    return ival
  end
  return val
end

local function processTableWithSchemaDestructive(jbeamTable, newList, inputOptions)
  -- its a list, so a table for us. Verify that the first row is the header
  local header = jbeamTable[1]
  if type(header) ~= "table" then
    log('W', "", "*** Invalid table header: " .. dumpsz(header, 2))
    return -1
  end
  if tableIsDict(header) then
    log('W', "", "*** Invalid table header, must be a list, not a dict: "..dumps(header))
    return -1
  end

  local headerSize = #header
  local headerSize1 = headerSize + 1
  local newListSize = 0
  local localOptions = replaceSpecialValues(deepcopy(inputOptions)) or {}

  -- remove the header from the data, as we dont need it anymore
  table.remove(jbeamTable, 1)
  --log('D', ""header size: "..headerSize)

  -- walk the list entries
  for rowKey, rowValue in ipairs(jbeamTable) do
    if type(rowValue) ~= "table" then
      log('W', "", "*** Invalid table row: "..dumps(rowValue))
      return -1
    end
    if tableIsDict(rowValue) then
      -- case where options is a dict on its own, filling a whole line
      tableMerge(localOptions, replaceSpecialValues(rowValue))
      localOptions.__astNodeIdx = nil
    else
      local newID = rowKey
      --log('D', "" *** "..tostring(rowKey).." = "..tostring(rowValue).." ["..type(rowValue).."]")

      -- allow last type to be the options always
      if #rowValue > headerSize + 1 then -- and type(rowValue[#rowValue]) ~= "table" then
        log('W', "", "*** Invalid table header, must be as long as all table cells (plus one additional options column):")
        log('W', "", "*** Table header: "..dumps(header))
        log('W', "", "*** Mismatched row: "..dumps(rowValue))
        return -1
      end

      -- walk the table row
      -- replace row: reassociate the header colums as keys to the row cells
      local newRow = deepcopy(localOptions)

      -- check if inline options are provided, merge them then
      for rk = headerSize1, #rowValue do
        local rv = rowValue[rk]
        if type(rv) == 'table' and tableIsDict(rv) and #rowValue > headerSize then
          tableMerge(newRow, replaceSpecialValues(rv))
          -- remove the options
          rowValue[rk] = nil -- remove them for now
          header[rk] = "options" -- for fixing some code below - let it know those are the options
          break
        end
      end
      newRow.__astNodeIdx = rowValue.__astNodeIdx

      -- now care about the rest
      for rk,rv in ipairs(rowValue) do
        --log('D', "jbeam.", "### "..header[rk].."//"..tostring(newRow[header[rk]]))
        -- if there is a local option named like a row key, use the option instead
        -- copy things
        if header[rk] == nil then
          log('E', "", "*** unable to parse row, header for entry is missing: ")
          log('E', "", "*** header: "..dumps(header) .. ' missing key: ' .. tostring(rk) .. ' -- is the section header too short?')
          log('E', "", "*** row: "..dumps(rowValue))
        else
          newRow[header[rk]] = replaceSpecialValues(rv)
        end
      end

      if newRow.id ~= nil then
        newID = newRow.id
        newRow.name = newRow.id -- this keeps the name for debugging or alike
        newRow.id = nil
      end

      -- done with that row
      newList[newID] = newRow
      newListSize = newListSize + 1
    end
  end

  newList.__astNodeIdx = jbeamTable.__astNodeIdx

  return newListSize
end

local function process(vehicle, processSlotsTable)
  profilerPushEvent('jbeam/tableSchema.process')

  --log('D', "","- Preparing jbeam")
  -- check for nodes key
  vehicle.maxIDs = {}
  vehicle.validTables = {}
  vehicle.beams = vehicle.beams or {}

  -- create empty options
  vehicle.options = vehicle.options or {}
  -- walk everything and look for options
  for keyEntry, entry in pairs(vehicle) do
    if type(entry) ~= "table" then
      -- seems to be a option, add it to the vehicle options
      vehicle.options[keyEntry] = entry
      vehicle[keyEntry] = nil
    end
  end

  -- then walk all (keys) / entries of that vehicle
  for keyEntry, entry in pairs(vehicle) do
    -- verify key names to be proper formatted
    --[[
    if type(entry) == "table" and tableIsDict(entry) then
      log('D', ""," ** "..tostring(keyEntry).." = [DICT] #" ..tableSize(entry))
    elseif type(entry) == "table" and not tableIsDict(entry) then
      log('D', ""," ** "..tostring(keyEntry).." = [LIST] #"..tableSize(entry))
    else
      log('D', ""," ** "..tostring(keyEntry).." = "..tostring(entry).." ["..type(entry).."]")
    end
    ]]--

    -- verify element name
    if string.match(keyEntry, "^([a-zA-Z_]+[a-zA-Z0-9_]*)$") == nil then
      log('E', "","*** Invalid attribute name '"..keyEntry.."'")
      profilerPopEvent() -- jbeam/tableSchema.process
      return false
    end

    -- init max
    vehicle.maxIDs[keyEntry] = 0
    --log('D', ""," ** creating max val "..tostring(keyEntry).." = "..tostring(vehicle.maxIDs[keyEntry]))
    -- then walk the tables
    if type(entry) == "table" and not tableIsDict(entry) and jbeamUtils.ignoreSections[keyEntry] == nil and not tableIsEmpty(entry) then
      if tableIsDict(entry) then
        -- ENTRY DICTS TO BE WRITTEN
      else
        if keyEntry == 'slots' and not processSlotsTable then
          -- slots are preprocessed in the io module
          vehicle.validTables[keyEntry] = true
        else
          if not vehicle.validTables[keyEntry] then
            local newList = {}
            local newListSize = processTableWithSchemaDestructive(entry, newList, vehicle.options)
            if newListSize < 0 then
              log('E', "", "section invalid: "..tostring(keyEntry) .. ' = ' .. dumpsz(entry, 2))
            elseif newListSize > 0 then
              -- this was a correct able, record that so we do not process twice
              vehicle.validTables[keyEntry] = true
            end
            vehicle[keyEntry] = newList
            --log('D', ""," - "..tostring(newListSize).." "..tostring(keyEntry))
          end
        end
      end
    end
  end
  profilerPopEvent() -- jbeam/tableSchema.process
  return true
end

M.process = process
M.processTableWithSchemaDestructive = processTableWithSchemaDestructive

return M