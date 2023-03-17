-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local defaultMaxUndoLevels = 1000

function C:init()
  self.maxUndoLevels = defaultMaxUndoLevels
  self.undoStack = {}
  self.redoStack = {}
  self.currentTransaction = nil
end

--- Undo a number of steps from the history stack.
-- @param steps how many steps to undo, default is 1 if not specified
function C:undo(steps)
  steps = steps or 1
  for i = 1, steps do
    if #self.undoStack == 0 then
      return
    end
    local undoTransaction = self.undoStack[#self.undoStack]
    for j = #undoTransaction.actions, 1, -1 do
      undoTransaction.actions[j].undo(undoTransaction.actions[j].data)
      if self.onUndo then self.onUndo(undoTransaction.actions[j]) end
    end
    table.insert(self.redoStack, undoTransaction)
    table.remove(self.undoStack, #self.undoStack)
  end
end

--- Redo a number of steps from the history stack.
-- @param steps how many steps to redo, default is 1 if not specified
function C:redo(steps)
  steps = steps or 1
  for i = 1, steps do
    if #self.redoStack == 0 then
      return
    end
    local redoTransaction = self.redoStack[#self.redoStack]
    for j = 1, #redoTransaction.actions do
      redoTransaction.actions[j].redo(redoTransaction.actions[j].data)
      if self.onRedo then self.onRedo(redoTransaction.actions[j]) end
    end
    table.insert(self.undoStack, redoTransaction)
    table.remove(self.redoStack, #self.redoStack)
  end
end

--- This will start a history transaction of adding multiple actions as a group.
-- @param name the name of the undo transaction (as a group of actions)
function C:beginTransaction(name) -- name is optional
  if self.currentTransaction then
    -- if there is already a transaction started and we want to start another
    return false
  end
  self.currentTransaction = {}
  self.currentTransaction.actions = {}
  self.currentTransaction.name = name
  return self.currentTransaction
end

--- Cancels a started transaction. Used when adding actions in a transaction, and some add action failed or data is not valid.
function C:cancelTransaction()
  -- just erase current transaction
  self.currentTransaction = nil
end

--- Ends a transaction successfuly and **EXECUTES ALL REDO** functions from all the added actions in this transaction.
function C:endTransaction(dontCallRedoNow)
  if #self.currentTransaction.actions > 0 then
    if #self.undoStack == self.maxUndoLevels then
      -- from this point, every time we add a new transaction, delete the first one so we keep the max undo levels size
      table.remove(self.undoStack, 0)
    end
    table.insert(self.undoStack, self.currentTransaction)

    if not dontCallRedoNow or dontCallRedoNow == nil then
      -- run the redo funcs for the gathered actions
      for _, action in ipairs(self.currentTransaction.actions) do
        action.redo(action.data)
      end
    end
    self.redoStack = {}
  end
  self.currentTransaction = nil
  return true
end

--- This adds the action on the undo stack **AND EXECUTES THE REDO** function with the given data table as argument.
-- When this function is called inside a beginTransaction/endTransaction, it will not execute the redo function until endTransaction, when all the redo functions of all the added actions inside that transaction are called at once.
-- @param name the name of the action, in the example format "MyCreateWhatever" do not add Action at the end of the string
-- @param data the data used by both undo and redo functions, where you keep new and old information about the action done
-- @param undoFunc the undo function, which has the format: local function myCreateWhateverUndo(actionData)
-- @param redoFunc the redo function, which has the format: local function myCreateWhateverRedo(actionData)
-- @return the action table that was pushed to the stack
function C:commitAction(name, data, undoFunc, redoFunc, dontCallRedoNow)
  if not redoFunc or not undoFunc then return false end
  local action = { name = name, undo = undoFunc, redo = redoFunc, data = data, userId = editor.userId, timestamp = os.time() }

  if self.currentTransaction then
    table.insert(self.currentTransaction.actions, action)
    if self.onCommitAction then self.onCommitAction(action) end
    return action
  else
    local singleActionTransaction = {}
    singleActionTransaction.actions = {}
    singleActionTransaction.name = name
    table.insert(singleActionTransaction.actions, action)

    if #self.undoStack == self.maxUndoLevels then
      -- from this point, every time we add a new transaction, delete the first one so we keep the max undo levels size
      table.remove(self.undoStack, 0)
    end

    table.insert(self.undoStack, singleActionTransaction)
    local result = action
    if not dontCallRedoNow or dontCallRedoNow == nil then
      result = redoFunc(data)
    end
    if self.onCommitAction then self.onCommitAction(action) end
    self.redoStack = {}
    return result
  end
  return nil
end

--- Clear the history undo and redo stacks, used on new document.
function C:clear()
  self.undoStack = {}
  self.redoStack = {}
end

--- Update an object id with a new one, that can be found in the redo actions.
-- @param oldObjectId the old id
-- @param newObjectId the new id
function C:updateRedoStackObjectId(oldObjectId, newObjectId)
  for _, transaction in ipairs(self.redoStack) do
    local action
    for j = #transaction.actions, 1, -1 do
      action = transaction.actions[j]
      if action.data then
        if action.data.objectId then
          if action.data.objectId == oldObjectId then
            action.data.objectId = newObjectId
          end
        end
        if action.data.objectIds then
          for i = 1, tableSize(action.data.objectIds) do
            if action.data.objectIds[i] == oldObjectId then
              action.data.objectIds[i] = newObjectId
            end
          end
        end
      end
    end
  end
end

--- Serialize the history stacks
function C:serialize(data)
  data.history = {}
  data.history.undoStack = self.undoStack
  data.history.redoStack = self.redoStack
end

--- Deserialize the history stacks
function C:deserialize(data)
  if data.history then
    self.undoStack = data.history.undoStack
    self.redoStack = data.history.redoStack
  end
  self.currentTransaction = nil
end

return function()
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init()
  return o
end