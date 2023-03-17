-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local function createTube(radius,steps,wallHeight)
  local crossPoints = {}
  local uv = {0}
  local cap = {}
  for i = 1, steps do
    crossPoints[#crossPoints+1] = vec3(math.cos(-(1+0.1*i)*math.pi/2 )*(radius+1),0,radius+math.sin(-(1+0.1*i)*math.pi/2)*(radius+1))
    uv[#uv+1] = 0
  end
  local cpc = #crossPoints
  if wallHeight and wallHeight > 0 and steps == 10 then
    crossPoints[#crossPoints+1] = vec3(-(radius+1),0,radius + wallHeight)
    crossPoints[#crossPoints+1] = vec3(-(radius)  ,0,radius + wallHeight)
    uv[#uv+1] = 0
    uv[#uv+1] = 1
    cap[#cap+1] = {cpc,cpc+1,cpc+2}
    cap[#cap+1] = {cpc,cpc+2,cpc+3}
  end
  for i = steps, 1,-1 do
    crossPoints[#crossPoints+1] = vec3(math.cos(-(1   +0.1*i)*math.pi/2 )*(radius),0,radius+math.sin(-(1   +0.1*i)*math.pi/2)*(radius))
    crossPoints[#crossPoints+1] = vec3(math.cos(-(0.95+0.1*i)*math.pi/2 )*(radius),0,radius+math.sin(-(0.95+0.1*i)*math.pi/2)*(radius))
    uv[#uv+1] = 1
    uv[#uv+1] = 1
  end
  cpc = #crossPoints+2
  uv[#uv+1] = 1
  for i = 1, steps do
    cap[#cap+1] = {cpc-2*i, cpc-2*i+1, i-1      }
    cap[#cap+1] = {cpc-2*i, i-1      , i        }
    cap[#cap+1] = {cpc-2*i, i        , cpc-2*i-1}
  end

  return {
    crossPoints = crossPoints,
    uv = uv,
    cap = cap,
    material = "track_editor_border",
    flipUVRight = true
  }
end

local function createSideWall(height, angle)
  if not angle then angle = 0 end
    return {
      crossPoints = {
        vec3(-1,0,-1),
        vec3(-math.sin(angle)*height,0,math.cos(angle) * height) + vec3(-math.cos(angle),0,-math.sin(angle)),
        vec3(-math.sin(angle)*height,0,math.cos(angle) * height)
        },
      cap = {{0,1,2},{0,2,4},{2,3,4}},
      uv = {0.7-0.2*height,0.8- 0.2*height,0.9- height*0.1,1-height*0.1,1},
      sharp = {1,2,3,4},
      flipUVRight = true,
      material = "track_editor_border"
    }
end


return
{
    sideWall01 = createSideWall(0.1),
    sideWall03 = createSideWall(0.3),
    sideWall05 = createSideWall(0.5),
    sideWall10 = createSideWall(1),
    sideWall50 = createSideWall(5),
    sideWall100 = createSideWall(10),

    rotWall15 = createSideWall(2,math.pi/12),
    rotWall30 = createSideWall(2,math.pi/6),
    rotWall45 = createSideWall(2,math.pi/4),
    rotWall90 = createSideWall(2,math.pi/2),


    tube5m = createTube(5,10,1),
    tube5mHigh = createTube(5,10,5),
    tube5mFull = createTube(5,20),
    tube10m = createTube(10,10,2),
    tube10mHigh = createTube(10,10,10),
    tube10mFull = createTube(10,20),
}