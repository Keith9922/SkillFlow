//
//  S3Service.swift
//  SkillFlow
//
//  Created by Trae AI on 2026/1/1.
//

import Foundation

enum S3Error: Error {
    case fileReadFailed
    case uploadFailed(Int, String)
    case invalidURL
}

actor S3Service {
    // 静态资源服务器 Base URL
    private let baseURL = "https://static.smart-teach.cn/seedo"
    // 简单的鉴权 Key
    private let putKey = "114514stcn"
    
    /// 上传文件到静态服务器并返回访问链接
    /// - Parameters:
    ///   - fileURL: 本地文件路径
    ///   - contentType: MIME 类型
    ///   - folder: 目标文件夹名称（可选），如果不传则自动生成 UUID
    /// - Returns: 公网访问链接
    func upload(fileURL: URL, contentType: String, folder: String? = nil) async throws -> String {
        let fileName = fileURL.lastPathComponent
        let folderName = folder ?? UUID().uuidString
        // 构建路径: folder/filename
        let objectPath = "\(folderName)/\(fileName)"
        
        // 最终的 URL 既是上传地址也是下载地址
        guard let url = URL(string: "\(baseURL)/\(objectPath)") else {
            throw S3Error.invalidURL
        }
        
        // 读取文件数据
        guard let fileData = try? Data(contentsOf: fileURL) else {
            throw S3Error.fileReadFailed
        }
        
        print("[S3Service] Uploading \(fileName) to \(url.absoluteString) (Size: \(fileData.count) bytes)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = fileData
        
        // 设置 Headers
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("\(fileData.count)", forHTTPHeaderField: "Content-Length")
        // 核心鉴权 Header
        request.setValue(putKey, forHTTPHeaderField: "x-put-key")
        
        // 打印请求信息用于调试
        print("[S3Service] PUT \(url.absoluteString)")
        
        // 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw S3Error.uploadFailed(0, "Invalid response")
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("[S3Service] Upload failed: HTTP \(httpResponse.statusCode) - \(body)")
            throw S3Error.uploadFailed(httpResponse.statusCode, body)
        }
        
        print("[S3Service] Upload success")
        return url.absoluteString
    }
}
