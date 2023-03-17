-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

require("utils")
local M = {}

local function materialLoadStr(str, name, mv)
  local f, err = load("return function () " .. str .. " end", name or str, "t", mv)
  if f then
    return f()
  else
    log("E", "material.init", tostring(err))
    return nop
  end
end

local function switchMaterial(vehicleObj, msc, matname, matState)
  if matname == nil then
    if matState[msc] ~= false then
      matState[msc] = false
      vehicleObj:resetMaterials(msc)
    end
  else
    if matState[msc] ~= matname then
      matState[msc] = matname
      vehicleObj:switchMaterial(msc, matname)
    end
  end
end

local function process(vehicleObj, vehicle)
  -- clean material cache
  local mv = {}

  local triggers = {}
  local triggerList = {}

  local switches = {}

  local deformMeshes = {}
  local matState = {}
  local triggerSet = {}

  -- store the flexbody materials for later usage
  local flexmeshMats = {}
  vehicle.flexbodies = vehicle.flexbodies or {}

  for flexKey, flexbody in pairs(vehicle.flexbodies) do
    local matNamesStr = vehicleObj:getMeshsMaterials(flexbody.mesh)
    if matNamesStr then
      --log('D', "material.init", "flexbody mesh '"..flexbody.mesh.."' contains the following materials: " .. matNamesStr)
      flexmeshMats[flexbody.mesh] = split(trim(matNamesStr), " ")
    end
  end


  -- now the glow map
  if vehicle.glowMap ~= nil then
    for orgMat, gm in pairsByKeys(vehicle.glowMap) do --order not guaranted when reloading GE
      --log('D', "material.init", "getSwitchableMaterial("..orgMat..")")
      local meshStr = vehicleObj:getMeshesContainingMaterial(orgMat)
      --log('D', "material.init", "[glowmap] meshes containing material " .. orgMat .. ": " .. tostring(meshStr))
      local meshes = split(trim(meshStr), " ")
      --if(not meshes or #meshes == 0 or (#meshes == 1 and meshes[1] == '')) then log('E', "material.init", "[glowmap] No meshes containing material " .. orgMat) end
      for meshi, mesh in pairs(meshes) do
        local gmat = deepcopy(gm)
        gmat.orgMat = orgMat

        if mesh == "" then
          goto continue
        end
        gmat.msc = vehicleObj:getSwitchableMaterial(orgMat, gm.off, mesh)

        if gmat.msc >= 0 then
          table.insert(triggers, gmat)
          local switchName = tostring(orgMat) .. "|" .. tostring(mesh)
          --log('D', "material.init", "[glowmap] created materialSwitch '"..switchName.."' [" .. tostring(gmat.msc) .. "] for material " .. tostring(orgMat) .. " on mesh " .. mesh)
          gmat.mesh = mesh
          switches[switchName] = gmat.msc
          local fields = {}
          if gm.simpleFunction then
            local cmd = nil
            if type(gm.simpleFunction) == "string" then
              cmd = gm.simpleFunction
              mv[gm.simpleFunction] = 0
              triggerSet[gm.simpleFunction] = true
            elseif type(gm.simpleFunction) == "table" then
              for fk, fc in pairs(gm.simpleFunction) do
                local s = "(" .. fk .. "*" .. fc .. ")"
                table.insert(fields, s)
                mv[fk] = 0
                triggerSet[fk] = true
              end
              cmd = "(" .. table.concat(fields, " + ") .. ")"
            end
            --if gm.limit then
            --    cmd = 'math.min('..gm.limit..', ('..cmd..'))'
            --end
            gmat.evalFunctionString = "return " .. cmd
            gmat.evalFunction = materialLoadStr(gmat.evalFunctionString, nil, mv)
          elseif gm.advancedFunction and gm.advancedFunction.triggers and gm.advancedFunction.cmd then
            for _, fc in pairs(gm.advancedFunction.triggers) do
              mv[fc] = 0
              triggerSet[fc] = true
            end
            gmat.evalFunctionString = "return (" .. gm.advancedFunction.cmd .. ")"
            gmat.evalFunction = materialLoadStr(gmat.evalFunctionString, nil, mv)
          end
        else
          log("E", "material.init", "[glowmap] failed to create materialSwitch '" .. switchName .. "' for material " .. tostring(k) .. " on mesh " .. tostring(mesh))
        end
        ::continue::
      end
    end
  end

  --log('D', "material.init", "###########################################################################")
  --dump(triggers)
  --dumpTableToFile(triggers, false, "triggers.js")
  --log('D', "material.init", "###########################################################################")
  -- and the deform groups
  local switchTmp = {}

  -- debug helper: list all materials on a mesh:
  --for flexKey, flexbody in pairs(vehicle.flexbodies) do
  --    log('D', "material.init", "flexbody mesh '"..flexbody.mesh.."' contains the following materials: " .. vehicleObj:getMeshsMaterials(flexbody.mesh))
  --end


  for flexKey, flexbody in pairs(vehicle.flexbodies) do
    if flexbody.deformGroup and flexbody.deformGroup ~= "" then
      if flexbody.deformSound and flexbody.deformSound ~= "" then -- cache deform sounds
        deformMeshes[flexbody.deformGroup] = flexbody
      end
      --log('I', "material.init", "found deformGroup "..flexbody.deformGroup.." on flexmesh " .. flexbody.mesh)
      local meshStr = vehicleObj:getMeshesContainingMaterial(flexbody.deformMaterialBase)

      --log('I', "material.init", "[deformgroup] meshes containing material " .. flexbody.deformMaterialBase .. ": " .. tostring(meshStr))
      --log('I', "material.init", "flexbody mesh '"..flexbody.mesh.."' contains the following materials: " .. vehicleObj:getMeshsMaterials(flexbody.mesh))

      for mati, matName in pairs(flexmeshMats[flexbody.mesh]) do
        if matName == "" then
          goto continue
        end
        local switchName = tostring(matName) .. "|" .. tostring(flexbody.mesh)
        local s = switches[switchName]
        if s == nil then
          s = vehicleObj:getSwitchableMaterial(matName, matName, flexbody.mesh)
          if s >= 0 then
          --log('I', "material.init", "[deformgroup] created materialSwitch '"..switchName.."' [" .. tostring(s) .. "] for material " .. tostring(matName) .. " on mesh " .. tostring(flexbody.mesh))
          end
        else
          --log('I', "material.init", "[deformgroup] reused materialSwitch '"..switchName.."' [" .. tostring(s) .. "] for material " .. tostring(matName) .. " on mesh " .. tostring(flexbody.mesh))
        end
        if s and s >= 0 then
          switches[switchName] = s
          if switchTmp[flexbody.deformGroup] == nil then
            switchTmp[flexbody.deformGroup] = {}
          end
          table.insert(switchTmp[flexbody.deformGroup], {switch = s, dmgMat = flexbody.deformMaterialDamaged, mesh = flexbody.mesh, deformGroup = flexbody.deformGroup})
        else
          log("W", "material.init", "[deformgroup] failed to create materialSwitch '" .. switchName .. "' for material " .. tostring(matName) .. " on mesh " .. tostring(flexbody.mesh))
        end
        ::continue::
      end
    end
  end

  -- add flexmesh switches to beam of the same deform group
  if vehicle.beams ~= nil then
    local assignStats = {}

    for i, b in pairs(vehicle.beams) do
      if b.deformGroup then
        local deformGroups = type(b.deformGroup) == "table" and b.deformGroup or {b.deformGroup}
        for _, g in pairs(deformGroups) do
          if switchTmp[g] ~= nil then
            for sk, sv in pairs(switchTmp[g]) do
              if b.deformSwitches == nil then
                b.deformSwitches = {}
              end
              b.deformSwitches[sv.switch] = sv
              switchMaterial(vehicleObj, sv.switch, sv.dmgMat, matState) -- preload dmg material
              if assignStats[g] == nil then
                assignStats[g] = 0
              end
              assignStats[g] = assignStats[g] + 1
            end
          else
            --log('W', "material.init", "deformGroup on beam not found on any flexmesh: "..beam.deformGroup)
          end
        end
      end
    end
  --log('I', "material.init", "available deformGroups:")
  --for k, va in pairs(assignStats) do
  --    log('I', "material.init", " * " .. k .. " on " .. va .. " beams")
  --end
  end

  -- switch all the materials through their states to precompile the shaders so it doesnt lag when the material switches really
  local matSet = {}
  triggerList = {}
  for _, s in pairs(triggers) do
    matSet[s.msc] = s
  end

  for tk, _ in pairs(triggerSet) do
    table.insert(triggerList, tk)
  end

  for _, s in pairs(matSet) do
    if s.on then
      switchMaterial(vehicleObj, s.msc, s.on, matState)
    end
    if s.on_intense then
      switchMaterial(vehicleObj, s.msc, s.on_intense, matState)
    end
    switchMaterial(vehicleObj, s.msc, nil, matState)
  end

  for _, va in pairs(switches) do
    switchMaterial(vehicleObj, va, nil, matState)
  end

  -- prepare data for the vehicle side
  local triggersCopy = deepcopy(triggers)
  for _, t in pairs(triggersCopy) do
    t.evalFunction = nil
  end

  vehicle._materials = {
    mv = mv,
    triggerList = triggerList,
    triggers = triggersCopy,
    matState = matState,
    deformMeshes = deformMeshes,
  }
end

-- public interface
M.process = process

return M
