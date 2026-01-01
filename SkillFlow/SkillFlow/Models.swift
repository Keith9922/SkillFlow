//
//  Models.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class Skill {
    @Attribute(.unique) var id: UUID
    var skillId: String  // Backend skill_id or generated
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
    
    // Full JSON Data conforming to AIPDL Schema
    @Attribute(.externalStorage)
    var packageData: Data?
    
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
        steps: [SkillStep] = [],
        packageData: Data? = nil
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
        self.packageData = packageData
    }
    
    // Helper to decode packageData
    func getPackage() -> AIPDLPackage? {
        guard let data = packageData else { return nil }
        return try? JSONDecoder().decode(AIPDLPackage.self, from: data)
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
    var parametersData: Data?  // JSON encoded parameters
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
