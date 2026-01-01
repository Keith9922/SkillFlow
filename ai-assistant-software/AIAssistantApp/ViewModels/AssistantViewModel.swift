import SwiftUI
import Combine

class AssistantViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var operationSteps: [OperationStep] = []
    @Published var currentStepIndex: Int = 0
    @Published var currentVideo: URL?
    @Published var isProcessing: Bool = false
    @Published var isGuiding: Bool = false
    @Published var isAutomating: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 欢迎消息
        messages.append(ChatMessage(
            content: "你好！我是 AI 助手。上传一段视频，我会分析其中的操作步骤，并帮助你学习或自动执行这些操作。",
            isFromUser: false
        ))
    }
    
    func uploadVideo(url: URL) {
        currentVideo = url
        isProcessing = true
        
        messages.append(ChatMessage(
            content: "正在分析视频中的操作步骤...",
            isFromUser: false
        ))
        
        // 模拟 AI 分析过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.processVideoAnalysis()
        }
    }
    
    private func processVideoAnalysis() {
        // 模拟返回的操作步骤
        operationSteps = [
            OperationStep(
                title: "打开系统偏好设置",
                description: "点击菜单栏 Apple 图标，选择系统偏好设置",
                targetApp: "System Preferences",
                action: .click(CGPoint(x: 20, y: 10))
            ),
            OperationStep(
                title: "进入网络设置",
                description: "在偏好设置中找到并点击「网络」图标",
                targetApp: "System Preferences",
                action: .click(CGPoint(x: 300, y: 200))
            ),
            OperationStep(
                title: "配置代理设置",
                description: "选择高级选项，切换到代理标签页",
                targetApp: "System Preferences",
                action: .click(CGPoint(x: 450, y: 350))
            ),
            OperationStep(
                title: "保存设置",
                description: "点击应用按钮保存更改",
                targetApp: "System Preferences",
                action: .click(CGPoint(x: 500, y: 400))
            )
        ]
        
        isProcessing = false
        
        messages.append(ChatMessage(
            content: "分析完成！我识别出 \(operationSteps.count) 个操作步骤。你可以选择「引导教学」让我一步步指导你，或选择「自动执行」让我帮你完成。",
            isFromUser: false
        ))
    }
    
    func sendMessage(_ content: String) {
        messages.append(ChatMessage(content: content, isFromUser: true))
        
        isProcessing = true
        
        // 模拟 AI 回复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.isProcessing = false
            self?.messages.append(ChatMessage(
                content: "收到！让我来帮你处理这个请求...",
                isFromUser: false
            ))
        }
    }
    
    func startGuidedTour() {
        isGuiding = true
        currentStepIndex = 0
        messages.append(ChatMessage(
            content: "开始引导模式。请按照高亮区域的提示进行操作，我会在旁边指导你。",
            isFromUser: false
        ))
    }
    
    func nextStep() {
        if currentStepIndex < operationSteps.count - 1 {
            currentStepIndex += 1
        } else {
            completeGuide()
        }
    }
    
    func completeGuide() {
        isGuiding = false
        messages.append(ChatMessage(
            content: "太棒了！你已经完成了所有步骤。有任何问题随时问我。",
            isFromUser: false
        ))
    }
    
    func startAutomation() {
        isAutomating = true
        currentStepIndex = 0
        
        messages.append(ChatMessage(
            content: "正在请求系统权限以执行自动化操作...",
            isFromUser: false
        ))
        
        // 这里需要请求辅助功能权限
        requestAccessibilityPermission()
    }
    
    private func requestAccessibilityPermission() {
        // 在实际应用中，这里需要引导用户开启辅助功能权限
        // AXIsProcessTrusted() 检查权限
        // 然后使用 CGEvent 或 AppleScript 执行操作
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.messages.append(ChatMessage(
                content: "请在「系统偏好设置 > 安全性与隐私 > 隐私 > 辅助功能」中授权此应用，以便进行自动化操作。",
                isFromUser: false
            ))
        }
    }
    
    func executeStep(_ step: OperationStep) {
        // 执行具体操作的逻辑
        // 使用 CGEvent 或 AppleScript 模拟用户操作
    }
}
