-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Pursuit Parameters'
C.description = 'Sets various parameters for the police system.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {'traffic', 'police', 'pursuit', 'ai', 'mode', 'settings', 'parameters'}


C.pinSchema = {
  { dir = 'in', type = 'number', name = 'policeStrictness', default = 0.5, description = 'Police strictness for catching offenses (from 0 to 1).' },
  { dir = 'in', type = 'number', name = 'arrestLimit', description = 'Duration until pursuit ends due to arrest.' },
  { dir = 'in', type = 'number', name = 'arrestRadius', description = 'Default arrest radius.' },
  { dir = 'in', type = 'number', name = 'evadeLimit', description = 'Duration until pursuit ends due to escape.' },
  { dir = 'in', type = 'number', name = 'evadeRadius', description = 'Default evade radius.' },
  { dir = 'in', type = 'number', name = 'roadblockFrequency', hidden = true, default = 0.5, description = 'Roadblock frequency at the highest wanted level (from 0 to 1).' }
}

function C:init()
  self.vars = {}
end

function C:workOnce()
  table.clear(self.vars)

  if self.pinIn.policeStrictness.value ~= nil then
    self.vars.strictness = self.pinIn.policeStrictness.value
  end
  if self.pinIn.arrestLimit.value ~= nil then
    self.vars.arrestLimit = self.pinIn.arrestLimit.value
  end
  if self.pinIn.arrestRadius.value ~= nil then
    self.vars.arrestRadius = self.pinIn.arrestRadius.value
  end
  if self.pinIn.evadeLimit.value ~= nil then
    self.vars.evadeLimit = self.pinIn.evadeLimit.value
  end
  if self.pinIn.evadeRadius.value ~= nil then
    self.vars.evadeRadius = self.pinIn.evadeRadius.value
  end
  if self.pinIn.roadblockFrequency.value ~= nil then
    self.vars.roadblockFrequency = self.pinIn.roadblockFrequency.value
  end

  gameplay_police.setPursuitVars(self.vars)
end

return _flowgraph_createNode(C)