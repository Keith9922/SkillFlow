//
//  Skill.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import SwiftData

@Model
final class Skill {
    @Attribute(.unique) var id: UUID
    var name: String
    var software: String
    var skillDescription: String
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
        name: String,
        software: String,
        description: String = "",
        steps: [SkillStep] = []
    ) {
        self.id = id
        self.name = name
        self.software = software
        self.skillDescription = description
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
    var actionType: String  // "click", "input", "drag", "shortcut"
    var targetName: String
    var targetType: String
    var instruction: String
    var waitAfter: Double
    var confidence: Double
    var locatorsData: Data?  // JSON encoded locators
    
    init(
        stepId: Int,
        actionType: String,
        targetName: String,
        targetType: String = "button",
        instruction: String
    ) {
        self.stepId = stepId
        self.actionType = actionType
        self.targetName = targetName
        self.targetType = targetType
        self.instruction = instruction
        self.waitAfter = 0.5
        self.confidence = 0.8
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
