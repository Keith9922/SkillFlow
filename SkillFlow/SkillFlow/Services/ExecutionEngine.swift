//
//  ExecutionEngine.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import AppKit
import ApplicationServices
import Combine

class ExecutionEngine: ObservableObject {
    static let shared = ExecutionEngine()
    
    @Published var isExecuting = false
    @Published var currentStep = 0
    @Published var executionMode: ExecutionMode = .guide
    @Published var executionStatus: ExecutionStatus = .idle
    
    private var currentSkill: Skill?
    private var targetApp: NSRunningApplication?
    private var onStepComplete: ((Int) -> Void)?
    private var onComplete: ((Bool, String?) -> Void)?
    
    private init() {}
    
    // MARK: - Execute Skill
    
    func executeSkill(
        _ skill: Skill,
        mode: ExecutionMode,
        onStepComplete: ((Int) -> Void)? = nil,
        onComplete: @escaping (Bool, String?) -> Void
    ) {
        guard !isExecuting else {
            onComplete(false, "Already executing a skill")
            return
        }
        
        self.currentSkill = skill
        self.executionMode = mode
        self.onStepComplete = onStepComplete
        self.onComplete = onComplete
        self.currentStep = 0
        self.isExecuting = true
        self.executionStatus = .running
        
        // Launch target app
        guard let app = launchTargetApp(software: skill.software) else {
            finishExecution(success: false, error: "Failed to launch \(skill.software)")
            return
        }
        
        self.targetApp = app
        
        // Wait for app to be ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.executeNextStep()
        }
    }
    
    private func executeNextStep() {
        guard let skill = currentSkill, currentStep < skill.steps.count else {
            finishExecution(success: true, error: nil)
            return
        }
        
        let step = skill.steps[currentStep]
        
        switch executionMode {
        case .guide:
            executeGuideStep(step)
        case .auto:
            executeAutoStep(step)
        }
    }
    
    private func executeGuideStep(_ step: SkillStep) {
        // In guide mode, highlight the element and wait for user confirmation
        guard let app = targetApp else {
            finishExecution(success: false, error: "Target app not found")
            return
        }
        
        // Find element
        if let locators = decodeLocators(step.locatorsData) {
            if let element = AccessibilityService.shared.findElement(in: app, matching: locators) {
                // Highlight element (will be handled by GuideOverlayWindow)
                if let position = AccessibilityService.shared.getPosition(element: element),
                   let size = AccessibilityService.shared.getSize(element: element) {
                    NotificationCenter.default.post(
                        name: .highlightElement,
                        object: nil,
                        userInfo: [
                            "position": position,
                            "size": size,
                            "instruction": step.instruction
                        ]
                    )
                }
            }
        }
        
        // Wait for user to proceed (will be triggered by GuideOverlayWindow)
        executionStatus = .waitingForUser
    }
    
    private func executeAutoStep(_ step: SkillStep) {
        guard let app = targetApp else {
            finishExecution(success: false, error: "Target app not found")
            return
        }
        
        // Find element
        guard let locators = decodeLocators(step.locatorsData),
              let element = AccessibilityService.shared.findElement(in: app, matching: locators) else {
            finishExecution(success: false, error: "Failed to find element: \(step.targetName)")
            return
        }
        
        // Perform action
        var success = false
        
        switch step.actionType {
        case "click":
            success = AccessibilityService.shared.click(element: element)
        case "input":
            if let text = locators["input_text"] as? String {
                success = AccessibilityService.shared.input(element: element, text: text)
            }
        case "shortcut":
            if let keys = locators["keys"] as? String {
                success = performShortcut(keys)
            }
        default:
            success = false
        }
        
        if !success {
            finishExecution(success: false, error: "Failed to perform action: \(step.actionType)")
            return
        }
        
        // Wait before next step
        DispatchQueue.main.asyncAfter(deadline: .now() + step.waitAfter) {
            self.onStepComplete?(self.currentStep)
            self.currentStep += 1
            self.executeNextStep()
        }
    }
    
    func proceedToNextStep() {
        guard executionMode == .guide else { return }
        
        onStepComplete?(currentStep)
        currentStep += 1
        executionStatus = .running
        executeNextStep()
    }
    
    func pauseExecution() {
        executionStatus = .paused
    }
    
    func resumeExecution() {
        executionStatus = .running
        executeNextStep()
    }
    
    func stopExecution() {
        finishExecution(success: false, error: "Execution stopped by user")
    }
    
    private func finishExecution(success: Bool, error: String?) {
        isExecuting = false
        executionStatus = success ? .completed : .failed
        
        // Hide highlight
        NotificationCenter.default.post(name: .hideHighlight, object: nil)
        
        onComplete?(success, error)
        
        // Reset state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.executionStatus = .idle
            self.currentStep = 0
            self.currentSkill = nil
            self.targetApp = nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func launchTargetApp(software: String) -> NSRunningApplication? {
        let bundleIds: [String: String] = [
            "Photoshop": "com.adobe.Photoshop",
            "Excel": "com.microsoft.Excel",
            "Chrome": "com.google.Chrome",
            "Safari": "com.apple.Safari",
            "Figma": "com.figma.Desktop"
        ]
        
        guard let bundleId = bundleIds[software] else {
            return nil
        }
        
        return AccessibilityService.shared.launchApp(bundleIdentifier: bundleId)
    }
    
    private func decodeLocators(_ data: Data?) -> [String: Any]? {
        guard let data = data else { return nil }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return json as? [String: Any]
        } catch {
            print("Failed to decode locators: \(error)")
            return nil
        }
    }
    
    private func performShortcut(_ keys: String) -> Bool {
        // Simplified shortcut execution
        // In production, use CGEvent to simulate key presses
        return true
    }
}

// MARK: - Enums

enum ExecutionMode {
    case guide
    case auto
}

enum ExecutionStatus {
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
