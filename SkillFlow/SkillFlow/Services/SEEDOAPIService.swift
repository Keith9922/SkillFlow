//
//  SEEDOAPIService.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//  新的 SEEDO API 服务层
//

import Foundation

@MainActor
class SEEDOAPIService {
    // MARK: - Singleton
    static let shared = SEEDOAPIService()
    
    // MARK: - Properties
    private let baseURL: String
    private let tokenManager: TokenManager
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    init(
        baseURL: String? = nil,
        tokenManager: TokenManager = .shared
    ) {
        self.baseURL = baseURL ?? APIConfiguration.shared.currentBaseURL
        self.tokenManager = tokenManager
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }
    
    // MARK: - Task Management API
    
    /// 创建任务
    /// - Returns: entryId
    func createTask() async throws -> String {
        struct Request: Encodable {
            // Empty request body
        }
        
        struct Response: Decodable {
            let entryId: String
            let status: String
        }
        
        let response: Response = try await makeRequest(
            endpoint: "/v1/tasks/create",
            method: "POST",
            body: Request()
        )
        
        return response.entryId
    }
    
    /// 获取任务状态
    /// - Parameter entryId: 任务 ID
    /// - Returns: 任务状态
    func getTaskStatus(entryId: String) async throws -> TaskStatus {
        struct Response: Decodable {
            let entryId: String
            let status: String
        }
        
        let response: Response = try await makeRequest(
            endpoint: "/v1/tasks/status",
            method: "GET",
            queryItems: [URLQueryItem(name: "entryId", value: entryId)]
        )
        
        guard let status = TaskStatus(rawValue: response.status) else {
            throw SEEDOError.invalidResponse
        }
        
        return status
    }
    
    /// 获取任务列表
    /// - Returns: 任务摘要列表
    func listTasks() async throws -> [TaskSummary] {
        struct Response: Decodable {
            let count: Int
            let tasks: [TaskSummary]
        }
        
        let response: Response = try await makeRequest(
            endpoint: "/v1/tasks/list",
            method: "GET"
        )
        
        return response.tasks
    }
    
    // MARK: - Parse Operations API
    
    /// 提交音频解析
    /// - Parameters:
    ///   - entryId: 任务 ID
    ///   - audioUrl: 音频文件 URL
    func parseAudio(entryId: String, audioUrl: String) async throws {
        struct Request: Encodable {
            let entryId: String
            let audioUrl: String
        }
        
        struct Response: Decodable {
            let status: String
        }
        
        let _: Response = try await makeRequest(
            endpoint: "/v1/parse/audio",
            method: "POST",
            body: Request(entryId: entryId, audioUrl: audioUrl)
        )
    }
    
    /// 提交视频解析
    /// - Parameters:
    ///   - entryId: 任务 ID
    ///   - videoUrl: 视频文件 URL
    ///   - transcriptText: 音频转录文本
    func parseVideo(
        entryId: String,
        videoUrl: String,
        transcriptText: String
    ) async throws {
        struct Request: Encodable {
            let entryId: String
            let videoUrl: String
            let transcriptText: String
        }
        
        struct Response: Decodable {
            let status: String
        }
        
        let _: Response = try await makeRequest(
            endpoint: "/v1/parse/video",
            method: "POST",
            body: Request(
                entryId: entryId,
                videoUrl: videoUrl,
                transcriptText: transcriptText
            )
        )
    }
    
    // MARK: - Artifact Retrieval API
    
    /// 获取处理结果
    /// - Parameters:
    ///   - entryId: 任务 ID
    ///   - track: 结果类型（audio/video/steps）
    /// - Returns: 结果数据
    func getArtifact(
        entryId: String,
        track: ArtifactTrack
    ) async throws -> ArtifactData {
        let artifact: ArtifactData = try await makeRequest(
            endpoint: "/v1/tasks/artifact",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "entryId", value: entryId),
                URLQueryItem(name: "track", value: track.rawValue)
            ]
        )
        
        return artifact
    }
    
    // MARK: - Generic Request Method
    
    /// 通用请求方法
    private func makeRequest<T: Decodable>(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem]? = nil,
        body: Encodable? = nil,
        retryCount: Int = 3
    ) async throws -> T {
        // 构建 URL
        var urlComponents = URLComponents(string: baseURL + endpoint)
        urlComponents?.queryItems = queryItems
        
        guard let url = urlComponents?.url else {
            throw SEEDOError.invalidURL
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加认证头
        let authHeaders = tokenManager.getAuthHeader()
        for (key, value) in authHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 添加请求体
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        // 执行请求（带重试）
        var lastError: Error?
        
        for attempt in 0..<retryCount {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SEEDOError.invalidResponse
                }
                
                // 处理不同的状态码
                switch httpResponse.statusCode {
                case 200...299:
                    // 成功
                    return try decoder.decode(T.self, from: data)
                    
                case 401:
                    // Token 过期，尝试刷新
                    if attempt == 0 {
                        try await tokenManager.refreshToken()
                        continue // 重试
                    } else {
                        throw SEEDOError.authenticationFailed
                    }
                    
                case 400...499:
                    // 客户端错误
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw SEEDOError.clientError(httpResponse.statusCode, errorMessage)
                    
                case 500...599:
                    // 服务器错误
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    throw SEEDOError.serverError(httpResponse.statusCode, errorMessage)
                    
                default:
                    throw SEEDOError.invalidResponse
                }
                
            } catch let error as SEEDOError {
                // SEEDO 错误直接抛出
                throw error
            } catch {
                // 网络错误，记录并重试
                lastError = error
                
                if attempt < retryCount - 1 {
                    // 等待后重试
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                    continue
                }
            }
        }
        
        // 所有重试都失败
        throw SEEDOError.networkError(lastError ?? NSError(domain: "Unknown", code: -1))
    }
}

// MARK: - Task Summary

struct TaskSummary: Codable, Identifiable {
    let entryId: String
    let status: TaskStatus
    
    var id: String { entryId }
}

// MARK: - SEEDO Error

enum SEEDOError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case tokenExpired
    case clientError(Int, String)
    case serverError(Int, String)
    case networkError(Error)
    case decodingError(Error)
    case uploadFailed(String)
    case taskCreationFailed(String)
    case audioParseFailed(String)
    case videoParseFailed(String)
    case stepGenerationFailed(String)
    case pollingTimeout
    case dataConversionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .invalidResponse:
            return "服务器响应无效"
        case .authenticationFailed:
            return "认证失败，请重新登录"
        case .tokenExpired:
            return "登录已过期，请重新登录"
        case .clientError(let code, let message):
            return "客户端错误 (\(code)): \(message)"
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .uploadFailed(let msg):
            return "文件上传失败: \(msg)"
        case .taskCreationFailed(let msg):
            return "任务创建失败: \(msg)"
        case .audioParseFailed(let msg):
            return "音频解析失败: \(msg)"
        case .videoParseFailed(let msg):
            return "视频分析失败: \(msg)"
        case .stepGenerationFailed(let msg):
            return "步骤生成失败: \(msg)"
        case .pollingTimeout:
            return "处理超时，请稍后查看任务列表"
        case .dataConversionFailed:
            return "数据转换失败"
        }
    }
}
