//
//  AssistantService.swift
//  SkillFlow
//
//  Created by SkillFlow Automation on 2026/1/2.
//

import Foundation
import SwiftUI

/// 智能助手服务：协调 Chat, Kimi (意图识别), 和 GLM-4V (视觉操作)
class AssistantService {
    static let shared = AssistantService()
    
    private init() {}
    
    /// 处理用户消息
    /// - Parameters:
    ///   - text: 用户输入的文本
    ///   - history: 聊天历史
    ///   - onResponse: 回调函数，用于流式或分步返回消息给 UI
    func handleUserMessage(text: String, history: [Message], onResponse: @escaping (String, Bool) -> Void) async {
        do {
            // 1. 调用 Kimi 进行对话和意图探测
            let kimiResponse = try await APIService.shared.chatWithKimi(userMessage: text, history: history)
            
            // 2. 检查是否有操作意图
            if let intent = extractAutomationIntent(from: kimiResponse) {
                // 通知用户正在准备操作
                onResponse("🤖 识别到操作意图：\(intent)\n正在分析屏幕...", false)
                
                // 3. 执行自动化流程
                try await performAutomation(intent: intent, onProgress: { status in
                    onResponse(status, false)
                }, onComplete: { summary in
                    onResponse("✅ \(summary)", true)
                })
                
            } else {
                // 普通对话，直接返回
                onResponse(kimiResponse, true)
            }
            
        } catch {
            print("Assistant Error: \(error)")
            onResponse("❌ 发生错误: \(error.localizedDescription)", true)
        }
    }
    
    // MARK: - Automation Flow
    
    /// 执行自动化流程（支持递归调用 resubmit）
    private func performAutomation(intent: String, onProgress: @escaping (String) -> Void, onComplete: @escaping (String) -> Void) async throws {
        var currentIntent = intent
        var stepCount = 0
        let maxSteps = 20 // 防止无限循环
        
        while stepCount < maxSteps {
            stepCount += 1
            
            // 1. 截图
            guard let screenData = await ScreenCaptureService.shared.captureMainScreen() else {
                throw NSError(domain: "AssistantService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法截取屏幕"])
            }
            
            onProgress("📸 [步骤 \(stepCount)] 屏幕已截取，正在规划动作...")
            
            // 2. 调用 GLM-4V 生成任务
            let vlmResponse = try await APIService.shared.executeVLMTask(intent: currentIntent, imageData: screenData)
            
            // 3. 汇报思考过程
            onProgress("🧠 [思考] \(vlmResponse.thought)")
            
            // 4. 执行任务
            try await executeVLMTasks(vlmResponse.tasks, onProgress: onProgress)
            
            // 5. 验证与后续处理 (Task Loop Logic)
            // 检查是否需要重新提交
            // 注意：executeVLMTasks 不会返回 shouldResubmit，我们需要检查 tasks 中的最后一个动作
            // 或者我们可以让 executeVLMTasks 返回一个状态，但为了简单，我们在 executeVLMTasks 内部处理了 resubmit 的执行
            // 这里我们需要检查 vlmResponse.tasks 是否包含 resubmit 或 finish
            
            var shouldResubmit = false
            var nextPrompt: String?
            
            if let lastTask = vlmResponse.tasks.last {
                if lastTask.action == .resubmit {
                    shouldResubmit = true
                    nextPrompt = lastTask.params?.prompt
                } else if lastTask.action == .finish {
                    break // 跳出循环进行验证
                }
            }
            
            if shouldResubmit {
                if let prompt = nextPrompt {
                    currentIntent = prompt
                    onProgress("🔄 [系统] 任务未完成，进入下一阶段: \(prompt)")
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                } else {
                    onProgress("⚠️ [系统] 要求重试但未提供新提示，停止。")
                    return
                }
            } else {
                // 如果没有显式的 finish 或 resubmit，通常也应该验证一下
                // 但如果模型只是执行了一部分，可能不需要验证？
                // 默认策略：如果不是 resubmit，就进行验证

                // 3.5 验证阶段 (Validation)
                // 截图并验证
                guard let validationScreen = await ScreenCaptureService.shared.captureMainScreen() else {
                    onProgress("⚠️ 无法截取屏幕进行验证，假定完成。")
                    return
                }
                
                onProgress("🔍 正在验证操作结果...")
                let validation = try await APIService.shared.validateTaskOutcome(originalGoal: intent, imageData: validationScreen)
                
                if validation.success {
                    onProgress("✅ 验证通过: \(validation.summary)")
                    onComplete(validation.summary)
                    return
                } else {
                    // 验证失败，尝试重试
                    if let newPrompt = validation.nextPrompt {
                        currentIntent = newPrompt
                        onProgress("❌ 验证未通过: \(validation.summary)\n🔄 尝试修正: \(newPrompt)")
                        try await Task.sleep(nanoseconds: 1_000_000_000)
                        continue
                    } else {
                        onProgress("❌ 验证未通过: \(validation.summary)\n⚠️ 无更多修正建议，停止。")
                        onComplete("操作部分完成或失败: \(validation.summary)")
                        return
                    }
                }
            }
        }
        
        throw NSError(domain: "AssistantService", code: -1, userInfo: [NSLocalizedDescriptionKey: "达到最大步骤限制 (\(maxSteps))，停止执行"])
    }
    
    // MARK: - Skill Execution
    
    /// 执行预定义的技能 (VLM 驱动)
    /// - Parameters:
    ///   - skill: 要执行的技能
    ///   - onProgress: 进度回调
    ///   - onComplete: 完成回调
    func executeSkillWithVLM(skill: Skill, onProgress: @escaping (String) -> Void, onComplete: @escaping (String) -> Void) async throws {
        
        onProgress("🚀 开始执行技能: \(skill.name)\n包含 \(skill.steps.count) 个步骤")
        
        let sortedSteps = skill.steps.sorted { $0.stepId < $1.stepId }
        
        for (index, step) in sortedSteps.enumerated() {
            onProgress("📍 [步骤 \(index + 1)/\(sortedSteps.count)] \(step.instruction)")
            
            // 1. 截图
            guard let screenData = await ScreenCaptureService.shared.captureMainScreen() else {
                throw NSError(domain: "AssistantService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法截取屏幕"])
            }
            
            // 2. 调用 VLM 确认操作细节
            onProgress("👀 正在分析屏幕以定位目标: \(step.targetName)...")
            let vlmResponse = try await APIService.shared.executeSkillStepWithVLM(step: step, imageData: screenData)
            
            // 3. 汇报思考
            onProgress("🧠 [思考] \(vlmResponse.thought)")
            
            // 4. 执行 VLM 生成的具体操作
            try await executeVLMTasks(vlmResponse.tasks, onProgress: onProgress)
            
            // 5. 验证当前步骤 (Validate)
            onProgress("🔍 验证步骤 \(index + 1) 结果...")
            // 验证时使用当前步骤的 instruction 作为 goal
            guard let validationScreen = await ScreenCaptureService.shared.captureMainScreen() else { continue }
            
            let validation = try await APIService.shared.validateTaskOutcome(originalGoal: step.instruction, imageData: validationScreen)
            
            if validation.success {
                onProgress("✅ 步骤 \(index + 1) 验证通过")
            } else {
                // 如果验证失败，尝试重试一次 (简单逻辑：用 validation 的建议重试)
                if let nextPrompt = validation.nextPrompt {
                    onProgress("⚠️ 步骤验证失败: \(validation.summary)\n🔄 尝试修正: \(nextPrompt)")
                    
                    // 构造一个临时的 SkillStep 进行重试
                    // 这里的逻辑可以更复杂，比如递归调用 VLM，这里简化为单次修正
                    try await performAutomation(intent: nextPrompt, onProgress: onProgress, onComplete: { _ in })
                } else {
                    throw NSError(domain: "AssistantService", code: -1, userInfo: [NSLocalizedDescriptionKey: "步骤 \(index + 1) 执行失败且无法修正: \(validation.summary)"])
                }
            }
            
            // 步骤间延迟
            if step.waitAfter > 0 {
                onProgress("⏳ 等待 \(step.waitAfter) 秒...")
                try await Task.sleep(nanoseconds: UInt64(step.waitAfter * 1_000_000_000))
            }
        }
        
        onComplete("🎉 技能 \(skill.name) 执行完成！")
    }
    
    // 提取公共的 Task 执行逻辑
    private func executeVLMTasks(_ tasks: [AutomationTask], onProgress: @escaping (String) -> Void) async throws {
        let inputService = InputControlService.shared
        
        for (index, task) in tasks.enumerated() {
            // 汇报当前动作
            onProgress("▶️ [操作] 执行动作 \(index + 1)/\(tasks.count): \(task.action.rawValue)")
            
            switch task.action {
            case .moveMouse:
                if let x = task.params?.x, let y = task.params?.y {
                    let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
                    let pixelX = x * screenFrame.width
                    let pixelY = y * screenFrame.height
                    let duration = task.params?.duration ?? 500
                    await inputService.smooth_move_mouse(x: pixelX, y: pixelY, durationMs: duration)
                }
                
            case .click, .mouseDown, .mouseUp:
                // 检查参数中是否有坐标，如果有则先移动
                if let x = task.params?.x, let y = task.params?.y {
                    let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
                    let pixelX = x * screenFrame.width
                    let pixelY = y * screenFrame.height
                    // 移动前先确保没有按键残留
                    // await inputService.all_release() 
                    await inputService.smooth_move_mouse(x: pixelX, y: pixelY, durationMs: 500)
                    await inputService.delay(100)
                }
                
                let buttonStr = task.params?.button ?? "left"
                let button: MouseButton = (buttonStr == "right") ? .right : .left
                
                if task.action == .click {
                    await inputService.mouse_down(button: button)
                    await inputService.delay(100)
                    await inputService.mouse_up(button: button)
                } else if task.action == .mouseDown {
                    await inputService.mouse_down(button: button)
                } else if task.action == .mouseUp {
                    await inputService.mouse_up(button: button)
                }
                
            case .keyPress:
                if let keyStr = task.params?.key, let key = mapKey(keyStr) {
                    await inputService.key_press(key: key)
                }
            case .keyRelease:
                if let keyStr = task.params?.key, let key = mapKey(keyStr) {
                    await inputService.key_release(key: key)
                }
            case .type, .pasteText:
                if let text = task.params?.text {
                    await inputService.paste_text(text)
                }
            case .delay:
                let ms = task.params?.duration ?? 500
                await inputService.delay(ms)
            case .allRelease:
                await inputService.all_release()
            case .resubmit, .finish:
                break // Flow handled by caller
            case .fail:
                throw NSError(domain: "AssistantService", code: -1, userInfo: [NSLocalizedDescriptionKey: "模型反馈无法完成步骤"])
            }
            
            await inputService.delay(200)
        }
        await inputService.all_release()
    }

    // MARK: - Helpers
    
    /// 解析 Kimi 返回的 [OPERATE: ...] 标记
    private func extractAutomationIntent(from response: String) -> String? {
        let pattern = #"\[OPERATE:\s*(.*?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        
        let nsString = response as NSString
        let results = regex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = results.first {
            return nsString.substring(with: match.range(at: 1))
        }
        
        return nil
    }
    
    private func mapKey(_ keyName: String) -> KeyCode? {
        switch keyName.lowercased() {
        case "enter", "return": return .returnKey
        case "space": return .space
        case "escape", "esc": return .escape
        case "cmd", "command": return .command
        case "shift": return .shift
        case "opt", "option", "alt": return .option
        case "ctrl", "control": return .control
        case "tab": return .tab
        case "backspace", "delete": return .delete
        case "a": return .a
        case "b": return .b
        case "c": return .c
        // ... add more as needed
        default: return nil
        }
    }
}
