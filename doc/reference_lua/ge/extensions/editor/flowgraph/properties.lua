-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local imu = require('ui/imguiUtils')
local fg_utils = require('/lua/ge/extensions/flowgraph/utils')

local C = {}
local previousNode
C.windowName = 'fg_properties'
C.windowDescription = 'Properties'


C.dirtyChildren = nil

function C:init()
  editor.registerWindow(self.windowName, im.ImVec2(150,300), nil, true)
  self.previousNode = nil
  self.headerTexture = imu.texObj('art/imgui_node_header.png')
end

function C:_drawInputField(path, cdata, type, v, savePath, saveCallback, enterOnly, padRight, pin)
  local editEnded = im.BoolPtr(false)
  im.PushItemWidth(im.GetContentRegionAvailWidth() - (padRight or 0))
  local inputFlags = im.InputTextFlags_EnterReturnsTrue
  if type == 'number' then
    local setup = pin and pin.numericSetup or {}
    setup.type = setup.type or 'float'
    setup.gizmo = setup.gizmo or 'input'
    if setup.type == 'float' then
      if not cdata[path] then
        cdata[path] = im.FloatPtr(v)
      end
      if setup.gizmo == 'input' then
        editor.uiInputFloat("##input" .. path, cdata[path], setup.step, setup.stepFast, setup.format, nil, editEnded)
      elseif setup.gizmo == 'slider' then
        editor.uiSliderFloat("##input" .. path, cdata[path], setup.min, setup.max, setup.format, setup.power, editEnded)
      end
    elseif setup.type == 'int' then
      if not cdata[path] then
        cdata[path] = im.IntPtr(v)
      end
      if setup.gizmo == 'input' then
        editor.uiInputInt("##input" .. path, cdata[path], setup.step, setup.stepFast, nil, editEnded)
      elseif setup.gizmo == 'slider' then
        editor.uiSliderInt("##input" .. path, cdata[path], setup.min, setup.max, setup.format, editEnded)
      end
    end
    if editEnded[0] then
      if setup.min then cdata[path][0] = math.max(cdata[path][0], setup.min) end
      if setup.max then cdata[path][0] = math.min(cdata[path][0], setup.max) end
      saveCallback(savePath, cdata[path][0])
    end
  elseif type == 'string' then
    if not cdata[path] then
      cdata[path] = im.ArrayChar(8192, v)
    end
    im.PopItemWidth()
    im.PushItemWidth(im.GetContentRegionAvailWidth() - (padRight or 0) - 30)
    if editor.uiInputText("##input" .. path, cdata[path], nil, nil, nil, nil, editEnded) then
    end
    if editEnded[0] then
      saveCallback(savePath, ffi.string(cdata[path]))
    end
    im.SameLine()
    if editor.uiIconImageButton(editor.icons.format_line_spacing, im.ImVec2(22,22)) then
      self._editMultilineText = {saveCallback = saveCallback, buf = im.ArrayChar(8192, v), pos = im.GetCursorScreenPos()}
    end

    --im.PopItemWidth()

  elseif type == 'bool' or type == 'boolean' then
    if not cdata[path] then
      cdata[path] = im.BoolPtr(v)
    end
    if im.Checkbox("##input" .. path, cdata[path]) then
      saveCallback(savePath, cdata[path][0])
    end
  elseif type == 'vec3' then
    if not cdata[path] then
      cdata[path] = im.ArrayFloat(3)
      cdata[path][0] = im.Float(v[1])
      cdata[path][1] = im.Float(v[2])
      cdata[path][2] = im.Float(v[3])
    end
    if editor.uiInputFloat3("##input" .. path, cdata[path], nil, inputFlags, editEnded) then
    end
    if editEnded[0] then
      saveCallback(savePath, {cdata[path][0],cdata[path][1],cdata[path][2]})
    end
  elseif type == 'quat' then
    if not cdata[path] then
      cdata[path] = im.ArrayFloat(4)
      cdata[path][0] = im.Float(v[1])
      cdata[path][1] = im.Float(v[2])
      cdata[path][2] = im.Float(v[3])
      cdata[path][3] = im.Float(v[4])
    end
    if editor.uiInputFloat4("##input" .. path, cdata[path], nil, inputFlags, editEnded) then
    end
    if editEnded[0] then
      saveCallback(savePath, {cdata[path][0],cdata[path][1],cdata[path][2],cdata[path][3]})
    end
  elseif type == 'color' then
    local setup = pin and pin.colorSetup or {}
    setup.vehicleColor = setup.vehicleColor
    if setup.vehicleColor then
      if not cdata[path] then
        cdata[path] = {
         clr = im.ArrayFloat(8),
         pbr = {}
        }
        cdata[path].clr[0] = im.Float(v[1])
        cdata[path].clr[1] = im.Float(v[2])
        cdata[path].clr[2] = im.Float(v[3])
        cdata[path].clr[3] = im.Float(v[4])
        cdata[path].pbr[1] = im.FloatPtr(v[5] or 0.5)
        cdata[path].pbr[2] = im.FloatPtr(v[6] or 0.2)
        cdata[path].pbr[3] = im.FloatPtr(v[7] or 0.8)
        cdata[path].pbr[4] = im.FloatPtr(v[8] or 0)

      end
      editor.uiColorEdit8("##input" .. path, cdata[path], nil, editEnded)
      if editEnded[0] then
        --dump({cdata[path].clr[0],cdata[path].clr[1],cdata[path].clr[2],cdata[path].clr[3], cdata[path].other[1][0]})
        saveCallback(savePath, {
          cdata[path].clr[0],cdata[path].clr[1],cdata[path].clr[2],cdata[path].clr[3],
          cdata[path].pbr[1][0], cdata[path].pbr[2][0], cdata[path].pbr[3][0], cdata[path].pbr[4][0]}
        )
      end
    else
      if not cdata[path] then
        cdata[path] = im.ArrayFloat(4)
        cdata[path][0] = im.Float(v[1])
        cdata[path][1] = im.Float(v[2])
        cdata[path][2] = im.Float(v[3])
        cdata[path][3] = im.Float(v[4])
      end
      editor.uiColorEdit4("##input" .. path, cdata[path], inputFlags, editEnded)
      if editEnded[0] then
        saveCallback(savePath, {cdata[path][0],cdata[path][1],cdata[path][2],cdata[path][3]})
      end
    end

  elseif type == 'table' then
   -- im.BeginChild1('##innertable' .. path, im.ImVec2(0, 0))
   -- self:_drawDataTable(path, cdata, v, savePath, saveCallback, true)
   -- if im.SmallButton("Add element") then end -- Todo: being able to dynamically add an element to the table
   -- im.EndChild()
   im.TextUnformatted('(Not supported)')
  else
    im.TextUnformatted('(' .. tostring(type) .. ')')
  end
end

function C:_drawDataTable(path, cdata, v, savePath, saveCallback, keysEditable)
  local orderedKeys = tableKeys(v or {})
  table.sort(orderedKeys)

  if savePath ~= '' then
    savePath = savePath .. '.'
  end

  if #orderedKeys == 1 and orderedKeys[1] == 'value' then
    -- shortcut for one value
    local k = orderedKeys[1]
    self:_drawInputField(path .. k .. '_val', cdata, type(v[k]), v[k], savePath .. k, function(_savePath, newVal) v[k] = newVal ; if saveCallback then saveCallback(_savePath, newVal) end ; end, true)
  else
    im.Columns(2)
    for _, k in ipairs(orderedKeys) do
      if keysEditable then
        self:_drawInputField(path .. k .. '_key', cdata, type(k), k, savePath .. k, function(_savePath, newKey)
          v[newKey] = v[k]
          v[k] = nil
          if saveCallback then saveCallback(_savePath, v[k]) end
        end, true)
      else
        im.Text(tostring(k))
      end
      im.NextColumn()
      self:_drawInputField(path .. k .. '_val', cdata,type(v[k]),  v[k], savePath .. k,
        function(_savePath, newVal)
          v[k] = newVal
          if saveCallback then
            saveCallback(_savePath, newVal)
          end
        end, true)
      im.NextColumn()
    end
    im.Columns(1)
    -- if im.Button('add') then
    --   -- TODO
    -- end
  end
end

function C:customPropertyColor(item, customName, cdata)
  local editEnded = im.BoolPtr(false)
  local reason = nil
  editor.uiColorEdit4("##colorIcon"..customName, cdata, bit.bor(im.InputTextFlags_EnterReturnsTrue, im.ColorEditFlags_NoInputs), editEnded)
  if editEnded[0] then
    local clr = cdata
    item[customName] = im.ImVec4(clr[0],clr[1],clr[2],clr[3])
    reason = "Changed icon color for " .. item.name
  end
  return reason
end

function C:initCustomProperties(item)
  self._editCustomProperties = {}
  self._editCustomProperties.name = im.ArrayChar(256, tostring(item.customName or item.name or ''))
  --self._editCustomProperties.icon = im.ArrayChar(256, tostring(item.customIcon or item.icon or ''))
  local imVal = im.ArrayFloat(4)
  local val = item.customColor or item.color
  imVal[0] = im.Float(val.x)
  imVal[1] = im.Float(val.y)
  imVal[2] = im.Float(val.z)
  imVal[3] = im.Float(val.w)
  self._editCustomProperties.color = imVal

  imVal = im.ArrayFloat(4)
  val = item.iconColor or item.customIconColor
  imVal[0] = im.Float(val.x)
  imVal[1] = im.Float(val.y)
  imVal[2] = im.Float(val.z)
  imVal[3] = im.Float(val.w)
  self._editCustomProperties.iconColor = imVal
end
function C:drawItemHeader( item)
  if not item then return end

  -- ImDrawList_ctx, ImTextureID_user_texture_id, ImVec2_a, ImVec2_b, ImVec2_uv_a, ImVec2_uv_b, ImU32_col, float_rounding, int_rounding_corners)
  local style = im.GetStyle()
  local a = im.GetCursorScreenPos()
  local b = im.GetContentRegionAvail()
  local xx = style.WindowPadding.x
  local yy = style.WindowPadding.y
  a.x = a.x - xx
  a.y = a.y - yy
  b = im.ImVec2(a.x + b.x + xx * 2, a.y + im.GetFontSize() + 16)
  local uv = im.ImVec2(0.5, 0.1)
  im.ImDrawList_AddImageRounded(im.GetWindowDrawList(), self.headerTexture.texId, a, b, im.ImVec2(0, 0), uv, im.GetColorU322(item.color), 0, 0)

  im.PushItemWidth(100)
  im.Dummy(im.ImVec2(0,24))
  im.SameLine()
  local changed = false
  if not self._editCustomProperties then
    if editor.uiIconImageButton(editor.icons.mode_edit, im.ImVec2(22, 22)) then
      self:initCustomProperties(item)
      changed = true
    end
    im.SameLine()
  end
  local reset = false
  if self._editCustomProperties then
    local reason = nil
    local editEnded = im.BoolPtr(false)

    if im.BeginPopup("FGIconSelector") then
      im.BeginChild1("fgSelIcon", im.ImVec2(250*im.uiscale[0],400*im.uiscale[0]))
      editor_iconOverview.drawContent(function(v)
        item.customIcon = v
        reason = "Set custom icon for  " .. item.name .." to " .. v
        im.CloseCurrentPopup() end)
      im.EndChild()
      im.EndPopup()
    end
    if item.icon or item.customIcon then
      reason = self:customPropertyColor(item, "customIconColor", self._editCustomProperties.iconColor) or reason
      im.SameLine()
      if item.customIconColor then
        if editor.uiIconImageButton(editor.icons.undo, im.ImVec2(22,22)) then
          item.customIconColor = nil
          reason = "Reset custom Icon Color for " .. item.name
          self:initCustomProperties(item)
        end
      end
      im.SameLine()
    end

    if editor.uiIconImageButton(editor.icons[item.customIcon or item.icon or "add"], im.ImVec2(22, 22)) then
      im.OpenPopup("FGIconSelector")
    end
    if item.customIcon then
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.undo, im.ImVec2(22,22)) then
        item.customIcon = nil
        reason = "Reset custom Icon for " .. item.name
        self:initCustomProperties(item)
      end
    end
    im.SameLine()



    im.SameLine()
    im.Dummy(im.ImVec2(20,1))
    im.SameLine()
    reason = self:customPropertyColor(item, "customColor", self._editCustomProperties.color) or reason
    if item.customColor then
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.undo, im.ImVec2(22,22)) then
        item.customColor = nil
        reason = "Reset custom Color for " .. item.name
        self:initCustomProperties(item)
      end
    end
    im.SameLine()
    im.PushItemWidth(im.GetContentRegionAvailWidth()-64)

    if im.InputText('##Name', self._editCustomProperties.name, 256, im.InputTextFlags_EnterReturnsTrue) then
      if item.onCustomNameChanged then
        reason = item:onCustomNameChanged(ffi.string(self._editCustomProperties.name))
      else
        item.customName = ffi.string(self._editCustomProperties.name)
        reason = "Changed custom name for " .. item.name
      end
      -- History
    end
    if changed then im.SetKeyboardFocusHere() end
    if item.customName then
      im.SameLine()
      if editor.uiIconImageButton(editor.icons.undo, im.ImVec2(22,22)) then
        item.customName = nil
        reason = "Reset custom Name for " .. item.name
        self:initCustomProperties(item)
      end
    end
    im.SameLine()
    if editor.uiIconImageButton(editor.icons.check or editor.icons.add, im.ImVec2(22, 22)) then
      -- save name again in case enter has not been pressed
      if item.customName ~= ffi.string(self._editCustomProperties.name) and item.name ~= ffi.string(self._editCustomProperties.name) then
        if item.onCustomNameChanged then
          reason = item:onCustomNameChanged(ffi.string(self._editCustomProperties.name))
        else
          item.customName = ffi.string(self._editCustomProperties.name)
          reason = "Changed custom name for " .. item.name
        end
      end
      reset = true
    end
    if reset then self._editCustomProperties = nil  end
    if reason then self.fgEditor.addHistory(reason) end
  else
    local icon = item.customIcon or item.icon
    if icon and editor.icons[icon] then
      editor.uiIconImage(editor.icons[icon], im.ImVec2(22, 22), item.customIconColor or item.iconColor)
      im.SameLine()
    end
    im.Text(item.customName or item.name)
    if editor.getPreference("flowgraph.debug.displayIds") then
      im.SameLine()
      im.TextUnformatted('[' .. tostring(item.id) .. ']: ')
    end
    if item.category and item.tmpSecondPassFlag and ui_flowgraph_editor.isDynamicNode(item.category) then
      im.SameLine()
      if item.dynamicMode and item.dynamicMode == 'repeat' then
        im.TextUnformatted('( Repeat )')
        im.SameLine(im.GetWindowWidth() - 110)
        if im.Button("Set Once", im.ImVec2(90, 22)) then
          item:setDynamicMode('once')
        end
      else
        im.TextUnformatted('( Once )')
        im.SameLine(im.GetWindowWidth() - 110)
        if im.Button("Set Repeat", im.ImVec2(90, 22)) then
          item:setDynamicMode('repeat')
        end
      end
    end
    if item.type and item.type ~= 'node' then
      im.SameLine()
      im.TextUnformatted('(' .. tostring(item.type or '') .. ')')
    end
  end


  if item.targetID and editor.getPreference("flowgraph.debug.displayIds") then
    im.Text("targetID: " .. item.targetID)
  end

  im.Separator()
end

function C:getFirstAllowedType(types)
  if types == nil then return "number" end
  local tpe = 'bool'
  local allowList = {}
  for k, v in pairs(types) do if v then table.insert(allowList, k) end end
  table.sort(allowList)
  return allowList[1] or 'bool'
end

function C:drawCustomInPins(item)
  im.PushItemWidth(200)
  if im.TreeNodeEx1('Input Pins##propertiesPinIn_' .. "self_id", im.TreeNodeFlags_DefaultOpen) then
    --im.Columns(2, 'pinListOut' .. "self_id")
    im.Columns(2)
    im.SetColumnWidth(0, 70 * im.uiscale[0])
    for pid, pin in ipairs(item.pinList) do
      if pin.direction == 'in' then
        im.Text("Name")
        im.NextColumn()
        im.PushItemWidth(im.GetContentRegionAvail().x)
        if pin.fixed then
          im.Text(pin.name) im.tooltip("Fixed pins name can't be changed.")
        else
          local textinput = im.ArrayChar(256, tostring(pin.name or ''))
          if im.InputText('##Name' .. pin.id, textinput, 256, im.InputTextFlags_EnterReturnsTrue) then
            local oldName = pin.name
            if ffi.string(textinput) ~= '' and ffi.string(textinput):gsub("[%s]",""):len()~=0 then
              pin.name = ffi.string(textinput)
              item.pinInLocal[oldName] = nil
              item.pinInLocal[pin.name] = pin
              -- History
              self.fgEditor.addHistory("Renamed pin " .. oldName.. " to " .. pin.name)
            else
              textinput = im.ArrayChar(256, tostring(pin.name or ''))
            end
          end
        end
        im.NextColumn()

        local firstLink = pin:getFirstConnectedLink()

        if pin.hidden then
          editor.uiIconImage(editor.icons.visibility_off, im.ImVec2(24, 24), im.ImVec4(0.3, 0.3, 0.3, 1))
          if im.IsItemClicked() and self.mgr.allowEditing then
            pin.hidden = false
          end
        else
          editor.uiIconImage(editor.icons.visibility, im.ImVec2(24, 24), ui_flowgraph_editor.getTypeColor(pin.type))
          if im.IsItemClicked() and self.mgr.allowEditing and not firstLink then
            pin.hidden = true
          end
        end
        im.SameLine()

        local firstLink = pin:getFirstConnectedLink()

        local constValue = item:getPinInConstValue(pin.name)
        if pin.pinMode == 'hardcoded' then
          editor.uiIconImage(editor.icons.lock_outline, im.ImVec2(24, 24), ui_flowgraph_editor.getTypeColor(pin.type))
          if im.IsItemClicked() and self.mgr.allowEditing then
              item:_setHardcodedDummyInputPin(pin, nil)
              --item._cdata = nil
              -- History
              self.fgEditor.addHistory("Un-Hardcoded pin " ..pin.name)
          end
        elseif pin.pinMode == 'normal' then
          self.mgr:DrawTypeIcon(pin:getTypeWithImpulseAndChain(), firstLink ~= nil, 1, nil, (constValue ~= nil) and im.ImVec4(0,0,1,1) or nil)
          if im.IsItemClicked() and self.mgr.allowEditing and not firstLink and pin.type ~= 'table' then
            item:_setHardcodedDummyInputPin(pin, pin.defaultValue or fg_utils.getDefaultValueForType(pin.type), pin.defaultHardCodeType)
            if item._cdata then
              item._cdata['pins' .. pin.id ..'_val'] = nil
            end
            --item._cdata = nil
            -- History
            self.fgEditor.addHistory("Hardcoded pin " .. pin.name)
          end
        end

        --self.mgr:DrawTypeIcon(pin:getTypeWithImpulseAndChain(), pin:getFirstConnectedLink() ~= nil, 1)
        im.NextColumn()

        if not pin.fixed then
          if type(pin.type) ~= 'table' then
            if im.BeginCombo("##pinType" .. pin.id, pin.type) then
              for typename, type in pairs(ui_flowgraph_editor.getTypes()) do
                if item.allowedManualPinTypes == nil or item.allowedManualPinTypes[typename] then
                  self.mgr:DrawTypeIcon(typename, true, 1)
                  im.SameLine()
                  if im.Selectable1(typename, typename==pin.type) then
                    -- History
                    pin.type = typename
                    item:_setHardcodedDummyInputPin(pin, nil)
                    -- Check if the link should be deleted now
                    for k, link in pairs(item.graph.links) do
                      if link.targetPin == pin then
                        -- Found the right link. Now check if the pin types are still compatible
                        if not item.graph:pinsCompatible(link.sourcePin, link.targetPin) then
                          item.graph:deleteLink(link)
                        end
                      end
                    end
                    self.fgEditor.addHistory("Changed pin " .. pin.name .. " type to " .. pin.type)
                  end
                end
              end
              im.EndCombo()
            end
          else
            im.Text("Multi-Type. TBD")
          end
        end
        im.NextColumn()
        im.Text("Value")
        im.NextColumn()
        local hasHardTemplates = (pin.hardTemplates and next(pin.hardTemplates)) or (pin.allowFiles and next(pin.allowFiles))
        if firstLink or pin.type == 'flow' then
          im.TextUnformatted(tostring(item.pinInLocal[pin.name]._value))
        else
          if pin.pinMode == 'hardcoded' then
            -- hardcoded pins use 'value' instead of '_value' to save performance
            local displayVal = item.pinIn[pin.name] and item.pinIn[pin.name].value
            local allowedTypes = ui_flowgraph_editor.getSimpleTypes()
            if displayVal ~= nil then
              if not item._cdata then item._cdata = {} end
              local hcPin = item.pinIn[pin.name]
              --dumpz(hcPin,2)
              self:_drawInputField('pins' .. pin.id ..'_val', item._cdata, hcPin.hardCodeType, displayVal, '', function(_savePath, newVal)
                --item:_setHardcodedDummyInputPin(pin, newVal)
                hcPin.value = newVal
                -- History
                self.fgEditor.addHistory("Changed hardcoded pin " .. pin.name .. " value")
              end, nil,hasHardTemplates and 50, pin)

              if hasHardTemplates then
                im.SameLine()
                self:drawHardTemplates(pin, item)
              end

              if pin.type == 'any' or type(pin.type) == 'table' then
                local allowedTypes = ui_flowgraph_editor.getSimpleTypes()
                if type(pin.type) == 'table' then allowedTypes = pin.type end
                im.PushItemWidth(100)
                if im.BeginCombo("##pinType" .. pin.id, hcPin.hardCodeType) then
                  for _, typename in pairs(allowedTypes) do
                    self.mgr:DrawTypeIcon(typename, true, 1)
                    im.SameLine()
                    if im.Selectable1(typename) then
                      item:_setHardcodedDummyInputPin(pin, fg_utils.getDefaultValueForType(typename), typename)
                      --hcPin.hardCodeType = typename
                      --hcPin.value = fg_utils.getDefaultValueForType(hcPin.typename)
                      --dumpz(item._cdata['pins' .. pin.id ..'_val'],3)
                      -- History
                      --item._cdata['pins' .. pin.id ..'_val'] = nil
                      self.fgEditor.addHistory("Changed hardcoded pin type to " .. typename)
                    end
                  end
                  im.EndCombo()
                end
                --type = pin.hardCodeType
              end
            end
          elseif pin.pinMode == 'fromDefault' then
            im.TextUnformatted("Default")
          else
            if hasHardTemplates then
              self:drawHardTemplates(pin, item)
            end
          end
        end
        if not pin.fixed then
          if im.SmallButton("Delete##deletePin" .. pin.id) then
            item:removePin(pin)
            -- History
            self.fgEditor.addHistory("Deleted pin " .. pin.name)
          end
          if im.IsItemHovered() then
            im.BeginTooltip()
            im.TextUnformatted('Remove this pin')
            im.EndTooltip()
          end
          im.SameLine()
        end
        if im.SmallButton("Up##"..pin.id) then
          item:shiftPin(pid, -1)
          self.fgEditor.addHistory("Shifted pin up : " .. pin.name)
        end
        im.SameLine()
        if im.SmallButton("Down##"..pin.id) then
          item:shiftPin(pid, 1)
          self.fgEditor.addHistory("Shifted pin down : " .. pin.name)
        end
        im.Separator()
        im.NextColumn()
      end
    end
    im.Columns(1)
    if im.Button("Add Pin") then
      item:createPin('in', self:getFirstAllowedType(item.allowedManualPinTypes), "newPin", nil, "", 0)
      -- History
      self.fgEditor.addHistory("Added new pin to ".. item.name)
    end
    if item._pinTemplates then
      im.SameLine()
      if im.BeginCombo("##pinTemplateAdder", "From Template...") then
        for _,p in ipairs(item._pinTemplates._in or {}) do
          if not item.pinInLocal[p.name] then
            self.mgr:DrawTypeIcon(p.getTypeWithImpulseAndChain and p:getTypeWithImpulseAndChain() or p.type, true, 1)
            im.SameLine()
            if im.Selectable1(p.name, false) then
              item:createPin('in', p.type, p.name, nil, "", 0)
              self.fgEditor.addHistory("Added new pin to ".. item.name)
            end
          end
        end
        im.EndCombo()
      end
    end
    --im.Columns(1)
    im.TreePop()
  end
end

function C:drawCustomOutPins(item)
  if im.TreeNodeEx1('Output Pins##propertiesPinOut_' .. "self_id", im.TreeNodeFlags_DefaultOpen) then
    --im.Columns(2, 'pinListOut' .. "self_id")
    im.Columns(2)
    im.SetColumnWidth(0, 70 * im.uiscale[0])

    for pid, pin in ipairs(item.pinList) do
      if pin.direction == 'out' then
        im.Text("Name")
        im.NextColumn()
        im.PushItemWidth(im.GetContentRegionAvail().x)
        if pin.fixed then
          im.Text(pin.name) im.tooltip("Fixed pins name can't be changed.")
        else
          local textinput = im.ArrayChar(256, tostring(pin.name or ''))
          if im.InputText('##Name' .. pin.id, textinput, 256, im.InputTextFlags_EnterReturnsTrue) then
            local oldName = pin.name
            if ffi.string(textinput) ~= '' and ffi.string(textinput):gsub("[%s]",""):len()~=0 then
              pin.name = ffi.string(textinput)
              item.pinOut[oldName] = nil
              item.pinOut[pin.name] = pin
              -- History
              self.fgEditor.addHistory("Renamed pin " .. oldName.. " to " .. pin.name)
            else
              textinput = im.ArrayChar(256, tostring(pin.name or ''))
            end
          end
        end
        im.NextColumn()

        local firstLink = pin:getFirstConnectedLink()

        if pin.hidden then
          editor.uiIconImage(editor.icons.visibility_off, im.ImVec2(24, 24), im.ImVec4(0.3, 0.3, 0.3, 1))
          if im.IsItemClicked() and self.mgr.allowEditing then
            pin.hidden = false
          end
        else
          editor.uiIconImage(editor.icons.visibility, im.ImVec2(24, 24), ui_flowgraph_editor.getTypeColor(pin.type))
          if im.IsItemClicked() and self.mgr.allowEditing and not firstLink then
            pin.hidden = true
          end
        end
        im.SameLine()
        self.mgr:DrawTypeIcon(pin:getTypeWithImpulseAndChain(), pin:getFirstConnectedLink() ~= nil, 1)
        im.NextColumn()
        if not pin.fixed then
          if type(pin.type) ~= 'table' then
            if im.BeginCombo("##pinType" .. pin.id, pin.type) then
              for typename, type in pairs(ui_flowgraph_editor.getTypes()) do
                if item.allowedManualPinTypes == nil or item.allowedManualPinTypes[typename] then
                  self.mgr:DrawTypeIcon(typename, true, 1)
                  im.SameLine()
                  if im.Selectable1(typename, typename==pin.type) then
                    pin.type = typename
                    -- History

                    -- Check if the link should be deleted now
                    for k, link in pairs(item.graph.links) do
                      if link.sourcePin == pin then
                        -- Found the right link. Now check if the pin types are still compatible
                        if not item.graph:pinsCompatible(link.sourcePin, link.targetPin) then
                          item.graph:deleteLink(link)
                        end
                      end
                    end
                    self.fgEditor.addHistory("Changed pin " .. pin.name .. " type to " .. pin.type)
                  end
                end
              end
              im.EndCombo()
            end
          else
            im.Text("Multi-Type. TBD")
          end
        end



        im.NextColumn()
        im.Text("Value")
        im.NextColumn()
        im.TextUnformatted(tostring(pin._value))

        if not pin.fixed then
          if im.SmallButton("Delete##deletePin" .. pin.id) then
            item:removePin(pin)
            -- History
            self.fgEditor.addHistory("Deleted pin " .. pin.name)
          end
          im.tooltip("Delete this pin.")
          im.SameLine()
        end
        if im.SmallButton("Up##"..pin.id) then
          item:shiftPin(pid, -1)
          self.fgEditor.addHistory("Shifted pin up : " .. pin.name)
        end
        im.SameLine()
        if im.SmallButton("Down##"..pin.id) then
          item:shiftPin(pid, 1)
          self.fgEditor.addHistory("Shifted pin down : " .. pin.name)
        end

        im.NextColumn()
        im.Separator()
      end
    end
    im.Columns(1)
    if im.Button("Add Pin") then
      item:createPin('out', self:getFirstAllowedType(item.allowedManualPinTypes), "newPin", nil, "", true)
      -- History
      self.fgEditor.addHistory("Added new pin to ".. item.name)
    end
     if item._pinTemplates then
      im.SameLine()
      if im.BeginCombo("##pinTemplateAdder", "From Template...") then
        for _,p in ipairs(item._pinTemplates._out or {}) do
          if not item.pinOut[p.name] then
            self.mgr:DrawTypeIcon(p.type, true, 1)
            im.SameLine()
            if im.Selectable1(p.name, false) then
              item:createPin('out', p.type, p.name, nil, "", true)
              self.fgEditor.addHistory("Added new pin to ".. item.name)
            end
          end
        end
        im.EndCombo()
      end
    end
    --im.Columns(1)
    im.TreePop()
  end
end

local relativeFiles = {}
function C:drawHardTemplates(pin, item)
  --im.SameLine()
  im.PushItemWidth(50)
  local selected = nil
  if im.BeginCombo("##hardTemplates" .. pin.id, "...") then
    if pin.allowFiles then
      if im.Selectable1("Select File...") then
        extensions.editor_fileDialog.openFile(function(data)
          local sel = data.filepath
          if pin.node.mgr.savedDir then
            if data.filepath:find(pin.node.mgr.savedDir) then
              sel = data.filepath:sub(pin.node.mgr.savedDir:len()+1,-1)
            end
          end
          item:_setHardcodedDummyInputPin(pin, sel or fg_utils.getDefaultValueForType(pin.type))
          item._cdata = nil
          self.fgEditor.addHistory("Hardcoded pin " .. pin.name .. " using Template")
        end, pin.allowFiles, false, pin.node.mgr.savedDir or "/")
      end
      if pin.node.mgr.savedDir then
        if im.BeginMenu("Related Files...") then
          if relativeFiles == nil then
            relativeFiles = FS:findFiles(pin.node.mgr.savedDir, '*', -1, true, false)
          end
          for _, file in ipairs(relativeFiles) do
            local dir, filename, ext = path.split(file, true)
            local validExt = false
            for _, ft in ipairs(pin.allowFiles) do if file:find(ft[2]) or ft[2] == "*" then validExt = true break end end
            if validExt then
              local shortPath = file:sub(pin.node.mgr.savedDir:len()+1,-1)
              if im.Selectable1(shortPath) then
                selected = shortPath
              end
            end
          end
          im.EndMenu()
        else
          relativeFiles = nil
        end
      end
      im.Separator()
    end
    for i, ht in ipairs(pin.hardTemplates or {}) do
      if im.Selectable1(ht.label or dumps(ht.value)) then
        selected = ht.value
      end
    end
    im.EndCombo()
  end
  if selected then
    item:_setHardcodedDummyInputPin(pin, selected or fg_utils.getDefaultValueForType(pin.type))
    item._cdata = nil
    self.fgEditor.addHistory("Hardcoded pin " .. pin.name .. " using Template")
  end
end

function C:drawInPins(item)
  if (not tableIsEmpty(item.pinInLocal)) and item.pinList and im.TreeNodeEx1('Input Pins##propertiesPinIn_' .. "self_id", im.TreeNodeFlags_DefaultOpen) then
    im.Columns(2, 'pinListIn' .. "self_id")
    -- calculate column width first
    local colWidth = 10
    for pid, pin in pairs(item.pinList) do
      if pin.direction == 'in' then
        colWidth = math.max(colWidth, im.CalcTextSize(pin.name).x )
      end
    end
    colWidth = colWidth + 48*im.uiscale[0] + 24
    im.SetColumnWidth(0, colWidth)

    for pid, pin in pairs(item.pinList) do
      if pin.direction == 'in' then
          -- dataType, connected, alpha, typeIconSize, constFilled)
        local firstLink = pin:getFirstConnectedLink()

        local constValue = item:getPinInConstValue(pin.name)

        if pin.hidden then
          editor.uiIconImage(editor.icons.visibility_off, im.ImVec2(24, 24), im.ImVec4(0.3, 0.3, 0.3, 1))
          if im.IsItemClicked() and self.mgr.allowEditing then
            pin.hidden = false
          end
          ui_flowgraph_editor.tooltip("Show this pin")
        else
          editor.uiIconImage(editor.icons.visibility, im.ImVec2(24, 24), ui_flowgraph_editor.getTypeColor(pin.type))
          if im.IsItemClicked() and self.mgr.allowEditing and not firstLink then
            pin.hidden = true
          end
          if firstLink then
            ui_flowgraph_editor.tooltip("Remove all links to hide this pin.")
          else
            ui_flowgraph_editor.tooltip("Hide this pin")
          end
        end
        im.SameLine()

        if pin.pinMode == 'hardcoded' then
          editor.uiIconImage(editor.icons.lock_outline, im.ImVec2(24, 24), ui_flowgraph_editor.getTypeColor(pin.type))
          if im.IsItemClicked() and self.mgr.allowEditing then
              item:_setHardcodedDummyInputPin(pin, nil)
              --item._cdata = nil
              -- History
              self.fgEditor.addHistory("Un-Hardcoded pin " ..pin.name)
          end
        elseif pin.pinMode == 'normal' then
          self.mgr:DrawTypeIcon(pin:getTypeWithImpulseAndChain(), firstLink ~= nil, 1, nil, (constValue ~= nil) and im.ImVec4(0,0,1,1) or nil)
          if im.IsItemClicked() and self.mgr.allowEditing and not firstLink and pin.type ~= 'table' then
            item:_setHardcodedDummyInputPin(pin, pin.defaultValue or fg_utils.getDefaultValueForType(pin.type), pin.defaultHardCodeType)
            if item._cdata then
              item._cdata['pins' .. pin.id ..'_val'] = nil
            end
            --item._cdata = nil
            -- History
            self.fgEditor.addHistory("Hardcoded pin " .. pin.name)
          end
        end

        -- name
        im.SameLine()
        im.TextUnformatted(pin.name)
        ui_flowgraph_editor.tooltip(pin.description or "")
        im.NextColumn()


        local hasHardTemplates = (pin.hardTemplates and next(pin.hardTemplates)) or (pin.allowFiles and next(pin.allowFiles))
        if firstLink or pin.type == 'flow' then
          im.TextUnformatted(tostring(item.pinInLocal[pin.name]._value))
        else
          if pin.pinMode == 'hardcoded' then
            -- hardcoded pins use 'value' instead of '_value' to save performance
            local displayVal = item.pinIn[pin.name] and item.pinIn[pin.name].value
            local allowedTypes = ui_flowgraph_editor.getSimpleTypes()
            if displayVal ~= nil then
              if not item._cdata then item._cdata = {} end
              local hcPin = item.pinIn[pin.name]
              --dumpz(hcPin,2)
              self:_drawInputField('pins' .. pin.id ..'_val', item._cdata, hcPin.hardCodeType, displayVal, '', function(_savePath, newVal)
                --item:_setHardcodedDummyInputPin(pin, newVal)
                hcPin.value = newVal
                -- History
                self.fgEditor.addHistory("Changed hardcoded pin " .. pin.name .. " value")
              end, nil,hasHardTemplates and 50, pin)

              if hasHardTemplates then
                im.SameLine()
                self:drawHardTemplates(pin, item)
              end

              if pin.type == 'any' or type(pin.type) == 'table' then
                local allowedTypes = ui_flowgraph_editor.getSimpleTypes()
                if type(pin.type) == 'table' then allowedTypes = pin.type end
                im.PushItemWidth(100)
                if im.BeginCombo("##pinType" .. pin.id, hcPin.hardCodeType) then
                  for _, typename in pairs(allowedTypes) do
                    self.mgr:DrawTypeIcon(typename, true, 1)
                    im.SameLine()
                    if im.Selectable1(typename) then
                      item:_setHardcodedDummyInputPin(pin, fg_utils.getDefaultValueForType(typename), typename)
                      --hcPin.hardCodeType = typename
                      --hcPin.value = fg_utils.getDefaultValueForType(hcPin.typename)
                      --dumpz(item._cdata['pins' .. pin.id ..'_val'],3)
                      -- History
                      --item._cdata['pins' .. pin.id ..'_val'] = nil
                      self.fgEditor.addHistory("Changed hardcoded pin type to " .. typename)
                    end
                  end
                  im.EndCombo()
                end
                --type = pin.hardCodeType
              end
            end
          elseif pin.pinMode == 'fromDefault' then
            im.TextUnformatted("Default")
          else
            if hasHardTemplates then
              self:drawHardTemplates(pin, item)
            end
          end
        end
      im.NextColumn()
      end
    end
    im.Columns(1)
    im.TreePop()
  end
end

function C:drawOutPins(item)
  if (not tableIsEmpty(item.pinOut)) and item.pinList and im.TreeNodeEx1('Output Pins##propertiesPinOut_' .. "self_id", im.TreeNodeFlags_DefaultOpen) then
    im.Columns(2, 'pinListOut' .. "self_id")
    local colWidth = 10
    for pid, pin in pairs(item.pinList) do
      if pin.direction == 'out' then
        colWidth = math.max(colWidth, im.CalcTextSize(pin.name).x )
      end
    end
    colWidth = colWidth + 48*im.uiscale[0] + 24

    im.SetColumnWidth(0, colWidth)
    for pid, pin in pairs(item.pinList) do
      if pin.direction == 'out' then
        local firstLink = pin:getFirstConnectedLink()

        if pin.hidden then
          editor.uiIconImage(editor.icons.visibility_off, im.ImVec2(24, 24), im.ImVec4(0.3, 0.3, 0.3, 1))
          if im.IsItemClicked() and self.mgr.allowEditing then
            pin.hidden = false
          end
        else
          editor.uiIconImage(editor.icons.visibility, im.ImVec2(24, 24), ui_flowgraph_editor.getTypeColor(pin.type))
          if im.IsItemClicked() and self.mgr.allowEditing and not firstLink then
            pin.hidden = true
          end
        end
        im.SameLine()
        self.mgr:DrawTypeIcon(pin:getTypeWithImpulseAndChain(), pin:getFirstConnectedLink() ~= nil, 1)
        im.SameLine()
        im.TextUnformatted(pin.name)
        ui_flowgraph_editor.tooltip(pin.description or "")
        im.NextColumn()
        im.TextUnformatted(tostring(pin._value))
        im.NextColumn()
      end
    end
    im.Columns(1)
    im.TreePop()
  end
end

function C:drawItemProperties(itemType, item)
  if not item then return end

  if next(item.data) then
    if im.TreeNodeEx1('Data##propertiesData_' .. "self_id", im.TreeNodeFlags_DefaultOpen) then
      if not item._cdata then item._cdata = {} end
      local cb = nil
      if item._onPropertyChanged then
        cb = function(kc, vc)
          item:_onPropertyChanged(kc, vc)
          -- History
          self.fgEditor.addHistory("Changed generic property of node ("..dumps(kc)..")")
        end
      else
        cb = function(kc, vc)
          -- History
          self.fgEditor.addHistory("Changed generic property of node ("..dumps(kc)..")")
        end
      end
      self:_drawDataTable(tostring("self_id"), item._cdata, item.data, '', cb)
      im.TreePop()
    end
    im.Separator()
  else
    --im.TextUnformatted('No Data')
    --im.Separator()
  end

  -- left side pins
  if item.allowCustomInPins and self.mgr.allowEditing then
    self:drawCustomInPins(item)
  else
    self:drawInPins(item)
  end

  -- right side pins
  if item.allowCustomOutPins and self.mgr.allowEditing then
    self:drawCustomOutPins(item)
  else
    self:drawOutPins(item)
  end
end


function C:draw(dt)

  if not editor.isWindowVisible(self.windowName) then
    self:unselect()
    return
  end

  if self:Begin('Properties') then
    if not self.mgr.allowEditing then im.BeginDisabled() end
  -- if im.Begin('Properties', self.windowOpen) then
    for n,_ in pairs(self.mgr.selectedNodes) do
      local node = self.mgr.graph.nodes[n]
      if node then
        for _,p in ipairs(node.pinList) do
          p:highlightLinks()
        end
      end
    end

    local selectedNodeCount = self.mgr.selectedNodeCount
    if selectedNodeCount == 1 then
      local node = self.mgr.graph.nodes[next(self.mgr.selectedNodes)]
      if previousNode and previousNode ~= node then
        previousNode:hideProperties()
        previousNode = nil
        self._editCustomProperties = nil
        self._editMultilineText = nil
      end

      if node then
        if not previousNode then
          node:showProperties()
          previousNode = node
        end

        self:drawItemHeader(node)
        if type(node.drawCustomProperties) == 'function' then
          --if im.TreeNodeEx1("Properties##"..node.id,im.TreeNodeFlags_DefaultOpen) then
            im.PushID1('Node_'..node.id .. "_" .. node.mgr.id)
            local reason = node:drawCustomProperties(dt)
            im.PopID()
            if reason then
              if type(reason) == 'string' then
                self.fgEditor.addHistory("Custom Property Change of node " .. node.name..": " .. reason)
              else
                self.fgEditor.addHistory(reason.name, reason.graph)
              end
            end
            im.Separator()
          --  im.TreePop()
          --end
        end
        if self._editMultilineText then
          if not self._openedPopup then
            im.OpenPopup("fgmultiline")
            self._openedPopup = true
          end
          if im.BeginPopup("fgmultiline") then
            if im.Button("Save") then
              self._editMultilineText.saveCallback(self._editMultilineText.savePath, ffi.string(self._editMultilineText.buf))
              im.CloseCurrentPopup()
              self._editMultilineText = nil
            else
              editor.uiInputTextMultiline("##ml",self._editMultilineText.buf,8192, im.ImVec2(250*im.uiscale[0],400*im.uiscale[0]))
            end
            im.EndPopup()
          else
            self._openedPopup = nil
            self._editMultilineText = nil
          end

        end
        self:drawItemProperties('node', node)

      end
    elseif selectedNodeCount > 1 then
      self._editCustomProperties = nil
      self._editMultilineText = nil
      im.TextUnformatted(selectedNodeCount .. " nodes selected")
      self:unselect()
    elseif selectedNodeCount == 0 then
      self:unselect()
        --display graph properties
      self:drawGraphProperties(self.mgr.graph)
    end
    --[[
    if self.updateIntegratedNode then
      if self.mgr.graph then
        self.mgr:queueGraphForUpdate(self.mgr.graph)
        self.mgr.graph:setDirty(true)

        if self.mgr.graph.type == "graph" and self.mgr.graph.parent ~= nil then
          local integratedNode = self.mgr:findIntegratedNode(self.mgr.graph)
          self.mgr:refreshIntegratedPins(integratedNode)
        end
      end
    end
    self.updateIntegratedNode = false
    ]]
    if not self.mgr.allowEditing then im.EndDisabled() end
  end
  self:End()
end

function C:unselect()
  if previousNode then
    previousNode:hideProperties()
    previousNode = nil
  end
  self._editCustomProperties = nil
  self._editMultilineText = nil
end

function C:showAvailableMacroTags()
  for i,k in pairs(self.mgr.macroTags) do
    local textinput = im.ArrayChar(256, tostring(k or ''))
    im.PushItemWidth(100)
    if im.InputText('##Name' .. k, textinput, 256, im.InputTextFlags_EnterReturnsTrue) then
      local oldName = k
      self.mgr.macroTags[i] = ffi.string(textinput)
      self.fgEditor.addHistory("Changed macro tag from " .. oldName .. " to " .. ffi.string(textinput))
    end
    im.SameLine()
    im.PopItemWidth()
    if im.SmallButton('X') then
      table.remove(self.mgr.macroTags,i)
      self.fgEditor.addHistory("Removed macro tag " .. k)
    end
    if im.IsItemHovered() then
      im.BeginTooltip()
      im.TextUnformatted('Remove this Tag')
      im.EndTooltip()
    end
  end
end

function C:drawGraphProperties(graph)
  if not graph then return end
  im.Columns(2)
  im.SetColumnWidth(0,90 * im.uiscale[0])
  im.Text("Name:")
  im.NextColumn()
  im.PushItemWidth(im.GetContentRegionAvailWidth())
  local textinput = im.ArrayChar(256, tostring(graph.name or ''))
  local editEnded = im.BoolPtr(false)
  if editor.uiInputText('##Name', textinput, 256, nil, nil, nil, editEnded) then
  end
  if editEnded[0] then
    local oldName = graph.name
    graph.name = ffi.string(textinput)
    local integratedNode = self.mgr:findIntegratedNode(graph)
    if integratedNode then
      integratedNode.name = ffi.string(textinput)
    end

    graph.restoreView = true
    self.mgr.focusGraph = graph
    self.fgEditor.addHistory("Changed graph name from " .. oldName .. " to " .. graph.name)
  end
  im.PopItemWidth()
  im.NextColumn()

  im.Text("Description: ")
  im.NextColumn()
  local textinput = im.ArrayChar(512, tostring(graph.description or ''))
  local editEnded = im.BoolPtr(false)
  if editor.uiInputTextMultiline('##Description', textinput, 512,im.ImVec2(im.GetContentRegionAvailWidth(),150), nil, nil, nil, editEnded) then
  end
  if editEnded[0] then
    graph.description = ffi.string(textinput)
    self.fgEditor.addHistory("Changed graph description ")
  end
  im.NextColumn()
  if editor.getPreference("flowgraph.debug.editorDebug") then
  --if graph.type ~= "graph" then
    im.Text("Type:")
    im.NextColumn()
    im.Text("" .. graph.type)
    if graph.isStateGraph then
      im.SameLine()
      im.Text(" (State Graph)")
    end
    im.NextColumn()
  --end

  end
  if editor.getPreference("flowgraph.debug.displayIds") then
    im.Text("ID: ")
    im.NextColumn()
    im.Text("" .. graph.id)
    im.NextColumn()
  end

  if editor.getPreference("flowgraph.debug.displayIds") then
    if graph.type == "instance" then
      im.Text("Macro ID: ")
      im.NextColumn()
      im.Text("" .. (graph.macroID and graph.macroID or 'nil'))
      im.NextColumn()
    end
  end
  if #graph:getChildren() > 0 then
    im.Text("Children: ")
    im.NextColumn()

    for i, c in ipairs(graph:getChildren()) do
      im.Text(c.name)
      if im.IsItemClicked() then
        graph.mgr:selectGraph(c)
      end
    end

    im.NextColumn()
  end
  --if graph.parentId then
    im.Text("Parent: ")
    im.NextColumn()

    if graph.parentId == nil then
      im.Text("-")
    else
      im.Text(graph:getParent().name)
    end
    im.NextColumn()
  --end
  if editor.getPreference("flowgraph.debug.editorDebug") then
    if self.mgr.allowEditing then
      im.Text("Actions:")
      im.NextColumn()
      if im.Button("Delete Graph") then
        local parent = graph.parent
        self.mgr:deleteGraph(graph)
        self.fgEditor.addHistory("Deleted graph " .. graph.name, parent == nil and true or parent)
      end
      ui_flowgraph_editor.tooltip("Deletes this graph.")
      if im.Button("Copy Graph") then
        local created = self.mgr:copyGraph(graph, "Copy of " .. graph.name)
        self.mgr:selectGraph(created)
        self.fgEditor.addHistory("Copied graph " .. graph.name)
      end
      ui_flowgraph_editor.tooltip("Creates a copy of this graph.")
      if graph.type == "graph"  and graph.parentId ~= nil then
        if im.Button("Make Macro##"..graph.id) then
          self.mgr:convertToMacro(graph)
          self.fgEditor.addHistory("Converted graph " .. graph.name .. " to macro")
        end
        ui_flowgraph_editor.tooltip("Converts this Subgraph and all its children to Macro")
      end

      self:showAvailableMacroTags()
      if graph.type == "macro" and graph.parentId == nil then
        if im.Button("Save Macro") then
          self.fgEditor.saveMacro(graph)
        end

        if im.Button("Save Macro as") then
          self.fgEditor.saveMacroAs(graph)
        end

        im.NextColumn()
        im.Text("Macro Tags:")
        im.NextColumn()
        if not self.macroTagField then
          self.macroTagField = im.ArrayChar(128)
        end
        im.PushItemWidth(100)
        im.InputText('##addTag',self.macroTagField)
        im.PopItemWidth()
        if im.Button("Add Tag Field") then
          if ffi.string(self.macroTagField) ~= '' and ffi.string(self.macroTagField):gsub("[%s]",""):len()~=0 then
            table.insert(self.mgr.macroTags,tag)
          end
          self.macroTagField = im.ArrayChar(128)
          self.fgEditor.addHistory("Added tag " .. ffi.string(self.macroTagField) .. " to macro")
        end
      end
      im.NextColumn()
    end
    if true then
      if graph.viewPos ~= nil then
        im.Text("ViewPos:")
        im.NextColumn()
        im.Text(string.format("%0.1f / 0.1f", graph.viewPos[0].x, graph.viewPos[0].y))
        im.NextColumn()
      end
      if graph.viewZoom then
        im.Text("ViewZoom:")
        im.NextColumn()
        im.Text(string.format("%0.1f", graph.viewZoom[0]))
        im.NextColumn()
      end
    end
  end
  im.Columns(1)

  im.Separator()
end

return _flowgraph_createMgrWindow(C)
