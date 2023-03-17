-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local ffi = require('ffi')

local M = {}
local im = ui_imgui
local imUtils = require('ui/imguiUtils')
local toolWindowName = "shapeEditor"

-- initialized in initialize()
local shapePrev = nil
local gui3DMouseEvent = nil
local renderSize = {512,512}
local dimRdr = RectI()
dimRdr:set(0,0,renderSize[1],renderSize[2])
local dirtyRdr = true
local camrotation = {im.FloatPtr(0), im.FloatPtr(3.9)}
local renderFlags = {im.BoolPtr(false), im.BoolPtr(false), im.BoolPtr(false), im.BoolPtr(false), im.BoolPtr(false), im.BoolPtr(false)}
local forceDetail = im.BoolPtr(false)
local detailLevel = im.IntPtr(0)
local orbitDist = im.FloatPtr(0)
local meshFile = nil
local initialWindowSize = im.ImVec2(800, 600)
local windowTitle = "Shape Editor"
local lodAmount = im.FloatPtr(0.95)
local lodDetDest = im.IntPtr(0)
local comboCurrentItem = im.IntPtr(0)
local comboCtxTxt = ""
local highestDetail = -1
local meshConstructor = {}
local shapeInfo = {}
local selectedMaterialName = nil
local highlightMaterial = nil
local highlightMaterialName = nil
local lodSloppy = im.BoolPtr(false)
local lodErrorTarget = im.FloatPtr(1.0)
local lodBrokenMesh = false

local function onWindowMenuItem()
  dirtyRdr = true
  if editor and editor.showWindow then
    editor.showWindow(toolWindowName)
  end
end

local function onEditorInitialized()
  if not shapePrev then
    shapePrev = ShapePreview()
  end
  -- meshFile = "/levels/GridMap/art/shapes/buildings/busstop_grid.dae"
  -- shapePrev:setObjectModel(meshFile)
  editor.addWindowMenuItem(windowTitle, onWindowMenuItem)
  shapePrev:setRenderState(renderFlags[1][0],renderFlags[2][0],renderFlags[3][0],renderFlags[4][0],renderFlags[5][0])
  editor.registerWindow(toolWindowName, initialWindowSize)
end

local function _getShapeInfo()
  if shapePrev.getTSShapeInfo then
    lodBrokenMesh = false
    shapeInfo = shapePrev:getTSShapeInfo()
    if not shapeInfo then
      lodBrokenMesh = true
      log("E","showShapeEditorLoadFile", "getTSShapeInfo failed")
      return
    end
    comboCtxTxt = ""
    highestDetail = -1
    for k,v in pairs(shapeInfo.details) do
      if v.size < 0 then goto continue_info end
      if v.size > highestDetail then highestDetail = v.size end
      comboCtxTxt = comboCtxTxt..dumps(v.meshName).." - "..dumps(v.size).."\0"
      ::continue_info::
    end
    lodDetDest[0] = math.floor(highestDetail*0.8)
    comboCtxTxt = comboCtxTxt.."\0"
  end
end

local function _readMeshConstructor()
  local path,filename,ext = path.split(meshFile)
  filename = filename:gsub(ext,"cs")
  local mcf = path .. filename
  if FS:fileExists(mcf) then
    local data = readFile(mcf)
    if not string.startswith(data,"//JSON:") then
      log("E","_readMeshConstructor","no lua metadata!!")
    end
    meshConstructor = jsonDecode(data:match("^//JSON:([%w%g]+)"))
  end
end

local function _writeMeshConstructor()
  dump(path.split(meshFile))
  local path,filename,ext = path.split(meshFile)
  local filenameNoExt = filename:match( "(.+)."..ext.."*$" )
  filename =  filename:gsub(ext,"cs")
  local mcf = path .. filename
  local f = io.open(mcf, "w")
  if f then
    local content = jsonEncode(meshConstructor)
    f:write("//JSON:")
    f:write(content)
    f:write(string.format([[

singleton TSShapeConstructor(%s)
{
    baseShape = "%s";
    loadLights = "0";
    unit = "1.0";
    upAxis = "DEFAULT";
    lodType = "TrailingNumber";
    ignoreNodeScale = "0";
    adjustCenter = "0";
    adjustFloor = "0";
    forceUpdateMaterials = "0";
};
]],
      filenameNoExt,
      meshFile
    ))
    f:write(string.format("function %s::onLoad(%%this)\n{\n", filenameNoExt))
    for k,v in pairs(meshConstructor.createMeshLOD) do
      if v.sloppy then
        f:write(string.format("   %%this.createMeshLOD(%d, %f, %d, %d, %f);\n",
          v.src,
          v.amount,
          v.dest,
          v.sloppy,
          v.err
        ))
      else
        f:write(string.format("   %%this.createMeshLOD(%d, %f, %d);\n",
          v.src,
          v.amount,
          v.dest
        ))
      end
    end
    f:write("}")

    f:close()
  end

end

local function _getMaterialObj(matName)
  local mat = scenetree.findObject(matName)
  if not mat then
    log("E", "_getMaterialObj", dumps(matName) .. " sceneobject was not found")
    return nil
  end
  if mat:getClassName():lower() ~= "material" then
    log("E", "_getMaterialObj", dumps(matName) .. " is not a Material. type="..dumps(mat:getClassName()))
    return nil
  end
  return mat
end

local function _getLastDifuse(mat)
  local matVer = mat:getField("version", 0 )
  if matVer == "1" then --float are string because TS
    return mat:getField("colorMap", 1)
  elseif matVer == "1.5" then --pbr like input
    return mat:getField("baseColorMap", mat.activeLayers-1)
  else
    log("E", "unknwon Material version "..dumps(matVer))
  end
end

local function _setLastDifuse(mat,texPath)
  local matVer = mat:getField("version", 0 )
  if matVer == "1" then --float are string because TS
    mat:setField("colorMap", 1, texPath)
  elseif matVer == "1.5" then --pbr like input
    mat:setField("baseColorMap", mat.activeLayers-1, texPath)
  else
    log("E", "unknwon Material version "..dumps(matVer))
  end
  mat:reload()
end

local function _deleteMaterial(obj)
  if obj then
    --log("E", "del obj "..dumps(obj.name))
    obj:deleteObject()
  end
end


local function _deleteTempMaterial()
  if highlightMaterial then
    -- log("E", "del obj "..dumps(highlightMaterial.name))
    if highlightMaterialName and highlightMaterial.name ~= highlightMaterialName then
      -- log("E", "name diff "..dumps(highlightMaterial.name) .." | ".. dumps(highlightMaterialName))
      local mat = _getMaterialObj(highlightMaterialName)
      -- if mat then _deleteMaterial(mat) end
    end
    _deleteMaterial(highlightMaterial)
    highlightMaterial = nil
    highlightMaterialName = nil
  else
    if highlightMaterialName then
      -- log("E", "only name ".. dumps(highlightMaterialName))
      local mat = _getMaterialObj(highlightMaterialName)
      if mat then _deleteMaterial(mat) end
    end
  end
end

-- cloning material object introduce lots of bugs. warning about mapTo being duplicated and list of material is broken
local function _cloneMat(originalMaterial)
  local skipFields = {'name','mapTo','canSave',"Stages_beginarray","parentGroup","canSaveDynamicFields","class","className","internalName","persistentId","superClass"}
  if not highlightMaterial then
    highlightMaterialName = "tmp_spHighlight_"..randomASCIIString(8)
    highlightMaterial = createObject('Material')
    highlightMaterial.canSave = false
    highlightMaterial:setField('name', 0, highlightMaterialName)
    highlightMaterial:setField('mapTo', 0, highlightMaterialName)
    highlightMaterial:registerObject(highlightMaterialName)
  end

  local fdata = originalMaterial:getFieldsForEditor()
  for k,v in pairs(fdata) do
    if arrayFindValueIndex(skipFields,k) == false then
      highlightMaterial:setField(k, 0, originalMaterial:getField(k,0))
    end
  end
  for k,v in pairs(fdata.Stages_beginarray.fields) do
    for i = 0, 3 do
      highlightMaterial:setField(k, i, originalMaterial:getField(k,i))
    end
  end
  _setLastDifuse(highlightMaterial, "/core/art/highlight_material.png")

  -- highlightMaterial:flush()
  -- highlightMaterial:reload()
end

local function _updateSelectedMaterial(matName)
  if matName == selectedMaterialName then return end
  shapePrev:restoreMaterial()
  selectedMaterialName = nil
  if matName then
    local mat = _getMaterialObj(matName)
    if mat then
      -- print("preview mat"..dumps(matName))
      selectedMaterialName = matName
      _deleteTempMaterial()
      _cloneMat(mat)
      shapePrev:setMaterialEx(highlightMaterial,matName)
    else
      log("E","_updateSelectedMaterial", "highlight material invalid "..dumps(matName))
    end
  end
end

local function _addLod(src,amount,dest,sloppy,err)
  if not meshConstructor then
    meshConstructor = {}
  end
  if not meshConstructor.createMeshLOD then
    meshConstructor.createMeshLOD = {}
  end
  table.insert( meshConstructor.createMeshLOD,{src=src,amount=amount,dest=dest,sloppy=sloppy,err=err})
  _writeMeshConstructor()
  _getShapeInfo()
end

local function _removeLod(dest)
  if not meshConstructor or not meshConstructor.createMeshLOD then
    log("E","_removeLod", "no LOD managed")
    return
  end
  for k,v in pairs(meshConstructor.createMeshLOD) do
    if v.dest == dest then
      table.remove(meshConstructor.createMeshLOD, k)
      _writeMeshConstructor()
      log("I","_removeLod", "k="..dumps(k).." - "..dumps(meshConstructor.createMeshLOD))
      _getShapeInfo()
      return
    end
  end
  log("E","_removeLod", "not LOD found")
end

local function menuSize(width,height)
  local menuW, menuH
  local uiScale = 1
  if editor and editor.getPreference and editor.getPreference("ui.general.scale") then
    uiScale = editor.getPreference("ui.general.scale")
  else
    uiScale = ui_imgui.GetIO().FontGlobalScale
  end
  local minW=250*uiScale
  local maxW=600*uiScale
  local ratioW=0.3
  local minH=300*uiScale
  local maxH=1000*uiScale
  local ratioH=0.5
  if width*ratioW > maxW then menuW=maxW
  elseif width*ratioW < minW then menuW=math.min(width,minW)
  else menuW=width*ratioW
  end
  if height*ratioH > maxH then menuH=maxH
  elseif height*ratioH < minH then menuH=math.min(height,minH)
  else menuH=height*ratioH
  end
  return im.ImVec2(menuW, menuH)
end

local function onEditorGui()
  if shapePrev and editor.beginWindow(toolWindowName, windowTitle, im.WindowFlags_NoCollapse) then
    renderSize[1] = im.GetContentRegionAvail().x
    renderSize[2] = im.GetContentRegionAvail().y

    if renderSize[1] < 150 or renderSize[2] < 150 then
      im.TextUnformatted("too small")
      editor.endWindow()
      return
    end

    if dimRdr.extent.x ~= renderSize[1] or dimRdr.extent.y ~= renderSize[2] then
      dimRdr:set(0,0,renderSize[1],renderSize[2])
      dirtyRdr = true
    end

    if dirtyRdr then
      shapePrev:renderWorld(dimRdr)
      dirtyRdr = false
    end

    local cur = im.GetCursorPos()

    if not shapePrev:ImGui_Image(renderSize[1],renderSize[2]) then
      im.TextWrapped("<No Shape Selected for Editing>\r\n\r\nPlease select a TSStatic (shape) object in the scene tree or asset browser and use the 'Open in Shape Editor' button to open it here.")
      editor.endWindow()
      return
    end

    local mod = false

    im.SetCursorPos(cur)
    editor.uiTextUnformattedRightAlign("File = "..meshFile, true)
    im.SetCursorPos(cur)
    im.PushStyleColor2(im.Col_ChildBg, im.ImColorByRGB(0,0,0,64).Value)
    im.BeginChild1("shapeEditorMenu",  menuSize(im.GetWindowWidth(),im.GetWindowHeight()), true )
    im.PopStyleColor()
    if im.BeginTabBar("shapeeditor##") then
      if im.BeginTabItem("Details") then
        if im.Checkbox("Force detail", forceDetail) then
          shapePrev.mFixedDetail = forceDetail[0]
          dirtyRdr = true
        end
        im.SameLine()
        if not forceDetail[0] then
          im.BeginDisabled()
          detailLevel[0] = shapePrev.mCurrentDL
        end
        im.PushItemWidth(im.GetContentRegionAvailWidth())
        if im.SliderInt("##detailLevel", detailLevel, 0, shapePrev:getDetailLevelCount()-1) then
          shapePrev:setCurrentDetail(detailLevel[0])
          dirtyRdr = true
        end
        im.PopItemWidth()
        if not forceDetail[0] then
          im.EndDisabled()
        end

        if im.Button("Export to Collada") then
          editor_fileDialog.saveFile(
            function(data)
              shapePrev:exportToCollada(data.filepath)
            end,
            {{"Collada file",".dae"}},
            false,
            nil,
            "File already exists.\nDo you want to overwrite the file?"
          )
        end

        if shapePrev.exportToWavefront and im.Button("Export to Wavefront obj") then
          editor_fileDialog.saveFile(
            function(data)
              shapePrev:exportToWavefront(data.filepath)
            end,
            {{"Wavefront .obj file",".obj"}},
            false,
            nil,
            "File already exists.\nDo you want to overwrite the file?"
          )
        end
        if shapePrev.dumpTSShapeInfo and beamng_buildtype=="INTERNAL" and im.Button("dumpShapeInfo") then
          shapePrev:dumpTSShapeInfo()
        end
        if shapePrev.getTSShapeInfo and beamng_buildtype=="INTERNAL" and im.Button("getTSShapeInfo") then
          log("I","getTSShapeInfo", dumps(shapePrev:getTSShapeInfo()))
        end

        im.BeginChild1("", im.ImVec2(0, 0), false)
        im.Columns(4)

        im.TextUnformatted("DetName")
        im.NextColumn()
        im.TextUnformatted(shapePrev:getCurentDetailName())
        im.NextColumn()
        im.TextUnformatted("Size")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mDetailSize))
        im.NextColumn()
        im.TextUnformatted("Polys")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mDetailPolys))
        im.NextColumn()
        im.TextUnformatted("Pixel")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mPixelSize))
        im.NextColumn()
        im.TextUnformatted("Materials")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mNumMaterials) )
        im.NextColumn()
        im.TextUnformatted("DrawCalls")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mNumDrawCalls))
        im.NextColumn()
        im.TextUnformatted("Bones")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mNumBones))
        im.NextColumn()
        im.TextUnformatted("Weights")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mNumWeights))
        im.NextColumn()
        im.TextUnformatted("ColMeshes")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mColMeshes))
        im.NextColumn()
        im.TextUnformatted("ColPolys")
        im.NextColumn()
        im.TextUnformatted(tostring(shapePrev.mColPolys))
        im.NextColumn()
        im.EndChild()

        -- im.BeginChild1("###shapeStats", im.ImVec2(400, 200), true)
        -- im.Columns(2)
        -- for k,v in pairs(shapePrev:getMeshStat()) do
        --   im.Text(k)
        --   im.NextColumn()
        --   im.Text(dumps(v))
        --   im.Separator()
        --   im.NextColumn()
        -- end
        -- im.EndChild()

        im.EndTabItem()
      end
      if im.BeginTabItem("Render") then
        mod = false
        if im.Checkbox("Ghost", renderFlags[1]) then
          mod = true
        end
        if im.Checkbox("Nodes", renderFlags[2]) then
          mod = true
        end
        if im.Checkbox("Bounds", renderFlags[3]) then
          mod = true
        end
        if im.Checkbox("ObjBox", renderFlags[4]) then
          mod = true
        end
        if im.Checkbox("ColMeshes", renderFlags[5]) then
          mod = true
        end
        if shapePrev.createMeshLOD and im.Checkbox("wireframe", renderFlags[6]) then
          mod = true
        end
        if mod then
          shapePrev:setRenderState(renderFlags[1][0],renderFlags[2][0],renderFlags[3][0],renderFlags[4][0],renderFlags[5][0],true,renderFlags[6][0])
          dirtyRdr = true
        end

        im.EndTabItem()
      end
      if im.BeginTabItem("Nodes") then
        local nodes = shapePrev:getNodes()
        local displayTree
        displayTree = function(data)
          if data then
            for k, v in pairs(data) do
              if type(v) ~= 'table' then
                im.TextUnformatted(tostring(v))
              else
                if im.TreeNodeEx1(tostring(k), im.TreeNodeFlags_DefaultOpen) then
                  displayTree(v)
                  im.TreePop()
                end
              end
            end
          end
        end

        displayTree(nodes)
        im.EndTabItem()
      end
      if im.BeginTabItem("Material") then
        local mname = shapePrev:getMaterialNames()
        local matHover = nil
        for k,v in ipairs(mname) do
          if editor_materialEditor then
            if im.Selectable1(v, nil, im.SelectableFlags_DontClosePopups) then
              editor_materialEditor.showMaterialEditor()
              editor_materialEditor.selectMaterialByName(v)
            end
            if im.IsItemHovered() then
              matHover = v
            end
          else
            im.TextUnformatted(v)
          end
        end
        _updateSelectedMaterial(matHover)
        im.EndTabItem()
      end
      if shapePrev.createMeshLOD and im.BeginTabItem("LOD WIP") then
        if highestDetail == -1 then
          im.TextUnformatted("Error: no LOD")
        end
        if lodBrokenMesh then
          im.TextColored(im.ImVec4(1,0.1,0.1,1), "Broken/Invalid mesh !")
          if shapePrev.dumpTSShapeInfo and im.Button("dumpShapeInfo") then
            shapePrev:dumpTSShapeInfo()
          end
          im.BeginDisabled()
        end
        if im.Checkbox("wireframe", renderFlags[6]) then
          shapePrev:setRenderState(renderFlags[1][0],renderFlags[2][0],renderFlags[3][0],renderFlags[4][0],renderFlags[5][0],true,renderFlags[6][0])
        end
        if im.Combo2("Source detail", comboCurrentItem, comboCtxTxt) then
          shapePrev:setCurrentDetail(comboCurrentItem[0])
          forceDetail[0] = true
          shapePrev.mFixedDetail = comboCurrentItem[0]
          dirtyRdr = true
        end
        im.SliderFloat("amount", lodAmount, 0.1, 1)
        im.SliderInt("Destination Detail", lodDetDest, 1, highestDetail-1)
        if im.Checkbox("sloppy", lodSloppy) then
          print("sloppy modified")
          if lodSloppy[0] then
            lodErrorTarget[0] = 10
          else
            lodErrorTarget[0] = 1.0
          end
        end
        editor.uiInputFloat("Error target",lodErrorTarget,0.1,1, "%.2f", nil)
        if im.Button("add LOD") then
          shapePrev:createMeshLOD(detailLevel[0], lodAmount[0], lodDetDest[0],lodSloppy[0], lodErrorTarget[0]*0.01)
          _addLod(detailLevel[0], lodAmount[0], lodDetDest[0],lodSloppy[0], lodErrorTarget[0]*0.01)
        end
        -- if im.Button("refresh") then
        --   shapePrev:refreshShape()
        -- end
        -- if im.Button("dump info") then
        --   local info = shapePrev:getTSShapeInfo()
        --   if not info then
        --     log("E","showShapeEditorLoadFile", "getTSShapeInfo failed")
        --   else
        --     log("I","dump", dumps(info))
        --   end
        -- end
        -- if im.Button("read MC") then
        --   _readMeshConstructor()
        -- end

        im.BeginChild1("", im.ImVec2(0, 0), false)
        im.Columns(5)
        im.TextUnformatted("Source")
        im.NextColumn()
        im.TextUnformatted("Amount")
        im.NextColumn()
        im.TextUnformatted("Destination")
        im.NextColumn()
        im.TextUnformatted("Sloopy")
        im.NextColumn()
        im.TextUnformatted("ErrorTarget")
        im.NextColumn()

        if meshConstructor and meshConstructor.createMeshLOD and not lodBrokenMesh then
          for k,v in pairs(meshConstructor.createMeshLOD) do
            local src = tostring(v.src)
            if shapeInfo and shapeInfo.details[v.src+1] then
              src = src .. " " .. dumps(shapeInfo.details[v.src+1].name)
              src = src .. " " .. shapeInfo.details[v.src+1].meshName
            end
            im.TextUnformatted(src)
            im.NextColumn()
            im.TextUnformatted(tostring(v.amount))
            im.NextColumn()
            im.TextUnformatted(tostring(v.dest))
            im.NextColumn()
            if v.sloppy then
              im.TextUnformatted(tostring(v.sloppy))
              im.NextColumn()
              im.TextUnformatted(tostring(v.err))
              im.SameLine()
            else
              im.NextColumn()
            end
            if editor.uiIconImageButton(
              editor.icons.delete,
              im.ImVec2(24, 24)
            ) then
              -- shapePrev:removeMesh(shapeInfo.objects[shapeInfo.details[v.src+1].objectDetailNum+1].name)
              _removeLod(v.dest)
            end
            im.NextColumn()
          end
        end
        im.EndChild()
        if lodBrokenMesh then
          im.EndDisabled()
        end
        im.EndTabItem()
      end
      im.EndTabBar()
    end
    im.EndChild()
    shapePrev:setInputEnabled(not im.IsItemHovered())
  end
  editor.endWindow()
end

local function onPreRender()
  if(shapePrev) then
    --shapePrev:preRender()
    shapePrev:renderWorld(dimRdr)
  end
end

local function showShapeEditorGui(objectId)
  local obj = scenetree.findObjectById(objectId)
  if obj and obj.getClassName and obj:getClassName() == "TSStatic" then
    im.SameLine()
    if im.Button("Open in Shape Editor") then
      M.showShapeEditorLoadFile(obj:getModelFile())
    end
  end
end

local function onEditorInspectorHeaderGui(inspectorInfo)
  if inspectorInfo.selection and inspectorInfo.selection.object and #inspectorInfo.selection.object > 0 then
    showShapeEditorGui(inspectorInfo.selection.object[1])
  elseif editor.selection and editor.selection.object and #editor.selection.object > 0 then
    showShapeEditorGui(editor.selection.object[1])
  end
end

local function showShapeEditorLoadFile(filename)
  if not FS:fileExists(filename) then
    log("E","showShapeEditorLoadFile", "File doesn't exist")
  end
  meshFile = filename
  shapePrev:setObjectModel(filename)
  shapePrev:fitToShape()
  onWindowMenuItem()
  _getShapeInfo()
  _readMeshConstructor()
end

local function onSerialize()
  local data = {}
  data.meshFile = meshFile
  data.highlightMaterialName = highlightMaterialName
  return data
end

local function onDeserialized(data)
  shapePrev = ShapePreview()
  if data.meshFile then
    M.showShapeEditorLoadFile(data.meshFile)
  end
  if data.highlightMaterialName then
    highlightMaterialName = data.highlightMaterialName
    _deleteTempMaterial()
  end
end

local function onEditorExitLevel()
  shapePrev:clearShape()
end

local function onEditorObjectSelectionChanged()
  if not editor.isWindowVisible(toolWindowName) then return end
  if editor.getPreference("shapeEditor.general.autoOpenSelectedObject") and editor.selection.object and #editor.selection.object > 0 then
    local obj = scenetree.findObjectById(editor.selection.object[1])
    if obj and obj.getClassName and obj:getClassName() == "TSStatic" then
      M.showShapeEditorLoadFile(obj:getModelFile())
    end
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("shapeEditor")
  prefsRegistry:registerSubCategory("shapeEditor", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {autoOpenSelectedObject = {"bool", true, "Auto open/load the selected mesh object in the Shape Editor (if the window is visible)"}},
  })
end


local function onEditorDeactivated()
  if shapePrev then
    shapePrev:restoreMaterial()
  end
  if highlightMaterial then
    highlightMaterial:deleteObject()
    highlightMaterial = nil
  end
end

M.onSerialize = onSerialize
M.onDeserialized = onDeserialized
M.onEditorInitialized = onEditorInitialized
M.onEditorGui = onEditorGui
M.onEditorExitLevel = onEditorExitLevel
-- M.onPreRender = onPreRender
M.onEditorInspectorHeaderGui = onEditorInspectorHeaderGui
M.onEditorObjectSelectionChanged = onEditorObjectSelectionChanged
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorDeactivated = onEditorDeactivated
M.showShapeEditorLoadFile = showShapeEditorLoadFile

return M