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
        let maxSteps = 5 // 防止无限循环
        
        while stepCount < maxSteps {
            stepCount += 1
            
            // 1. 截图
            guard let screenData = await ScreenCaptureService.shared.captureMainScreen() else {
                throw NSError(domain: "AssistantService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法截取屏幕"])
            }
            
            onProgress("📸 [步骤 \(stepCount)] 屏幕已截取，正在规划动作...")
            
            // 2. 调用 GLM-4V 生成任务
            let vlmResponse = try await APIService.shared.executeVLMTask(intent: currentIntent, imageData: screenData)
            
            onProgress("🧠 [步骤 \(stepCount)] 思考: \(vlmResponse.thought)\n⚡️ 开始执行动作...")
            
            // 3. 执行任务
            let inputService = InputControlService.shared
            var shouldResubmit = false
            var nextPrompt: String?
            
            for (index, task) in vlmResponse.tasks.enumerated() {
                onProgress("▶️ [步骤 \(stepCount)] 执行 \(index + 1)/\(vlmResponse.tasks.count): \(task.action.rawValue)")
                
                switch task.action {
                case .moveMouse:
                    if let x = task.params?.x, let y = task.params?.y {
                        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
                        let pixelX = x * screenFrame.width
                        let pixelY = y * screenFrame.height
                        
                        let duration = task.params?.duration ?? 500
                        await inputService.smooth_move_mouse(x: pixelX, y: pixelY, durationMs: duration)
                    }
                    
                case .click:
                    let buttonStr = task.params?.button ?? "left"
                    let button: MouseButton = (buttonStr == "right") ? .right : .left
                    await inputService.mouse_down(button: button)
                    await inputService.delay(100) // 点击持续时间
                    await inputService.mouse_up(button: button)
                    
                case .mouseDown:
                    let buttonStr = task.params?.button ?? "left"
                    let button: MouseButton = (buttonStr == "right") ? .right : .left
                    await inputService.mouse_down(button: button)
                    
                case .mouseUp:
                    let buttonStr = task.params?.button ?? "left"
                    let button: MouseButton = (buttonStr == "right") ? .right : .left
                    await inputService.mouse_up(button: button)
                    
                case .keyPress:
                    if let keyStr = task.params?.key, let key = mapKey(keyStr) {
                        await inputService.key_press(key: key)
                    }
                    
                case .keyRelease:
                    if let keyStr = task.params?.key, let key = mapKey(keyStr) {
                        await inputService.key_release(key: key)
                    }
                    
                case .type:
                    // Legacy support: if model still outputs type, fallback to paste if text is present
                    if let text = task.params?.text {
                        await inputService.paste_text(text)
                    }
                    
                case .pasteText:
                    if let text = task.params?.text {
                        await inputService.paste_text(text)
                    }
                    
                case .delay:
                    let ms = task.params?.duration ?? 500
                    await inputService.delay(ms)
                    
                case .allRelease:
                    await inputService.all_release()
                    
                case .resubmit:
                    shouldResubmit = true
                    nextPrompt = task.params?.prompt
                    // 遇到 resubmit 后，执行完当前循环的其他任务吗？
                    // 通常 resubmit 应该是最后一个动作，但如果有其他动作，也先执行完比较安全
                    
                case .finish:
                    // 原先是直接 return，现在改为 break 跳出循环，进入下方的验证流程
                    // onProgress("🎉 任务标记完成")
                    // return
                    break // Break switch, then loop continues to next task or finishes
                    
                case .fail:
                    throw NSError(domain: "AssistantService", code: -1, userInfo: [NSLocalizedDescriptionKey: "模型反馈无法完成任务"])
                }
                
                // 步骤间默认延迟
                await inputService.delay(200)
                
                // 如果遇到 finish，就不再执行后续任务了，直接跳出任务循环进入验证
                if task.action == .finish {
                    break
                }
            }
            
            await inputService.all_release()
            
            // 检查是否需要重新提交
            if shouldResubmit {
                if let prompt = nextPrompt {
                    currentIntent = prompt
                    onProgress("🔄 任务未完成，进入下一阶段: \(prompt)")
                    // 稍微等待页面刷新
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                } else {
                    // Resubmit but no prompt? Fallback to original intent or stop
                    onProgress("⚠️ 要求重试但未提供新提示，停止。")
                    return
                }
            } else {
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
