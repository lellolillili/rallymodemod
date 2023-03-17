-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local C = {}
C.moduleOrder = 1000 -- low first, high later
C.hooks = {'onFlowgraphManagerPreUpdate'}

function C:init()
  self:clear()
end

function C:clear()
  self.children = {}
  self.messages = {}
  self.parentId = -1
end

function C:afterTrigger()
end

function C:sendMessage(targetId, message, sourceNode)
  log("I","","Sending Message" .. dumps(targetId) .. dumpsz(message, 2))
  local name = message.name or ""
  self.mgr:logEvent("Sent Message "..name.." to " .. dumps(targetId),"I", "A message has been sent to id " .. dumps(targetId)..". Contents: " .. dumpsz(message, 2), {type = "node", node = sourceNode})
  local target = core_flowgraphManager.getManagerByID(targetId)
  if targetId == -1 then target = core_flowgraphManager.getManagerByID(self.parentId) end
  if not target then return false end
  target.modules.thread:receiveMessage(message, self.mgr.id)
  return true
end

function C:onFlowgraphManagerPreUpdate()
  for _, message in ipairs(self.messages) do
    if message.hook then
      self.mgr:broadcastCall(message.hook, message.data)
    else
      self.mgr:broadcastCall("onThreadMessageProcess", message)
    end
  end
  table.clear(self.messages)
end

function C:receiveMessage(message, sourceId)
  table.insert(self.messages, message)
  local name = message.name or ""
  self.mgr:logEvent("Received Message " .. name.. " from " .. dumps(sourceId),"I", "A message has been received from " .. dumps(sourceId)..". Contents: " .. dumpsz(message, 2))
end

function C:startProjectFromFilepath(file, sourceNode)
  local mgr = core_flowgraphManager.loadManager(file)
  mgr:setRunning(true)
  table.insert(self.children, {
    fgId = mgr.id,
    originalPath = file
  })
  mgr.modules.thread.parentId = self.mgr.id
  dumpz(self.children, 2)
  self.mgr:logEvent("Loaded Child Project","I", "A Child has been loaded from path " .. dumps(file), {type = "node", node = sourceNode})
  return mgr.id
end

function C:executionStopped()
  for _, childData in ipairs(self.children) do
    local fgId = childData.fgId
    local childFg = core_flowgraphManager.getManagerByID(fgId)
    if childFg then
      childFg:setRunning(false, true)
      core_flowgraphManager.removeNextFrame(childFg)
    end
  end
  self:clear()
end

function C:executionStarted()

end


return _flowgraph_createModule(C)