-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'Get Progress'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
C.description = "Shows the aggregated progress for the current progressKey."
C.category = 'once_p_duration'

C.pinSchema = {


  { dir = 'out', type = 'table', name = "aggregate", description = "Aggregate Object", fixed=true },
  { dir = 'out', type = 'string', name = "bestType", description = "Best Type", fixed=true, hidden=true },
  { dir = 'out', type = 'bool', name = "passed", description = "Passed", fixed=true, hidden=true },
  { dir = 'out', type = 'bool', name = "completed", description = "Completed", fixed=true, hidden=true },
  { dir = 'out', type = 'number', name = "attemptCount", description = "attemptCount", fixed=true, hidden=true },
  { dir = 'out', type = 'number', name = "mostRecentDate", description = "Completed", fixed=true, hidden=true },
  { dir = 'out', type = 'string', name = "aggText", description = "Aggregate as simple Text.", fixed=true },
  { dir = 'out', type = 'string', name = "aggHtml", description = "Aggregate as a html-formatted list.", fixed=true },
}

C.tags = {'activity'}
C.allowCustomOutPins = true
function C:init()
  self.savePins = true
end

function C:workOnce()
  if self.pinIn.flow.value then
    if not self.mgr.activity then return end

    -- todo: get progress key
    local progressKey = self.mgr.activity.currentProgressKey or self.mgr.activity.defaultProgressKey
    local aggregate = self.mgr.activity.saveData.progress[progressKey].aggregate


    local text = ""
    local html = "<ul>"
    local keysSorted = tableKeysSorted(aggregate)
    for _, k in ipairs(keysSorted) do
      local val = aggregate[k]
      if type(val) == 'number' then
        text = text .. string.format("%s: %0.2d. ", k, val)
        html = html .. string.format("<li>%s: %0.2d</li>", k, val)
      else
        text = text .. string.format("%s: %s. ", k, val)
        html = html .. string.format("<li>%s: %s</li>", k, val)
      end
    end
    html = html.."</ul>"
    self.pinOut.aggText.value = text
    self.pinOut.aggHtml.value = html

    for key, val in pairs(aggregate) do
      if self.pinOut[key] then
        self.pinOut[key].value = val
      end
    end
  end
end


return _flowgraph_createNode(C)
