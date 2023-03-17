-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'On Vehicle Switched'
C.description = 'Triggers when the player switches to another vehicle.'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.category = 'logic'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.', impulse = true },
  { dir = 'out', type = 'number', name = 'oldID', description = 'Id of the previous vehicle.' },
  { dir = 'out', type = 'number', name = 'newID', description = 'Id of the new vehicle.' },
  { dir = 'out', type = 'number', name = 'player', hidden = true, description = 'Id of the player.' },
}


C.tags = {'event'}

function C:init(mgr, ...)

end

function C:_executionStarted()
  self.flag = false
  self.info = {}
end


function C:work(args)
  if self.flag then
    self.pinOut.oldID.value = self.info.oldID
    self.pinOut.newID.value = self.info.newID
    self.pinOut.player.value = self.info.player
    self.pinOut.flow.value = true
    self.flag = false
  else
    self.pinOut.flow.value = false
  end
end

function C:_afterTrigger()
  self.flag = false
end

function C:onVehicleSwitched( oid, nid, player)
  self.info.oldID = oid
  self.info.newID = nid
  self.info.player = player
  self.flag = true

end



return _flowgraph_createNode(C)
