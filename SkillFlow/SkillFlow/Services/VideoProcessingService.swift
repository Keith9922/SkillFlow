//
//  VideoProcessingService.swift
//  SkillFlow
//
//  Created by Trae AI on 2026/1/1.
//

import Foundation
import AVFoundation

enum VideoProcessingError: Error {
    case exportSessionCreationFailed
    case exportFailed(Error?)
    case outputURLInvalid
    case trackNotFound
}

actor VideoProcessingService {
    
    /// 将视频拆分为无音频的 MP4 和音频文件 (WAV)
    /// - Parameter url: 视频文件 URL
    /// - Returns: (videoURL, audioURL)
    func splitVideo(url: URL) async throws -> (video: URL, audio: URL) {
        let asset = AVAsset(url: url)
        
        // 并行执行音频提取和视频提取
        async let audioURL = extractAudio(from: asset)
        async let videoURL = extractVideoWithoutAudio(from: asset)
        
        return try await (videoURL, audioURL)
    }
    
    private func extractAudio(from asset: AVAsset) async throws -> URL {
        // 使用 AVAssetReader 和 AVAssetWriter 转码为 WAV (PCM)
        // 这样可以确保输出格式为无损的 wav，满足 wav/mp3/pcm/opus/webm 的要求
        
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let audioTrack = audioTracks.first else {
            throw VideoProcessingError.trackNotFound
        }
        
        // 1. 设置 Reader
        let reader = try AVAssetReader(asset: asset)
        // 使用 kAudioFormatLinearPCM 读取原始数据
        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)
        
        // 2. 设置 Writer (目标为 .wav)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
            
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
        
        // WAV 输出设置：16位 PCM，采样率保持源文件或设为 44100
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 44100.0, // 统一重采样到 44.1kHz 兼容性最好
            AVNumberOfChannelsKey: 1
        ]
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writer.add(writerInput)
        
        // 3. 开始转码
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // 使用队列处理数据
        let queue = DispatchQueue(label: "com.skillflow.audioExport")
        
        return try await withCheckedThrowingContinuation { continuation in
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let buffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(buffer)
                    } else {
                        writerInput.markAsFinished()
                        
                        // 完成处理
                        if reader.status == .completed {
                            writer.finishWriting {
                                if writer.status == .completed {
                                    continuation.resume(returning: outputURL)
                                } else {
                                    continuation.resume(throwing: writer.error ?? VideoProcessingError.exportFailed(nil))
                                }
                            }
                        } else {
                            writer.cancelWriting()
                            continuation.resume(throwing: reader.error ?? VideoProcessingError.exportFailed(nil))
                        }
                        break
                    }
                }
            }
        }
    }
    
    private func extractVideoWithoutAudio(from asset: AVAsset) async throws -> URL {
        let composition = AVMutableComposition()
        
        // 获取视频轨道
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw VideoProcessingError.trackNotFound
        }
        
        // 创建组合轨道
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)
        
        try compositionVideoTrack?.insertTimeRange(timeRange, of: videoTrack, at: .zero)
        
        // 保持视频方向
        let transform = try await videoTrack.load(.preferredTransform)
        compositionVideoTrack?.preferredTransform = transform
        
        // 导出为 MP4
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
            
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // 使用 HighestQuality 确保兼容性，虽然可能比 Passthrough 慢
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoProcessingError.exportSessionCreationFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        
        await exportSession.export()
        
        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw VideoProcessingError.exportFailed(exportSession.error)
        case .cancelled:
            throw VideoProcessingError.exportFailed(NSError(domain: "VideoProcessing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
        default:
            throw VideoProcessingError.exportFailed(nil)
        }
    }
}
