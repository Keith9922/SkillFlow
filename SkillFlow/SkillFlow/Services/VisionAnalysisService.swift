//
//  VisionAnalysisService.swift
//  SkillFlow
//
//  Created by SkillFlow Automation on 2026/1/1.
//

import Foundation
import Vision
import CoreGraphics

class VisionAnalysisService {
    static let shared = VisionAnalysisService()
    
    private init() {}
    
    /// 执行 OCR 识别
    /// - Parameter image: 要分析的 CGImage
    /// - Returns: OCRResult 数组
    func performOCR(on image: CGImage) async throws -> [OCRResult] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let results = observations.compactMap { observation -> OCRResult? in
                    // 获取最佳候选文本
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    
                    // boundingBox 是归一化坐标，原点在左下角 (0,0)
                    return OCRResult(
                        text: candidate.string,
                        normalizedRect: observation.boundingBox,
                        confidence: candidate.confidence
                    )
                }
                
                continuation.resume(returning: results)
            }
            
            // 配置请求
            request.recognitionLevel = .accurate // 使用精确模式
            request.usesLanguageCorrection = true // 启用语言校正
            request.recognitionLanguages = ["zh-Hans", "en-US"] // 支持中文和英文
            
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// 将 OCR 结果数组转换为精简的 JSON 字符串，供 Prompt 使用
    /// - Parameter results: OCRResult 数组
    /// - Returns: JSON 字符串
    func formatForPrompt(_ results: [OCRResult]) -> String {
        guard let data = try? JSONEncoder().encode(results),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }
}
