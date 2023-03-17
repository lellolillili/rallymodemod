--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local function process(vehicle)
  profilerPushEvent('jbeam/groups.process')

  local groupCounter = 0
  local groups = {}
  for keyEntry, entry in pairs(vehicle) do
    if type(entry) == "table" then
      for rowKey, row in pairs(entry) do
        if type(row) == "table" then
          local newGroups
          local firstIdx
          if row.group ~= nil and type(row.group) == "table" then
            newGroups = {}
            for keyGroup, group in pairs(row.group) do
              if group ~= "" then
                if groups[group] == nil then
                  groups[group] = groupCounter
                  groupCounter = groupCounter + 1
                end
                if firstIdx == nil then
                  firstIdx = groups[group]
                end
                newGroups[groups[group]] = group
              end
            end
          end
          if firstIdx ~= nil then
            row.group = newGroups
            row.firstGroup = firstIdx
          end
        end
      end
    end
  end

  vehicle.groups = groups

  if not tableIsEmpty(vehicle.groups) then
    --log('D', "jbeam.postProcess"," - processed "..tableSize(vehicle.groups).." groups")
    --for k, g in pairs(vehicle.groups) do
    --    log('D', "jbeam.postProcess","  - "..k.." : "..g)
    --end
  end
  profilerPopEvent() -- jbeam/groups.process
end

M.process = process

return M