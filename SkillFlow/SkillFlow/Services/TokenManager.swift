//
//  TokenManager.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation
import Security
import Combine

@MainActor
class TokenManager: ObservableObject {
    // MARK: - Singleton
    static let shared = TokenManager()
    
    // MARK: - Published Properties
    @Published var token: String?
    @Published var isAuthenticated: Bool = false
    
    // MARK: - Private Properties
    private let keychainService = "com.skillflow.token"
    private let keychainAccount = "bearer_token"
    
    // MARK: - Initialization
    private init() {
        loadToken()
    }
    
    // MARK: - Public Methods
    
    /// 登录获取 Token
    /// - Parameters:
    ///   - username: 用户名
    ///   - password: 密码
    func login(username: String, password: String) async throws {
        // TODO: 实现实际的登录 API 调用
        // 这里暂时使用模拟实现
        
        guard !username.isEmpty && !password.isEmpty else {
            throw TokenError.invalidCredentials
        }
        
        // 模拟 API 调用
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
        
        // 模拟获取 token
        let mockToken = "Bearer_\(UUID().uuidString)"
        
        // 保存 token
        try saveToken(mockToken)
        
        // 更新状态
        self.token = mockToken
        self.isAuthenticated = true
    }
    
    /// 刷新 Token
    func refreshToken() async throws {
        guard let currentToken = token else {
            throw TokenError.noToken
        }
        
        // TODO: 实现实际的刷新 API 调用
        // 这里暂时使用模拟实现
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
        
        // 模拟刷新 token
        let newToken = "Bearer_\(UUID().uuidString)"
        
        // 保存新 token
        try saveToken(newToken)
        
        // 更新状态
        self.token = newToken
        self.isAuthenticated = true
    }
    
    /// 登出
    func logout() {
        deleteToken()
        token = nil
        isAuthenticated = false
    }
    
    /// 获取认证头
    func getAuthHeader() -> [String: String] {
        guard let token = token else {
            return [:]
        }
        return ["Authorization": "Bearer \(token)"]
    }
    
    // MARK: - Keychain Operations
    
    /// 从 Keychain 加载 Token
    func loadToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let tokenString = String(data: data, encoding: .utf8) {
            self.token = tokenString
            self.isAuthenticated = true
        } else {
            self.token = nil
            self.isAuthenticated = false
        }
    }
    
    /// 保存 Token 到 Keychain
    private func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw TokenError.encodingFailed
        }
        
        // 先删除旧的
        deleteToken()
        
        // 添加新的
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw TokenError.keychainError(status)
        }
    }
    
    /// 从 Keychain 删除 Token
    private func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Token Error

enum TokenError: Error, LocalizedError {
    case invalidCredentials
    case noToken
    case encodingFailed
    case keychainError(OSStatus)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "用户名或密码无效"
        case .noToken:
            return "未找到有效的 Token"
        case .encodingFailed:
            return "Token 编码失败"
        case .keychainError(let status):
            return "Keychain 错误: \(status)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}
