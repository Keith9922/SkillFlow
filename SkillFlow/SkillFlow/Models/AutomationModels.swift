//
//  AutomationModels.swift
//  SkillFlow
//
//  Created by SkillFlow Automation on 2026/1/2.
//

import Foundation

/// 自动化动作类型
public enum AutomationActionType: String, Codable {
    case moveMouse = "move_mouse"
    case mouseDown = "mouse_down"
    case mouseUp = "mouse_up"
    case click = "click" // 复合动作，方便模型输出
    case keyPress = "key_press"
    case keyRelease = "key_release"
    case type = "type" // 复合动作：输入文本 (Legacy)
    case pasteText = "paste_text" // 新增：剪贴板粘贴文本
    case delay = "delay"
    case allRelease = "all_release"
    case finish = "finish"
    case resubmit = "resubmit" // 新增：重新提交任务以进行多步操作
    case fail = "fail"
}

/// 自动化任务单元
public struct AutomationTask: Codable {
    public let action: AutomationActionType
    public let params: AutomationParams?
    public let thought: String? // 模型的思考过程
}

/// 动作参数
public struct AutomationParams: Codable {
    // 鼠标相关 (归一化 0-1)
    public let x: Double?
    public let y: Double?
    public let button: String? // "left", "right", "center"
    public let duration: Int? // ms
    
    // 键盘相关
    public let key: String? // "enter", "space", "a", "cmd", etc.
    public let text: String? // for type/paste action
    
    // 流程相关
    public let prompt: String? // for resubmit action
}

/// VLM 响应结构 (GLM-4V)
public struct VLMTaskResponse: Codable {
    public let thought: String
    public let tasks: [AutomationTask]
}

/// 验证结果响应
public struct ValidationResponse: Codable {
    public let success: Bool
    public let summary: String // 成功时的成果总结，或失败时的原因分析
    public let nextPrompt: String? // 如果失败，下一步的建议 Prompt
}

/// 配置常量
public struct SiliconFlowConfig {
    public static let kimiModel = "moonshotai/Kimi-K2-Instruct-0905"
    public static let glmModel = "zai-org/GLM-4.6V"
    
    // 从环境变量获取 Key，或者使用硬编码的默认值
    public static var apiKey: String {
        return ProcessInfo.processInfo.environment["SILICONFLOW_API_KEY"] ?? "sk-hvmvjwljevimjtluwqjmxcbxkznkopthjjpyzotamnqcympy"
    }
}
