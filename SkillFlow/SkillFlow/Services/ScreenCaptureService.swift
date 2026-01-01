//
//  ScreenCaptureService.swift
//  SkillFlow
//
//  Created by SkillFlow Automation on 2026/1/1.
//

import Foundation
import CoreGraphics
import AppKit
import VideoToolbox
import ScreenCaptureKit

class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    
    private init() {}
    
    /// 捕获主屏幕截图 (异步)
    /// - Returns: 包含图像数据的 Data (JPEG 格式)，如果失败则返回 nil
    func captureMainScreen() async -> Data? {
        guard let image = await captureMainScreenImage() else { return nil }
        return convertToJPEGData(image: image, compressionQuality: 0.6)
    }
    
    /// 捕获主屏幕并返回 CGImage (异步)
    func captureMainScreenImage() async -> CGImage? {
        // macOS 14.0+ 使用 ScreenCaptureKit
        if #available(macOS 14.0, *) {
            do {
                return try await captureWithSCKit()
            } catch {
                print("ScreenCaptureKit capture failed: \(error), falling back to CGDisplayCreateImage")
            }
        }
        
        // 旧版本或 SCKit 失败时回退到 CoreGraphics
        return captureWithCoreGraphics()
    }
    
    // MARK: - Implementation Details
    
    @available(macOS 14.0, *)
    private func captureWithSCKit() async throws -> CGImage {
        let content = try await SCShareableContent.current
        guard let mainDisplay = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) else {
            throw NSError(domain: "ScreenCaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Main display not found"])
        }
        
        let filter = SCContentFilter(display: mainDisplay, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = mainDisplay.width
        config.height = mainDisplay.height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }
    
    private func captureWithCoreGraphics() -> CGImage? {
        // macOS 15+ (Sequoia) SDK 中，CGDisplayCreateImage 等 API 已被标记为 unavailable
        // 且 ScreenCaptureKit 是唯一的推荐方案。
        // 为了确保项目在使用新 SDK 编译时能通过，我们这里不再尝试调用旧 API。
        // 如果是在旧系统上运行，App 应该回退到旧的构建或动态检查，
        // 但由于这是一个新项目，我们假设用户运行在支持 SCKit 的系统上（macOS 12.3+），
        // 或者我们完全放弃在 macOS 15 SDK 下编译时的 fallback 支持。
        
        print("Legacy capture fallback is disabled/unavailable in this build environment.")
        return nil
    }
    
    /// 将 CGImage 转换为 JPEG Data
    private func convertToJPEGData(image: CGImage, compressionQuality: Float) -> Data? {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionQuality])
    }
    
    /// 检查屏幕录制权限
    func checkScreenRecordingPermission() -> Bool {
        if #available(macOS 11.0, *) {
            return CGPreflightScreenCaptureAccess()
        } else {
            return true
        }
    }
    
    /// 请求屏幕录制权限
    func requestScreenRecordingPermission() {
        if #available(macOS 11.0, *) {
            CGRequestScreenCaptureAccess()
        }
    }
}
