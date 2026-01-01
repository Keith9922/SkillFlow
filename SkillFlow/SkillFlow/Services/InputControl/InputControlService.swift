//
//  InputControlService.swift
//  SkillFlow
//
//  Created by SkillFlow Input Control on 2026/1/2.
//

import Foundation
import CoreGraphics
import AppKit
import ApplicationServices

/// 负责底层输入控制的服务
/// 采用 Actor 模型保证状态管理的线程安全
actor InputControlService {
    
    static let shared = InputControlService()
    
    // MARK: - State Tracking
    
    private var pressedKeys: Set<KeyCode> = []
    private var pressedButtons: Set<MouseButton> = []
    
    // MARK: - Input Actions
    
    /// 移动鼠标到指定坐标
    /// - Parameters:
    ///   - x: 全局 X 坐标
    ///   - y: 全局 Y 坐标
    func move_mouse(x: Double, y: Double) {
        let point = CGPoint(x: x, y: y)
        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else {
            print("Failed to create mouse move event")
            return
        }
        event.post(tap: .cghidEventTap)
    }
    
    /// 按下鼠标按键
    /// - Parameter button: 鼠标按键类型 (左/右/中)
    func mouse_down(button: MouseButton) {
        guard let location = CGEvent(source: nil)?.location else { return }
        
        guard let event = CGEvent(mouseEventSource: nil, mouseType: button.cgEventTypeDown, mouseCursorPosition: location, mouseButton: button.cgButton) else {
            print("Failed to create mouse down event")
            return
        }
        
        event.post(tap: .cghidEventTap)
        pressedButtons.insert(button)
    }
    
    /// 释放鼠标按键
    /// - Parameter button: 鼠标按键类型
    func mouse_up(button: MouseButton) {
        guard let location = CGEvent(source: nil)?.location else { return }
        
        guard let event = CGEvent(mouseEventSource: nil, mouseType: button.cgEventTypeUp, mouseCursorPosition: location, mouseButton: button.cgButton) else {
            print("Failed to create mouse up event")
            return
        }
        
        event.post(tap: .cghidEventTap)
        pressedButtons.remove(button)
    }
    
    /// 键盘按键按下
    /// - Parameter key: 键位枚举
    func key_press(key: KeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: key.rawValue, keyDown: true) else {
            print("Failed to create key press event")
            return
        }
        
        event.post(tap: .cghidEventTap)
        pressedKeys.insert(key)
    }
    
    /// 键盘按键释放
    /// - Parameter key: 键位枚举
    func key_release(key: KeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: key.rawValue, keyDown: false) else {
            print("Failed to create key release event")
            return
        }
        
        event.post(tap: .cghidEventTap)
        pressedKeys.remove(key)
    }
    
    /// 异步延迟
    /// - Parameter milliseconds: 毫秒数
    func delay(_ milliseconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
    
    /// 平滑移动鼠标到指定坐标
    /// - Parameters:
    ///   - x: 目标 X 坐标
    ///   - y: 目标 Y 坐标
    ///   - durationMs: 持续时间 (毫秒)
    func smooth_move_mouse(x: Double, y: Double, durationMs: Int) async {
        let startLocation = CGEvent(source: nil)?.location ?? CGPoint(x: 0, y: 0)
        let endLocation = CGPoint(x: x, y: y)
        
        let startTime = Date()
        let duration = Double(durationMs) / 1000.0
        
        // 如果持续时间很短，直接移动
        if duration <= 0.001 {
            move_mouse(x: x, y: y)
            return
        }
        
        while true {
            let now = Date()
            let elapsed = now.timeIntervalSince(startTime)
            
            if elapsed >= duration {
                move_mouse(x: x, y: y)
                break
            }
            
            let progress = elapsed / duration
            // 线性插值
            let currentX = startLocation.x + (endLocation.x - startLocation.x) * progress
            let currentY = startLocation.y + (endLocation.y - startLocation.y) * progress
            
            move_mouse(x: currentX, y: currentY)
            
            // 尝试以 1ms 间隔轮询
            // 注意：系统调度可能无法保证精确的 1ms，但我们会尽可能快地循环
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
    
    /// 释放所有按下的键和鼠标按钮
    func all_release() {
        // 释放鼠标
        let currentButtons = pressedButtons
        for button in currentButtons {
            mouse_up(button: button)
        }
        
        // 释放键盘
        let currentKeys = pressedKeys
        for key in currentKeys {
            key_release(key: key)
        }
        
        // 确保清空 (尽管 mouse_up/key_release 已经做了移除，但为了保险再次清空)
        pressedButtons.removeAll()
        pressedKeys.removeAll()
    }
    
    /// 粘贴文本 (通过剪贴板 + Cmd+V)
    /// - Parameter text: 要粘贴的文本
    @MainActor
    func paste_text(_ text: String) async {
        // 1. 设置剪贴板
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 2. 模拟 Cmd + V
        await key_press(key: .command)
        await delay(50) // 短暂延迟确保修饰键生效
        await key_press(key: .v)
        await delay(50)
        await key_release(key: .v)
        await key_release(key: .command)
    }
    
    // MARK: - Data Model Retrieval
    
    /// 获取当前输入上下文 (前台窗口标题和鼠标位置)
    /// - Returns: InputContext
    func getCurrentContext() -> InputContext {
        let mousePos = CGEvent(source: nil)?.location ?? .zero
        let title = getActiveWindowTitle()
        
        return InputContext(activeWindowTitle: title, mousePosition: mousePos)
    }
    
    // MARK: - Private Helpers
    
    private func getActiveWindowTitle() -> String {
        // 1. 获取前台应用
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return "No Active Application"
        }
        
        // 2. 创建 Accessibility Element
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        
        // 3. 获取焦点窗口
        var focusedWindow: AnyObject?
        let resultWindow = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        guard resultWindow == .success, let windowElement = focusedWindow else {
            return "No Focused Window (Check Accessibility Permissions)"
        }
        
        // 4. 获取窗口标题
        var title: AnyObject?
        let resultTitle = AXUIElementCopyAttributeValue(windowElement as! AXUIElement, kAXTitleAttribute as CFString, &title)
        
        if resultTitle == .success, let titleStr = title as? String {
            return titleStr
        }
        
        return "Unknown Title"
    }
}
