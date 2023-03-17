-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'inventory'

M.itemsTable = {}
local function existItem(entryTable, valueObj)
  -- log('I', logTag, 'existItem called ... type(entryTable) = '..type(entryTable) ..'  type(valueObj) = '..type(valueObj))
  -- dump(entryTable)
  -- dump(valueObj)
  local found
  for _,item in ipairs(entryTable) do
  found = true
    for k,v in pairs(item) do
      found = found and valueObj[k] == v
    end

    if found then
      -- log('I', logTag, 'Found duplicate!')
      goto continue
    end
  end
  ::continue::
  return found
end

local function addItem(itemType, valueObj)
  log('I', logTag, 'addItem called... itemType '..tostring(itemType)..' '..type(valueObj))

  local valueObjType = type(valueObj)

  if itemType and valueObj then
    itemType = string.upper(itemType)
    local itemsTable = M.itemsTable
    if not itemsTable[itemType] then
      if valueObjType == 'table' then
        itemsTable[itemType] = {}
      else
        itemsTable[itemType] = 0
      end
    end

    if valueObjType == 'table' then
      local entry = itemsTable[itemType]
      if not existItem(entry, valueObj) then
        table.insert(entry, valueObj)
      end
    else
      itemsTable[itemType] = itemsTable[itemType] + valueObj
    end
  end

  -- dump(itemsTable)
end

local function removeItem(itemType, valueObj)
  log('I', logTag, 'removeItem called... itemType '..tostring(itemType)..' '..type(valueObj))

  local valueObjType = type(valueObj)

  if itemType and valueObj then
    itemType = string.upper(itemType)
    local itemsTable = M.itemsTable
    if itemsTable[itemType] then
      if valueObjType == 'table' then
        local entryTable = itemsTable[itemType]
        for index,entry in ipairs(entryTable) do
          if entry.model == valueObj.model and entry.config == valueObj.config then
            table.remove(entryTable, index)
            goto continue
          end
        end
      else
        itemsTable[itemType] = itemsTable[itemType] - valueObj
      end
    end
  end
  ::continue::
  -- log('I', logTag, 'after removeItem')
  -- dump(M.itemsTable)
end

local function getItem(itemType, itemId)
  local itemEntry = M.itemsTable[itemType]
  local result = nil
  if type(itemEntry) == 'table' then
    for _,v in ipairs(itemEntry) do
      if v.itemId == itemId then
        result = deepcopy(v)
      end
    end
  else
    result = itemEntry or 0
  end

  return result
end

local function getItemList(itemType)
  local itemsTable = M.itemsTable
  itemsTable[itemType] = itemsTable[itemType] or {}
  local result = deepcopy(itemsTable[itemType])
  return result
end

local function processTable(operation, key, entry)
  -- log('I', logTag, 'processTable called...   operation: '..tostring(operation)..'  key: '..key)
  -- dump(entry)

  local opFunc
  if operation == 'remove' then
    opFunc = removeItem
  else
    opFunc = addItem
  end

  local itemType = '$$$_'..string.upper(key)
  if type(entry) == 'table' then
    for _,item in ipairs(entry) do
      opFunc(itemType, item)
    end
  else
      opFunc(itemType, entry)
  end
end

local function processOnEvent(onEventData, earnedMedal)
--[[
  OnEventData may contain keys for operations or items to assign directly
  Currently we have only Operations keys 'add' and 'remove'
  Add operation is a direct assignment from the value it points to
  Remove operation contains multiple tables. The value of the remove operation is another dictionary.
    the dictionary has keys for each possible medal - 'bronze', 'silver' and 'gold'. The value of any of these keys
    is the table to use for the remove operation. The one to use is determined by the 'earnedMedal' passed in.
    Examples:
      In this example, when the user wins a gold medal, the pickup would be removed from their inventory
        and 2500 units of currency
      "remove":{
        "gold": {
          "vehicles": [{"model":"pickup","config": "v8_4wd_rusty"}],
          "money" : 2500
        },
        "silver": {
        },
        "bronze": {
        }
      },

      In this example, the end medal does not matter, the pickup and money will always be removed
      "remove":{
          "vehicles": [{"model":"pickup","config": "v8_4wd_rusty"}],
          "money" : 2500
      },
  ]]
  log('I', logTag, 'processOnEvent called...   earnedMedal: '..tostring(earnedMedal))

  if onEventData then
    for key,entry in pairs(onEventData) do
      if key == 'remove' then
        for subKey,data in pairs(entry) do
          if subKey == 'gold' or subKey == 'silver' or subKey == 'bronze' then
            if earnedMedal and subKey == earnedMedal then
              for invType,value in pairs(data) do
                processTable('remove', invType, value)
              end
            end
          else
            processTable('remove', subKey, data)
          end
        end
      else
        processTable('add', key, entry)
      end
    end
  end
end

local function onSaveCampaign(saveCallback)
  local data = deepcopy(M.itemsTable)
  saveCallback(M.__globalAlias__, data)
end

local function onResumeCampaign(campaignInProgress, data)
  log('I', logTag, 'resume campaign called.....')
  M.itemsTable = data
end

local function onSerialize()
  -- log('D', logTag, 'onSerialize called...')
  local data = deepcopy(M.itemsTable)
  return data
end

local function onDeserialized(data)
  -- dump(data)
end

M.addItem           = addItem
M.removeItem        = removeItem
M.getItem           = getItem
M.getItemList       = getItemList
M.processOnEvent    = processOnEvent
M.onResumeCampaign  = onResumeCampaign
M.onSaveCampaign    = onSaveCampaign
M.onSerialize       = onSerialize
M.onDeserialized    = onDeserialized
return M

-- core_inventory.addItem("$$$_MONEY", 200)
-- core_inventory.addItem("$$$_PART", {name='etk800', config='etk800_m'})
-- core_inventory.addItem("$$$_VEHICLE", {model='etk800', config='etk800_m', color='1 1 1 1'})


