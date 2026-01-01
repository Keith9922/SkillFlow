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
    // Removed internal skills array. View uses @Query now.
    
    @Published var searchText = ""
    @Published var selectedCategory = "全部"
    @Published var sortBy: SortOption = .recent
    
    private var modelContext: ModelContext?
    
    let categories = ["全部", "图像处理", "办公软件", "开发工具", "浏览器", "其他"]
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Filtering
    
    func filterSkills(_ skills: [Skill]) -> [Skill] {
        var result = skills
        
        // Filter by category
        if selectedCategory != "全部" {
            // Since Skill doesn't have explicit category, we infer it or check tags
            // For now, simple logic or assume "其他"
            // Implementation: Check if any tag matches category or map software to category
            result = result.filter { skill in
                let category = getCategoryForSoftware(skill.software)
                return category == selectedCategory
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { skill in
                skill.name.localizedCaseInsensitiveContains(searchText) ||
                skill.software.localizedCaseInsensitiveContains(searchText) ||
                skill.skillDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort (Note: @Query already handles basic sorting, but if we need dynamic sorting in memory:
        // Ideally @Query should handle sorting. But dynamic sorting with @Query is tricky in SwiftUI.
        // We will sort in memory here.)
        switch sortBy {
        case .recent:
            result.sort { $0.createdAt > $1.createdAt }
        case .name:
            result.sort { $0.name < $1.name }
        case .usage:
            result.sort { $0.usageCount > $1.usageCount }
        }
        
        return result
    }
    
    // MARK: - Skill Management
    
    func deleteSkill(_ skill: Skill) {
        modelContext?.delete(skill)
        try? modelContext?.save()
    }
    
    func addSampleData() {
        guard let context = modelContext else { return }
        
        // Create Sample 1: Photoshop Crop
        let meta1 = PackageMeta(
            name: "快速裁剪图片",
            createdAt: ISO8601DateFormatter().string(from: Date()),
            description: "自动裁剪图片到 16:9",
            author: "System",
            tags: ["图像处理", "效率"]
        )
        let app1 = AppSpec(name: "Photoshop", minVersion: "2024", maxVersion: nil)
        let step1 = AIPDLStep.click(StepClick(
            id: "s1", op: .click, name: "Select Crop Tool",
            scope: nil, retry: nil, onFail: nil,
            target: .selector(.ocr(OCRSelector(strategy: "ocr", text: "Crop Tool", match: nil, scope: nil))),
            params: nil, fallback: nil
        ))
        let package1 = AIPDLPackage(
            version: "0.1", package: meta1, app: app1,
            env: nil, vars: nil, selectors: nil, steps: [step1]
        )
        
        let skill1 = Skill(
            name: meta1.name,
            software: app1.name,
            description: meta1.description ?? "",
            packageData: try? JSONEncoder().encode(package1)
        )
        
        // Create Sample 2: Excel Sum
        let meta2 = PackageMeta(
            name: "自动求和",
            createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
            description: "对选定列进行求和",
            author: "System",
            tags: ["办公软件", "Excel"]
        )
        let app2 = AppSpec(name: "Excel", minVersion: nil, maxVersion: nil)
        let package2 = AIPDLPackage(
            version: "0.1", package: meta2, app: app2,
            env: nil, vars: nil, selectors: nil, steps: []
        )
        
        let skill2 = Skill(
            name: meta2.name,
            software: app2.name,
            description: meta2.description ?? "",
            packageData: try? JSONEncoder().encode(package2)
        )
        
        context.insert(skill1)
        context.insert(skill2)
        try? context.save()
    }
    
    // MARK: - Helper Methods
    
    private func getCategoryForSoftware(_ software: String) -> String {
        switch software.lowercased() {
        case "photoshop", "lightroom", "illustrator": return "图像处理"
        case "excel", "word", "powerpoint", "pages", "numbers": return "办公软件"
        case "xcode", "vscode", "terminal": return "开发工具"
        case "safari", "chrome", "firefox": return "浏览器"
        default: return "其他"
        }
    }
}

// MARK: - Sort Option

enum SortOption: String, CaseIterable {
    case recent = "最近创建"
    case name = "名称"
    case usage = "使用次数"
}
