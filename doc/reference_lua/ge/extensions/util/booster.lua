-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

function M.trigger(data)
  print("Booster triggered")
  dump(data)

  if event == 'enter' then
    local veh = be:getObjectByID(data.subjectID)
    if veh then
      veh:queueLuaCommand("extensions.core_booster.boost(vec3(0,0,1),0.01)")
    end
  end
end


return M