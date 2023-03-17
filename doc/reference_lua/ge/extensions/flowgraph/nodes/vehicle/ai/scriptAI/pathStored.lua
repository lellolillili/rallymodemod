-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Stored AI Path'
C.color = ui_flowgraph_editor.nodeColors.ai
C.icon = ui_flowgraph_editor.nodeIcons.ai
C.description = 'Stores and provides a ScriptAI path.'
C.category = 'provider'

C.pinSchema = {
  { dir = 'out', type = 'table', name = 'path',  tableType = 'aiPath', description = 'Puts out the loaded AI path.' },
}

C.tags = {'manual', 'driveTo', 'scriptai'}

function C:init()
  self.aiPath = {}
  self.currentID = "Select..."
end

function C:_executionStopped()
end

local dbgPt = vec3()
local lastPt = vec3()
local dbgPrimA = Point2F(0.4, 0.7)
local dbgPrimB = Point2F(0.4, 0.7)
function C:drawDebugPath()

  local focusPos = vec3(Lua.lastDebugFocusPos)
  local campos = getCameraPosition()
  local camDist = (campos - focusPos):length()

  local objMax = be:getObjectCount() - 1

  --print("camDist = " .. tostring(camDist))
  local cutoffPointSq = math.min(200, math.max(100, camDist))
  --print("cutoffPoint = " .. tostring(cutoffPointSq))
  cutoffPointSq = cutoffPointSq * cutoffPointSq

  local clr = ColorF(1,0,1, 0.2)
  for k, p in pairs(self.aiPath) do
    dbgPt:set(p)
    if (dbgPt - campos):squaredLength() < cutoffPointSq then -- 100 x 100 m
      if k > 1 then
        debugDrawer:drawSquarePrism(lastPt, dbgPt, dbgPrimA, dbgPrimB, clr)
      end
    end
    lastPt:set(dbgPt)
  end
end

function C:drawCustomProperties()
  im.Text("Stored Path: " .. tostring(#self.aiPath).. " elements.")
  self:drawDebugPath()
  im.Separator()
  if im.Button("Open ScriptAIManager") then
    if editor_scriptAIManager then
      editor_scriptAIManager.open()
    end
  end
  if editor_scriptAIManager then
    im.PushItemWidth(im.GetContentRegionAvailWidth())
    if im.BeginCombo("Selector",tostring(self.currentID)) then
      for id, rec in pairs(editor_scriptAIManager.getCurrentRecordings()) do
        if im.Selectable1(tostring(id), tostring(id) == self.currentID) then
          self.currentID = id
        end
      end
      im.EndCombo()
    end
    local rec = editor_scriptAIManager.getCurrentRecordings()[self.currentID]
    if rec then
      im.Text("Path with " .. tostring(#rec.path).. " elements.")
      if im.Button("Load Selected Recording into node.") then
        self.aiPath = rec.path
      end
    end
  else
    im.Text("Open ScriptAIManager to record.")
  end
end

function C:work()
  self.pinOut.path.value = {path = self.aiPath}
end


function C:drawMiddle(builder, style)
  builder:Middle()
  im.Text(tostring(#self.aiPath) .. " elements")
end

function C:_onSerialize(res)
  res.aiPath = self.aiPath
end

function C:_onDeserialized(nodeData)
  self.aiPath = nodeData.aiPath or {}
end

return _flowgraph_createNode(C)
