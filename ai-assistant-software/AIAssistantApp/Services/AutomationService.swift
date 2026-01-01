import SwiftUI
import ApplicationServices

// MARK: - 自动化服务（用于控制电脑操作）
class AutomationService {
    static let shared = AutomationService()
    
    private init() {}
    
    // 检查辅助功能权限
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    // 模拟鼠标点击
    func click(at point: CGPoint) {
        guard checkAccessibilityPermission() else { return }
        
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    // 模拟双击
    func doubleClick(at point: CGPoint) {
        guard checkAccessibilityPermission() else { return }
        
        click(at: point)
        click(at: point)
    }
    
    // 模拟右键点击
    func rightClick(at point: CGPoint) {
        guard checkAccessibilityPermission() else { return }
        
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right)
        
        mouseDown?.post(tap: .cghidEventTap)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    // 模拟拖拽
    func drag(from startPoint: CGPoint, to endPoint: CGPoint) {
        guard checkAccessibilityPermission() else { return }
        
        let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: startPoint, mouseButton: .left)
        let mouseDrag = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: endPoint, mouseButton: .left)
        let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: endPoint, mouseButton: .left)
        
        mouseDown?.post(tap: .cghidEventTap)
        usleep(100000)
        mouseDrag?.post(tap: .cghidEventTap)
        usleep(100000)
        mouseUp?.post(tap: .cghidEventTap)
    }
    
    // 模拟键盘输入
    func type(text: String) {
        guard checkAccessibilityPermission() else { return }
        
        for character in text {
            let keyCode = keyCodeForCharacter(character)
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            usleep(50000)
        }
    }
    
    // 获取窗口位置（用于定位操作目标）
    func getWindowFrame(for appName: String) -> CGRect? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        for window in windowList {
            if let owner = window[kCGWindowOwnerName as String] as? String,
               owner.contains(appName),
               let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                return CGRect(
                    x: bounds["X"] ?? 0,
                    y: bounds["Y"] ?? 0,
                    width: bounds["Width"] ?? 0,
                    height: bounds["Height"] ?? 0
                )
            }
        }
        
        return nil
    }
    
    private func keyCodeForCharacter(_ character: Character) -> CGKeyCode {
        // 简化的键码映射，实际应用中需要完整映射
        let keyMap: [Character: CGKeyCode] = [
            "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5,
            "h": 4, "i": 34, "j": 38, "k": 40, "l": 37, "m": 46, "n": 45,
            "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32,
            "v": 9, "w": 13, "x": 7, "y": 16, "z": 6, " ": 49
        ]
        return keyMap[Character(character.lowercased())] ?? 0
    }
}
