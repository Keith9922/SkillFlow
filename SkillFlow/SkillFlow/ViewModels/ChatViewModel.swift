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
    
    // MARK: - Dependencies
    private let apiService: SEEDOAPIService
    private let pollingManager: PollingManager
    private let s3Uploader: S3Uploader
    private let videoDownloader: VideoDownloader
    private let tokenManager: TokenManager
    private let dataConverter: DataConverter
    
    private var modelContext: ModelContext?
    private var currentEntryId: String?
    
    // MARK: - Initialization
    
    init(
        apiService: SEEDOAPIService? = nil,
        pollingManager: PollingManager? = nil,
        s3Uploader: S3Uploader? = nil,
        videoDownloader: VideoDownloader? = nil,
        tokenManager: TokenManager? = nil,
        dataConverter: DataConverter? = nil
    ) {
        // Use provided dependencies or create defaults
        let tokenMgr = tokenManager ?? TokenManager.shared
        let apiSvc = apiService ?? SEEDOAPIService(
            baseURL: "https://api.seedo.example.com",
            tokenManager: tokenMgr
        )
        
        self.tokenManager = tokenMgr
        self.apiService = apiSvc
        self.pollingManager = pollingManager ?? PollingManager(apiService: apiSvc)
        self.s3Uploader = s3Uploader ?? S3Uploader(
            bucket: "skillflow-videos",
            region: "us-west-2"
        )
        self.videoDownloader = videoDownloader ?? VideoDownloader()
        self.dataConverter = dataConverter ?? DataConverter()
        
        initializeStageDetails()
    }
    
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
    
    private func markStageCompleted(_ stage: ParseStage) {
        if let index = stageDetails.firstIndex(where: { $0.stage == stage }) {
            stageDetails[index].status = .completed
        }
    }
    
    private func markStageFailed(_ stage: ParseStage, error: String) {
        if let index = stageDetails.firstIndex(where: { $0.stage == stage }) {
            stageDetails[index].status = .failed
        }
        errorMessage = error
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
        errorMessage = nil
        initializeStageDetails()
        
        let botMessage = Message(content: "正在解析视频...", isUser: false)
        addMessage(botMessage)
        
        Task {
            do {
                // Step 1: Download video
                updateStage(.downloading, progress: 0, message: "正在下载视频...")
                let videoPath = try await videoDownloader.download(url: url) { progress in
                    Task { @MainActor in
                        self.updateStage(.downloading, progress: progress * 15, message: "下载中 \(Int(progress * 100))%")
                    }
                }
                markStageCompleted(.downloading)
                
                // Step 2: Extract audio
                updateStage(.extractingAudio, progress: 15, message: "正在提取音频...")
                let audioPath = try await videoDownloader.extractAudio(from: videoPath)
                markStageCompleted(.extractingAudio)
                
                // Step 3: Upload to S3
                updateStage(.uploading, progress: 20, message: "正在上传文件...")
                let dirLocation = "skillflow/\(UUID().uuidString)/"
                
                let videoData = try Data(contentsOf: videoPath)
                let audioData = try Data(contentsOf: audioPath)
                
                _ = try await s3Uploader.upload(
                    data: videoData,
                    key: "\(dirLocation)video.mp4",
                    contentType: "video/mp4"
                ) { progress in
                    Task { @MainActor in
                        self.updateStage(.uploading, progress: 20 + progress * 5, message: "上传视频 \(Int(progress * 100))%")
                    }
                }
                
                _ = try await s3Uploader.upload(
                    data: audioData,
                    key: "\(dirLocation)audio.wav",
                    contentType: "audio/wav"
                ) { progress in
                    Task { @MainActor in
                        self.updateStage(.uploading, progress: 25 + progress * 5, message: "上传音频 \(Int(progress * 100))%")
                    }
                }
                markStageCompleted(.uploading)
                
                // Step 4: Create task
                updateStage(.creatingTask, progress: 30, message: "正在创建任务...")
                let entryId = try await apiService.createTask(dirLocation: dirLocation)
                currentEntryId = entryId
                markStageCompleted(.creatingTask)
                
                // Step 5: Parse audio
                updateStage(.audioProcessing, progress: 35, message: "正在提交音频解析...")
                try await apiService.parseAudio(entryId: entryId, dirLocation: dirLocation)
                
                updateStage(.audioProcessing, progress: 40, message: "正在等待音频转录...")
                let transcriptText = try await pollForAudio(entryId: entryId)
                markStageCompleted(.audioProcessing)
                
                // Step 6: Parse video
                updateStage(.videoProcessing, progress: 55, message: "正在提交视频分析...")
                try await apiService.parseVideo(
                    entryId: entryId,
                    dirLocation: dirLocation,
                    transcriptText: transcriptText
                )
                
                updateStage(.videoProcessing, progress: 60, message: "正在等待视频分析...")
                _ = try await pollForVideo(entryId: entryId)
                markStageCompleted(.videoProcessing)
                
                // Step 7: Generate steps
                updateStage(.stepsGenerating, progress: 80, message: "正在生成操作步骤...")
                let skill = try await pollForSteps(entryId: entryId)
                markStageCompleted(.stepsGenerating)
                
                // Step 8: Complete
                updateStage(.completed, progress: 100, message: "视频解析完成！技能已生成：\(skill.name)")
                markStageCompleted(.completed)
                
                currentSkill = skill
                saveSkill(skill)
                
                isProcessing = false
                
                // Clean up temporary files
                try? FileManager.default.removeItem(at: videoPath)
                try? FileManager.default.removeItem(at: audioPath)
                
            } catch {
                await handleParseError(error)
            }
        }
    }
    
    // MARK: - Polling Methods
    
    private func pollForAudio(entryId: String) async throws -> String {
        return try await pollingManager.pollForAudio(entryId: entryId) { status in
            Task { @MainActor in
                let progressValue = 40 + self.calculateStatusProgress(status) * 15
                self.updateStage(.audioProcessing, progress: progressValue, message: "音频转录中... (\(status.rawValue))")
            }
        }
    }
    
    private func pollForVideo(entryId: String) async throws -> VideoAnalysisData {
        return try await pollingManager.pollForVideo(entryId: entryId) { status in
            Task { @MainActor in
                let progressValue = 60 + self.calculateStatusProgress(status) * 20
                self.updateStage(.videoProcessing, progress: progressValue, message: "视频分析中... (\(status.rawValue))")
            }
        }
    }
    
    private func pollForSteps(entryId: String) async throws -> Skill {
        return try await pollingManager.pollForSteps(entryId: entryId) { status in
            Task { @MainActor in
                let progressValue = 80 + self.calculateStatusProgress(status) * 20
                self.updateStage(.stepsGenerating, progress: progressValue, message: "生成步骤中... (\(status.rawValue))")
            }
        }
    }
    
    private func calculateStatusProgress(_ status: TaskStatus) -> Double {
        // Simple progress estimation based on status
        switch status {
        case .processing:
            return 0.5
        case .audioDone, .videoDone, .finished:
            return 1.0
        case .failed:
            return 0.0
        }
    }
    
    // MARK: - Error Handling
    
    private func handleParseError(_ error: Error) async {
        isProcessing = false
        
        let errorMsg: String
        if let seedoError = error as? SEEDOError {
            errorMsg = seedoError.localizedDescription
            
            // Mark the appropriate stage as failed
            switch seedoError {
            case .uploadFailed:
                markStageFailed(.uploading, error: errorMsg)
            case .taskCreationFailed:
                markStageFailed(.creatingTask, error: errorMsg)
            case .audioParseFailed:
                markStageFailed(.audioProcessing, error: errorMsg)
            case .videoParseFailed:
                markStageFailed(.videoProcessing, error: errorMsg)
            case .stepGenerationFailed:
                markStageFailed(.stepsGenerating, error: errorMsg)
            case .pollingTimeout:
                markStageFailed(currentStage, error: errorMsg)
            case .authenticationFailed, .tokenExpired:
                markStageFailed(currentStage, error: errorMsg)
                // Prompt user to re-login
                NotificationCenter.default.post(name: .authenticationRequired, object: nil)
            default:
                markStageFailed(currentStage, error: errorMsg)
            }
        } else {
            errorMsg = "解析失败: \(error.localizedDescription)"
            markStageFailed(currentStage, error: errorMsg)
        }
        
        updateLastMessage(errorMsg)
        currentStage = .failed
    }
    
    func retryParsing() {
        guard let lastVideoURL = messages.last(where: { isVideoURL($0.content) })?.content else {
            return
        }
        parseVideo(url: lastVideoURL)
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
    static let authenticationRequired = Notification.Name("authenticationRequired")
}
