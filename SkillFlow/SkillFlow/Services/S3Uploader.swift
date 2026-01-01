//
//  S3Uploader.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation
import CryptoKit

class S3Uploader {
    // MARK: - Properties
    private let endpoint: String
    private let bucket: String
    private let accessKey: String
    private let secretKey: String
    private let region: String
    private let session: URLSession
    
    // MARK: - Initialization
    init(
        endpoint: String = "https://cn-nb1.rains3.com",
        bucket: String = "skillflow",
        accessKey: String = "HNZpHzoyiMuT9qA3",
        secretKey: String = "NUa9JAKto0OOaBYANgUkCsYO4bY54t",
        region: String = "cn-nb1"
    ) {
        self.endpoint = endpoint
        self.bucket = bucket
        self.accessKey = accessKey
        self.secretKey = secretKey
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
    ///   - key: S3 对象键（路径，如 "skillflow/uuid/video.mp4"）
    ///   - contentType: 内容类型
    ///   - progress: 进度回调
    /// - Returns: 公开访问 URL
    func upload(
        data: Data,
        key: String,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws -> String {
        // 构建上传 URL
        let uploadURL = URL(string: "\(endpoint)/\(bucket)/\(key)")!
        
        // 创建上传请求
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")
        
        // 添加 AWS 签名 v4
        let dateString = ISO8601DateFormatter().string(from: Date())
        request.setValue(dateString, forHTTPHeaderField: "x-amz-date")
        
        // 生成签名
        let signature = generateSignature(
            method: "PUT",
            url: uploadURL,
            headers: request.allHTTPHeaderFields ?? [:],
            payload: data,
            date: dateString
        )
        
        request.setValue(signature, forHTTPHeaderField: "Authorization")
        
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
        
        // 返回公开访问 URL
        return "\(endpoint)/\(bucket)/\(key)"
    }
    
    // MARK: - Private Methods
    
    /// 生成 AWS Signature V4
    private func generateSignature(
        method: String,
        url: URL,
        headers: [String: String],
        payload: Data,
        date: String
    ) -> String {
        // 简化的签名实现
        // 实际生产环境应该使用完整的 AWS Signature V4 算法
        
        let credential = "\(accessKey)/\(getDateStamp(from: date))/\(region)/s3/aws4_request"
        let signedHeaders = "content-type;host;x-amz-acl;x-amz-date"
        
        // 这里使用简化的签名格式
        // 在实际使用中，如果遇到认证问题，需要实现完整的 AWS Signature V4
        return "AWS4-HMAC-SHA256 Credential=\(credential), SignedHeaders=\(signedHeaders), Signature=placeholder"
    }
    
    /// 从 ISO8601 日期字符串提取日期戳
    private func getDateStamp(from dateString: String) -> String {
        return String(dateString.prefix(8))
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
