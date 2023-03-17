-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Get Custom Vehicle Data'
C.description = 'Gets all the dynamic fields stored in the vehicle.'
C.color = ui_flowgraph_editor.nodeColors.traffic
C.icon = ui_flowgraph_editor.nodeIcons.traffic
C.category = 'once_instant'
C.tags = {}


C.pinSchema = {
  {dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle Id.', fixed = true}
}

C.allowedManualPinTypes = {
  flow = false,
  string = true,
  number = true,
  bool = true,
  any = true,
  table = true,
  vec3 = true,
  quat = true,
  color = true,
}

function C:init()
  self.savePins = true
  self.allowCustomOutPins = true
end

--Custom converter to table (idk if there is any converter already)
function C:convertStringToTable(str)
  local wps = {}
  local e = 1
  local s = 1
  local i = 1
  while s <= #str do
    while str:sub(e, e) ~= "," and e <= #str do
      e = e + 1
    end
    wps[i] = str:sub(s, e - 1)
    e = e + 1
    s = e
    i = i + 1
  end
  return wps
end

function C:workOnce()
  if self.pinIn.vehId.value then
    local veh = scenetree.findObjectById(self.pinIn.vehId.value)

    for name, pin in pairs(self.pinOut) do
      if name ~= 'flow' and not pin.fixed then
        --Identify what type is the pinOut and proceed to check if the dynamicField exist in the vehicle, if exists, copy the value into the pinOutput.
        --If the type of the pinOut is a table or a vector, convert the value properly to the new type.


      end
    end

    if veh.waypoints and veh.wayponits ~= "" then
      self.pinOut.waypoints.value = wps
    end
    if veh.routeSpeed and veh.routeSpeed ~= "" then
      self.pinOut.routeSpeed.value = tonumber(veh.routeSpeed)
    end
    if veh.risk and veh.risk ~= "" then
      self.pinOut.risk.value = tonumber(veh.risk)
    end
  end
end

return _flowgraph_createNode(C)