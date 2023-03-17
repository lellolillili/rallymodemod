-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui


local C = {}

C.name = 'Planet'
C.color = ui_flowgraph_editor.nodeColors.vehicle
C.icon = ui_flowgraph_editor.nodeIcons.vehicle
C.description = 'Sets an vehicles planetary gravity.'
C.category = 'once_p_duration'
C.todo = "Needs further documentation on what each parameter does and how it should be used."

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Defines the id of the vehicle, whose gravity to modify.' },
  { dir = 'in', type = 'vec3', name = 'position', description = 'Defines the position to spawn the planet in.' },
  { dir = 'in', type = 'string', name = 'heightmap', description = 'Defines the heightmap for the planet.' },
  { dir = 'in', type = 'number', name = 'surfaceHeight', description = 'Defines the surface height for the planet.' },
  { dir = 'in', type = 'number', name = 'radius', description = 'Defines the radius of the planet.' },
  { dir = 'in', type = 'number', name = 'mass', description = 'Defines the mass of the planet.' },
}
C.legacyPins = {
  _in = {
    vehID = 'vehId'
  }
}
C.tags = {}
C.gConst = 6.6742 * math.pow(10, -11) --(m3,s-2,kg-1)
function C:init()
  --self.data.clearPlanets = true
  self.data.showDebug = true
end

function C:_executionStopped()
  self:onNodeReset()
end

function C:onNodeReset()
  if self.veh then
    self.veh:queueLuaCommand("obj:setPlanets({})")
    self.veh = nil
  end
  if self.objs then
    for _, obj in ipairs(self.objs) do
      if editor and editor.onRemoveSceneTreeObjects then
        editor.onRemoveSceneTreeObjects({ obj:getId() })
      end
      obj:delete()
    end
    self.objs = nil
  end
end

function C:workOnce()
  if self.pinIn.position.value == nil or self.pinIn.radius.value == nil or self.pinIn.mass.value == nil or math.abs(self.pinIn.radius.value) < 1 then
    return
  end

  local veh
  if self.pinIn.vehId.value then
    veh = scenetree.findObjectById(self.pinIn.vehId.value)
  else
    veh = be:getPlayerVehicle(0)
  end
  self.veh = veh
  --if self.data.clearPlanets then
   -- veh:queueLuaCommand('obj:setPlanet')
 -- end
  local command = 'obj:setPlanets({'
  command = command .. (self.pinIn.position.value[1] or 0)..','..(self.pinIn.position.value[2] or 0)..','..(self.pinIn.position.value[3] or 0)..','
  command = command .. (self.pinIn.radius.value) ..','
  command = command .. (self.pinIn.mass.value)..'})'

  veh:queueLuaCommand(command)



  TorqueScript.eval([[
    singleton Material(procheightmapMat)
{
    mapTo = "procheightmapMat";
    diffuseColor[0] = "0.803922 0.803922 0.803922 1";
    useAnisotropic[0] = "1";
    doubleSided = "0";
    translucentBlendOp = "None";
    materialTag1 = "RoadAndPath";
    materialTag0 = "beamng";

   colorMap[0] = "core/art/trackBuilder/track_editor_mud_d.dds";
     groundType = "DIRT";
};]])

  local r = self.pinIn.radius.value
  local dLength = math.sqrt(2*r*r)
  local sLength = math.sqrt((dLength*dLength)/2)/2
  local cubeGrid = self:heightmapFromPNG(self.pinIn.heightmap.value or "cubemap_small.png")
  --dumpz(cubeGrid,2)
  --dump(cubeGrid)
  local rots = {
    {id = 'u', quat = quatFromEuler(0,0,0)},
    {id = 'f', quat = quatFromEuler(math.pi/2,0,0)},
    {id = 'r', quat = quatFromEuler(0,0,math.pi/2)*quatFromEuler(0,-math.pi/2,0)   },
    {id = 'l', quat = quatFromEuler(0,0,-math.pi/2)*quatFromEuler(0,math.pi/2,0)  },
    {id = 'b', quat = quatFromEuler(0,0,math.pi)*quatFromEuler(-math.pi/2,0,0)  },
    {id = 'd', quat = quatFromEuler(math.pi,0,0)},
  }
  self.objs = {}
  for _, side in ipairs(rots) do
    print("Doing side " .. side.id)
    local square = self:getSquare(cubeGrid, #cubeGrid/3, side.id, sLength)
    local warped = self:warpSphereCubic(self.pinIn.radius.value,square, sLength, self.pinIn.surfaceHeight.value or 1)
    local mesh = self:createheightmapMesh(warped, 5,"procheightmapMat")
    table.insert(self.objs, self:placeObject("testMesh",mesh, vec3(self.pinIn.position.value), side.quat ))
  end


--  local hm = self:heightmapFromPNG(self.pinIn.heightmap.value or "terrain.png",vec3(sLength,sLength, self.pinIn.surfaceHeight.value or 0))

  be:reloadCollision()
end


function C:drawMiddle(builder, style)
  builder:Middle()
  if self.pinIn.position.value == nil or self.pinIn.radius.value == nil or self.pinIn.mass.value == nil or self.pinIn.radius.value < 1 then
    return
  end
  if self.data.showDebug and self.pinIn.position.value then
    local veh
    if self.pinIn.vehId.value then
      veh = scenetree.findObjectById(self.pinIn.vehId.value)
    else
      veh = be:getPlayerVehicle(0)
    end

    if not veh then return end

    local center = vec3(self.pinIn.position.value[1] or 0, self.pinIn.position.value[2] or 0,self.pinIn.position.value[3] or 0)
    local vehPos = veh:getPosition()
    --  print("debug")
    debugDrawer:drawSphere(center, self.pinIn.radius.value or 0, ColorF(0,0,1,0.1))
    debugDrawer:drawText(center, String("Mass: " .. string.format('%0.2E', self.pinIn.mass.value or 0)), ColorF(0,0,0,1))


    debugDrawer:drawLine(center,vehPos,ColorF(0,0,1,0.3))
    local h = center:distance(vehPos)
    local grav = C.gConst * (self.pinIn.mass.value / (h*h))
    debugDrawer:drawText(veh:getPosition(), String("Force: " .. string.format('%0.2E', grav).." | Dist: "..string.format('%0.2E', center:distance(vehPos)) ), ColorF(0,0,0,1))
  end

  if self.pinIn.mass.value and self.pinIn.radius.value then
    local surfaceGravity = C.gConst * (self.pinIn.mass.value / (self.pinIn.radius.value*self.pinIn.radius.value))
    im.Text("Surface Gravity: %0.3f", surfaceGravity)
  end
end

---- PLANET GENERATION STUFF




-- points: 2d array of points
function C:createheightmapMesh(heightmap, uvScale, material)
  local vertices = {}
  local uvs = {}
  local normals = {}
  local faces = {}

  local yCount = #heightmap
  local xCount = #heightmap[2]

  local gridSize = xCount-2

  local points = heightmap

  local normalDict = {}
  for y = 1, yCount do
    normalDict[y] = {}
  end

  uvScale = uvScale or 1

  for y = 2, yCount-1 do

    for x = 2, xCount-1 do
      -- vertex
      table.insert(vertices, {x = points[y][x].x, y = points[y][x].y, z = points[y][x].z})
      --uv
      table.insert(uvs, {u = points[y][x].origX / uvScale, v = points[y][x].origY / uvScale})

      -- smooth normal for every vertex
      local count = 0
      local normal = vec3()
      --if x > 1  and y > 1 then
        normal = normal + self:normalFromPoints(points[y][x], points[y][x-1], points[y-1][x])
        count = count+1
      --end
      --if x > 1 and y < yCount-1 then
        normal = normal + self:normalFromPoints(points[y][x], points[y][x-1], points[y+1][x])
        count = count+1
      --end
      --if x < xCount-1 and y > 1 then
        normal = normal + self:normalFromPoints(points[y][x], points[y][x+1], points[y-1][x])
        count = count+1
      --end
      --if x < xCount-1 and y < yCount-1 then
        normal = normal + self:normalFromPoints(points[y][x], points[y][x+1], points[y+1][x])
        count = count+1
     -- end
      normal = normal/count
      table.insert(normals, normal)

      -- faces
      if y ~= yCount-1 and x ~= xCount-1 then

        local xx = x-1
        local yy = y-1

        local tl = (xx-1) + (yy-1)*gridSize
        local tr = (xx-0) + (yy-1)*gridSize
        local bl = (xx-1) + (yy-0)*gridSize
        local br = (xx-0) + (yy-0)*gridSize
        table.insert(faces, {v = tl, u = tl, n = tl}) -- tl
        table.insert(faces, {v = tr, u = tr, n = tr}) -- tr
        table.insert(faces, {v = bl, u = bl, n = bl}) -- bl


        table.insert(faces, {v = bl, u = bl, n = bl}) -- bl
        table.insert(faces, {v = tr, u = tr, n = tr}) -- tr
        table.insert(faces, {v = br, u = br, n = br}) -- br

      end
    end
  end

  material = material or 'track_editor_A_border'
  local mesh = {
    verts = vertices,
    uvs = uvs,
    normals = normals,
    faces = faces,
    material = material
  }
  return mesh
end

function C:warpSphere(sphereRadius, heightmap, surfaceHeight)
  -- step1: transform coordinates
  local yCount = #heightmap
  local xCount = #heightmap[1]
  for y = 1, yCount do
    for x = 1, xCount do
      local pos = heightmap[y][x]
      local d = vec3(pos.x, pos.y, 0):length()/sphereRadius
      local h = pos.z
      local r = math.atan2(pos.y, pos.x)
      local sphereVec = vec3(math.cos(r) * math.sin(d),  math.sin(r) * math.sin(d), -math.cos(d)) * (sphereRadius-h)
      heightmap[y][x] = {x = sphereVec.x, y = sphereVec.y, z = sphereVec.z, origX = pos.x, origY = pos.y }
    end
  end
  return heightmap
end

function C:warpSphereCubic(sphereRadius, heightmap, cLength, surfaceHeight)
  -- step1: transform coordinates
  local yCount = #heightmap
  local xCount = #heightmap[2]
  local corner = vec3(heightmap[2][2])
  corner.z = 0
  cLength = corner:length()
  local sphereCenter = vec3(0,0, -(cLength/math.sqrt(2)))

  for y = 1, yCount do
    for x = 1, xCount do
      if heightmap[y][x] then
        local pos = heightmap[y][x]
        local d = vec3(pos.x,pos.y,0) - sphereCenter
        local sphereVec = (d:normalized() * (sphereRadius - (pos.z * surfaceHeight)))

        heightmap[y][x] = {x = -sphereVec.x, y = sphereVec.y, z = sphereVec.z, origX = pos.x, origY = pos.y , r = sphereVec:length()}
      end
    end
  end

  return heightmap
end


function C:normalFromPoints(p1, p3, p2)
  local u = vec3(p2)-vec3(p1)
  local v = vec3(p3)-vec3(p1)

  local n = u:cross(v)
  if n.z < 0 then
    n = n * -1
  end
  n = n:normalized()
  return n
end

function C:placeObject(name, mesh, pos, rot)
  name = name or "procObject"
  pos = pos or vec3(0,0,0)
  rot = rot or quat(0,0,0,0)

  pos = vec3(pos)
  rot = rot:toTorqueQuat()

  local proc = createObject('ProceduralMesh')
  proc:registerObject(name)
  proc.canSave = false
  scenetree.MissionGroup:add(proc.obj)
  proc:createMesh({{mesh}})
  proc:setPosition(pos)
  proc:setField('rotation', 0, rot.x .. ' ' .. rot.y .. ' ' .. rot.z .. ' ' .. rot.w)
  proc.scale = vec3(1, 1, 1)



  return proc
end

function C:heightmapFromPNG(path, scale, invertColors)
  local bitmap = GBitmap()
  local col = ColorI(255,255,255,255)
  bitmap:loadFile(path)

  local width = bitmap:getWidth()
  local height = bitmap:getHeight()

  local heightmap = {}

  for y = 1, height do
    local row = {}
    for x = 1, width do
      bitmap:getColor(x-1,y-1,col)
      local z = (col.red + col.blue + col.green) / (3 * 255)
      z = z * (invertColors and 1 or -1)
      row[x] = vec3(x,y,z)
    end
    heightmap[y] = row
  end
  return heightmap
end

  local blLookup = {
    fu = {'u','d', true},
    fr = {'r','l', true},
    fd = {'d','u', false},
    fl = {'l','r', false},

    ru = {'u','r', true},
    rr = {'b','l', true},
    rd = {'d','r', false},
    rl = {'f','r', false},

    bu = {'u','u', true},
    br = {'l','l', true},
    bd = {'d','d', false},
    bl = {'r','r', false},

    lu = {'u','l', true},
    lr = {'f','l', true},
    ld = {'d','l', false},
    ll = {'b','r', false},

    uu = {'b','d', true},
    ur = {'r','u', true},
    ud = {'f','u', false},
    ul = {'l','u', false},

    du = {'f','d', true},
    dr = {'r','d', true},
    dd = {'b','d', false},
    dl = {'l','d', false},
  }

function C:getSquare(grid, size, identifier, dimensions)
  local heightmap = {}
  local border = size+2
  local centerCoordinates = {}
  centerCoordinates.f = vec3(1*size+1,1*size+1)
  centerCoordinates.r = vec3(2*size+1,1*size+1)
  centerCoordinates.b = vec3(3*size+1,1*size+1)
  centerCoordinates.l = vec3(0*size+1,1*size+1)
  centerCoordinates.u = vec3(1*size+1,0*size+1)
  centerCoordinates.d = vec3(1*size+1,2*size+1)


  local borderLine = function(index, grid, info)
    local identifier = info[1]
    local side = info[2]
    local ccw = info[3]
    local startPos = centerCoordinates[identifier]
    index = index -1
    local sOffset = size-1
    local ret = nil
    if ccw then
      if side == 'l' then ret =  grid[startPos.y+index][startPos.x] end
      if side == 'd' then ret =  grid[startPos.y+sOffset][startPos.x+index] end
      if side == 'r' then ret =  grid[startPos.y+sOffset-index][ startPos.x+sOffset] end
      if side == 'u' then ret =  grid[startPos.y][startPos.x+sOffset-index] end
    else
      if side == 'l' then ret =  grid[startPos.y+sOffset-index][startPos.x] end
      if side == 'd' then ret =  grid[startPos.y+sOffset][startPos.x+sOffset-index] end
      if side == 'r' then ret =  grid[startPos.y+index][ startPos.x+sOffset] end
      if side == 'u' then ret =  grid[startPos.y][startPos.x+index] end
    end
    if not ret then print("No RET! " .. index ..  " " .. dumps(startPos) .. dumps(info)) end

    return ret
  end
  local startPos = centerCoordinates[identifier]
  dump(startPos)
  for y = 1, size+2 do
    heightmap[y] = {}
    for x = 1, size+2 do

      if x == 1 then
        if y > 1 and y < border then
          heightmap[y][x] = borderLine(y-1,grid,blLookup[identifier..'l'])
        end
      elseif x == border then
        if y > 1 and y < border then
          heightmap[y][x] = borderLine(y-1,grid,blLookup[identifier..'r'])
        end
      elseif y == 1 then
        if x > 1 and x < border then
          heightmap[y][x] = borderLine(x-1,grid,blLookup[identifier..'u'])
        end
      elseif y == border then
        if x > 1 and x < border then
          heightmap[y][x] = borderLine(x-1,grid,blLookup[identifier..'d'])
        end
      else
        heightmap[y][x] = grid[startPos.y + y -2][startPos.x + x-2]
      end
    end
  end
  --dump(heightmap)

  local curDim =  size-1

  local scl = (dimensions) / (curDim)--+0.5)
  for y = 1, size+2 do
    for x = 1, size+2 do
      if heightmap[y][x] then
        heightmap[y][x].x =(x-2) * scl - (dimensions)/2---1)/2
        heightmap[y][x].y =(y-2) * scl - (dimensions)/2---1)/2
      end
    end
  end
  --dump(heightmap)
  return heightmap
end

local function test()
  TorqueScript.eval([[
    singleton Material(procheightmapMat)
{
    mapTo = "procheightmapMat";
    diffuseColor[0] = "0.803922 0.803922 0.803922 1";
    useAnisotropic[0] = "1";
    doubleSided = "0";
    translucentBlendOp = "None";
    materialTag1 = "RoadAndPath";
    materialTag0 = "beamng";

   colorMap[0] = "core/art/trackBuilder/track_editor_mud_d.dds";
     groundType = "DIRT";
};]])

  local hm = M.heightmapFromPNG("terrain.png",vec3(500,500,30))
  hm = M.warpSphere(250, hm)
  print("Successfully warped")
  local mesh = M.createheightmapMesh(hm, 10,"procheightmapMat")
  local obj = M.placeObject("testMesh",mesh, vec3(400,300,1000) )
end

-- end--


return _flowgraph_createNode(C)
