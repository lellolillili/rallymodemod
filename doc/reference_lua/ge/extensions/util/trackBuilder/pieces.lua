-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local tipPiece
local gridScale = 4
local heightScale = 1



local function toSegment(piece, tip)
  tipPiece = tip

  if piece.piece == "init" then
    return M.initialTrackPiece(piece)
  elseif piece.piece == "hexForward" or piece.piece == "squareForward" or piece.piece == "freeForward" then
    return M.forward(piece.length)

  elseif piece.piece == "hexCurve" then
    return M.curve(piece.length, math.pi/3, piece.direction,piece.hardness, math.sqrt(3))
  elseif piece.piece == "squareCurve" then
    return M.curve(piece.length, math.pi/2, piece.direction, piece.hardness, 1)
  elseif piece.piece == "freeCurve" then
    return M.curve(piece.radius, piece.length * math.pi/180, piece.direction, piece.hardness,piece.fitHex and math.sqrt(3) or 1)

  elseif piece.piece == "hexOffsetCurve" then
    return M.offsetCurve(piece.length, piece.xOffset, piece.hardness, true)
  elseif piece.piece == "squareOffsetCurve" then
    return M.offsetCurve(piece.length, piece.xOffset, 1, false)
  elseif piece.piece == "freeOffsetCurve" then
    return M.offsetCurve(piece.length, piece.xOffset, piece.hardness, false)

  elseif piece.piece == "hexBezier" then
    return M.customBezier(piece.xOff, piece.yOff, piece.dirOff * math.pi/3, piece.forwardLen, piece.backwardLen, true)
  elseif piece.piece == "squareBezier" then
    return M.customBezier(piece.xOff, piece.yOff, piece.dirOff * math.pi/2, piece.forwardLen, piece.backwardLen, false)
  elseif piece.piece == "freeBezier" then
    return M.customBezier(piece.xOff, piece.yOff, piece.dirOff * math.pi/180, piece.forwardLen, piece.backwardLen, false, piece.absolute, piece.empty)


  elseif piece.piece == "hexSpiral" then
    return M.hexSpiral(piece.size, piece.inside, piece.direction)
  elseif piece.piece == "squareSpiral" then
    return M.squareSpiral(piece.size, piece.inside, piece.direction)
  elseif piece.piece == "freeSpiral" then
    return M.freeSpiral(piece.size, piece.inside, piece.direction, piece.angle /180 * math.pi)


  elseif piece.piece == "hexLoop" then
    return M.loop(piece.xOffset, piece.radius, true )
  elseif piece.piece == "freeLoop" then
    return M.loop(piece.xOffset, piece.radius, false )

  elseif piece.piece == "hexEmptyOffset" then
    return M.emptyOffset(piece.xOff, piece.yOff, piece.zOff, piece.dirOff, piece.absolute, true)
  elseif piece.piece == "squareEmptyOffset" then
    return M.emptyOffset(piece.xOff, piece.yOff, piece.zOff, piece.dirOff, piece.absolute, false)
  end
end



-- smooth slope interpolation, goes from 0/0 to 1/delta, having horizontal slope at 0 and 1
local function smoothSlope(t,delta)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return delta,0
  else
    return (3-2*t)*delta*t*t , (6-6*t)*delta*t
  end
end

-- smoother slope interpolation, goes from 0/0 to 1/delta, having horizontal slope at 0 and 1
local function smootherSlope(t,delta)
  if t <= 0 then
    return 0,0
  elseif t >= 1 then
    return delta,0
  else
    return delta*t*t*t*(t*(t*6-15)+10) , delta*30*(t-1)*(t-1)*t*t
  end
end


local function getHdgVector(hdg)
  return vec3(math.sin(hdg), math.cos(hdg), 0)
end

local function initialTrackPiece(p)
  return {
      position = p and p.position or vec3(0,0,0),
      hdg = p and p.hdg or 0,
      polyMult = 1,
      noPoints = true
    }
end

--creates a hexForward piece of the specified length.
local function forward( length )

  --check in which direction we are actually going.
  local off = M.getHdgVector(tipPiece.hdg)
  return
    {
      position = tipPiece.position + off * length,
      origin = vec3(tipPiece.position),
      controlPointA =  off * 0.25 * length,
      controlPointB = -off * 0.25 * length,
      hdg = tipPiece.hdg,
      polyMult = length/2,
      pointsType = 'bezier'
    }

end

local function bezierCurve(radius, angle, direction, hardness, radiusMult)
  radius = radius * radiusMult
  local off = vec3(direction *(1-math.cos(angle)), math.sin(angle),0) * radius
  --rotate the offset by the hdg of the previous piece.
  off = M.rotateVectorByQuat(off, quatFromEuler(0,0,tipPiece.hdg))
  local bzLength = 0.552284749831
  if hardness < 0 then
    bzLength = (1+hardness)*bzLength
  elseif hardness > 0 then
    bzLength = (1-hardness) * bzLength + (1-(1-hardness))
  end
  return
    {
      position = tipPiece.position + off,
      origin = vec3(tipPiece.position),
      controlPointA =  M.getHdgVector(tipPiece.hdg) * bzLength * radius,
      controlPointB = M.getHdgVector(tipPiece.hdg + direction * angle) * -bzLength * radius,
      hdg = tipPiece.hdg + direction*angle ,
      polyMult = math.max(1,radius*angle / 3),
      pointsType = 'bezier'
    }
end

--creates a track fo specified length. direction allows for turning in 60?-steps
local function curve(radius, angle, direction, hardness, radiusMult)
  if hardness and hardness ~= 0 then
    return M.bezierCurve(radius,angle,direction,hardness,radiusMult)
  else
    radius = radius * radiusMult
    local off = vec3(direction *(1-math.cos(angle)), math.sin(angle),0) * radius
    --rotate the offset by the hdg of the previous piece.
    off = M.rotateVectorByQuat(off, quatFromEuler(0,0,tipPiece.hdg))
    return
      {
        position = tipPiece.position + off,
        origin = vec3(tipPiece.position),
        radius = radius,
        angle = angle,
        direction = direction,
        hdg = tipPiece.hdg + angle * direction,
        polyMult = math.max(1,radius*angle / 3),
        pointsType = 'arc'
      }
  end
end

--this creates an S-hexCurve of specified length and offset to the left or right.
local function offsetCurve(length, xOffset, hardness, isHex)

  local len = length
  --if the xOffset is not a multipPiecele of 2, increase the length so that it still snaps to the triangular grid.
  if isHex and xOffset % 2 == 1 then
    len = len + 0.5
  end
  local off = vec3(
      math.sin(tipPiece.hdg) * len + math.cos(tipPiece.hdg) * xOffset *  (isHex and math.sqrt(3)/2 or 1),
      math.cos(tipPiece.hdg) * len - math.sin(tipPiece.hdg) * xOffset *  (isHex and math.sqrt(3)/2 or 1),
      0
  )
  if not hardness then hardness = 0 end
  local cpLength = math.abs(len) * (0.1 + (hardness+4) * 0.1)
 -- tipPiece.hexForwardBezierCPLength = math.abs(len) * (0.1 + (hardness+4) * 0.1)
  return
    {
      position = tipPiece.position + off,
      origin = vec3(tipPiece.position),
      controlPointA = M.getHdgVector(tipPiece.hdg) * cpLength,
      controlPointB = M.getHdgVector(tipPiece.hdg) * -cpLength,
      hdg = tipPiece.hdg,
      pointsType = 'bezier',
      polyMult = math.abs(len /3) + math.abs(xOffset/3)
    }
end


local function customBezier(xOff, yOff, dirOff, forwardLen, backwardLen, isHex,absolute, empty)

  local pos= {position = vec3(tipPiece.position), hdg = tipPiece.hdg}
  local tp = M.splineTrack.getTrackPosition()
  if absolute then
    pos.position = vec3(tp.x,tp.y,tp.z)
    pos.hdg = tp.hdg
  end

  if isHex then
    if xOff % 2 == 1 then
      yOff = yOff + 0.5
    end
  end
  local hdg = absolute and pos.hdg or tipPiece.hdg
  local off = vec3(
      math.sin(hdg) * yOff + math.cos(hdg) * xOff *  (isHex and math.sqrt(3)/2 or 1),
      math.cos(hdg) * yOff - math.sin(hdg) * xOff *  (isHex and math.sqrt(3)/2 or 1),
      0
  )

  local localUnitX = vec3(
      math.sin(tipPiece.hdg) * 0 + math.cos(tipPiece.hdg) * 1 *  (isHex and math.sqrt(3)/2 or 1),
      math.cos(tipPiece.hdg) * 0 - math.sin(tipPiece.hdg) * 1 *  (isHex and math.sqrt(3)/2 or 1),
      0
  )
  local localUnitY = vec3(
      math.sin(tipPiece.hdg) * 1 + math.cos(tipPiece.hdg) * 0 *  (isHex and math.sqrt(3)/2 or 1),
      math.cos(tipPiece.hdg) * 1 - math.sin(tipPiece.hdg) * 0 *  (isHex and math.sqrt(3)/2 or 1),
      0
  )

  local tg = tipPiece.position - vec3(tp.x,tp.y,tp.z)
  local globalPos = (pos.position + off)  - vec3(tp.x,tp.y,tp.z)
  local localPos =   (pos.position + off) - tipPiece.position

  return
    {
      position = pos.position + off,
      origin = tipPiece.position,
      controlPointA = M.getHdgVector(tipPiece.hdg) *forwardLen,
      controlPointB = M.getHdgVector(pos.hdg + dirOff) * -backwardLen,
      hdg = pos.hdg + dirOff,
      polyMult = math.max(1,((pos.position + off - tipPiece.position):length())/4),
      pointsType = 'bezier',
      noPoints = empty or false,
      globalPosition = vec3(globalPos:dot(tp.unitX ), globalPos:dot(tp.unitY )),
      localPosition =  vec3(localPos:dot(localUnitX), localPos:dot(localUnitY)),
      globalHdg = pos.hdg + dirOff - tp.hdg,
      localHdg = pos.hdg + dirOff - tipPiece.hdg
    }

end


--this creates a hexSpiral piece, leading into a hexCurve.
local function hexSpiral(size, inside, dir)

  local inverse = not inside
  local absSize = math.abs(size)

  local off = vec3(absSize * math.sqrt(3)/2, absSize * 2.5, 0)

  if inverse then
    off:set(absSize * math.sqrt(3), absSize * 2, 0)
  end

  off.x = off.x * sign(dir)
  off = M.rotateVectorByQuat(off, quatFromEuler(0,0,tipPiece.hdg))

  local hexForwardCPLength = 1.111 * absSize
  local backwardCPLength = 1 * absSize
  if inverse then
    backwardCPLength = 1.111 * absSize
    hexForwardCPLength = 1 * absSize
  end
  return
    {
      position = tipPiece.position + off,
      origin = vec3(tipPiece.position),
      controlPointA = M.getHdgVector(tipPiece.hdg) *hexForwardCPLength,
      controlPointB = M.getHdgVector(tipPiece.hdg + dir * math.pi / 3) * -backwardCPLength,
      hdg = tipPiece.hdg + dir * math.pi / 3,
      polyMult = absSize * 1,
      pointsType = 'bezier'
    }
end

--this creates a hexSpiral piece, leading into a hexCurve.
local function squareSpiral(size, inside, dir)

  local inverse = not inside
  local absSize = math.abs(size)

  local off = vec3(absSize * 2, absSize * 1, 0)

  if inverse then
    off:set(absSize * 1, absSize * 2, 0)
  end

  off.x = off.x * sign(dir)
  off = M.rotateVectorByQuat(off, quatFromEuler(0,0,tipPiece.hdg))

  local hexForwardCPLength = math.sqrt(0.75) * absSize
  local backwardCPLength = 1 * absSize
  if inverse then
    backwardCPLength = math.sqrt(0.75) * absSize
    hexForwardCPLength = 1 * absSize
  end
  return
    {
      position = tipPiece.position + off,
      origin = vec3(tipPiece.position),
      controlPointA = M.getHdgVector(tipPiece.hdg) *hexForwardCPLength,
      controlPointB = M.getHdgVector(tipPiece.hdg + dir * math.pi /2) * -backwardCPLength,
      hdg = tipPiece.hdg + dir * math.pi /2,
      polyMult = absSize * 1,
      pointsType = 'bezier'
    }
end

local function freeSpiral(size, inside, dir, angle)

  local inverse = not inside
  local absSize = math.abs(size)


  local off = vec3(1,0.5,0) - vec3(-math.cos(math.pi + angle), math.sin(math.pi + angle) , 0)

  off = off * absSize
  if not inverse then
    off:set(-off.x,off.y, 0)
    off = quatFromEuler(0,0,angle):__mul(off)
  end


  off.x = off.x * sign(dir)
  off = M.rotateVectorByQuat(off, quatFromEuler(0,0,tipPiece.hdg))

  local forwardCPLength
  local backwardCPLength
  if angle <= 15/180 * math.pi then
    forwardCPLength = 0.5
    backwardCPLength = 0.15
  elseif angle <= 30/180 * math.pi then
    forwardCPLength = 0.6
    backwardCPLength = 0.24
  elseif angle <= 45/180 * math.pi then
    forwardCPLength = 0.8
    backwardCPLength = 0.28
  elseif angle <= 60/180 * math.pi then
    forwardCPLength = 0.9
    backwardCPLength = 0.32
  elseif angle <= 75/180 * math.pi then
    forwardCPLength = 1.1
    backwardCPLength = 0.34
  end

  if not inverse then
    local swp = backwardCPLength
    backwardCPLength = forwardCPLength
    forwardCPLength = swp
  end

  backwardCPLength = backwardCPLength * absSize
  forwardCPLength = forwardCPLength * absSize
  return
    {
      position = tipPiece.position + off,
      origin = vec3(tipPiece.position),
      controlPointA = M.getHdgVector(tipPiece.hdg) *forwardCPLength,
      controlPointB = M.getHdgVector(tipPiece.hdg + dir * angle) * -backwardCPLength,
      hdg = tipPiece.hdg + dir * angle,
      polyMult = absSize * 1,
      pointsType = 'bezier'
    }
end




--helper function for the hexLoop calculation. returns point from an euler hexSpiral.
local function fresnelSC(d)
    local point = {x = 0, y = 0}
    if d == 0 then return point end
    local dx, dy

    local oldt = 0
    local current = {}

    local subdivisions = math.max(150,math.floor(d*400))
    if subs then
      subdivisions = subs
    end

    local dt = d/subdivisions

    for i=0, subdivisions-1 do
        local t= (i*d)/subdivisions
        dt = (((i+1)*d)/subdivisions) - t

        oldt = t
        dx = math.cos( t*t * math.pi/2 ) * dt
        dy = math.sin( t*t * math.pi/2 ) * dt
        point= {x = point.x + dx, y = point.y + dy}
    end
    return point
end

--creates a hexLooping.
local function loop(xOffset, radius, isHex)

  if radius < 1 then
    radius = 1
  end

  --create custom points. treat off x/y as 0/0, ignore heading of tipPiece
  --scaling and rotating is done in converting to Spline.
  --make sure that the first point is at -x/-y.
  local numPoints = radius * 7 + math.abs(xOffset*2)
  if numPoints < 48 then
    numPoints = 48
  end
  if numPoints > 300 then
    numPoints = 300
  end
  if numPoints%2 == 1 then
    numPoints = numPoints +1
  end

  local offset = xOffset
  if isHex then
    offset = offset * math.sqrt(3)
  end

  local off = vec3(
      math.sin(tipPiece.hdg) * radius + math.cos(tipPiece.hdg) * offset,
      math.cos(tipPiece.hdg) * radius - math.sin(tipPiece.hdg) * offset,
      0
  )

  --this is the center position of the hexLooping. used for mirroring.
  local cX = M.fresnelSC(math.sqrt(2)).x
  local sclaingFactor = gridScale*radius/(2*cX)
  local customPoints = {}
  --current length of the hexLoop
  local len = 0

  for i = 0, numPoints-1 do
    local t = i/numPoints
    --halfT is the value we plug into the fresnel function.
    local halfT = t
    if t > 0.5 then
      halfT = 1-t
    end
    halfT = halfT * math.sqrt(2) * 2

    local tan = math.atan2(math.sin(halfT*halfT * math.pi/2), math.cos(halfT*halfT*math.pi/2))
    local f = M.fresnelSC(halfT)

    if t > 0.5 then
      f.x = -f.x + 2*cX
      tan = -tan
    end
    local p = {
      position = vec3(
        0,
        -radius+  f.x * (sclaingFactor * heightScale/gridScale),
        f.y*sclaingFactor
        ),
      rot = quatFromEuler(tan,0,0)
    }
    customPoints[i+1] = p

    --calculate some length infos.
    if i > 0 then
      customPoints[i+1].dist = customPoints[i].position:distance(customPoints[i+1].position)
    else
      customPoints[i+1].dist = 0
    end
    if i > 0 then
      len = len + customPoints[i+1].dist
    end
  end
  --after the first pass, add the xOffset and tilt the track to match the offset.
  local currentLen = 0
  for i = 0, numPoints-1 do
    currentLen = currentLen + customPoints[i+1].dist

    local t = currentLen / len
    local off, slope = smoothSlope(t,offset)
    customPoints[i+1].position.x = -offset + off
    local tan = -(math.atan2(len,slope) - math.pi/2)
    local nq = quatFromEuler(0,0,-tan*4):__mul(customPoints[i+1].rot)
    customPoints[i+1].rot = nq
  end

  -- adjust the first point to be exactly where needed.
  customPoints[1] = {
    position = vec3(-offset, -radius, 0),
    rot = quatFromEuler(0,0,0)
  }
  customPoints[#customPoints+1] = {
    position = vec3(0,0, 0),
    rot = quatFromEuler(0,0,0)
  }
  return
    {
      position = tipPiece.position + off,
      origin = vec3(tipPiece.position),
      hdg = tipPiece.hdg,
      polyMult = 4,
      customPoints = customPoints,
      pointsType = 'custom'
    }
end

local function emptyOffset(xOff, yOff, zOff, dirOff, absolute, isHex)

  if absolute then
    local tp = M.splineTrack.getTrackPosition()
    tipPiece.position = vec3(tp.x,tp.y,tp.z)
    tipPiece.hdg = tp.hdg
  end
  local adjustedYOff = yOff

  if isHex and xOff % 2 == 1 then
    adjustedYOff = adjustedYOff + 0.5
  end
  local off = vec3(
      math.sin(tipPiece.hdg) * adjustedYOff + math.cos(tipPiece.hdg) * xOff *  (isHex and math.sqrt(3)/2 or 1),
      math.cos(tipPiece.hdg) * adjustedYOff - math.sin(tipPiece.hdg) * xOff *  (isHex and math.sqrt(3)/2 or 1),
      zOff
  )
  return
    {
      position = tipPiece.position + off,
      origin = vec3(tipPiece.position),
      hdg = tipPiece.hdg + dirOff * math.pi / (isHex and 3 or 2),
      polyMult = 0,
      noPoints = true
    }

end

--helper function to rotate a vector by a quat.
local function rotateVectorByQuat(v, q)
  return q:__mul(v)
end


M.toSegment = toSegment
M.getHdgVector = getHdgVector
M.rotateVectorByQuat = rotateVectorByQuat

--Hex Pieces
M.initialTrackPiece = initialTrackPiece
M.forward = forward
M.curve = curve
M.bezierCurve = bezierCurve
M.offsetCurve = offsetCurve
M.hexSpiral = hexSpiral
M.squareSpiral = squareSpiral
M.fresnelSC = fresnelSC
M.loop = loop
M.emptyOffset = emptyOffset
M.freeSpiral = freeSpiral

M.customBezier = customBezier
M.splineTrack = nil

return M