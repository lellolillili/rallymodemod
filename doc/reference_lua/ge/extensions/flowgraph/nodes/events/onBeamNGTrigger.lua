-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local C = {}

C.name = 'on BeamNGTrigger'
C.description = "Listens to onBeamNGTrigger events and lets flow through in such an event. Can filter trigger names"
C.todo = "name filtering should be a pin, maybe merge this node with custom trigger."
C.category = 'repeat_instant'

C.color = ui_flowgraph_editor.nodeColors.event
C.icon = ui_flowgraph_editor.nodeIcons.event
C.pinSchema = {
  { dir = 'out', type = 'flow', name = 'enter', description = 'Puts out flow, when the trigger event was of type enter.', impulse = true },
  { dir = 'out', type = 'flow', name = 'exit', description = 'Puts out flow, when the trigger event was of type exit.', impulse = true },
  { dir = 'out', type = 'number', name = 'vehId', description = 'Id of the vehicle that caused the trigger event.' },
  { dir = 'out', type = 'number', name = 'triggerId', description = 'Id of the trigger that triggered the event.' },
  { dir = 'out', type = 'string', name = 'vehicleName', description = 'Name of the vehicle that caused the trigger event.' },
  { dir = 'out', type = 'string', name = 'triggerName', description = 'Name of the trigger that triggered the event.' },
}
C.legacyPins = {
  out = {
    vehicleId = 'vehId'
  },
}


C.tags = {}

function C:init(mgr, ...)
  self.data.filterName = ""
  self.enterFlag = false
  self.exitFlag = false
end

function C:onBeamNGTrigger(data)
  if self.data.filterName ~= "" and data.triggerName ~= self.data.filterName then
    return
  end

  self.pinOut.vehId.value = data.subjectID
  self.pinOut.vehicleName.value =  data.subjectName
  self.pinOut.triggerId.value =  data.triggerID
  self.pinOut.triggerName.value =  data.triggerName

  if data.event == "enter" then
    self.enterFlag = true
  elseif data.event == "exit" then
    self.exitFlag = true
  end

  self:trigger()
end

function C:work(args)
  self.pinOut.enter.value = self.enterFlag
  self.pinOut.exit.value = self.exitFlag
  self.enterFlag = false
  self.exitFlag = false
end


function C:drawMiddle(builder, style)
  builder:Middle()
  if self.data.filterName ~= "" then
    im.Text("Only:")
    im.Text(self.data.filterName)
  end
end

return _flowgraph_createNode(C)
