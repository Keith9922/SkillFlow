import Foundation
import Cocoa
import ApplicationServices
import Carbon

// MARK: - Enums & Constants

/// 常用按键映射 (Virtual Key Codes)
/// 参考: Carbon.framework/Events.h
enum Key: UInt16, CaseIterable {
    case a = 0x00
    case s = 0x01
    case d = 0x02
    case f = 0x03
    case h = 0x04
    case g = 0x05
    case z = 0x06
    case x = 0x07
    case c = 0x08
    case v = 0x09
    
    case q = 0x0C
    case w = 0x0D
    case e = 0x0E
    case r = 0x0F
    case y = 0x10
    case t = 0x11
    
    case one = 0x12
    case two = 0x13
    case three = 0x14
    case four = 0x15
    case six = 0x16
    case five = 0x17
    case nine = 0x19
    case seven = 0x1A
    case eight = 0x1C
    case zero = 0x1D
    
    case o = 0x1F
    case u = 0x20
    case i = 0x22
    case p = 0x23
    case l = 0x25
    case j = 0x26
    case k = 0x28
    
    case returnKey = 0x24
    case tab = 0x30
    case space = 0x31
    case delete = 0x33
    case escape = 0x35
    
    case command = 0x37
    case shift = 0x38
    case capsLock = 0x39
    case option = 0x3A
    case control = 0x3B
    
    case leftArrow = 0x7B
    case rightArrow = 0x7C
    case downArrow = 0x7D
    case upArrow = 0x7E
}

enum MouseButton {
    case left
    case right
}

// MARK: - Data Models

struct SystemState: Codable {
    let foregroundAppTitle: String
    let foregroundWindowTitle: String
    let mousePosition: CGPoint
}

// MARK: - Input Controller

actor InputController {
    
    // 状态保持
    private var pressedKeys: Set<Key> = []
    private var pressedMouseButtons: Set<MouseButton> = []
    
    // MARK: - Data Retrieval
    
    /// 获取当前系统状态（前台窗口和鼠标位置）
    func getCurrentState() -> SystemState {
        let mouseLoc = CGEvent(source: nil)?.location ?? .zero
        
        var appName = "Unknown"
        var windowTitle = "Unknown"
        
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            appName = frontApp.localizedName ?? "Unknown"
            
            let pid = frontApp.processIdentifier
            let appElement = AXUIElementCreateApplication(pid)
            
            var focusedWindow: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
               let window = focusedWindow {
                
                var title: AnyObject?
                if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success,
                   let titleStr = title as? String {
                    windowTitle = titleStr
                }
            }
        }
        
        return SystemState(
            foregroundAppTitle: appName,
            foregroundWindowTitle: windowTitle,
            mousePosition: mouseLoc
        )
    }
    
    // MARK: - Actions
    
    func move_mouse(to point: CGPoint) async {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.post(tap: .cghidEventTap)
        // 简单的平滑移动由于 CGEvent 是瞬发的，这里直接设置位置。
        // 如果需要轨迹模拟，需要在一个循环中多次调用。
    }
    
    func mouse_down(_ button: MouseButton) async {
        guard let currentLoc = CGEvent(source: nil)?.location else { return }
        
        let type: CGEventType = (button == .left) ? .leftMouseDown : .rightMouseDown
        let cgButton: CGMouseButton = (button == .left) ? .left : .right
        
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: currentLoc, mouseButton: cgButton) else { return }
        event.post(tap: .cghidEventTap)
        
        pressedMouseButtons.insert(button)
    }
    
    func mouse_up(_ button: MouseButton) async {
        guard let currentLoc = CGEvent(source: nil)?.location else { return }
        
        let type: CGEventType = (button == .left) ? .leftMouseUp : .rightMouseUp
        let cgButton: CGMouseButton = (button == .left) ? .left : .right
        
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: currentLoc, mouseButton: cgButton) else { return }
        event.post(tap: .cghidEventTap)
        
        pressedMouseButtons.remove(button)
    }
    
    func key_press(_ key: Key) async {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: true) else { return }
        
        // 必须设置 flags 才能让修饰键生效
        // 这里简化处理，如果按下的是修饰键，CGEvent 通常会自动处理，但明确设置 flag 更好
        // 这是一个简单的实现，不追踪当前所有的 flag 组合，而是依赖 CGEvent 的内部状态或 explicit flags
        
        event.post(tap: .cghidEventTap)
        pressedKeys.insert(key)
    }
    
    func key_release(_ key: Key) async {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: false) else { return }
        event.post(tap: .cghidEventTap)
        pressedKeys.remove(key)
    }
    
    func delay(_ milliseconds: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(milliseconds) * 1_000_000)
    }
    
    /// 释放所有按下的键和鼠标按钮
    func all_release() async {
        for key in pressedKeys {
            await key_release(key)
        }
        // pressedKeys is modified in key_release, but we are iterating a copy or we should be careful.
        // Since we are in an actor, calls are serialized. 
        // Better implementation:
        let keysToRelease = pressedKeys
        for key in keysToRelease {
            await key_release(key)
        }
        
        let buttonsToRelease = pressedMouseButtons
        for button in buttonsToRelease {
            await mouse_up(button)
        }
        
        print("All inputs released.")
    }
}

// MARK: - Main Execution

@main
struct MacInputAgent {
    static func main() async {
        let controller = InputController()
        
        print("=== Mac Input Agent Started ===")
        print("⚠️ 注意: 此程序需要 '辅助功能 (Accessibility)' 权限才能正常工作。")
        print("   请在 系统设置 -> 隐私与安全性 -> 辅助功能 中添加此终端应用 (如 Terminal 或 iTerm)。")
        
        // 打印初始状态
        let initialState = await controller.getCurrentState()
        print("Initial State: \(initialState)")
        
        // 示例执行流程
        print("\n--- 开始执行操作序列 ---")
        
        // 1. 获取屏幕中心
        guard let screen = NSScreen.main else { return }
        let center = CGPoint(x: screen.frame.width / 2, y: screen.frame.height / 2)
        
        // 2. 移动鼠标到中心
        print("Moving mouse to center: \(center)")
        await controller.move_mouse(to: center)
        await controller.delay(500)
        
        // 3. 模拟点击 (选中某物)
        print("Clicking left mouse button...")
        await controller.mouse_down(.left)
        await controller.delay(100)
        await controller.mouse_up(.left)
        await controller.delay(500)
        
        // 4. 模拟组合键: Command + Space (Spotlight)
        print("Pressing Command + Space...")
        await controller.key_press(.command)
        await controller.delay(100)
        await controller.key_press(.space)
        await controller.delay(100)
        await controller.key_release(.space)
        await controller.key_release(.command)
        
        await controller.delay(1000)
        
        // 5. 输入文字 "hello"
        print("Typing 'hello'...")
        let textToType: [Key] = [.h, .e, .l, .l, .o]
        for key in textToType {
            await controller.key_press(key)
            await controller.delay(50)
            await controller.key_release(key)
            await controller.delay(50)
        }
        
        await controller.delay(1000)
        
        // 6. 获取新状态 (此时 Spotlight 应该弹出了)
        let newState = await controller.getCurrentState()
        print("Current State: \(newState)")
        
        // 7. 退出 Spotlight (Escape)
        print("Pressing Escape...")
        await controller.key_press(.escape)
        await controller.key_release(.escape)
        
        // 8. 确保清理所有状态
        await controller.all_release()
        
        print("\n=== Execution Finished ===")
    }
}
