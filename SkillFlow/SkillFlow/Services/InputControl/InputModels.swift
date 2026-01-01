//
//  InputModels.swift
//  SkillFlow
//
//  Created by SkillFlow Input Control on 2026/1/2.
//

import Foundation
import CoreGraphics

/// 鼠标按键枚举
public enum MouseButton {
    case left
    case right
    case center
    
    var cgEventTypeDown: CGEventType {
        switch self {
        case .left: return .leftMouseDown
        case .right: return .rightMouseDown
        case .center: return .otherMouseDown
        }
    }
    
    var cgEventTypeUp: CGEventType {
        switch self {
        case .left: return .leftMouseUp
        case .right: return .rightMouseUp
        case .center: return .otherMouseUp
        }
    }
    
    var cgButton: CGMouseButton {
        switch self {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        }
    }
}

/// 键盘按键枚举 (部分常用键映射)
public enum KeyCode: UInt16 {
    // Letters
    case a = 0x00
    case b = 0x0B
    case c = 0x08
    case d = 0x02
    case e = 0x0E
    case f = 0x03
    case g = 0x05
    case h = 0x04
    case i = 0x22
    case j = 0x26
    case k = 0x28
    case l = 0x25
    case m = 0x2E
    case n = 0x2D
    case o = 0x1F
    case p = 0x23
    case q = 0x0C
    case r = 0x0F
    case s = 0x01
    case t = 0x11
    case u = 0x20
    case v = 0x09
    case w = 0x0D
    case x = 0x07
    case y = 0x10
    case z = 0x06
    
    // Numbers
    case one = 0x12
    case two = 0x13
    case three = 0x14
    case four = 0x15
    case five = 0x17
    case six = 0x16
    case seven = 0x1A
    case eight = 0x1C
    case nine = 0x19
    case zero = 0x1D
    
    // Function Keys
    case f1 = 0x7A
    case f2 = 0x78
    case f3 = 0x63
    case f4 = 0x76
    case f5 = 0x60
    case f6 = 0x61
    case f7 = 0x62
    case f8 = 0x64
    case f9 = 0x65
    case f10 = 0x6D
    case f11 = 0x67
    case f12 = 0x6F
    
    // Modifiers & Others
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
    case rightShift = 0x3C
    case rightOption = 0x3D
    case rightControl = 0x3E
    case arrowLeft = 0x7B
    case arrowRight = 0x7C
    case arrowDown = 0x7D
    case arrowUp = 0x7E
}

/// 输入上下文数据模型
public struct InputContext: Sendable {
    /// 当前前台窗口标题
    public let activeWindowTitle: String
    /// 当前鼠标在屏幕上的全局坐标
    public let mousePosition: CGPoint
    /// 捕获时间
    public let timestamp: Date
    
    public init(activeWindowTitle: String, mousePosition: CGPoint, timestamp: Date = Date()) {
        self.activeWindowTitle = activeWindowTitle
        self.mousePosition = mousePosition
        self.timestamp = timestamp
    }
}
