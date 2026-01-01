//
//  AIPDLModels.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation

// MARK: - Core Protocols & Enums

/// Type-erased codable wrapper for dynamic JSON values
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode AnyCodable"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let dict as [String: Any]:
            let codableDict = dict.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        case let array as [Any]:
            let codableArray = array.map { AnyCodable($0) }
            try container.encode(codableArray)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Cannot encode value of type \(type(of: value))"
                )
            )
        }
    }
}

// MARK: - AIPDL Package

struct AIPDLPackage: Codable {
    let version: String
    let package: PackageMeta
    let app: AppSpec
    let env: EnvSpec?
    let vars: [String: VarDef]?
    let selectors: [String: Selector]?
    let steps: [AIPDLStep]
}

struct PackageMeta: Codable {
    let name: String
    let createdAt: String // ISO8601
    let description: String?
    let author: String?
    let tags: [String]?
}

struct AppSpec: Codable {
    let name: String
    let minVersion: String?
    let maxVersion: String?
}

struct EnvSpec: Codable {
    let os: [String]?
    let resolutionHint: String?
    let localeHint: String?
}

struct VarDef: Codable {
    let type: String
    let `default`: AnyCodable?
    let description: String?
}

// MARK: - Selectors

indirect enum SelectorOrRef: Codable {
    case ref(String)
    case selector(Selector)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let refDict = try? container.decode([String: String].self),
           let ref = refDict["$ref"] {
            self = .ref(ref)
        } else {
            self = .selector(try container.decode(Selector.self))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .ref(let ref):
            try container.encode(["$ref": ref])
        case .selector(let selector):
            try container.encode(selector)
        }
    }
}

indirect enum Selector: Codable {
    case ocr(OCRSelector)
    case template(TemplateSelector)
    case relative(RelativeSelector)
    case multi(MultiSelector)
    
    enum CodingKeys: String, CodingKey {
        case strategy
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let strategy = try container.decode(String.self, forKey: .strategy)
        
        switch strategy {
        case "ocr":
            self = .ocr(try OCRSelector(from: decoder))
        case "template":
            self = .template(try TemplateSelector(from: decoder))
        case "relative":
            self = .relative(try RelativeSelector(from: decoder))
        case "multi":
            self = .multi(try MultiSelector(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .strategy, in: container, debugDescription: "Unknown selector strategy: \(strategy)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .ocr(let s): try s.encode(to: encoder)
        case .template(let s): try s.encode(to: encoder)
        case .relative(let s): try s.encode(to: encoder)
        case .multi(let s): try s.encode(to: encoder)
        }
    }
}

struct OCRSelector: Codable {
    let strategy: String
    let text: String
    let match: OCRMatch?
    let scope: Scope?
}

struct OCRMatch: Codable {
    enum Mode: String, Codable {
        case equals, contains, regex
    }
    let mode: Mode?
    let lang: String?
    let caseSensitive: Bool?
    let regex: String?
}

struct TemplateSelector: Codable {
    let strategy: String
    let template: String
    let match: TemplateMatch?
    let scope: Scope?
}

struct TemplateMatch: Codable {
    let threshold: Double?
}

struct RelativeSelector: Codable {
    let strategy: String
    let anchor: SelectorOrRef
    let relation: Relation
    let target: SelectorOrRef
    let scope: Scope?
}

struct Relation: Codable {
    enum RelationType: String, Codable {
        case below, above, leftOf, rightOf, near
    }
    let type: RelationType
    let maxDistancePx: Int?
}

struct MultiSelector: Codable {
    let strategy: String
    let candidates: [SelectorOrRef]
    let pick: PickPolicy?
    let scope: Scope?
}

struct PickPolicy: Codable {
    enum Policy: String, Codable {
        case bestConfidence, firstMatch
    }
    let policy: Policy?
}

// MARK: - Scopes

indirect enum Scope: Codable {
    case rect(ScopeRect)
    case band(ScopeBand)
    case window(ScopeWindow)
    case dialog(ScopeDialog)
    case activeMenu
    case elementRef(ScopeElementRef)
    case around(ScopeAround)
    case nearest(ScopeNearest)
    case union(ScopeUnion)
    case intersect(ScopeIntersect)
    case exclude(ScopeExclude)
    
    enum CodingKeys: String, CodingKey {
        case type
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "rect": self = .rect(try ScopeRect(from: decoder))
        case "band": self = .band(try ScopeBand(from: decoder))
        case "window": self = .window(try ScopeWindow(from: decoder))
        case "dialog": self = .dialog(try ScopeDialog(from: decoder))
        case "activeMenu": self = .activeMenu
        case "elementRef": self = .elementRef(try ScopeElementRef(from: decoder))
        case "around": self = .around(try ScopeAround(from: decoder))
        case "nearest": self = .nearest(try ScopeNearest(from: decoder))
        case "union": self = .union(try ScopeUnion(from: decoder))
        case "intersect": self = .intersect(try ScopeIntersect(from: decoder))
        case "exclude": self = .exclude(try ScopeExclude(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown scope type: \(type)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .rect(let s): try s.encode(to: encoder)
        case .band(let s): try s.encode(to: encoder)
        case .window(let s): try s.encode(to: encoder)
        case .dialog(let s): try s.encode(to: encoder)
        case .activeMenu: 
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("activeMenu", forKey: .type)
        case .elementRef(let s): try s.encode(to: encoder)
        case .around(let s): try s.encode(to: encoder)
        case .nearest(let s): try s.encode(to: encoder)
        case .union(let s): try s.encode(to: encoder)
        case .intersect(let s): try s.encode(to: encoder)
        case .exclude(let s): try s.encode(to: encoder)
        }
    }
}

struct ScopeRect: Codable {
    let type: String
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let normalized: Bool?
}

struct ScopeBand: Codable {
    let type: String
    let edge: String // top, bottom, left, right
    let ratio: Double
}

struct ScopeWindow: Codable {
    let type: String
    let mode: String // active, main, byTitle
    let title: String?
    let match: String? // equals, contains, regex
}

struct ScopeDialog: Codable {
    let type: String
    let role: String // topmost, modal, byTitle
    let title: String?
    let match: String?
}

struct ScopeElementRef: Codable {
    let type: String
    let refStepId: String
    let paddingPx: Int?
}

struct ScopeAround: Codable {
    let type: String
    let anchor: SelectorOrRef
    let radiusPx: Int
}

struct ScopeNearest: Codable {
    let type: String
    let to: String // anchor
}

struct ScopeUnion: Codable {
    let type: String
    let scopes: [Scope]
}

struct ScopeIntersect: Codable {
    let type: String
    let scopes: [Scope]
}

struct ScopeExclude: Codable {
    let type: String
    let base: Scope
    let exclude: Scope
}

// MARK: - Steps

struct RetryPolicy: Codable {
    let times: Int?
    let intervalMs: Int?
    let timeoutMs: Int?
}

struct OnFailPolicy: Codable {
    enum Action: String, Codable {
        case abort, skip, fallback_step_id
    }
    let action: Action
    let reason: String?
    let stepId: String?
}

struct Fallback: Codable {
    let point: FallbackPoint
    let policy: String? // last_retry_only, always
}

struct FallbackPoint: Codable {
    let x: Double
    let y: Double
    let normalized: Bool?
}

enum AIPDLOpType: String, Codable {
    case click, drag, type, scroll, hotkey, wait, assert
}

struct AIPDLBaseStep: Codable {
    let id: String?
    let op: AIPDLOpType
    let name: String?
    let scope: Scope?
    let retry: RetryPolicy?
    let onFail: OnFailPolicy?
    
    enum CodingKeys: String, CodingKey {
        case id, op, name, scope, retry
        case onFail = "on_fail"
    }
}

enum AIPDLStep: Codable {
    case click(StepClick)
    case drag(StepDrag)
    case type(StepType)
    case scroll(StepScroll)
    case hotkey(StepHotkey)
    case wait(StepWait)
    case assert(StepAssert)
    
    enum CodingKeys: String, CodingKey {
        case op
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let op = try container.decode(AIPDLOpType.self, forKey: .op)
        
        switch op {
        case .click: self = .click(try StepClick(from: decoder))
        case .drag: self = .drag(try StepDrag(from: decoder))
        case .type: self = .type(try StepType(from: decoder))
        case .scroll: self = .scroll(try StepScroll(from: decoder))
        case .hotkey: self = .hotkey(try StepHotkey(from: decoder))
        case .wait: self = .wait(try StepWait(from: decoder))
        case .assert: self = .assert(try StepAssert(from: decoder))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        switch self {
        case .click(let s): try s.encode(to: encoder)
        case .drag(let s): try s.encode(to: encoder)
        case .type(let s): try s.encode(to: encoder)
        case .scroll(let s): try s.encode(to: encoder)
        case .hotkey(let s): try s.encode(to: encoder)
        case .wait(let s): try s.encode(to: encoder)
        case .assert(let s): try s.encode(to: encoder)
        }
    }
}

// Specific Step Definitions

struct StepClick: Codable {
    let id: String?
    let op: AIPDLOpType
    let name: String?
    let scope: Scope?
    let retry: RetryPolicy?
    let onFail: OnFailPolicy?
    
    let target: SelectorOrRef
    let params: ClickParams?
    let fallback: Fallback?
    
    enum CodingKeys: String, CodingKey {
        case id, op, name, scope, retry
        case onFail = "on_fail"
        case target, params, fallback
    }
}

struct ClickParams: Codable {
    enum Button: String, Codable {
        case left, right, middle
    }
    let button: Button?
    let clickCount: Int?
    let offset: Offset?
}

struct Offset: Codable {
    let dx: Int
    let dy: Int
}

struct StepDrag: Codable {
    let id: String?
    let op: AIPDLOpType
    let name: String?
    let scope: Scope?
    let retry: RetryPolicy?
    let onFail: OnFailPolicy?
    
    let from: SelectorOrRef
    let to: SelectorOrRef?
    let vector: DragVector?
    let params: DragParams?
    let fallback: Fallback?
    
    enum CodingKeys: String, CodingKey {
        case id, op, name, scope, retry
        case onFail = "on_fail"
        case from, to, vector, params, fallback
    }
}

struct DragVector: Codable {
    let direction: String // up, down, left, right
    let distancePx: Int
}

struct DragParams: Codable {
    let durationMs: Int?
}

struct StepType: Codable {
    let id: String?
    let op: AIPDLOpType
    let name: String?
    let scope: Scope?
    let retry: RetryPolicy?
    let onFail: OnFailPolicy?
    
    let text: String
    let target: SelectorOrRef?
    let params: TypeParams?
    
    enum CodingKeys: String, CodingKey {
        case id, op, name, scope, retry
        case onFail = "on_fail"
        case text, target, params
    }
}

struct TypeParams: Codable {
    let clearFirst: Bool?
    let delayPerCharMs: Int?
}

struct StepScroll: Codable {
    let id: String?
    let op: AIPDLOpType
    let name: String?
    let scope: Scope?
    let retry: RetryPolicy?
    let onFail: OnFailPolicy?
    
    let target: SelectorOrRef?
    let delta: ScrollDelta
    let params: ScrollParams?
    
    enum CodingKeys: String, CodingKey {
        case id, op, name, scope, retry
        case onFail = "on_fail"
        case target, delta, params
    }
}

struct ScrollDelta: Codable {
    let direction: String // up, down, left, right
    let amount: Int
}

struct ScrollParams: Codable {
    let steps: Int?
}

struct StepHotkey: Codable {
    let id: String?
    let op: AIPDLOpType
    let name: String?
    let scope: Scope?
    let retry: RetryPolicy?
    let onFail: OnFailPolicy?
    
    let keys: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, op, name, scope, retry
        case onFail = "on_fail"
        case keys
    }
}

struct StepWait: Codable {
    let id: String?
    let op: AIPDLOpType
    let name: String?
    let scope: Scope?
    let retry: RetryPolicy?
    let onFail: OnFailPolicy?
    
    let until: SelectorOrRef
    let params: WaitParams?
    
    enum CodingKeys: String, CodingKey {
        case id, op, name, scope, retry
        case onFail = "on_fail"
        case until, params
    }
}

struct WaitParams: Codable {
    let mode: String? // appear, disappear
    let minConfidence: Double?
}

struct StepAssert: Codable {
    let id: String?
    let op: AIPDLOpType
    let name: String?
    let scope: Scope?
    let retry: RetryPolicy?
    let onFail: OnFailPolicy?
    
    let expect: SelectorOrRef
    let params: AssertParams?
    
    enum CodingKeys: String, CodingKey {
        case id, op, name, scope, retry
        case onFail = "on_fail"
        case expect, params
    }
}

struct AssertParams: Codable {
    let minConfidence: Double?
    let negate: Bool?
}

// MARK: - Legacy / Compatibility Types

/// Source type for skill creation
enum SourceType: String, Codable {
    case videoAnalysis = "video_analysis"
    case manual = "manual"
}

/// Action type for skill steps
enum ActionType: String, Codable {
    case click = "click"
    case input = "input"
    case drag = "drag"
    case shortcut = "shortcut"
    case menu = "menu"
    // Schema compatible types
    case type = "type"
    case scroll = "scroll"
    case hotkey = "hotkey"
    case wait = "wait"
    case assert = "assert"
}

/// Target element type
enum TargetType: String, Codable {
    case button = "button"
    case toolButton = "tool_button"
    case menuItem = "menu_item"
    case inputField = "input_field"
    case icon = "icon"
    case unknown = "unknown"
}

/// Locator method for finding UI elements
enum LocatorMethod: String, Codable {
    case accessibility = "accessibility"
    case text = "text"
    case position = "position"
    case visual = "visual"
}

/// Locator for finding UI elements
struct Locator: Codable {
    let method: LocatorMethod
    let value: AnyCodable
    let priority: Int
}

/// Target element information
struct Target: Codable {
    let targetType: TargetType
    let name: String
    let locators: [Locator]
    
    enum CodingKeys: String, CodingKey {
        case targetType = "type"
        case name
        case locators
    }
}
