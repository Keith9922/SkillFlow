//
//  StageDetail.swift
//  SkillFlow
//
//  Created by SEEDO API Refactor on 2026/1/1.
//

import Foundation

struct StageDetail: Identifiable {
    let id = UUID()
    let stage: ParseStage
    var status: StageStatus
    let title: String
    let icon: String
    
    init(stage: ParseStage, status: StageStatus = .pending) {
        self.stage = stage
        self.status = status
        self.title = stage.displayName
        self.icon = stage.icon
    }
}

enum StageStatus {
    case pending
    case inProgress
    case completed
    case failed
    
    var displayName: String {
        switch self {
        case .pending:
            return "待处理"
        case .inProgress:
            return "进行中"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        }
    }
}
