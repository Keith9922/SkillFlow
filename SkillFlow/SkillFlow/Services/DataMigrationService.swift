//
//  DataMigrationService.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import Foundation
import SwiftData

/// 数据迁移服务，用于处理旧数据格式到新格式的转换
class DataMigrationService {
    static let shared = DataMigrationService()
    
    private let migrationVersionKey = "data.migration.version"
    private let currentMigrationVersion = 2 // SEEDO API 版本
    
    private init() {}
    
    // MARK: - Migration Check
    
    /// 检查是否需要迁移
    func needsMigration() -> Bool {
        let savedVersion = UserDefaults.standard.integer(forKey: migrationVersionKey)
        return savedVersion < currentMigrationVersion
    }
    
    /// 获取当前迁移版本
    func getCurrentMigrationVersion() -> Int {
        return UserDefaults.standard.integer(forKey: migrationVersionKey)
    }
    
    // MARK: - Migration Execution
    
    /// 执行数据迁移
    func performMigration(context: ModelContext) async throws {
        let fromVersion = getCurrentMigrationVersion()
        
        print("开始数据迁移: 从版本 \(fromVersion) 到版本 \(currentMigrationVersion)")
        
        // 根据版本执行不同的迁移步骤
        if fromVersion < 1 {
            try await migrateToVersion1(context: context)
        }
        
        if fromVersion < 2 {
            try await migrateToVersion2(context: context)
        }
        
        // 更新迁移版本
        UserDefaults.standard.set(currentMigrationVersion, forKey: migrationVersionKey)
        
        print("数据迁移完成")
    }
    
    // MARK: - Version-Specific Migrations
    
    /// 迁移到版本 1（初始版本）
    private func migrateToVersion1(context: ModelContext) async throws {
        print("执行迁移到版本 1")
        // 初始版本，无需迁移
    }
    
    /// 迁移到版本 2（SEEDO API 版本）
    private func migrateToVersion2(context: ModelContext) async throws {
        print("执行迁移到版本 2: SEEDO API 兼容")
        
        // 1. 确保所有现有的 Skill 对象都有正确的数据格式
        try await validateExistingSkills(context: context)
        
        // 2. 清理可能存在的临时数据
        try await cleanupTemporaryData()
        
        // 3. 初始化新的数据结构（如果需要）
        try await initializeNewDataStructures(context: context)
    }
    
    // MARK: - Migration Helpers
    
    /// 验证现有技能数据
    private func validateExistingSkills(context: ModelContext) async throws {
        let descriptor = FetchDescriptor<Skill>()
        let skills = try context.fetch(descriptor)
        
        print("验证 \(skills.count) 个现有技能")
        
        for skill in skills {
            // 确保所有必需字段都存在
            if skill.name.isEmpty {
                skill.name = "未命名技能"
            }
            
            if skill.software.isEmpty {
                skill.software = "未知软件"
            }
            
            // 验证步骤数据
            for step in skill.steps {
                if step.instruction.isEmpty {
                    step.instruction = "无说明"
                }
                
                if step.actionType.isEmpty {
                    step.actionType = "unknown"
                }
            }
        }
        
        try context.save()
        print("技能验证完成")
    }
    
    /// 清理临时数据
    private func cleanupTemporaryData() async throws {
        print("清理临时数据")
        
        // 清理临时文件目录
        let tempDir = FileManager.default.temporaryDirectory
        let skillFlowTemp = tempDir.appendingPathComponent("SkillFlow")
        
        if FileManager.default.fileExists(atPath: skillFlowTemp.path) {
            try? FileManager.default.removeItem(at: skillFlowTemp)
            print("已清理临时目录")
        }
    }
    
    /// 初始化新的数据结构
    private func initializeNewDataStructures(context: ModelContext) async throws {
        print("初始化新数据结构")
        
        // 这里可以添加任何需要初始化的新数据结构
        // 例如：创建默认的配置、示例数据等
    }
    
    // MARK: - Data Conversion
    
    /// 将旧格式的技能数据转换为新格式
    func convertLegacySkillData(_ legacyData: SkillData) -> Skill {
        let skill = Skill(
            name: legacyData.name,
            software: legacyData.software,
            description: legacyData.description
        )
        
        skill.tags = legacyData.tags
        skill.totalSteps = legacyData.totalSteps
        
        for stepData in legacyData.steps {
            let step = SkillStep(
                stepId: stepData.stepId,
                actionType: stepData.actionType,
                targetName: stepData.target.name,
                targetType: stepData.target.type,
                instruction: stepData.instruction
            )
            step.confidence = stepData.confidence
            
            // 编码 locators
            if let locatorsData = try? JSONEncoder().encode(stepData.target.locators) {
                step.locatorsData = locatorsData
            }
            
            skill.steps.append(step)
        }
        
        return skill
    }
    
    /// 验证技能数据的完整性
    func validateSkillData(_ skill: Skill) -> [String] {
        var errors: [String] = []
        
        if skill.name.isEmpty {
            errors.append("技能名称不能为空")
        }
        
        if skill.software.isEmpty {
            errors.append("软件名称不能为空")
        }
        
        if skill.steps.isEmpty {
            errors.append("技能必须包含至少一个步骤")
        }
        
        for (index, step) in skill.steps.enumerated() {
            if step.instruction.isEmpty {
                errors.append("步骤 \(index + 1) 的说明不能为空")
            }
            
            if step.actionType.isEmpty {
                errors.append("步骤 \(index + 1) 的操作类型不能为空")
            }
            
            if step.targetName.isEmpty {
                errors.append("步骤 \(index + 1) 的目标名称不能为空")
            }
        }
        
        return errors
    }
    
    // MARK: - Backup and Restore
    
    /// 创建数据备份
    func createBackup(context: ModelContext) async throws -> URL {
        print("创建数据备份")
        
        let backupDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillFlow_Backup")
        
        try FileManager.default.createDirectory(
            at: backupDir,
            withIntermediateDirectories: true
        )
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupFile = backupDir.appendingPathComponent("backup_\(timestamp).json")
        
        // 导出所有技能数据
        let descriptor = FetchDescriptor<Skill>()
        let skills = try context.fetch(descriptor)
        
        let backupData = BackupData(
            version: currentMigrationVersion,
            timestamp: Date(),
            skills: skills.map { skill in
                BackupSkill(
                    name: skill.name,
                    software: skill.software,
                    description: skill.description,
                    tags: skill.tags,
                    steps: skill.steps.map { step in
                        BackupStep(
                            stepId: step.stepId,
                            actionType: step.actionType,
                            targetName: step.targetName,
                            targetType: step.targetType,
                            instruction: step.instruction,
                            confidence: step.confidence
                        )
                    }
                )
            }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(backupData)
        try jsonData.write(to: backupFile)
        
        print("备份已创建: \(backupFile.path)")
        return backupFile
    }
    
    /// 从备份恢复数据
    func restoreFromBackup(backupURL: URL, context: ModelContext) async throws {
        print("从备份恢复数据: \(backupURL.path)")
        
        let jsonData = try Data(contentsOf: backupURL)
        let decoder = JSONDecoder()
        let backupData = try decoder.decode(BackupData.self, from: jsonData)
        
        print("恢复 \(backupData.skills.count) 个技能")
        
        for backupSkill in backupData.skills {
            let skill = Skill(
                name: backupSkill.name,
                software: backupSkill.software,
                description: backupSkill.description
            )
            skill.tags = backupSkill.tags
            
            for backupStep in backupSkill.steps {
                let step = SkillStep(
                    stepId: backupStep.stepId,
                    actionType: backupStep.actionType,
                    targetName: backupStep.targetName,
                    targetType: backupStep.targetType,
                    instruction: backupStep.instruction
                )
                step.confidence = backupStep.confidence
                skill.steps.append(step)
            }
            
            context.insert(skill)
        }
        
        try context.save()
        print("数据恢复完成")
    }
}

// MARK: - Backup Data Structures

struct BackupData: Codable {
    let version: Int
    let timestamp: Date
    let skills: [BackupSkill]
}

struct BackupSkill: Codable {
    let name: String
    let software: String
    let description: String
    let tags: [String]
    let steps: [BackupStep]
}

struct BackupStep: Codable {
    let stepId: Int
    let actionType: String
    let targetName: String
    let targetType: String
    let instruction: String
    let confidence: Double
}
