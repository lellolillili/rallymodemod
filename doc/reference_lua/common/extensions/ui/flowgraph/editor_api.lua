-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = ffi.C -- shortcut to prevent lookups all the time
local im = ui_imgui

-- slower, but adds sanity checks
local pointerGuard = true

return function(M)
  -- enums
  M.StyleColor_Bg = C.StyleColor_Bg
  M.StyleColor_Grid = C.StyleColor_Grid
  M.StyleColor_NodeBg = C.StyleColor_NodeBg
  M.StyleColor_NodeBorder = C.StyleColor_NodeBorder
  M.StyleColor_HovNodeBorder = C.StyleColor_HovNodeBorder
  M.StyleColor_SelNodeBorder = C.StyleColor_SelNodeBorder
  M.StyleColor_NodeSelRect = C.StyleColor_NodeSelRect
  M.StyleColor_NodeSelRectBorder = C.StyleColor_NodeSelRectBorder
  M.StyleColor_HovLinkBorder = C.StyleColor_HovLinkBorder
  M.StyleColor_SelLinkBorder = C.StyleColor_SelLinkBorder
  M.StyleColor_LinkSelRect = C.StyleColor_LinkSelRect
  M.StyleColor_LinkSelRectBorder = C.StyleColor_LinkSelRectBorder
  M.StyleColor_PinRect = C.StyleColor_PinRect
  M.StyleColor_PinRectBorder = C.StyleColor_PinRectBorder
  M.StyleColor_Flow = C.StyleColor_Flow
  M.StyleColor_FlowMarker = C.StyleColor_FlowMarker
  M.StyleColor_GroupBg = C.StyleColor_GroupBg
  M.StyleColor_GroupBorder = C.StyleColor_GroupBorder
  M.StyleColor_Count = C.StyleColor_Count

  M.StyleVar_NodePadding = C.StyleVar_NodePadding
  M.StyleVar_NodeRounding = C.StyleVar_NodeRounding
  M.StyleVar_NodeBorderWidth = C.StyleVar_NodeBorderWidth
  M.StyleVar_HoveredNodeBorderWidth = C.StyleVar_HoveredNodeBorderWidth
  M.StyleVar_SelectedNodeBorderWidth = C.StyleVar_SelectedNodeBorderWidth
  M.StyleVar_PinRounding = C.StyleVar_PinRounding
  M.StyleVar_PinBorderWidth = C.StyleVar_PinBorderWidth
  M.StyleVar_LinkStrength = C.StyleVar_LinkStrength
  M.StyleVar_SourceDirection = C.StyleVar_SourceDirection
  M.StyleVar_TargetDirection = C.StyleVar_TargetDirection
  M.StyleVar_ScrollDuration = C.StyleVar_ScrollDuration
  M.StyleVar_FlowMarkerDistance = C.StyleVar_FlowMarkerDistance
  M.StyleVar_FlowSpeed = C.StyleVar_FlowSpeed
  M.StyleVar_FlowDuration = C.StyleVar_FlowDuration
  M.StyleVar_FlowMarkerSize = C.StyleVar_FlowMarkerSize
  M.StyleVar_PivotAlignment = C.StyleVar_PivotAlignment
  M.StyleVar_PivotSize = C.StyleVar_PivotSize
  M.StyleVar_PivotScale = C.StyleVar_PivotScale
  M.StyleVar_PinCorners = C.StyleVar_PinCorners
  M.StyleVar_PinRadius = C.StyleVar_PinRadius
  M.StyleVar_PinArrowSize = C.StyleVar_PinArrowSize
  M.StyleVar_PinArrowWidth = C.StyleVar_PinArrowWidth
  M.StyleVar_GroupRounding = C.StyleVar_GroupRounding
  M.StyleVar_GroupBorderWidth = C.StyleVar_GroupBorderWidth

  M.Dirty_None = C.Dirty_None
  M.Dirty_Navigation = C.Dirty_Navigation
  M.Dirty_Position = C.Dirty_Position
  M.Dirty_Size = C.Dirty_Size
  M.Dirty_Selection = C.Dirty_Selection
  M.Dirty_User = C.Dirty_User

  M.PinKind_Input = C.Input
  M.PinKind_Output = C.Output

  M.IconType_Flow = C.Flow
  M.IconType_Circle = C.Circle
  M.IconType_Square = C.Square
  M.IconType_Grid = C.Grid
  M.IconType_RoundSquare = C.RoundSquare
  M.IconType_Diamond = C.Diamond
--[[
  M.Dirty_None       = 0x00000000
  M.Dirty_Navigation = 0x00000001
  M.Dirty_Position   = 0x00000002
  M.Dirty_Size       = 0x00000004
  M.Dirty_Selection  = 0x00000008
  M.Dirty_User       = 0x00000010
  ]]

  -- functions
  M.ctx = nil
  if C.fge_GetCurrentEditor() ~= nil then
     M.ctx = C.fge_GetCurrentEditor()
  end
  local chkContext = nil
  if pointerGuard then
    chkContext = function(M, fct)
      return function(...)
        if not M.ctx then
          --print("M.ctx = " .. tostring(M.ctx))
          --print("fge_GetCurrentEditor = " .. tostring(C.fge_GetCurrentEditor()))
          log('E', '', 'Node Editor context nil: ' .. debug.tracesimple())
          return
        end
        return fct(...)
      end
    end
  else
    chkContext = function(M, fct)
      return function(...)
        return fct(...)
      end
    end
  end


  M.SetCurrentEditor = function(ctx)
    M.ctx = ctx
    C.fge_SetCurrentEditor(ctx)
  end

  M.GetCurrentEditor = C.fge_GetCurrentEditor
  M.CreateEditor = C.fge_CreateEditor
  M.DestroyEditor = C.fge_DestroyEditor

  M.GetStyle = chkContext(M, C.fge_GetStyle)
  M.GetStyleColorName = chkContext(M, C.fge_GetStyleColorName)
  M.PushStyleColor = chkContext(M, C.fge_PushStyleColor)
  M.PopStyleColor = chkContext(M, C.fge_PopStyleColor)
  M.PushStyleVar1 = chkContext(M, C.fge_PushStyleVar1)
  M.PushStyleVar2 = chkContext(M, C.fge_PushStyleVar2)
  M.PushStyleVar4 = chkContext(M, C.fge_PushStyleVar4)
  M.PopStyleVar = chkContext(M, C.fge_PopStyleVar)
  M.Begin =
  function(...)
    local result = chkContext(M, C.fge_Begin)(...)
    if im then
      local io = im.GetIO(io)
      im.SetWindowFontScale(1/io.FontGlobalScale)
      M.oldImguiScale = im.uiscale[0]
      im.uiscale[0] = 1
    end
    return result
  end
  M.End =
  function(...)
    local result = chkContext(M, C.fge_End)(...)
    if im then im.uiscale[0] = M.oldImguiScale end
    im.SetWindowFontScale(1)

    return result
  end
  M.BeginNode = chkContext(M, C.fge_BeginNode)
  M.BeginPin = chkContext(M, C.fge_BeginPin)
  M.PinRect = chkContext(M, C.fge_PinRect)
  M.PinPivotRect = chkContext(M, C.fge_PinPivotRect)
  M.PinPivotSize = chkContext(M, C.fge_PinPivotSize)
  M.PinPivotScale = chkContext(M, C.fge_PinPivotScale)
  M.PinPivotAlignment = chkContext(M, C.fge_PinPivotAlignment)
  M.EndPin = chkContext(M, C.fge_EndPin)
  M.Group = chkContext(M, C.fge_Group)
  M.SetGroupingDisabled = chkContext(M, C.fge_SetGroupingDisabled)
  M.EndNode = chkContext(M, C.fge_EndNode)
  M.BeginGroupHint = chkContext(M, C.fge_BeginGroupHint)
  M.GetGroupMin = chkContext(M, C.fge_GetGroupMin)
  M.GetGroupMax = chkContext(M, C.fge_GetGroupMax)
  M.GetHintForegroundDrawList = chkContext(M, C.fge_GetHintForegroundDrawList)
  M.GetHintBackgroundDrawList = chkContext(M, C.fge_GetHintBackgroundDrawList)
  M.EndGroupHint = chkContext(M, C.fge_EndGroupHint)
  M.GetNodeBackgroundDrawList = chkContext(M, C.fge_GetNodeBackgroundDrawList)
  M.Link = chkContext(M, C.fge_Link)
  M.Flow = chkContext(M, C.fge_Flow)
  M.BeginCreate = chkContext(M, C.fge_BeginCreate)
  M.QueryNewLink1 = chkContext(M, C.fge_QueryNewLink1)
  M.QueryNewLink2 = chkContext(M, C.fge_QueryNewLink2)
  M.QueryNewNode1 = chkContext(M, C.fge_QueryNewNode1)
  M.QueryNewNode2 = chkContext(M, C.fge_QueryNewNode2)
  M.AcceptNewItem1 = chkContext(M, C.fge_AcceptNewItem1)
  M.AcceptNewItem2 = chkContext(M, C.fge_AcceptNewItem2)
  M.RejectNewItem1 = chkContext(M, C.fge_RejectNewItem1)
  M.RejectNewItem2 = chkContext(M, C.fge_RejectNewItem2)
  M.EndCreate = chkContext(M, C.fge_EndCreate)
  M.BeginDelete = chkContext(M, C.fge_BeginDelete)
  M.QueryDeletedLink = chkContext(M, C.fge_QueryDeletedLink)
  M.QueryDeletedNode = chkContext(M, C.fge_QueryDeletedNode)
  M.AcceptDeletedItem = chkContext(M, C.fge_AcceptDeletedItem)
  M.RejectDeletedItem = chkContext(M, C.fge_RejectDeletedItem)
  M.EndDelete = chkContext(M, C.fge_EndDelete)
  M.SetNodePosition = chkContext(M, C.fge_SetNodePosition)
  M.GetNodePosition = chkContext(M, C.fge_GetNodePosition)
  M.GetNodeSize = chkContext(M, C.fge_GetNodeSize)
  M.CenterNodeOnScreen = chkContext(M, C.fge_CenterNodeOnScreen)
  M.RestoreNodeState = chkContext(M, C.fge_RestoreNodeState)
  M.Suspend = chkContext(M, C.fge_Suspend)
  M.Resume = chkContext(M, C.fge_Resume)
  M.IsSuspended = chkContext(M, C.fge_IsSuspended)
  M.IsActive = chkContext(M, C.fge_IsActive)
  M.HasSelectionChanged = chkContext(M, C.fge_HasSelectionChanged)
  M.GetSelectedObjectCount = chkContext(M, C.fge_GetSelectedObjectCount)
  M.GetSelectedNodes = chkContext(M, C.fge_GetSelectedNodes)
  M.GetSelectedLinks = chkContext(M, C.fge_GetSelectedLinks)
  M.ClearSelection = chkContext(M, C.fge_ClearSelection)
  M.SelectNode = chkContext(M, C.fge_SelectNode)
  M.SelectLink = chkContext(M, C.fge_SelectLink)
  M.DeselectNode = chkContext(M, C.fge_DeselectNode)
  M.DeselectLink = chkContext(M, C.fge_DeselectLink)
  M.DeleteNode = chkContext(M, C.fge_DeleteNode)
  M.DeleteLink = chkContext(M, C.fge_DeleteLink)
  M.NavigateToContent = chkContext(M, C.fge_NavigateToContent)
  M.NavigateToSelection = chkContext(M, C.fge_NavigateToSelection)
  M.ShowNodeContextMenu = chkContext(M, C.fge_ShowNodeContextMenu)
  M.ShowPinContextMenu = chkContext(M, C.fge_ShowPinContextMenu)
  M.ShowLinkContextMenu = chkContext(M, C.fge_ShowLinkContextMenu)
  M.ShowBackgroundContextMenu = chkContext(M, C.fge_ShowBackgroundContextMenu)
  M.EnableShortcuts = chkContext(M, C.fge_EnableShortcuts)
  M.AreShortcutsEnabled = chkContext(M, C.fge_AreShortcutsEnabled)
  M.BeginShortcut = chkContext(M, C.fge_BeginShortcut)
  M.AcceptCut = chkContext(M, C.fge_AcceptCut)
  M.AcceptCopy = chkContext(M, C.fge_AcceptCopy)
  M.AcceptPaste = chkContext(M, C.fge_AcceptPaste)
  M.AcceptDuplicate = chkContext(M, C.fge_AcceptDuplicate)
  M.AcceptCreateNode = chkContext(M, C.fge_AcceptCreateNode)
  M.GetActionContextSize = chkContext(M, C.fge_GetActionContextSize)
  M.GetActionContextNodes = chkContext(M, C.fge_GetActionContextNodes)
  M.GetActionContextLinks = chkContext(M, C.fge_GetActionContextLinks)
  M.EndShortcut = chkContext(M, C.fge_EndShortcut)
  M.GetCurrentZoom = chkContext(M, C.fge_GetCurrentZoom)
  M.GetDoubleClickedNode = chkContext(M, C.fge_GetDoubleClickedNode)
  M.GetDoubleClickedPin = chkContext(M, C.fge_GetDoubleClickedPin)
  M.GetDoubleClickedLink = chkContext(M, C.fge_GetDoubleClickedLink)
  M.IsBackgroundClicked = chkContext(M, C.fge_IsBackgroundClicked)
  M.IsBackgroundDoubleClicked = chkContext(M, C.fge_IsBackgroundDoubleClicked)
  M.PinHadAnyLinks = chkContext(M, C.fge_PinHadAnyLinks)
  M.GetScreenSize = chkContext(M, C.fge_GetScreenSize)
  M.ScreenToCanvas = chkContext(M, C.fge_ScreenToCanvas)
  M.CanvasToScreen = chkContext(M, C.fge_CanvasToScreen)
  M.GetVisibleCanvasBounds = chkContext(M, C.fge_getVisibleBounds)
  M.DrawIcon = chkContext(M, C.fge_DrawIcon)
  M.Icon = chkContext(M, C.fge_Icon)
  M.setDebugEnabled = chkContext(M, C.fge_setDebugEnabled)
  M.getDebugEnabled = chkContext(M, C.fge_getDebugEnabled)

  M.getViewState = chkContext(M, C.fge_getViewState)
  M.setViewState = chkContext(M, C.fge_setViewState)

  M.FindLinkAt = chkContext(M, C.fge_FindLinkAt)
  M.GetHotObjectId = chkContext(M, C.fge_GetHotObjectId)

  M.GetDirtyReason = chkContext(M, C.fge_GetDirtyReason)
  M.ClearDirty = chkContext(M, C.fge_ClearDirty)
end