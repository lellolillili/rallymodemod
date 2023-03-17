-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'DOF'

C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui

C.description = 'Changes the Depth of Field'
C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'blurIn', description = 'start fading in' },
  { dir = 'in', type = 'flow', name = 'blurOut', description = 'start fading out' },
  { dir = 'out', type = 'flow', name = 'blurDone', description = 'Outflow for this node.' },

  { dir = 'in', type = 'number', name = 'fadeTime', default = 1, description = "How long the fade should take in seconds" },
}

C.tags = {'gfx','dof'}

function C:reset()
  self.timer = 0
  self.mode = ''

  -- reset to stored values
  if self.savedBlurMin then
    TorqueScriptLua.setVar('$DOFPostFx::BlurMin', self.savedBlurMin)
  end

  if self.savedBlurMax then
    TorqueScriptLua.setVar('$DOFPostFx::BlurMax', self.savedBlurMax)
  end

  if self.savedFocusRangeMax then
    TorqueScriptLua.setVar('$DOFPostFx::FocusRangeMax', self.savedFocusRangeMax)
  end

  if self.savedBlurCurveFar then
    TorqueScriptLua.setVar('$DOFPostFx::BlurCurveFar', self.savedBlurCurveFar)
  end

  local dofPostEffect = scenetree.findObject("DOFPostEffect")
  if dofPostEffect then
    dofPostEffect.updateDOFSettings()
  end
end

function C:init(mgr, ...)
  self:reset()
end

function C:_executionStopped()
  self:reset()
end

function C:work()
  local fadeTime = self.pinIn.fadeTime.value or 1

  if self.pinIn.blurIn.value or self.pinIn.blurOut.value then
    local cmode = ''
    if self.pinIn.blurIn.value and not self.pinIn.blurOut.value then
      cmode = 'in'
    elseif self.pinIn.blurOut.value and not self.pinIn.blurIn.value then
      cmode = 'out'
    end
    if cmode ~= self.mode then
      self:reset()
      self.mode = cmode

      self.savedBlurMin = TorqueScriptLua.getVar('$DOFPostFx::BlurMin')
      self.savedBlurMax = TorqueScriptLua.getVar('$DOFPostFx::BlurMax')
      self.savedFocusRangeMax = TorqueScriptLua.getVar('$DOFPostFx::FocusRangeMax')
      self.savedBlurCurveFar = TorqueScriptLua.getVar('$DOFPostFx::BlurCurveFar')
      self.targetBlur = 430
      TorqueScriptLua.setVar('$DOFPostFx::FocusRangeMax', 3)

      local dofPostEffect = scenetree.findObject("DOFPostEffect")
      if dofPostEffect then
        dofPostEffect.updateDOFSettings()
      end
    end
  end

  if self.mode == '' then return end

  self.timer = self.timer + self.mgr.dtSim

  if self.timer >= fadeTime then
    self.pinOut.blurDone.value = true
  else
    --print(" self.mode = " .. tostring(self.mode) .. " / self.timer = " .. tostring(self.timer) .. ' / fadeTime = ' .. tostring(fadeTime))
    local newVal = 0
    if self.mode == 'out' then
      newVal = fadeTime - self.timer
    elseif self.mode == 'in' then
      newVal = 1 - (fadeTime - self.timer)
    end
    TorqueScriptLua.setVar('$DOFPostFx::BlurMin', newVal)
    TorqueScriptLua.setVar('$DOFPostFx::BlurMax', newVal)
    TorqueScriptLua.setVar('$DOFPostFx::BlurCurveFar', newVal * self.targetBlur)

    local dofPostEffect = scenetree.findObject("DOFPostEffect")
    if dofPostEffect then
      dofPostEffect.updateDOFSettings()
    end

    self.pinOut.blurDone.value = false
  end
end

return _flowgraph_createNode(C)
