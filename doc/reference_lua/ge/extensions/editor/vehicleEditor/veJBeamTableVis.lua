-- This Source Code Form is subject to the terms of the bCDDL, var. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
M.menuEntry = "JBeam Debug/JBeam Table Visualizer"
local im = extensions.ui_imgui
local imguiUtils = require('ui/imguiUtils')

local plotParams = {
  autoScale = true,
  showCatmullRomCurve = true
}
local plotHelperUtil = require('/lua/ge/extensions/editor/util/plotHelperUtil')(plotParams)
local wndName = "JBeam Table Visualizer"

local jbeamFileName = nil
local jbeamFilePath = nil
local jbeamData = nil
local graphableData = {}

local dataGraphingKey = nil
local dataGraphingPath = nil

local function removeHeader(t)
  local header = t[1]

  if type(header[1]) == "string" then
    table.remove(t, 1)
  end
end

-- From common/jbeam/io.lua that parses a JBeam file from its filename
local function parseJBeamFile(filename)
  local content = readFile(filename)
  if content then
    local ok, data = pcall(json.decode, content)
    if ok == false then
      log('E', "jbeam.parseFile","unable to decode JSON: "..tostring(filename))
      log('E', "jbeam.parseFile","JSON decoding error: "..tostring(data))
      return nil
    end
    return data
  else
    log('E', "jbeam.parseFile","unable to read file: "..tostring(filename))
  end
end

-- Goes through the jbeam data recursively to find tables that can be graphable (possibly)
local function getGraphableData(data, path, resTable)
  -- Viable canidates are tables that only have equally sized subtables
  -- and have number arrays in all subbtables except first?
  for k, v in pairs(data) do
    if type(v) == "table" then
      local allEquallySizedTables = false
      local allExceptFirstHaveNums = false
      local firstCount = -1

      -- Go through subtables
      for k1, v1 in ipairs(v) do
        if type(v1) == "table" then
          if firstCount == -1 then
            firstCount = tableSize(v1)
          else
            allEquallySizedTables = firstCount == tableSize(v1)
            allExceptFirstHaveNums = type(v1[1]) == "number" and type(v1[2]) == "number"

            if not allEquallySizedTables or not allExceptFirstHaveNums then
              break
            end
          end
        else
          allEquallySizedTables = false
          break
        end
      end

      local pathToData = path ~= "" and path .. " > " .. k or k

      if allEquallySizedTables and allExceptFirstHaveNums then
        removeHeader(v)
        resTable[pathToData] = v
      else
        getGraphableData(v, pathToData, resTable)
      end
    end
  end
end

-- if parameter is nil, its assummed to refresh data
local function loadJBeamFileInMemory(inputJBeamData)
  local jbeamData = inputJBeamData

  if not inputJBeamData then
    if jbeamFilePath then
      jbeamData = parseJBeamFile(jbeamFilePath)
    else
      return
    end
  end

  local resTable = {}
  getGraphableData(jbeamData, "", resTable)

  -- Sort the table
  local keys = tableKeysSorted(resTable)

  local sortedResTable = {}
  for _,k in ipairs(keys) do
    table.insert(sortedResTable, {pathToData = k, data = resTable[k]})
  end

  graphableData = sortedResTable

  if inputJBeamData then -- new data
    dataGraphingKey = nil
    dataGraphingPath = nil
  else -- refresh current data
    if dataGraphingKey and graphableData then
      plotHelperUtil:setData(graphableData[dataGraphingKey].data)
    end
  end
end

-- Load JBeam file in memory from choosing one in file dialog
local function loadJBeamFile(fileDialogData)
  jbeamFileName = fileDialogData.filename
  jbeamFilePath = fileDialogData.filepath
  jbeamData = parseJBeamFile(jbeamFilePath)

  loadJBeamFileInMemory(jbeamData)
end

local function onEditorGui(dt)
  if not vEditor.vehicle then return end
  if editor.beginWindow(wndName, wndName) then
    if im.Button("Open JBeam File...") then
      -- Opens a file dialog to choose JBeam file to load
      editor_fileDialog.openFile(function(data)
        loadJBeamFile(data)
      end, {{"JBeam files", ".jbeam"}}, false, "/vehicles/")
    end

    im.SameLine()
    im.Text(jbeamFileName or "")

    if im.BeginCombo("##chooseDataToGraphCombobox", dataGraphingPath or "Choose data to graph...", im.ComboFlags_HeightLarge) then
      for k, v in ipairs(graphableData) do
        local pathToData = v.pathToData
        local data = v.data

        if pathToData and data then
          if im.Selectable1(pathToData) then
            dataGraphingPath = pathToData
            dataGraphingKey = k

            plotHelperUtil:setData(data)
          end
        end
      end
      im.EndCombo()
    end

    if im.Button("Refresh") then
      if jbeamFilePath then
        loadJBeamFileInMemory(nil)
      end
    end

    local size = im.GetContentRegionAvail()
    plotHelperUtil:draw(size.x-10, size.y-10, dt)
  end
  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(700,400))
end

M.open = open

M.onEditorGui = onEditorGui
M.onEditorInitialized = onEditorInitialized

return M