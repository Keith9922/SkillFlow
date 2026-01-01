//
//  Task.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation
import SwiftData

@Model
final class Task {
    @Attribute(.unique) var entryId: String
    var status: String // processing, audio_done, video_done, finished, failed
    var dirLocation: String
    var createdAt: Date
    var updatedAt: Date
    var errorMessage: String?
    
    init(entryId: String, dirLocation: String, status: String = "processing") {
        self.entryId = entryId
        self.dirLocation = dirLocation
        self.status = status
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
