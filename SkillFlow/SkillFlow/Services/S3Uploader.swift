//
//  S3Uploader.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation

class S3Uploader {
    // MARK: - Properties
    private let bucket: String
    private let region: String
    private let session: URLSession
    
    // MARK: - Initialization
    init(bucket: String = "skillflow", region: String = "us-east-1") {
        self.bucket = bucket
        self.region = region
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 600 // 10 minutes
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Upload Methods
    
    /// 上传文件到 S3
    /// - Parameters:
    ///   - data: 文件数据
    ///   - key: S3 对象键（完整路径，如 "s3://bucket/prefix/file.mp4"）
    ///   - contentType: 内容类型
    ///   - progress: 进度回调
    /// - Returns: S3 URL
    func upload(
        data: Data,
        key: String,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws -> String {
        // 解析 S3 路径
        let s3URL = try parseS3URL(key)
        
        // 生成预签名 URL
        let uploadURL = try await generatePresignedURL(key: s3URL.key)
        
        // 创建上传请求
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        
        // 执行上传
        let (_, response) = try await uploadWithProgress(
            request: request,
            data: data,
            progress: progress
        )
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw S3Error.uploadFailed("HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        
        return key
    }
    
    /// 生成预签名 URL
    /// - Parameter key: S3 对象键
    /// - Returns: 预签名 URL
    func generatePresignedURL(key: String) async throws -> URL {
        // TODO: 实现实际的预签名 URL 生成
        // 这里暂时使用模拟实现
        
        // 在实际实现中，应该调用后端 API 获取预签名 URL
        // 或者使用 AWS SDK 生成
        
        let s3URL = try parseS3URL(key)
        
        // 模拟预签名 URL（实际应该包含签名参数）
        let urlString = "https://\(s3URL.bucket).s3.\(region).amazonaws.com/\(s3URL.key)"
        
        guard let url = URL(string: urlString) else {
            throw S3Error.invalidURL
        }
        
        return url
    }
    
    // MARK: - Private Methods
    
    /// 解析 S3 URL
    private func parseS3URL(_ urlString: String) throws -> (bucket: String, key: String) {
        // 支持两种格式：
        // 1. s3://bucket/key
        // 2. https://bucket.s3.region.amazonaws.com/key
        
        if urlString.hasPrefix("s3://") {
            let path = urlString.replacingOccurrences(of: "s3://", with: "")
            let components = path.components(separatedBy: "/")
            
            guard components.count >= 2 else {
                throw S3Error.invalidURL
            }
            
            let bucket = components[0]
            let key = components.dropFirst().joined(separator: "/")
            
            return (bucket, key)
        } else if urlString.contains(".s3.") {
            guard let url = URL(string: urlString),
                  let host = url.host,
                  let bucket = host.components(separatedBy: ".").first else {
                throw S3Error.invalidURL
            }
            
            let key = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            
            return (bucket, key)
        } else {
            throw S3Error.invalidURL
        }
    }
    
    /// 带进度的上传
    private func uploadWithProgress(
        request: URLRequest,
        data: Data,
        progress: @escaping (Double) -> Void
    ) async throws -> (Data, URLResponse) {
        // 创建上传任务
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, from: data) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: S3Error.networkError(error))
                    return
                }
                
                guard let data = data, let response = response else {
                    continuation.resume(throwing: S3Error.uploadFailed("No response"))
                    return
                }
                
                continuation.resume(returning: (data, response))
            }
            
            // 监听进度（简化版本，实际需要使用 URLSessionTaskDelegate）
            // 这里模拟进度更新
            Task {
                let totalSize = Double(data.count)
                var uploadedSize = 0.0
                
                while uploadedSize < totalSize && task.state == .running {
                    uploadedSize += totalSize * 0.1
                    let currentProgress = min(uploadedSize / totalSize, 1.0)
                    progress(currentProgress)
                    
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 秒
                }
                
                progress(1.0)
            }
            
            task.resume()
        }
    }
}

// MARK: - S3 Error

enum S3Error: Error, LocalizedError {
    case invalidURL
    case uploadFailed(String)
    case networkError(Error)
    case authenticationFailed
    case bucketNotFound
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 S3 URL"
        case .uploadFailed(let message):
            return "上传失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .authenticationFailed:
            return "S3 认证失败"
        case .bucketNotFound:
            return "S3 存储桶不存在"
        case .accessDenied:
            return "S3 访问被拒绝"
        }
    }
}
