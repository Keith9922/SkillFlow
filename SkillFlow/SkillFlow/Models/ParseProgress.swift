//
//  ParseProgress.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation

struct ParseProgress {
    var stage: ParseStage
    var progress: Double
    var message: String
    var timestamp: Date
    
    init(stage: ParseStage, progress: Double, message: String) {
        self.stage = stage
        self.progress = progress
        self.message = message
        self.timestamp = Date()
    }
}
