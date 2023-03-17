--[[
This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
If a copy of the bCDDL was not distributed with this
file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
This module contains a set of functions which manipulate behaviours of vehicles.
]]

local M = {}

local jbeamUtils = require("jbeam/utils")

local function translationWorldToPropAxis(trans, inLocalSpace, refPos, refXPos, refYPos)
  local nx = refXPos - refPos
  local ny = refYPos - refPos
  local nz = ny:cross(nx)

  if inLocalSpace then
    nx:normalize()
    ny:normalize()
  end
  nz:normalize()

  local mat = MatrixF(true)
  mat:setColumn(0, nx)
  mat:setColumn(1, ny)
  mat:setColumn(2, nz)
  mat:inverse()

  return mat:mulP3F(trans)
end

local function parseColor(v)
  if v == nil then
    return ColorF(0,0,0,0)
  end
  if type(v) == 'table' then
    return ColorF(v.r / 255, v.g / 255, v.b / 255, v.a / 255)
  elseif type(v) == 'string' and string.len(v) > 7 and v:sub(1,1) == '#' then
    v = v:gsub("#","")
    return ColorF(tonumber("0x"..v:sub(1,2)) / 255, tonumber("0x"..v:sub(3,4)) / 255, tonumber("0x"..v:sub(5,6)) / 255, tonumber("0x"..v:sub(7,8)) / 255)
  end
end


local function processTris(objID, vehicleObj, vehicle)
  if vehicleObj and vehicle.triangles then
    for _, triangle in pairs(vehicle.triangles) do
      -- skip denormalized tris
      if triangle.id1 ~= triangle.id2 and triangle.id1 ~= triangle.id3 and triangle.id2 ~= triangle.id3 then
        vehicleObj:addPhysicsTriangle(triangle.id1, triangle.id2, triangle.id3)
      end
    end
  end
end

local function processProps(objID, vehicleObj, vehicle)
  profilerPushEvent('processProps')
  local disableSteeringProp = settings.getValue("disableSteeringwheel")
  if disableSteeringProp == nil then disableSteeringProp = false end
  if vehicle.props ~= nil and vehicleObj then
    local prop_count = 0
    for propKey, prop in pairs(vehicle.props) do
      if disableSteeringProp and prop.func == 'steering' then
        log('I', 'jbeam.pushToPhysics', 'removed steering wheel prop due to settings')
        prop.disabled = true
        goto continue
      end

      if not (prop.idRef and prop.idX and prop.idY) then
        log('E', 'jbeam.pushToPhysics', 'prop IDs not set '.. tostring(prop.mesh))
        goto continue
      end
      if not prop.translation then
        log('E', 'jbeam.pushToPhysics', 'prop translation not set: '.. tostring(prop.mesh))
        goto continue
      end
      if not prop.rotation then
        log('E', 'jbeam.pushToPhysics', 'prop rotation not set: '.. tostring(prop.mesh))
        goto continue
      end

      local pid = vehicleObj:addProp(prop.originalMesh or prop.mesh) -- originalMesh is here so we can feed the same data again
      if pid < 0 then
        log('E', 'jbeam.pushToPhysics', 'unable to prop: '.. tostring(prop.mesh))
        goto continue
      end
      prop.pid = pid
      local p = vehicleObj:getProp(pid)
      if p ~= nil then
        if prop.mesh ~= p:getMeshName() then
          --print("GE renamed the prop mesh: " .. tostring(prop.mesh) .. ' > ' .. tostring(p:getMeshName()))
          prop.originalMesh = prop.mesh
          prop.mesh = p:getMeshName()
        end

        prop_count = prop_count + 1
        -- now clean up the input data

        local idRef, idX, idY = tonumber(prop.idRef), tonumber(prop.idX), tonumber(prop.idY)

        -- Set prop ref nodes first since stuff below is dependent on this
        p:setRefNodes(idRef, idX, idY)

        -- Prop translation
        p:setTranslation(vec3(prop.translation))

        if prop.translationGlobal then
          prop.translation = translationWorldToPropAxis(
            vec3(prop.translationGlobal),
            false,
            vehicle.nodes[idRef].pos,
            vehicle.nodes[idX].pos,
            vehicle.nodes[idY].pos
          )
        end

        -- Prop base translation (optional)
        if prop.baseTranslation then
          p:setBaseTranslation(vec3(prop.baseTranslation))
        end
        if prop.baseTranslationGlobal then
          p:setBaseTranslationGlobal(vec3(prop.baseTranslationGlobal))
        end
        if prop.baseTranslationGlobalElastic then
          p:setBaseTranslationGlobalElastic(vec3(prop.baseTranslationGlobalElastic))
        end
        if prop.baseTranslationGlobalRigid then
          p:setBaseTranslationGlobalRigid(vec3(prop.baseTranslationGlobalRigid))
        end

        -- Prop translation offset (optional)
        if prop.translationOffset then
          p:setTranslationOffset(vec3(prop.translationOffset))
        end
        -- translate everything for testing:
        --if prop.translationOffset == nil then prop.translationOffset = {x=0, y=0, z=-2} end

        local rotDeg = vec3(prop.rotation)
        prop.rotation = vec3(math.rad(rotDeg.x), math.rad(rotDeg.y), math.rad(rotDeg.z))
        p:setRotation(prop.rotation)

        --[[
        if prop.rotationGlobal then
          rotDeg = vec3(prop.rotationGlobal)
          prop.rotationGlobal = vec3(math.rad(rotDeg.x), math.rad(rotDeg.y), math.rad(rotDeg.z))
          p:setRotationGlobal(prop.rotationGlobal)
        end
        ]]--
        -- baseRotation (optional)
        if prop.baseRotation then
          prop.baseRotation = vec3(math.rad(prop.baseRotation.x), math.rad(prop.baseRotation.y), math.rad(prop.baseRotation.z))
          p:setBaseRotation(prop.baseRotation)
        end
        if prop.baseRotationGlobal then
          prop.baseRotationGlobal = vec3(math.rad(prop.baseRotationGlobal.x), math.rad(prop.baseRotationGlobal.y), math.rad(prop.baseRotationGlobal.z))
          p:setBaseRotationGlobal(prop.baseRotationGlobal)
        end

        if prop.min == nil then prop.min = 0 end
        if prop.max == nil then prop.max = 100 end
        if prop.offset == nil then prop.offset = 0 end
        if prop.multiplier == nil then prop.multiplier = 1 end

        p:setVisible(true)
        p:setDataValue(0)

        prop.slotID = pid
        if prop.mesh == "SPOTLIGHT" or prop.mesh == "POINTLIGHT" then
          local plight = p:getLight()
          if not plight then
            log('E', 'jbeam.pushToPhysics', 'unable to create light for prop:'.. dumps(prop))
          else
            -- try to set the light options then
            local innerAngle = prop.lightInnerAngle or 40
            local outerAngle = prop.lightOuterAngle or 45
            local brightness = prop.lightBrightness or 1
            local range = prop.lightRange or 10
            local castShadows = prop.lightCastShadows or false
            local flareName = prop.flareName or 'vehicleDefaultLightflare'
            local flareScale = prop.flareScale or 1
            local cookieName = prop.cookieName or ''
            local animationType = prop.animationType or ''
            local animationPeriod = prop.animationPeriod or 1
            local animationPhase = prop.animationPhase or 1
            local texSize = prop.texSize or 256
            local shadowSoftness = prop.shadowSoftness or 1

            local color = ColorF(0, 0, 0, 0)
            if prop.lightColor then color = parseColor(prop.lightColor) end

            local attenuation = vec3(0, 1, 1)
            if prop.lightAttenuation then attenuation = vec3(prop.lightAttenuation) end
            plight:setLightArgs(innerAngle, outerAngle, brightness, range, color, attenuation, castShadows)
            plight:setLightArgs2(flareName, flareScale, cookieName, animationType, animationPeriod, animationPhase, texSize, shadowSoftness)
          end
        end
      end
      ::continue::
    end
    --log('D', "jbeam.pushToPhysics","- added ".. prop_count .." props")
  end
  profilerPopEvent()
end

local function processFlexbodies(objID, vehicleObj, vehicle)
  profilerPushEvent('processFlexbodies')
  local flexmesh_count = 0
  if vehicle.flexbodies ~= nil and vehicleObj then
    for flexKey, flexbody in pairs(vehicle.flexbodies) do
      local flexnodeCount = #flexbody['_group_nodes']
      if flexnodeCount > 0 then
        local fid = vehicleObj:addFlexmesh(flexbody.originalMesh or flexbody.mesh) -- originalMesh is here so we can feed the same data again
        if fid < 0 then
          log('E', "jbeam.pushToPhysics","unable to create flexmesh: " .. tostring(flexbody.mesh))
          goto continue
        end
        flexbody.fid = fid
        local f = vehicleObj:getFlexmesh(fid)
        if f ~= nil then
          -- check if GE renamed the mesh and update our references accordingly
          if flexbody.mesh ~= f:getMeshName() then
            --print("GE renamed the flexbody mesh: " .. tostring(flexbody.mesh) .. ' > ' .. tostring(f:getMeshName()))
            flexbody.originalMesh = flexbody.mesh
            flexbody.mesh = f:getMeshName()
          end
          flexmesh_count = flexmesh_count + 1
          local flexnodes = flexbody['_group_nodes']
          for k = 1, flexnodeCount do
            f:addNodeBinding(flexnodes[k])
          end
          if flexbody.pos ~= nil or flexbody.rot ~= nil or flexbody.scale ~= nil then
            local pos
            if flexbody.pos then
              pos = vec3(tonumber(flexbody.pos.x), tonumber(flexbody.pos.y), tonumber(flexbody.pos.z))
            else
              pos = vec3(0,0,0)
            end

            local rotDeg
            if flexbody.rot then
              rotDeg = vec3(tonumber(flexbody.rot.x), tonumber(flexbody.rot.y), tonumber(flexbody.rot.z))
            else
              rotDeg = vec3(0,0,0)
            end
            local rotRad = vec3(math.rad(rotDeg.x), math.rad(rotDeg.y), math.rad(rotDeg.z))

            local scale
            if flexbody.scale then
              scale = vec3(tonumber(flexbody.scale.x), tonumber(flexbody.scale.y), tonumber(flexbody.scale.z))
            else
              scale = vec3(1,1,1)
            end

            --log('D', "jbeam.pushToPhysics","setInitialTransformation: " .. flexbody.mesh .. " = " .. tostring(pos) .. ", ".. tostring(rot) .. ", " .. tostring(scale))

            f:setInitialTransformation(pos, rotRad, scale, flexbody.flatMap or false)
          end
          --f:initialize()
        else
          log('E', "jbeam.pushToPhysics", "unable to create flexmesh: " .. flexbody.mesh)
        end
      else
        --log('D', "jbeam.pushToPhysics", "flexmesh has no node bindings, ignoring: " .. flexbody.mesh)
      end
      ::continue::
    end
  end
  profilerPopEvent()
end


local function process(objID, vehicleObj, vehicle)
  profilerPushEvent('jbeam/meshs.process')
  if vehicle.flexbodies ~= nil then
    for _, v in pairs(vehicle.flexbodies) do
      if v.nodeOffset and type(v.nodeOffset) == 'table' and v.nodeOffset.x and v.nodeOffset.y and v.nodeOffset.z then
        v.pos = v.pos or {x = 0, y = 0, z = 0}
        local nodeOffsetCoef = v.ignoreNodeOffset and 0 or 1
        v.pos.x = v.pos.x + fsign(v.pos.x) * v.nodeOffset.x * nodeOffsetCoef
        v.pos.y = v.pos.y + v.nodeOffset.y * nodeOffsetCoef
        v.pos.z = v.pos.z + v.nodeOffset.z * nodeOffsetCoef
      end
      if v.nodeMove and type(v.nodeMove) == 'table' and v.nodeMove.x and v.nodeMove.y and v.nodeMove.z then
        v.pos = v.pos or {x = 0, y = 0, z = 0}
        v.pos.x, v.pos.y, v.pos.z = v.pos.x + v.nodeMove.x, v.pos.y + v.nodeMove.y, v.pos.z + v.nodeMove.z
      end
    end
  end

  -- request the 3d meshes for faster processing on the c++ side
  -- make sure we use the same directories for the dae files, etc
  if vehicleObj then
    vehicleObj:clearResourceSearchPath()
    for _, d in ipairs(vehicle.directoriesLoaded or {}) do
      vehicleObj:addResourceSearchPath(d)
    end
  end

  local reuseMesh = false
  if vehicleObj then
    vehicleObj:requestMeshBegin()
    if vehicle.props ~= nil then
      for _, prop in pairs(vehicle.props) do
        if prop.mesh ~= "SPOTLIGHT" and prop.mesh ~= "POINTLIGHT" then
          vehicleObj:requestMesh(prop.mesh)
        end
      end
    end
    if vehicle.flexbodies ~= nil then
      for _, flexbody in pairs(vehicle.flexbodies) do
        vehicleObj:requestMesh(flexbody.mesh)
      end
    end
    reuseMesh = (vehicleObj:requestMeshCommit() == 1)
  end

  processTris(objID, vehicleObj, vehicle)
  processProps(objID, vehicleObj, vehicle)
  processFlexbodies(objID, vehicleObj, vehicle)

  if vehicleObj then
    vehicleObj:meshCommit()
  end
  profilerPopEvent() -- jbeam/meshs.process
end

M.process = process

return M