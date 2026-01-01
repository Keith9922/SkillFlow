//
//  PollingManager.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//  轮询管理器 - 管理任务状态轮询逻辑
//

import Foundation

@MainActor
class PollingManager {
    // MARK: - Properties
    private let apiService: SEEDOAPIService
    private let dataConverter: DataConverter
    private let pollingInterval: TimeInterval
    private let maxAttempts: Int
    
    // MARK: - Initialization
    init(
        apiService: SEEDOAPIService = .shared,
        dataConverter: DataConverter = .shared,
        pollingInterval: TimeInterval = 2.0,
        maxAttempts: Int = 300 // 10 分钟 (300 * 2秒)
    ) {
        self.apiService = apiService
        self.dataConverter = dataConverter
        self.pollingInterval = pollingInterval
        self.maxAttempts = maxAttempts
    }
    
    // MARK: - Generic Polling Method
    
    /// 轮询直到达到目标状态
    /// - Parameters:
    ///   - entryId: 任务 ID
    ///   - targetStatus: 目标状态
    ///   - onProgress: 进度回调
    /// - Returns: 最终状态
    func pollUntil(
        entryId: String,
        targetStatus: TaskStatus,
        onProgress: @escaping (TaskStatus, Int) -> Void
    ) async throws -> TaskStatus {
        var attempts = 0
        
        while attempts < maxAttempts {
            attempts += 1
            
            // 查询状态
            let currentStatus = try await apiService.getTaskStatus(entryId: entryId)
            
            // 回调进度
            onProgress(currentStatus, attempts)
            
            // 检查是否达到目标状态
            if currentStatus == targetStatus {
                return currentStatus
            }
            
            // 检查是否失败
            if currentStatus == .failed {
                throw SEEDOError.taskCreationFailed("任务失败")
            }
            
            // 等待后继续轮询
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }
        
        // 超时
        throw SEEDOError.pollingTimeout
    }
    
    // MARK: - Audio Polling
    
    /// 轮询音频完成
    /// - Parameters:
    ///   - entryId: 任务 ID
    ///   - onProgress: 进度回调
    /// - Returns: 转录文本
    func pollForAudio(
        entryId: String,
        onProgress: @escaping (TaskStatus, Int) -> Void
    ) async throws -> String {
        // 轮询直到 audio_done
        let finalStatus = try await pollUntil(
            entryId: entryId,
            targetStatus: .audioDone,
            onProgress: onProgress
        )
        
        guard finalStatus == .audioDone else {
            throw SEEDOError.audioParseFailed("音频解析未完成")
        }
        
        // 获取音频结果
        let artifact = try await apiService.getArtifact(
            entryId: entryId,
            track: .audio
        )
        
        // 转换数据
        let transcriptText = try dataConverter.convertAudioArtifact(artifact)
        
        return transcriptText
    }
    
    // MARK: - Video Polling
    
    /// 轮询视频完成
    /// - Parameters:
    ///   - entryId: 任务 ID
    ///   - onProgress: 进度回调
    /// - Returns: 视频分析数据
    func pollForVideo(
        entryId: String,
        onProgress: @escaping (TaskStatus, Int) -> Void
    ) async throws -> VideoAnalysisData {
        // 轮询直到 video_done
        let finalStatus = try await pollUntil(
            entryId: entryId,
            targetStatus: .videoDone,
            onProgress: onProgress
        )
        
        guard finalStatus == .videoDone else {
            throw SEEDOError.videoParseFailed("视频分析未完成")
        }
        
        // 获取视频结果
        let artifact = try await apiService.getArtifact(
            entryId: entryId,
            track: .video
        )
        
        // 转换数据
        let videoAnalysis = try dataConverter.convertVideoArtifact(artifact)
        
        return videoAnalysis
    }
    
    // MARK: - Steps Polling
    
    /// 轮询步骤完成
    /// - Parameters:
    ///   - entryId: 任务 ID
    ///   - onProgress: 进度回调
    /// - Returns: Skill 模型
    func pollForSteps(
        entryId: String,
        onProgress: @escaping (TaskStatus, Int) -> Void
    ) async throws -> Skill {
        // 轮询直到 finished
        let finalStatus = try await pollUntil(
            entryId: entryId,
            targetStatus: .finished,
            onProgress: onProgress
        )
        
        guard finalStatus == .finished else {
            throw SEEDOError.stepGenerationFailed("步骤生成未完成")
        }
        
        // 获取步骤结果
        let artifact = try await apiService.getArtifact(
            entryId: entryId,
            track: .steps
        )
        
        // 转换数据
        let skill = try dataConverter.convertStepsArtifact(artifact)
        
        return skill
    }
    
    // MARK: - Combined Polling (完整流程)
    
    /// 完整的轮询流程：音频 → 视频 → 步骤
    /// - Parameters:
    ///   - entryId: 任务 ID
    ///   - onAudioProgress: 音频进度回调
    ///   - onVideoProgress: 视频进度回调
    ///   - onStepsProgress: 步骤进度回调
    /// - Returns: (转录文本, 视频分析, 技能)
    func pollComplete(
        entryId: String,
        onAudioProgress: @escaping (TaskStatus, Int) -> Void,
        onVideoProgress: @escaping (TaskStatus, Int) -> Void,
        onStepsProgress: @escaping (TaskStatus, Int) -> Void
    ) async throws -> (String, VideoAnalysisData, Skill) {
        // 1. 轮询音频
        let transcriptText = try await pollForAudio(
            entryId: entryId,
            onProgress: onAudioProgress
        )
        
        // 2. 轮询视频
        let videoAnalysis = try await pollForVideo(
            entryId: entryId,
            onProgress: onVideoProgress
        )
        
        // 3. 轮询步骤
        let skill = try await pollForSteps(
            entryId: entryId,
            onProgress: onStepsProgress
        )
        
        return (transcriptText, videoAnalysis, skill)
    }
    
    // MARK: - Helper Methods
    
    /// 取消轮询（通过 Task 取消机制）
    func cancelPolling() {
        // 由于使用 async/await，可以通过 Task.cancel() 取消
        // 这个方法主要用于文档说明
    }
    
    /// 计算预估剩余时间
    /// - Parameters:
    ///   - attempts: 当前尝试次数
    ///   - maxAttempts: 最大尝试次数
    /// - Returns: 预估剩余秒数
    func estimatedTimeRemaining(attempts: Int, maxAttempts: Int) -> TimeInterval {
        let remainingAttempts = max(0, maxAttempts - attempts)
        return Double(remainingAttempts) * pollingInterval
    }
}
