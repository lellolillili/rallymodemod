-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- module that deals with particles

local M = {}
local materials
local materialsMap

local function getMaterialByID(mats, i)
    if i == nil then return nil end
    return mats[i]
end

local function getMaterialIDByName(mats, s)
    for k,v in pairs(mats) do
        --print(" "..s.." == "..v.name)
        if s == v.name then
            return k
        end
    end

    --log('W', "particles.getMaterialIDByName", "unknown material: " .. tostring(s))
    -- creating temp definition
    local m = {
        colorB = 255,
        colorG = 255,
        colorR = 255,
        dynamic = true,
        name = s
    }
    table.insert(mats, m)
    return #mats - 1
end

local function particleLoadStr(str, name)
    local f, err = loadstring("return function (arg) " .. str .. " end", name or str)
    if f then return f() else return f, err end
end

local function preloadParticlesTable()
    local mix = readDictJSONTable("lua/common/particles.json")

    --dump(mix)

    local particles = mix.particles
    materials = mix.materials
    materialsMap = {}

    -- 0 = simple equals, 1 = expression
    --comparefields = {materialID1=0, materialID2=0, perpendicularVel=1, slipVel=1} -- material ids by the dict
    local comparefields = {perpendicularVel=1, slipVel=1}

    -- fix the constants
    for k,v in pairs(particles) do
        v.materialID1 = getMaterialIDByName(materials, v.materialID1)
        v.materialID2 = getMaterialIDByName(materials, v.materialID2)

        -- exchange in a clever way
        if v.materialID2 > v.materialID1 then
            local tmp = v.materialID1
            v.materialID1 = v.materialID2
            v.materialID2 = tmp
        end

        -- construct the comparison string
        local fields = {}
        for kc,vc in pairs(comparefields) do
            if v[kc] ~= "" then
                --print("kc: "..tostring(kc) .. " / " .. v[kc])
                local s = ""
                if vc == 0 then
                    -- simple compare
                    s = "arg."..kc.."=="..v[kc]
                elseif vc == 1 then
                    -- expression
                    s = v[kc]:gsub("X", "arg."..kc)
                end
                table.insert(fields, s)
            end
        end
        v.compareFuncStr = table.concat(fields, " and ")
        if v.compareFuncStr == nil then
            -- always true if no filters
            v.compareFuncStr = "true"
        end

        -- parse it
        local err = nil
        v.compareFunc, err = particleLoadStr("return " .. v.compareFuncStr)
        if err then
            log('W', "particles.getMaterialsParticlesTable", "### Fatal Particle comparison parsing error:")
            log('W', "particles.getMaterialsParticlesTable", "### " .. compareFuncStr)
            log('W', "particles.getMaterialsParticlesTable", "### " .. tostring(err))
        end

        local mKey = v.materialID1 * 10000 + v.materialID2
        if materialsMap[mKey] == nil then
            materialsMap[mKey] = {}
        end

        table.insert(materialsMap[mKey], v)
        --[[
        -- example call:
        p = {}
        p.slipVel = 12
        p.perpendicularVel = 1

        print("###"..compareFuncStr.. " = " .. tostring(v.compareFunc(p)).."")
        ]]--
    end
    --dump(materialsMap)
end

local function getMaterialsParticlesTable()
    return materials, materialsMap
end

preloadParticlesTable()

-- public interface
M.getMaterialByID            = getMaterialByID
M.getMaterialIDByName        = getMaterialIDByName
M.getMaterialsParticlesTable = getMaterialsParticlesTable

return M