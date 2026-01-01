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
    @Published var currentStage: ParseStage = .idle
    @Published var stageDetails: [StageDetail] = []
    @Published var errorMessage: String?
    
    private var modelContext: ModelContext?
    private var currentEntryId: String?
    private let videoProcessor = VideoProcessingService()
    private let s3Service = S3Service()
    
    // MARK: - Initialization
    
    init() {
        initializeStageDetails()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadMessages()
        
        // Listen for skill insertion notification
        NotificationCenter.default.addObserver(
            forName: .insertSkillReference,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            // Extract data from notification safely
            let userInfo = notification.userInfo
            
            Task { @MainActor in
                guard let skill = userInfo?["skill"] as? Skill else { return }
                self.insertSkillReference(skill)
            }
        }
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Stage Management
    
    private func initializeStageDetails() {
        stageDetails = [
            StageDetail(stage: .downloading, status: .pending, title: "下载视频", icon: "arrow.down.circle"),
            StageDetail(stage: .extractingAudio, status: .pending, title: "提取音频", icon: "waveform"),
            StageDetail(stage: .uploading, status: .pending, title: "上传文件", icon: "arrow.up.circle"),
            StageDetail(stage: .creatingTask, status: .pending, title: "创建任务", icon: "doc.badge.plus"),
            StageDetail(stage: .audioProcessing, status: .pending, title: "音频转录", icon: "text.bubble"),
            StageDetail(stage: .videoProcessing, status: .pending, title: "视频分析", icon: "video"),
            StageDetail(stage: .stepsGenerating, status: .pending, title: "生成步骤", icon: "list.bullet"),
            StageDetail(stage: .completed, status: .pending, title: "完成", icon: "checkmark.circle")
        ]
    }
    
    private func updateStage(_ stage: ParseStage, progress: Double, message: String? = nil) {
        currentStage = stage
        parseProgress = progress
        
        // Update stage details
        if let index = stageDetails.firstIndex(where: { $0.stage == stage }) {
            stageDetails[index].status = .inProgress
            
            // Mark previous stages as completed
            for i in 0..<index {
                if stageDetails[i].status != .failed {
                    stageDetails[i].status = .completed
                }
            }
        }
        
        // Update message if provided
        if let message = message {
            updateLastMessage(message)
        }
    }
    
    // MARK: - Message Handling
    
    private var currentTask: Task<Void, Never>?
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let input = inputText
        inputText = ""
        
        // Add user message
        let userMessage = Message(content: input, isUser: true)
        addMessage(userMessage)
        
        // Check for skill invocation
        if input.contains("[SKILL:") || input.contains("@") {
            handleSkillInvocation(input)
        } else {
            handleRegularChat(input)
        }
    }
    
    func stopProcessing() {
        currentTask?.cancel()
        currentTask = nil
        isProcessing = false
        // Optionally add a system message indicating cancellation
        // let msg = Message(content: "🛑 操作已取消", isUser: false)
        // addMessage(msg)
    }
    
    func clearContext() {
        messages.removeAll()
        try? modelContext?.delete(model: Message.self) // Clear from DB if needed, or just memory
        // Re-save context to persist deletion if using SwiftData for persistence
        try? modelContext?.save()
        errorMessage = nil
        isProcessing = false
        stageDetails = []
        parseProgress = 0
    }
    
    private func handleRegularChat(_ input: String) {
        // Show "thinking" state
        isProcessing = true
        
        // Add a placeholder bot message
        let botMessage = Message(content: "...", isUser: false)
        let tempId = botMessage.id
        addMessage(botMessage)
        
        currentTask = Task {
            await AssistantService.shared.handleUserMessage(text: input, history: messages) { [weak self] responseText, isComplete in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if Task.isCancelled { return }
                    
                    // Find and update the placeholder message
                    if let index = self.messages.firstIndex(where: { $0.id == tempId }) {
                        self.messages[index].content = responseText
                        try? self.modelContext?.save()
                    }
                    
                    if isComplete {
                        self.isProcessing = false
                        self.currentTask = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Skill Invocation
    
    private func insertSkillReference(_ skill: Skill) {
        // Append [SKILL: Skill Name] to input text
        // This format avoids issues with spaces in skill names
        if inputText.isEmpty {
            inputText = "[SKILL: \(skill.name)]"
        } else {
            inputText += " [SKILL: \(skill.name)]"
        }
    }
    
    private func handleSkillInvocation(_ input: String) {
        // Extract skill name from input using regex for [SKILL: Name]
        // This allows skill names to contain spaces
        var skillName: String?
        
        // Regex to match [SKILL: <Anything>]
        let pattern = "\\[SKILL:\\s*(.*?)\\]"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = input as NSString
            let results = regex.matches(in: input, options: [], range: NSRange(location: 0, length: nsString.length))
            
            if let match = results.first, match.numberOfRanges > 1 {
                skillName = nsString.substring(with: match.range(at: 1))
            }
        }
        
        // Fallback to legacy @ parsing if new format not found
        if skillName == nil {
            let components = input.components(separatedBy: " ")
            for component in components {
                if component.hasPrefix("@") {
                    skillName = String(component.dropFirst())
                    break
                }
            }
        }
        
        guard let name = skillName, !name.isEmpty else {
            handleRegularChat(input)
            return
        }
        
        // Find skill in DB
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Skill>(
            predicate: #Predicate<Skill> { $0.name == name }
        )
        
        do {
            let skills = try context.fetch(descriptor)
            if let skill = skills.first {
                // Found skill, "execute" it (Show skill card)
                currentSkill = skill
                
                // Add bot message
                let response = Message(content: "正在调用技能: \(skill.name)", isUser: false)
                // Optionally attach skill data to message
                if let packageData = skill.packageData {
                    response.skillData = packageData // Store raw package data or customized card data
                }
                let tempId = response.id
                addMessage(response)
                
                // Execute Skill using AssistantService (VLM driven)
                isProcessing = true
                Task {
                    do {
                        try await AssistantService.shared.executeSkillWithVLM(
                            skill: skill,
                            onProgress: { [weak self] status in
                                Task { @MainActor in
                                    guard let self = self else { return }
                                    // Append new message for progress
                                    let progressMsg = Message(content: status, isUser: false)
                                    self.addMessage(progressMsg)
                                }
                            },
                            onComplete: { [weak self] summary in
                                Task { @MainActor in
                                    guard let self = self else { return }
                                    // Append final summary
                                    let summaryMsg = Message(content: summary, isUser: false)
                                    self.addMessage(summaryMsg)
                                    self.isProcessing = false
                                }
                            }
                        )
                    } catch {
                        Task { @MainActor in
                            guard let self = self else { return }
                            let errorMsg = Message(content: "❌ 技能执行失败: \(error.localizedDescription)", isUser: false)
                            self.addMessage(errorMsg)
                            self.isProcessing = false
                        }
                    }
                }
                
            } else {
                addMessage(Message(content: "❌ 未找到技能: \(name)", isUser: false))
            }
        } catch {
            print("Error fetching skill: \(error)")
            addMessage(Message(content: "❌ 技能查找出错", isUser: false))
        }
    }
    
    // MARK: - Process Local Video
    
    func processLocalVideo(url: URL) {
        // Add user message
        let userMessage = Message(content: "上传视频: \(url.lastPathComponent)", isUser: true)
        addMessage(userMessage)
        
        isProcessing = true
        parseProgress = 0
        errorMessage = nil
        initializeStageDetails()
        
        let botMessage = Message(content: "正在处理本地视频...", isUser: false)
        addMessage(botMessage)
        
        // Security Scoped Resource Handling
        // 必须在主线程开启访问权限，并传递给异步任务
        // 注意：startAccessingSecurityScopedResource 必须成对调用 stopAccessingSecurityScopedResource
        let isAccessing = url.startAccessingSecurityScopedResource()
        
        Task {
            // 使用 defer 确保在 Task 结束时释放权限
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                // Update stage: Extracting Audio/Video
                await MainActor.run {
                    updateStage(.extractingAudio, progress: 0.1, message: "正在拆分音频与视频轨道...")
                }
                
                // Perform Split
                let (videoURL, audioURL) = try await videoProcessor.splitVideo(url: url)
                
                print("Video split completed:")
                print("Video: \(videoURL.path)")
                print("Audio: \(audioURL.path)")
                
                await MainActor.run {
                    updateStage(.extractingAudio, progress: 0.3, message: "拆分完成，准备上传文件...")
                }
                
                // Upload to S3
                await MainActor.run {
                    updateStage(.uploading, progress: 0.4, message: "正在上传视频与音频到云端...")
                }
                
                // 使用同一个 uploadId 作为文件夹，方便在 S3 中查看
                let uploadId = UUID().uuidString
                print("[Upload] Starting upload batch with ID: \(uploadId)")
                
                async let videoUpload = s3Service.upload(fileURL: videoURL, contentType: "video/mp4", folder: uploadId)
                async let audioUpload = s3Service.upload(fileURL: audioURL, contentType: "audio/wav", folder: uploadId)
                
                let (videoPublicURL, audioPublicURL) = try await (videoUpload, audioUpload)
                
                print("Upload completed:")
                print("Video: \(videoPublicURL)")
                print("Audio: \(audioPublicURL)")
                
                await MainActor.run {
                    updateStage(.uploading, progress: 0.5, message: "上传完成")
                }
                
                // Start Remote Analysis
                await startRemoteAnalysis(videoURL: videoPublicURL, audioURL: audioPublicURL)
                
            } catch {
                print("Video processing failed: \(error)")
                await MainActor.run {
                    errorMessage = "处理失败: \(error.localizedDescription)"
                    updateStage(.failed, progress: 0, message: "失败: \(error.localizedDescription)")
                    
                    // Update bot message
                    updateLastMessage("❌ 处理失败: \(error.localizedDescription)")
                    isProcessing = false
                }
            }
        }
    }
    
    // MARK: - Remote Analysis Logic
    
    private func startRemoteAnalysis(videoURL: String, audioURL: String) async {
        do {
            // 1. Create Task
            await MainActor.run {
                updateStage(.creatingTask, progress: 0.55, message: "正在创建云端任务...")
            }
            
            let entryId = try await APIService.shared.createTask()
            print("[Task] Created entryId: \(entryId)")
            
            // 2. Parse Audio
            await MainActor.run {
                updateStage(.audioProcessing, progress: 0.6, message: "正在提交音频解析...")
            }
            
            try await APIService.shared.parseAudio(entryId: entryId, audioUrl: audioURL)
            
            // Poll for Audio Status: Wait for "audio_done"
            // 注意：checkStatus 只是返回状态，真正的数据在 artifact 接口
            _ = try await pollForStatus(entryId: entryId, targetStatus: "audio_done")
            
            // Get Audio Artifact
            let audioArtifact = try await APIService.shared.getArtifact(entryId: entryId, track: "audio")
            // 修正字段名：从 "text" 改为 "data"
            guard let transcript = audioArtifact["data"] as? String else {
                // 如果没有 data 字段，尝试打印整个 artifact 以排查
                print("[Task] Audio Artifact: \(audioArtifact)")
                throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "音频转录结果为空"])
            }
            
            print("[Task] Audio Transcript: \(transcript.prefix(50))...")
            
            // 3. Parse Video
            await MainActor.run {
                updateStage(.videoProcessing, progress: 0.75, message: "正在提交视频分析...")
            }
            
            try await APIService.shared.parseVideo(entryId: entryId, videoUrl: videoURL, transcriptText: transcript)
            
            // Poll for Video Status: Wait for "video_done"
            _ = try await pollForStatus(entryId: entryId, targetStatus: "video_done")
            
            // Get Video Artifact (This contains the final steps data now)
            let videoArtifact = try await APIService.shared.getArtifact(entryId: entryId, track: "video")
            print("[Task] Video Artifact retrieved")
            
            // 5. Completion (Skip steps generation phase)
            await MainActor.run {
                updateStage(.completed, progress: 1.0, message: "所有处理完成！")
                
                let resultMessage = """
                ✅ 处理完成
                
                任务 ID: \(entryId)
                
                📝 转录摘要:
                \(transcript.prefix(100))...
                
                (详细步骤已生成)
                """
                updateLastMessage(resultMessage)
                isProcessing = false
                
                print("Video Artifact: \(videoArtifact)")

                // Handle generated steps from video artifact
                // Note: The structure is inside "data" -> { ... } which matches the schema
                if let stepsData = videoArtifact["data"] as? [String: Any],
                   let stepsArray = stepsData["steps"] as? [[String: Any]] {
                    
                    // Create Skill
                    let skillName = (stepsData["name"] as? String) ?? "New Skill"
                    let skillDesc = (stepsData["description"] as? String) ?? "Generated from video analysis"
                    let software = (stepsData["software"] as? String) ?? "Unknown"
                    
                    let newSkill = Skill(
                        name: skillName,
                        software: software,
                        description: skillDesc,
                        sourceType: .videoAnalysis,
                        steps: []
                    )
                    
                    // Parse Steps
                    for stepDict in stepsArray {
                        let instruction = (stepDict["instruction"] as? String) ?? ""
                        let actionTypeStr = (stepDict["action_type"] as? String) ?? "click"
                        let targetDict = stepDict["target"] as? [String: Any]
                        let targetName = (targetDict?["name"] as? String) ?? ""
                        let targetTypeStr = (targetDict?["type"] as? String) ?? "button"
                        
                        // Parse Locators
                        var locators: [Locator] = []
                        if let locatorsArray = targetDict?["locators"] as? [[String: Any]] {
                            for locDict in locatorsArray {
                                if let methodRaw = locDict["method"] as? String,
                                   let value = locDict["value"] as? String,
                                   let method = LocatorMethod(rawValue: methodRaw) {
                                    locators.append(Locator(method: method, value: AnyCodable(value), priority: (locDict["priority"] as? Int) ?? 1))
                                }
                            }
                        }
                        
                        _ = Target(
                            targetType: TargetType(rawValue: targetTypeStr) ?? .button,
                            name: targetName,
                            locators: locators
                        )
                        
                        let step = SkillStep(
                            stepId: (stepDict["step_id"] as? Int) ?? 0,
                            actionType: ActionType(rawValue: actionTypeStr) ?? .click,
                            targetName: targetName,
                            targetType: TargetType(rawValue: targetTypeStr) ?? .button,
                            instruction: instruction,
                            waitAfter: (stepDict["wait_after"] as? Double) ?? 0.0,
                            confidence: (stepDict["confidence"] as? Double) ?? 1.0
                        )
                        
                        newSkill.steps.append(step)
                    }
                    
                    // Save to Database
                    if let context = modelContext {
                        context.insert(newSkill)
                        try? context.save()
                        print("Skill saved: \(newSkill.name) with \(newSkill.steps.count) steps")
                        
                        // Set current skill to show card
                        currentSkill = newSkill
                    }
                } else {
                    print("Failed to parse video artifact data")
                }
            }
            
        } catch {
            print("Remote analysis failed: \(error)")
            await MainActor.run {
                errorMessage = "分析失败: \(error.localizedDescription)"
                updateStage(.failed, progress: 0, message: "分析失败: \(error.localizedDescription)")
                updateLastMessage("❌ 分析失败: \(error.localizedDescription)")
                isProcessing = false
            }
        }
    }
    
    /// 轮询直到 status 字段变为 targetStatus
    private func pollForStatus(entryId: String, targetStatus: String) async throws -> [String: Any] {
        let maxRetries = 100 // 100 times * 2s = ~3.3 minutes max
        
        for i in 0..<maxRetries {
            // Check Status
            let result = try await APIService.shared.checkStatus(entryId: entryId)
            
            // Print status for debugging
            print("[Poll] Status Check (\(i)): \(result)")
            
            if let status = result["status"] as? String {
                if status == targetStatus {
                    return result
                } else if ["failed", "error"].contains(status.lowercased()) {
                    throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "任务失败: \(status)"])
                }
            }
            
            // Wait before next poll
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        throw NSError(domain: "ChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "操作超时: 等待 \(targetStatus)"])
    }
    
    private func parseVideo(url: String) {
        isProcessing = true
        parseProgress = 0
        errorMessage = nil
        initializeStageDetails()
        
        let botMessage = Message(content: "正在解析视频... (逻辑已移除)", isUser: false)
        addMessage(botMessage)
        
        // Mock completion
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            isProcessing = false
            let successMessage = Message(content: "✅ 模拟解析完成 (UI 演示)", isUser: false)
            addMessage(successMessage)
        }
    }
    
    func retryParsing() {
        print("Retry parsing (Logic removed)")
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
    static let authenticationRequired = Notification.Name("authenticationRequired")
}
