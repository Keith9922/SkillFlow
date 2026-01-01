//
//  Models.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import SwiftData

// MARK: - Backend-Aligned Enums

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
}

/// Target element type
enum TargetType: String, Codable {
    case button = "button"
    case toolButton = "tool_button"
    case menuItem = "menu_item"
    case inputField = "input_field"
    case icon = "icon"
}

/// Locator method for finding UI elements
enum LocatorMethod: String, Codable {
    case accessibility = "accessibility"
    case text = "text"
    case position = "position"
    case visual = "visual"
}

// MARK: - Supporting Structures

/// Type-erased codable wrapper for dynamic JSON values
struct AnyCodable: Codable {
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

// MARK: - SwiftData Models

@Model
final class Skill {
    @Attribute(.unique) var id: UUID
    var skillId: String  // Backend skill_id
    var name: String
    var software: String
    var version: String  // Software version
    var skillDescription: String
    var sourceType: String  // "video_analysis" or "manual"
    var sourceUrl: String?
    var thumbnailData: Data?
    var createdAt: Date
    var usageCount: Int
    var tags: [String]
    var totalSteps: Int
    var estimatedDuration: Int
    
    @Relationship(deleteRule: .cascade)
    var steps: [SkillStep]
    
    init(
        id: UUID = UUID(),
        skillId: String = UUID().uuidString,
        name: String,
        software: String,
        version: String = "any",
        description: String = "",
        sourceType: SourceType = .manual,
        steps: [SkillStep] = []
    ) {
        self.id = id
        self.skillId = skillId
        self.name = name
        self.software = software
        self.version = version
        self.skillDescription = description
        self.sourceType = sourceType.rawValue
        self.steps = steps
        self.createdAt = Date()
        self.usageCount = 0
        self.tags = []
        self.totalSteps = steps.count
        self.estimatedDuration = steps.count * 3
    }
}

@Model
final class SkillStep {
    var stepId: Int
    var actionType: String  // Use ActionType enum raw value
    var targetName: String
    var targetType: String  // Use TargetType enum raw value
    var instruction: String
    var waitAfter: Double  // Wait time after action in seconds
    var confidence: Double  // Confidence score 0-1
    var parametersData: Data?  // JSON encoded parameters (input text, drag distance, etc.)
    var locatorsData: Data?  // JSON encoded array of Locator structs
    
    init(
        stepId: Int,
        actionType: ActionType,
        targetName: String,
        targetType: TargetType = .button,
        instruction: String,
        waitAfter: Double = 0.5,
        confidence: Double = 0.8
    ) {
        self.stepId = stepId
        self.actionType = actionType.rawValue
        self.targetName = targetName
        self.targetType = targetType.rawValue
        self.instruction = instruction
        self.waitAfter = waitAfter
        self.confidence = confidence
    }
}

@Model
final class Message {
    var id: UUID
    var content: String
    var isUser: Bool
    var timestamp: Date
    var skillData: Data?  // JSON encoded skill card data
    
    init(content: String, isUser: Bool) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}
