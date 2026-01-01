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
