-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = extensions.ui_imgui
local imguiUtils = require('ui/imguiUtils')

local C = {}
local minWrap = 300
local maxWrap = 800
C.windowName = 'fg_welcome'
C.windowDescription = 'Welcome'


function C:attach(mgr)
  self.mgr = mgr
end

function C:init()
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, true)

  self.headerImage = imguiUtils.texObj('/lua/ge/extensions/editor/flowgraph/welcomeHeader.png')
  self.headerImageSize = im.ImVec2(1200, 200)

  self.sideImage = imguiUtils.texObj('/lua/ge/extensions/editor/flowgraph/welcomeSide.png')
  self.sideImageSize = im.ImVec2(200, 800)
  self.focus = true

  self.demoProjects = {
    {
      name = "Barrel Knocker",
      description = 'Knock over barrels with a time limit.',
      data = jsonReadFile('levels/Industrial/scenarios/barrelKnocker/barrelKnocker.flow.json')
    },
    {
      name = "East Coast Chase",
      description = 'Stop an AI-controlled vehicle from escaping.',
      data = jsonReadFile('levels/east_coast_usa/scenarios/chase_1/chase_1.flow.json')
    },
    {
      name = "Speedy Scramble",
      description = "Reach Checkpoints with a time limit and traffic.",
      data = jsonReadFile('levels/west_coast_usa/scenarios/speedyScramble/speedyScramble.flow.json')
    }
  }

  table.sort(self.demoProjects, function(a,b) return a.name < b.name end)
end

local function headerText(txt)
  im.SetWindowFontScale(2)
  im.TextColored(im.GetStyleColorVec4(im.Col_NavHighlight), txt)
  im.SetWindowFontScale(1)
  im.Dummy(im.ImVec2(0, 10))
end

local hoverState = {}

local function fancyIconButton(id, icon, iconHover, txt, lowerTxt)
  local col = im.ImVec4(1, 1, 1, 1)
  local ico = icon
  local leftpadding = 5

  if hoverState[id] then
    col = im.ImVec4(1,0.5,0,1)
    ico = iconHover
  end
  local pBegin = im.GetCursorPos()
  im.BeginGroup()
  im.Dummy(im.ImVec2(leftpadding, 0))
  im.SameLine()
  editor.uiIconImage(ico, im.ImVec2(32, 32), col, im.ImVec4(0,0,0,0))
  im.SameLine()
  im.Dummy(im.ImVec2(leftpadding, 0))
  im.SameLine()

  local pEnd = im.GetCursorPos()
  im.BeginGroup()
  --im.BeginChild1("##" .. txt, im.ImVec2(im.GetContentRegionAvailWidth(), lowerTxt and 80 or 30), nil, im.WindowFlags_NoScrollWithMouse)
  im.TextColored(col, txt)

  if lowerTxt then
    im.PushStyleColor2(im.Col_Text, im.ImVec4(0.5, 0.5, 0.5, 1))
    im.PushTextWrapPos(im.GetCursorPosX() +  math.max(minWrap,math.min(im.GetContentRegionAvailWidth(), maxWrap-43)))
    im.TextWrapped(lowerTxt)
    im.PopTextWrapPos()
    im.PopStyleColor()
  end
  im.EndGroup()
  --im.EndChild()

  -- aparently the hover thing breaks imgui in some really weird way.
  -- solved it now by displaying invisible buttons.
  im.EndGroup()

  local size = im.GetItemRectSize()
  local cursorBefore = im.GetCursorPos()
  im.SetCursorPos(pBegin)
  local btn = im.InvisibleButton("##"..id, size)
  hoverState[id] = im.IsItemHovered()
  im.SetCursorPos(cursorBefore)
  return btn
end

function C:drawLeftColumn()
  im.BeginChild1("##leftColumn", im.ImVec2(450, 0), nil, im.WindowFlags_NoScrollWithMouse)
  im.Dummy(im.ImVec2(0, 10))
  headerText('Projects')
  if fancyIconButton('NewProject', editor.icons.folder_open, editor.icons.create_new_folder, "New Project", "") then
    local mgr, succ = core_flowgraphManager.addManager()
    self.fgEditor.setManager(mgr)
  end
  if fancyIconButton('OpenProject', editor.icons.folder_open, editor.icons.folder, "Open Project...", "") then
    extensions.editor_fileDialog.openFile(function(data)self.fgEditor.openFile(data, true)end, {{"Any files", "*"},{"Node graph Files",".flow.json"}}, false, self.fgEditor.lastOpenedFolder)
  end
  headerText('Recent Files')
  local recentFiles = editor.getPreference("flowgraph.general.recentFiles") or {}
  local btnCount = 0
  for k, file in ipairs(recentFiles) do
    if FS:fileExists(file) then
      local dir, filename, ext = path.split(file, true)
      if fancyIconButton('recent_'..k, editor.icons.folder_open, editor.icons.folder, filename, file) then
        self.fgEditor.openFile({filepath = file}, true)
      end
      btnCount = btnCount +1
    end
    if btnCount > 5 then
      break
    end
  end
  im.EndChild()
end


function C:drawRightColumn()
  --im.BeginChild1("##welcomeContentColumn2", im.ImVec2(0, 0), nil, im.WindowFlags_NoScrollWithMouse)

  im.BeginGroup()
  im.Dummy(im.ImVec2(0, 20))
  im.PushTextWrapPos(im.GetCursorPosX() + math.max(minWrap,math.min(im.GetContentRegionAvailWidth(), maxWrap)))

  headerText('Disclaimer')
  im.TextWrapped("Welcome to the Flowgraph Editor! You can use it to create new gameplay for BeamNG.Drive. If you're new, there are examples you can check out below.")
  im.Dummy(im.ImVec2(1,1))
  im.TextWrapped("If you are returning, you might notice some changes around here. Most notably, we added a State System, which greatly reduces Flowgraph size and complexity. It also makes it easier to modify existing projects.")
  im.Dummy(im.ImVec2(1,1))
  im.TextWrapped("Please keep in mind, while the Flowgraph Editor is in a good shape and can already be used to create new content, it is still WIP. That means projects that work now may not work after another update in the future.")
  im.Dummy(im.ImVec2(1,5))

  headerText('Basic Examples')
  im.TextWrapped("These are some simple examples you can check out to learn about Flowgraph. They showcase basic concepts of the Editor, such as creating and editing nodes, or working with the new state system.")
  im.Dummy(im.ImVec2(1,1))
  im.TextWrapped("You can find more examples in the Examples Window when you have a project opened.")
  im.Dummy(im.ImVec2(1,5))


  if not self._examplesSorted then
    self._examplesSorted = {}
    local res, _ = self.examples:getExamplesLookup()
    for r, e in pairs(res.beginner.examples) do
      table.insert(self._examplesSorted, e)
    end
    table.sort(self._examplesSorted, function(a,b) return (a.data.exampleOrder or 10^10) < (b.data.exampleOrder or 10^10) end )
  end
  for _, e in ipairs(self._examplesSorted) do
    if fancyIconButton('exampleE'..e.data.name, editor.icons.folder_open, editor.icons.folder,
      e.data.name, e.data.description) then
      local mgr, succ = core_flowgraphManager.addManager(e.data)
      mgr.savedDir, mgr.savedFilename = nil, nil
      self.fgEditor.setManager(mgr)
    end
  end

  im.Dummy(im.ImVec2(1,5))
  headerText('Scenario Examples')
  im.TextWrapped("These are some more advanced examples, taken from actual scenario from the game. In these, you can see how different scenarios are set up.")
  im.Dummy(im.ImVec2(1,1))
  im.TextWrapped("All of these examples can also be found in the Main Game Menu.")
  im.Dummy(im.ImVec2(1,5))


  for k, p in pairs(self.demoProjects) do
    if fancyIconButton('welcomeContentColumn2demo1' .. k, editor.icons.folder_open, editor.icons.folder, p.name, p.description) then
      local mgr, succ = core_flowgraphManager.addManager(p.data)
      --mgr.savedDir, mgr.savedFilename = nil, nil
      self.fgEditor.setManager(mgr)
    end
  end

  im.PopTextWrapPos()
  im.EndGroup()
  --im.EndChild()
  --im.ImDrawList_AddRect(im.GetWindowDrawList(), im.GetItemRectMin(), im.GetItemRectMax(), im.GetColorU322(im.ImVec4(1, 0, 0, 1)))
end

function C:draw()
  if not editor.isWindowVisible(self.windowName) then self.focus = false return end
  if self.focus then im.SetNextWindowFocus() self.focus = false end

  self:Begin('Welcome')
  self:drawContent()
  self:End()
end

function C:drawContent()
  local col = im.GetStyleColorVec4(im.Col_Text)

  --[[

  +-------------------------+
  | <header image>          |
  +-----+------+------------+
  |<si  |start | customize  |
  | de  +------+------------+
  |img> |recent| learn      |
  |     +------+------------+
  |     |help  |            |
  +-----+------+------------+

  --]]
  --im.Dummy(im.ImVec2(self.headerImageSize.x,1))
  im.PushStyleVar2(im.StyleVar_ItemSpacing, im.ImVec2(0, 0))
  im.Image(self.headerImage.texId, self.headerImageSize, im.ImVec2(0, 0), im.ImVec2(1, 1), col)
  --im.ImDrawList_AddRect(im.GetWindowDrawList(), im.GetItemRectMin(), im.GetItemRectMax(), im.GetColorU322(im.ImVec4(1, 0, 0, 1)))

  if im.GetContentRegionAvailWidth() > 500 then
    im.Image(self.sideImage.texId, self.sideImageSize, im.ImVec2(0, 0), im.ImVec2(1, 1), col)
    im.SameLine()
  end
  --im.ImDrawList_AddRect(im.GetWindowDrawList(), im.GetItemRectMin(), im.GetItemRectMax(), im.GetColorU322(im.ImVec4(1, 0, 1, 1)))

  im.PopStyleVar()
  im.PushStyleVar2(im.StyleVar_ItemSpacing,im.ImVec2(3, 3))
  im.Dummy(im.ImVec2(40, 0))
  im.SameLine()
  self:drawLeftColumn()
  im.SameLine()
  im.Dummy(im.ImVec2(40, 0))
  im.SameLine()
  self:drawRightColumn()
  im.SameLine()
  im.Dummy(im.ImVec2(40, 0))
  im.PopStyleVar()
  --im.ImDrawList_AddRect(im.GetWindowDrawList(), im.GetItemRectMin(), im.GetItemRectMax(), im.GetColorU322(im.ImVec4(0.5, 0, 1, 1)))


end

function C:_onSerialize(data)

end

function C:_onDeserialized(data)

end

return _flowgraph_createMgrWindow(C)
