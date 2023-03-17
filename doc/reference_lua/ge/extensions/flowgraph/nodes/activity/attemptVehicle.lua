-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor

local C = {}

C.name = 'ActivityAttempt Vehicle'
C.color = im.ImVec4(0.03,0.41,0.64,0.75)
C.description = "Creates an attempt for an activity."
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'string', name = "vehKey", description = "" },
  { dir = 'in', type = 'number', name = "vehId", description = "",  },
  { dir = 'in', type = 'table', name = "attempt", tableType = "attemptData", description = "Attempt Data for other nodes to process", fixed=true },
  { dir = 'out', type = 'table', name = "attempt", tableType = "attemptData", description = "Attempt Data for other nodes to process", fixed=true },
}

C.tags = {'activity'}

function C:init()

end

function C:workOnce()
  if self.pinIn.flow.value then
    local veh
    if self.pinIn.vehId.value then
      veh = scenetree.findObjectById(self.pinIn.vehId.value)
    else
      veh = be:getPlayerVehicle(0)
    end
    if veh then
      local vData = {
        model = veh.jbeam,
        config = veh.partConfig,
        isConfigFile = string.endswith(veh.partConfig,'.pc')
      }
      local attempt = self.pinIn.attempt.value
      attempt[self.pinIn.vehKey.value or "vehicle"] = vData
      self.pinOut.attempt.value = attempt
    end
  end
end


return _flowgraph_createNode(C)
