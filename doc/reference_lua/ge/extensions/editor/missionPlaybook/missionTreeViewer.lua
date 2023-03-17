-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local ffi = require("ffi")
local im = ui_imgui
local hColor = im.ImVec4(0.3,1,0.2,1)
local defaultStarColor = im.ImVec4(1,1,0.2,1)
local bonusStarColor = im.ImVec4(0.3,1,1,1)
local toolWindowName = "Playbook Mission Tree Viewer"

local function createRect(minR, maxR)
  local res = {
    x = minR.x,
    y = minR.y,
    w = maxR.x - minR.x,
    h = maxR.y - minR.y,
  }
  res.top_left = function() return im.ImVec2(res.x, res.y) end
  res.top_right = function() return im.ImVec2(res.x + res.w , res.y) end
  res.bottom_left = function() return im.ImVec2(res.x, res.y + res.h) end
  res.bottom_right = function() return im.ImVec2(res.x + res.w, res.y + res.h) end
  res.is_empty = function() return w == 0 and h == 0 end
  return res
end

local function GetItemRect()
  return createRect(im.GetItemRectMin(), im.GetItemRectMax())
end

local nodeSize = im.ImVec2(200,40)
M.nodes = {

}
M.nodesByMId = {}
local function pinIds(nodeId) return #M.nodes+nodeId*2+2, #M.nodes+nodeId*2+3 end

local function generateNodes()
  local nodes = {}
  M.nodesByMId = {}
  local id = 0
   for _, m in ipairs(gameplay_missions_missions.get()) do
    if m.careerSetup.showInCareer then
      id = id+1
      local node = {
        id = id,
        name = m.id,
        missionId = m.id,
        pos = vec3(m.unlocks.depth*300, id*(nodeSize.y+20),0),
      }
      ui_flowgraph_editor.SetNodePosition(node.id, im.ImVec2(node.pos.x, node.pos.y))
      table.insert(nodes, node)
      M.nodesByMId[m.id] = node
   end
  end
  M.nodes = nodes

end

local nodeColors = {
  green = im.ImVec4(0.4, 0.9, 0.55, 0.9),
  yellow = im.ImVec4(0.8, 0.8, 0.4, 0.9),
  red = im.ImVec4(0.9, 0.5, 0.45, 0.9),

}

local function drawNode(node)
  local mission = gameplay_missions_missions.getMissionById(node.missionId)
  local book = editor_missionPlaybook.book
  local data = book.results[book.page]
  local unlocks = data.unlocksById[mission.id]

  local clr = nodeColors.red

  if unlocks.visible then clr = nodeColors.yellow end
  if unlocks.startable then clr = nodeColors.green end
  local str = 0.2
  ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_NodeBg, im.ImVec4(clr.x*str, clr.y*str, clr.z*str, 0.95))
  ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_NodeBorder, clr)


  ui_flowgraph_editor.BeginNode(node.id)
  local cp = im.GetCursorPos()
  --im.Dummy(nodeSize)
  --im.SetCursorPos(cp)


  local pinIn, pinOut = pinIds(node.id)
  --ui_flowgraph_editor.SetNodePosition(node.id, node.pos)
  im.PushID4(node.id)

  ui_flowgraph_editor.PushStyleVar2(ui_flowgraph_editor.StyleVar_PivotAlignment, im.ImVec2(0.5, 0.5))
  ui_flowgraph_editor.BeginPin(pinIn,ui_flowgraph_editor.PinKind_Input)
  --im.SetCursorPosY(cp.y+nodeSize.y/2-10)
  --im.SetCursorPosX(cp.x)
  im.Dummy(im.ImVec2(10,nodeSize.y))
  ui_flowgraph_editor.EndPin()

  local itemRect = GetItemRect()
  im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), itemRect.top_left(), itemRect.bottom_right(), im.GetColorU322(clr), 3)
  im.SameLine()
  local width = math.max(im.CalcTextSize(node.name).x+20, nodeSize.x)

  im.SameLine()

  im.BeginGroup()
  im.Text(translateLanguage(mission.name, mission.name, true))

  if data and data.unlockedStars then
    for i, key in ipairs(mission.careerSetup._activeStarCache.sortedStars) do
      if i ~= 1 then im.SameLine() end
      local icon = editor.icons[data.unlockedStars[mission.id][key] and "star" or "star_border"]
      if data.unlockedThisStep[mission.id][key] then
        icon = editor.icons.stars
      end
      editor.uiIconImage(icon,im.ImVec2(20,20), mission.careerSetup._activeStarCache.defaultStarKeysByKey[key] and defaultStarColor or bonusStarColor)
    end
  end
  im.EndGroup()

  im.SameLine()


  im.SameLine()
  ui_flowgraph_editor.BeginPin(pinOut,ui_flowgraph_editor.PinKind_Output)

  im.Dummy(im.ImVec2(10,nodeSize.y))
  ui_flowgraph_editor.EndPin()
  local itemRect = GetItemRect()
  local outClr = im.ImVec4(1,1,1,1)
  im.ImDrawList_AddRectFilled(im.GetWindowDrawList(), itemRect.top_left(), itemRect.bottom_right(), im.GetColorU322(outClr), 3)
  im.SameLine()
  im.PopID()
  local ep = im.GetCursorPos()
  ui_flowgraph_editor.EndNode()




  local text = "BL  " .. mission.unlocks.maxBranchlevel
    local txtSize = im.CalcTextSize(text)
    txtSize.x = txtSize.x + 6
    txtSize.y = txtSize.y + 6
    local center = im.ImVec2(cp.x - txtSize.x, (cp.y + ep.y)/2)

    local off = im.GetWindowPos()
    im.ImDrawList_AddRectFilled(im.GetWindowDrawList(),
      im.ImVec2(center.x - txtSize.x/2 + off.x, center.y - txtSize.y/2 + off.y),
      im.ImVec2(center.x + txtSize.x/2 + off.x, center.y + txtSize.y/2 + off.y),
      im.GetColorU322(im.ImVec4(0.3, 0.3, 0.3, 1)), 3
      )
    im.ImDrawList_AddRect(im.GetWindowDrawList(),
      im.ImVec2(center.x - txtSize.x/2 + off.x, center.y - txtSize.y/2 + off.y),
      im.ImVec2(center.x + txtSize.x/2 + off.x, center.y + txtSize.y/2 + off.y),
      im.GetColorU322(im.ImVec4(clr.x*str, clr.y*str, clr.z*str, 0.6)), 3, nil , 2
      )
    im.SetCursorPos(im.ImVec2(center.x - txtSize.x/2+3, center.y - txtSize.y/2+3))
    im.Text(text)


  ui_flowgraph_editor.PopStyleVar(1)
  ui_flowgraph_editor.PopStyleColor(1)
end

local linkIds = 0
local function drawNodeLinks(node)
  local mission = gameplay_missions_missions.getMissionById(node.missionId)
  local ownPinIn, ownPinOut = pinIds(node.id)
  for _, fId in ipairs(mission.unlocks.forward) do
    local otherNode = M.nodesByMId[fId]
    local otherPinIn, otherPinOut = pinIds(otherNode.id)
    ui_flowgraph_editor.Link(linkIds, ownPinOut, otherPinIn, im.ImVec4(1,1,1,1), 2 * im.uiscale[0], false, "")
    linkIds = linkIds +1
  end

end

-- display window
local function onEditorGui()
  if not editor.isWindowVisible("Mission Playbook") then return end
  if editor.beginWindow(toolWindowName, toolWindowName,  im.WindowFlags_MenuBar) then
    local book = editor_missionPlaybook.book
    if book and book.results and book.results[book.page] then
      local savedEctx = ui_flowgraph_editor.GetCurrentEditor()

      if not M.previewEctx then
        M.previewEctx = ui_flowgraph_editor.CreateEditor(ui_imgui.ctx)
      end

      ui_flowgraph_editor.SetCurrentEditor(M.previewEctx)


      if im.Button("Generate") then
        generateNodes()
      end
      ui_flowgraph_editor.Begin('asdfsdd', im.ImVec2(0, 0), false)
      --ui_flowgraph_editor.NavigateToContent(0.01)
      for _, node in ipairs(M.nodes) do
        drawNode(node)
      end
      linkIds = 0
      for _, node in ipairs(M.nodes) do
        drawNodeLinks(node)
      end
      ui_flowgraph_editor.End()
      if (bit.band(tonumber(ui_flowgraph_editor.GetDirtyReason()), ui_flowgraph_editor.Dirty_Position) ~= 0) then
        dump("AD")
        ui_flowgraph_editor.ClearDirty()
      end


      ui_flowgraph_editor.SetCurrentEditor(savedEctx)

    end
    editor.endWindow()
  end
end


local function onWindowMenuItem()
  editor.showWindow("Mission Playbook")
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, im.ImVec2(500,500))
  editor.addWindowMenuItem(toolWindowName, onWindowMenuItem, {groupMenuName="Missions"})
end

local function onPlaybookLogAfterStep(resultData)
  local unlockedStars = {}
  local unlockedThisStep = {}
  local unlocksById = {}
  for _, m in ipairs(gameplay_missions_missions.get()) do
    if m.careerSetup.showInCareer then
      unlockedStars[m.id] = deepcopy(m.saveData.unlockedStars)
      unlockedThisStep[m.id] = {}
      unlocksById[m.id] = deepcopy(m.unlocks)

    end
  end
  resultData.unlockedStars = unlockedStars

  if resultData.funRet and resultData.funRet.unlockedStarsChanged then
    unlockedThisStep[resultData.funRet.missionId] = deepcopy(resultData.funRet.unlockedStarsChanged)
  end
  resultData.unlockedThisStep = unlockedThisStep
  resultData.unlocksById = unlocksById
  dump(resultData.unlockedThisStep)

end
M.onPlaybookLogAfterStep = onPlaybookLogAfterStep

M.onEditorInitialized = onEditorInitialized
M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onEditorGui = onEditorGui
M.show = onWindowMenuItem

return M
