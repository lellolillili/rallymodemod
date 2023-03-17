-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui

local C = {}
C.windowDescription = 'Track Layout'


function C:init(raceEditor)
  self.raceEditor = raceEditor
end

function C:setPath(path)
  self.path = path
end
function C:selected() end
function C:unselect() end

function C:draw()
  self:drawGeneralInfo()
end

local function setFieldUndo(data) data.self.path[data.field] = data.old data.self:selected() end
local function setFieldRedo(data) data.self.path[data.field] = data.new data.self:selected() end

function C:changeField(field,  new)
  if new ~= self.path[field] then
    editor.history:commitAction("Changed Field " .. field.. " of Path",
    {self = self, old = self.path[field], new = new, field = field},
    setFieldUndo, setFieldRedo)
  end
end

function C:drawGeneralInfo()
  im.BeginChild1("Layout", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)

  local laps = im.IntPtr(self.path.defaultLaps)
  if im.InputInt("Lap Count", laps) then
    self:changeField("defaultLaps",math.max(laps[0], 1))
  end im.tooltip("How many laps this track has by default. Open tracks can not have more than 1 lap.")

  self:selector("Start Node", self.path.pathnodes, "startNode", ColorI(0,60,0,200), "This node should be placed on the start line for open tracks, and on the start/finish line for closed tracks.")
  self:selector("End Node", self.path.pathnodes, "endNode", ColorI(60,0,0,200), "This node should be placed on the finish line for open tracks. It is not needed for closed tracks.")

  self:selector("Default Starting Position", self.path.startPositions, "defaultStartPosition", ColorI(0,0,80,200), "This is where the vehicle will be positioned for regular mode.")
  self:selector("Reverse Starting Position", self.path.startPositions, "reverseStartPosition", ColorI(30,00,80,200), "This is where the vehicle will be positioned for reverse mode.")
  self:selector("Rolling Starting Position", self.path.startPositions, "rollingStartPosition", ColorI(0,30,80,200), "This is where the vehicle will be positioned for rolling start mode.")
  self:selector("Reverse Rolling Starting Position", self.path.startPositions, "rollingReverseStartPosition", ColorI(30,30,80,200),"This is where the vehicle will be positioned for reverse rolling start mode.")

  im.Separator()
  local classification = self.path:classify()
  im.Text("Classification:") im.tooltip("These fields show you how your track is classified. The values depend on your track layout\nas well as what values you have set for the fields above.")
  self:displayClassification(classification, "Reversible: ", 'reversible', "If the track can be reversed. Possible if both the Default Starting Position\nand Reverse Starting Positions are set, as well as the End Node for open tracks.")
  im.SameLine() im.SetCursorPosX(180)
  self:displayClassification(classification, "Rolling Start: ", 'allowRollingStart', "If the track can be started from from a distance. Possible if Rolling Start Position is set.\nIf the track is reversible, also Reverse Rolling Start has to be set.")
  self:displayClassification(classification, "Closed: ", 'closed', "If the track is closed, Lap Count can be set to values higher than 1\nand End Node does not need to be set. A non-closed track is considered Open.")
  im.SameLine() im.SetCursorPosX(180)
  self:displayClassification(classification, "Branching: ", 'branching', "Branching tracks will not compare lap times or record final times in Time Trial Mode.")
  im.Separator()
  im.EndChild()
end

function C:displayClassification(classification, name, field, tt)
  local cpx = im.GetCursorPosX()
  im.Text(name) im.SameLine() im.SetCursorPosX(cpx + 90) im.tooltip(tt or "")
  if classification[field] then
    editor.uiIconImage(editor.icons.check, im.ImVec2(24, 24))
  else
    editor.uiIconImage(editor.icons.close, im.ImVec2(24, 24))
  end
  im.tooltip(tt or "")
end



function C:selector(name, objects, fieldName, clrI, tt)
  if not objects.objects[self.path[fieldName]].missing then
    debugDrawer:drawTextAdvanced(objects.objects[self.path[fieldName]].pos,
      String(name),
      ColorF(1,1,1,1),true, false,
      clrI or ColorI(0,0,0,0.7*255))
  end

  if im.BeginCombo(name..'##'..fieldName, objects.objects[self.path[fieldName]].name) then
    if im.Selectable1('#'..0 .. " - None", objects.objects[self.path[fieldName]].id == -1) then
      self:changeField(fieldName,-1)
    end
    for i, sp in ipairs(objects.sorted) do
      if im.Selectable1('#'..i .. " - " .. sp.name, objects.objects[self.path[fieldName]].id == sp.id) then
        self:changeField(fieldName,sp.id)
      end
      if im.IsItemHovered() then
        debugDrawer:drawTextAdvanced(sp.pos,
          String(sp.name),
          ColorF(1,1,1,0.5),true, false,
          ColorI(0,0,0,0.5*255))
      end
    end
    im.EndCombo()
  end
  im.tooltip(tt or "")
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
