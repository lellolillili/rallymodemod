--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local min, max = math.min, math.max
local str_byte, str_sub, str_len, str_find = string.byte, string.sub, string.len, string.find

local optionalLinks = {['torqueArm:'] = 1,['torqueArm2:'] = 1, ['torqueCoupling:'] = 1, ['torqueCouple:'] = 1, ['nodeArm:'] = 1, ['nodeCoupling:'] = 1, ['nodeCouple:'] = 1}

local function prepareLinksDestructive(vehicle)
  profilerPushEvent('jbeam/links.prepareLinksDestructive')
  local links = {}
  local linksidx = 1
  local entrykeys = {}

  for keyEntry, entry in pairs(vehicle) do
    if type(entry) == "table" then
      local keysLen = 0
      for k, _ in pairs(entry) do
        keysLen = keysLen + 1
        entrykeys[keysLen] = k
      end
      for i = 1, keysLen do
        local rowKey = entrykeys[i]
        local rowValue = entry[rowKey]
        -- Check for links of the form: "link:section":[1,2,3,4]
        if type(rowValue) == "table" then
          if str_find(rowKey, ':', 1, true) then
            -- this is for special cases like this: { "torqueReactionNodes:", { "e1l", "e2l", "e4r" } }
            local parts = split(rowKey, ":", 2)
            if #parts == 2 then
              local sectionName
              if parts[2] == "" then
                sectionName = "nodes"
              else
                sectionName = parts[2]
              end

              if vehicle[sectionName] ~= nil then
                for tKey, tValue in ipairs(rowValue) do
                  if vehicle[sectionName][tValue] ~= nil then
                    links[linksidx] = rowValue
                    links[linksidx+1] = tKey
                    links[linksidx+2] = vehicle[sectionName][tValue]
                    linksidx = linksidx + 3
                  else
                    if not rowValue.optional then
                      log('W', "jbeam.prepareLinksDestructive", "link target not found: " .. keyEntry .. "/" .. rowKey .. " > ".. sectionName.."/"..tValue .. " id1:" .. tostring(rowValue.id1) .. ", id2:" .. tostring(rowValue.id2) .. ", partOrigin:" .. tostring(rowValue.partOrigin) .. " - DATA DISCARDED".. (rowValue.id1 == nil and rowValue.id2 == nil and rowValue.partOrigin == nil and ": "..dumps(rowValue) or ""))
                    else
                      --log('D', "jbeam.prepareLinksDestructive", "optional link discarded: " .. keyEntry .. "/" .. rowKey .. " > "..sectionName.."/"..tValue .. ' - OPTIONAL DATA DISCARDED')
                    end
                    entry[rowKey] = nil
                    break
                  end
                end
                entry[parts[1]..'_'..sectionName] = rowValue
                entry[rowKey] = nil
              end
            end
          else
            for cellKey,cellValue in pairs(rowValue) do
              --log('D', "jbeam.prepareLinksDestructive"," * key:"..tostring(cellKey).." = "..tostring(cellValue)..".")
              if str_find(cellKey, ':', 1, true) then
                local parts = split(cellKey, ":", 3)
                if #parts == 2 then
                  if string.match(parts[1], '%[.*%]') == nil then
                    -- its a link
                    -- default, resolve to nodes
                    local sectionName
                    if parts[2] ~= "" then
                      sectionName = parts[2]
                    else
                      sectionName = "nodes"
                    end

                    if vehicle[sectionName] ~= nil then
                      if type(cellValue) == "table" then
                        -- this is  for special cases like this:
                        --[[
                            "rails":{
                              "leaf_RL":{
                                "looped":false,
                                "broken:":{},
                                "capped":true,
                                "links:":[
                                  "axsl",
                                  "lf3l"
                                ]
                              },
                        --]]
                        for tKey, tValue in ipairs(cellValue) do
                          if vehicle[sectionName][tValue] ~= nil then
                            links[linksidx] = cellValue
                            links[linksidx+1] = tKey
                            links[linksidx+2] = vehicle[sectionName][tValue]
                            linksidx = linksidx + 3
                          else
                            if not rowValue.optional then
                              log('W', "jbeam.prepareLinksDestructive", "link target not found: " .. keyEntry .. "/" .. rowKey .. " > ".. sectionName.."/"..tValue .. " id1:" .. tostring(rowValue.id1) .. ", id2:" .. tostring(rowValue.id2) .. ", partOrigin: " .. tostring(rowValue.partOrigin) .. " - DATA DISCARDED".. (rowValue.id1 == nil and rowValue.id2 == nil and rowValue.partOrigin == nil and ": "..dumps(rowValue) or ""))
                            else
                              --log('D', "jbeam.prepareLinksDestructive", "optional link discarded: " .. keyEntry .. "/" .. rowKey .. " > "..sectionName.."/"..tValue .. ' - OPTIONAL DATA DISCARDED')
                            end
                            entry[rowKey] = nil
                            break
                          end
                        end
                      else
                        -- this is the default case, normal table row
                        if vehicle[sectionName][cellValue] ~= nil then
                          links[linksidx] = rowValue
                          links[linksidx+1] = parts[1]
                          links[linksidx+2] = vehicle[sectionName][cellValue]
                          linksidx = linksidx + 3

                          rowValue[cellKey] = nil
                        else
                          if optionalLinks[cellKey] == nil then
                            if not rowValue.optional then
                              log('W', "jbeam.prepareLinksDestructive", "link target not found: " .. keyEntry .. "/" .. rowKey .. " > ".. sectionName.."/"..cellValue .. " id1:" .. tostring(rowValue.id1) .. ", id2:" .. tostring(rowValue.id2) .. ", partOrigin: " .. tostring(rowValue.partOrigin) .. " - DATA DISCARDED".. (rowValue.id1 == nil and rowValue.id2 == nil and rowValue.partOrigin == nil and ": "..dumps(rowValue) or ""))
                            else
                              --log('D', "jbeam.prepareLinksDestructive", "optional link discarded: " .. keyEntry .. "/" .. rowKey .. " > "..sectionName.."/"..cellValue .. ' - OPTIONAL DATA DISCARDED')
                            end
                            entry[rowKey] = nil
                            break
                          end
                        end
                      end
                    end
                    -- else
                    --     local sectionName = "nodes"
                    --     if parts[2] ~= "" then
                    --         sectionName = parts[2]
                    --     end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  profilerPopEvent() -- jbeam/links.prepareLinksDestructive
  return links
end

local function resolveLinks(vehicle, links)
  profilerPushEvent('jbeam/links.resolveLinks')
  for i = 1, #links, 3 do
    links[i][links[i+1]] = links[i+2].cid
  end

  -- walk all sections
  for sectionName, section in pairs(vehicle) do
    if type(section) == "table" then
      -- walk all rows
      local newSection = {}
      for rowKey, rowValue in pairs(section) do
        if vehicle.validTables[sectionName] == true and rowValue.cid then
          newSection[rowValue.cid] = rowValue
        else
          newSection[rowKey] = rowValue
        end
      end
      vehicle[sectionName] = newSection
    end
  end
  profilerPopEvent() -- jbeam/links.resolveLinks
  return true
end

local function resolveGroupLinks(vehicle)
  profilerPushEvent('jbeam/links.resolveGroupLinks')
  local journal = {}
  local groupindex = {}
  local table_clear = table.clear
  -- walk all sections
  for _, entry in pairs(vehicle) do
    -- walk all vehicle sections
    if type(entry) == "table" then
      for _, rowValue in pairs(entry) do
        if type(rowValue) == "table" then
          -- walk all cells
          for cellKey, groupvals in pairs(rowValue) do
            if str_byte(cellKey,1) == 91 then -- [
              local groupname
              local sectioname
              groupname, sectioname = string.match(cellKey, '%[(.*)%]:(.*)')
              if groupname then
                if type(groupvals) == 'string' then
                  groupvals = {groupvals}
                end
                local cids = {}
                table_clear(groupindex)
                -- Create groupvals index
                for _, gvalname in pairs(groupvals) do
                  groupindex[gvalname] = 1
                end
                -- walk all specified groups
                if sectioname == '' then sectioname = "nodes" end
                for _, val in pairs(vehicle[sectioname]) do
                  local vgn = val[groupname]
                  if vgn ~= nil then
                    local typevgn = type(vgn)
                    if typevgn == 'string' then
                      if groupindex[vgn] ~= nil then
                        val[groupname] = {vgn}
                        table.insert(cids, val.cid)
                      end
                    elseif typevgn == 'table' then
                      for _, gvalname in pairs(vgn) do
                        if groupindex[gvalname] ~= nil then
                          table.insert(cids, val.cid)
                          break
                        end
                      end
                    end
                  end
                end
                table.insert(journal, {rowValue, '_'..groupname..'_'..sectioname, cids})
              end
            end
          end
        end
      end
    end
  end

  -- play journal
  for _, val in ipairs(journal) do
    val[1][val[2]] = val[3]
  end
  profilerPopEvent() -- jbeam/links.resolveGroupLinks
  return true
end


M.prepareLinksDestructive = prepareLinksDestructive
M.resolveLinks = resolveLinks
M.resolveGroupLinks = resolveGroupLinks

return M