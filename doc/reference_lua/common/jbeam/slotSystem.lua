--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local min, max = math.min, math.max
local str_byte, str_sub, str_len, str_find = string.byte, string.sub, string.len, string.find

local jbeamIO = require('jbeam/io')

--[[
LUA 5.1 compatible

Ordered Table
keys added will be also be stored in a metatable to recall the insertion oder
metakeys can be seen with for i,k in ( <this>:ipairs()  or ipairs( <this>._korder ) ) do
ipairs( ) is a bit faster

variable names inside __index shouldn't be added, if so you must delete these again to access the metavariable
or change the metavariable names, except for the 'del' command. thats the reason why one cannot change its value
]] --
local function newT(t)
  local mt = {}
  -- set methods
  mt.__index = {
    -- set key order table inside __index for faster lookup
    _korder = {},
    -- traversal of hidden values
    hidden = function() return pairs(mt.__index) end,
    -- traversal of table ordered: returning index, key
    ipairs = function(self) return ipairs(self._korder) end,
    -- traversal of table
    pairs = function(self) return pairs(self) end,
    -- traversal of table ordered: returning key,value
    opairs = function(self)
      local i = 0
      local function iter(self)
        i = i + 1
        local k = self._korder[i]
        if k then
          return k, self[k]
        end
      end
      return iter, self
    end,
    -- to be able to delete entries we must write a delete function
    del = function(self, key)
      if self[key] then
        self[key] = nil
        for i, k in ipairs(self._korder) do
          if k == key then
            table.remove(self._korder, i)
            return
          end
        end
      end
    end,
  }
  -- set new index handling
  mt.__newindex = function(self, k, v)
    if k ~= "del" and v then
      rawset(self, k, v)
      table.insert(self._korder, k)
    end
  end
  return setmetatable(t or {}, mt)
end

local function unifyParts(target, source, level, slotOptions, partPath)
  --log('I', "jbeam.unifyParts",string.rep(" ", level).."* merging part "..source.partName.." ["..source.slotType.."] => "..target.partName.." ["..target.slotType.."] ... ")
  -- walk and merge all sections
  for sectionKey, section in pairs(source) do
    if sectionKey == 'slots' or sectionKey == "information" then
      goto continue
    end

    --log('D', "jbeam.unifyParts"," *** "..tostring(sectionKey).." = "..tostring(section).." ["..type(section).."] -> "..tostring(sectionKey).." = "..tostring(target[sectionKey]).." ["..type(target[sectionKey]).."]")
    if target[sectionKey] == nil then
      -- easy merge
      target[sectionKey] = section

      -- care about the slotoptions if we are first
      if type(section) == "table" and not tableIsDict(section) then
        local localSlotOptions = deepcopy(slotOptions) or {}
        localSlotOptions.partOrigin = source.partName
        --localSlotOptions.partPath = partPath
        --localSlotOptions.partLevel = level
        table.insert(target[sectionKey], 2, localSlotOptions)
        -- now we need to negate the slotoptions out again
        local slotOptionReset = {}
        for k4, v4 in pairs(localSlotOptions) do
          slotOptionReset[k4] = ""
        end
        table.insert(target[sectionKey], slotOptionReset)
      end
    elseif type(target[sectionKey]) == "table" and type(section) == "table" then
      -- append to existing tables
      -- add info where this came from
      local counter = 0
      local localSlotOptions = nil
      for k3, v3 in pairs(section) do
        if tonumber(k3) ~= nil then
          -- if its an index, append if index > 1
          if counter > 0 then
            table.insert(target[sectionKey], v3)
          else
            localSlotOptions = deepcopy(slotOptions) or {}
            localSlotOptions.partOrigin = source.partName
            --localSlotOptions.partPath = partPath
            --localSlotOptions.partLevel = level
            --localSlotOptions.partOrigin = sectionKey .. '/' .. source.partName
            table.insert(target[sectionKey], localSlotOptions)
          end
        else
          --it's a key value pair, check how to proceed with merging potentially existing values
          -- check if magic $ appears in the KEY, if new value is a number (for example "$+MyFoo": 42)
          if type(v3) == "number" and str_byte(k3, 1) == 36 then
            local actualK3 = k3:sub(3) --remove the magic chars at the beginning to get the actual KEY, this can potentially lead to issues if k3 omits the second magic char
            local existingValue = target[sectionKey][actualK3]

            local existingModifierValue = target[sectionKey][k3] --in case we are trying to merge a modifier with another modifier, we need to check if this is the case
            if type(existingModifierValue) == "number" then
              --we need to merge a new modifier with an existing modifier, to do that, set our existing value of actualK3 to the existing value of the raw k3 (including the modifier syntax)
              existingValue = existingModifierValue
              --also overwrite the key to be a modifier again (foo -> $+foo), this way the merged value will be written as a modifier value
              actualK3 = k3
            end

            if type(existingValue) == "number" then --check if old value is also a number (and not null)
              local secondChar = str_byte(k3, 2)

              if secondChar == 43 then -- +/sum
                target[sectionKey][actualK3] = existingValue + v3 --do a sum
              elseif secondChar == 42 then -- * / multiplication
                target[sectionKey][actualK3] = existingValue * v3 -- do a multiplication
              elseif secondChar == 60 then -- < / min
                target[sectionKey][actualK3] = min(existingValue, v3) -- use the min
              elseif secondChar == 62 then -- > / max
                target[sectionKey][actualK3] = max(existingValue, v3) -- use the max
              else
                target[sectionKey][k3] = v3
              end
            else
              --we have special merging, but the initial value is no number (or nil), so just pass the modifier value onto the merged data.
              --This specifically does NOT strip the modifier syntax from k3 so that parent parts still know that this is a modifier
              target[sectionKey][k3] = v3
            end
          else
            --we have a regular value, no special merging, just overwrite it
            target[sectionKey][k3] = v3
          end
        end
        counter = counter + 1
      end
      if localSlotOptions then
        -- now we need to negate the slotoptions out again
        local slotOptionReset = {}
        for k4, v4 in pairs(localSlotOptions) do
          slotOptionReset[k4] = ""
        end
        table.insert(target[sectionKey], slotOptionReset)
      end

    else
      -- just overwrite any basic data
      if sectionKey ~= "slotType" and sectionKey ~= "partName" then
        target[sectionKey] = section
      end
    end
    ::continue::
  end
end

local function fillSlots_rec(ioCtx, userPartConfig, currentPart, level, _slotOptions, chosenParts, activePartsOrig, path, unifyJournal)
  if level > 50 then
    log('E', "jbeam.fillSlots", "* ERROR: over 50 levels of parts, check if parts are self referential")
    return
  end

  if currentPart.slots ~= nil then
    --log('D', "jbeam.fillSlots",string.rep(" ", level).."* found "..(#part.slots-1).." slot(s):")
    for _, slot in ipairs(currentPart.slots) do
      local slotOptions = deepcopy(_slotOptions or {})
      -- the options are only valid for this hierarchy.
      -- if we do not clone/deepcopy it, the childs will leak options to the parents

      local slotId = slot.name or slot.type

      slotOptions = tableMerge(slotOptions, deepcopy(slot))
      -- remove the slot table from the options
      slotOptions.name = nil
      slotOptions.type = nil
      slotOptions.default = nil
      slotOptions.description = nil

      local userPartName = userPartConfig[slotId]
      -- the UI uses 'none' for empty slots, we use ''
      if userPartName == 'none' then userPartName = '' end
      if slot.default == 'none' then slot.default = '' end

      local newPath
      if path ~= '/' then
        newPath = path .. '/' .. slot.type
      else
        newPath = path .. slot.type
      end

      -- user wishes this to be empty, do not try to be overly smart and add defaults, etc
      if userPartName == '' then
        chosenParts[slotId] = ''
        goto continue
      end

      local chosenPart
      local chosenPartName
      if userPartName then
        chosenPartName = userPartName
        chosenPart = jbeamIO.getPart(ioCtx, chosenPartName)
        if not chosenPart then
          log('E', "jbeam.fillSlots", 'slot "' .. tostring(slot.type) .. '" reset to default part "' .. tostring(slot.default) .. '" as the wished part "' .. tostring(chosenPartName) .. '" was not found')
        else
          if chosenPart.slotType ~= slot.type then
            log('E', 'slotSystem', 'Chosen part has wrong slot type. Required is ' .. tostring(slot.type) .. ' provided by part ' .. tostring(chosenPartName) .. ' is ' .. tostring(chosenPart.slotType) .. '. Resetting to default')
            chosenPart = nil
          end
        end
      end

      if slot.default and not chosenPart then
        if slot.default == '' then
          -- default is to be empty
          chosenParts[slotId] = ''
          goto continue
        else
          chosenPartName = slot.default
          chosenPart = jbeamIO.getPart(ioCtx, slot.default)
        end
      end

      if chosenPart then
        if chosenPart.slotType ~= slot.type then
          log('E', 'slotSystem', 'Chosen part has wrong slot type. Required is ' .. tostring(slot.type) .. ' provided by part ' .. tostring(chosenPartName) .. ' is ' .. tostring(chosenPart.slotType) .. '. Emptying slot.')
          goto continue
        end

        newPath = newPath .. '[' .. chosenPart.partName .. ']'

        if slotOptions.coreSlot == true then
          slotOptions.coreSlot = nil
        end
        slotOptions.variables = nil

        --chosenParts[newPath] = chosenPart.partName -- TODO: use full path in the future

        --if chosenParts[slot.type] then
        --  -- TODO: unique slot type name
        --end
        chosenParts[slotId] = chosenPart.partName

        activePartsOrig[chosenPart.partName or slotId] = deepcopy(chosenPart) -- deepcopy is required as chosePart is modified/unified with all sub parts below

        fillSlots_rec(ioCtx, userPartConfig, chosenPart, level + 1, slotOptions, chosenParts, activePartsOrig, newPath, unifyJournal)

        table.insert(unifyJournal, {currentPart, chosenPart, level, slotOptions, newPath, slot})

      else
        if selectedPartName and selectedPartName ~= '' then
          log('E', "jbeam.fillSlots", 'slot "' .. tostring(slot.type) .. '" left empty as part "' .. tostring(selectedPartName) .. '" was not found')
        else
          --log('D', "jbeam.fillSlots", "no suitable part found for type: " .. tostring(slot.type))
        end
      end
      ::continue::
    end
  else
    --('D', "jbeam.fillSlots",string.rep(" ", level+1).."* no slots")
  end
end

local function findParts(ioCtx, vehicleConfig)
  profilerPushEvent('jbeam/slotsystem.findParts')

  local chosenParts = {}
  local activePartsOrig = {} -- key = partname, value = part deep-copied in the original state

  local rootPart = jbeamIO.getPart(ioCtx, vehicleConfig.mainPartName)
  if not rootPart then
    log('E', "jbeam.loadVehicle", "main slot not found, unable to spawn")
    profilerPopEvent() -- jbeam/slotsystem.process
    return
  end

  -- add main part to the part lists
  chosenParts['main'] = vehicleConfig.mainPartName
  activePartsOrig[vehicleConfig.mainPartName] = deepcopy(rootPart)  -- make a copy of the original part

  local unifyJournal = {}
  fillSlots_rec(ioCtx, vehicleConfig.parts or {}, rootPart, 1, nil, chosenParts, activePartsOrig, '/', unifyJournal)

  profilerPopEvent() -- jbeam/slotsystem.process
  return rootPart, unifyJournal, chosenParts, activePartsOrig
end

local function unifyPartJournal(ioCtx, unifyJournal)
  profilerPushEvent('jbeam/slotsystem.unifyParts')
  for i, j in ipairs(unifyJournal) do
    unifyParts(unpack(j))
  end
  profilerPopEvent() -- jbeam/slotsystem.unifyParts
  return true
end

M.findParts = findParts
M.unifyPartJournal = unifyPartJournal

return M
