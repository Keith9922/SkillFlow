//
//  ExecutionViewModel.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ExecutionViewModel: ObservableObject {
    @Published var isExecuting = false
    @Published var currentStep = 0
    @Published var totalSteps = 0
    @Published var executionMode: ExecutionMode = .guide
    @Published var executionStatus: ExecutionStatus = .idle
    @Published var currentInstruction = ""
    @Published var highlightRect: CGRect?
    @Published var errorMessage: String?
    
    private var currentSkill: Skill?
    
    init() {
        // Listen for highlight notifications
        NotificationCenter.default.addObserver(
            forName: .highlightElement,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleHighlight(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: .hideHighlight,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.highlightRect = nil
            self?.currentInstruction = ""
        }
    }
    
    // MARK: - VLM Automation
    
    /// 开始 VLM 驱动的自动化任务
    /// - Parameter goal: 任务目标
    func startVLMAutomation(goal: String) {
        guard !isExecuting else { return }
        
        // 1. 检查权限
        guard ScreenCaptureService.shared.checkScreenRecordingPermission() else {
            errorMessage = "Please grant Screen Recording permission in System Settings."
            ScreenCaptureService.shared.requestScreenRecordingPermission()
            return
        }
        
        // 初始化状态
        isExecuting = true
        executionStatus = .running
        executionMode = .auto
        currentInstruction = "Initializing VLM Automation..."
        errorMessage = nil
        
        Task {
            // 注意：新的架构下，AssistantService 负责整个流程
            // 这里我们只是作为一个 UI 状态的代理
            
            await AssistantService.shared.handleUserMessage(text: goal, history: []) { [weak self] status, isComplete in
                Task { @MainActor in
                    self?.currentInstruction = status
                    
                    if isComplete {
                        self?.stopExecution()
                    }
                }
            }
        }
    }
    
    // (runVLMLoop 已被废弃，由 AssistantService 接管)

    // MARK: - Execute Skill
    
    func executeSkill(_ skill: Skill, mode: ExecutionMode) {
        self.currentSkill = skill
        self.totalSteps = skill.steps.count
        self.executionMode = mode
        self.errorMessage = nil
        
        self.isExecuting = true
        self.executionStatus = .running
        
        print("Execute skill: \(skill.name) in \(mode) mode (Logic removed)")
    }
    
    func proceedToNextStep() {
        if currentStep < totalSteps {
            currentStep += 1
            print("Proceed to step \(currentStep)")
        } else {
            executionStatus = .completed
            isExecuting = false
            print("Execution completed")
        }
    }
    
    func pauseExecution() {
        executionStatus = .paused
    }
    
    func resumeExecution() {
        executionStatus = .running
    }
    
    func stopExecution() {
        executionStatus = .idle
        isExecuting = false
        currentStep = 0
        highlightRect = nil
    }
    
    // MARK: - Callbacks
    
    private func handleHighlight(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let position = userInfo["position"] as? CGPoint,
              let size = userInfo["size"] as? CGSize,
              let instruction = userInfo["instruction"] as? String else {
            return
        }
        
        highlightRect = CGRect(origin: position, size: size)
        currentInstruction = instruction
    }
    
    // MARK: - Computed Properties
    
    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStep) / Double(totalSteps)
    }
    
    var progressText: String {
        "\(currentStep)/\(totalSteps)"
    }
    
    var canProceed: Bool {
        executionMode == .guide && executionStatus == .waitingForUser
    }
    
    var canPause: Bool {
        isExecuting && executionStatus == .running
    }
    
    var canResume: Bool {
        isExecuting && executionStatus == .paused
    }
}

// MARK: - Enums

enum ExecutionMode: String {
    case guide
    case auto
}

enum ExecutionStatus: String {
    case idle
    case running
    case paused
    case waitingForUser
    case completed
    case failed
}

// MARK: - Notifications

extension Notification.Name {
    static let highlightElement = Notification.Name("highlightElement")
    static let hideHighlight = Notification.Name("hideHighlight")
}
