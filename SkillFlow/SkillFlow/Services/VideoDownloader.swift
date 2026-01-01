//
//  VideoDownloader.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation
import AVFoundation

class VideoDownloader {
    // MARK: - Properties
    private let session: URLSession
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes
        config.timeoutIntervalForResource = 1800 // 30 minutes
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Download Methods
    
    /// 下载视频
    /// - Parameters:
    ///   - url: 视频 URL（支持直接链接或平台链接）
    ///   - progress: 进度回调
    /// - Returns: 本地文件路径
    func download(
        url: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        // 检查是否是直接视频链接
        if isDirectVideoURL(url) {
            return try await downloadDirect(url: url, progress: progress)
        } else {
            // 对于平台链接（B站、抖音等），需要先解析真实视频地址
            return try await downloadFromPlatform(url: url, progress: progress)
        }
    }
    
    /// 提取音频
    /// - Parameter videoPath: 视频文件路径
    /// - Returns: 音频文件路径
    func extractAudio(from videoPath: URL) async throws -> URL {
        let asset = AVAsset(url: videoPath)
        
        // 检查是否有音频轨道
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw VideoDownloadError.noAudioTrack
        }
        
        // 创建输出文件路径
        let outputURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        
        // 创建导出会话
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw VideoDownloadError.exportFailed("无法创建导出会话")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        // 执行导出
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw VideoDownloadError.exportFailed(
                exportSession.error?.localizedDescription ?? "未知错误"
            )
        }
        
        // 转换为 WAV 格式（如果需要）
        return try await convertToWAV(from: outputURL)
    }
    
    // MARK: - Private Methods
    
    /// 检查是否是直接视频链接
    private func isDirectVideoURL(_ urlString: String) -> Bool {
        let videoExtensions = ["mp4", "mov", "avi", "mkv", "flv", "wmv", "m4v"]
        let lowercased = urlString.lowercased()
        
        return videoExtensions.contains { lowercased.hasSuffix(".\($0)") }
    }
    
    /// 直接下载视频
    private func downloadDirect(
        url: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        guard let videoURL = URL(string: url) else {
            throw VideoDownloadError.invalidURL
        }
        
        // 创建临时文件路径
        let tempURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        // 下载文件
        let (localURL, response) = try await downloadWithProgress(
            url: videoURL,
            to: tempURL,
            progress: progress
        )
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw VideoDownloadError.downloadFailed(
                "HTTP status: \((response as? HTTPURLResponse)?.statusCode ?? 0)"
            )
        }
        
        return localURL
    }
    
    /// 从平台下载视频
    private func downloadFromPlatform(
        url: String,
        progress: @escaping (Double) -> Void
    ) async throws -> URL {
        // TODO: 实现平台视频解析
        // 这里需要集成 yt-dlp 或类似工具
        // 暂时抛出未实现错误
        
        // 在实际实现中，应该：
        // 1. 调用 yt-dlp 解析视频真实地址
        // 2. 下载视频到本地
        // 3. 返回本地路径
        
        throw VideoDownloadError.platformNotSupported(
            "平台视频下载功能尚未实现，请使用直接视频链接"
        )
    }
    
    /// 带进度的下载
    private func downloadWithProgress(
        url: URL,
        to destination: URL,
        progress: @escaping (Double) -> Void
    ) async throws -> (URL, URLResponse) {
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: url) { tempURL, response, error in
                if let error = error {
                    continuation.resume(throwing: VideoDownloadError.networkError(error))
                    return
                }
                
                guard let tempURL = tempURL, let response = response else {
                    continuation.resume(throwing: VideoDownloadError.downloadFailed("No response"))
                    return
                }
                
                do {
                    // 移动文件到目标位置
                    if self.fileManager.fileExists(atPath: destination.path) {
                        try self.fileManager.removeItem(at: destination)
                    }
                    try self.fileManager.moveItem(at: tempURL, to: destination)
                    
                    continuation.resume(returning: (destination, response))
                } catch {
                    continuation.resume(throwing: VideoDownloadError.fileOperationFailed(error))
                }
            }
            
            // 监听进度（简化版本）
            Task {
                var currentProgress = 0.0
                
                while currentProgress < 1.0 && task.state == .running {
                    currentProgress += 0.1
                    progress(min(currentProgress, 1.0))
                    
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 秒
                }
                
                progress(1.0)
            }
            
            task.resume()
        }
    }
    
    /// 转换为 WAV 格式
    private func convertToWAV(from sourceURL: URL) async throws -> URL {
        let outputURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        
        let asset = AVAsset(url: sourceURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw VideoDownloadError.conversionFailed("无法创建转换会话")
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .wav
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            // 如果 WAV 转换失败，返回原始 M4A 文件
            // 大多数情况下 M4A 也可以被接受
            return sourceURL
        }
        
        // 删除源文件
        try? fileManager.removeItem(at: sourceURL)
        
        return outputURL
    }
}

// MARK: - Video Download Error

enum VideoDownloadError: Error, LocalizedError {
    case invalidURL
    case downloadFailed(String)
    case networkError(Error)
    case noAudioTrack
    case exportFailed(String)
    case conversionFailed(String)
    case fileOperationFailed(Error)
    case platformNotSupported(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的视频 URL"
        case .downloadFailed(let message):
            return "下载失败: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .noAudioTrack:
            return "视频中没有音频轨道"
        case .exportFailed(let message):
            return "导出失败: \(message)"
        case .conversionFailed(let message):
            return "格式转换失败: \(message)"
        case .fileOperationFailed(let error):
            return "文件操作失败: \(error.localizedDescription)"
        case .platformNotSupported(let message):
            return message
        }
    }
}
