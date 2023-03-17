---@diagnostic disable: undefined-global
-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

--require('/lua/vehicle/controller')

local C = {}

C.name = 'Lights Controller'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Updates the lights for the Drag Races missions.'
C.todo = ""
C.category = 'repeat_instant'

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = "Inflow for this node."},
  {dir = 'in', type = 'flow', name = 'reset', description = 'Reset this node.', impulse = true},
  {dir = 'in', type = 'bool', name = 'proTree', description = 'TODO', default = true},
  {dir = 'in', type = 'number', name = 'velocity', description = 'Velocity of the players vehicle'},
  {dir = 'out', type = 'flow', name = 'flow', description = "Outflow for this node."},
  {dir = 'out', type = 'flow', name = 'disqualified', description = "Outflow if the player has been desqualified."},
  {dir = 'out', type = 'flow', name = 'started', description = "Outflow when the race is started."}
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
end

function C:_executionStarted()
  self.started = false
  self.starttimer = 0
  self.jumpStarted = false
  self.pinOut.disqualified.value = false
  self.pinOut.started.value = false
end

function C:init()
  self.started = false
  self.starttimer = 0
  self.jumpStarted = false
  self.pinOut.disqualified.value = false
  self.pinOut.started.value = false
end

function C:work()
  self.pinOut.flow.value = true
  if self.pinIn.reset.value then
    self.started = false
    self.starttimer = 0
    self.jumpStarted = false
    self.pinOut.disqualified.value = false
    self.pinOut.started.value = false

    self:initLights()

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
    return
  end
  if not self.started then
    self.starttimer = self.starttimer + self.mgr.dtSim
    if self.pinIn.proTree.value then
      if self.starttimer > 2.0 then
        if self.starttimer < 2.4 and self.lights.countDownLights.amberLight1L.obj:isHidden() then
          self.lights.countDownLights.amberLight1L.obj:setHidden(false)
          self.lights.countDownLights.amberLight2L.obj:setHidden(false)
          self.lights.countDownLights.amberLight3L.obj:setHidden(false)
          self.lights.countDownLights.amberLight1R.obj:setHidden(false)
          self.lights.countDownLights.amberLight2R.obj:setHidden(false)
          self.lights.countDownLights.amberLight3R.obj:setHidden(false)
        end
        if self.starttimer > 2.4 and not self.started then
          self.lights.countDownLights.amberLight1L.obj:setHidden(true)
          self.lights.countDownLights.amberLight2L.obj:setHidden(true)
          self.lights.countDownLights.amberLight3L.obj:setHidden(true)
          self.lights.countDownLights.amberLight1R.obj:setHidden(not self.jumpStarted)
          self.lights.countDownLights.amberLight2R.obj:setHidden(not self.jumpStarted)
          self.lights.countDownLights.amberLight3R.obj:setHidden(not self.jumpStarted)
          self.lights.countDownLights.greenLightL.obj:setHidden(false)
          self.lights.countDownLights.greenLightR.obj:setHidden(self.jumpStarted)
          if not self.jumpStarted then
            self.started = true
            self.pinOut.started.value = true
          end
        end
      end
    else
      if self.starttimer > 1.0 and self.starttimer < 1.5 and self.lights.countDownLights.amberLight1L.obj:isHidden() then
        self.lights.countDownLights.amberLight1L.obj:setHidden(false)
        self.lights.countDownLights.amberLight1R.obj:setHidden(self.jumpStarted)
      end
      if self.starttimer > 1.5 and self.starttimer < 2.0 and self.lights.countDownLights.amberLight2L.obj:isHidden() then
        self.lights.countDownLights.amberLight1L.obj:setHidden(true)
        self.lights.countDownLights.amberLight2L.obj:setHidden(false)
        if not self.jumpStarted then
          self.lights.countDownLights.amberLight1R.obj:setHidden(true)
          self.lights.countDownLights.amberLight2R.obj:setHidden(self.jumpStarted)
        end
      end
      if self.starttimer > 2.0 and self.starttimer < 2.5 and self.lights.countDownLights.amberLight3L.obj:isHidden() then
        self.lights.countDownLights.amberLight2L.obj:setHidden(true)
        self.lights.countDownLights.amberLight3L.obj:setHidden(false)
        if not self.jumpStarted then
          self.lights.countDownLights.amberLight2R.obj:setHidden(true)
          self.lights.countDownLights.amberLight3R.obj:setHidden(self.jumpStarted)
        end
      end
      if self.starttimer > 2.5 and not self.started then
        self.lights.countDownLights.amberLight3L.obj:setHidden(true)
        self.lights.countDownLights.greenLightL.obj:setHidden(false)
        if not self.jumpStarted then
          self.lights.countDownLights.amberLight3R.obj:setHidden(true)
          self.lights.countDownLights.greenLightR.obj:setHidden(self.jumpStarted)
          self.started = true
          self.pinOut.started.value = true
          return
        end
      end
    end
  end
  if (not self.jumpStarted and not self.started and self.pinIn.velocity.value > 0.5) then
    self.jumpStarted = true
    self.pinOut.disqualified.value = true
    self.lights.countDownLights.amberLight1R.obj:setHidden(false)
    self.lights.countDownLights.amberLight2R.obj:setHidden(false)
    self.lights.countDownLights.amberLight3R.obj:setHidden(false)
    self.lights.countDownLights.greenLightR.obj:setHidden(true)
    self.lights.countDownLights.redLightR.obj:setHidden(false)
  end
end

return _flowgraph_createNode(C)
