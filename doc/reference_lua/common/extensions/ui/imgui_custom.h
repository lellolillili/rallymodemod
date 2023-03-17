// feel free to add things here
typedef unsigned __int64 size_t;

typedef void (*ImGuiSizeCallback)(ImGuiSizeCallbackData* data);

typedef struct ImTextureID_type * ImTextureID;
typedef struct ImTextureHandler {
  const void* ptr_do_not_use;
} ImTextureHandler;
void imgui_ImTextureHandler_set(ImTextureHandler *hnd, const char *path);
ImTextureID imgui_ImTextureHandler_get(ImTextureHandler *hnd);
void imgui_ImTextureHandler_size(ImTextureHandler *hnd, ImVec2 *vec2);
const char* imgui_ImTextureHandler_format(ImTextureHandler *hnd);
bool imgui_ImTextureHandler_isCached(const char* path);

ImGuiContext* imgui_GetMainContext();
void imgui_registerDrawData( int queueId);
void imgui_NewFrame2( int queueId);

typedef struct voidPtr * voidPtr;
typedef int (*ImGuiInputTextCallback)(ImGuiInputTextCallbackData *data);

bool imgui_PushFont2( unsigned int idx);
bool imgui_PushFont3(const char* uniqueId);
int imgui_IoFontsGetCount();
void imgui_TextGlyph(unsigned int unicode);
const char* imgui_IoFontsGetName( unsigned int idx);
void imgui_SetDefaultFont( unsigned int idx);

bool imgui_InputText( const char* label, char* buf, size_t buf_size, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void* user_data);
bool imgui_InputTextMultiline( const char* label, char* buf, size_t buf_size, const ImVec2& size, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void* user_data);

void imgui_PlotMultiLines( const char* label, int num_datas, const char** names, const ImColor* colors, float** datas, int values_count, const char* overlay_text, float scale_min, float scale_max, ImVec2 graph_size);
void imgui_PlotMultiHistograms( const char* label, int num_hists, const char** names, const ImColor* colors, float** datas, int values_count, const char* overlay_text, float scale_min, float scale_max, ImVec2 graph_size, bool sumValues);

struct PlotMulti2Options {
    const char* label;
    int num_datas;
    const char** names;
    const ImColor* colors;
    void *getter;
    float** datas;
    int values_count;
    const char* overlay_text;
    float scale_min[2];
    float scale_max[2];
    ImVec2 graph_size;
    bool sumValues; //only for Histograms
    const char* axis_text[3];
    int *num_format;
    int axis_format[2];
    bool grid_x;
    bool display_legend;
    bool display_legend_last_value;
    float background_alpha;
};
void imgui_PlotMulti2Lines(  struct PlotMulti2Options &options);
void imgui_PlotMulti2Histograms( struct PlotMulti2Options &options);

ImU32 imgui_GetColorU32ByVec4(const ImVec4& col);

void imgui_DockBuilderDockWindow(const char* window_name, ImGuiID node_id);
void imgui_DockBuilderAddNode(ImGuiID node_id, ImVec2 ref_size, ImGuiDockNodeFlags flags);
ImGuiID imgui_DockBuilderSplitNode( ImGuiID node_id, ImGuiDir split_dir, float size_ratio_for_node_at_dir, ImGuiID* out_id_dir, ImGuiID* out_id_other);
void imgui_DockBuilderFinish(ImGuiID node_id);

void imgui_BeginDisabled( bool disable);
void imgui_EndDisabled();

const char * imgui_TextFilter_GetInputBuf(ImGuiTextFilter* ImGuiTextFilter_ctx);
void imgui_TextFilter_SetInputBuf(ImGuiTextFilter* ImGuiTextFilter_ctx, const char * text);
int imgui_getMonitorIndex();
bool imgui_getCurrentMonitorSize(ImVec2* vec2);

void imgui_LoadIniSettingsFromDisk(const char* ini_filename);
void imgui_SaveIniSettingsToDisk(const char* ini_filename);
void imgui_ClearActiveID();

// TextEditor below
typedef struct TextEditor TextEditor;
TextEditor* imgui_createTextEditor();
void imgui_destroyTextEditor(TextEditor* te);
void imgui_TextEditor_SetLanguageDefinition(TextEditor* te, const char* str);
void imgui_TextEditor_Render(TextEditor* te, const char* title, const ImVec2& size, bool border);
void imgui_TextEditor_SetText(TextEditor* te, const char* text);
const char *imgui_TextEditor_GetText(TextEditor* te);
bool imgui_TextEditor_IsTextChanged(TextEditor* te);

void imgui_readGlobalActions();