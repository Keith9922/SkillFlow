//
//  DataConverter.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//  数据转换工具 - 将 SEEDO API 数据转换为 SkillFlow 数据模型
//

import Foundation

class DataConverter {
    // MARK: - Singleton
    static let shared = DataConverter()
    
    private let validator = SkillValidator()
    
    init() {}
    
    // MARK: - Audio Data Conversion
    
    /// 转换音频结果（转录文本）
    /// - Parameter artifactData: Artifact 数据
    /// - Returns: 转录文本
    func convertAudioArtifact(_ artifactData: ArtifactData) throws -> String {
        guard artifactData.track == "audio" else {
            throw ConversionError.wrongTrackType
        }
        
        // 音频结果应该是字符串
        if let text = artifactData.data.value as? String {
            return text
        }
        
        throw ConversionError.invalidDataFormat
    }
    
    // MARK: - Video Data Conversion
    
    /// 转换视频分析结果
    /// - Parameter artifactData: Artifact 数据
    /// - Returns: 视频分析数据
    func convertVideoArtifact(_ artifactData: ArtifactData) throws -> VideoAnalysisData {
        guard artifactData.track == "video" else {
            throw ConversionError.wrongTrackType
        }
        
        // 将 AnyCodable 转换为 VideoAnalysisData
        let jsonData = try JSONSerialization.data(
            withJSONObject: artifactData.data.value
        )
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        return try decoder.decode(VideoAnalysisData.self, from: jsonData)
    }
    
    // MARK: - Steps Data Conversion
    
    /// 转换步骤数据为 Skill 模型
    /// - Parameter artifactData: Artifact 数据
    /// - Returns: Skill 模型
    func convertStepsArtifact(_ artifactData: ArtifactData) throws -> Skill {
        guard artifactData.track == "steps" else {
            throw ConversionError.wrongTrackType
        }
        
        // 将 AnyCodable 转换为字典
        guard let dict = artifactData.data.value as? [String: Any] else {
            throw ConversionError.invalidDataFormat
        }
        
        // 提取基本信息
        guard let skillId = dict["skill_id"] as? String,
              let name = dict["name"] as? String,
              let software = dict["software"] as? String else {
            throw ConversionError.missingRequiredFields
        }
        
        let version = dict["version"] as? String ?? "any"
        let description = dict["description"] as? String ?? ""
        let tags = dict["tags"] as? [String] ?? []
        let sourceTypeStr = dict["source_type"] as? String ?? "video_analysis"
        
        // 验证 source_type
        guard let sourceType = SourceType(rawValue: sourceTypeStr) else {
            throw ConversionError.invalidDataFormat
        }
        
        // 转换步骤数据
        guard let stepsArray = dict["steps"] as? [[String: Any]] else {
            throw ConversionError.invalidDataFormat
        }
        
        let steps = try stepsArray.map { stepDict in
            try convertStepData(stepDict)
        }
        
        // 创建 Skill 对象
        let skill = Skill(
            skillId: skillId,
            name: name,
            software: software,
            version: version,
            description: description,
            sourceType: sourceType,
            steps: steps
        )
        
        // 设置额外属性
        skill.tags = tags
        skill.totalSteps = steps.count
        skill.estimatedDuration = steps.count * 3
        
        // 验证转换后的 Skill
        do {
            try validator.validate(skill: skill)
        } catch {
            throw ConversionError.validationFailed(error.localizedDescription)
        }
        
        return skill
    }
    
    // MARK: - Private Helper Methods
    
    /// 转换单个步骤数据
    private func convertStepData(_ dict: [String: Any]) throws -> SkillStep {
        guard let stepId = dict["step_id"] as? Int,
              let actionTypeStr = dict["action_type"] as? String,
              let targetDict = dict["target"] as? [String: Any],
              let targetName = targetDict["name"] as? String,
              let instruction = dict["instruction"] as? String else {
            throw ConversionError.invalidStepData
        }
        
        // 验证 action_type
        guard let actionType = ActionType(rawValue: actionTypeStr) else {
            throw ConversionError.invalidDataFormat
        }
        
        let targetTypeStr = targetDict["type"] as? String ?? "button"
        
        // 验证 target_type
        guard let targetType = TargetType(rawValue: targetTypeStr) else {
            throw ConversionError.invalidDataFormat
        }
        
        // 创建 SkillStep 对象
        let step = SkillStep(
            stepId: stepId,
            actionType: actionType,
            targetName: targetName,
            targetType: targetType,
            instruction: instruction
        )
        
        // 设置可选属性
        if let waitAfter = dict["wait_after"] as? Double {
            step.waitAfter = waitAfter
        }
        
        if let confidence = dict["confidence"] as? Double {
            step.confidence = confidence
        }
        
        // 转换 parameters 数据
        if let parameters = dict["parameters"] {
            let parametersData = try JSONSerialization.data(withJSONObject: parameters)
            step.parametersData = parametersData
        }
        
        // 转换 locators 数据
        if let locatorsArray = targetDict["locators"] as? [[String: Any]] {
            let locatorsData = try JSONSerialization.data(withJSONObject: locatorsArray)
            step.locatorsData = locatorsData
        }
        
        return step
    }
    
    // MARK: - Reverse Conversion (for compatibility)
    
    /// 将 Skill 转换回 SEEDO 格式（用于验证或导出）
    /// - Parameter skill: Skill 模型
    /// - Returns: 字典格式的数据
    func convertSkillToDict(_ skill: Skill) -> [String: Any] {
        var dict: [String: Any] = [
            "name": skill.name,
            "software": skill.software,
            "description": skill.skillDescription,
            "tags": skill.tags,
            "total_steps": skill.totalSteps,
            "estimated_duration": skill.estimatedDuration
        ]
        
        let stepsArray = skill.steps.map { step -> [String: Any] in
            var stepDict: [String: Any] = [
                "step_id": step.stepId,
                "action_type": step.actionType,
                "target": [
                    "name": step.targetName,
                    "type": step.targetType
                ],
                "instruction": step.instruction,
                "wait_after": step.waitAfter,
                "confidence": step.confidence
            ]
            
            // 添加 locators 如果存在
            if let locatorsData = step.locatorsData,
               let locators = try? JSONSerialization.jsonObject(with: locatorsData) {
                var targetDict = stepDict["target"] as! [String: Any]
                targetDict["locators"] = locators
                stepDict["target"] = targetDict
            }
            
            return stepDict
        }
        
        dict["steps"] = stepsArray
        
        return dict
    }
}

// MARK: - Conversion Error

enum ConversionError: Error, LocalizedError {
    case wrongTrackType
    case invalidDataFormat
    case missingRequiredFields
    case invalidStepData
    case jsonSerializationFailed
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .wrongTrackType:
            return "错误的数据类型"
        case .invalidDataFormat:
            return "无效的数据格式"
        case .missingRequiredFields:
            return "缺少必需字段"
        case .invalidStepData:
            return "无效的步骤数据"
        case .jsonSerializationFailed:
            return "JSON 序列化失败"
        case .validationFailed(let message):
            return "数据验证失败: \(message)"
        }
    }
}
