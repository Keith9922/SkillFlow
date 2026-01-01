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
    
    private let executionEngine = ExecutionEngine.shared
    private var currentSkill: Skill?
    
    init() {
        // Observe execution engine changes
        executionEngine.$isExecuting
            .assign(to: &$isExecuting)
        
        executionEngine.$currentStep
            .assign(to: &$currentStep)
        
        executionEngine.$executionStatus
            .assign(to: &$executionStatus)
        
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
    
    // MARK: - Execute Skill
    
    func executeSkill(_ skill: Skill, mode: ExecutionMode) {
        self.currentSkill = skill
        self.totalSteps = skill.steps.count
        self.executionMode = mode
        self.errorMessage = nil
        
        executionEngine.executeSkill(
            skill,
            mode: mode,
            onStepComplete: { [weak self] step in
                self?.onStepComplete(step)
            },
            onComplete: { [weak self] success, error in
                self?.onExecutionComplete(success: success, error: error)
            }
        )
    }
    
    func proceedToNextStep() {
        executionEngine.proceedToNextStep()
    }
    
    func pauseExecution() {
        executionEngine.pauseExecution()
    }
    
    func resumeExecution() {
        executionEngine.resumeExecution()
    }
    
    func stopExecution() {
        executionEngine.stopExecution()
    }
    
    // MARK: - Callbacks
    
    private func onStepComplete(_ step: Int) {
        // Update UI or log
        print("Step \(step + 1) completed")
    }
    
    private func onExecutionComplete(success: Bool, error: String?) {
        if success {
            print("Execution completed successfully")
        } else {
            errorMessage = error ?? "Unknown error"
            print("Execution failed: \(errorMessage ?? "")")
        }
    }
    
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
