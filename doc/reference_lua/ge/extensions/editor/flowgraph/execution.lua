-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local ime = ui_flowgraph_editor
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local C = {}
C.windowName = 'fg_execution'
C.windowDescription = 'Task Manager'

C.passedGraphIds = {}

function C:init()
  self.contextMenuElement = nil
  self.fgMgr = extensions['core_flowgraphManager']
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, true)
end

function C:drawManager(mgr)
  im.Separator()
  editor.uiIconImage(mgr.runningState ~= "running" and editor.icons.pause_circle_outline or editor.icons.play_circle_filled, im.ImVec2(20, 20))
  ui_flowgraph_editor.tooltip(mgr.runningState == "running" and "Project Running" or "Project Stopped")
  im.SameLine()
  if mgr.hidden then
    editor.uiIconImage(editor.icons.visibility_off, im.ImVec2(20, 20))
    ui_flowgraph_editor.tooltip("This project is invisible. You can see it because you have Dev Mode enabled.")
    im.SameLine()
  end
  if mgr.transient then

    editor.uiIconImage(editor.icons.goat, im.ImVec2(20, 20))
    ui_flowgraph_editor.tooltip("This project is transient. It cannot be saved.")
    im.SameLine()
  end
  if mgr == self.mgr then
    im.TextColored(im.ImVec4(0.8,0.8,1,1), ">"..mgr.name)
  else
    im.Text(mgr.name)
    if im.IsItemClicked() then
      self.fgEditor.setManager(mgr)
    end
  end
  im.NextColumn()

  if mgr.runningState == "running" then
    if editor.uiIconImage(editor.icons.play_arrow, im.ImVec2(20, 20)) then
      --mgr:setRunning(true)
    end
    --ui_flowgraph_editor.tooltip("Start Project Execution")
    im.SameLine()
    if editor.uiIconImageButton(editor.icons.stop, im.ImVec2(20, 20)) then
      mgr:setRunning(false)
    end
    ui_flowgraph_editor.tooltip("Stop Project Execution")
  else
    if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(20, 20)) then
      mgr:setRunning(true)
    end
    ui_flowgraph_editor.tooltip("Start Project Execution")
    im.SameLine()
    if editor.uiIconImage(editor.icons.stop, im.ImVec2(20, 20)) then
      --mgr:setRunning(false)
    end
    --ui_flowgraph_editor.tooltip("Stop Project Execution")
  end
  --im.SameLine()
  --if editor.uiIconImageButton(editor.icons.replay, im.ImVec2(20, 20)) then
  --  mgr:queueForRestart()
  --end
  --ui_flowgraph_editor.tooltip("Reset Manager")
  im.SameLine()
  if self.alone then
    if editor.uiIconImageButton(editor.icons.search, im.ImVec2(20, 20)) then
      if self.alone then
        self.fgEditor.open()
      end
      self.fgEditor.setManager(mgr)
    end
    ui_flowgraph_editor.tooltip("Select Project")
  end
  im.SameLine()
  if editor.uiIconImageButton(editor.icons.close, im.ImVec2(20, 20)) then
    if self.alone or self.mgr ~= mgr then
      self.fgMgr.removeManager(mgr)
    else
      self.fgEditor.closeCurrent()
    end
  end
  ui_flowgraph_editor.tooltip("Close Project")
  im.NextColumn()

end

function C:ExecutionView()
  if self.alone then
    self:Begin('Task Manager'..'##'..'alone')
  else
    self:Begin('Task Manager')
  end
  local avail = im.GetContentRegionAvail().x
  im.Columns(2)
  im.SetColumnWidth(0, avail-75 * im.uiscale[0])
  im.Text("Projects: ")
  im.NextColumn()
  if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(20, 20)) then
    for _, m in ipairs(self.fgMgr.getAllManagers()) do
      m:setRunning(true)
    end
  end
  ui_flowgraph_editor.tooltip("Start All Projects")
  im.SameLine()

  if editor.uiIconImageButton(editor.icons.stop, im.ImVec2(20, 20)) then
    for _, m in ipairs(self.fgMgr.getAllManagers()) do
      m:setRunning(false)
    end
  end
  ui_flowgraph_editor.tooltip("Stop All Projects")
  --im.SameLine()

  --if editor.uiIconImageButton(editor.icons.replay, im.ImVec2(25, 25)) then
 --   for _, m in ipairs(self.fgMgr.getAllManagers()) do
  --    m:queueForRestart()
   -- end
  --end
  --ui_flowgraph_editor.tooltip("Reset All Managers")
  --im.NextColumn()


  im.NextColumn()
  im.Separator()
  for _, mgr in ipairs(self.fgMgr.getAllManagers()) do
    if (not mgr.hidden and not mgr.transient) or editor.getPreference("flowgraph.debug.editorDebug") then
      self:drawManager(mgr)
    end
  end
  im.Columns(1)

  self:End()
end

function C:drawAlone()

  --if not self.mgr.mainWindow then return end
  self.mgr = nil
  self.alone = true
  self:ExecutionView()
end

function C:draw()
  --if not self.mgr.mainWindow then return end
  if not editor.isWindowVisible(self.windowName) then return end

  --if not self.fgEditor.dockspaces["NE_RightBottomPanel_Dockspace"] then self.fgEditor.dockspaces["NE_RightBottomPanel_Dockspace"] = im.GetID1("NE_RightBottomPanel_Dockspace") end
  self.alone = false
  --im.SetNextWindowDockID(self.fgEditor.dockspaces["NE_RightBottomPanel_Dockspace"])
  self:ExecutionView()
end


return _flowgraph_createMgrWindow(C)
