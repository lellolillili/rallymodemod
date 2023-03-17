-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im = ui_imgui

local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local C = {}

local enableUsageTracking = true

function C:init(graph, node, direction, type, name, default, description)
  self.graph = graph
  self.id = graph.mgr:getNextFreePinLinkId()
  if self.graph.mgr.__safeIds then
    if self.graph.mgr:checkDuplicateId(self.id) then
      log("E", "", "Duplicate ID error! Pin")
      print(debug.tracesimple())
    end
  end
  self.hardTemplates = {}
  self.name = name
  self.type = type
  self.pinMode = 'normal'
  self.node = node
  self.direction = direction
  self.default = default
  self.defaultValue = default
  self.description = description
  self.hidden = false
  self.links = {}

  -- This is the type for the hardcoded value for an any-pin
  -- if self.type == "any" then
  --   self.hardCodeType = "string"
  -- end

  if enableUsageTracking then
    self._value = default or nil
    local mt = getmetatable(self)
    mt.__index = function(tbl, key)
      if key == 'value' then
        tbl._frameLastUsed = tbl.graph.mgr.frameCount
        key = '_value'
        --print('> > > > > KEY: ' .. tostring(key))

      end
      local val = rawget(tbl, key)
      if val ~= nil then
        return val
      else
        return rawget(mt, key)
      end
    end
    mt.__newindex = function(tbl, key, value)
      if key == 'value' then
        --[[
        if tbl.id == GlobTrackingId then
          print("Changin Pin value to " .. tostring(value))
          print(debug.tracesimple())
        end
        ]]
        tbl._frameLastUsed = tbl.graph.mgr.frameCount
        key = '_value'
      end
      rawset(tbl, key, value)
    end
  else
    self.value = default or nil
  end

  if self.direction == 'out' and self.type == 'delegate' then
    self.hasOutputDelegates = true
  end
  --dumpz(self,2)
end

function C:getFirstConnectedLink()
  return self.links[1]
end

local function formatValueForDisplay(val, hardType)
  local type = hardType or type(val)
  if type == 'number' then
    return string.format('%g', val)
  elseif type == 'vec3' then
    return string.format('{%g, %g, %g}', val[1], val[2], val[3])
  elseif type == 'color' then
    return string.format('{%g, %g, %g, %g}', val[1], val[2], val[3], val[4])
  elseif type == 'quat' then
    return string.format('{%g, %g, %g, %g}', val[1], val[2], val[3], val[4])
  elseif type == 'table' then
    return '{...}'
  end
  return tostring(val)
end

function C:_draw_in(builder, style, alpha, simpleDraw, constValue, outWidth)
  local mgr = self.graph.mgr
  local scale = im.uiscale[0]
  local xStart = im.GetCursorPosX()
  self.imPos = im.GetCursorPos()
  if constValue == nil then
    mgr:DrawTypeIcon(self:getTypeWithImpulseAndChain(), self:isUsed(), (constValue ~= nil) and alpha * 0.5 or alpha, nil, (constValue ~= nil) and im.ImVec4(0, 0, 1, 1) or nil)
  else
    editor.uiIconImage(editor.icons.lock_outline, im.ImVec2(24 * scale, 24 * scale), ui_flowgraph_editor.getTypeColor(self.type))
  end

  if simpleDraw ~= 'simple' then
    local displayName = self.quickAccess and ('[' .. self.accessName .. ']') or self.name
    if constValue ~= nil and editor.getPreference("flowgraph.general.displayConstPinValues") then
      --if self.type == 'number' or self.type == 'bool' or self.type == 'string' then
      im.SameLine()
      im.TextUnformatted(tostring(displayName) .. '=' .. ui_flowgraph_editor.shortValueString(constValue, self.type)) --formatValueForDisplay(constValue))
      -- else
      --  im.TextUnformatted(tostring(self.name) .. '= (' .. tostring(self.type) .. ')')
      --end
    else
      local hide = ((self.name == 'value' or self.name == 'flow') and editor.getPreference("flowgraph.general.hideSimpleNames"))
      if not hide then
        im.SameLine()
        im.TextUnformatted(displayName)
        --im.TextUnformatted(self.name .. ' [' .. self.id .. ']')
      end
    end
  end
  im.SameLine()
  im.Dummy(im.ImVec2((xStart + outWidth - (im.GetCursorPosX() + 4)), 1))
end

function C:_draw_out(builder, style, alpha, simpleDraw, const, outWidth)
  local xStart = im.GetCursorPosX()
  if simpleDraw ~= 'simple' then
    local displayName = self.quickAccess and ('[' .. self.accessName .. ']') or self.name
    local hide = ((self.name == 'value' or self.name == 'flow') and editor.getPreference("flowgraph.general.hideSimpleNames"))
    if not hide then
      local dnWidth = im.CalcTextSize(displayName)
      im.SetCursorPosX(xStart + outWidth - 16 - dnWidth.x - 3)
      im.TextUnformatted(displayName)
      im.SameLine()
      --im.TextUnformatted('[' .. self.id .. '] ' .. self.name)
    end
  end
  im.SetCursorPosX(xStart + outWidth - 16)

  self.imPos = im.GetCursorPos()
  self.graph.mgr:DrawTypeIcon(self:getTypeWithImpulseAndChain(), self:isUsed(), alpha)
end

-- getter for type with inclusion of impulse (mostly for drawing icons)
function C:getTypeWithImpulseAndChain()
  return self.impulse and 'impulse' or self.chainFlow and 'chainFlow' or self.type
end

function C:getTableType()
  if self.type == "table" or (type(self.type) == "table" and tableContains(self.type, "table")) then
    return self.tableType or "generic"
  else
    return ""
  end
end

function C:_getCalculatedWidth(simpleDraw)
  local displayName = self.quickAccess and ('[' .. self.accessName .. ']') or self.name
  if editor.getPreference("flowgraph.debug.viewMode") == 'simple' then
    displayName = ""
  end
  local textWidth = 0
  local fixedPadding = 8
  local hide = ((self.name == 'value' or self.name == 'flow') and editor.getPreference("flowgraph.general.hideSimpleNames"))
  if not hide then
    textWidth = im.CalcTextSize(displayName).x
    fixedPadding = 16
  end
  return ui_flowgraph_editor.defaultTypeIconSize + textWidth + fixedPadding
end

-- checks if the pin is usable when creating new links. Active = pin usable, drawn / inactive = in background and unusable
function C:isActive()
  local mgr = self.graph.mgr
  if mgr.newLinkPin and not self.graph:canCreateLink(mgr.newLinkPin, self, mgr._creationWorkflowInfo) and self ~= mgr.newLinkPin then
    return false
  end
  return true
end

function C:drawTooltip(mgr)
  if editor_flowgraphEditor.allowTooltip then
    -- Push style changes
    im.PushStyleVar2(im.StyleVar_WindowPadding, im.ImVec2(5, 5))
    im.PushStyleColor2(im.Col_Separator, im.ImVec4(1.0, 1.0, 1.0, 0.175))
    if self.graph.mgr.runningState ~= "running" then
      im.PushStyleColor2(im.Col_Border, im.ImVec4(1.0, 1.0, 1.0, 0.25))
    end
    im.BeginTooltip()
    im.PushTextWrapPos(200)
    local connectedLink = self:getFirstConnectedLink()

    self.graph.mgr:DrawTypeIcon(self.type, connectedLink ~= nil, 1, nil, (constValue ~= nil) and im.ImVec4(0, 0, 1, 1) or nil)
    im.SameLine()
    im.TextUnformatted(self.name)
    im.Separator();

    local typeTxt
    if self.direction == 'out' then
      typeTxt = 'Out'
    elseif self.direction == 'in' then
      typeTxt = 'Valid'
    end
    if type(self.type) == 'table' then
      typeTxt = typeTxt .. ' types: ' .. dumps(self.type)
    else
      typeTxt = typeTxt .. ' type: ' .. tostring(self.type)
    end
    local val = self.hardCodeType and self.value or self._value

    if connectedLink and connectedLink.targetPin == self then
      typeTxt = 'Connected type: ' .. dumps(connectedLink.sourcePin.type)
      val = connectedLink.sourcePin._value
    end
    im.TextUnformatted(typeTxt)

    if self.type == "table" or (type(self.type) == 'table' and tableContains(self.type,'table')) then
      im.TextUnformatted("Table type: "..self:getTableType())
    end

    --im.TextUnformatted('Value: ' .. valStr)
    --im.Text(val)
    --im.Text("_hardcodedDummyPin = " .. tostring(self._hardcodedDummyPin))
    --im.Text("HC Type = " .. tostring(self.hardCodeType))
    --im.Text(ui_flowgraph_editor.fullValueString(val, self.hardCodeType and self.hardCodeType or self.type))
    --im.TextUnformatted('PIN ID: ' .. tostring(self.id))
    --im.TextUnformatted("lastUsed: " .. tostring(self._frameLastUsed))

    if self.description then
      im.Separator();
      im.TextUnformatted('Description: ' .. tostring(self.description))
    end
    if editor.getPreference("flowgraph.debug.displayIds") then
      im.Separator();
      im.TextUnformatted("ID: " .. self.id)
    end
    im.PopTextWrapPos()
    im.EndTooltip()

    -- Pop style changes
    im.PopStyleVar()
    im.PopStyleColor()
    if self.graph.mgr.runningState ~= "running" then
      im.PopStyleColor()
    end
  end
end

function C:highlightLinks()
  for i, lnk in pairs(self.links) do
    lnk._highlight = true
  end
end

function C:draw(builder, style, isHeader, constValue, outWidth)
  local mgr = self.graph.mgr

  local alpha = style.Alpha
  local isActive = self:isActive()
  if not isActive then
    alpha = alpha * 0.188
  end

  im.PushStyleVar1(im.StyleVar_Alpha, alpha)



  -- call specific draw functions
  if constValue ~= nil then
    ui_flowgraph_editor.PushStyleColor(ui_flowgraph_editor.StyleColor_PinRect, im.ImVec4(0, 0.7, 0, 0.5))
    --ui_flowgraph_editor.PushStyleVar1(ui_flowgraph_editor.StyleVar_PinCorners, 8)
  end

  builder:BeginPinDynamic(self)
  self['_draw_' .. self.direction](self, builder, style, alpha, editor.getPreference("flowgraph.debug.viewMode"), constValue, outWidth)
  builder:EndPinDynamic(self)

  if constValue ~= nil then
    --ui_flowgraph_editor.PopStyleVar(1)
    ui_flowgraph_editor.PopStyleColor(1)
  end
  self._hovered = im.IsItemHovered()
  self._hoverPos = im.GetCursorPos()
  if im.IsItemClicked() then
    ui_flowgraph_editor.ClearSelection()
    ui_flowgraph_editor.SelectNode(self.node.id, true)
  end

  im.PopStyleVar()

  return isActive
end

function C:hoverDraw(mgr)
  if self._hovered then
    self:highlightLinks()
    self:drawTooltip(mgr)
  end
end

function C:showContextMenu(menuPos, main)
  im.SetWindowFontScale(editor.getPreference("ui.general.scale"))
  if self.node.graph.mgr.allowEditing then
    main:showQuickAccessSubmenu(menuPos, self)

    if next(self.links) then
      im.MenuItem1("Hide this pin", nil, false, false)
    else
      if im.MenuItem1("Hide this pin") then
        self.hidden = true
      end
    end
  end
  if im.MenuItem1("Show all links") then
    for _, link in ipairs(self.links) do
      link.hidden = false
    end
  end
  if im.MenuItem1("Hide all links") then
    for _, link in ipairs(self.links) do
      link.hidden = true
    end
  end
  if self.node.graph.mgr.displayIDs then
    im.Separator()
    im.Text("id: %s", tostring(self.id))
    im.Text("Node: %s", tostring(self.node.id))
    im.Separator()
  end
  if editor.getPreference("flowgraph.debug.editorDebug") then
    if im.BeginMenu('Dumpz Node') then
      --im.SetWindowFontScale(editor.getPreference("ui.general.scale"))
      for i = 1, 5 do
        if im.MenuItem1("Depth " .. i) then
          dumpz(self, i)
        end
      end
      --im.SetWindowFontScale(1)
      im.EndMenu()
    end
  end
end

function C:_onLink(link)
  if self.type ~= 'flow' and self.direction == 'in' then
    self.links[1] = link
  else
    table.insert(self.links, link)
  end
  self.hidden = false
end

function C:_onUnlink(link)
  --if self.type ~= 'flow' then
  --  self.links[1] = nil
  --else
  for i, lnk in ipairs(self.links) do
    if lnk == link then
      table.remove(self.links, i)
      break
    end
  end
  --end
end

function C:isUsed()
  return next(self.links) ~= nil or self.pinMode == 'hardcoded'
end

function C:valueSetVec3(v)
  self.valueHelperTable = self.valueHelperTable or table.new(4,0)
  table.clear(self.valueHelperTable)
  self.valueHelperTable[1] = v.x
  self.valueHelperTable[2] = v.y
  self.valueHelperTable[3] = v.z
  self.valueHelperTable[4] = nil
  self.value = self.valueHelperTable
end

function C:valueSetQuat(v)
  self.valueHelperTable = self.valueHelperTable or table.new(4,0)
  self.valueHelperTable[1] = v.x
  self.valueHelperTable[2] = v.y
  self.valueHelperTable[3] = v.z
  self.valueHelperTable[4] = v.w
  self.value = self.valueHelperTable
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end