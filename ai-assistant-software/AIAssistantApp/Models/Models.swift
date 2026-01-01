import SwiftUI

// MARK: - 聊天消息
struct ChatMessage: Identifiable {
    let id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    
    init(content: String, isFromUser: Bool) {
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
    }
}

// MARK: - 操作步骤
struct OperationStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let targetApp: String
    let action: StepAction
    
    // 目标元素的位置（用于高亮显示）
    var targetFrame: CGRect?
}

// MARK: - 操作类型
enum StepAction {
    case click(CGPoint)
    case doubleClick(CGPoint)
    case rightClick(CGPoint)
    case drag(from: CGPoint, to: CGPoint)
    case type(String)
    case shortcut([CGKeyCode])
    case scroll(direction: ScrollDirection, amount: CGFloat)
}

enum ScrollDirection {
    case up, down, left, right
}

// MARK: - 应用状态
enum AppState {
    case idle
    case uploading
    case analyzing
    case guiding
    case automating
}
