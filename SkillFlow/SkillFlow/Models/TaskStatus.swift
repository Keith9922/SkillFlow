//
//  TaskStatus.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation

enum TaskStatus: String, Codable {
    case created
    case processing
    case audioDone = "audio_done"
    case videoDone = "video_done"
    case finished
    case failed
    
    var displayName: String {
        switch self {
        case .created:
            return "已创建"
        case .processing:
            return "处理中"
        case .audioDone:
            return "音频完成"
        case .videoDone:
            return "视频完成"
        case .finished:
            return "已完成"
        case .failed:
            return "失败"
        }
    }
}
