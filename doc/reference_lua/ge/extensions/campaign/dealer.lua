-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'dealer'
M.state = {}

M.state.stock = {}

local function existItem(entryTable, valueObj)
  -- log('I', logTag, 'existItem called ... type(entryTable) = '..type(entryTable) ..'  type(valueObj) = '..type(valueObj))
  -- dump(entryTable)
  -- dump(valueObj)
  local found = false
  for _,item in ipairs(entryTable) do
    for k,v in pairs(item) do
      if valueObj[k] == v then
        found = true
      end
    end

    if found then
      -- log('I', logTag, 'Found duplicate!')
      goto continue
    end
  end
  ::continue::
  return found
end

local function addToStock(itemType, valueObj)
  log('I', logTag, 'addToStock called... itemType '..tostring(itemType)..' '..type(valueObj))
  local state = M.state

  local valueObjType = type(valueObj)

  if itemType and valueObj then
    itemType = string.upper(itemType)
    if not state.stock[itemType] then
      if valueObjType == 'table' then
        state.stock[itemType] = {}
      else
        state.stock[itemType] = 0
      end
    end

    if valueObjType == 'table' then
      local entry = state.stock[itemType]
      if not existItem(entry, valueObj) then
        table.insert(entry, valueObj)
      end
    else
      state.stock[itemType] = state.stock[itemType] + valueObj
    end
  end

  -- dump(state.stock)
end

local function getStock(itemType)
  local state = M.state
  state.stock[itemType] = state.stock[itemType] or {}
  local result = deepcopy(state.stock[itemType])
  return result
end

local function removeFromStock(itemType, valueObj)
  log('I', logTag, 'removeFromStock called... itemType '..tostring(itemType)..' '..type(valueObj))
  -- dump(state.stock)

  if itemType and valueObj then
    local state = M.state
    local valueObjType = type(valueObj)
    itemType = string.upper(itemType)
    if state.stock[itemType] then
      if valueObjType == 'table' then
        local itemTable = state.stock[itemType]
        print('dealer looping...')
        for index,entry in ipairs(itemTable) do
          print(entry.model, entry.config)
          if entry.model == valueObj.model and entry.config == valueObj.config then
            table.remove(itemTable, index)
            goto continue
          end
        end
        print('end looping...')
      else
        state.stock[itemType] = state.stock[itemType] - valueObj
      end
    end
  end
  ::continue::
  -- log('I', logTag, 'after removeFromStock')
  -- dump(state.stock)
end

local function buy(itemType, index)
  -- body
end

local function onSerialize()
  -- log('D', logTag, 'onSerialize called...')
  local data = deepcopy(M.state)
  return data
end

local function onDeserialized(data)
  log('D', logTag, 'onDeserialized called...')
  -- dump(data)
end

local function onSaveCampaign(saveCallback)
  local data = deepcopy(M.state)
  saveCallback(M.__globalAlias__, data)
end

local function onResumeCampaign(campaignInProgress, data)
  log('I', logTag, 'resume campaign called.....')
  M.state = data
end

M.addToStock        = addToStock
M.buy               = buy
M.getStock          = getStock
M.removeFromStock   = removeFromStock
M.onResumeCampaign  = onResumeCampaign
M.onSaveCampaign    = onSaveCampaign

M.onSerialize       = onSerialize
M.onDeserialized    = onDeserialized

return M
