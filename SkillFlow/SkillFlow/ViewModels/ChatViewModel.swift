//
//  ChatViewModel.swift
//  SkillFlow
//
//  Created by Ronggang on 2026/1/1.
//

import Foundation
import SwiftUI
import SwiftData
import Combine

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isProcessing = false
    @Published var currentSkill: Skill?
    @Published var parseProgress: Double = 0
    
    private let apiService = APIService.shared
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadMessages()
    }
    
    private func loadMessages() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Message>(
            sortBy: [SortDescriptor(\.timestamp)]
        )
        
        do {
            messages = try context.fetch(descriptor)
        } catch {
            print("Failed to load messages: \(error)")
        }
    }
    
    // MARK: - Send Message
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(content: inputText, isUser: true)
        addMessage(userMessage)
        
        let userInput = inputText
        inputText = ""
        
        // Check if it's a video URL
        if isVideoURL(userInput) {
            parseVideo(url: userInput)
        } else if userInput.contains("@") {
            // Skill invocation
            handleSkillInvocation(userInput)
        } else {
            // Regular chat
            handleRegularChat(userInput)
        }
    }
    
    private func parseVideo(url: String) {
        isProcessing = true
        parseProgress = 0
        
        let botMessage = Message(content: "正在解析视频...", isUser: false)
        addMessage(botMessage)
        
        // Generate a unique client ID for this session
        let clientID = UUID().uuidString
        
        // Connect to WebSocket for progress updates
        apiService.connectWebSocket(clientID: clientID) { [weak self] progressUpdate in
            guard let self = self else { return }
            
            // Update progress (progress is Int 0-100)
            self.parseProgress = Double(progressUpdate.progress) / 100.0
            self.updateLastMessage("[\(progressUpdate.stage)] \(progressUpdate.message) (\(progressUpdate.progress)%)")
            
            // Check if we received skill data
            if let skillData = progressUpdate.data {
                // Convert SkillData to Skill model
                let skill = self.convertToSkill(skillData)
                self.currentSkill = skill
                self.saveSkill(skill)
                self.updateLastMessage("视频解析完成！技能已生成：\(skill.name)")
                self.isProcessing = false
                self.parseProgress = 1.0
                self.apiService.disconnectWebSocket()
            }
        }
        
        // Start video analysis
        Task {
            do {
                let response = try await apiService.analyzeVideo(videoURL: url, clientID: clientID)
                print("Analysis started: \(response.message)")
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.updateLastMessage("解析失败: \(error.localizedDescription)")
                    self.apiService.disconnectWebSocket()
                }
            }
        }
    }
    
    private func convertToSkill(_ data: SkillData) -> Skill {
        let skill = Skill(
            name: data.name,
            software: data.software,
            description: data.description
        )
        
        skill.tags = data.tags
        skill.totalSteps = data.totalSteps
        
        for stepData in data.steps {
            let step = SkillStep(
                stepId: stepData.stepId,
                actionType: stepData.actionType,
                targetName: stepData.target.name,
                targetType: stepData.target.type,
                instruction: stepData.instruction
            )
            step.confidence = stepData.confidence
            
            // Encode locators to Data
            if let locatorsData = try? JSONEncoder().encode(stepData.target.locators) {
                step.locatorsData = locatorsData
            }
            
            skill.steps.append(step)
        }
        
        return skill
    }
    
    private func handleSkillInvocation(_ input: String) {
        // Extract skill name from @mention
        let components = input.components(separatedBy: "@")
        guard components.count > 1 else {
            addMessage(Message(content: "未找到技能引用", isUser: false))
            return
        }
        
        let skillName = components[1].components(separatedBy: " ").first ?? ""
        
        // Find skill in database
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<Skill>(
            predicate: #Predicate { $0.name.contains(skillName) }
        )
        
        do {
            let skills = try context.fetch(descriptor)
            
            if let skill = skills.first {
                currentSkill = skill
                addMessage(Message(content: "准备执行技能：\(skill.name)", isUser: false))
                
                // Show execution options
                NotificationCenter.default.post(
                    name: .showExecutionOptions,
                    object: nil,
                    userInfo: ["skill": skill]
                )
            } else {
                addMessage(Message(content: "未找到技能：\(skillName)", isUser: false))
            }
        } catch {
            addMessage(Message(content: "查询技能失败: \(error.localizedDescription)", isUser: false))
        }
    }
    
    private func handleRegularChat(_ input: String) {
        // Simple response for now
        let response = generateResponse(for: input)
        addMessage(Message(content: response, isUser: false))
    }
    
    private func generateResponse(for input: String) -> String {
        let lowercased = input.lowercased()
        
        if lowercased.contains("帮助") || lowercased.contains("help") {
            return """
            我可以帮你：
            1. 解析视频教程 - 直接粘贴视频链接
            2. 执行技能 - 使用 @技能名 调用
            3. 管理技能库 - 点击右侧技能库按钮
            """
        } else if lowercased.contains("技能") {
            return "你可以通过粘贴视频链接来创建新技能，或使用 @技能名 来调用已保存的技能。"
        } else {
            return "我是 SkillFlow 助手，可以帮你解析视频教程并执行操作。试试粘贴一个视频链接吧！"
        }
    }
    
    // MARK: - Helper Methods
    
    private func addMessage(_ message: Message) {
        messages.append(message)
        
        if let context = modelContext {
            context.insert(message)
            try? context.save()
        }
    }
    
    private func updateLastMessage(_ content: String) {
        guard let lastMessage = messages.last, !lastMessage.isUser else { return }
        lastMessage.content = content
        
        if let context = modelContext {
            try? context.save()
        }
    }
    
    private func saveSkill(_ skill: Skill) {
        guard let context = modelContext else { return }
        context.insert(skill)
        try? context.save()
    }
    
    private func isVideoURL(_ text: String) -> Bool {
        let patterns = [
            "bilibili.com",
            "youtube.com",
            "youtu.be",
            "douyin.com"
        ]
        
        return patterns.contains { text.contains($0) }
    }
    
    func clearChat() {
        guard let context = modelContext else { return }
        
        for message in messages {
            context.delete(message)
        }
        
        messages.removeAll()
        try? context.save()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let showExecutionOptions = Notification.Name("showExecutionOptions")
}
