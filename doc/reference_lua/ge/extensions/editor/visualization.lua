-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.dependencies = {'editor_aiEditor'} -- Having this dependency is not nice, but it's the easiest way to have navgraph vis in here as well as in the ai editor
local logTag = 'editor_visualization'
local im = ui_imgui
local toolWindowName = "visualization"

local var = {}
var.visualizationTypesDefault = {}
var.visibleTypesDefault = {}
var.selectableTypesDefault = {}

local vizFilter = im.ImGuiTextFilter()

local materialDebugVisualizationType = im.IntPtr(0)
local materialDebugVisualizationTypes = nil

local function updateVisSettings()
  local tbl = {}
  for _, type in ipairs(editor.getVisualizationTypes()) do
    local active = editor.getVisualizationType(type.name)
    tbl[type.name] = active
  end
  editor.setPreference("gizmos.visualization.visTypes", tbl)
end

local function drawResetButton(itemPath)
  im.Spacing(im.ImVec2(0, 0))
  local prefWindowCurrWidth = im.GetContentRegionAvailWidth();
  im.SameLine(prefWindowCurrWidth - 133 * im.uiscale[0])
  if im.Button("Reset To Defaults") then
    im.OpenPopup("Reset To Defaults")
  end
  if im.IsItemHovered() then im.SetTooltip("Reset all preferences in this tab to their default values") end
  -- Reset confirmation
  if im.BeginPopupModal("Reset To Defaults", nil, im.WindowFlags_AlwaysAutoResize) then
    im.Text("Do you really want to reset all preferences in this tab to default values ?\n"..
               "Warning: This operation is not undoable.\n\n\n")
               im.Separator()
    if im.Button("Yes", im.ImVec2(120,0)) then
      im.CloseCurrentPopup()
      local item = editor.preferencesRegistry:findItem(itemPath)
      if itemPath == "gizmos.visualization.visTypes" then
        editor.setPreference(itemPath, deepcopy(var.visualizationTypesDefault))
      elseif itemPath == "gizmos.visualization.visible" then
        editor.setPreference(itemPath, deepcopy(var.visibleTypesDefault))
      elseif itemPath == "gizmos.visualization.selectable" then
        editor.setPreference(itemPath, deepcopy(var.selectableTypesDefault))
      end
    end
    im.SameLine()
    if im.Button("No", im.ImVec2(120,0)) then im.CloseCurrentPopup() end
    im.EndPopup()
  end
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Visualization") then
    --  Viz type filter search box
    im.Text("Filter Types:")
    im.SameLine()
    im.PushID1("VizSearchFilter")
    if editor.uiInputSearchTextFilter("##vizSearchFilter", vizFilter, im.GetContentRegionAvailWidth(), nil) then
      if ffi.string(im.TextFilter_GetInputBuf(vizFilter)) == "" then
        im.ImGuiTextFilter_Clear(vizFilter)
      end
    end
    im.PopID()
    if im.IsItemHovered() then im.SetTooltip("Filter Types") end
    -- Filter validator
    local filterQuery = string.gsub(ffi.string(im.TextFilter_GetInputBuf(vizFilter)), "[^%w_]+", " ")   -- sanitize
    filterQuery = string.gsub(filterQuery, "^%s*(.-)%s*$", "%1")  -- trim edges
    local filterTokens = {}
    for token in string.gmatch(filterQuery, "[%w_]+") do  -- split
      table.insert(filterTokens, string.lower(token))     -- lower case
    end
    local displayType = function(type, debug)
      if #filterTokens == 0 then return true end  -- #NoFilter :3
      for _, token in ipairs(filterTokens) do
        --  lower case matching
        if debug and (string.match(string.lower(type.name), token)
            or string.match(string.lower(type.displayName), token)) then
          return true
        elseif not debug and string.match(string.lower(type), token) then
          return true
        end
      end
      return false
    end
    --  Tabs
    local tabNo = 1
    if im.BeginTabBar("decal editor##") then
      if im.BeginTabItem("Debug") then
        tabNo = 1
        im.EndTabItem()
      end
      if im.BeginTabItem("Visible") then
        tabNo = 2
        im.EndTabItem()
      end
      if im.BeginTabItem("Selectable") then
        tabNo = 3
        im.EndTabItem()
      end
      im.EndTabBar()
    end

    im.BeginChild1("visTypes")
    local nItems = 0    -- Items count
    if tabNo == 1 then
      drawResetButton("gizmos.visualization.visTypes")

      if displayType({name = "MaterialDebug", displayName = "Material Debug"}, true) then
        local materialDebugVisualizationTypeNames = {}
        for _,v in ipairs(materialDebugVisualizationTypes) do
          table.insert(materialDebugVisualizationTypeNames, v.displayName)
        end

        if im.Combo1("Material Debug", materialDebugVisualizationType, im.ArrayCharPtrByTbl(materialDebugVisualizationTypeNames)) then
          materialDebugVisualizationTypes[(materialDebugVisualizationType[0] + 1)].setter()
        end
        if materialDebugVisualizationTypes[(materialDebugVisualizationType[0] + 1)].info then
          materialDebugVisualizationTypes[(materialDebugVisualizationType[0] + 1)].info()
          im.Separator()
        end
      end

      local tbl = {}
      for _, type in ipairs(editor.getVisualizationTypes()) do
        local active = im.BoolPtr(editor.getVisualizationType(type.name))
        if displayType(type, true) then
          nItems = nItems + 1
          if im.Checkbox(type.displayName, active) then
            editor.setVisualizationType(type.name, active[0])
            updateVisSettings()
          end
        end
      end
    end
    if tabNo == 2 then
      drawResetButton("gizmos.visualization.visible")
      local classes = worldEditorCppApi.getObjectClassNames()
      for _, name in ipairs(classes) do
        local visible = im.BoolPtr(editor.getObjectTypeVisible(name))
        if displayType(name) then
          nItems = nItems + 1
          if im.Checkbox(name, visible) then
            editor.setObjectTypeVisible(name, visible[0])
            editor.getPreference("gizmos.visualization.visible")[name] = visible[0]
            if editor.getPreference("gizmos.visualization.saveVisualizationSettings") then
              editor.savePreferences()
            end
          end
        end
      end
    end
    if tabNo == 3 then
      drawResetButton("gizmos.visualization.selectable")
      local classes = worldEditorCppApi.getObjectClassNames()
      for _, name in ipairs(classes) do
        local selectable = im.BoolPtr(editor.getObjectTypeSelectable(name))
        if displayType(name) then
          nItems = nItems + 1
          if im.Checkbox(name, selectable) then
            editor.setObjectTypeSelectable(name, selectable[0])
            editor.getPreference("gizmos.visualization.selectable")[name] = selectable[0]
            if editor.getPreference("gizmos.visualization.saveVisualizationSettings") then
              editor.savePreferences()
            end
          end
        end
      end
    end
    if nItems == 0 then
      im.Text("No match")
    end
    im.EndChild()
  end
  editor.endWindow()
end

local function onEditorPreferenceValueChanged(path, value)
  if path == "gizmos.visualization.visTypes" then
    for _, type in ipairs(editor.getVisualizationTypes()) do
      if value[type.name] ~= nil then
        editor.setVisualizationType(type.name, value[type.name])
      else
        -- just set this viz to false, clearing it
        editor.setVisualizationType(type.name, false)
      end
    end
  end

  if path == "gizmos.visualization.visible" then
    for _, name in ipairs(worldEditorCppApi.getObjectClassNames()) do
      if value[name] ~= nil then
        editor.setObjectTypeVisible(name, value[name])
      end
    end
  end

  if path == "gizmos.visualization.selectable" then
    for _, name in ipairs(worldEditorCppApi.getObjectClassNames()) do
      if value[name] ~= nil then
        editor.setObjectTypeSelectable(name, value[name])
      end
    end
  end

  if path == "gizmos.visualization.saveVisualizationSettings" then
    if value then
      editor.preferencesRegistry:removeNonPersistentItemPath("gizmos.visualization.visTypes")
      editor.preferencesRegistry:removeNonPersistentItemPath("gizmos.visualization.visible")
      editor.preferencesRegistry:removeNonPersistentItemPath("gizmos.visualization.selectable")
    else
      editor.preferencesRegistry:addNonPersistentItemPath("gizmos.visualization.visTypes")
      editor.preferencesRegistry:addNonPersistentItemPath("gizmos.visualization.visible")
      editor.preferencesRegistry:addNonPersistentItemPath("gizmos.visualization.selectable")
    end
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  local classes = worldEditorCppApi.getObjectClassNames()
  for _, name in ipairs(classes) do
    local visible = im.BoolPtr(editor.getObjectTypeVisible(name))
    local selectable = im.BoolPtr(editor.getObjectTypeSelectable(name))
    var.visibleTypesDefault[name] = visible
    var.selectableTypesDefault[name] = selectable
  end

  prefsRegistry:registerCategory("gizmos")
  prefsRegistry:registerSubCategory("gizmos", "visualization", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    -- hidden
    {visTypes = {"table", {}, "", nil, nil, nil, true}},
    {visible = {"table", {}, "", nil, nil, nil, true}},
    {selectable = {"table", {}, "", nil, nil, nil, true}},
    {saveVisualizationSettings = {"bool", true, "Persistent Visualization Settings"}},
  })
end

local function createRenderModeSetter(objName, varName, functionName)
  return function(on)
    local boolToNumber = on and "1" or "0"
    setConsoleVariable(varName, boolToNumber)
    if _G["toggleLightVisualizer"] then
      _G["toggleLightVisualizer"](objName, on, varName)
    end
  end
end

local function registerNavgraphVisualization(tpe, name)
  editor.registerVisualizationType(
    {type = editor.varTypes.Custom, name = "drawNavGraph"..tpe, displayName = "Navgraph: "..name,
     setter = function(on) editor_aiEditor.enableDrawMode(tpe, on)   end,
     getter = function() return editor_aiEditor.getDrawMode() == tpe end})
end

local renderDebugFlags = {
  FlagsDebugNone = 0,
  FlagsDebugBaseColor = bit.lshift(1,0),
  FlagsDebugOpacity = bit.lshift(1,1),
  FlagsDebugMetallic = bit.lshift(1,2),
  FlagsDebugRoughness = bit.lshift(1,3),
  FlagsDebugAmbientOcclusion = bit.lshift(1,4),
  FlagsDebugClearCoat = bit.lshift(1,5),
  FlagsDebugClearCoatRoughness = bit.lshift(1,6),
  FlagsDebugUV0 = bit.lshift(1,7),
  FlagsDebugUV0Checkerboard = bit.lshift(1,8),
  FlagsDebugUV0ColorGrid = bit.lshift(1,9),
  FlagsDebugUV1 = bit.lshift(1,10),
  FlagsDebugUV1Checkerboard = bit.lshift(1,11),
  FlagsDebugUV1ColorGrid = bit.lshift(1,12),
  FlagsDebugMaterialDeprecated = bit.lshift(1,13),
  FlagsDebugLayerCount = bit.lshift(1,14),
  FlagsDebugNormalsWS = bit.lshift(1,15),
  FlagsDebugEmissive = bit.lshift(1,16),
}

local function materialDebugSetter(flag)
  materialDebugSetFlag(flag)
  if flag == renderDebugFlags.FlagsDebugNone then
    enableMaterialDebug(false)
  else
    enableMaterialDebug(true)
  end
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(500,600))
  editor.clearVisualizationTypes()
  editor.registerVisualizationType({type = editor.varTypes.Setting, name = "BeamNGWaypointDrawDebug", displayName = "BeamNG: draw waypoints"})
  registerNavgraphVisualization('type', 'Road Type')
  registerNavgraphVisualization('drivability', 'Road Drivability')
  registerNavgraphVisualization('speedLimit', 'Speed Limit')
  editor.registerVisualizationType({type = editor.varTypes.Setting, name = "DebugDrawDrawAdvancedText", displayName = "Advanced text drawing"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "GFXDevice.renderWireframe", displayName = "Wireframe Mode"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "SceneManager.renderBoundingBoxes", displayName = "Bounding Boxes"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "SceneManager.lockFrustum", displayName = "Frustum Lock"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "SFXEmitter.renderEmitters", displayName = "Sound Emitters"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "SFXEmitter.renderFarEmitters", displayName = "Far Sound Emitters"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "BeamNGTrigger.drawTriggers", displayName = "Triggers"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "TerrainBlock.debugRender", displayName = "Terrain"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "Engine.Render.DecalMgr.debugRender", displayName = "Decals"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "LightShadowMap.renderFrustums", displayName = "Light Frustums"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "SceneCullingState.disableZoneCulling", displayName = "Disable Zone Culling"})
  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "SceneCullingState.disableTerrainOcclusion", displayName = "Disable Terrain Occlusion"})

  -- TODO These are not used. Can be removed?
  --editor.registerVisualizationType({type = editor.varTypes.ConVar, name = "$SFXSpace::isRenderable", displayName = "Render: Sound Spaces"})
  --editor.registerVisualizationType({type = editor.varTypes.ConVar, name = "$Zone::isRenderable", displayName = "Zones"})
  --editor.registerVisualizationType({type = editor.varTypes.ConVar, name = "$Portal::isRenderable", displayName = "Portals"})
  --editor.registerVisualizationType({type = editor.varTypes.ConVar, name = "$OcclusionVolume::isRenderable", displayName = "Occlusion Volumes"})
  --editor.registerVisualizationType({type = editor.varTypes.ConVar, name = "$Player::renderCollision", displayName = "Player Collision"})
  --editor.registerVisualizationType({type = editor.varTypes.ConVar, name = "$Trigger::renderTriggers", displayName = "Triggers"})
  --editor.registerVisualizationType({type = editor.varTypes.ConVar, name = "$PhysicalZone::renderZones", displayName = "PhysicalZones"})

  editor.registerVisualizationType({type = editor.varTypes.LuaVar, name = "ShadowMapPass.disableShadows", displayName = "Disable Shadows", callback = ShadowMapManager.updateShadowDisable})

  editor.registerVisualizationType({type = editor.varTypes.Custom, name = "$AL_LightColorVisualizeVar", displayName = "Advanced Lighting: Light Color Viz",
                                    setter = createRenderModeSetter("AL_LightColorVisualize", "$AL_LightColorVisualizeVar", "toggleLightColorViz"),
                                    getter = function() return getConsoleVariable("$AL_LightColorVisualizeVar") == "1" end})

  editor.registerVisualizationType({type = editor.varTypes.Custom, name = "$AL_LightSpecularVisualizeVar", displayName = "Advanced Lighting: Light Specular Viz",
                                    setter = createRenderModeSetter("AL_LightSpecularVisualize", "$AL_LightSpecularVisualizeVar", "toggleLightSpecularViz"),
                                    getter = function() return getConsoleVariable("$AL_LightSpecularVisualizeVar") == "1" end})

  editor.registerVisualizationType({type = editor.varTypes.Custom, name = "$AL_NormalsVisualizeVar", displayName = "Advanced Lighting: Normals Viz",
                                    setter = createRenderModeSetter("AL_NormalsVisualize", "$AL_NormalsVisualizeVar", "toggleNormalsViz"),
                                    getter = function() return getConsoleVariable("$AL_NormalsVisualizeVar") == "1" end})

  editor.registerVisualizationType({type = editor.varTypes.Custom, name = "$AL_DepthVisualizeVar", displayName = "Advanced Lighting: Depth Viz",
                                    setter = createRenderModeSetter("AL_DepthVisualize", "$AL_DepthVisualizeVar", "toggleDepthViz"),
                                    getter = function() return getConsoleVariable("$AL_DepthVisualizeVar") == "1" end})

  if ResearchVerifier.isTechLicenseVerified() then
    editor.registerVisualizationType({type = editor.varTypes.Custom, name = "$AnnotationVisualizeVar", displayName = "Annotation Viz",
                                      setter = createRenderModeSetter("AnnotationVisualize", "$AnnotationVisualizeVar", "toggleAnnotationVisualize"),
                                      getter = function() return getConsoleVariable("$AnnotationVisualizeVar") == "1" end})
  end

  -- Material Debug Visualization
  materialDebugVisualizationTypes = {
    {type = editor.varTypes.Custom, name = "Material_None", displayName = "None",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugNone) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugNone end},
    {type = editor.varTypes.Custom, name = "Material_BaseColor", displayName = "Base Color",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugBaseColor) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugBaseColor end},
    {type = editor.varTypes.Custom, name = "Material_Opacity", displayName = "Opacity",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugOpacity) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugOpacity end},
    {type = editor.varTypes.Custom, name = "Material_Metallic", displayName = "Metallic",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugMetallic) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugMetallic end},
    {type = editor.varTypes.Custom, name = "Material_Roughness", displayName = "Roughness",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugRoughness) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugRoughness end},
    {type = editor.varTypes.Custom, name = "Material_NormalsWS", displayName = "Normals World Space",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugNormalsWS) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugNormalsWS end},
    {type = editor.varTypes.Custom, name = "Material_AmbientOcclusion", displayName = "Ambient Occlusion",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugAmbientOcclusion) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugAmbientOcclusion end},
    {type = editor.varTypes.Custom, name = "Material_Emissive", displayName = "Emissive",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugEmissive) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugEmissive end},
    {type = editor.varTypes.Custom, name = "Material_ClearCoat", displayName = "Clear Coat",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugClearCoat) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugClearCoat end},
    {type = editor.varTypes.Custom, name = "Material_ClearCoatRoughness", displayName = "Clear Coat Roughness",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugClearCoatRoughness) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugClearCoatRoughness end},
    {type = editor.varTypes.Custom, name = "Material_UV0", displayName = "UV0",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugUV0) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugUV0 end},
    {type = editor.varTypes.Custom, name = "Material_UV0Checkerboard", displayName = "UV0 Checkerboard",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugUV0Checkerboard) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugUV0Checkerboard end},
    {type = editor.varTypes.Custom, name = "Material_UV0ColorGrid", displayName = "UV0 Color Grid",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugUV0ColorGrid) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugUV0ColorGrid end},
    {type = editor.varTypes.Custom, name = "Material_UV1", displayName = "UV1",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugUV1) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugUV1 end},
    {type = editor.varTypes.Custom, name = "Material_UV1Checkerboard", displayName = "UV1 Checkerboard",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugUV1Checkerboard) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugUV1Checkerboard end},
    {type = editor.varTypes.Custom, name = "Material_UV1ColorGrid", displayName = "UV1 Color Grid",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugUV1ColorGrid) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugUV1ColorGrid end},
    {type = editor.varTypes.Custom, name = "Material_MaterialDeprecated", displayName = "Deprecated Material",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugMaterialDeprecated) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugMaterialDeprecated end,
      info = function()
        im.ColorEdit3("Deprecated Material", editor.getTempFloatArray3_TableTable({1, 0, 0}), im.flags(im.ColorEditFlags_NoTooltip, im.ColorEditFlags_NoInputs, im.ColorEditFlags_NoPicker))
        im.ColorEdit3("New Material", editor.getTempFloatArray3_TableTable({0, 1, 0}), im.flags(im.ColorEditFlags_NoTooltip, im.ColorEditFlags_NoInputs, im.ColorEditFlags_NoPicker))
      end},
    {type = editor.varTypes.Custom, name = "Material_LayerCount", displayName = "Layer Count",
      setter = function() materialDebugSetter(renderDebugFlags.FlagsDebugLayerCount) end,
      getter = function() return materialDebugGetFlag() == renderDebugFlags.FlagsDebugLayerCount end,
      info = function()
        im.ColorEdit3("New material", editor.getTempFloatArray3_TableTable({0, 0, 1}), im.flags(im.ColorEditFlags_NoTooltip, im.ColorEditFlags_NoInputs, im.ColorEditFlags_NoPicker))
        im.ColorEdit3("1 Layer", editor.getTempFloatArray3_TableTable({0, 1, 0}), im.flags(im.ColorEditFlags_NoTooltip, im.ColorEditFlags_NoInputs, im.ColorEditFlags_NoPicker))
        im.ColorEdit3("2 Layer", editor.getTempFloatArray3_TableTable({1/3, 2/3, 0}), im.flags(im.ColorEditFlags_NoTooltip, im.ColorEditFlags_NoInputs, im.ColorEditFlags_NoPicker))
        im.ColorEdit3("3 Layer", editor.getTempFloatArray3_TableTable({2/3, 1/3, 0}), im.flags(im.ColorEditFlags_NoTooltip, im.ColorEditFlags_NoInputs, im.ColorEditFlags_NoPicker))
        im.ColorEdit3("4 Layer", editor.getTempFloatArray3_TableTable({1, 0, 0}), im.flags(im.ColorEditFlags_NoTooltip, im.ColorEditFlags_NoInputs, im.ColorEditFlags_NoPicker))
      end}
  }
  for k, v in ipairs(materialDebugVisualizationTypes) do
    if v.getter() then
      materialDebugVisualizationType[0] = (k-1)
      return
    end
  end

  if not editor.getPreference("gizmos.visualization.saveVisualizationSettings") then
    editor.preferencesRegistry:addNonPersistentItemPath("gizmos.visualization.visTypes")
    editor.preferencesRegistry:addNonPersistentItemPath("gizmos.visualization.visible")
    editor.preferencesRegistry:addNonPersistentItemPath("gizmos.visualization.selectable")
  end

  -- Fill visualizationTypesDefault here as VisualizationTypes are not available in onEditorRegisterPreferences
  for _, type in ipairs(editor.getVisualizationTypes()) do
    if type.name == "SFXEmitter.renderEmitters" or
       type.name == "BeamNGWaypointDrawDebug" or
       type.name == "SceneCullingState.disableTerrainOcclusion" then
      var.visualizationTypesDefault[type.name] = true
    else
      var.visualizationTypesDefault[type.name] = false
    end
  end
end

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorPreferenceValueChanged = onEditorPreferenceValueChanged

return M