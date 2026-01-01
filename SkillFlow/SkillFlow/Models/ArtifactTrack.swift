//
//  ArtifactTrack.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation

enum ArtifactTrack: String {
    case audio
    case video
    case steps
    
    var displayName: String {
        switch self {
        case .audio:
            return "音频"
        case .video:
            return "视频"
        case .steps:
            return "步骤"
        }
    }
}
