-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'Clear Lights Dragrace'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Clear the lights and the display when a mission is finished or abandoned.'
C.todo = ""
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
}

function C:initLights()
  self.lights = {
    stageLights = {
      prestageLightL  = {obj = scenetree.findObject("Prestagelight_l"), anim = "prestage"},
      prestageLightR  = {obj = scenetree.findObject("Prestagelight_r"), anim = "prestage"},
      stageLightL     = {obj = scenetree.findObject("Stagelight_l"),    anim = "prestage"},
      stageLightR     = {obj = scenetree.findObject("Stagelight_r"),    anim = "prestage"}
    },
    countDownLights = {
      amberLight1R    = {obj = scenetree.findObject("Amberlight1_R"), anim = "tree"},
      amberLight2R    = {obj = scenetree.findObject("Amberlight2_R"), anim = "tree"},
      amberLight3R    = {obj = scenetree.findObject("Amberlight3_R"), anim = "tree"},
      amberLight1L    = {obj = scenetree.findObject("Amberlight1_L"), anim = "tree"},
      amberLight2L    = {obj = scenetree.findObject("Amberlight2_L"), anim = "tree"},
      amberLight3L    = {obj = scenetree.findObject("Amberlight3_L"), anim = "tree"},
      greenLightR     = {obj = scenetree.findObject("Greenlight_R"),  anim = "tree"},
      greenLightL     = {obj = scenetree.findObject("Greenlight_L"),  anim = "tree"},
      redLightR       = {obj = scenetree.findObject("Redlight_R"),    anim = "tree"},
      redLightL       = {obj = scenetree.findObject("Redlight_L"),    anim = "tree"}
    }
  }
  self.lights.stageLights.stageLightL.obj:setHidden(true)
  self.lights.stageLights.prestageLightL.obj:setHidden(true)
  self.lights.stageLights.stageLightR.obj:setHidden(true)
  self.lights.stageLights.prestageLightR.obj:setHidden(true)
  self.lights.countDownLights.amberLight1L.obj:setHidden(true)
  self.lights.countDownLights.amberLight2L.obj:setHidden(true)
  self.lights.countDownLights.amberLight3L.obj:setHidden(true)
  self.lights.countDownLights.amberLight1R.obj:setHidden(true)
  self.lights.countDownLights.amberLight2R.obj:setHidden(true)
  self.lights.countDownLights.amberLight3R.obj:setHidden(true)
  self.lights.countDownLights.greenLightR.obj:setHidden(true)
  self.lights.countDownLights.greenLightL.obj:setHidden(true)
  self.lights.countDownLights.redLightR.obj:setHidden(true)
  self.lights.countDownLights.redLightL.obj:setHidden(true)
end

function C:clearDigits()
  for i=1, 5 do
    local leftTimeDigit = scenetree.findObject("display_time_" .. i .. "_l")
    leftTimeDigit:setHidden(true)

    local rightTimeDigit = scenetree.findObject("display_time_" .. i .. "_r")
    rightTimeDigit:setHidden(true)

    local rightSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_r")
    rightSpeedDigit:setHidden(true)

    local leftSpeedDigit = scenetree.findObject("display_speed_" .. i .. "_l")
    leftSpeedDigit:setHidden(true)
  end
end

function C:_executionStarted()
  self.lights = {}
  self.pinOut.flow.value = false
end

function C:init()
  self.lights = {}
  self.pinOut.flow.value = false
end

function C:work()
  self.pinOut.flow.value = false

  self:initLights()
  self:clearDigits()

  self.pinOut.flow.value = true
end

return _flowgraph_createNode(C)
