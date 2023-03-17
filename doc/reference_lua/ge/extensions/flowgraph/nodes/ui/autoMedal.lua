-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.name = 'Medal'
C.description = "Automatically gets the medal based on points."
C.category = 'repeat_instant'

C.color = ui_flowgraph_editor.nodeColors.ui
C.icon = ui_flowgraph_editor.nodeIcons.ui
C.pinSchema = {

  { dir = 'in', type = 'number', name = 'points', description = 'The players points.' },
  { dir = 'in', type = 'number', name = 'bronze', description = 'Threshold for bronze medal.', default=50 },
  { dir = 'in', type = 'number', name = 'silver', description = 'Threshold for silver medal.', default=85 },
  { dir = 'in', type = 'number', name = 'gold',   description = 'Threshold for gold medal.', default=100},
  { dir = 'in', type = 'number', name = 'platinium',   description = 'Threshold for platinium medal.', default=125},
  { dir = 'in', type = 'bool', name = 'ascending',description = 'If true, higher points mean better medal.', hidden=true, hardcoded=true, default=true },
  { dir = 'in', type = 'string', name = 'woodText', description = 'The text attached to this medal.' },
  { dir = 'in', type = 'string', name = 'bronzeText', description = 'The text attached to this medal.' },
  { dir = 'in', type = 'string', name = 'silverText', description = 'The text attached to this medal.' },
  { dir = 'in', type = 'string', name = 'goldText', description = 'The text attached to this medal.' },

  { dir = 'out', type = 'string', name = 'medal', description = 'The resulting medal.' },

  { dir = 'out', type = 'bool', name = 'bronze', description = 'True, if at least bronze was achieved.', hidden=true},
  { dir = 'out', type = 'bool', name = 'silver', description = 'True, if at least silver was achieved.', hidden=true},
  { dir = 'out', type = 'bool', name = 'gold',   description = 'True, if at least gold was achieved.',   hidden=true},
  { dir = 'out', type = 'bool', name = 'platinium',   description = 'True, if at least platinium was achieved.',   hidden=true},
  { dir = 'out', type = 'string', name = 'text',   description = 'The text attached to the resulting medal'},
  { dir = 'out', type = 'number', name = 'nextScore',   description = 'Gives the next medal score to reach'},
  { dir = 'out', type = 'string', name = 'nextMedal',   description = 'Gives the next medal name to reach'},
  { dir = 'out', type = 'bool', name = 'passed',   description = 'Whether this mission has been passed'},
  { dir = 'out', type = 'bool', name = 'completed',   description = 'Whether this mission has been completed'},
  { dir = 'out', type = 'bool', name = 'failed',   description = 'Whether this mission has been failed'},
}

local gte = function(a,b) return a >= b end
local lte = function(a,b) return a <= b end
local medals = {'bronze', 'silver', 'gold', "platinium"}
function C:work()
  self.pinOut.flow.value = true
  local points =  self.pinIn.points.value
  self.pinOut.medal.value = nil
  if not points then return end

  local comp = lte
  if self.pinIn.ascending.value then
    comp = gte
  end

  self.pinOut.medal.value = 'wood'
  local nextMedal = ""
  for _, m in ipairs(medals) do
    local val = self.pinIn[m].value
    self.pinOut[m].value = false
    if val and comp(points, val) then
      self.pinOut.medal.value = m
      self.pinOut.text.value = self.pinIn[m.."Text"].value
      self.pinOut[m].value = true
      nextMedal = medals[math.min(arrayFindValueIndex(medals, m) + 1, #medals)]
      self.pinOut.nextMedal.value = nextMedal
      self.pinOut.nextScore.value = self.pinIn[nextMedal].value
    end
  end
  self.pinOut.text.value = self.pinOut.text.value or self.pinIn.woodText.value
  self.pinOut.nextMedal.value = self.pinOut.nextMedal.value or medals[1]
  self.pinOut.nextScore.value = self.pinIn[self.pinOut.nextMedal.value].value

  self.pinOut.completed.value = self.pinOut.medal.value == "platinium"
  self.pinOut.passed.value = self.pinOut.completed.value or self.pinOut.medal.value == "silver" or self.pinOut.medal.value == "bronze" or self.pinOut.medal.value == "gold"
  self.pinOut.failed.value = not self.pinOut.passed.value
end

return _flowgraph_createNode(C)
