-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- this module is loaded dynamically loaded from the C++ side/world editor

local M = {}

local function onPreRender(dt)
  local camPos = getCameraPosition()
  local fadeStart = 200
  local fadeEnd = 250
  for _, AIPathName in ipairs(scenetree.findClassObjects('AIPath')) do
    local o = scenetree.findObject(AIPathName)
    if o and o.drivability > 0 then
      local segCount = o:getNodeCount() - 1
      if segCount > 0 then

        local drivability = o.drivability
        local oneWay = o.oneWay or false
        local flipDirection = o.flipDirection or false

        local lastData = nil
        local vis = 0
        local camDist = 0
        for i = 0, segCount do
          local n = {
            pos = vec3(o:getNodePosition(i)),
            radius = o:getNodeWidth(i) * 0.5,
          }
          camDist = (camPos - n.pos):length()
          vis = 1 - clamp((camDist - fadeStart * 2) / (fadeEnd * 2 - fadeStart * 2), 0, 1)
          if vis < 0.01 then goto continue end

          debugDrawer:drawSphere(n.pos, n.radius, ColorF(1,0,0, 0.1 * vis))
          --debugDrawer:drawText(pp, String(tostring(nid)), ColorF(0,0,0,1))
          if lastData then
            debugDrawer:drawSquarePrism(lastData.pos, n.pos, Point2F(0.6, lastData.radius*2), Point2F(0.6, n.radius*2), ColorF(0,0,1,0.1*vis))

            -- draw the segment
            local lastPos = vec3()
            local dir = (n.pos - lastData.pos)
            if flipDirection then
              --dir = dir * -1
            end

            local lanesTotal = o.lanesLeft + o.lanesRight

            local function drawLane(ldir, lmid, lwidth, color)

              local k = 0 --lastData.radius * 1.4
              for o = 0, 1000 do -- failsafe for not running into endless loops
                local p = k / dir:length()

                local nodeRad = lastData.radius + (n.radius - lastData.radius) * p
                local lrad =  nodeRad * lwidth
                local offset = dir:perpendicular():normalized() * (lmid * nodeRad)

                local posDetail = lastData.pos + dir * p + offset

                local data = {}
                data.texture = 'art/arrow_waypoint_1.dds'
                data.position = posDetail
                data.color = color
                data.fadeStart = fadeStart
                data.fadeEnd = fadeEnd
                local s = lrad * 2 * 0.9
                data.scale = vec3(s, s, s)
                local d = dir * ldir
                data.forwardVec = d
                Engine.Render.DynamicDecalMgr.addDecal(data)

                k = k + lrad * 2
                if k >= dir:length() then break end
              end
            end

            local leftColor = ColorF(0, 1, 1, 1 )
            local rightColor = ColorF(1, 0, 0, 1 )

            local laneWidth = 1 / lanesTotal
            local color = (not flipDirection and leftColor) or rightColor
            local offset = laneWidth - 1 -- lane is -1 to +1
            for l = 0, o.lanesLeft - 1 do
              drawLane((flipDirection and -1) or 1, offset, laneWidth, color)
              offset = offset + laneWidth * 2
            end

            local color = (not flipDirection and rightColor) or leftColor
            for l = 0, o.lanesRight - 1, 1 do
              drawLane((flipDirection and 1) or -1, offset, laneWidth, color)
              offset = offset + laneWidth * 2
            end

          end

          ::continue::

          lastData = n
        end
      end
    end
  end
end

local function onExtensionUnloaded()
  log('I', 'AIPathEditor', "module unloaded")
end
local function onExtensionLoaded()
  log('I', 'AIPathEditor', "module loaded")
end

M.onExtensionLoaded = onExtensionLoaded
M.onExtensionUnloaded = onExtensionUnloaded
M.onPreRender = onPreRender

return M
