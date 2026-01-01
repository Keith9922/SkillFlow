//
//  LegacyAPIAdapter.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import Foundation

/// 旧版 API 适配器，用于保持向后兼容
/// 这个类包装了旧的 APIService，使其可以与新的架构一起工作
class LegacyAPIAdapter {
    private let legacyService: APIService
    
    init(baseURL: String) {
        // 注意：这里假设旧的 APIService 仍然存在
        // 实际使用时需要确保旧代码没有被删除
        self.legacyService = APIService.shared
    }
    
    // MARK: - Legacy Methods
    
    /// 使用旧版 WebSocket API 解析视频
    func analyzeVideoLegacy(
        videoURL: String,
        clientID: String,
        onProgress: @escaping (ProgressUpdate) -> Void
    ) async throws -> AnalysisResponse {
        // 连接 WebSocket
        legacyService.connectWebSocket(clientID: clientID, onProgress: onProgress)
        
        // 调用旧的分析接口
        let response = try await legacyService.analyzeVideo(
            videoURL: videoURL,
            clientID: clientID
        )
        
        return response
    }
    
    /// 断开 WebSocket 连接
    func disconnectWebSocket() {
        legacyService.disconnectWebSocket()
    }
}

/// 进度更新数据结构（旧版）
struct ProgressUpdate {
    let stage: String
    let message: String
    let progress: Int
    let data: SkillData?
}

/// 分析响应数据结构（旧版）
struct AnalysisResponse {
    let message: String
    let clientID: String
}

/// 技能数据结构（旧版）
struct SkillData: Codable {
    let name: String
    let software: String
    let description: String
    let tags: [String]
    let totalSteps: Int
    let steps: [StepData]
}

/// 步骤数据结构（旧版）
struct StepData: Codable {
    let stepId: Int
    let actionType: String
    let target: TargetData
    let instruction: String
    let confidence: Double
}

/// 目标数据结构（旧版）
struct TargetData: Codable {
    let name: String
    let type: String
    let locators: [String: String]
}
