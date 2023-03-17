// ImGui Node Editor - Bindings

typedef struct EditorContext fge_EditorContext;
typedef size_t fge_NodeId;
typedef size_t fge_LinkId;
typedef size_t fge_PinId;
typedef enum  {
  StyleColor_Bg,
  StyleColor_Grid,
  StyleColor_NodeBg,
  StyleColor_NodeBorder,
  StyleColor_HovNodeBorder,
  StyleColor_SelNodeBorder,
  StyleColor_NodeSelRect,
  StyleColor_NodeSelRectBorder,
  StyleColor_HovLinkBorder,
  StyleColor_SelLinkBorder,
  StyleColor_LinkSelRect,
  StyleColor_LinkSelRectBorder,
  StyleColor_PinRect,
  StyleColor_PinRectBorder,
  StyleColor_Flow,
  StyleColor_FlowMarker,
  StyleColor_GroupBg,
  StyleColor_GroupBorder,
  StyleColor_Count
} fge_StyleColor;
typedef enum {
  StyleVar_NodePadding,
  StyleVar_NodeRounding,
  StyleVar_NodeBorderWidth,
  StyleVar_HoveredNodeBorderWidth,
  StyleVar_SelectedNodeBorderWidth,
  StyleVar_PinRounding,
  StyleVar_PinBorderWidth,
  StyleVar_LinkStrength,
  StyleVar_SourceDirection,
  StyleVar_TargetDirection,
  StyleVar_ScrollDuration,
  StyleVar_FlowMarkerDistance,
  StyleVar_FlowSpeed,
  StyleVar_FlowDuration,
  StyleVar_FlowMarkerSize,
  StyleVar_PivotAlignment,
  StyleVar_PivotSize,
  StyleVar_PivotScale,
  StyleVar_PinCorners,
  StyleVar_PinRadius,
  StyleVar_PinArrowSize,
  StyleVar_PinArrowWidth,
  StyleVar_GroupRounding,
  StyleVar_GroupBorderWidth,
} fge_StyleVar;
typedef struct {
  ImVec4  NodePadding;
  float   NodeRounding;
  float   NodeBorderWidth;
  float   HoveredNodeBorderWidth;
  float   SelectedNodeBorderWidth;
  float   PinRounding;
  float   PinBorderWidth;
  float   LinkStrength;
  ImVec2  SourceDirection;
  ImVec2  TargetDirection;
  float   ScrollDuration;
  float   FlowMarkerDistance;
  float   FlowSpeed;
  float   FlowDuration;
  ImVec2  PivotAlignment;
  ImVec2  PivotSize;
  ImVec2  PivotScale;
  float   PinCorners;
  float   PinRadius;
  float   PinArrowSize;
  float   PinArrowWidth;
  float   GroupRounding;
  float   GroupBorderWidth;
  ImVec4  Colors[18]; // StyleColor_Count
} fge_Style;
typedef enum  {
  Input,
  Output
} fge_PinKind;
typedef enum  {
  Dirty_None       = 0x00000000,
  Dirty_Navigation = 0x00000001,
  Dirty_Position   = 0x00000002,
  Dirty_Size       = 0x00000004,
  Dirty_Selection  = 0x00000008,
  Dirty_User       = 0x00000010
} fge_dirtyflags;
void fge_SetCurrentEditor(fge_EditorContext* ectx);
fge_EditorContext* fge_GetCurrentEditor();
fge_EditorContext* fge_CreateEditor(ImGuiContext* ctx);
void fge_DestroyEditor(fge_EditorContext* ectx);
fge_Style& fge_GetStyle();
const char* fge_GetStyleColorName(fge_StyleColor colorIndex);
void fge_PushStyleColor(fge_StyleColor colorIndex, const ImVec4& color);
void fge_PopStyleColor(int count);
void fge_PushStyleVar1(fge_StyleVar varIndex, float value);
void fge_PushStyleVar2(fge_StyleVar varIndex, const ImVec2& value);
void fge_PushStyleVar4(fge_StyleVar varIndex, const ImVec4& value);
void fge_PopStyleVar(int count);
void fge_Begin(const char* id, const ImVec2& size, bool readOnly);
void fge_End();
void fge_BeginNode(fge_NodeId id);
void fge_BeginPin(fge_PinId id, fge_PinKind kind);
void fge_PinRect(const ImVec2& a, const ImVec2& b);
void fge_PinPivotRect(const ImVec2& a, const ImVec2& b);
void fge_PinPivotSize(const ImVec2& size);
void fge_PinPivotScale(const ImVec2& scale);
void fge_PinPivotAlignment(const ImVec2& alignment);
void fge_EndPin();
void fge_Group(const ImVec2& size, bool forceSize);
void fge_SetGroupingDisabled(fge_NodeId nodeId, bool disabled);
void fge_EndNode();
bool fge_BeginGroupHint(fge_NodeId nodeId);
ImVec2 fge_GetGroupMin();
ImVec2 fge_GetGroupMax();
ImDrawList* fge_GetHintForegroundDrawList();
ImDrawList* fge_GetHintBackgroundDrawList();
void fge_EndGroupHint();
ImDrawList* fge_GetNodeBackgroundDrawList(fge_NodeId nodeId);
bool fge_Link(fge_LinkId id, fge_PinId startPinId, fge_PinId endPinId, const ImVec4& color, float thickness, bool isShortCut, const char* shortcutLabel);
void fge_Flow(fge_LinkId linkId);
bool fge_BeginCreate(const ImVec4& color, float thickness);
bool fge_QueryNewLink1(fge_PinId* startId, fge_PinId* endId);
bool fge_QueryNewLink2(fge_PinId* startId, fge_PinId* endId, const ImVec4& color, float thickness);
bool fge_QueryNewNode1(fge_PinId* pinId);
bool fge_QueryNewNode2(fge_PinId* pinId, const ImVec4& color, float thickness);
bool fge_AcceptNewItem1();
bool fge_AcceptNewItem2(const ImVec4& color, float thickness);
void fge_RejectNewItem1();
void fge_RejectNewItem2(const ImVec4& color, float thickness);
void fge_EndCreate();
bool fge_BeginDelete();
bool fge_QueryDeletedLink(fge_LinkId* linkId, fge_PinId* startId, fge_PinId* endId);
bool fge_QueryDeletedNode(fge_NodeId* nodeId);
bool fge_AcceptDeletedItem();
void fge_RejectDeletedItem();
void fge_EndDelete();
void fge_SetNodePosition(fge_NodeId nodeId, const ImVec2& editorPosition);
ImVec2 fge_GetNodePosition(fge_NodeId nodeId);
ImVec2 fge_GetNodeSize(fge_NodeId nodeId);
void fge_CenterNodeOnScreen(fge_NodeId nodeId);
void fge_RestoreNodeState(fge_NodeId nodeId);
void fge_Suspend();
void fge_Resume();
bool fge_IsSuspended();
bool fge_IsActive();
bool fge_HasSelectionChanged();
int  fge_GetSelectedObjectCount();
int  fge_GetSelectedNodes(fge_NodeId* nodes, int size);
int  fge_GetSelectedLinks(fge_LinkId* links, int size);
void fge_ClearSelection();
void fge_SelectNode(fge_NodeId nodeId, bool append);
void fge_SelectLink(fge_LinkId linkId, bool append);
void fge_DeselectNode(fge_NodeId nodeId);
void fge_DeselectLink(fge_LinkId linkId);
bool fge_DeleteNode(fge_NodeId nodeId);
bool fge_DeleteLink(fge_LinkId linkId);
void fge_NavigateToContent(float duration);
void fge_NavigateToSelection(bool zoomIn, float duration);
bool fge_ShowNodeContextMenu(fge_NodeId* nodeId);
bool fge_ShowPinContextMenu(fge_PinId* pinId);
bool fge_ShowLinkContextMenu(fge_LinkId* linkId);
bool fge_ShowBackgroundContextMenu();
void fge_EnableShortcuts(bool enable);
bool fge_AreShortcutsEnabled();
bool fge_BeginShortcut();
bool fge_AcceptCut();
bool fge_AcceptCopy();
bool fge_AcceptPaste();
bool fge_AcceptDuplicate();
bool fge_AcceptCreateNode();
int  fge_GetActionContextSize();
int  fge_GetActionContextNodes(fge_NodeId* nodes, int size);
int  fge_GetActionContextLinks(fge_LinkId* links, int size);
void fge_EndShortcut();
float fge_GetCurrentZoom();
fge_NodeId fge_GetDoubleClickedNode();
fge_PinId fge_GetDoubleClickedPin();
fge_LinkId fge_GetDoubleClickedLink();
bool fge_IsBackgroundClicked();
bool fge_IsBackgroundDoubleClicked();
bool fge_PinHadAnyLinks(fge_PinId pinId);
ImVec2 fge_GetScreenSize();
ImVec2 fge_ScreenToCanvas(const ImVec2& pos);
ImVec2 fge_CanvasToScreen(const ImVec2& pos);
ImVec4 fge_getVisibleBounds();

typedef enum  { Flow, Circle, Square, Grid, RoundSquare, Diamond } fge_IconType;
void fge_DrawIcon(ImDrawList* drawList, const ImVec2& a, const ImVec2& b, fge_IconType type, bool filled, ImU32 color, ImU32 innerColor);
void fge_Icon(ImGuiContext* ctx, const ImVec2& size, fge_IconType type, bool filled, const ImVec4& color, const ImVec4& innerColor);

void fge_setDebugEnabled(bool v);
bool fge_getDebugEnabled();

void fge_getViewState(ImVec2& pos, float& zoom);
void fge_setViewState(const ImVec2& pos, const float& zoom);

size_t fge_FindLinkAt(const ImVec2& pos);
size_t fge_GetHotObjectId();

fge_dirtyflags fge_GetDirtyReason();
void fge_ClearDirty();
