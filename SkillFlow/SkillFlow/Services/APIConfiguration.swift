//
//  APIConfiguration.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import Foundation
import Combine

/// API 版本枚举
enum APIVersion: String, Codable, CaseIterable {
    case legacy = "legacy"  // 旧的 WebSocket API
    case seedo = "seedo"    // 新的 SEEDO 轮询 API
    
    var displayName: String {
        switch self {
        case .legacy:
            return "旧版 API (WebSocket)"
        case .seedo:
            return "SEEDO API (轮询)"
        }
    }
    
    var description: String {
        switch self {
        case .legacy:
            return "使用 WebSocket 实时推送进度，适用于旧版后端"
        case .seedo:
            return "使用任务轮询机制，支持 S3 上传和分阶段处理"
        }
    }
}

/// API 配置管理器
class APIConfiguration: ObservableObject {
    static let shared = APIConfiguration()
    
    // MARK: - Properties
    
    @Published var currentVersion: APIVersion {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var seedoBaseURL: String {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var legacyBaseURL: String {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var s3Bucket: String {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var s3Region: String {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var s3Endpoint: String {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var s3AccessKey: String {
        didSet {
            saveConfiguration()
        }
    }
    
    @Published var s3SecretKey: String {
        didSet {
            saveConfiguration()
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private let versionKey = "api.version"
    private let seedoBaseURLKey = "api.seedo.baseURL"
    private let legacyBaseURLKey = "api.legacy.baseURL"
    private let s3BucketKey = "api.s3.bucket"
    private let s3RegionKey = "api.s3.region"
    private let s3EndpointKey = "api.s3.endpoint"
    private let s3AccessKeyKey = "api.s3.accessKey"
    private let s3SecretKeyKey = "api.s3.secretKey"
    
    // MARK: - Initialization
    
    private init() {
        // Load saved configuration or use defaults
        if let savedVersion = UserDefaults.standard.string(forKey: versionKey),
           let version = APIVersion(rawValue: savedVersion) {
            self.currentVersion = version
        } else {
            // Default to SEEDO API for new installations
            self.currentVersion = .seedo
        }
        
        self.seedoBaseURL = UserDefaults.standard.string(forKey: seedoBaseURLKey) 
            ?? "https://api.sf.smart-teach.cn"
        self.legacyBaseURL = UserDefaults.standard.string(forKey: legacyBaseURLKey) 
            ?? "https://api.sf.smart-teach.cn"
        self.s3Bucket = UserDefaults.standard.string(forKey: s3BucketKey) 
            ?? "skillflow"
        self.s3Region = UserDefaults.standard.string(forKey: s3RegionKey) 
            ?? "cn-nb1"
        self.s3Endpoint = UserDefaults.standard.string(forKey: s3EndpointKey) 
            ?? "https://cn-nb1.rains3.com"
        self.s3AccessKey = UserDefaults.standard.string(forKey: s3AccessKeyKey) 
            ?? "HNZpHzoyiMuT9qA3"
        self.s3SecretKey = UserDefaults.standard.string(forKey: s3SecretKeyKey) 
            ?? "NUa9JAKto0OOaBYANgUkCsYO4bY54t"
    }
    
    // MARK: - Configuration Management
    
    /// 保存配置到 UserDefaults
    private func saveConfiguration() {
        UserDefaults.standard.set(currentVersion.rawValue, forKey: versionKey)
        UserDefaults.standard.set(seedoBaseURL, forKey: seedoBaseURLKey)
        UserDefaults.standard.set(legacyBaseURL, forKey: legacyBaseURLKey)
        UserDefaults.standard.set(s3Bucket, forKey: s3BucketKey)
        UserDefaults.standard.set(s3Region, forKey: s3RegionKey)
        UserDefaults.standard.set(s3Endpoint, forKey: s3EndpointKey)
        UserDefaults.standard.set(s3AccessKey, forKey: s3AccessKeyKey)
        UserDefaults.standard.set(s3SecretKey, forKey: s3SecretKeyKey)
    }
    
    /// 切换到指定版本
    func switchToVersion(_ version: APIVersion) {
        currentVersion = version
        
        // 发送通知，让相关组件重新初始化
        NotificationCenter.default.post(
            name: .apiVersionChanged,
            object: nil,
            userInfo: ["version": version]
        )
    }
    
    /// 重置为默认配置
    func resetToDefaults() {
        currentVersion = .seedo
        seedoBaseURL = "https://api.sf.smart-teach.cn"
        legacyBaseURL = "https://api.sf.smart-teach.cn"
        s3Bucket = "skillflow"
        s3Region = "cn-nb1"
        s3Endpoint = "https://cn-nb1.rains3.com"
        s3AccessKey = "HNZpHzoyiMuT9qA3"
        s3SecretKey = "NUa9JAKto0OOaBYANgUkCsYO4bY54t"
    }
    
    /// 验证配置是否有效
    func validateConfiguration() -> [String] {
        var errors: [String] = []
        
        // 验证 URL 格式
        if URL(string: seedoBaseURL) == nil {
            errors.append("SEEDO API URL 格式无效")
        }
        
        if URL(string: legacyBaseURL) == nil {
            errors.append("旧版 API URL 格式无效")
        }
        
        if URL(string: s3Endpoint) == nil {
            errors.append("S3 Endpoint URL 格式无效")
        }
        
        // 验证 S3 配置
        if s3Bucket.isEmpty {
            errors.append("S3 Bucket 不能为空")
        }
        
        if s3Region.isEmpty {
            errors.append("S3 Region 不能为空")
        }
        
        if s3AccessKey.isEmpty {
            errors.append("S3 Access Key 不能为空")
        }
        
        if s3SecretKey.isEmpty {
            errors.append("S3 Secret Key 不能为空")
        }
        
        return errors
    }
    
    // MARK: - Convenience Methods
    
    /// 获取当前使用的 Base URL
    var currentBaseURL: String {
        switch currentVersion {
        case .legacy:
            return legacyBaseURL
        case .seedo:
            return seedoBaseURL
        }
    }
    
    /// 是否使用 SEEDO API
    var isUsingSEEDO: Bool {
        return currentVersion == .seedo
    }
    
    /// 是否使用旧版 API
    var isUsingLegacy: Bool {
        return currentVersion == .legacy
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let apiVersionChanged = Notification.Name("apiVersionChanged")
}
