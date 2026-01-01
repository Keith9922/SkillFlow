//
//  SkillValidator.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import Foundation

/// Validates Skill data against backend schema
class SkillValidator {
    
    // MARK: - Validation Errors
    
    enum ValidationError: Error, LocalizedError {
        case missingRequiredField(String)
        case invalidFieldType(String, expected: String)
        case invalidEnumValue(String, field: String)
        case emptyArray(String)
        case invalidConfidence(Double)
        case invalidPriority(Int)
        
        var errorDescription: String? {
            switch self {
            case .missingRequiredField(let field):
                return "缺少必需字段: \(field)"
            case .invalidFieldType(let field, let expected):
                return "字段类型错误: \(field)，期望类型: \(expected)"
            case .invalidEnumValue(let value, let field):
                return "无效的枚举值: \(value) 在字段 \(field)"
            case .emptyArray(let field):
                return "数组不能为空: \(field)"
            case .invalidConfidence(let value):
                return "置信度必须在 0-1 之间，当前值: \(value)"
            case .invalidPriority(let value):
                return "优先级必须大于 0，当前值: \(value)"
            }
        }
    }
    
    // MARK: - Validation Methods
    
    /// Validate a complete Skill object
    /// - Parameter skill: The skill to validate
    /// - Throws: ValidationError if validation fails
    func validate(skill: Skill) throws {
        // Validate required string fields
        if skill.skillId.isEmpty {
            throw ValidationError.missingRequiredField("skill_id")
        }
        if skill.name.isEmpty {
            throw ValidationError.missingRequiredField("name")
        }
        if skill.software.isEmpty {
            throw ValidationError.missingRequiredField("software")
        }
        if skill.version.isEmpty {
            throw ValidationError.missingRequiredField("version")
        }
        
        // Validate source_type enum
        guard SourceType(rawValue: skill.sourceType) != nil else {
            throw ValidationError.invalidEnumValue(skill.sourceType, field: "source_type")
        }
        
        // Validate steps array
        if skill.steps.isEmpty {
            throw ValidationError.emptyArray("steps")
        }
        
        // Validate total_steps matches actual steps count
        if skill.totalSteps != skill.steps.count {
            throw ValidationError.invalidFieldType(
                "total_steps",
                expected: "should match steps array length (\(skill.steps.count))"
            )
        }
        
        // Validate each step
        for (index, step) in skill.steps.enumerated() {
            do {
                try validate(step: step)
            } catch {
                // Add step context to error
                throw ValidationError.invalidFieldType(
                    "steps[\(index)]",
                    expected: error.localizedDescription
                )
            }
        }
    }
    
    /// Validate a SkillStep object
    /// - Parameter step: The step to validate
    /// - Throws: ValidationError if validation fails
    func validate(step: SkillStep) throws {
        // Validate action_type enum
        guard ActionType(rawValue: step.actionType) != nil else {
            throw ValidationError.invalidEnumValue(step.actionType, field: "action_type")
        }
        
        // Validate target_type enum
        guard TargetType(rawValue: step.targetType) != nil else {
            throw ValidationError.invalidEnumValue(step.targetType, field: "target_type")
        }
        
        // Validate required string fields
        if step.instruction.isEmpty {
            throw ValidationError.missingRequiredField("instruction")
        }
        if step.targetName.isEmpty {
            throw ValidationError.missingRequiredField("target.name")
        }
        
        // Validate confidence range
        if step.confidence < 0 || step.confidence > 1 {
            throw ValidationError.invalidConfidence(step.confidence)
        }
        
        // Validate wait_after is non-negative
        if step.waitAfter < 0 {
            throw ValidationError.invalidFieldType(
                "wait_after",
                expected: "non-negative number"
            )
        }
        
        // Validate locators if present
        if let locatorsData = step.locatorsData {
            do {
                let locators = try JSONDecoder().decode([Locator].self, from: locatorsData)
                
                if locators.isEmpty {
                    throw ValidationError.emptyArray("target.locators")
                }
                
                for (index, locator) in locators.enumerated() {
                    do {
                        try validate(locator: locator)
                    } catch {
                        throw ValidationError.invalidFieldType(
                            "target.locators[\(index)]",
                            expected: error.localizedDescription
                        )
                    }
                }
            } catch let error as DecodingError {
                throw ValidationError.invalidFieldType(
                    "target.locators",
                    expected: "valid JSON array of Locator objects: \(error.localizedDescription)"
                )
            }
        } else {
            throw ValidationError.missingRequiredField("target.locators")
        }
    }
    
    /// Validate a Locator object
    /// - Parameter locator: The locator to validate
    /// - Throws: ValidationError if validation fails
    func validate(locator: Locator) throws {
        // Locator method is already validated by enum type
        
        // Validate priority is positive
        if locator.priority < 1 {
            throw ValidationError.invalidPriority(locator.priority)
        }
        
        // Note: We don't validate the value field deeply since it's AnyCodable
        // and can be various types depending on the locator method
    }
    
    // MARK: - Convenience Methods
    
    /// Validate and return detailed error messages
    /// - Parameter skill: The skill to validate
    /// - Returns: Array of error messages (empty if valid)
    func validateAndGetErrors(skill: Skill) -> [String] {
        do {
            try validate(skill: skill)
            return []
        } catch let error as ValidationError {
            return [error.localizedDescription]
        } catch {
            return [error.localizedDescription]
        }
    }
    
    /// Check if a skill is valid
    /// - Parameter skill: The skill to check
    /// - Returns: true if valid, false otherwise
    func isValid(skill: Skill) -> Bool {
        do {
            try validate(skill: skill)
            return true
        } catch {
            return false
        }
    }
}
