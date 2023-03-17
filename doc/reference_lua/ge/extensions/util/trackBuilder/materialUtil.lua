-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local materialObjects = {
  center = {},
  border = {}
}
local letters = {"A","B","C","D","E","F","G","H"}

local currentMaterials = {
  A = {
    baseCenterColor = {0.803922,0.803922,0.803922,1},
    baseBorderColor = {0.803922,0.803922,0.803922,1},
    centerColor =  {0,0,0,0.535912},
    borderColor = {0.882353,0.313726,0,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_decal.dds",
    centerGlow = false,
    borderGlow = false,
    groundtype = "ASPHALT"
  },
  B = {
    baseCenterColor = {0.803922,0.803922,0.803922,1},
    baseBorderColor = {0.803922,0.803922,0.803922,1},
    centerColor =  {0,0,0,0.535912},
    borderColor = {0.339012,0.834254,0.207411,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_decal.dds",
    centerGlow = false,
    borderGlow = false,
    groundtype = "ASPHALT"
  },
  C = {
    baseCenterColor = {0.803922,0.803922,0.803922,1},
    baseBorderColor = {0.803922,0.803922,0.803922,1},
    centerColor =  {0,0,0,0.535912},
    borderColor = {0.121547,0.43216,1,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_decal.dds",
    centerGlow = false,
    borderGlow = false,
    groundtype = "ASPHALT"
  },
  D = {
    baseCenterColor = {0.803922,0.803922,0.803922,1},
    baseBorderColor = {0.803922,0.803922,0.803922,1},
    centerColor =  {0,0,0,0.535912},
    borderColor = {0.928177,0.19969,0.102561,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_decal.dds",
    centerGlow = false,
    borderGlow = false,
    groundtype = "ASPHALT"
  },
  E = {
    baseCenterColor = {0.309392,0.309392,0.309392,1},
    baseBorderColor = {0.309392,0.309392,0.309392,1},
    centerColor =  {0.845304,0.417324,0.046702,1},
    borderColor = {0.883978,0.311995,0,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_raw_decal.dds",
    centerGlow = true,
    borderGlow = true,
    groundtype = "ASPHALT"
  },
  F = {
    baseCenterColor = {0.309392,0.309392,0.309392,1},
    baseBorderColor = {0.309392,0.309392,0.309392,1},
    centerColor =  {0.053768,0.823204,0.018192,0.535912},
    borderColor = {0.480693,1,0.121547,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_raw_decal.dds",
    centerGlow = true,
    borderGlow = true,
    groundtype = "ASPHALT"
  },
  G = {
    baseCenterColor = {0.309392,0.309392,0.309392,1},
    baseBorderColor = {0.309392,0.309392,0.309392,1},
    centerColor =  {0,0.702385,1,0.535912},
    borderColor = {0,0.300846,0.850829,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_raw_decal.dds",
    centerGlow = true,
    borderGlow = true,
    groundtype = "ASPHALT"
  },
  H = {
    baseCenterColor = {0.309392,0.309392,0.309392,1},
    baseBorderColor = {0.309392,0.309392,0.309392,1},
    centerColor =  {1,0,0,0.701657},
    borderColor = {0.850829,0.056409,0,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_raw_decal.dds",
    centerGlow = true,
    borderGlow = true,
    groundtype = "ASPHALT"
  }
}

local originalMaterials = {
  A = {
    baseCenterColor = {0.803922,0.803922,0.803922,1},
    baseBorderColor = {0.803922,0.803922,0.803922,1},
    centerColor =  {0,0,0,0.535912},
    borderColor = {0.882353,0.313726,0,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_decal.dds",
    centerGlow = false,
    borderGlow = false,
    groundtype = "ASPHALT"
  },
  B = {
    baseCenterColor = {0.803922,0.803922,0.803922,1},
    baseBorderColor = {0.803922,0.803922,0.803922,1},
    centerColor =  {0,0,0,0.535912},
    borderColor = {0.339012,0.834254,0.207411,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_decal.dds",
    centerGlow = false,
    borderGlow = false,
    groundtype = "ASPHALT"
  },
  C = {
    baseCenterColor = {0.803922,0.803922,0.803922,1},
    baseBorderColor = {0.803922,0.803922,0.803922,1},
    centerColor =  {0,0,0,0.535912},
    borderColor = {0.121547,0.43216,1,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_decal.dds",
    centerGlow = false,
    borderGlow = false,
    groundtype = "ASPHALT"
  },
  D = {
    baseCenterColor = {0.803922,0.803922,0.803922,1},
    baseBorderColor = {0.803922,0.803922,0.803922,1},
    centerColor =  {0,0,0,0.535912},
    borderColor = {0.928177,0.19969,0.102561,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_decal.dds",
    centerGlow = false,
    borderGlow = false,
    groundtype = "ASPHALT"
  },
  E = {
    baseCenterColor = {0.309392,0.309392,0.309392,1},
    baseBorderColor = {0.309392,0.309392,0.309392,1},
    centerColor =  {0.845304,0.417324,0.046702,1},
    borderColor = {0.883978,0.311995,0,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_raw_decal.dds",
    centerGlow = true,
    borderGlow = true,
    groundtype = "ASPHALT"
  },
  F = {
    baseCenterColor = {0.309392,0.309392,0.309392,1},
    baseBorderColor = {0.309392,0.309392,0.309392,1},
    centerColor =  {0.053768,0.823204,0.018192,0.535912},
    borderColor = {0.480693,1,0.121547,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_raw_decal.dds",
    centerGlow = true,
    borderGlow = true,
    groundtype = "ASPHALT"
  },
  G = {
    baseCenterColor = {0.309392,0.309392,0.309392,1},
    baseBorderColor = {0.309392,0.309392,0.309392,1},
    centerColor =  {0,0.702385,1,0.535912},
    borderColor = {0,0.300846,0.850829,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_raw_decal.dds",
    centerGlow = true,
    borderGlow = true,
    groundtype = "ASPHALT"
  },
  H = {
    baseCenterColor = {0.309392,0.309392,0.309392,1},
    baseBorderColor = {0.309392,0.309392,0.309392,1},
    centerColor =  {1,0,0,0.701657},
    borderColor = {0.850829,0.056409,0,1},
    baseTexture = "core/art/trackBuilder/track_editor_base_d.dds",
    baseTextureN = nil,
    baseTextureS = nil,
    centerTexture = "core/art/trackBuilder/track_editor_line_center_decal.dds",
    borderTexture = "core/art/trackBuilder/track_editor_strip_raw_decal.dds",
    centerGlow = true,
    borderGlow = true,
    groundtype = "ASPHALT"
  }
}

local function colorToFloatArray(color)
  local res = {}
  local t = {}
  local i = 1
  for str in string.gmatch(color, "([^' ']+)") do
    t[i] = tonumber(str)
    i = i + 1
  end

  if #t == 4 then
    res = {t[1], t[2], t[3], t[4]}
  elseif #res == 0 then
    --if debug then log('I', logTag, "Get stock color of " .. color) end
    local col = getStockColor(color)
    if col ~= nil then
      col[4] = 1.0
      res = ffi.new("float[4]", col)
    else
      log('E', logTag, "Cannot find stock color " .. color .. "! Fallback to white.")
      res = {1,1,1,1}
    end
  else
    log('E', logTag, "Wrong color value! Fallback to white.")
    res = {1,1,1,1}
  end
  return res
end

local function toBool(val)
  if type(val) == "string" then
    if val == "0" then return false elseif val == "1" then return true end
  elseif type(val) == "number" then
    if val == 0 then return false elseif val == 1 then return true end
  else
    log('E', logTag, "Type " .. type(val) .. " not supported by toBool() function!")
  end
end


local function loadMaterial(l, skipSet)
  --if materialObjects.center[l] == nil or materialObjects.border[l] == nil then
    materialObjects.center[l] = scenetree.findObject("track_editor_" .. l .. '_center')
    materialObjects.border[l] = scenetree.findObject("track_editor_" .. l .. '_border')
    if not skipSet then
      local mat = currentMaterials[l]
      mat.baseCenterColor = colorToFloatArray(materialObjects.center[l]:getField('diffuseColor', 0))
      mat.centerColor     = colorToFloatArray(materialObjects.center[l]:getField('diffuseColor', 1))
      mat.baseBorderColor = colorToFloatArray(materialObjects.border[l]:getField('diffuseColor', 0))
      mat.borderColor     = colorToFloatArray(materialObjects.border[l]:getField('diffuseColor', 1))
      mat.baseTexture     = editor.texObj(materialObjects.center[l]:getField('colorMap', 0)).path
      mat.centerTexture   = editor.texObj(materialObjects.center[l]:getField('colorMap', 1)).path
      mat.borderTexture   = editor.texObj(materialObjects.border[l]:getField('colorMap', 1)).path
      mat.centerGlow      = toBool(materialObjects.center[l]:getField('glow', 1))
      mat.borderGlow      = toBool(materialObjects.border[l]:getField('glow', 1))
      mat.groundtype     = materialObjects.border[l]:getField('groundtype', 0) or "ASPHALT"
    end
  --end
end


local function setTextures(letter, field, texture)
  if texture and field == "colorMap" then
    materialObjects.center[letter]:setField('colorMap', 0, texture)
    materialObjects.border[letter]:setField('colorMap', 0, texture)
  elseif texture and field == "specularMap" then
    materialObjects.center[letter]:setField('specularMap', 0, texture)
    materialObjects.border[letter]:setField('specularMap', 0, texture)
  elseif texture and field == "normalMap" then
    materialObjects.center[letter]:setField('normalMap', 0, texture)
    materialObjects.border[letter]:setField('normalMap', 0, texture)
  elseif texture and field == "centerTexture" then
    materialObjects.center[letter]:setField('colorMap', 1, texture)
  elseif texture and field == "borderTexture" then
    materialObjects.border[letter]:setField('colorMap', 1, texture)
  end

end

local function setColor(letter, field, color)

  local value = string.format('%f %f %f %f', color[1], color[2], color[3], color[4])
  if field == 'center_base' then
    materialObjects.center[letter]:setField('diffuseColor', 0, value)
  elseif field == 'border_base' then
    materialObjects.border[letter]:setField('diffuseColor', 0, value)
  elseif field == 'center_glow' then
    materialObjects.center[letter]:setField('diffuseColor', 1, value)
  elseif field == 'border_glow' then
    materialObjects.border[letter]:setField('diffuseColor', 1, value)
  else
    log('E', 'editortrackbuilder', 'Wrong material type!')
  end
end

local function setGlow(letter, field, active)
  local value
  if active == false then value = '0' elseif active == true then value = '1' end
  if field == 'center' then
    materialObjects.center[letter]:setField('glow', 1, value)
    materialObjects.center[letter]:setField('emissive', 1, value)
  elseif field == 'border' then
    materialObjects.border[letter]:setField('glow', 1, value)
    materialObjects.border[letter]:setField('emissive', 1, value)
  else
    log('E', 'editortrackbuilder', 'Wrong material type!')
  end
end

local function setGroundmodel(letter, groundtype)
  materialObjects.center[letter]:setField('groundtype', 0, groundtype)
  materialObjects.border[letter]:setField('groundtype', 0, groundtype)
end


local function removeDefaults(material,original)
  local ret = {}
  for key, value in pairs(material) do
    if type(material[key]) == "table" then
      local same = true
      for i = 1,4 do
        same = same and math.abs(material[key][i] - original[key][i]) < 0.00001
      end
      if same then
        --
      else
        ret[key] = material[key]
      end
    else
      if material[key] == original[key] then
        --
      else
        ret[key] = material[key]
      end
    end
  end
  return ret
end

local function fillDefaults(material, original)
  for key, value in pairs(original) do
    if material[key] == nil then
      if type(original[key]) == "table" then
        material[key] = {original[key][1],original[key][2],original[key][3],original[key][4]}
      else
        material[key] = original[key]
      end
    end
  end
  return material
end



local function setMaterials(materials, skipSet)
  if not materials then return end
  for letter, mat in pairs(materials) do
    M.setSingleMaterial(letter,fillDefaults(mat,originalMaterials[letter]), skipSet)
  end
end

local function setSingleMaterial(letter, material, skipSet)
  loadMaterial(letter,skipSet)
  setTextures(letter,'colorMap',material.baseTexture)
  setTextures(letter,'specularMap',material.baseTextureS)
  setTextures(letter,'normalMap',material.baseTextureN)
  setTextures(letter,'borderTexture',material.borderTexture)
  setTextures(letter,'centerTexture',material.centerTexture)
  setColor(letter,'center_base',material.baseCenterColor)
  setColor(letter,'border_base',material.baseBorderColor)
  setColor(letter,'center_glow',material.centerColor)
  setColor(letter,'border_glow',material.borderColor)
  setGlow( letter,'center',material.centerGlow)
  setGlow( letter,'border',material.borderGlow)
  setGroundmodel(letter,material.groundtype)


  materialObjects.center[letter]:flush()
  materialObjects.center[letter]:reload()
  materialObjects.border[letter]:flush()
  materialObjects.border[letter]:reload()

  currentMaterials[letter] = material
end

local function resetMaterialsToDefault(letter)
  if not letter then
    setMaterials(originalMaterials)
  else
    loadMaterial(letter)
    dump(currentMaterials[letter])
    setSingleMaterial(letter,originalMaterials[letter])
    dump(currentMaterials[letter])
  end
end

local function getMaterials()
  for _,l in ipairs(letters) do
    loadMaterial(l)
  end
  local ret = {}
  for letter, mat in pairs(currentMaterials) do
    ret[letter] = removeDefaults(mat,originalMaterials[letter])
  end
  return ret
end

M.getMaterials = getMaterials
M.setMaterials = setMaterials
M.setSingleMaterial = setSingleMaterial
M.loadMaterials = loadMaterials
--loadMaterials()
M.currentMaterials = currentMaterials
M.resetMaterialsToDefault = resetMaterialsToDefault
return M