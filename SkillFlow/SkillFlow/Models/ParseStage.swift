//
//  ParseStage.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation

enum ParseStage: String, Codable {
    case idle
    case downloading
    case extractingAudio
    case uploading
    case creatingTask
    case audioProcessing
    case audioPolling
    case videoProcessing
    case videoPolling
    case stepsGenerating
    case stepsPolling
    case completed
    case failed
    
    var displayName: String {
        switch self {
        case .idle:
            return "空闲"
        case .downloading:
            return "下载视频中"
        case .extractingAudio:
            return "提取音频中"
        case .uploading:
            return "上传文件中"
        case .creatingTask:
            return "创建任务中"
        case .audioProcessing:
            return "音频解析中"
        case .audioPolling:
            return "等待音频结果"
        case .videoProcessing:
            return "视频分析中"
        case .videoPolling:
            return "等待视频结果"
        case .stepsGenerating:
            return "步骤生成中"
        case .stepsPolling:
            return "等待步骤结果"
        case .completed:
            return "完成"
        case .failed:
            return "失败"
        }
    }
    
    var icon: String {
        switch self {
        case .idle:
            return "circle"
        case .downloading:
            return "arrow.down.circle"
        case .extractingAudio:
            return "waveform"
        case .uploading:
            return "arrow.up.circle"
        case .creatingTask:
            return "plus.circle"
        case .audioProcessing, .audioPolling:
            return "mic.circle"
        case .videoProcessing, .videoPolling:
            return "video.circle"
        case .stepsGenerating, .stepsPolling:
            return "list.bullet.circle"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
}
