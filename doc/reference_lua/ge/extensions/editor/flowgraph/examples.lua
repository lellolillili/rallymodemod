-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}
C.windowName = 'fg_examples'
C.windowDescription = 'Examples'
C.arrowControllable = true
local matchColor = im.ImVec4(1,0.5,0,1)

function C:attach(mgr)
  self.mgr = mgr
  self.searchChanged = true

  self.doClick = nil
end

function C:init()
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, false)
  self.searchResultsByMgr = {}
  self.searchText = im.ArrayChar(128)
  self.search =  require('/lua/ge/extensions/editor/util/searchUtil')()
  self.results = {}
  self:loadExamples()
end

local examplesLookup = nil
function C:loadExamples()
  local stateTemplatePath = '/lua/ge/extensions/flowgraph/examples/'
  if not examplesLookup then
    local res = {}
    local lookup = {}

    for i, filename in ipairs(FS:findFiles(stateTemplatePath, '*flow.json', -1, true, false)) do

      local dirname, fn, e = path.splitWithoutExt(filename, true)
      local path = dirname:sub(string.len(stateTemplatePath) + 1)

      if path ~= "" then
        local pathArgs = split(path, '/')

        local treeNode = res
        for i = 1, #pathArgs do
          if pathArgs[i] ~= '' then
            if not treeNode[pathArgs[i]] then
              treeNode[pathArgs[i]] = { examples = {} }
            end
            treeNode = treeNode[pathArgs[i]]
          end
        end
        local moduleName = fn
        --local requireFilename = string.sub(filename, 1, string.len(filename) - 4)
        local lectionData = {}

        lectionData.data = readJsonFile(filename)
        lectionData.path = path .. moduleName
        lectionData.sourcePath = stateTemplatePath .. path .. moduleName..'.lua'
        lectionData.splitPath = pathArgs
        lectionData.splitPath[#lectionData.splitPath] = moduleName
        lectionData.splitPath[#lectionData.splitPath+1] = lectionData.name
        treeNode.examples[moduleName] = lectionData
        lookup[path .. moduleName] = lectionData
      end
    end
    examplesLookup = {lookup = lookup, res = res}
  end
  return examplesLookup.res, examplesLookup.lookup
end

function C:getExamplesLookup()
  return self:loadExamples()
end

function C:createNode()
  self.doClick = true
end

function C:navigateList(up)
  if self.selectedButtonListIndex then
    if up then
      self.selectedButtonListIndex = math.max(self.selectedButtonListIndex - 1, 1)
    else
      self.selectedButtonListIndex = math.min(self.selectedButtonListIndex + 1, self.numberOfButtons)
    end
    self.arrowPressed = true
  end
end

function C:drawSearchInput()
  im.Text("Find: ")
  im.SameLine()
  if self.focusSearch and self.focusSearch > 0 then
    im.SetKeyboardFocusHere()
    self.focusSearch = self.focusSearch -1
  end
  if im.InputText("##searchInProject", self.searchText, nil, im.InputTextFlags_AutoSelectAll) then
    self.searchChanged = true
    self.selectedButtonListIndex = 0
    self.buttonListIndex = 0
    self.doClick = nil
  end
  im.SameLine()
  if im.Button("X") then
    self.searchChanged = true
    self.selectedButtonListIndex = 0
    self.buttonListIndex = 0
    self.doClick = nil
    self.searchText = im.ArrayChar(128)
  end
  im.SameLine()
  editor.uiIconImage(editor.icons.help, im.ImVec2(20,20))
  ui_flowgraph_editor.tooltip("Type any string to search for nodes, graphs and pins.\nBegin with 'node:', 'graph:' or 'pin:' to only search for those elements.")
end



function C:findExamples(match)
  for _, info in pairs(examplesLookup.lookup) do
    self.search:queryElement({
        name = info.data.name,
        score = 1,
        frecencyId = info.path,
        info = info
      })
  end
end




function C:findStuff()
  if self.searchChanged then
    table.clear(self.results)
    self.matchString = string.lower(ffi.string(self.searchText))
    self.search:setFrecencyData(self.mgr.frecency or {})
    self.search:startSearch(self.matchString)
    if match ~= '' then
      self:findExamples()
    end
    self.results = self.search:finishSearch()
    self.searchChanged = false
  end
end

function C:highlightText(label, highlightText)
  im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 0))
  if highlightText == "" then
    im.TextColored(matchColor,label)
  else
    local pos1 = 1
    local pos2 = 0
    local labelLower = label:lower()
    local highlightLower = highlightText:lower()
    local highlightLowerLen = string.len(highlightLower) - 1
    for i = 0, 6 do -- up to 6 matches overall ...
      pos2 = labelLower:find(highlightLower, pos1, true)
      if not pos2 then
        im.Text(label:sub(pos1))
        break
      elseif pos1 < pos2 then
        im.Text(label:sub(pos1, pos2 - 1))
        im.SameLine()
      end

      local pos3 = pos2 + highlightLowerLen
      im.TextColored(matchColor, label:sub(pos2, pos3))
      im.SameLine()
      pos1 = pos3 + 1
    end
  end
  im.PopStyleVar()
end


local iconSize = im.ImVec2(20,20)
function C:displayResults()
  local foundResult = false
  local debugEnabled = editor.getPreference("flowgraph.debug.editorDebug")
  for _, result in ipairs(self.results or {}) do
    if self.filterByType and string.lower(result.type) == string.lower(self.filterByType) or not self.filterByType then
      local prePos = im.GetCursorPos()
      im.BeginGroup()
      local x = im.GetCursorPosX()
      self:highlightText(result.name, self.matchString or "")
      if result.info.data.description then
        im.Text(result.info.data.description)
        ui_flowgraph_editor.tooltip(result.info.data.description)
      end
      im.EndGroup()
      self:arrowHelper(prePos, im.GetItemRectSize())
      self:manageClick(result)
      foundResult = true
    end
  end
  if not foundResult then
    im.BeginDisabled()
    im.Text("No Results!")
    im.EndDisabled()
  end
  self.doClick = false
end

function C:manageClick(result)
  local doClick = im.IsItemClicked() or (self.buttonListIndex == self.selectedButtonListIndex and self.doClick)
  if doClick then
    local mgr, succ = core_flowgraphManager.addManager(result.info.data)
    mgr.savedDir, mgr.savedFilename = nil, nil
    self.fgEditor.setManager(mgr)
  end
end

function C:draw()
  if not editor.isWindowVisible(self.windowName) then return end
  self:Begin("Examples")

  self.buttonListIndex = 0

  self:handleActionMap()
  self:drawSearchInput()
  self:findStuff()
  if self.matchString and self.matchString ~= "" then
    self:displayResults()
  else
    self:displayTreeView()
  end

  self.numberOfButtons = self.buttonListIndex
  self.arrowPressed = nil

  self:End()
end

function C:displayTreeView()
  self:recursiveTreeView(examplesLookup.res,0)
end

local folderSort = {beginner = 0, intermediate = 1, expert = 2, nodes = 3}

local folderName = 'examples'
function C:recursiveTreeView(element, depth)
  if element.examples then
    local sortedExamples = {}
    for k, v in pairs(element.examples) do if k ~= folderName then table.insert(sortedExamples, k) end end

    table.sort(sortedExamples, function(a,b) return (element.examples[a].data.exampleOrder or 10^10) < (element.examples[b].data.exampleOrder or 10^10) end )
    for i, key in ipairs(sortedExamples) do
      local example = element.examples[key]
      local prePos = im.GetCursorPos()
      im.BeginGroup()
      local x = im.GetCursorPosX()
      self:highlightText(i.." - " .. (example.data.name or key),"")
      if example.data.description then
        im.TextWrapped(example.data.description)
        ui_flowgraph_editor.tooltip(example.data.description)
      end
      im.EndGroup()
      self:arrowHelper(prePos, im.GetItemRectSize())
      self:manageClick({info = example})
    end
  end

  local sortedKeys = {}
  for k, v in pairs(element) do if k ~= folderName then table.insert(sortedKeys, k) end end
  table.sort(sortedKeys, function(a,b)
    local fsA, fsB = folderSort[a] or math.huge, folderSort[b] or math.huge
    if fsA == fsB then
      return a<b
    else
      return fsA < fsB
    end
  end
    )
  for _, key in ipairs(sortedKeys) do
    if im.TreeNode1(key.."##"..depth) then
      self:recursiveTreeView(element[key], depth+1)
      im.TreePop()
    end
  end
end

function C:handleActionMap()
  if im.IsWindowFocused(im.FocusedFlags_ChildWindows) then
    self.fgEditor.arrowControllableWindow = self
    if not self.pushedActionMap then
      pushActionMapHighestPriority("NodeLibrary")
      table.insert(editor.additionalActionMaps, "NodeLibrary")
      self.pushedActionMap = true
      self.fgEditor.pushedNodeLibActionMap = true
    end
  else
    self.pushedActionMap = nil
  end
end


function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

function C:arrowHelper(cursor, itemSize, doHover)
  self.buttonListIndex = self.buttonListIndex +1
  if self.buttonListIndex == self.selectedButtonListIndex then
    im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                          cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                          im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                          cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                          im.GetColorU321(im.Col_HeaderActive), 1, 1)

    -- Set the scrollbar to show the selected node
    if self.arrowPressed then
      if cursor.y > im.GetScrollY() + im.GetWindowHeight() then
        im.SetScrollY(math.min(cursor.y - im.GetWindowHeight()/2, im.GetScrollMaxY()))
      end
      if cursor.y < im.GetScrollY() then
        im.SetScrollY(math.max(cursor.y - im.GetWindowHeight()/2, 0))
      end
      self.arrowPressed = false
    end
  end
  if im.IsItemHovered() then
    -- display blue rectangle when node is hovered
    im.ImDrawList_AddRect(im.GetWindowDrawList(), im.ImVec2(cursor.x + im.GetWindowPos().x - 2,
                          cursor.y + im.GetWindowPos().y + (im.GetStyle().ItemSpacing.y/2) - 2 - im.GetScrollY()),
                          im.ImVec2(cursor.x + im.GetWindowPos().x + itemSize.x + (im.GetStyle().ItemSpacing.y/2),
                          cursor.y + im.GetWindowPos().y + itemSize.y + 2 - im.GetScrollY()),
                          im.GetColorU321(im.Col_HeaderHovered), 1, 1)
  end
end

return _flowgraph_createMgrWindow(C)
