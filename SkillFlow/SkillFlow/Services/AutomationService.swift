//
//  AutomationService.swift
//  SkillFlow
//
//  Created by SkillFlow Automation on 2026/1/1.
//

import Foundation
import CoreGraphics
import AppKit

class AutomationService {
    static let shared = AutomationService()
    
    private init() {}
    
    // MARK: - Core Actions
    
    /// 执行鼠标点击
    /// - Parameters:
    ///   - normalizedPoint: 归一化坐标 (Vision 坐标系: 0,0 在左下)
    ///   - doubleClick: 是否双击
    func click(at normalizedPoint: CGPoint, doubleClick: Bool = false) {
        let screenPoint = normalizedToScreen(normalizedPoint)
        
        postMouseEvent(type: .leftMouseDown, position: screenPoint)
        postMouseEvent(type: .leftMouseUp, position: screenPoint)
        
        if doubleClick {
            usleep(50000) // 50ms 间隔
            postMouseEvent(type: .leftMouseDown, position: screenPoint)
            postMouseEvent(type: .leftMouseUp, position: screenPoint)
        }
    }
    
    /// 执行右键点击
    func rightClick(at normalizedPoint: CGPoint) {
        let screenPoint = normalizedToScreen(normalizedPoint)
        postMouseEvent(type: .rightMouseDown, position: screenPoint)
        postMouseEvent(type: .rightMouseUp, position: screenPoint)
    }
    
    /// 模拟键盘输入
    /// - Parameter text: 要输入的文本
    func typeText(_ text: String) {
        // 使用 CGEventKeyboardSetUnicodeString
        // 注意：这种方式不触发快捷键，主要用于文本输入
        // 对于快捷键，需要使用 key code
        
        let eventSource = CGEventSource(stateID: .hidSystemState)
        
        for char in text.utf16 {
            // 创建一个占位的 keydown 事件
            guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: true) else { continue }
            
            // 设置实际的 unicode 字符
            var charCode = char
            event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &charCode)
            event.post(tap: .cghidEventTap)
            
            // Key up
            guard let upEvent = CGEvent(keyboardEventSource: eventSource, virtualKey: 0, keyDown: false) else { continue }
            upEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: &charCode)
            upEvent.post(tap: .cghidEventTap)
            
            usleep(10000) // 10ms 延迟
        }
    }
    
    /// 模拟滚动
    /// - Parameters:
    ///   - dx: 水平滚动量
    ///   - dy: 垂直滚动量
    func scroll(dx: Int, dy: Int) {
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: Int32(dy), wheel2: Int32(dx), wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }
    
    // MARK: - Helper Methods
    
    /// 将 Vision 归一化坐标转换为屏幕坐标
    /// Vision: (0,0) 在左下，(1,1) 在右上
    /// Screen: (0,0) 在左上，(Width, Height) 在右下
    private func normalizedToScreen(_ point: CGPoint) -> CGPoint {
        let mainScreen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        
        // 1. Vision Y 轴翻转: Vision Y (0 at bottom) -> Screen Y (0 at top)
        // ScreenY = (1 - VisionY) * Height
        let screenX = point.x * mainScreen.width
        let screenY = (1.0 - point.y) * mainScreen.height
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    private func postMouseEvent(type: CGEventType, position: CGPoint) {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: position, mouseButton: .left) else { return }
        event.post(tap: .cghidEventTap)
    }
}
