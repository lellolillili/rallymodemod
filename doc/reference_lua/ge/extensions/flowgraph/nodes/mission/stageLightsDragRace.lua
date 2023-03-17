---@diagnostic disable: undefined-global
-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'Set Stage Lights'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Activates or desactivates the Pre Stage and the Stage lights of the christmas tree of the drag race.'
C.todo = ""
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Reset this node.', impulse = true},
  {dir = 'in', type = 'string', name = 'side', default = 'l', description = 'Side of the lane that is going to be updated'},
  {dir = 'in', type = 'string', name = 'light', default = 'preStage', description = 'Turned on light of the Christmas Tree of the dragRace'},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
}

function C:postInit()
  self.pinInLocal.side.hardTemplates = {
    { label = 'left', value = 'l' },
    { label = 'right', value = 'r' },
  }
  self.pinInLocal.light.hardTemplates = {
    { label = 'Pre Stage', value = 'preStage' },
    { label = 'Stage', value = 'stage' },
  }
end

function C:initLights()
  self.lights = {
    stageLights = {
      prestageLightL  = {obj = scenetree.findObject("Prestagelight_l"), anim = "prestage"},
      prestageLightR  = {obj = scenetree.findObject("Prestagelight_r"), anim = "prestage"},
      stageLightL     = {obj = scenetree.findObject("Stagelight_l"),    anim = "prestage"},
      stageLightR     = {obj = scenetree.findObject("Stagelight_r"),    anim = "prestage"}
    }
  }
end

function C:_executionStarted()
end

function C:init()
end

function C:work()
  if self.pinIn.reset.value then

    self:initLights()
    self.lights.stageLights.prestageLightL.obj:setHidden(true)
    self.lights.stageLights.prestageLightR.obj:setHidden(true)
    self.lights.stageLights.stageLightL.obj:setHidden(true)
    self.lights.stageLights.stageLightR.obj:setHidden(true)
    return
  end

  if self.pinIn.side.value == "l" then
    if self.pinIn.light.value == "preStage" then
      self.lights.stageLights.prestageLightL.obj:setHidden(false)
    else
      self.lights.stageLights.stageLightL.obj:setHidden(false)
    end
  else
    if self.pinIn.light.value == "preStage" then
      self.lights.stageLights.prestageLightR.obj:setHidden(false)
    else
      self.lights.stageLights.stageLightR.obj:setHidden(false)
    end
  end
end

return _flowgraph_createNode(C)
