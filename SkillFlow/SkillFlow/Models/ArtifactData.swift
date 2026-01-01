//
//  ArtifactData.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation

struct ArtifactData: Codable {
    let entryId: String
    let track: String
    let data: AnyCodable
    
    enum CodingKeys: String, CodingKey {
        case entryId
        case track
        case data
    }
}

// Helper to handle any Codable type
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
                    codingPath: container.codingPath,
                    debugDescription: "Cannot encode AnyCodable"
                )
            )
        }
    }
}

// Video Analysis Data Structure
struct VideoAnalysisData: Codable {
    let frames: [FrameAnalysis]
    let software: String
    let operations: [Operation]
}

struct FrameAnalysis: Codable {
    let frameNumber: Int
    let timestamp: Double
    let description: String
    let elements: [UIElement]
}

struct UIElement: Codable {
    let type: String
    let name: String
    let position: CGPoint?
    let action: String?
}

struct Operation: Codable {
    let stepId: Int
    let actionType: String
    let target: String
    let description: String
}
