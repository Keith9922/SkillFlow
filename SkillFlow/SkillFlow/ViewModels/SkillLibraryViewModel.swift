//
//  SkillLibraryViewModel.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class SkillLibraryViewModel: ObservableObject {
    @Published var skills: [Skill] = []
    @Published var searchText = ""
    @Published var selectedCategory = "全部"
    @Published var sortBy: SortOption = .recent
    
    private var modelContext: ModelContext?
    
    let categories = ["全部", "图像处理", "办公软件", "开发工具", "浏览器", "其他"]
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadSkills()
    }
    
    // MARK: - Load Skills
    
    func loadSkills() {
        guard let context = modelContext else { return }
        
        var descriptor = FetchDescriptor<Skill>()
        
        // Apply filters
        if !searchText.isEmpty {
            descriptor.predicate = #Predicate { skill in
                skill.name.contains(searchText) ||
                skill.skillDescription.contains(searchText) ||
                skill.tags.contains(searchText)
            }
        }
        
        // Apply sorting
        switch sortBy {
        case .recent:
            descriptor.sortBy = [SortDescriptor(\.createdAt, order: .reverse)]
        case .name:
            descriptor.sortBy = [SortDescriptor(\.name)]
        case .usage:
            descriptor.sortBy = [SortDescriptor(\.usageCount, order: .reverse)]
        }
        
        do {
            var fetchedSkills = try context.fetch(descriptor)
            
            // Filter by category
            if selectedCategory != "全部" {
                fetchedSkills = fetchedSkills.filter { skill in
                    getCategoryForSoftware(skill.software) == selectedCategory
                }
            }
            
            skills = fetchedSkills
        } catch {
            print("Failed to load skills: \(error)")
        }
    }
    
    // MARK: - Skill Management
    
    func deleteSkill(_ skill: Skill) {
        guard let context = modelContext else { return }
        
        context.delete(skill)
        try? context.save()
        loadSkills()
    }
    
    func updateSkill(_ skill: Skill) {
        guard let context = modelContext else { return }
        try? context.save()
        loadSkills()
    }
    
    func incrementUsageCount(_ skill: Skill) {
        skill.usageCount += 1
        updateSkill(skill)
    }
    
    func addTag(_ tag: String, to skill: Skill) {
        if !skill.tags.contains(tag) {
            skill.tags.append(tag)
            updateSkill(skill)
        }
    }
    
    func removeTag(_ tag: String, from skill: Skill) {
        skill.tags.removeAll { $0 == tag }
        updateSkill(skill)
    }
    
    // MARK: - Export/Import
    
    func exportSkill(_ skill: Skill) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let exportData = SkillExportData(
            name: skill.name,
            software: skill.software,
            description: skill.skillDescription,
            tags: skill.tags,
            steps: skill.steps.map { step in
                StepExportData(
                    stepId: step.stepId,
                    actionType: step.actionType,
                    targetName: step.targetName,
                    targetType: step.targetType,
                    instruction: step.instruction,
                    waitAfter: step.waitAfter,
                    confidence: step.confidence,
                    locators: step.locatorsData
                )
            }
        )
        
        return try? encoder.encode(exportData)
    }
    
    func importSkill(from data: Data) -> Bool {
        guard let context = modelContext else { return false }
        
        let decoder = JSONDecoder()
        
        do {
            let exportData = try decoder.decode(SkillExportData.self, from: data)
            
            let skill = Skill(
                name: exportData.name,
                software: exportData.software,
                description: exportData.description
            )
            
            skill.tags = exportData.tags
            
            for stepData in exportData.steps {
                // Convert string to enum
                guard let actionType = ActionType(rawValue: stepData.actionType),
                      let targetType = TargetType(rawValue: stepData.targetType) else {
                    throw NSError(domain: "SkillImport", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "Invalid action or target type in step \(stepData.stepId)"
                    ])
                }
                
                let step = SkillStep(
                    stepId: stepData.stepId,
                    actionType: actionType,
                    targetName: stepData.targetName,
                    targetType: targetType,
                    instruction: stepData.instruction
                )
                step.waitAfter = stepData.waitAfter
                step.confidence = stepData.confidence
                step.locatorsData = stepData.locators
                
                skill.steps.append(step)
            }
            
            context.insert(skill)
            try context.save()
            loadSkills()
            
            return true
        } catch {
            print("Failed to import skill: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCategoryForSoftware(_ software: String) -> String {
        let mapping: [String: String] = [
            "Photoshop": "图像处理",
            "Illustrator": "图像处理",
            "Excel": "办公软件",
            "Word": "办公软件",
            "PowerPoint": "办公软件",
            "Xcode": "开发工具",
            "VSCode": "开发工具",
            "Chrome": "浏览器",
            "Safari": "浏览器"
        ]
        
        return mapping[software] ?? "其他"
    }
    
    var filteredSkills: [Skill] {
        skills
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case recent = "最近创建"
    case name = "名称"
    case usage = "使用次数"
}

// MARK: - Export Data Models

struct SkillExportData: Codable {
    let name: String
    let software: String
    let description: String
    let tags: [String]
    let steps: [StepExportData]
}

struct StepExportData: Codable {
    let stepId: Int
    let actionType: String
    let targetName: String
    let targetType: String
    let instruction: String
    let waitAfter: Double
    let confidence: Double
    let locators: Data?
}
