-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local imguiUtils = require('ui/imguiUtils')
local jbeamIO = require('jbeam/io')
local im = ui_imgui

local wndName = 'Part List'
M.menuEntry = 'JBeam Editor/Part List'

local checkboxActivePartsOnly = im.BoolPtr(true)
local parts = nil
local partsSortingDirty = false

local partsSearchText = im.ArrayChar(256)
local partsSearchTextCache
local partsViewCount = 0
local tableFlags = bit.bor(im.TableFlags_Hideable, im.TableFlags_ScrollY, im.TableFlags_Resizable, im.TableFlags_RowBg, im.TableFlags_Reorderable, im.TableFlags_Sortable, im.TableFlags_Borders)

local backgroundCol = im.GetStyleColorVec4(im.Col_Button)
local highLightBg   = im.ImVec4(0.5, 0, 0, 1)

local rightClickedPart

local function timeDiffStr(t)
  local td = os.time() - t
  if td < 60 then
    return 'last minute'
  elseif td < 3600 then
    return 'last hour'
  elseif td < 86400 then
    return 'last 24h: ' .. os.date("%x %H:%M", t)
  elseif td < 86400 * 7 then
    return 'last week: ' .. os.date("%x %H:%M", t)
  end
  return os.date("%x %H:%M", t)
end

local function openPartWindows()
  editor.showWindow('Part Tree')
  editor.showWindow('Part Text View')
end

local function selectPart(partName)
  vEditor.selectedPart = partName
  openPartWindows()
end

local function onEditorGui()
  if not vEditor.vehicle or not vEditor.vehData then return end

  if not parts then
    parts = {}
    local ioCtx = vEditor.vehData.ioCtx
    local partsList = jbeamIO.getAvailableParts(ioCtx)
    local activeParts = vEditor.vehData.vdata.activeParts
    local stat
    local statEpoch
    local statStr

    for partName, _ in pairs(partsList) do
      local part, jbeamFilename = jbeamIO.getPart(ioCtx, partName)
      if not checkboxActivePartsOnly[0] or activeParts[partName] then
        stat = FS:stat(jbeamFilename)
        statStr = ''
        statEpoch = 0
        if stat then
          statStr = timeDiffStr(stat.modtime)
          statEpoch = stat.modtime
        end
        if part.slotType == "main" then
          vEditor.selectedPart = partName
        end

        table.insert(parts, {true, partName, jbeamFilename, statEpoch, statStr, part})
      end
    end
    partsSortingDirty = true
  end

  if editor.beginWindow(wndName, wndName) then
    im.PushItemWidth(80)
    if im.InputText('##partsSearch', partsSearchText) then
      partsSortingDirty = true
    end
    im.SameLine()
    im.PushItemWidth(15)
    if im.Button('x##partsSearchReset') then
      partsSearchText[0] = 0
      partsSortingDirty = true
    end
    im.SameLine()
    if im.Checkbox('Active', checkboxActivePartsOnly) then
      -- refresh data
      parts = nil
    end

    if parts then
      local maxTreeHeight = im.GetContentRegionAvail().y - (im.GetStyle().FramePadding.y * 2 + im.GetStyle().ItemInnerSpacing.y + 2 * im.GetStyle().ItemSpacing.y) - 10

      if im.BeginChild1("##partList", im.ImVec2(0, maxTreeHeight), false) then
        im.GetContentRegionAvail()
        if im.BeginTable('##partlisttable', 3, tableFlags) then
          im.TableSetupColumn('Name', im.TableColumnFlags_NoHide, 0, 2) -- last argument is ColumnUserID
          im.TableSetupColumn('Filename', im.TableColumnFlags_DefaultHide, 0, 3)
          im.TableSetupColumn('Last modified', im.TableColumnFlags_DefaultHide, 0, 4)
          im.TableSetupScrollFreeze(0, 1) -- Make header row always visible
          im.TableHeadersRow()

          local specs = im.TableGetSortSpecs()
          if specs and (specs.SpecsDirty or partsSortingDirty) then
            -- sort the data if required :)
            for i = 0, specs.SpecsCount do
              --dump{specs.Specs[i].ColumnIndex, specs.Specs[i].SortOrder, specs.Specs[i].SortDirection}
              local colUserId = specs.Specs[i].ColumnUserID
              if colUserId > 0 then
                if specs.Specs[i].SortDirection == 1 then
                  -- ascending
                  table.sort(parts, function(a, b)
                    return a[colUserId] < b[colUserId]
                  end)
                  break
                elseif specs.Specs[i].SortDirection == 2 then
                  -- descending
                  table.sort(parts, function(a, b)
                    return a[colUserId] > b[colUserId]
                  end)
                  break
                end
              end
            end
            partsSearchTextCache = ffi.string(partsSearchText)
            partsViewCount = 0
            for _, v in pairs(parts) do
              local partName = tostring(v[2])
              local jbeamFilename = tostring(v[3])
              v[1] = partsSearchTextCache == '' or (partName:lower():find(partsSearchTextCache, 1, true) or jbeamFilename:lower():find(partsSearchTextCache, 1, true))
              if v[1] then
                partsViewCount = partsViewCount + 1
              end
            end
            specs.SpecsDirty = false
            partsSortingDirty = false
          end
          local partName
          local isSelectedPart = false
          for k, v in pairs(parts) do
            if v[1] then
              partName = tostring(v[2])
              isSelectedPart = partName == vEditor.selectedPart

              if isSelectedPart then
                im.PushStyleColor2(im.Col_TableRowBg, highLightBg)
                im.PushStyleColor2(im.Col_TableRowBgAlt, highLightBg)
              end

              im.TableNextColumn()
              im.Selectable1("##part" .. tostring(k), true, bit.bor(im.SelectableFlags_SpanAllColumns, im.SelectableFlags_AllowItemOverlap))
              if im.IsItemHovered() then
                if im.IsItemClicked(0) then
                  selectPart(partName)
                elseif im.IsItemClicked(1) then
                  im.OpenPopup('part_context_menu')
                  rightClickedPart = v
                end
              end
              im.SameLine()

              editor.uiHighlightedText(partName, partsSearchTextCache)

              im.TableNextColumn()
              --im.tooltip('Double click to select and copy part name to clipboard')
              if im.IsItemHovered() and im.IsMouseDoubleClicked(0) then
                vEditor.selectedPart = partName
                openPartWindows()
                im.SetClipboardText(partName)
              end
              editor.uiHighlightedText(tostring(v[3]), partsSearchTextCache)

              im.TableNextColumn()
              --im.tooltip('Double click to select and copy filename to clipboard')
              if im.IsItemHovered() and im.IsMouseDoubleClicked(0) then
                vEditor.selectedPart = partName
                openPartWindows()
                local _, filename, _ = path.split(tostring(v[3]))
                im.SetClipboardText(filename)
              end

              im.TextUnformatted(tostring(v[5]))
              im.TableNextRow()
              if isSelectedPart then
                im.PopStyleColor(2)
              end
            end
          end
        end
        im.EndTable()
      end
      im.EndChild()

      if im.BeginPopup('part_context_menu') then
        if im.MenuItem1("Open location in file explorer") then
          Engine.Platform.exploreFolder(tostring(rightClickedPart[3]))
        end
        im.EndPopup()
      end

      im.TextUnformatted(tostring(partsViewCount) .. ' parts found')
      if vEditor.selectedPart then
        im.SameLine()
        if im.Button('unselect') then
          vEditor.selectedPart = nil
        end
      end

    end
  end
  editor.endWindow()
end

local function open()
  editor.showWindow(wndName)
end

local function onEditorInitialized()
  editor.registerWindow(wndName, im.ImVec2(500,400))
end


local function onSerialize()
  return {
    selectedPart = vEditor.selectedPart,
  }
end

local function onDeserialized(data)
  vEditor.selectedPart = data.selectedPart
end

M.onDeserialized = onDeserialized
M.onSerialize = onSerialize

M.onEditorGui = onEditorGui
M.open = open
M.onEditorInitialized = onEditorInitialized

return M