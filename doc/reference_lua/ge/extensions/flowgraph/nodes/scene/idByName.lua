-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'ID by Name'
C.description = 'Gets object ID by game object name.'
C.color = ui_flowgraph_editor.nodeColors.scene
C.icon = ui_flowgraph_editor.nodeIcons.scene
C.category = 'simple'

C.pinSchema = {
  { dir = 'in', type = 'string', name = 'name', description = 'The name of the Object.', hidden = true },
  { dir = 'out', type = 'number', name = 'objID', description = 'The id of the first object with the given name.' },
}

C.tags = {'scene'}

function C:init()
  self.data.name = ""
  self.objID = nil
end

function C:work()

  if self.pinInLocal.name:isUsed() then
    self.data.name = self.pinIn.name.value
  end
  --if self.objID == nil then
  local ob =  scenetree.findObject(self.data.name or "")
  if ob then
    self.objID = ob:getID()
  end
  --end

  if self.objID ~= nil then
    self.pinOut.objID.value = self.objID
  end
end

function C:onClientEndMission()
  self.objID = nil
end

function C:onClientStartMission()
  self.objID = nil
end

function C:_executionStarted()
  self.objID = nil
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(self.data.name)
  im.Text(tostring(self.objID))
end


return _flowgraph_createNode(C)
