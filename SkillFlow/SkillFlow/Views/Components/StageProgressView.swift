//
//  StageProgressView.swift
//  SkillFlow
//
//  Created by Kiro on 2026/1/1.
//

import SwiftUI

struct StageProgressView: View {
    let stageDetails: [StageDetail]
    let currentProgress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Overall progress bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("整体进度")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(currentProgress))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: currentProgress, total: 100)
                    .progressViewStyle(.linear)
            }
            .padding(.bottom, 8)
            
            // Stage list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(stageDetails) { detail in
                    StageRow(detail: detail)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct StageRow: View {
    let detail: StageDetail
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .frame(width: 20, height: 20)
            
            // Stage info
            VStack(alignment: .leading, spacing: 2) {
                Text(detail.title)
                    .font(.system(size: 13))
                    .foregroundColor(textColor)
                
                if detail.status == .inProgress {
                    Text("进行中...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status indicator
            if detail.status == .inProgress {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch detail.status {
        case .pending:
            Image(systemName: detail.icon)
                .foregroundColor(.secondary)
        case .inProgress:
            Image(systemName: detail.icon)
                .foregroundColor(.blue)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }
    
    private var textColor: Color {
        switch detail.status {
        case .pending:
            return .secondary
        case .inProgress:
            return .primary
        case .completed:
            return .secondary
        case .failed:
            return .red
        }
    }
}

#Preview {
    StageProgressView(
        stageDetails: [
            StageDetail(stage: .downloading, status: .completed, title: "下载视频", icon: "arrow.down.circle"),
            StageDetail(stage: .extractingAudio, status: .completed, title: "提取音频", icon: "waveform"),
            StageDetail(stage: .uploading, status: .inProgress, title: "上传文件", icon: "arrow.up.circle"),
            StageDetail(stage: .creatingTask, status: .pending, title: "创建任务", icon: "doc.badge.plus"),
            StageDetail(stage: .audioProcessing, status: .pending, title: "音频转录", icon: "text.bubble"),
            StageDetail(stage: .videoProcessing, status: .pending, title: "视频分析", icon: "video"),
            StageDetail(stage: .stepsGenerating, status: .pending, title: "生成步骤", icon: "list.bullet"),
            StageDetail(stage: .completed, status: .pending, title: "完成", icon: "checkmark.circle")
        ],
        currentProgress: 35
    )
    .frame(width: 300)
    .padding()
}
