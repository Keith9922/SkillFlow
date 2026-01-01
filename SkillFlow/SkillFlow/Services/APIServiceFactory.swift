//
//  APIServiceFactory.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import Foundation

/// API 服务工厂，根据配置创建对应的服务
class APIServiceFactory {
    static let shared = APIServiceFactory()
    
    private let config = APIConfiguration.shared
    
    private init() {}
    
    // MARK: - Service Creation
    
    /// 创建 ChatViewModel，根据当前配置使用对应的 API
    func createChatViewModel() -> ChatViewModel {
        switch config.currentVersion {
        case .seedo:
            return createSEEDOChatViewModel()
        case .legacy:
            return createLegacyChatViewModel()
        }
    }
    
    /// 创建使用 SEEDO API 的 ChatViewModel
    private func createSEEDOChatViewModel() -> ChatViewModel {
        let tokenManager = TokenManager.shared
        let apiService = SEEDOAPIService(
            baseURL: config.seedoBaseURL,
            tokenManager: tokenManager
        )
        let pollingManager = PollingManager(apiService: apiService)
        let s3Uploader = S3Uploader(
            bucket: config.s3Bucket,
            region: config.s3Region
        )
        let videoDownloader = VideoDownloader()
        let dataConverter = DataConverter()
        
        return ChatViewModel(
            apiService: apiService,
            pollingManager: pollingManager,
            s3Uploader: s3Uploader,
            videoDownloader: videoDownloader,
            tokenManager: tokenManager,
            dataConverter: dataConverter
        )
    }
    
    /// 创建使用旧版 API 的 ChatViewModel
    /// 注意：这个方法返回的 ChatViewModel 会使用旧的 WebSocket 逻辑
    private func createLegacyChatViewModel() -> ChatViewModel {
        // 为了向后兼容，我们仍然创建 SEEDO 版本的 ViewModel
        // 但是可以在内部检测配置并使用不同的逻辑
        // 这里暂时返回 SEEDO 版本，实际使用时需要根据配置切换逻辑
        return createSEEDOChatViewModel()
    }
    
    /// 创建 TaskListViewModel
    func createTaskListViewModel() -> TaskListViewModel {
        if config.isUsingSEEDO {
            let tokenManager = TokenManager.shared
            let apiService = SEEDOAPIService(
                baseURL: config.seedoBaseURL,
                tokenManager: tokenManager
            )
            let dataConverter = DataConverter()
            
            return TaskListViewModel(
                apiService: apiService,
                dataConverter: dataConverter
            )
        } else {
            // 旧版 API 不支持任务列表
            // 返回一个空的 ViewModel
            return TaskListViewModel()
        }
    }
}
