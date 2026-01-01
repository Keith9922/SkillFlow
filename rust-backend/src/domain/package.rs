use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Package {
    pub version: String,
    pub package: PackageMeta,
    pub app: AppSpec,
    #[serde(default)]
    pub env: Option<EnvSpec>,
    #[serde(default)]
    pub vars: HashMap<String, VarDef>,
    pub selectors: HashMap<String, Selector>,
    pub steps: Vec<Step>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageMeta {
    pub name: String,
    #[serde(rename = "createdAt")]
    pub created_at: String, // ISO 8601 string
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub author: Option<String>,
    #[serde(default)]
    pub tags: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppSpec {
    pub name: String,
    #[serde(rename = "minVersion", default)]
    pub min_version: Option<String>,
    #[serde(rename = "maxVersion", default)]
    pub max_version: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EnvSpec {
    #[serde(default)]
    pub os: Vec<String>,
    #[serde(rename = "resolutionHint", default)]
    pub resolution_hint: Option<String>,
    #[serde(rename = "localeHint", default)]
    pub locale_hint: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VarDef {
    #[serde(rename = "type")]
    pub var_type: String, // "string", "number", "boolean", "path"
    #[serde(default)]
    pub default: Option<serde_json::Value>,
    #[serde(default)]
    pub description: Option<String>,
}

// --- Selectors ---

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum SelectorOrRef {
    Ref(SelectorRef),
    Inline(Box<Selector>), // Box to avoid recursive size issues if any
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SelectorRef {
    #[serde(rename = "$ref")]
    pub reference: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "strategy")]
pub enum Selector {
    #[serde(rename = "ocr")]
    OCR(OCRSelector),
    #[serde(rename = "template")]
    Template(TemplateSelector),
    #[serde(rename = "relative")]
    Relative(RelativeSelector),
    #[serde(rename = "multi")]
    Multi(MultiSelector),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OCRSelector {
    pub text: String,
    #[serde(default)]
    pub match_options: Option<OCRMatch>, // 'match' is a keyword in Rust
    #[serde(default)]
    pub scope: Option<Scope>,
}

// Custom deserialization for 'match' field mapping
impl OCRSelector {
    // Helper to handle the 'match' field rename if needed, but serde(rename) works on field
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OCRMatch {
    #[serde(default = "default_match_mode")]
    pub mode: String, // "equals", "contains", "regex"
    #[serde(default = "default_lang")]
    pub lang: String,
    #[serde(rename = "caseSensitive", default)]
    pub case_sensitive: bool,
    #[serde(default)]
    pub regex: Option<String>,
}

fn default_match_mode() -> String { "contains".to_string() }
fn default_lang() -> String { "chi_sim".to_string() }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateSelector {
    pub template: String,
    #[serde(rename = "match", default)]
    pub match_options: Option<TemplateMatch>,
    #[serde(default)]
    pub scope: Option<Scope>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemplateMatch {
    #[serde(default = "default_threshold")]
    pub threshold: f64,
}

fn default_threshold() -> f64 { 0.8 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelativeSelector {
    pub anchor: SelectorOrRef,
    pub relation: Relation,
    pub target: SelectorOrRef,
    #[serde(default)]
    pub scope: Option<Scope>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Relation {
    #[serde(rename = "type")]
    pub rel_type: String, // "below", "above", "leftOf", "rightOf", "near"
    #[serde(rename = "maxDistancePx", default = "default_max_distance")]
    pub max_distance_px: u32,
}

fn default_max_distance() -> u32 { 400 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MultiSelector {
    pub candidates: Vec<SelectorOrRef>,
    #[serde(default)]
    pub pick: Option<PickPolicy>,
    #[serde(default)]
    pub scope: Option<Scope>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PickPolicy {
    #[serde(default = "default_pick_policy")]
    pub policy: String, // "bestConfidence", "firstMatch"
}

fn default_pick_policy() -> String { "bestConfidence".to_string() }

// --- Scopes ---

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
pub enum Scope {
    #[serde(rename = "rect")]
    Rect(ScopeRect),
    #[serde(rename = "band")]
    Band(ScopeBand),
    #[serde(rename = "window")]
    Window(ScopeWindow),
    #[serde(rename = "dialog")]
    Dialog(ScopeDialog),
    #[serde(rename = "activeMenu")]
    ActiveMenu(ScopeActiveMenu),
    #[serde(rename = "elementRef")]
    ElementRef(ScopeElementRef),
    #[serde(rename = "around")]
    Around(ScopeAround),
    #[serde(rename = "nearest")]
    Nearest(ScopeNearest),
    #[serde(rename = "union")]
    Union(ScopeUnion),
    #[serde(rename = "intersect")]
    Intersect(ScopeIntersect),
    #[serde(rename = "exclude")]
    Exclude(ScopeExclude),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeRect {
    pub x: f64,
    pub y: f64,
    pub w: f64,
    pub h: f64,
    #[serde(default = "default_true")]
    pub normalized: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeBand {
    pub edge: String, // "top", "bottom", "left", "right"
    pub ratio: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeWindow {
    pub mode: String, // "active", "main", "byTitle"
    #[serde(default)]
    pub title: Option<String>,
    #[serde(rename = "match", default = "default_match_mode")]
    pub match_mode: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeDialog {
    pub role: String, // "topmost", "modal", "byTitle"
    #[serde(default)]
    pub title: Option<String>,
    #[serde(rename = "match", default = "default_match_mode")]
    pub match_mode: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeActiveMenu {}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeElementRef {
    #[serde(rename = "refStepId")]
    pub ref_step_id: String,
    #[serde(rename = "paddingPx", default)]
    pub padding_px: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeAround {
    pub anchor: SelectorOrRef,
    #[serde(rename = "radiusPx")]
    pub radius_px: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeNearest {
    pub to: String, // "anchor"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeUnion {
    pub scopes: Vec<Scope>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeIntersect {
    pub scopes: Vec<Scope>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScopeExclude {
    pub base: Box<Scope>,
    pub exclude: Box<Scope>,
}

// --- Steps ---

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Step {
    pub id: String,
    #[serde(default)]
    pub name: Option<String>,
    #[serde(default)]
    pub scope: Option<Scope>,
    #[serde(default)]
    pub retry: Option<Retry>,
    #[serde(default)]
    pub on_fail: Option<OnFail>,
    
    #[serde(flatten)]
    pub op: StepOperation,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "op")]
pub enum StepOperation {
    #[serde(rename = "click")]
    Click(StepClick),
    #[serde(rename = "drag")]
    Drag(StepDrag),
    #[serde(rename = "type")]
    Type(StepType),
    #[serde(rename = "scroll")]
    Scroll(StepScroll),
    #[serde(rename = "hotkey")]
    Hotkey(StepHotkey),
    #[serde(rename = "wait")]
    Wait(StepWait),
    #[serde(rename = "assert")]
    Assert(StepAssert),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Retry {
    #[serde(default)]
    pub times: u32,
    #[serde(rename = "intervalMs", default)]
    pub interval_ms: u32,
    #[serde(rename = "timeoutMs", default)]
    pub timeout_ms: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OnFail {
    pub action: String, // "abort", "skip", "fallback_step_id"
    #[serde(default)]
    pub reason: Option<String>,
    #[serde(rename = "stepId", default)]
    pub step_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Fallback {
    pub point: FallbackPoint,
    pub policy: String, // "last_retry_only", "always"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FallbackPoint {
    pub x: f64,
    pub y: f64,
    #[serde(default = "default_true")]
    pub normalized: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepClick {
    pub target: SelectorOrRef,
    #[serde(default)]
    pub params: Option<ClickParams>,
    #[serde(default)]
    pub fallback: Option<Fallback>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClickParams {
    #[serde(default = "default_click_button")]
    pub button: String,
    #[serde(rename = "clickCount", default = "default_click_count")]
    pub click_count: u32,
    #[serde(default)]
    pub offset: Option<Offset>,
}

fn default_click_button() -> String { "left".to_string() }
fn default_click_count() -> u32 { 1 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Offset {
    pub dx: i32,
    pub dy: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepDrag {
    pub from: SelectorOrRef,
    #[serde(default)]
    pub to: Option<SelectorOrRef>,
    #[serde(default)]
    pub vector: Option<DragVector>,
    #[serde(default)]
    pub params: Option<DragParams>,
    #[serde(default)]
    pub fallback: Option<Fallback>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DragVector {
    pub direction: String, // "up", "down", "left", "right"
    #[serde(rename = "distancePx")]
    pub distance_px: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DragParams {
    #[serde(rename = "durationMs", default = "default_drag_duration")]
    pub duration_ms: u32,
}

fn default_drag_duration() -> u32 { 250 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepType {
    pub text: String,
    #[serde(default)]
    pub target: Option<SelectorOrRef>,
    #[serde(default)]
    pub params: Option<TypeParams>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeParams {
    #[serde(rename = "clearFirst", default)]
    pub clear_first: bool,
    #[serde(rename = "delayPerCharMs", default)]
    pub delay_per_char_ms: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepScroll {
    pub delta: ScrollDelta,
    #[serde(default)]
    pub target: Option<SelectorOrRef>,
    #[serde(default)]
    pub params: Option<ScrollParams>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScrollDelta {
    pub direction: String,
    pub amount: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScrollParams {
    #[serde(default = "default_scroll_steps")]
    pub steps: u32,
}

fn default_scroll_steps() -> u32 { 1 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepHotkey {
    pub keys: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepWait {
    pub until: SelectorOrRef,
    #[serde(default)]
    pub params: Option<WaitParams>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WaitParams {
    #[serde(default = "default_wait_mode")]
    pub mode: String, // "appear", "disappear"
    #[serde(rename = "minConfidence", default = "default_wait_confidence")]
    pub min_confidence: f64,
}

fn default_wait_mode() -> String { "appear".to_string() }
fn default_wait_confidence() -> f64 { 0.6 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StepAssert {
    pub expect: SelectorOrRef,
    #[serde(default)]
    pub params: Option<AssertParams>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AssertParams {
    #[serde(rename = "minConfidence", default = "default_assert_confidence")]
    pub min_confidence: f64,
    #[serde(default)]
    pub negate: bool,
}

fn default_assert_confidence() -> f64 { 0.65 }

fn default_true() -> bool { true }

#[cfg(test)]
mod tests {
    use crate::domain::package::{Package, StepOperation, SelectorOrRef};

    #[test]
    fn test_case_1_minimal_click() {
        let json = r##"{
            "version": "0.1",
            "package": { "name": "Minimal Click", "createdAt": "2026-01-01T00:00:00+09:00" },
            "app": { "name": "Photoshop", "minVersion": "2023" },
            "selectors": {
                "menu_file": {
                "strategy": "ocr",
                "text": "文件",
                "match": { "mode": "equals", "lang": "chi_sim", "caseSensitive": false },
                "scope": { "type": "band", "edge": "top", "ratio": 0.18 }
                }
            },
            "steps": [
                {
                "id": "s1",
                "op": "click",
                "target": { "$ref": "#/selectors/menu_file" },
                "retry": { "times": 2, "intervalMs": 400, "timeoutMs": 3000 },
                "on_fail": { "action": "abort", "reason": "menu_file not found" }
                }
            ]
        }"##;

        let pkg: Package = serde_json::from_str(json).expect("Failed to parse Case 1");
        assert_eq!(pkg.package.name, "Minimal Click");
        assert!(pkg.selectors.contains_key("menu_file"));
        if let StepOperation::Click(click) = &pkg.steps[0].op {
             if let SelectorOrRef::Ref(r) = &click.target {
                 assert_eq!(r.reference, "#/selectors/menu_file");
             } else {
                 panic!("Expected ref");
             }
        } else {
            panic!("Expected click step");
        }
    }

    #[test]
    fn test_case_2_basic() {
        let json = r##"{
        "version": "0.1",
        "package": { "name": "Click and Verify", "createdAt": "2026-01-01T00:00:00+09:00" },
        "app": { "name": "Photoshop", "minVersion": "2023" },

        "selectors": {
            "menu_file": {
            "strategy": "ocr",
            "text": "文件",
            "match": { "mode": "contains", "lang": "chi_sim" },
            "scope": { "type": "band", "edge": "top", "ratio": 0.18 }
            },
            "menu_export": {
            "strategy": "ocr",
            "text": "导出",
            "match": { "mode": "contains", "lang": "chi_sim" },
            "scope": { "type": "activeMenu" }
            }
        },

        "steps": [
            {
            "id": "s1",
            "op": "click",
            "target": { "$ref": "#/selectors/menu_file" },
            "retry": { "times": 3, "intervalMs": 500, "timeoutMs": 6000 },
            "on_fail": { "action": "abort", "reason": "Open File menu failed" }
            },
            {
            "id": "s2",
            "op": "wait",
            "until": { "$ref": "#/selectors/menu_export" },
            "params": { "mode": "appear" },
            "retry": { "times": 6, "intervalMs": 250, "timeoutMs": 2500 },
            "on_fail": { "action": "abort", "reason": "Export item did not appear" }
            },
            {
            "id": "s3",
            "op": "assert",
            "expect": { "$ref": "#/selectors/menu_export" },
            "params": { "minConfidence": 0.65 }
            }
        ]
        }"##;
        let pkg: Package = serde_json::from_str(json).expect("Failed to parse Case 2");
        assert_eq!(pkg.steps.len(), 3);
    }

    #[test]
    fn test_case_3_medium() {
        let json = r##"{
        "version": "0.1",
        "package": { "name": "Relative Drag", "createdAt": "2026-01-01T00:00:00+09:00" },
        "app": { "name": "Photoshop", "minVersion": "2023" },

        "selectors": {
            "layers_panel_title": {
            "strategy": "ocr",
            "text": "图层",
            "match": { "mode": "equals", "lang": "chi_sim" },
            "scope": { "type": "band", "edge": "right", "ratio": 0.45 }
            },
            "layer_1": {
            "strategy": "relative",
            "anchor": { "$ref": "#/selectors/layers_panel_title" },
            "relation": { "type": "below", "maxDistancePx": 600 },
            "target": {
                "strategy": "ocr",
                "text": "图层 1",
                "match": { "mode": "contains", "lang": "chi_sim" },
                "scope": { "type": "nearest", "to": "anchor" }
            }
            }
        },

        "steps": [
            {
            "id": "s1",
            "op": "drag",
            "from": { "$ref": "#/selectors/layers_panel_title" },
            "vector": { "direction": "down", "distancePx": 380 },
            "params": { "durationMs": 300 },
            "retry": { "times": 2, "intervalMs": 500, "timeoutMs": 5000 },
            "fallback": {
                "point": { "x": 0.86, "y": 0.45, "normalized": true },
                "policy": "last_retry_only"
            },
            "on_fail": { "action": "skip", "reason": "Could not scroll layers panel" }
            },
            {
            "id": "s2",
            "op": "click",
            "target": { "$ref": "#/selectors/layer_1" },
            "retry": { "times": 2, "intervalMs": 400, "timeoutMs": 4000 },
            "on_fail": { "action": "abort", "reason": "layer_1 not found" }
            }
        ]
        }"##;
        let pkg: Package = serde_json::from_str(json).expect("Failed to parse Case 3");
        assert_eq!(pkg.steps.len(), 2);
    }

    #[test]
    fn test_case_4_complex() {
        let json = r##"{
        "version": "0.1",
        "package": {
            "name": "Export Workflow Advanced",
            "createdAt": "2026-01-01T00:00:00+09:00",
            "description": "Export with verification and fallbacks"
        },
        "app": { "name": "Photoshop", "minVersion": "2023" },

        "vars": {
            "EXPORT_DIR": { "type": "path", "default": "" },
            "FILE_NAME": { "type": "string", "default": "output" }
        },

        "selectors": {
            "menu_file": {
            "strategy": "ocr",
            "text": "文件",
            "match": { "mode": "contains", "lang": "chi_sim" },
            "scope": { "type": "band", "edge": "top", "ratio": 0.18 }
            },

            "menu_export": {
            "strategy": "multi",
            "candidates": [
                {
                "strategy": "ocr",
                "text": "导出",
                "match": { "mode": "contains", "lang": "chi_sim" },
                "scope": { "type": "activeMenu" }
                },
                {
                "strategy": "template",
                "template": "assets/templates/export_icon.png",
                "match": { "threshold": 0.82 },
                "scope": { "type": "activeMenu" }
                }
            ],
            "pick": { "policy": "bestConfidence" }
            },

            "dialog_export_title": {
            "strategy": "ocr",
            "text": "导出",
            "match": { "mode": "contains", "lang": "chi_sim" },
            "scope": { "type": "dialog", "role": "topmost" }
            },

            "input_filename": {
            "strategy": "relative",
            "anchor": {
                "strategy": "ocr",
                "text": "文件名",
                "match": { "mode": "contains", "lang": "chi_sim" },
                "scope": { "type": "dialog", "role": "topmost" }
            },
            "relation": { "type": "rightOf", "maxDistancePx": 420 },
            "target": {
                "strategy": "template",
                "template": "assets/templates/text_input.png",
                "match": { "threshold": 0.78 }
            }
            },

            "btn_confirm": {
            "strategy": "multi",
            "candidates": [
                {
                "strategy": "ocr",
                "text": "导出",
                "match": { "mode": "equals", "lang": "chi_sim" },
                "scope": { "type": "dialog", "role": "topmost" }
                },
                {
                "strategy": "ocr",
                "text": "Export",
                "match": { "mode": "equals", "lang": "eng" },
                "scope": { "type": "dialog", "role": "topmost" }
                }
            ],
            "pick": { "policy": "firstMatch" }
            },

            "toast_success": {
            "strategy": "ocr",
            "text": "已导出",
            "match": { "mode": "contains", "lang": "chi_sim" },
            "scope": { "type": "band", "edge": "bottom", "ratio": 0.25 }
            }
        },

        "steps": [
            {
            "id": "s1",
            "op": "click",
            "target": { "$ref": "#/selectors/menu_file" },
            "retry": { "times": 3, "intervalMs": 500, "timeoutMs": 6000 },
            "on_fail": { "action": "abort", "reason": "Open menu failed" }
            },
            {
            "id": "s2",
            "op": "click",
            "target": { "$ref": "#/selectors/menu_export" },
            "retry": { "times": 4, "intervalMs": 500, "timeoutMs": 7000 },
            "on_fail": { "action": "abort", "reason": "Export entry not found" }
            },
            {
            "id": "s3",
            "op": "wait",
            "until": { "$ref": "#/selectors/dialog_export_title" },
            "params": { "mode": "appear" },
            "retry": { "times": 10, "intervalMs": 300, "timeoutMs": 4000 },
            "on_fail": { "action": "abort", "reason": "Export dialog not appeared" }
            },
            {
            "id": "s4",
            "op": "click",
            "target": { "$ref": "#/selectors/input_filename" },
            "retry": { "times": 3, "intervalMs": 300, "timeoutMs": 3500 },
            "on_fail": { "action": "abort", "reason": "Filename input not found" }
            },
            {
            "id": "s5",
            "op": "type",
            "text": "{{FILE_NAME}}",
            "params": { "clearFirst": true }
            },
            {
            "id": "s6",
            "op": "click",
            "target": { "$ref": "#/selectors/btn_confirm" },
            "retry": { "times": 3, "intervalMs": 500, "timeoutMs": 6000 },
            "on_fail": { "action": "abort", "reason": "Confirm button not found" }
            },
            {
            "id": "s7",
            "op": "wait",
            "until": { "$ref": "#/selectors/toast_success" },
            "params": { "mode": "appear" },
            "retry": { "times": 12, "intervalMs": 400, "timeoutMs": 8000 },
            "on_fail": { "action": "skip", "reason": "No success toast; continue" }
            }
        ]
        }"##;

        let pkg: Package = serde_json::from_str(json).expect("Failed to parse Case 4");
        assert_eq!(pkg.vars.len(), 2);
    }
}
